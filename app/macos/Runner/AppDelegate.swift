import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var statusMenuController: StatusMenuController?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    statusMenuController = StatusMenuController { [weak self] action in
      self?.handleStatusMenuAction(action)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // 悬浮入口关闭不应直接退出应用；通过菜单或退出按钮结束。
    return false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      mainFlutterWindow?.makeKeyAndOrderFront(nil)
    }
    sender.activate(ignoringOtherApps: true)
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func handleStatusMenuAction(_ action: StatusMenuAction) {
    switch action {
    case .showWindow:
      mainFlutterWindow?.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    case .checkForUpdates:
      sendCommand("checkForUpdates")
      mainFlutterWindow?.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    case .quit:
      NSApp.terminate(nil)
    }
  }

  private func sendCommand(_ method: String) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(
      name: "com.inbox.app/commands",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.invokeMethod(method, arguments: nil)
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
  private static var windowDragSession: WindowDragSession?

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.engine.binaryMessenger)
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
      case "pickFolder":
        result(pickFolder())
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
        result(FlutterError(code: "NOT_IMPLEMENTED", message: "DMG 安装将在后续任务接入", details: nil))
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
    // setContentSize 直接设置内容区尺寸，Flutter 视图与之一致，不会被标题栏吃掉高度。
    // 同时保持窗口顶边（左上角）位置不变。
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
    panel.message = "选择你的 Obsidian Vault 文件夹"
    panel.prompt = "选择此文件夹"
    let response = panel.runModal()
    guard response == .OK, let url = panel.url else { return nil }
    return url.path
  }
}
