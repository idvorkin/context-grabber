//  Story 240 (#147): the cog picks a ring style, and the next launch remembers it.

import XCTest

final class BreatheStyleUITests: XCTestCase {
  func testPickTideAndItIsRememberedNextLaunch() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_BREATHE"] = "open"
    app.launch()
    let cog = app.buttons["breathe-style"]
    XCTAssertTrue(cog.waitForExistence(timeout: 15), app.debugDescription)
    cog.tap()
    let tide = app.buttons["breathe-style-tide"]
    XCTAssertTrue(tide.waitForExistence(timeout: 5))
    tide.tap()
    XCTAssertTrue(tide.isSelected)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.lifetime = .keepAlways
    add(shot)
    app.buttons["breathe-style-done"].tap()

    app.terminate()
    app.launch()
    XCTAssertTrue(cog.waitForExistence(timeout: 15))
    cog.tap()
    XCTAssertTrue(app.buttons["breathe-style-tide"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["breathe-style-tide"].isSelected, "Tide is remembered across launches")
    XCTAssertFalse(app.buttons["breathe-style-line"].isSelected)
  }
}
