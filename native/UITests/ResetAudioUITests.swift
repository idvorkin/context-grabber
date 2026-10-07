//  Story 149: Reset audio in the home screen's cog lets go of the audio and says what it was and is.

import XCTest

final class ResetAudioUITests: XCTestCase {
  func testResetAudioShowsTheRouteBeforeAndAfter() throws {
    let app = XCUIApplication()
    app.launch()
    let cog = app.buttons["home-settings"]
    XCTAssertTrue(cog.waitForExistence(timeout: 15), app.debugDescription)
    cog.tap()
    let reset = app.buttons["home-reset-audio"]
    for _ in 0..<5 where !reset.isHittable { app.swipeUp() }
    XCTAssertTrue(reset.waitForExistence(timeout: 5), app.debugDescription)
    reset.tap()
    // The line sits under the button, below the fold: a list only shows rows on screen.
    let result = app.staticTexts["home-reset-audio-result"]
    for _ in 0..<4 where !result.waitForExistence(timeout: 2) { app.swipeUp() }
    XCTAssertTrue(result.exists, app.debugDescription)
    let line = result.label
    XCTAssertTrue(line.hasPrefix("Was ") || line.hasPrefix("iOS refused"), line)
  }
}
