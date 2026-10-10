//  Story 147 on the simulator: a launcher hidden through the home screen's cog stays hidden after a relaunch,
//  and a launcher moved there stays moved. Run: xcodebuild … -only-testing:GrabberNativeUITests/HomeSettingsUITests

import XCTest

final class HomeSettingsUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testAHiddenRowStaysHiddenAndAMovedRowStaysMovedAfterARelaunch() throws {
    let app = XCUIApplication()
    app.launch()
    openSheet(app)
    app.buttons["home-rows-reset"].tap()  // whatever an earlier run left
    app.buttons["home-settings-done"].tap()
    // Open it again at its top: a swipe down on a sheet closes it, so it is never scrolled back.
    let cog = app.buttons["home-settings"]
    XCTAssertTrue(cog.waitForExistence(timeout: 10), app.debugDescription)
    cog.tap()

    // Drag the Gym Timer above Call Larry by its reorder handle.
    let handle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder' AND label CONTAINS 'Gym Timer'"))
      .firstMatch
    XCTAssertTrue(handle.waitForExistence(timeout: 5), app.debugDescription)
    let callHandle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder' AND label CONTAINS 'Call Larry'"))
      .firstMatch
    // Slow, with a hold before letting go: a quick drag does not register on a loaded simulator.
    handle.press(forDuration: 1.0, thenDragTo: callHandle, withVelocity: .slow, thenHoldForDuration: 0.5)

    // Hide the Cockpit, further down the list than the screen reaches.
    let cockpit = app.switches["home-row-cockpit"]
    for _ in 0..<6 where !cockpit.isHittable { app.swipeUp() }
    XCTAssertTrue(cockpit.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertEqual(cockpit.value as? String, "1")
    cockpit.switches.firstMatch.tap()
    XCTAssertEqual(cockpit.value as? String, "0")

    app.buttons["home-settings-done"].tap()
    assertHome(app)

    app.terminate()
    app.launch()
    assertHome(app)

    // Put things back for the next run, and check Reset does it.
    openSheet(app)
    app.buttons["home-rows-reset"].tap()
    app.buttons["home-settings-done"].tap()
    XCTAssertTrue(app.buttons["home-cockpit"].waitForExistence(timeout: 5))
    XCTAssertTrue(before(app.buttons["home-call"], app.buttons["home-gym_timer"]), app.debugDescription)
  }

  private func openSheet(_ app: XCUIApplication) {
    let cog = app.buttons["home-settings"]
    XCTAssertTrue(cog.waitForExistence(timeout: 10), app.debugDescription)
    cog.tap()
    let reset = app.buttons["home-rows-reset"]
    XCTAssertTrue(app.navigationBars["Home screen"].waitForExistence(timeout: 5), app.debugDescription)
    // Reset is under the launchers, below the fold once the list outgrows the screen.
    for _ in 0..<6 where !reset.isHittable { app.swipeUp() }
    XCTAssertTrue(reset.waitForExistence(timeout: 5), app.debugDescription)
  }

  /// The Cockpit gone, the Gym Timer first.
  private func assertHome(_ app: XCUIApplication) {
    let gym = app.buttons["home-gym_timer"]
    XCTAssertTrue(gym.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertFalse(app.buttons["home-cockpit"].exists)
    let call = app.buttons["home-call"]
    XCTAssertTrue(before(gym, call), "gym \(gym.frame) call \(call.frame)")
  }

  /// Reading order on the home screen (story 151): higher up, or the same row of tiles and further left.
  private func before(_ a: XCUIElement, _ b: XCUIElement) -> Bool {
    let (fa, fb) = (a.frame, b.frame)
    if abs(fa.minY - fb.minY) < 2 { return fa.minX < fb.minX }
    return fa.minY < fb.minY
  }
}
