import AppKit

enum StatusMenuAction: Equatable {
  case showWindow
  case checkForUpdates
  case quit
}

final class StatusMenuDispatcher {
  private let onAction: (StatusMenuAction) -> Void

  init(onAction: @escaping (StatusMenuAction) -> Void) {
    self.onAction = onAction
  }

  func dispatch(_ action: StatusMenuAction) {
    onAction(action)
  }
}

final class StatusMenuController: NSObject {
  private let dispatcher: StatusMenuDispatcher
  private let statusItem: NSStatusItem

  init(onAction: @escaping (StatusMenuAction) -> Void) {
    self.dispatcher = StatusMenuDispatcher(onAction: onAction)
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    super.init()
    configureStatusItem()
  }

  private func configureStatusItem() {
    if let button = statusItem.button {
      let icon = (NSApp.applicationIconImage ?? NSImage()).copy() as? NSImage ?? NSImage()
      icon.size = NSSize(width: 18, height: 18)
      icon.isTemplate = true
      button.image = icon
      button.imagePosition = .imageOnly
      button.toolTip = "INbox"
    }

    let menu = NSMenu()
    menu.addItem(makeMenuItem(title: "显示 INbox", action: #selector(showWindow)))
    menu.addItem(makeMenuItem(title: "检查更新", action: #selector(checkForUpdates)))
    menu.addItem(makeMenuItem(title: "完全退出", action: #selector(quit)))
    statusItem.menu = menu
  }

  private func makeMenuItem(title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  @objc private func showWindow() {
    dispatcher.dispatch(.showWindow)
  }

  @objc private func checkForUpdates() {
    dispatcher.dispatch(.checkForUpdates)
  }

  @objc private func quit() {
    dispatcher.dispatch(.quit)
  }
}
