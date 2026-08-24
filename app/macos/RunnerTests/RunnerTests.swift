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
}
