//  #219: Think of a card is Think a Card Trainer's own screen, shared. The home row opens it with the ask started:
//  a card up, a small count, then a new card. A tap on the middle switches the card; Done goes home. The simulator
//  has no sound, so the spoken card is the phone's to check. Screenshots stay local (they show cards, not positions).

import XCTest

final class CardUITests: XCTestCase {
  // #229: the trainer speaks the card in lower case ("two of spades").
  private let cardName = NSPredicate(format: "label MATCHES[c] %@", ".* of (spades|hearts|diamonds|clubs)")

  func testTheTrainersScreenAsksThenDeals() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    let row = app.buttons["home-think_a_card"]
    XCTAssertTrue(row.appears(within: 15), app.debugDescription)
    row.tap()

    let card = app.descendants(matching: .any).matching(cardName).firstMatch
    XCTAssertTrue(card.appears(within: 10), app.debugDescription)
    let asked = card.label
    // The ask started from the row: the count's digit is up beside the card. The rank is a digit too (a two shows
    // "2"), so the count is the small one. Under load the scan can outlast the count, so a card already dealt counts.
    let count = app.staticTexts.matching(NSPredicate(format: "label IN {'3', '2', '1'}"))
    let counting = NSPredicate { _, _ in
      count.allElementsBoundByIndex.contains { $0.exists && $0.frame.height < 100 } || card.label != asked
    }
    expectation(for: counting, evaluatedWith: count)
    waitForExpectations(timeout: 3)
    shot("card-asking")
    // Three beats, then the new card and no count. #694: wait on the card's own label, one element; a predicate over
    // every digit on screen took 30 s a poll under a loaded Mac, and timed out with the card long dealt. A predicate
    // expectation on `card` holds the element it first found, which the deal replaces, so look the new card up afresh.
    let dealt = app.descendants(matching: .any).matching(cardName).matching(NSPredicate(format: "label != %@", asked))
    XCTAssertTrue(dealt.firstMatch.appears(within: 15), "the ask dealt a new card")
    XCTAssertFalse(
      count.allElementsBoundByIndex.contains { $0.exists && $0.frame.height < 100 },
      "the count is gone once the card is dealt")
    shot("card-dealt")

    // A tap on the middle third switches the card.
    let before = card.label
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    let switched = NSPredicate(format: "label != %@", before)
    expectation(for: switched, evaluatedWith: card)
    waitForExpectations(timeout: 5)

    app.buttons["card-done"].tap()
    XCTAssertTrue(row.appears(within: 5), "back home")
  }

  // Story 220: Drill the stack covers the card with the trainer's drill, asking Card → position first; Done returns
  // to the card. The taps that grade, and the ledger, are the phone's to check (the simulator has no ledger key).
  func testDrillTheStackOpensTheTrainersDrill() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    let row = app.buttons["home-think_a_card"]
    XCTAssertTrue(row.appears(within: 15), app.debugDescription)
    row.tap()
    let drill = app.buttons["card-drill"]
    XCTAssertTrue(drill.appears(within: 10), app.debugDescription)
    drill.tap()

    let prompt = app.buttons["Tap to see its position"]
    XCTAssertTrue(prompt.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.buttons["Mixed"].exists, "the direction picker offers Mixed")
    XCTAssertTrue(app.buttons["Stats"].exists, "Stats is there: the app gives the drill a ledger")
    shot("card-drill")
    // #400: the card's own Done sits under the cover and answers to the same label.
    app.buttons.matching(NSPredicate(format: "label == 'Done' AND identifier != 'card-done'")).firstMatch.tap()
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: prompt)
    waitForExpectations(timeout: 5)
    XCTAssertTrue(drill.appears(within: 5), "back on the card")
  }

  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
  }
}
