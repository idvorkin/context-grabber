//  #221: Today's hand, the large widget. Added through SpringBoard's own gallery as Igor would: the card and the role
//  of the day draw, a tap on the card deals another without opening the app, and Think of a card opens the card
//  screen counting. Screenshots under GRABBER_SHOTS.

import XCTest

final class TodaysHandUITests: XCTestCase {
  func testTheLargeWidgetDealsInPlaceAndStartsTheCount() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    XCTAssertTrue(app.buttons["home-think_a_card"].appears(within: 15))

    XCUIDevice.shared.press(.home)
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let role = springboard.staticTexts["Today, be"]
    if !role.appears(within: 3) { addTheLargeWidget(springboard) }
    XCTAssertTrue(role.appears(within: 10), springboard.debugDescription)
    let card = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Memdeck card'")).firstMatch
    XCTAssertTrue(card.appears(within: 5), springboard.debugDescription)
    shot("todays-hand")

    // A tap deals in place: a different card, and the app stays in the background.
    let before = card.label
    card.tap()
    let changed = NSPredicate(format: "label != %@", before)
    expectation(for: changed, evaluatedWith: card)
    waitForExpectations(timeout: 10)
    XCTAssertNotEqual(app.state, .runningForeground, "the card deals without opening the app")
    shot("todays-hand-dealt")

    springboard.buttons["Think of a card"].tap()
    XCTAssertTrue(app.buttons["card-done"].appears(within: 15), app.debugDescription)
  }

  /// Long press, Edit, Add Widget, search, swipe to the large size, Add Widget.
  private func addTheLargeWidget(_ springboard: XCUIApplication) {
    springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 1.5)
    let edit = springboard.buttons["Edit"]
    if edit.appears(within: 5) { edit.tap() }
    let addWidget = springboard.buttons["Add Widget"]
    XCTAssertTrue(addWidget.appears(within: 5), springboard.debugDescription)
    addWidget.tap()
    let search = springboard.searchFields.firstMatch
    XCTAssertTrue(search.appears(within: 5), springboard.debugDescription)
    search.tap()
    search.typeText("Grabber")
    let result = springboard.cells.containing(.staticText, identifier: "Grabber Native").firstMatch
    XCTAssertTrue(result.appears(within: 5), springboard.debugDescription)
    result.tap()
    let add = springboard.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Widget'")).firstMatch
    XCTAssertTrue(add.appears(within: 5), springboard.debugDescription)
    // The gallery opens on the usage tile's small size; Today's hand is after its medium.
    for _ in 0..<2 {
      springboard.swipeLeft()
      sleep(1)
    }
    shot("gallery-large")
    add.tap()
    sleep(2)
    let done = springboard.buttons["Done"]
    if done.appears(within: 3) { done.tap() }
    sleep(2)
  }

  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
  }
}
