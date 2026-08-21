import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // 悬浮入口关闭不应直接退出应用；通过菜单或退出按钮结束。
    return false
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

    // 3) 图片：先尝试按原始类型取字节，保留 PNG/JPEG/GIF 等；
    //    只有拿不到原始格式时才回退为 PNG（见《方案》第六、七节）。
    if let (bytes, ext, mime) = readImage(from: pb) {
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
      case "pickFolder":
        result(pickFolder())
      case "setWindowSize":
        guard let args = call.arguments as? [String: Any],
              let w = args["width"] as? Double,
              let h = args["height"] as? Double else {
          result(FlutterError(code: "BAD_ARGS", message: "setWindowSize 需要 width/height", details: nil)); return
        }
        setWindowSize(controller: controller, width: w, height: h)
        result(nil)
      case "quit":
        NSApp.terminate(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func setWindowSize(controller: FlutterViewController, width: Double, height: Double) {
    guard let window = controller.view.window else { return }
    let newSize = NSSize(width: width, height: height)
    var frame = window.frame
    // 保持窗口左上角位置不变，只调整宽高（macOS 坐标原点在左下角）。
    frame.origin.y += frame.size.height - CGFloat(height)
    frame.size = newSize
    window.animator().setFrame(frame, display: true)
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
