//  Story 148: What's new stays on the home screen when opened, leaves on its ✕, stays gone after a relaunch, and
//  lives in the cog.

import XCTest

final class WhatsNewSeenUITests: XCTestCase {
  func testHomeRowGoesOnItsXAndStaysInTheCog() throws {
    let app = XCUIApplication()
    app.launch()
    let row = app.buttons["whats-new-row"]
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    row.tap()
    XCTAssertTrue(app.otherElements["whats-new"].waitForExistence(timeout: 5) || app.tables["whats-new"].exists
      || app.collectionViews["whats-new"].exists, app.debugDescription)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let cog = app.buttons["home-settings"]
    XCTAssertTrue(cog.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertTrue(row.waitForExistence(timeout: 5), "opening keeps the row")
    app.buttons["whats-new-dismiss"].tap()
    let gone = NSPredicate(format: "exists == false")
    expectation(for: gone, evaluatedWith: row)
    waitForExpectations(timeout: 5)

    app.terminate()
    app.launch()
    XCTAssertTrue(cog.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertFalse(app.buttons["whats-new-row"].exists, "a relaunch should not bring it back")

    cog.tap()
    let inCog = app.buttons["home-settings-whats-new"]
    for _ in 0..<5 where !inCog.isHittable { app.swipeUp() }
    XCTAssertTrue(inCog.waitForExistence(timeout: 5), app.debugDescription)
    inCog.tap()
    XCTAssertTrue(app.navigationBars["What's new"].waitForExistence(timeout: 5), app.debugDescription)
  }
}
