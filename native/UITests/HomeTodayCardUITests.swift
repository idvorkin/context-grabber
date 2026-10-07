//  Story 151 (#189): the home screen opens on today: a Today card with the last grab's numbers, the daily four as
//  tiles, the rest as rows. GRABBER_SHOTS=<dir> on the test's environment saves a picture.

import XCTest

final class HomeTodayCardUITests: XCTestCase {
  func testTheCardShowsTheLastGrabAndTheTilesLead() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_MIRROR"] = "fixture"
    app.launch()
    XCTAssertTrue(app.staticTexts["hook-done"].waitForExistence(timeout: 60), app.debugDescription)
    app.navigationBars.buttons.element(boundBy: 0).tap()  // back to home

    let card = app.buttons["home-today-card"]
    XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertFalse(card.label.contains("tap to look"), "the card shows the grab: \(card.label)")
    XCTAssertTrue(card.label.contains("as of"), card.label)
    // The daily four lead, as tiles, above the rows.
    let call = app.buttons["home-call"], places = app.buttons["home-places"], card2 = app.buttons["home-think_a_card"]
    XCTAssertTrue(call.exists && places.exists, app.debugDescription)
    XCTAssertLessThan(places.frame.minY, card2.frame.minY)
    XCTAssertEqual(call.frame.minY, app.buttons["home-gym_timer"].frame.minY, accuracy: 2, "two by two")
    if let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] {
      try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/home-today.png"))
    }
  }
}
