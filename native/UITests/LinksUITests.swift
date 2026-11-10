//  Story 135 (#167): a link opens the app cold where it says, and the Links screen copies them. The link goes
//  through iOS (`XCUIApplication.open`), as a Shortcut's *Open URL* would; where a warm link lands is HomeStackTests'.

import XCTest

final class LinksUITests: XCTestCase {
  private func shot(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  /// The warm links (over a running screen, an unknown one, an unknown preset) are host tests now: HomeStackTests'
  /// `testWarmLinksOverTheTimer` and the link pairs (test-ladder card 2). This keeps the one only iOS can do.
  func testATimerLinkStartsTheAppCold() throws {
    let app = XCUIApplication()
    // Cold: the link launches the app.
    app.open(URL(string: "grabbernative://timer?preset=10,10,2")!)
    XCTAssertTrue(app.buttons["STOP"].appears(within: 20), "the link starts the workout")
    shot(app, "timer-from-link")
  }

  func testTheLinksScreenCopiesALink() throws {
    let app = XCUIApplication()
    app.launch()
    // The Links screen sits behind the home screen's Settings tile (story 147).
    app.openHomeSettings()
    let row = app.buttons["home-links"]
    for _ in 0..<5 where !row.isHittable { app.swipeUp() }
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
    row.tap()
    let copy = app.buttons["copy-grabbernative://timer?preset=1min"]
    XCTAssertTrue(copy.appears(within: 5), app.debugDescription)
    shot(app, "links-screen")
    copy.tap()
    XCTAssertEqual(copy.label, "Copied")
  }
}
