//  Story 136 (#168): the app loads a usage reading, and the live tile on the home screen draws it. The test adds
//  the tile through SpringBoard's own widget gallery, as Igor would, and keeps a screenshot of the home screen.

import XCTest

final class UsageTileUITests: XCTestCase {
  private func shot(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  func testTheTileOnTheHomeScreenDrawsTheReading() throws {
    let app = XCUIApplication()
    app.launch()
    // The strip is drawn once a reading loaded; that load is what writes the tile's reading.
    XCTAssertTrue(app.buttons["usage-strip"].waitForExistence(timeout: 30), "the Cockpit is reachable from this Mac")

    XCUIDevice.shared.press(.home)
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    // The tile's buttons are in SpringBoard's tree; a simulator that has the tile already skips the gallery.
    let gymTimer = springboard.buttons["Gym Timer"]
    if !gymTimer.waitForExistence(timeout: 3) { addTheMediumTile(springboard) }
    XCTAssertTrue(gymTimer.waitForExistence(timeout: 10), springboard.debugDescription)
    XCTAssertTrue(springboard.staticTexts["Week 99% left"].exists || springboard.staticTexts.matching(
      NSPredicate(format: "label BEGINSWITH 'Week ' AND label ENDSWITH ' left'")).firstMatch.exists, "the tile draws the reading")
    shot(springboard, "home-screen")

    gymTimer.tap()
    XCTAssertTrue(app.buttons["STOP"].waitForExistence(timeout: 15), "Gym Timer on the tile starts the last preset")
    shot(app, "timer-from-tile")
  }

  /// Through SpringBoard's own gallery: long press, Edit, Add Widget, search, the medium size, Add Widget.
  private func addTheMediumTile(_ springboard: XCUIApplication) {
    springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 1.5)
    let edit = springboard.buttons["Edit"]
    if edit.waitForExistence(timeout: 5) { edit.tap() }
    let addWidget = springboard.buttons["Add Widget"]
    XCTAssertTrue(addWidget.waitForExistence(timeout: 5), springboard.debugDescription)
    addWidget.tap()
    let search = springboard.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5), springboard.debugDescription)
    search.tap()
    search.typeText("Grabber")
    let result = springboard.cells.containing(.staticText, identifier: "Grabber Native").firstMatch
    XCTAssertTrue(result.waitForExistence(timeout: 5), springboard.debugDescription)
    result.tap()
    shot(springboard, "gallery-small")
    // The label carries a leading symbol (" Add Widget").
    let add = springboard.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Widget'")).firstMatch
    XCTAssertTrue(add.waitForExistence(timeout: 5), springboard.debugDescription)
    springboard.swipeLeft()  // the gallery opens on the small size
    sleep(1)
    shot(springboard, "gallery-medium")
    add.tap()
    sleep(2)
    let done = springboard.buttons["Done"]
    if done.waitForExistence(timeout: 3) { done.tap() }
    sleep(2)
  }
}
