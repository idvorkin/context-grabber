//  #234: a page the Cockpit opens in place can be backed out of: Back takes one real step, Cockpit goes straight to the
//  start page from two deep, Done leaves. Which buttons show when, and that the panel never outlives a failed page,
//  are CockpitPageStateTests on the host; this keeps only what needs WebKit's own back list.

import XCTest

final class CockpitBackUITests: XCTestCase {
  func testBackAndCockpitLeaveAPageTheDashboardOpened() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_COCKPIT_URL"] = "cockpit-bridge-test"
    app.launch()
    let row = app.buttons["home-cockpit"]
    XCTAssertTrue(row.appears(within: 15), app.debugDescription)
    row.tap()

    let away = app.links["Open another page"]
    XCTAssertTrue(away.appears(within: 15), app.debugDescription)
    away.tap()
    let back = app.buttons["cockpit-back"]
    XCTAssertTrue(back.appears(within: 10), app.debugDescription)

    back.tap()
    XCTAssertTrue(away.appears(within: 10), "Back returns to the dashboard")

    // Two pages deep, then Cockpit: the start page in one tap.
    away.tap()
    let deeper = app.links["One page deeper"]
    XCTAssertTrue(deeper.appears(within: 10))
    deeper.tap()
    sleep(1)
    app.buttons["cockpit-home"].tap()
    XCTAssertTrue(away.appears(within: 10), "Cockpit returns to the start page")

    app.buttons["cockpit-done"].tap()
    XCTAssertTrue(row.appears(within: 5), "Done leaves the Cockpit")
  }
}
