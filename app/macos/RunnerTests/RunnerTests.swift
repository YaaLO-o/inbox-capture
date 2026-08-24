import Cocoa
import FlutterMacOS
import XCTest
@testable import INbox

class RunnerTests: XCTestCase {

  func testWindowDragUsesAbsoluteScreenDelta() {
    let session = WindowDragSession(
      mouseOrigin: NSPoint(x: 400, y: 300),
      windowOrigin: NSPoint(x: 100, y: 80)
    )

    XCTAssertEqual(
      session.origin(for: NSPoint(x: 455, y: 270)),
      NSPoint(x: 155, y: 50)
    )
  }

  func testStatusMenuDispatchesEverySupportedAction() {
    var received: [StatusMenuAction] = []
    let dispatcher = StatusMenuDispatcher { received.append($0) }

    dispatcher.dispatch(.showWindow)
    dispatcher.dispatch(.checkForUpdates)
    dispatcher.dispatch(.quit)

    XCTAssertEqual(received, [.showWindow, .checkForUpdates, .quit])
  }

  func testUpdatePathsStayBesideApplicationsInstall() {
    let paths = UpdatePaths(installApp: URL(fileURLWithPath: "/Applications/INbox.app"), pid: 42)

    XCTAssertEqual(paths.staged.path, "/Applications/.INbox.app.installing.42")
    XCTAssertEqual(paths.backup.path, "/Applications/.INbox.app.backup.42")
  }

  func testHdiutilAttachPlistMountPointIsParsed() throws {
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>system-entities</key>
      <array>
        <dict>
          <key>content-hint</key>
          <string>Apple_HFS</string>
          <key>mount-point</key>
          <string>/Volumes/INbox</string>
        </dict>
      </array>
    </dict>
    </plist>
    """

    let mountPoint = try UpdateInstaller.mountPoint(fromAttachPlist: Data(plist.utf8))

    XCTAssertEqual(mountPoint.path, "/Volumes/INbox")
  }

  func testHelperLaunchScrubsInheritedOpenOverride() {
    let paths = UpdatePaths(installApp: URL(fileURLWithPath: "/Applications/INbox.app"), pid: 42)
    let process = UpdateInstaller.configuredHelperProcess(
      helperURL: URL(fileURLWithPath: "/tmp/replace_macos_app.sh"),
      paths: paths,
      oldPID: 42,
      inheritedEnvironment: [
        "INBOX_OPEN_COMMAND": "/tmp/fake-open",
        "INBOX_FAKE_OPEN_LOG": "/tmp/open.log",
        "PATH": "/tmp/poison",
      ]
    )

    XCTAssertEqual(process.environment, ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"])
    XCTAssertNil(process.environment?["INBOX_OPEN_COMMAND"])
    XCTAssertNil(process.environment?["INBOX_FAKE_OPEN_LOG"])
  }
}
