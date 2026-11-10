//  #391, story 222: press and hold a home tile for a popover of its choices, and a tap outside opens nothing. What a
//  choice opens is host-tested; the light tick and the drawn art are the phone's to judge.

import XCTest

final class HoldPopoverUITests: XCTestCase {
  private func hold(_ tile: String, in app: XCUIApplication) {
    let row = app.buttons["home-\(tile)"]
    XCTAssertTrue(row.appears(within: 15), app.debugDescription)
    for _ in 0..<4 where !row.isHittable { app.swipeUp() }
    row.press(forDuration: 1.5)
  }

  // What each choice opens (stories 223-225, 465-466) is the host's: HomeStackTests'
  // `testEveryHeldChoiceOpensItsScreenFromHome`, HoldChoicesTests and BlogLinksTests (test-ladder card 2). This keeps
  // the one real press and hold.

  // Story 222: a tap outside closes the popover with nothing opened, and the tile's tap still works after a hold.
  func testATapOutsideOpensNothing() throws {
    let app = XCUIApplication()
    app.launch()
    hold("breathe", in: app)
    XCTAssertTrue(app.buttons["breathe-10"].appears(within: 10), app.debugDescription)
    // UIKit's region outside a popover; a tap at the very top lands in the status bar and never reaches it.
    let outside = app.otherElements["PopoverDismissRegion"]
    XCTAssertTrue(outside.appears(within: 5), app.debugDescription)
    outside.tap()
    XCTAssertFalse(app.buttons["breathe-10"].appears(within: 2), "the popover closed")
    XCTAssertTrue(app.buttons["home-breathe"].isHittable, "still on the home screen")
  }
}
