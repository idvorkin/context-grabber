//  Stories 344, 345, 349, 357, 360, 371, 380–389 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it), on a board on paper (the only canvas since 2026-11-07): a stroke and a pause bring Claude's ghost through a
//  streamed answer, words spoken on an empty board bring one with no stroke, and Larry's turn hands him the board and his
//  marks arrive by themselves beside Claude's, and the note opens on his reply (story 768). A finger draws on the simulator; the Pencil is the iPad's check. What paper
//  shows (its ghosts, taps, lines and colours, by pixels) is `WhiteboardPaperGhostsUITests`' and
//  `WhiteboardPaperLinesUITests`'. The turn's rules (Claude's fade, the count climbing, a Cockpit that doesn't stream, Ghosts
//  off for strokes and for words, stale answers, spoken words held, a tap's keep or dismiss) are `WhiteboardGhostTurnsTests`,
//  on the host.

import XCTest

final class WhiteboardTurnUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// A new board open, Ghosts on, the app talking to the fake Cockpit, which streams one mark.
  private func openBoard(say: String? = nil) throws -> (XCUIApplication, XCUIElement) {
    let cockpit = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    if let say { app.launchEnvironment["GRABBER_WHITEBOARD_SAY"] = say }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts off") { ghosts.tap() }
    sleep(1)
    return (app, ghosts)
  }

  /// The canvas is not in the accessibility snapshot: the stroke goes to the window by position, ending at 60% across.
  private func stroke(_ app: XCUIApplication, atHeight dy: CGFloat = 0.5) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: dy))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: dy)))
  }

  private func wait(_ button: XCUIElement, label: String, timeout: TimeInterval) {
    waitUntil(NSPredicate(format: "label == %@", label), button, timeout: timeout)
  }

  /// How many strokes the board holds, from the Send button's label.
  private func wait(_ app: XCUIApplication, strokes: Int) {
    waitUntil(
      NSPredicate(format: "label == %@", "Send to Larry, \(strokes) strokes"), app.buttons["whiteboard-send"],
      timeout: 8)
  }

  func testSpeakingOnAnEmptyBoardBringsAGhostWithoutAStroke() throws {
    let (app, ghosts) = try openBoard(say: "draw a circle")
    app.buttons["whiteboard-mic"].tap()
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)
    wait(app, strokes: 0)
  }

  /// The one path from a streamed answer to a ghost on screen (story 370's reading is `WhiteboardGhostTurnsTests`).
  func testAPauseBringsAGhostAndLarryTakesATurn() throws {
    let (app, ghosts) = try openBoard()
    stroke(app)
    wait(ghosts, label: "Ghosts on, 1 showing", timeout: 8)

    app.buttons["whiteboard-larry"].tap()
    // Larry's two marks beside Claude's one, with no further tap: each author replaces only their own.
    wait(ghosts, label: "Ghosts on, 3 showing", timeout: 15)
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Larry: this is where it goes")).firstMatch
        .appears(within: 3), app.debugDescription)
    // Story 371: what the ghosts look like, Claude's and Larry's, is for a person to judge: kept with the test's result.
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "ghosts-like-ink"
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// The fake Cockpit draws on the board's thread, as Larry does when he has something to add.
  private func larryDraws(_ count: Int, on cockpit: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/larry-draws")))
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"count": \#(count)}"#.utf8)
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// Back to the list and into the same board.
  private func reopenBoard(_ app: XCUIApplication) {
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let card = app.buttons["whiteboard-card"].firstMatch
    XCTAssertTrue(card.appears(within: 5), app.debugDescription)
    card.tap()
    XCTAssertTrue(app.buttons["whiteboard-ghosts"].appears(within: 5), app.debugDescription)
  }

  /// Stories 382, 383, 386 and 388, with Ghosts off so only Larry's marks show. Unprompted marks replace his unkept ones with no
  /// tap, the newest set comes back when the board opens again, and once dismissed it doesn't, on either count.
  func testLarrysMarksArriveOnTheirOwnAndADismissedSetStaysGone() throws {
    let cockpit = try XCTUnwrap(ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"])
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    stroke(app)
    wait(app, strokes: 1)
    app.buttons["whiteboard-larry"].tap()
    let marks = { (count: Int) -> NSPredicate in
      NSPredicate(format: "label == %@", "\(count) to keep")
    }
    XCTAssertTrue(
      app.staticTexts.matching(marks(2)).firstMatch.appears(within: 15), app.debugDescription)

    try larryDraws(3, on: cockpit)
    XCTAssertTrue(
      app.staticTexts.matching(marks(3)).firstMatch.appears(within: 10), app.debugDescription)

    reopenBoard(app)
    XCTAssertTrue(
      app.staticTexts.matching(marks(3)).firstMatch.appears(within: 10), app.debugDescription)

    app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
    let none = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", " to keep")).firstMatch
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: none)
    waitForExpectations(timeout: 3)
    sleep(4)  // A look at the thread has come and gone.
    XCTAssertFalse(none.exists, app.debugDescription)
    reopenBoard(app)
    sleep(4)
    XCTAssertFalse(none.exists, app.debugDescription)
  }

  /// Story 768: a tap on the note's chevron opens the conversation over the board, holding Larry's whole reply. What the
  /// line and the panel say is `WhiteboardNoteTests`, on the host.
  func testTheNoteOpensOnLarrysReply() throws {
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    stroke(app)
    wait(app, strokes: 1)
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Larry: this is where it goes")).firstMatch
        .appears(within: 15), app.debugDescription)
    let chevron = app.buttons["whiteboard-note-chevron"]
    XCTAssertTrue(chevron.appears(within: 5), app.debugDescription)
    // The panel's own identifier isn't an element XCUITest finds; its thread text is, and is there only while open.
    let panel = app.textViews["whiteboard-conversation-text"]
    if !panel.exists { chevron.tap() }
    // Open or closed outlives the launch: the next test starts with it closed.
    addTeardownBlock {
      if panel.exists { chevron.tap() }
    }
    XCTAssertTrue(panel.appears(within: 5), app.debugDescription)
    waitUntil(NSPredicate(format: "value CONTAINS %@", "Larry: this is where it goes"), panel, timeout: 8)
  }
}
