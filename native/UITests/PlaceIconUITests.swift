//  Story 057 (#161): choosing an icon on a known place's screen changes its pin at once, and Use the guess gives
//  it back. Needs the fixture's places, imported as `just native-test-sim` imports them (PlacesUnnamedUITests says
//  how); the test puts Home's icon back at the end.

import XCTest

final class PlaceIconUITests: XCTestCase {
  func testChooseAnIconThenUseTheGuess() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_PLACES"] = "open,edit:Home"
    app.launch()
    let heart = app.buttons["icon-heart.fill"]
    guard heart.waitForExistence(timeout: 20) else { throw XCTSkip("no known place called Home: import the fixture first") }
    XCTAssertTrue(app.staticTexts["Guessed from the name"].exists, app.debugDescription)
    heart.tap()
    XCTAssertTrue(app.staticTexts["Chosen"].waitForExistence(timeout: 5))
    app.buttons["place-done"].tap()

    let pin = app.descendants(matching: .any)["place-Home"]
    XCTAssertTrue(pin.waitForExistence(timeout: 10))
    XCTAssertEqual(pin.value as? String, "heart.fill", "the pin shows the chosen icon")

    // Known places is below the day cards: scroll to it.
    let row = app.buttons["known-Home"].firstMatch
    for _ in 0..<12 where !(row.exists && row.isHittable) { app.swipeUp() }
    row.tap()
    let guess = app.buttons["Use the guess"]
    XCTAssertTrue(guess.waitForExistence(timeout: 5))
    guess.tap()
    XCTAssertTrue(app.staticTexts["Guessed from the name"].waitForExistence(timeout: 5))
    app.buttons["place-done"].tap()
    for _ in 0..<12 where !app.descendants(matching: .any)["place-Home"].isHittable { app.swipeDown() }
    XCTAssertEqual(app.descendants(matching: .any)["place-Home"].value as? String, "house.fill")
  }
}
