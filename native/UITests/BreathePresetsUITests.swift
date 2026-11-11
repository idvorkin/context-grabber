//  Story 241 (#155): breath presets one tap each, and Custom with its own in and out. Remembering them is BreathTests'.

import XCTest

final class BreathePresetsUITests: XCTestCase {
  func testAPresetIsOneTapAndCustomShowsItsSides() throws {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_BREATHE"] = "open"
    app.launch()
    let twelve = app.buttons["breathe-preset-12"]
    XCTAssertTrue(twelve.appears(within: 15), app.debugDescription)
    twelve.tap()
    let summary = app.staticTexts["breathe-summary"]
    // 12 s a side at 5 minutes: 6 cycles of 48 s.
    XCTAssertTrue(summary.label.hasPrefix("6 cycles"), summary.label)
    XCTAssertFalse(app.otherElements["breathe-in"].exists || app.sliders["breathe-in"].exists, "no sliders on a preset")

    app.buttons["breathe-preset-custom"].tap()
    let inSlider = app.descendants(matching: .any)["breathe-in"]
    XCTAssertTrue(inSlider.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.descendants(matching: .any)["breathe-out"].exists)
    // That each choice is remembered for the next open is BreathTests' (`BreathSetup.writes` read back by `restore`).
  }
}
