//  #236, #238: the daily strip under the Today card. Gym and Journal are checks; Balloons and Magic count, a tap for
//  one more and a long press for one fewer. The simulator's database keeps today's values between runs, so the test
//  reads before it changes.

import XCTest

final class DailyStripUITests: XCTestCase {
  func testChecksAndCounters() throws {
    let app = XCUIApplication()
    app.launch()
    let balloons = app.otherElements["strip-balloons"].exists ? app.otherElements["strip-balloons"] : app.descendants(matching: .any)["strip-balloons"]
    XCTAssertTrue(balloons.waitForExistence(timeout: 15), app.debugDescription)
    let call = app.buttons["home-call"]
    XCTAssertLessThan(balloons.frame.maxY, call.frame.minY, "above the tiles")
    XCTAssertLessThan(balloons.frame.height, 40, "one tight line")

    let start = Int(balloons.value as? String ?? "") ?? -1
    balloons.tap()
    XCTAssertEqual(balloons.value as? String, "\(start + 1)", "a tap adds one")
    balloons.press(forDuration: 1.0)
    XCTAssertEqual(balloons.value as? String, "\(start)", "a long press takes one off")

    let journal = app.buttons["strip-journal"]
    let before = journal.value as? String
    journal.tap()
    XCTAssertNotEqual(journal.value as? String, before, "a tap flips the check")
    if let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] {
      try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/daily-strip.png"))
    }
    journal.tap()
    XCTAssertEqual(journal.value as? String, before, "and back")
    XCTAssertNotNil(app.buttons["strip-gym"].value as? String)
  }
}
