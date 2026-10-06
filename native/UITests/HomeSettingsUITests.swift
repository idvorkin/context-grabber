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

    // Hide the Cockpit.
    let cockpit = app.switches["home-row-cockpit"]
    XCTAssertTrue(cockpit.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertEqual(cockpit.value as? String, "1")
    cockpit.switches.firstMatch.tap()
    XCTAssertEqual(cockpit.value as? String, "0")

    // Drag the Gym Timer above Call Larry by its reorder handle.
    let handle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder' AND label CONTAINS 'Gym Timer'"))
      .firstMatch
    XCTAssertTrue(handle.waitForExistence(timeout: 5), app.debugDescription)
    let callHandle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder' AND label CONTAINS 'Call Larry'"))
      .firstMatch
    handle.press(forDuration: 0.5, thenDragTo: callHandle)

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
    XCTAssertLessThan(app.buttons["home-call"].frame.minY, app.buttons["home-gym_timer"].frame.minY)
  }

  private func openSheet(_ app: XCUIApplication) {
    let cog = app.buttons["home-settings"]
    XCTAssertTrue(cog.waitForExistence(timeout: 10), app.debugDescription)
    cog.tap()
    XCTAssertTrue(app.buttons["home-rows-reset"].waitForExistence(timeout: 5), app.debugDescription)
  }

  /// The Cockpit gone, the Gym Timer first.
  private func assertHome(_ app: XCUIApplication) {
    let gym = app.buttons["home-gym_timer"]
    XCTAssertTrue(gym.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertFalse(app.buttons["home-cockpit"].exists)
    XCTAssertLessThan(gym.frame.minY, app.buttons["home-call"].frame.minY, app.debugDescription)
  }
}
