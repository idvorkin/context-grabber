//  Story 151 (#189): the home screen opens on today: a Today card with the last grab's numbers and no heading
//  (#355), then the tiles, three to a line. GRABBER_SHOTS=<dir> on the test's environment saves a picture.

import XCTest

final class HomeTodayCardUITests: XCTestCase {
  func testTheCardShowsTheLastGrabAndTheTilesLead() throws {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_MIRROR"] = "fixture"
    app.launch()
    XCTAssertTrue(app.staticTexts["hook-done"].appears(within: 60), app.debugDescription)
    app.navigationBars.buttons.element(boundBy: 0).tap()  // back to home

    let card = app.buttons["home-today-card"]
    XCTAssertTrue(card.appears(within: 10), app.debugDescription)
    XCTAssertFalse(card.label.contains("tap to look"), "the card shows the grab: \(card.label)")
    XCTAssertTrue(card.label.contains("as of"), card.label)
    // The tiles lead under the card, three to a line (#284): Call beside Timer, Places starting the next line.
    let call = app.buttons["home-call"]
    let places = app.buttons["home-places"]
    XCTAssertTrue(call.exists && places.exists, app.debugDescription)
    XCTAssertGreaterThan(call.frame.minY, card.frame.maxY, "the tiles come after the card")
    XCTAssertEqual(call.frame.minY, app.buttons["home-gym_timer"].frame.minY, accuracy: 2, "Call beside Timer")
    XCTAssertGreaterThan(places.frame.minY, call.frame.maxY, "Places starts the next line")
    if let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] {
      try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/home-today.png"))
    }
  }
}
