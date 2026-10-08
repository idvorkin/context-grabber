//  Story 129 in Grabber Native (#219): Think of a card is in the app. The home row opens the card face down and
//  counting; at zero a new card is face up; a tap deals another; Never mind keeps the card that was showing.

import XCTest

final class CardUITests: XCTestCase {
  func testThinkOfACardCountsThenReveals() throws {
    let app = XCUIApplication()
    app.launch()
    let row = app.buttons["home-think_a_card"]
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    row.tap()

    // Face down and counting, straight from the row.
    let back = app.otherElements["card-back"]
    XCTAssertTrue(back.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertEqual(app.buttons["card-think"].label, "Never mind")
    shot("card-counting")

    // About five seconds later, a card face up.
    let face = app.buttons["card-face"]
    XCTAssertTrue(face.waitForExistence(timeout: 9), app.debugDescription)
    XCTAssertFalse(back.exists)
    XCTAssertEqual(app.buttons["card-think"].label, "Think of a card")
    shot("card-revealed")

    // A tap deals a different card.
    let first = face.label
    face.tap()
    XCTAssertNotEqual(face.label, first, "a tap deals another")

    // Never mind mid-count: the card that was showing comes back.
    let showing = face.label
    app.buttons["card-think"].tap()
    XCTAssertTrue(back.waitForExistence(timeout: 3))
    app.buttons["card-think"].tap()
    XCTAssertTrue(face.waitForExistence(timeout: 3))
    XCTAssertEqual(face.label, showing, "Never mind keeps the card")

    app.buttons["card-done"].tap()
    XCTAssertTrue(row.waitForExistence(timeout: 5), "back home")
  }

  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
  }
}
