import Cocoa
import FlutterMacOS

enum CaptureFeedbackStatus: Equatable {
  case idle
  case success
  case failure

  init?(nativeValue: String) {
    switch nativeValue {
    case "idle": self = .idle
    case "success": self = .success
    case "failure": self = .failure
    default: return nil
    }
  }

  var color: NSColor {
    switch self {
    case .idle: return .black
    case .success: return .systemGreen
    case .failure: return .systemRed
    }
  }
}

extension Notification.Name {
  static let assistantVisibilityDidChange = Notification.Name(
    "com.inbox.app.assistantVisibilityDidChange"
  )
}

final class AssistantVisibilityStore {
  private static let key = "assistantVisible"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var isVisible: Bool {
    guard defaults.object(forKey: Self.key) != nil else { return true }
    return defaults.bool(forKey: Self.key)
  }

  func setVisible(_ visible: Bool) {
    defaults.set(visible, forKey: Self.key)
    NotificationCenter.default.post(name: .assistantVisibilityDidChange, object: self)
  }
}

/// Stable INbox Core entry. It triggers Dart capture and renders feedback only.
final class MenuBarController: NSObject {
  static let channelName = "com.inbox.app/core"

  private let statusItem: NSStatusItem
  private let channel: FlutterMethodChannel
  private let menu = NSMenu()
  private let visibilityStore: AssistantVisibilityStore
  private weak var window: MainFlutterWindow?
  private var assistantMenuItem: NSMenuItem!
  private var visibilityObserver: NSObjectProtocol?
  private var fallbackIdleTimer: Timer?

  init(
    controller: FlutterViewController,
    window: MainFlutterWindow,
    visibilityStore: AssistantVisibilityStore
  ) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    self.window = window
    self.visibilityStore = visibilityStore
    super.init()

    configureStatusItem()
    configureMenu()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    visibilityObserver = NotificationCenter.default.addObserver(
      forName: .assistantVisibilityDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.updateAssistantMenuState()
    }
  }

  deinit {
    fallbackIdleTimer?.invalidate()
    if let visibilityObserver {
      NotificationCenter.default.removeObserver(visibilityObserver)
    }
    NSStatusBar.system.removeStatusItem(statusItem)
  }

  private func configureStatusItem() {
    guard let button = statusItem.button else { return }
    button.image = Self.circleImage(color: CaptureFeedbackStatus.idle.color)
    button.imagePosition = .imageOnly
    button.toolTip = "INbox Capture（右键打开菜单）"
    button.target = self
    button.action = #selector(statusItemClicked(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    button.setAccessibilityLabel("INbox Capture")
  }

  private func configureMenu() {
    let header = NSMenuItem(title: "INbox", action: nil, keyEquivalent: "")
    header.isEnabled = false
    menu.addItem(header)
    menu.addItem(item("Capture", action: #selector(captureFromMenu)))
    menu.addItem(.separator())
    menu.addItem(item("Inbox", action: #selector(openInbox)))
    menu.addItem(item("History", action: #selector(openHistory)))
    menu.addItem(.separator())

    let assistants = NSMenuItem(title: "Assistants", action: nil, keyEquivalent: "")
    let assistantsMenu = NSMenu(title: "Assistants")
    assistantMenuItem = item(
      "Floating Assistant",
      action: #selector(toggleAssistant)
    )
    assistantsMenu.addItem(assistantMenuItem)
    assistants.submenu = assistantsMenu
    menu.addItem(assistants)
    menu.addItem(item("Settings", action: #selector(openSettings)))
    menu.addItem(.separator())
    menu.addItem(item("Quit INbox", action: #selector(quit)))
    updateAssistantMenuState()
  }

  private func item(_ title: String, action: Selector) -> NSMenuItem {
    let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
    menuItem.target = self
    return menuItem
  }

  @objc private func statusItemClicked(_ sender: Any?) {
    if NSApp.currentEvent?.type == .rightMouseUp {
      statusItem.menu = menu
      statusItem.button?.performClick(nil)
      statusItem.menu = nil
    } else {
      requestCapture()
    }
  }

  @objc private func captureFromMenu() { requestCapture() }
  @objc private func openInbox() { invoke("openInbox") }
  @objc private func openHistory() { invoke("openHistory") }
  @objc private func openSettings() { invoke("openSettings") }

  @objc private func toggleAssistant() {
    window?.setAssistantVisible(!visibilityStore.isVisible)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func requestCapture() {
    channel.invokeMethod("capture", arguments: nil) { [weak self] response in
      if response is FlutterError || FlutterMethodNotImplemented.isEqual(response) {
        self?.showFallbackFailure()
      }
    }
  }

  private func invoke(_ method: String) {
    channel.invokeMethod(method, arguments: nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setCaptureStatus",
          let arguments = call.arguments as? [String: Any],
          let value = arguments["status"] as? String,
          let status = CaptureFeedbackStatus(nativeValue: value) else {
      result(FlutterMethodNotImplemented)
      return
    }
    setStatus(status)
    result(nil)
  }

  private func setStatus(_ status: CaptureFeedbackStatus) {
    statusItem.button?.image = Self.circleImage(color: status.color)
  }

  private func showFallbackFailure() {
    fallbackIdleTimer?.invalidate()
    setStatus(.failure)
    fallbackIdleTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: false) {
      [weak self] _ in
      self?.setStatus(.idle)
    }
  }

  private func updateAssistantMenuState() {
    assistantMenuItem?.state = visibilityStore.isVisible ? .on : .off
  }

  private static func circleImage(color: NSColor) -> NSImage {
    let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) {
      rect in
      color.setFill()
      NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
      return true
    }
    image.isTemplate = false
    return image
  }
}
