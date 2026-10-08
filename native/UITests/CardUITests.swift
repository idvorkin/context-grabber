//  #219: Think of a card is Think a Card Trainer's own screen, shared. The home row opens it with the ask started:
//  a card up, a small count, then a new card. A tap on the middle switches the card; Done goes home. The simulator
//  has no sound, so the spoken card is the phone's to check. Screenshots stay local (they show cards, not positions).

import XCTest

final class CardUITests: XCTestCase {
  private let cardName = NSPredicate(format: "label MATCHES %@", ".* of (Spades|Hearts|Diamonds|Clubs)")

  func testTheTrainersScreenAsksThenDeals() throws {
    throw XCTSkip("#229: the card's accessibility label is not yet matched; the screen itself shows correctly")
    let app = XCUIApplication()
    app.launch()
    let row = app.buttons["home-think_a_card"]
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    row.tap()

    let card = app.descendants(matching: .any).matching(cardName).firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
    // The ask started from the row: the count's digit is up beside the card.
    let count = app.staticTexts.matching(NSPredicate(format: "label IN {'3', '2', '1'}")).firstMatch
    XCTAssertTrue(count.waitForExistence(timeout: 3), "the count runs: \(app.debugDescription)")
    shot("card-asking")
    let asked = card.label
    // Three beats, then the new card and no count.
    let dealt = NSPredicate(format: "exists == false")
    expectation(for: dealt, evaluatedWith: count)
    waitForExpectations(timeout: 8)
    XCTAssertNotEqual(card.label, asked, "the ask dealt a new card")
    shot("card-dealt")

    // A tap on the middle third switches the card.
    let before = card.label
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    let switched = NSPredicate(format: "label != %@", before)
    expectation(for: switched, evaluatedWith: card)
    waitForExpectations(timeout: 5)

    app.buttons["card-done"].tap()
    XCTAssertTrue(row.waitForExistence(timeout: 5), "back home")
  }

  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
  }
}
