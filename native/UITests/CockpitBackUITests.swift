//  #234: a page the Cockpit opens in place can be backed out of. Back appears once there is a page to go back to and
//  takes one step; Cockpit goes straight to the start page from any depth; Done is no longer drawn as back.

import XCTest

final class CockpitBackUITests: XCTestCase {
  func testBackAndCockpitLeaveAPageTheDashboardOpened() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_COCKPIT_URL"] = "cockpit-bridge-test"
    app.launch()
    let row = app.buttons["home-cockpit"]
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    row.tap()

    let away = app.links["Open another page"]
    XCTAssertTrue(away.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertFalse(app.buttons["cockpit-back"].exists, "no Back on the start page")
    away.tap()
    let back = app.buttons["cockpit-back"]
    XCTAssertTrue(back.waitForExistence(timeout: 10), "Back appears on the page the Cockpit opened")
    XCTAssertTrue(app.buttons["cockpit-home"].exists)
    shot(app, "cockpit-away")

    back.tap()
    XCTAssertTrue(away.waitForExistence(timeout: 10), "Back returns to the dashboard")
    XCTAssertTrue(app.buttons["cockpit-back"].waitForNonExistence(timeout: 5), "and Back goes")

    // Two pages deep, then Cockpit: the start page in one tap.
    away.tap()
    let deeper = app.links["One page deeper"]
    XCTAssertTrue(deeper.waitForExistence(timeout: 10))
    deeper.tap()
    sleep(1)
    app.buttons["cockpit-home"].tap()
    XCTAssertTrue(away.waitForExistence(timeout: 10), "Cockpit returns to the start page")

    app.buttons["cockpit-done"].tap()
    XCTAssertTrue(row.waitForExistence(timeout: 5), "Done leaves the Cockpit")
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
  }
}
