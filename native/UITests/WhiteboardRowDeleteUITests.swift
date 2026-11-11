//  Stories 396, 399 (#613) on the simulator: a swipe deletes a board another device drew, after asking; it stays gone,
//  and a link to it says so. The delete crossing iCloud needs two real devices: the simulator has no account.

import XCTest

final class WhiteboardRowDeleteUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// The boards, with a board the iPad drew on a fresh id, so runs on one simulator don't meet each other's boards.
  private func openWithAnIPadBoard(_ id: String) -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_BOARD_FIXTURE"] = id
    app.launchEnvironment["GRABBER_BOARD_FIXTURE_FROM"] = "iPad"
    app.launch()
    return app
  }

  private func row(_ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'Drawn on iPad'")).firstMatch
  }

  private func iPadRows(_ app: XCUIApplication) -> Int {
    app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'Drawn on iPad'")).count
  }

  func testASwipeAsksThenDeletesABoardDrawnElsewhereAndALinkToItSaysSo() {
    let id = "board-613-\(UUID().uuidString.lowercased())"
    var app = openWithAnIPadBoard(id)
    XCTAssertTrue(row(app).appears(within: 20), app.debugDescription)
    let before = iPadRows(app)

    // A long press offers Delete on a board drawn elsewhere, and no Rename.
    row(app).press(forDuration: 1.2)
    XCTAssertTrue(app.buttons["Delete"].appears(within: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["Rename"].exists, "only its own device renames it")
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
    XCTAssertTrue(app.buttons["whiteboard-done"].appears(within: 5), app.debugDescription)

    // The swipe asks first.
    row(app).swipeLeft()
    let delete = app.buttons["Delete"].firstMatch
    XCTAssertTrue(delete.appears(within: 5), app.debugDescription)
    delete.tap()
    let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete Board'")).firstMatch
    XCTAssertTrue(confirm.appears(within: 5), app.debugDescription)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.lifetime = .keepAlways
    add(shot)
    confirm.tap()
    let fewer = NSPredicate { _, _ in self.iPadRows(app) == before - 1 }
    wait(for: [expectation(for: fewer, evaluatedWith: app)], timeout: 10)

    // Still gone next launch, and a link to it is a copyable problem.
    app.terminate()
    app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://whiteboard?board=\(id)"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()
    XCTAssertTrue(app.buttons["copy-error"].appears(within: 20), app.debugDescription)
    XCTAssertEqual(iPadRows(app), before - 1, app.debugDescription)
  }
}
