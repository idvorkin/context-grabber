//  Story 142, #182: a shake opens the report over a sheet that is already up, and again after Cancel.

import XCTest

final class ShakeOverSheetUITests: XCTestCase {
  func testReportOpensOverTheCogSheetTwice() throws {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_HOME"] = "settings"
    app.launchEnvironment["GRABBER_SHAKE_AFTER"] = "6"
    app.launch()
    XCTAssertTrue(app.navigationBars["Home screen"].appears(within: 10), app.debugDescription)
    let report = app.navigationBars["Report a problem"]
    XCTAssertTrue(report.appears(within: 15), app.debugDescription)
    report.buttons["Cancel"].tap()
    // The report has to be gone, not just closing: the sheet's bar shows underneath it the whole time, so its being there
    // proves nothing, and a swipe during the close lands on the report going away.
    XCTAssertTrue(report.waitForNonExistence(timeout: 5), app.debugDescription)
    // The sheet underneath is still there.
    XCTAssertTrue(app.navigationBars["Home screen"].appears(within: 5), app.debugDescription)
    // A second report, from the sheet's own button: the first one's close let go of it.
    let button = app.buttons["home-settings-report"]
    for _ in 0..<10 where !button.isHittable { app.swipeUp() }  // the Settings list is long: launchers, then About
    button.tap()
    XCTAssertTrue(report.appears(within: 5), app.debugDescription)
  }
}
