import Cocoa
import FlutterMacOS

struct WindowDragSession {
  let mouseOrigin: NSPoint
  let windowOrigin: NSPoint

  func origin(for mouse: NSPoint) -> NSPoint {
    NSPoint(
      x: windowOrigin.x + mouse.x - mouseOrigin.x,
      y: windowOrigin.y + mouse.y - mouseOrigin.y
    )
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    configureFloatingWindow(flutterViewController: flutterViewController)
    ClipboardChannel.register(with: flutterViewController)
    SettingsChannel.register(with: flutterViewController)

    super.awakeFromNib()
  }

  /// V0.1：一个轻量、可拖拽、置顶的悬浮入口（见《方案》第十一节）。
  private func configureFloatingWindow(flutterViewController: FlutterViewController) {
    // 先配置窗口样式：fullSizeContentView 让 contentView 延伸到标题栏区域，
    // 这样 setContentSize 设置的尺寸与 Flutter 视图尺寸一致，不会被标题栏吃掉。
    self.title = "INbox"
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.styleMask.remove(.resizable)
    self.isMovableByWindowBackground = false
    self.isReleasedWhenClosed = false
    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    self.backgroundColor = .clear
    self.isOpaque = false
    self.hasShadow = true

    // 让 Flutter 视图透明，胶囊圆角外不显示方形底色；引导页自身绘制不透明背景。
    flutterViewController.backgroundColor = .clear

    // 初始内容尺寸必须在 Flutter 首帧前与将呈现的视图匹配：
    // 未配置有效 Vault → 引导页 420x300；否则胶囊 132x132。
    // 用 setContentSize 而非 setFrame，保证 Flutter 视图拿到的就是这个尺寸。
    let size = initialWindowSize()
    self.setContentSize(size)

    // 右上角定位（锚定窗口顶边，Y 坐标按窗口外框计算）。
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    var frame = self.frame
    frame.origin.x = screenFrame.maxX - frame.width - 24
    frame.origin.y = screenFrame.maxY - frame.height - 24
    self.setFrameOrigin(frame.origin)

    // 即时布局，确保 Flutter 首帧拿到正确尺寸。
    self.layoutIfNeeded()

    // 不在 Dock 显示图标，保持菜单栏工具属性。
    NSApp.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// 决定启动时窗口尺寸：与 Dart 端 WindowSizes 保持一致。
  /// 未配置 Vault / 已保存的 Vault 目录已失效 → 引导页尺寸；否则胶囊尺寸。
  /// 与 Dart 的 SettingsService.loadValidVaultPath 使用同一判定，避免两端不一致。
  private func initialWindowSize() -> NSSize {
    if let path = UserDefaults.standard.string(forKey: "vaultPath"),
       !path.trimmingCharacters(in: .whitespaces).isEmpty {
      var isDir: ObjCBool = false
      if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
        return NSSize(width: 132, height: 132)
      }
    }
    return NSSize(width: 420, height: 300)
  }
}
