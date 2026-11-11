//  #236, #238: the daily strip under the Today card. Gym and Journal are checks; Balloons and Magic count, a tap for
//  one more and a press and hold for the counter's week (#342). The simulator's database keeps the values between
//  runs, so the test reads before it changes.

import XCTest

final class DailyStripUITests: XCTestCase {
  func testChecksAndCounters() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    let balloons =
      app.otherElements["strip-balloons"].exists
      ? app.otherElements["strip-balloons"] : app.descendants(matching: .any)["strip-balloons"]
    XCTAssertTrue(balloons.appears(within: 15), app.debugDescription)
    let call = app.buttons["home-call"]
    XCTAssertLessThan(balloons.frame.maxY, call.frame.minY, "above the tiles")
    XCTAssertLessThan(balloons.frame.height, 40, "one tight line")

    // At 0 the counter reads days since ("never", "3 days since"), not a number (story 251).
    let atZero = balloons.value as? String
    let start = Int(atZero ?? "") ?? 0
    balloons.tap()
    XCTAssertEqual(balloons.value as? String, "\(start + 1)", "a tap adds one")

    // #342, story 254: press and hold opens the week; − today and + yesterday stay in the sheet until Confirm.
    balloons.press(forDuration: 1.0)
    let todayCount = app.staticTexts["strip-week-count-0"]
    XCTAssertTrue(todayCount.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.staticTexts["strip-week-count-6"].exists, "seven days")
    XCTAssertEqual(todayCount.label, "\(start + 1)")
    let yesterday = app.staticTexts["strip-week-count-1"]
    let yesterdayBefore = Int(yesterday.label) ?? 0
    app.buttons["strip-week-minus-0"].tap()
    app.buttons["strip-week-plus-1"].tap()
    XCTAssertEqual(todayCount.label, "\(start)")
    XCTAssertEqual(yesterday.label, "\(yesterdayBefore + 1)")
    XCTAssertEqual(balloons.value as? String, "\(start + 1)", "nothing saved before Confirm")
    app.buttons["strip-week-confirm"].tap()
    XCTAssertTrue(todayCount.waitForNonExistence(timeout: 5))
    if start > 0 {
      XCTAssertEqual(balloons.value as? String, "\(start)", "today's − saved")
    } else {
      XCTAssertEqual(balloons.value as? String, "1 day since", "back to 0, read as days since yesterday's +")
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

  /// #414, story 255: staging, Cancel, save and taking yesterday back, with today's mark untouched.
  func testPressAndHoldEditsTwoWeeks() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    let journal = app.buttons["strip-journal"]
    XCTAssertTrue(journal.appears(within: 15), app.debugDescription)
    journal.press(forDuration: 1.0)
    let yesterday = app.buttons["strip-day-1"]
    XCTAssertTrue(yesterday.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.buttons["strip-day-13"].exists)
    XCTAssertTrue(app.buttons["strip-day-0"].exists)
    let initial = yesterday.isSelected
    let todayDone = app.buttons["strip-day-0"].isSelected
    yesterday.tap()
    XCTAssertEqual(yesterday.isSelected, !initial)
    XCTAssertTrue(app.staticTexts["strip-grid-summary"].label.contains("1 change to save"))
    app.buttons["strip-backdate-cancel"].tap()
    XCTAssertTrue(yesterday.waitForNonExistence(timeout: 5))
    journal.press(forDuration: 1.0)
    XCTAssertTrue(yesterday.appears(within: 5))
    XCTAssertEqual(yesterday.isSelected, initial, "Cancel discards edits")
    yesterday.tap()
    app.buttons["strip-grid-done"].tap()
    XCTAssertTrue(yesterday.waitForNonExistence(timeout: 5))
    journal.press(forDuration: 1.0)
    XCTAssertTrue(yesterday.appears(within: 5))
    XCTAssertEqual(yesterday.isSelected, !initial, "Done saved the toggle")
    XCTAssertEqual(app.buttons["strip-day-0"].isSelected, todayDone)
    yesterday.tap()
    app.buttons["strip-grid-done"].tap()
    XCTAssertTrue(yesterday.waitForNonExistence(timeout: 5))
    journal.press(forDuration: 1.0)
    XCTAssertTrue(yesterday.appears(within: 5))
    XCTAssertEqual(yesterday.isSelected, initial, "mark and unmark both persist")
    app.buttons["strip-backdate-cancel"].tap()
  }
}
