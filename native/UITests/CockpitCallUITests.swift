//  Story 200: the Cockpit page's ☎ opens Grabber Native's own Call screen, with one call, not Context Grabber.

import XCTest

final class CockpitCallUITests: XCTestCase {
  func testPageCallButtonStaysInTheApp() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_COCKPIT"] = "open"
    app.launchEnvironment["GRABBER_COCKPIT_URL"] = "cockpit-bridge-test"
    app.launch()
    let phone = app.webViews.buttons["☎ Call"]
    XCTAssertTrue(phone.waitForExistence(timeout: 20), app.debugDescription)
    phone.tap()
    XCTAssertTrue(app.staticTexts["call-status"].waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertEqual(app.state, .runningForeground)
  }
}
