//  Stories 950–953 on the iPad simulator: ? and Feedback, one tap each at the board's top right, as on Larry's /ink.
//  The cheat sheet lists the board's gestures and closes; Feedback opens BugKit's report sheet over the board, and once
//  it is logged the board says *Feedback logged ✓*. The top bar keeps the Board menu (#848).

import XCTest

final class WhiteboardHelpFeedbackUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func openBoard() -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    if let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"] {
      app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    return app
  }

  /// Stories 950, 951: one tap opens the cheat sheet; the bar keeps its Board menu.
  func testTheCheatSheetIsOneTap() {
    let app = openBoard()
    let help = app.buttons["whiteboard-help"]
    XCTAssertTrue(help.appears(within: 10), app.debugDescription)
    XCTAssertTrue(app.buttons["whiteboard-board"].isHittable, "the Board menu stays in the bar (#848)")
    XCTAssertTrue(app.buttons["whiteboard-send"].exists, "Send stays in the bar")
    let feedback = app.buttons["whiteboard-feedback"]
    XCTAssertTrue(feedback.exists, "Feedback beside it")
    // Story 949 (#1162): a ladybug alone, no wider than the ?, still named Feedback.
    XCTAssertEqual(feedback.label, "Feedback")
    XCTAssertLessThanOrEqual(feedback.frame.width, help.frame.width + 1, "the ladybug carries no word")
    help.tap()
    XCTAssertTrue(app.navigationBars["How this board works"].appears(within: 5), app.debugDescription)
    // Scrolled by a drag inside the cheat sheet, measured from its title: a swipe on the app's middle can start beside
    // the popover and close it (with the ladybug alone the ? sits further right and the popover opens to its left, #1162).
    let title = app.navigationBars["How this board works"]
    let scroll = {
      title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 8))
        .press(forDuration: 0.05, thenDragTo: title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 2)))
    }
    for gesture in [
      "Tap beside a line", "Hold and drag down", "Hold a header's mark", "Hold the Pencil on a word",
      "Underline a line, or start it with #", "Fast zigzag over ink", "Lasso, then To text",
      "Hold the Pencil at a stroke's end", "Keep all",
    ] {
      let row = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", gesture)).firstMatch
      if !row.exists { scroll() }
      XCTAssertTrue(row.appears(within: 3), "\(gesture) is listed: \(app.debugDescription)")
    }
    app.buttons["whiteboard-help-done"].tap()
    // `waitUntil` reads a missing element as "not yet", so the close is waited on with an expectation.
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.navigationBars["How this board works"])
    waitForExpectations(timeout: 5)
    XCTAssertTrue(app.buttons["whiteboard-board"].isHittable, "back on the board")
  }

  /// Stories 952, 953: one tap opens the report sheet; Log it brings *Feedback logged ✓* on the board.
  func testFeedbackIsOneTapAndSaysItWasLogged() {
    let app = openBoard()
    let feedback = app.buttons["whiteboard-feedback"]
    XCTAssertTrue(feedback.appears(within: 10), app.debugDescription)
    feedback.tap()
    let sheet = app.navigationBars["Report a problem"]
    XCTAssertTrue(sheet.appears(within: 10), app.debugDescription)
    // The board's own paper is a text view too, so the note is found by its identifier.
    let field = app.descendants(matching: .any)["report-note"].firstMatch
    XCTAssertTrue(field.appears(within: 5), app.debugDescription)
    field.tap()
    field.typeText("from the board's Feedback button")
    app.buttons["report-log-it"].tap()
    let logged = app.staticTexts["whiteboard-feedback-logged"]
    XCTAssertTrue(logged.appears(within: 10), app.debugDescription)
    XCTAssertEqual(logged.label, "Feedback logged ✓")
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: sheet)
    waitForExpectations(timeout: 5)
  }
}
