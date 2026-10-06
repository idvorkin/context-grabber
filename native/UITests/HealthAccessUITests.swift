//  The simulator's one HealthKit check (docs/TESTING.md): launch with GRABBER_MIRROR=healthkit, grant Health's
//  access sheet (simctl cannot tap it), and wait for the app to save the fixture week, grab it back and export.
//  sim-smoke.sh then compares the exports with the TypeScript app's on the same fixture.

import XCTest

final class HealthAccessUITests: XCTestCase {
  func testGrantHealthAccessAndGrabTheFixtureWeek() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_MIRROR"] = "healthkit"
    app.launch()
    let done = app.staticTexts["hook-done"]
    // The sheet's "Select All N Topics" row: the cell carries the identifier, its text carries the label.
    let selectAll = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Select All'")).firstMatch
    let allow = app.buttons["UIA.Health.Allow.Button"]
    for _ in 0..<6 {
      if done.exists { break }
      if selectAll.waitForExistence(timeout: 20), selectAll.isHittable { selectAll.tap() }
      for _ in 0..<4 { app.swipeUp(velocity: .fast) }
      if allow.waitForExistence(timeout: 5) {
        var swipes = 0
        while !allow.isHittable, swipes < 20 {
          app.swipeUp(velocity: .fast)
          swipes += 1
        }
        sleep(1)
        if allow.isHittable { allow.tap() }
        sleep(2)
      }
      // iOS 27 adds a second page: how much history to share. All of it (the fixture week is in the past), then Allow.
      let allHistory = app.staticTexts["All Recorded Data and Future Data"]
      let finalAllow = app.buttons.matching(NSPredicate(format: "label == 'Allow'")).firstMatch
      if allHistory.waitForExistence(timeout: 5) {
        allHistory.tap()
        if finalAllow.waitForExistence(timeout: 5), finalAllow.isEnabled { finalAllow.tap() }
      }
      sleep(2)
    }
    XCTAssertTrue(done.waitForExistence(timeout: 180), app.debugDescription)
  }
}
