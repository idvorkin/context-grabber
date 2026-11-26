//  #236, #238: the daily strip under the Today card. Gym and Journal are checks; Balloons and Magic count, a tap for
//  one more and a press and hold for the counter's week (#342). The simulator's database keeps the values between
//  runs, so the test reads before it changes. The counters, the checks and the two-week sheet share one launch (story
//  757, #905).

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

    // #342, story 254: press and hold opens the week; − today stays in the sheet until Confirm. Another day's steps,
    // and that only changed days are saved, are `CounterWeekTests`, on the host (story 770).
    balloons.press(forDuration: 1.0)
    let todayCount = app.staticTexts["strip-week-count-0"]
    XCTAssertTrue(todayCount.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.staticTexts["strip-week-count-6"].exists, "seven days")
    XCTAssertEqual(todayCount.label, "\(start + 1)")
    // #1493, story 572: the week's graph above the rows, today last, following − before Confirm; all seven rows
    // still fit below it.
    let graph = app.descendants(matching: .any)["strip-week-graph"]
    XCTAssertTrue(graph.exists, app.debugDescription)
    XCTAssertLessThan(graph.frame.maxY, todayCount.frame.minY, "above the rows")
    XCTAssertLessThan(app.staticTexts["strip-week-count-6"].frame.maxY, app.windows.firstMatch.frame.maxY, "all fit")
    let todayBar = { (graph.value as? String)?.split(separator: ",").last.map(String.init) ?? "" }
    XCTAssertTrue(todayBar().hasSuffix(" \(start + 1)"), "today's bar: \(graph.value ?? "nil")")
    app.buttons["strip-week-minus-0"].tap()
    XCTAssertEqual(todayCount.label, "\(start)")
    XCTAssertTrue(todayBar().hasSuffix(" \(start)"), "the bar follows − at once: \(graph.value ?? "nil")")
    XCTAssertEqual(balloons.value as? String, "\(start + 1)", "nothing saved before Confirm")
    app.buttons["strip-week-confirm"].tap()
    XCTAssertTrue(todayCount.waitForNonExistence(timeout: 5))
    if start > 0 {
      XCTAssertEqual(balloons.value as? String, "\(start)", "today's − saved")
    } else {
      XCTAssertNil(Int(balloons.value as? String ?? ""), "back to 0, read as days since, not a number")
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

    // #414, story 255: one round of a check's two weeks: a staged change says so, Done saves it and leaves today's mark
    // alone, then it's taken back so the next run finds the day as it was. Staging, Cancel and an unmark being saved are
    // `CheckFortnightTests`, on the host (story 770).
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
    app.buttons["strip-grid-done"].tap()
    XCTAssertTrue(yesterday.waitForNonExistence(timeout: 5))
    journal.press(forDuration: 1.0)
    XCTAssertTrue(yesterday.appears(within: 5))
    XCTAssertEqual(yesterday.isSelected, !initial, "Done saved the toggle")
    XCTAssertEqual(app.buttons["strip-day-0"].isSelected, todayDone)
    yesterday.tap()
    app.buttons["strip-grid-done"].tap()
    XCTAssertTrue(yesterday.waitForNonExistence(timeout: 5))
  }

  /// #1503, story 570: a Gym Timer workout finished today puts a stopwatch under today's tile in Gym's two weeks,
  /// which open at full height with taller tiles. Health's workout kinds, their order and "+N" are `GymDayMarksTests`,
  /// on the host (the simulator's UI tests ask Health nothing, story 1630).
  func testGymsTwoWeeksShowWhatWasDone() throws {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_TIMER"] = "1,0,1"  // one round of a second: a finished workout in a few seconds
    app.launch()
    let stop = app.buttons["STOP"]
    XCTAssertTrue(stop.appears(within: 15), "the hook starts the workout: \(app.debugDescription)")
    XCTAssertTrue(stop.waitForNonExistence(timeout: 30), "and it finishes")
    app.buttons["Done"].firstMatch.tap()

    let gym = app.buttons["strip-gym"]
    XCTAssertTrue(gym.appears(within: 10), app.debugDescription)
    gym.press(forDuration: 1.0)
    let today = app.buttons["strip-day-0"]
    XCTAssertTrue(today.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.descendants(matching: .any)["strip-day-marks-0"].exists, "today's tile shows what was done")
    XCTAssertTrue(today.label.contains("Gym Timer"), "and says it: \(today.label)")
    XCTAssertGreaterThanOrEqual(today.frame.height, 80, "taller tiles")
    let window = app.windows.firstMatch.frame
    XCTAssertLessThan(app.buttons["strip-day-13"].frame.minY, window.minY + window.height * 0.45, "full height")
    if let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] {
      try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/gym-two-weeks.png"))
    }
    app.buttons["strip-backdate-cancel"].tap()
    XCTAssertTrue(today.waitForNonExistence(timeout: 5))
  }
}
