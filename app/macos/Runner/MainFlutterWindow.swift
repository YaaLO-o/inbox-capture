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

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  let assistantVisibilityStore = AssistantVisibilityStore()
  /// 持住 Flutter 视图控制器，切换窗口样式时需要同步其背景色。
  private weak var flutterViewController: FlutterViewController?

  /// 当前是否为标准窗口模式（控制中心 / 阅读器 / 从控制中心进入的更新页）。
  private(set) var isStandardMode = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.flutterViewController = flutterViewController
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.delegate = self
    applyFloatingWindowStyle(initialSize: initialWindowSize())
    ClipboardChannel.register(with: flutterViewController)
    SettingsChannel.register(with: flutterViewController)

    super.awakeFromNib()

    if initialWindowSize() == NSSize(width: 132, height: 132) {
      DispatchQueue.main.async { [weak self] in
        self?.restoreAssistantVisibility()
      }
    }
  }

  // MARK: - 窗口样式切换

  /// 切换到标准 macOS 窗口：有标题栏和红叉、普通层级、居中。
  /// 内容尺寸由 Dart 侧在调用前通过 setWindowSize 设定。
  func applyStandardWindowStyle() {
    isStandardMode = true

    styleMask.remove(.fullSizeContentView)
    styleMask.insert([.titled, .closable])
    styleMask.remove(.resizable)
    isMovableByWindowBackground = false
    isReleasedWhenClosed = false

    titleVisibility = .visible
    titlebarAppearsTransparent = false
    title = "INbox"

    level = .normal
    collectionBehavior = []

    isOpaque = true
    backgroundColor = .windowBackgroundColor
    hasShadow = true
    flutterViewController?.backgroundColor = .windowBackgroundColor

    layoutIfNeeded()
    center()
    makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// 切回悬浮入口样式：无标题栏、置顶透明、右上角 132×132。
  func applyFloatingWindowStyle() {
    applyFloatingWindowStyle(initialSize: NSSize(width: 132, height: 132))
  }

  /// Floating Assistant visibility is independent from Core process lifetime.
  func setAssistantVisible(_ visible: Bool) {
    assistantVisibilityStore.setVisible(visible)
    guard !isStandardMode else { return }
    if visible {
      makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    } else {
      orderOut(nil)
    }
  }

  func restoreAssistantVisibility() {
    guard !isStandardMode else { return }
    if assistantVisibilityStore.isVisible {
      makeKeyAndOrderFront(nil)
    } else {
      orderOut(nil)
    }
  }

  /// 悬浮样式：启动时按是否已配置 Vault 决定初始尺寸，运行时回退固定 132²。
  private func applyFloatingWindowStyle(initialSize: NSSize) {
    isStandardMode = false

    // 先配置窗口样式：fullSizeContentView 让 contentView 延伸到标题栏区域，
    // 这样 setContentSize 设置的尺寸与 Flutter 视图尺寸一致，不会被标题栏吃掉。
    title = "INbox"
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    styleMask.insert([.titled, .closable]) // nib 原始样式，fullSizeContentView 下不可见
    styleMask.remove(.resizable)
    isMovableByWindowBackground = false
    isReleasedWhenClosed = false
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true

    // 让 Flutter 视图透明，胶囊圆角外不显示方形底色；引导页自身绘制不透明背景。
    flutterViewController?.backgroundColor = .clear

    setContentSize(initialSize)

    // 右上角定位（锚定窗口顶边，Y 坐标按窗口外框计算）。
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    var frame = self.frame
    frame.origin.x = screenFrame.maxX - frame.width - 24
    frame.origin.y = screenFrame.maxY - frame.height - 24
    setFrameOrigin(frame.origin)

    // 即时布局，确保 Flutter 首帧拿到正确尺寸。
    layoutIfNeeded()

    // 不在 Dock 显示图标，保持菜单栏工具属性。
    NSApp.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)
  }

  // MARK: - NSWindowDelegate

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    // 标准窗口（控制中心/阅读器）点红叉：不真正关闭，原地切回悬浮宠物，
    // 并通过 channel 通知 Dart 复位模式状态。
    if isStandardMode {
      applyFloatingWindowStyle()
      if let controller = flutterViewController {
        let channel = FlutterMethodChannel(
          name: SettingsChannel.channelName,
          binaryMessenger: controller.engine.binaryMessenger
        )
        channel.invokeMethod("mainWindowDidClose", arguments: nil)
      }
      restoreAssistantVisibility()
      return false
    }
    setAssistantVisible(false)
    return false
  }

  /// 决定启动时窗口尺寸：与 Dart 端 WindowSizes 保持一致。
  /// 未配置存储文件夹 / 已保存的目录已失效 → 引导页尺寸；否则胶囊尺寸。
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
