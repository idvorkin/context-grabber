//  Story 252 (#340, #353): Report a problem is a tile on the home screen, and a tap opens the same report sheet a
//  shake opens.

import XCTest

final class HomeReportTileUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testTheBeetleTileOpensTheReportSheet() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    let tile = app.buttons["home-report_problem"]
    for _ in 0..<8 where !(tile.exists && tile.isHittable) { app.swipeUp() }
    XCTAssertTrue(tile.appears(within: 10), app.debugDescription)
    XCTAssertEqual(tile.label, "Report a problem", "VoiceOver names the tile")
    tile.tap()
    XCTAssertTrue(app.navigationBars["Report a problem"].appears(within: 10), app.debugDescription)
    app.buttons["Cancel"].tap()
  }
}
