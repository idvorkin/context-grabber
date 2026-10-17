//  #236, #238: the daily strip under the Today card. Gym and Journal are checks; Balloons and Magic count, a tap for
//  one more and a long press for one fewer. The simulator's database keeps today's values between runs, so the test
//  reads before it changes.

import XCTest

final class DailyStripUITests: XCTestCase {
  func testChecksAndCounters() throws {
    let app = XCUIApplication()
    app.launch()
    let balloons =
      app.otherElements["strip-balloons"].exists
      ? app.otherElements["strip-balloons"] : app.descendants(matching: .any)["strip-balloons"]
    XCTAssertTrue(balloons.waitForExistence(timeout: 15), app.debugDescription)
    let call = app.buttons["home-call"]
    XCTAssertLessThan(balloons.frame.maxY, call.frame.minY, "above the tiles")
    XCTAssertLessThan(balloons.frame.height, 40, "one tight line")

    // At 0 the counter reads days since ("never", "3 days since"), not a number (story 251).
    let atZero = balloons.value as? String
    let start = Int(atZero ?? "") ?? 0
    balloons.tap()
    XCTAssertEqual(balloons.value as? String, "\(start + 1)", "a tap adds one")
    balloons.press(forDuration: 1.0)
    if start > 0 {
      XCTAssertEqual(balloons.value as? String, "\(start)", "a long press takes one off")
    } else {
      XCTAssertEqual(balloons.value as? String, atZero, "a long press takes it back to 0, read as days since")
    }

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
    // #257: meditation sits on the same line; green on its own after breathing or Health, else a tap's check.
    let meditation = app.buttons["strip-meditation"]
    XCTAssertTrue(meditation.exists, app.debugDescription)
    XCTAssertEqual(meditation.frame.midY, journal.frame.midY, accuracy: 2, "one line")
    XCTAssertNotNil(meditation.value as? String)
  }

  /// #290: press and hold a check, the sheet starts on yesterday, Confirm marks it and closes; today is untouched.
  func testPressAndHoldMarksYesterday() throws {
    let app = XCUIApplication()
    app.launch()
    let journal = app.buttons["strip-journal"]
    XCTAssertTrue(journal.waitForExistence(timeout: 15), app.debugDescription)
    let today = journal.value as? String
    journal.press(forDuration: 1.0)
    let day = app.staticTexts["strip-backdate-day"]
    XCTAssertTrue(day.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertTrue(day.label.hasPrefix("yesterday"), day.label)
    app.buttons["strip-backdate-confirm"].tap()
    XCTAssertTrue(day.waitForNonExistence(timeout: 5), "one and done")
    XCTAssertEqual(journal.value as? String, today, "yesterday marked, today as it was")
  }
}
