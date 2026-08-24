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
}
