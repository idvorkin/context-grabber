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
    if ghosts.label.hasPrefix("Ask at my pauses: off") { ghosts.tap() }
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
    wait(ghosts, label: "Ask at my pauses: on, 1 showing", timeout: 8)
    wait(app, strokes: 0)
  }

  /// Story 926 (bead context-grabber-h5c0): holding the mic, closed, offers its own row and the microphones, and that
  /// row still talks. The simulator has no microphone to pick; the pocket mic is the iPad's to show.
  func testHoldingTheMicPicksTheMicrophone() throws {
    let (app, ghosts) = try openBoard(say: "draw a circle")
    app.buttons["whiteboard-mic"].press(forDuration: 1.2)
    let talk = app.buttons["Talk to Claude"]
    XCTAssertTrue(talk.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.buttons["Automatic"].exists, app.debugDescription)
    // A menu's rows keep their labels but not their identifiers.
    XCTAssertTrue(app.buttons["Find microphones"].exists, app.debugDescription)
    shot("whiteboard-mic-hold")
    talk.tap()
    wait(ghosts, label: "Ask at my pauses: on, 1 showing", timeout: 8)
  }

  /// The one path from a streamed answer to a ghost on screen (story 370's reading is `WhiteboardGhostTurnsTests`).
  func testAPauseBringsAGhostAndLarryTakesATurn() throws {
    let (app, ghosts) = try openBoard()
    stroke(app)
    wait(ghosts, label: "Ask at my pauses: on, 1 showing", timeout: 8)

    app.buttons["whiteboard-send"].tap()
    // Larry's two marks beside Claude's one, with no further tap: each author replaces only their own.
    wait(ghosts, label: "Ask at my pauses: on, 3 showing", timeout: 15)
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

  /// Stories 382, 383, 386, 388, 810 and 1155, with Ghosts off so only Larry's marks show. His second reply, unprompted,
  /// joins his unkept marks from the first with no tap, rather than replacing them (bead context-grabber-n8ab), and a
  /// stray tap off them dismisses none of them (#883). That a dismissed or kept mark alone stays
  /// gone, that the newest set comes back on opening, and that a seen set never comes back between looks, are
  /// `WhiteboardMarksTests`, on the host.
  func testLarrysMarksArriveOnTheirOwnAndAStrayTapLeavesThem() throws {
    let cockpit = try XCTUnwrap(ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"])
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    stroke(app)
    wait(app, strokes: 1)
    app.buttons["whiteboard-send"].tap()
    let marks = { (count: Int) -> NSPredicate in
      NSPredicate(format: "label == %@", "\(count) to keep")
    }
    XCTAssertTrue(
      app.staticTexts.matching(marks(2)).firstMatch.appears(within: 15), app.debugDescription)

    try larryDraws(3, on: cockpit)
    XCTAssertTrue(
      app.staticTexts.matching(marks(5)).firstMatch.appears(within: 10),
      "the first reply's two stay: \(app.debugDescription)")

    app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
    sleep(2)
    XCTAssertTrue(app.staticTexts.matching(marks(5)).firstMatch.exists, "a stray tap dismisses nothing")
    XCTAssertFalse(app.buttons["whiteboard-mark-dismiss"].exists, "and shows no buttons")
  }

  /// Story 895: Keep all, beside the count of marks to keep, makes every mark of his ink at once, and one undo would take them all
  /// back (the keep is one step, as a single Keep is in `WhiteboardPaperGhostsUITests.testOneUndoTakesAKeptMarkBack`).
  /// Where each lands, in order and off his ink, is `WhiteboardTidyTests`, on the host.
  func testKeepingAllOfLarrysMarksMakesThemInkInOneStep() throws {
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    stroke(app)
    wait(app, strokes: 1)
    app.buttons["whiteboard-send"].tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label == %@", "2 to keep")).firstMatch.appears(within: 15),
      app.debugDescription)
    let keepAll = app.buttons["whiteboard-keep-all"]
    XCTAssertTrue(keepAll.appears(within: 5), app.debugDescription)
    keepAll.tapWhenSettled()
    waitUntil(
      NSPredicate(format: "label BEGINSWITH 'Send to Larry, ' AND NOT (label == 'Send to Larry, 1 strokes')"),
      app.buttons["whiteboard-send"], timeout: 8)
    XCTAssertFalse(
      app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' to keep'")).firstMatch.exists, "none left to keep")
  }

  /// Stories 768, 837: a tap on the note's chevron opens the conversation over the board, holding Larry's whole reply, in a
  /// panel held to a fifth of the board. What the line and the panel say is `WhiteboardNoteTests`, on the host.
  func testTheNoteOpensOnLarrysReply() throws {
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    stroke(app)
    wait(app, strokes: 1)
    app.buttons["whiteboard-send"].tap()
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
    // Story 837 (#917): the thread's text is held to a fifth of the board, under the window's fifth, however long.
    let window = app.windows.firstMatch.frame.height
    XCTAssertLessThanOrEqual(panel.frame.height, max(window / 5, 120) + 1, "the panel scrolls, it doesn't grow")
    // Story 1047 (#1003): his words, no row for the picture that went without words, and one chip for where it is.
    XCTAssertFalse(
      (panel.value as? String ?? "").contains(WhiteboardTurnUITests.boardTurnNote), "no row for a wordless picture")
    let chip = app.staticTexts["whiteboard-conversation-live-chip"]
    XCTAssertTrue(chip.appears(within: 5), app.debugDescription)
    // Bead context-grabber-l9u: his reply came, so the chip says Answered, never Sent (the fake Cockpit marks nothing).
    waitUntil(NSPredicate(format: "label == %@", "Your board · Answered"), chip, timeout: 8)
    // Story 1048 (#1003): the panel pushes the paper down; the paper's top corner (its ? button) is below the panel.
    let help = app.buttons["whiteboard-help"]
    XCTAssertTrue(help.appears(within: 5), app.debugDescription)
    let open = help.frame.minY
    XCTAssertGreaterThanOrEqual(open, panel.frame.maxY, "nothing on the paper is under the panel")
    shot("whiteboard-conversation-open")
    chevron.tap()
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: panel)
    waitForExpectations(timeout: 5)
    let deadline = Date().addingTimeInterval(5)
    while help.frame.minY >= open - 20, Date() < deadline { usleep(200_000) }
    XCTAssertLessThan(help.frame.minY, open - 20, "closed, the paper moves back up")
    chevron.tap()
    XCTAssertTrue(panel.appears(within: 5), app.debugDescription)
  }

  /// Story 1045 (#1438, Igor 2026-11-24: "Make docked chat be wider, like only halfway"): the docked conversation's text
  /// runs to about half the board, not a narrow column nor across it. The simulator stays in its own orientation: turning
  /// it leaves SpringBoard a minute from idle for the next test. Half of a wide board is `WhiteboardNoteTests`, on the
  /// host; in portrait the seventy-character floor is a little over half.
  func testTheDockedConversationIsAboutHalfTheBoard() throws {
    let (app, ghosts) = try openBoard()
    ghosts.tap()
    stroke(app)
    wait(app, strokes: 1)
    app.buttons["whiteboard-send"].tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Larry: this is where it goes")).firstMatch
        .appears(within: 15), app.debugDescription)
    let chevron = app.buttons["whiteboard-note-chevron"]
    XCTAssertTrue(chevron.appears(within: 5), app.debugDescription)
    let panel = app.textViews["whiteboard-conversation-text"]
    if !panel.exists { chevron.tap() }
    addTeardownBlock {
      if panel.exists { chevron.tap() }
    }
    XCTAssertTrue(panel.appears(within: 5), app.debugDescription)
    let window = app.windows.firstMatch.frame.width
    let deadline = Date().addingTimeInterval(5)
    while panel.frame.width < window * 0.45, Date() < deadline { usleep(200_000) }
    XCTAssertGreaterThanOrEqual(panel.frame.width, window * 0.45, "docked, the text runs to about half the board")
    XCTAssertLessThanOrEqual(panel.frame.width, window * 0.65, "and not across the whole board")
    shot("whiteboard-conversation-docked-half")
  }

  private static let boardTurnNote = "Your turn on the board"

  /// A picture for the PR, when the run names a folder (TEST_RUNNER_GRABBER_SHOTS).
  private func shot(_ name: String) {
    guard let dir = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
  }

  /// #1005 (stories 1054, 1055): with nothing to paste there is no Paste, so no hole in the bar; a long press on a button
  /// names it and says what a tap does, and a tap still does it.
  func testTheBarNamesItsButtonsAndHasNoHole() throws {
    UIPasteboard.general.items = []
    let (app, ghosts) = try openBoard()
    XCTAssertFalse(app.buttons["whiteboard-paste"].exists, "nothing to paste: no Paste")
    let mic = app.buttons["whiteboard-mic"]
    let send = app.buttons["whiteboard-send"]
    // Story 1176: one Send, no Larry's turn.
    XCTAssertFalse(app.buttons["whiteboard-larry"].exists, "Larry's turn is Send now")
    // Even spacing: the gaps between the three on the right differ by no more than a few points.
    let gaps = zip([mic, ghosts], [ghosts, send]).map { $1.frame.minX - $0.frame.maxX }
    XCTAssertLessThan((gaps.max() ?? 0) - (gaps.min() ?? 0), 12, "\(gaps)")
    ghosts.press(forDuration: 1.2)
    let named = app.buttons["Stop asking Larry at my pauses"]
    XCTAssertTrue(named.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.staticTexts["Ask at my pauses"].exists, app.debugDescription)
    shot("whiteboard-bar-long-press")
    named.tapWhenSettled()
    waitUntil(NSPredicate(format: "label BEGINSWITH 'Ask at my pauses: off'"), ghosts, timeout: 5)
    ghosts.tap()
    waitUntil(NSPredicate(format: "label BEGINSWITH 'Ask at my pauses: on'"), ghosts, timeout: 5)
  }

  /// How many pause turns the fake Cockpit has been asked so far, by any board (story 1171).
  private func turnsAsked(_ cockpit: String) throws -> Int {
    let url = try XCTUnwrap(URL(string: cockpit + "/fake/turns"))
    var got: Data?
    let done = expectation(description: "the fake Cockpit answered")
    URLSession.shared.dataTask(with: url) { body, _, _ in
      got = body
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    let json = try JSONSerialization.jsonObject(with: try XCTUnwrap(got)) as? [String: Any]
    return try XCTUnwrap(json?["turns"] as? [Any]).count
  }

  /// A stroke, then longer than the longest pause (5 s, story 892): no turn reaches the Cockpit.
  private func aPauseAsksNoOne(_ app: XCUIApplication, _ cockpit: String, strokes: Int, atHeight dy: CGFloat) throws {
    let before = try turnsAsked(cockpit)
    stroke(app, atHeight: dy)
    wait(app, strokes: strokes)
    sleep(7)
    XCTAssertEqual(try turnsAsked(cockpit), before, "a pause with the switch off asks no one")
  }

  /// Story 1171 (bead context-grabber-4ic): the switch is *Ask at my pauses*, for whoever answers. On, a pause reaches
  /// the Cockpit; off, the same pause reaches no one, on a Larry board (a new board's own, story 960) and on a Haiku
  /// board, the bar says no one is watching, and Larry's marks already showing stay. The long press names the responder.
  func testAskAtMyPausesOffAsksNoOneOnALarryOrAHaikuBoard() throws {
    let cockpit = try XCTUnwrap(ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"])
    let (app, asking) = try openBoard()
    // On: a pause reaches the Cockpit, so the counts below can see one.
    let before = try turnsAsked(cockpit)
    stroke(app)
    wait(asking, label: "Ask at my pauses: on, 1 showing", timeout: 8)
    XCTAssertGreaterThan(try turnsAsked(cockpit), before, "on, a pause asks")
    app.buttons["whiteboard-send"].tap()
    wait(asking, label: "Ask at my pauses: on, 3 showing", timeout: 15)

    // Off, on the Larry board, from the long press's row: Claude's mark goes, Larry's two stay.
    asking.press(forDuration: 1.2)
    let stop = app.buttons["Stop asking Larry at my pauses"]
    XCTAssertTrue(stop.appears(within: 5), app.debugDescription)
    // Bead context-grabber-3zil: a menu's row exists before it stops moving, and a tap then can miss, leaving the menu
    // up over the bar (#686), so the button under it reads as not found: the tap waits for the row to settle. Bead
    // context-grabber-xnvx: even a settled row can take a tap and do nothing, so it's tapped until the menu has closed.
    stop.tapUntilGone(took: { asking.exists && asking.label.hasPrefix("Ask at my pauses: off") })
    wait(asking, label: "Ask at my pauses: off, 2 showing", timeout: 5)
    try aPauseAsksNoOne(app, cockpit, strokes: 2, atHeight: 0.35)
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "no one is watching")).firstMatch
        .appears(within: 3), app.debugDescription)

    // The board given to Haiku: the long press names Haiku, and off still asks no one.
    app.buttons["whiteboard-board"].tap()
    let responder = app.descendants(matching: .any)["whiteboard-responder"].firstMatch
    XCTAssertTrue(responder.appears(within: 5), app.debugDescription)
    responder.tapWhenSettled()
    let haiku = app.descendants(matching: .any)["Haiku"].firstMatch
    XCTAssertTrue(haiku.appears(within: 5), app.debugDescription)
    haiku.tapWhenSettled()
    sleep(1)
    asking.press(forDuration: 1.2)
    let ask = app.buttons["Ask Haiku at my pauses"]
    XCTAssertTrue(ask.appears(within: 5), app.debugDescription)
    shot("whiteboard-ask-at-my-pauses-haiku")
    ask.tapUntilGone(took: { asking.exists && asking.label.hasPrefix("Ask at my pauses: on") })
    wait(asking, label: "Ask at my pauses: on, 2 showing", timeout: 5)
    asking.tap()
    wait(asking, label: "Ask at my pauses: off, 2 showing", timeout: 5)
    try aPauseAsksNoOne(app, cockpit, strokes: 3, atHeight: 0.65)
    XCTAssertEqual(asking.label, "Ask at my pauses: off, 2 showing", "Larry's marks stay")
  }
}
