//  Stories 880, 882, 883, 885, 889, 1119 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts
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
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }
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

    // Story 885: read-only on a tap, folded to a chip, opened out by a tap.
    card.tap()
    let collapse = app.buttons["whiteboard-question-collapse"]
    XCTAssertTrue(collapse.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.staticTexts["Renew"].exists, app.debugDescription)
    collapse.tap()
    waitUntil(NSPredicate(format: "label == %@", "✓ Renew the gym for a year?"), card, timeout: 5)
    card.tap()
    waitUntil(NSPredicate(format: "label == %@", "✓ Renew the gym for a year?, Renew"), card, timeout: 5)
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "question-card-answered"
    picture.lifetime = .keepAlways
    add(picture)
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
}
