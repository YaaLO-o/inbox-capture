import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var menuBarController: MenuBarController?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    guard let window = mainFlutterWindow as? MainFlutterWindow,
          let controller = window.contentViewController as? FlutterViewController else { return }
    menuBarController = MenuBarController(
      controller: controller,
      window: window,
      visibilityStore: window.assistantVisibilityStore
    )
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // 悬浮入口关闭不应直接退出应用；通过右键菜单或更新流程结束。
    return false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      (mainFlutterWindow as? MainFlutterWindow)?.setAssistantVisible(true)
    }
    sender.activate(ignoringOtherApps: true)
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

// MARK: - 剪贴板通道

/// 读取 macOS 剪贴板：文字、图片（尽量保留原始格式）、Finder 复制的本地文件。
enum ClipboardChannel {
  static let channelName = "com.inbox.app/clipboard"

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "readClipboard" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(readClipboard())
    }
  }

  private static func readClipboard() -> [String: Any] {
    let pb = NSPasteboard.general
    var out: [String: Any] = [:]

    // 1) Finder 复制的本地文件路径（优先，避免把图片文件当成图片数据流处理）。
    if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
      out["files"] = urls.map { $0.path }
    } else if let names = pb.propertyList(forType: .init("NSFilenamesPboardType")) as? [String], !names.isEmpty {
      out["files"] = names
    }

    // 2) 文字。
    if let s = pb.string(forType: .string), !s.isEmpty {
      out["text"] = s
    }

    // 3) Finder 文件优先，避免同一张图片同时保存文件和 bitmap。
    //    普通应用复制图片时仍按原始类型读取，最后才回退为 PNG。
    let hasFiles = (out["files"] as? [String])?.isEmpty == false
    if !hasFiles, let (bytes, ext, mime) = readImage(from: pb) {
      out["imageBytes"] = FlutterStandardTypedData(bytes: bytes)
      out["imageExtension"] = ext
      if let mime = mime { out["imageMimeType"] = mime }
    }

    return out
  }

  private static func readImage(from pb: NSPasteboard) -> (Data, String, String?)? {
    let known: [(NSPasteboard.PasteboardType, String, String)] = [
      (.init("public.png"), "png", "image/png"),
      (.init("public.jpeg"), "jpg", "image/jpeg"),
      (.init("com.compuserve.gif"), "gif", "image/gif"),
      (.init("public.tiff"), "tiff", "image/tiff"),
      (.init("public.webp"), "webp", "image/webp"),
    ]
    let types = pb.types ?? []
    for (type, ext, mime) in known {
      if types.contains(type), let data = pb.data(forType: type), !data.isEmpty {
        return (data, ext, mime)
      }
    }

    // 回退：系统只提供 bitmap 表示时，渲染为 PNG。
    guard pb.canReadObject(forClasses: [NSImage.self], options: nil),
          let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
          let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
      return nil
    }
    return (png, "png", "image/png")
  }
}

// MARK: - 设置 / Vault 选择通道

enum SettingsChannel {
  static let channelName = "com.inbox.app/settings"
  private static let vaultKey = "vaultPath"
  private static let displayMethodKey = "displayMethod"
  private static let validDisplayMethods: Set<String> = ["inbox", "system", "obsidian"]
  private static var windowDragSession: WindowDragSession?
  /// 保留 channel 引用以支持原生 → Dart 反向调用（mainWindowDidClose）。
  private static var channel: FlutterMethodChannel?

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.engine.binaryMessenger)
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getVaultPath":
        result(UserDefaults.standard.string(forKey: vaultKey))
      case "setVaultPath":
        if let args = call.arguments as? [String: Any], let path = args["path"] as? String {
          UserDefaults.standard.set(path, forKey: vaultKey)
          result(nil)
        } else {
          result(FlutterError(code: "BAD_ARGS", message: "setVaultPath 需要 path", details: nil))
        }
      case "clearVaultPath":
        UserDefaults.standard.removeObject(forKey: vaultKey)
        result(nil)
      case "getDisplayMethod":
        result(UserDefaults.standard.string(forKey: displayMethodKey))
      case "setDisplayMethod":
        guard let args = call.arguments as? [String: Any],
              let method = args["method"] as? String,
              validDisplayMethods.contains(method) else {
          result(FlutterError(code: "BAD_ARGS",
                              message: "setDisplayMethod 需要 method ∈ inbox|system|obsidian",
                              details: nil))
          return
        }
        UserDefaults.standard.set(method, forKey: displayMethodKey)
        result(nil)
      case "getAssistantVisible":
        guard let window = controller.view.window as? MainFlutterWindow else {
          result(true)
          return
        }
        result(window.assistantVisibilityStore.isVisible)
      case "setAssistantVisible":
        guard let args = call.arguments as? [String: Any],
              let visible = args["visible"] as? Bool,
              let window = controller.view.window as? MainFlutterWindow else {
          result(FlutterError(code: "BAD_ARGS", message: "setAssistantVisible 需要 visible", details: nil))
          return
        }
        window.setAssistantVisible(visible)
        result(nil)
      case "pickFolder":
        result(pickFolder())
      case "revealPath":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "revealPath 需要 path", details: nil))
          return
        }
        let ok = NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        result(ok)
      case "openPath":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "openPath 需要 path", details: nil))
          return
        }
        result(NSWorkspace.shared.open(URL(fileURLWithPath: path)))
      case "openExternalUrl":
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
          result(FlutterError(code: "BAD_ARGS", message: "openExternalUrl 需要合法 url", details: nil))
          return
        }
        // 先探测是否有应用能处理该 scheme（例如 obsidian://）：
        // 没有则返回 false，由 Dart 侧给出"未检测到 Obsidian"的兜底。
        guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else {
          result(false)
          return
        }
        result(NSWorkspace.shared.open(url))
      case "setWindowMode":
        guard let args = call.arguments as? [String: Any],
              let mode = args["mode"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "setWindowMode 需要 mode", details: nil))
          return
        }
        guard let window = controller.view.window as? MainFlutterWindow else {
          result(FlutterError(code: "NO_WINDOW", message: "窗口不是 MainFlutterWindow", details: nil))
          return
        }
        switch mode {
        case "standard":
          window.applyStandardWindowStyle()
        case "floating":
          window.applyFloatingWindowStyle()
          window.restoreAssistantVisibility()
        default:
          result(FlutterError(code: "BAD_ARGS", message: "mode 必须是 standard|floating", details: nil))
          return
        }
        result(nil)
      case "getAppVersion":
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !version.isEmpty {
          result(version)
        } else {
          result(FlutterError(code: "MISSING_VERSION", message: "CFBundleShortVersionString is missing", details: nil))
        }
      case "showWindow":
        controller.view.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        result(nil)
      case "setWindowSize":
        guard let args = call.arguments as? [String: Any],
              let w = args["width"] as? Double,
              let h = args["height"] as? Double else {
          result(FlutterError(code: "BAD_ARGS", message: "setWindowSize 需要 width/height", details: nil)); return
        }
        // 默认动画；启动/切换关键视图时传 animate:false 可即时调整，避免首帧错配。
        let animate = (args["animate"] as? Bool) ?? true
        setWindowSize(controller: controller, width: w, height: h, animate: animate)
        result(nil)
      case "moveWindowBy":
        guard let args = call.arguments as? [String: Any],
              let dx = args["dx"] as? Double,
              let dy = args["dy"] as? Double else {
          result(FlutterError(code: "BAD_ARGS", message: "moveWindowBy 需要 dx/dy", details: nil)); return
        }
        moveWindowBy(controller: controller, dx: dx, dy: dy)
        result(nil)
      case "beginWindowDrag":
        beginWindowDrag(controller: controller)
        result(nil)
      case "updateWindowDrag":
        updateWindowDrag(controller: controller)
        result(nil)
      case "endWindowDrag":
        endWindowDrag()
        result(nil)
      case "installUpdate":
        guard let args = call.arguments as? [String: Any],
              let dmgPath = args["dmgPath"] as? String,
              !dmgPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          result(FlutterError(code: "BAD_ARGS", message: "installUpdate 需要 dmgPath", details: nil))
          return
        }
        let dmgURL = URL(fileURLWithPath: dmgPath)
        UpdateInstaller.prepare(dmgPath: dmgPath) { installResult in
          // 无论成功失败，清理下载的临时 DMG 及其目录
          let tmpDir = dmgURL.deletingLastPathComponent()
          if tmpDir.lastPathComponent.hasPrefix("inbox-update_") {
            try? FileManager.default.removeItem(at: tmpDir)
          } else {
            try? FileManager.default.removeItem(at: dmgURL)
          }
          switch installResult {
          case .success:
            result(nil)
            DispatchQueue.main.async {
              NSApp.terminate(nil)
            }
          case .failure(let error):
            result(FlutterError(code: error.flutterCode, message: error.message, details: nil))
          }
        }
      case "quit":
        NSApp.terminate(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func setWindowSize(controller: FlutterViewController, width: Double, height: Double, animate: Bool) {
    guard let window = controller.view.window else { return }
    let newSize = NSSize(width: width, height: height)
    let oldTop = window.frame.maxY
    let oldLeft = window.frame.minX
    let apply = {
      window.setContentSize(newSize)
      var f = window.frame
      f.origin.x = oldLeft
      f.origin.y = oldTop - f.height
      window.setFrameOrigin(f.origin)
    }
    if animate {
      NSAnimationContext.runAnimationGroup({ ctx in
        ctx.duration = 0.2
        window.animator().setContentSize(newSize)
        var f = window.frame
        f.origin.x = oldLeft
        f.origin.y = oldTop - f.height
        window.animator().setFrameOrigin(f.origin)
      }, completionHandler: nil)
    } else {
      apply()
    }
  }

  private static func moveWindowBy(controller: FlutterViewController, dx: Double, dy: Double) {
    guard let window = controller.view.window else { return }
    window.setFrameOrigin(NSPoint(
      x: window.frame.origin.x + CGFloat(dx),
      y: window.frame.origin.y - CGFloat(dy)
    ))
  }

  private static func beginWindowDrag(controller: FlutterViewController) {
    guard let window = controller.view.window else {
      windowDragSession = nil
      return
    }
    windowDragSession = WindowDragSession(
      mouseOrigin: NSEvent.mouseLocation,
      windowOrigin: window.frame.origin
    )
  }

  private static func updateWindowDrag(controller: FlutterViewController) {
    guard let window = controller.view.window,
          let session = windowDragSession else { return }
    window.setFrameOrigin(session.origin(for: NSEvent.mouseLocation))
  }

  private static func endWindowDrag() {
    windowDragSession = nil
  }

  private static func pickFolder() -> String? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.message = "选择采集内容的存储文件夹"
    panel.prompt = "选择此文件夹"
    let response = panel.runModal()
    guard response == .OK, let url = panel.url else { return nil }
    return url.path
  }
}
