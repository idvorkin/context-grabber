//  Stories 880, 882, 883, 885, 889, 1119, 1314–1317, 1273, 1274 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts
//  it): Larry puts a question card on the board, a tap opens it, an option answers it through the fake's /act, the card
//  keeps the question over the answer, opens read-only and folds to a chip that a tap opens out. Where cards land, the
//  open asks naming a board, the answers fetched for asks closed elsewhere and the eraser are `WhiteboardQuestionsTests`,
//  on the host. The fake Cockpit has no asks until a test asks for them, and this one takes them away again.

import XCTest

final class WhiteboardQuestionUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  override func tearDown() {
    if let cockpit { try? post(cockpit, "/fake/asks", ["open": false]) }
  }

  private var cockpit: String? {
    ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"].flatMap { $0.isEmpty ? nil : $0 }
  }

  private func post(_ cockpit: String, _ path: String, _ body: [String: Any]) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + path)))
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let done = expectation(description: "the fake Cockpit took \(path)")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// What the fake Cockpit was posted to /act, /close and /snooze.
  private func answers(_ cockpit: String) throws -> [[String: Any]] {
    var got: Data?
    let done = expectation(description: "the fake Cockpit answered")
    URLSession.shared.dataTask(with: try XCTUnwrap(URL(string: cockpit + "/fake/answers"))) { body, _, _ in
      got = body
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    let json = try JSONSerialization.jsonObject(with: try XCTUnwrap(got)) as? [String: Any]
    return try XCTUnwrap(json?["answers"] as? [[String: Any]])
  }

  /// A new board with a stroke and Larry's turn, then Larry's question for igor2-88g.879 on it (story 880): the app and
  /// the card. `other` gives the ask Larry's own-answer option, keyed other and labelled *Something else*.
  private func boardWithQuestion(_ cockpit: String, other: Bool = false) throws -> (XCUIApplication, XCUIElement) {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ask at my pauses: on") { ghosts.tap() }
    // A stroke and Larry's turn give the board its thread, where Larry then asks.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.6))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.6)))
    waitUntil(
      NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), app.buttons["whiteboard-send"], timeout: 8)
    app.buttons["whiteboard-send"].tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Larry: this is where it goes")).firstMatch
        .appears(within: 15), app.debugDescription)

    // Story 880: his question lands as a live card.
    try post(cockpit, "/fake/larry-asks", ["ask": "igor2-88g.879", "other": other])
    let card = app.buttons["whiteboard-question-igor2-88g.879"]
    XCTAssertTrue(card.appears(within: 10), app.debugDescription)
    waitUntil(NSPredicate(format: "label == %@", "? Renew the gym for a year? ···"), card, timeout: 8)
    return (app, card)
  }

  func testLarrysQuestionLandsAnswersAndFolds() throws {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-whiteboard-ui.sh") }
    let (app, card) = try boardWithQuestion(cockpit)

    // Story 882: a tap opens it; an option answers it as the Inbox would.
    card.tap()
    let option = app.buttons["decision-option-yes"]
    XCTAssertTrue(option.appears(within: 10), app.debugDescription)
    // Story 1130: the board's card has no Other of its own; its own answer is the field under it.
    XCTAssertFalse(app.buttons["decision-other"].exists, app.debugDescription)
    // Story 1119: the fold control takes the opened card back to its one line, answering nothing; a tap opens it again.
    app.buttons["decision-fold"].tap()
    XCTAssertTrue(option.waitForNonExistence(timeout: 5), "the popup closed: \(app.debugDescription)")
    XCTAssertEqual(card.label, "? Renew the gym for a year? ···", "still open, one line")
    card.tap()
    XCTAssertTrue(option.appears(within: 10), app.debugDescription)
    // Story 889 (#625): the own answer's mic sits immediately beside Send, after the field, both a finger's size.
    let field =
      app.textViews["whiteboard-question-words"].exists
      ? app.textViews["whiteboard-question-words"] : app.textFields["whiteboard-question-words"]
    let mic = app.buttons["whiteboard-question-mic"]
    let send = app.buttons["whiteboard-question-send"]
    XCTAssertTrue(mic.appears(within: 5), app.debugDescription)
    XCTAssertTrue(mic.isEnabled, "no call is live, so the mic is ready")
    XCTAssertEqual(mic.label, "Speak a message")
    XCTAssertLessThanOrEqual(field.frame.maxX, mic.frame.minX, "the field comes before the mic")
    XCTAssertLessThanOrEqual(mic.frame.maxX, send.frame.minX, "the mic comes before Send")
    XCTAssertLessThanOrEqual(send.frame.minX - mic.frame.maxX, 8, "the mic is right beside Send")
    for button in [mic, send] {
      XCTAssertGreaterThanOrEqual(button.frame.width, 44, button.identifier)
      XCTAssertGreaterThanOrEqual(button.frame.height, 44, button.identifier)
    }
    let bar = XCTAttachment(screenshot: app.screenshot())
    bar.name = "question-card-mic-by-send"
    bar.lifetime = .keepAlways
    add(bar)
    option.tap()
    // Story 883: the card keeps the question over the answer.
    waitUntil(NSPredicate(format: "label == %@", "✓ Renew the gym for a year?, Renew"), card, timeout: 10)
    let posted = try answers(cockpit).first { $0["id"] as? String == "igor2-88g.879" }
    XCTAssertEqual(posted?["path"] as? String, "/act")
    XCTAssertEqual(posted?["response"] as? String, "DECISION: Renew")

    // Story 885: read-only on a tap.
    card.tap()
    XCTAssertTrue(app.staticTexts["Renew"].appears(within: 5), app.debugDescription)
    app.buttons["whiteboard-question-close"].tap()
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "question-card-answered"
    picture.lifetime = .keepAlways
    add(picture)

    // Stories 885, 1321 (#1387 part 3): the strip's Collapse steps it full → short → round, the strip not moving;
    // a tap on the short opens it out.
    let collapse = app.buttons["whiteboard-question-collapse-igor2-88g.879"]
    XCTAssertTrue(collapse.appears(within: 5), app.debugDescription)
    let strip = collapse.frame
    collapse.tap()
    waitUntil(NSPredicate(format: "label == %@", "✓ Renew the gym for a year?"), card, timeout: 5)
    XCTAssertEqual(collapse.frame.minX, strip.minX, accuracy: 1, "the strip stays put between looks")
    XCTAssertEqual(collapse.frame.minY, strip.minY, accuracy: 1)
    XCTAssertTrue(app.buttons["whiteboard-question-openOut-igor2-88g.879"].exists, "Open out once it's not full")
    card.tap()
    waitUntil(NSPredicate(format: "label == %@", "✓ Renew the gym for a year?, Renew"), card, timeout: 5)

    // Story 1319: a double tap steps it full → short → round → full, and opens nothing.
    for label in ["✓ Renew the gym for a year?", "✓", "✓ Renew the gym for a year?, Renew"] {
      card.doubleTap()
      waitUntil(NSPredicate(format: "label == %@", label), card, timeout: 5)
    }
    XCTAssertFalse(app.buttons["whiteboard-question-close"].exists, "no popup")
  }

  /// Story 1130 (Igor, 2026-11-22): Larry's own-answer option, keyed other and labelled *Something else*, is in the
  /// popup's card; a tap sends nothing and puts the cursor in *Your own answer*, and only his words go.
  func testLarrysSomethingElseTakesTheCursorToTheOwnAnswer() throws {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-whiteboard-ui.sh") }
    let (app, card) = try boardWithQuestion(cockpit, other: true)
    card.tap()
    let larrys = app.buttons["decision-option-other"]
    XCTAssertTrue(larrys.appears(within: 10), app.debugDescription)
    XCTAssertTrue(larrys.label.contains("Something else"), larrys.label)
    XCTAssertFalse(app.buttons["decision-other"].exists, "no second Other: \(app.debugDescription)")
    let field =
      app.textViews["whiteboard-question-words"].exists
      ? app.textViews["whiteboard-question-words"] : app.textFields["whiteboard-question-words"]
    let send = app.buttons["whiteboard-question-send"]
    larrys.tap()
    waitUntil(NSPredicate(format: "hasKeyboardFocus == true"), field, timeout: 5)
    XCTAssertFalse(send.isEnabled, "Send is off until there are words")
    XCTAssertTrue(try answers(cockpit).filter { $0["id"] as? String == "igor2-88g.879" }.isEmpty, "nothing sent")
    field.typeText("Month to month")
    XCTAssertTrue(send.isEnabled)
    send.tap()
    waitUntil(NSPredicate(format: "label == %@", "✓ Renew the gym for a year?, Month to month"), card, timeout: 10)
    let posted = try answers(cockpit).filter { $0["id"] as? String == "igor2-88g.879" }
    XCTAssertEqual(posted.map { $0["response"] as? String }, ["DECISION: Month to month"], "\(posted)")
  }

  /// Stories 1273, 1274 (#1387): *Collapse* shrinks the open card to a bare '?' where its left end was, answering
  /// nothing; the '?' and the card drag and stay where they're let go, a drag opening nothing; a tap on the '?'
  /// brings the card back where the '?' is.
  func testAQuestionHidesToAMarkAndDrags() throws {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-whiteboard-ui.sh") }
    let (app, card) = try boardWithQuestion(cockpit)
    let line = "? Renew the gym for a year? ···"
    let whole = card.frame

    // #1387 part 3: Collapse is on the card's strip; an open card goes straight to its round.
    let hide = app.buttons["whiteboard-question-collapse-igor2-88g.879"]
    XCTAssertTrue(hide.appears(within: 10), app.debugDescription)
    hide.tap()
    waitUntil(NSPredicate(format: "label == %@", "?"), card, timeout: 5)
    XCTAssertFalse(hide.exists, "a round carries no strip")
    let mark = card.frame
    XCTAssertLessThan(mark.width, whole.width / 4, "a bare '?', not the card")
    XCTAssertEqual(mark.minX, whole.minX, accuracy: 2, "where the card's left end was")
    XCTAssertEqual(mark.minY, whole.minY, accuracy: 2)
    XCTAssertTrue(try answers(cockpit).filter { $0["id"] as? String == "igor2-88g.879" }.isEmpty, "nothing answered")
    let hidden = XCTAttachment(screenshot: app.screenshot())
    hidden.name = "question-card-hidden"
    hidden.lifetime = .keepAlways
    add(hidden)

    // Story 1274: the '?' drags and stays; a drag opens nothing.
    let from = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    from.press(forDuration: 0.2, thenDragTo: from.withOffset(CGVector(dx: 150, dy: 120)))
    XCTAssertFalse(app.buttons["decision-option-yes"].waitForExistence(timeout: 1), "a drag opens no popup")
    XCTAssertEqual(card.frame.minX, mark.minX + 150, accuracy: 12, app.debugDescription)
    XCTAssertEqual(card.frame.minY, mark.minY + 120, accuracy: 12, app.debugDescription)
    XCTAssertEqual(card.label, "?", "still hidden after the drag")

    // Story 1273: a tap brings the card back where the '?' is, and no popup opens.
    let moved = card.frame
    card.tap()
    waitUntil(NSPredicate(format: "label == %@", line), card, timeout: 5)
    XCTAssertFalse(app.buttons["decision-option-yes"].waitForExistence(timeout: 1), "showing it opens no popup")
    XCTAssertEqual(card.frame.minY, moved.minY, accuracy: 2)
    XCTAssertGreaterThan(card.frame.width, whole.width - 4, "the whole card again")

    // The card itself drags too, and a tap still opens it afterwards.
    let shown = card.frame
    let grab = card.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
    grab.press(forDuration: 0.2, thenDragTo: grab.withOffset(CGVector(dx: 0, dy: 160)))
    XCTAssertEqual(card.frame.minY, shown.minY + 160, accuracy: 12, app.debugDescription)
    XCTAssertFalse(app.buttons["decision-option-yes"].exists, "a drag opens no popup")
    card.tap()
    XCTAssertTrue(app.buttons["decision-option-yes"].appears(within: 10), app.debugDescription)
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "question-card-moved"
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// Stories 1314, 1315 (#1387): *Archive* takes the card off the board, answering nothing; the board menu's *Archived
  /// questions* lists it as open, and *Reopen* puts it back where it was.
  func testAQuestionArchivesAndReopens() throws {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-whiteboard-ui.sh") }
    let (app, card) = try boardWithQuestion(cockpit)
    let was = card.frame

    // #1387 part 3: Archive is on the card's strip.
    let archive = app.buttons["whiteboard-question-archive-igor2-88g.879"]
    XCTAssertTrue(archive.appears(within: 10), app.debugDescription)
    archive.tap()
    XCTAssertTrue(card.waitForNonExistence(timeout: 5), "the card left the board: \(app.debugDescription)")
    XCTAssertTrue(try answers(cockpit).filter { $0["id"] as? String == "igor2-88g.879" }.isEmpty, "nothing answered")

    app.buttons["whiteboard-board"].tap()
    let row = app.buttons["whiteboard-archived-questions"]
    XCTAssertTrue(row.appears(within: 5), app.debugDescription)
    XCTAssertEqual(row.label, "Archived questions (1)")
    row.tap()
    XCTAssertTrue(app.staticTexts["open"].appears(within: 5), "its answer, or open: \(app.debugDescription)")
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "question-archived-list"
    shot.lifetime = .keepAlways
    add(shot)
    app.buttons["whiteboard-archived-reopen-igor2-88g.879"].tap()
    XCTAssertTrue(card.appears(within: 5), "back on the board: \(app.debugDescription)")
    XCTAssertEqual(card.frame.minX, was.minX, accuracy: 2, "where it was")
    XCTAssertEqual(card.frame.minY, was.minY, accuracy: 2)
    XCTAssertEqual(card.label, "? Renew the gym for a year? ···", "as it was: open")
  }

  /// Stories 1316, 1317 (#1387): *Thinking* opens *Talk it over*; Igor's words go to the ask's own thread, Larry's
  /// reply comes into the popup, the card reads as thought over, and nothing is answered.
  func testThinkingTalksItOverWithLarry() throws {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-whiteboard-ui.sh") }
    let (app, card) = try boardWithQuestion(cockpit)

    card.tap()
    let thinking = app.buttons["whiteboard-question-thinking"]
    XCTAssertTrue(thinking.appears(within: 10), app.debugDescription)
    thinking.tap()
    let field =
      app.textViews["whiteboard-question-talk-words"].exists
      ? app.textViews["whiteboard-question-talk-words"] : app.textFields["whiteboard-question-talk-words"]
    XCTAssertTrue(field.appears(within: 5), app.debugDescription)
    field.tap()
    field.typeText("Month to month?")
    app.buttons["whiteboard-question-talk-send"].tap()

    let mine = app.staticTexts.matching(NSPredicate(format: "label == %@", "You: Month to month?")).firstMatch
    XCTAssertTrue(mine.appears(within: 10), app.debugDescription)
    let larry = app.staticTexts.matching(NSPredicate(format: "label == %@", "Larry: Larry heard: Month to month?"))
      .firstMatch
    XCTAssertTrue(larry.appears(within: 15), "his reply comes into the card: \(app.debugDescription)")
    XCTAssertTrue(app.buttons["decision-option-yes"].exists, "an option can still answer it")
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "question-thinking"
    shot.lifetime = .keepAlways
    add(shot)
    XCTAssertTrue(try answers(cockpit).filter { $0["id"] as? String == "igor2-88g.879" }.isEmpty, "nothing answered")

    app.buttons["whiteboard-question-close"].tap()
    waitUntil(NSPredicate(format: "label == %@", "… Renew the gym for a year? ···"), card, timeout: 5)
  }
}
