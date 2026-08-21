import Cocoa
import FlutterMacOS

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
    // 初始尺寸：一个小胶囊按钮。
    let size = NSSize(width: 120, height: 56)
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let origin = NSPoint(
      x: screenFrame.maxX - size.width - 24,
      y: screenFrame.maxY - size.height - 24
    )
    self.setFrame(NSRect(origin: origin, size: size), display: true)

    self.title = "Inbox"
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.styleMask.remove(.resizable)
    self.isMovableByWindowBackground = true
    self.isReleasedWhenClosed = false
    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    self.backgroundColor = .clear
    self.isOpaque = false
    self.hasShadow = true

    // 让 Flutter 视图透明，胶囊圆角外不显示方形底色；引导页自身绘制不透明背景。
    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.backgroundColor = NSColor.clear.cgColor

    // 不在 Dock 上显示独立任务图标，保持工具属性；通过 App 菜单可退出。
    // NSApp.setActivationPolicy(.accessory) 会同时隐藏 Dock 图标。
    NSApp.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)
  }
}
