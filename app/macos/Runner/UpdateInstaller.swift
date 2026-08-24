import Foundation

struct UpdatePaths {
  let installApp: URL
  let staged: URL
  let backup: URL
  let log: URL

  init(installApp: URL, pid: pid_t) {
    self.installApp = installApp
    let installDirectory = installApp.deletingLastPathComponent()
    let pidSuffix = String(pid)
    staged = installDirectory.appendingPathComponent(".INbox.app.installing.\(pidSuffix)", isDirectory: true)
    backup = installDirectory.appendingPathComponent(".INbox.app.backup.\(pidSuffix)", isDirectory: true)
    log = FileManager.default.temporaryDirectory
      .appendingPathComponent("inbox-update-install-\(pidSuffix).log", isDirectory: false)
  }
}

enum UpdateInstallError: Error {
  case mountFailed(String)
  case missingApp(String)
  case permissionDenied(String)
  case stagingFailed(String)
  case helperLaunchFailed(String)

  var flutterCode: String {
    switch self {
    case .mountFailed:
      return "MOUNT_FAILED"
    case .missingApp:
      return "MISSING_APP"
    case .permissionDenied:
      return "PERMISSION_DENIED"
    case .stagingFailed:
      return "STAGING_FAILED"
    case .helperLaunchFailed:
      return "HELPER_LAUNCH_FAILED"
    }
  }

  var message: String {
    switch self {
    case .mountFailed(let message),
         .missingApp(let message),
         .permissionDenied(let message),
         .stagingFailed(let message),
         .helperLaunchFailed(let message):
      return message
    }
  }
}

enum UpdateInstaller {
  private static let appName = "INbox.app"
  private static let installApp = URL(fileURLWithPath: "/Applications/INbox.app", isDirectory: true)

  static func prepare(dmgPath: String, completion: @escaping (Result<Void, UpdateInstallError>) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      let result: Result<Void, UpdateInstallError>
      do {
        try prepareSynchronously(dmgPath: dmgPath)
        result = .success(())
      } catch let error as UpdateInstallError {
        result = .failure(error)
      } catch {
        result = .failure(.stagingFailed(error.localizedDescription))
      }

      DispatchQueue.main.async {
        completion(result)
      }
    }
  }

  static func mountPoint(fromAttachPlist data: Data) throws -> URL {
    let plist: Any
    do {
      plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    } catch {
      throw UpdateInstallError.mountFailed("Could not parse hdiutil output: \(error.localizedDescription)")
    }

    guard let dictionary = plist as? [String: Any],
          let entities = dictionary["system-entities"] as? [[String: Any]] else {
      throw UpdateInstallError.mountFailed("hdiutil output did not include mounted entities")
    }

    for entity in entities {
      if let mountPath = entity["mount-point"] as? String, !mountPath.isEmpty {
        return URL(fileURLWithPath: mountPath, isDirectory: true)
      }
    }

    throw UpdateInstallError.mountFailed("hdiutil output did not include a mount point")
  }

  private static func prepareSynchronously(dmgPath: String) throws {
    let paths = UpdatePaths(
      installApp: installApp,
      pid: ProcessInfo.processInfo.processIdentifier
    )
    let installDirectory = paths.installApp.deletingLastPathComponent()

    guard FileManager.default.isWritableFile(atPath: installDirectory.path) else {
      throw UpdateInstallError.permissionDenied("INbox cannot write to \(installDirectory.path)")
    }

    let attachResult: CommandResult
    do {
      attachResult = try run(
        executable: URL(fileURLWithPath: "/usr/bin/hdiutil"),
        arguments: ["attach", "-nobrowse", "-readonly", "-plist", dmgPath]
      )
    } catch {
      throw UpdateInstallError.mountFailed("Could not start hdiutil: \(error.localizedDescription)")
    }
    guard attachResult.exitCode == 0 else {
      throw UpdateInstallError.mountFailed(attachResult.failureMessage(defaultMessage: "Could not mount update DMG"))
    }

    let mountPoint = try self.mountPoint(fromAttachPlist: attachResult.stdout)
    var shouldDetach = true
    defer {
      if shouldDetach {
        _ = try? run(
          executable: URL(fileURLWithPath: "/usr/bin/hdiutil"),
          arguments: ["detach", mountPoint.path]
        )
      }
    }

    let sourceApp = mountPoint.appendingPathComponent(appName, isDirectory: true)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: sourceApp.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      throw UpdateInstallError.missingApp("The update DMG does not contain \(appName)")
    }

    try removeGeneratedPathIfPresent(paths.staged)
    let dittoResult: CommandResult
    do {
      dittoResult = try run(
        executable: URL(fileURLWithPath: "/usr/bin/ditto"),
        arguments: [sourceApp.path, paths.staged.path]
      )
    } catch {
      try? removeGeneratedPathIfPresent(paths.staged)
      throw UpdateInstallError.stagingFailed("Could not start ditto: \(error.localizedDescription)")
    }
    guard dittoResult.exitCode == 0 else {
      try? removeGeneratedPathIfPresent(paths.staged)
      throw UpdateInstallError.stagingFailed(dittoResult.failureMessage(defaultMessage: "Could not stage INbox update"))
    }

    if let detachResult = try? run(
      executable: URL(fileURLWithPath: "/usr/bin/hdiutil"),
      arguments: ["detach", mountPoint.path]
    ), detachResult.exitCode == 0 {
      shouldDetach = false
    }

    var helperURL: URL?
    do {
      let copiedHelperURL = try copyHelperToTemporaryFile(pid: ProcessInfo.processInfo.processIdentifier)
      helperURL = copiedHelperURL
      try launchHelper(
        helperURL: copiedHelperURL,
        paths: paths,
        oldPID: ProcessInfo.processInfo.processIdentifier
      )
    } catch {
      if let helperURL = helperURL {
        try? FileManager.default.removeItem(at: helperURL)
      }
      try? removeGeneratedPathIfPresent(paths.staged)
      throw error
    }
  }

  private static func copyHelperToTemporaryFile(pid: pid_t) throws -> URL {
    guard let bundledHelper = Bundle.main.url(forResource: "replace_macos_app", withExtension: "sh") else {
      throw UpdateInstallError.helperLaunchFailed("Bundled update helper is missing")
    }

    let temporaryHelper = FileManager.default.temporaryDirectory
      .appendingPathComponent("replace_macos_app_\(pid)_\(UUID().uuidString).sh", isDirectory: false)

    do {
      try FileManager.default.copyItem(at: bundledHelper, to: temporaryHelper)
      try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o700))],
        ofItemAtPath: temporaryHelper.path
      )
      return temporaryHelper
    } catch {
      throw UpdateInstallError.helperLaunchFailed("Could not prepare update helper: \(error.localizedDescription)")
    }
  }

  private static func launchHelper(helperURL: URL, paths: UpdatePaths, oldPID: pid_t) throws {
    let process = Process()
    process.executableURL = helperURL
    process.arguments = [
      String(oldPID),
      paths.staged.path,
      paths.installApp.path,
      paths.backup.path,
      paths.log.path,
    ]

    do {
      try process.run()
    } catch {
      throw UpdateInstallError.helperLaunchFailed("Could not launch update helper: \(error.localizedDescription)")
    }
  }

  private static func removeGeneratedPathIfPresent(_ url: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path) else { return }

    guard url.lastPathComponent.hasPrefix(".INbox.app.") else {
      throw UpdateInstallError.stagingFailed("Refusing to remove unexpected path: \(url.path)")
    }

    try FileManager.default.removeItem(at: url)
  }

  private static func run(executable: URL, arguments: [String]) throws -> CommandResult {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    return CommandResult(
      exitCode: process.terminationStatus,
      stdout: stdout.fileHandleForReading.readDataToEndOfFile(),
      stderr: stderr.fileHandleForReading.readDataToEndOfFile()
    )
  }
}

private struct CommandResult {
  let exitCode: Int32
  let stdout: Data
  let stderr: Data

  func failureMessage(defaultMessage: String) -> String {
    let stderrText = String(data: stderr, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let stderrText = stderrText, !stderrText.isEmpty {
      return stderrText
    }

    let stdoutText = String(data: stdout, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let stdoutText = stdoutText, !stdoutText.isEmpty {
      return stdoutText
    }

    return defaultMessage
  }
}
