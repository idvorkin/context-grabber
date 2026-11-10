//  Story 240 (#147): the cog picks a ring style. That the next launch reads it back is BreathStyleTests' on the host
//  (testEveryStyleIsReadBackAsItIsStored), so this no longer relaunches.

import XCTest

final class BreatheStyleUITests: XCTestCase {
  func testTheCogPicksTide() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_BREATHE"] = "open"
    app.launch()
    let cog = app.buttons["breathe-style"]
    XCTAssertTrue(cog.appears(within: 15), app.debugDescription)
    cog.tap()
    let tide = app.buttons["breathe-style-tide"]
    XCTAssertTrue(tide.appears(within: 5))
    tide.tap()
    XCTAssertTrue(tide.isSelected)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.lifetime = .keepAlways
    add(shot)
    XCTAssertFalse(app.buttons["breathe-style-line"].isSelected)
    app.buttons["breathe-style-done"].tap()
  }
}
