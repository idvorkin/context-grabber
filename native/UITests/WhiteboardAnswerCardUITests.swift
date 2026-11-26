//  Answer cards (#1439, stories 1355-1357) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it): Larry's answer lands as his card and folds like an answered card; an answer naming a question card answers
//  it. Where they land and what they say are `WhiteboardAnswerCardsTests`, on the host.

import XCTest

final class WhiteboardAnswerCardUITests: XCTestCase {
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

  /// A new board with a stroke and Larry's turn, so it has a thread for Larry to answer on.
  private func boardWithThread(_ cockpit: String) -> XCUIApplication {
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
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.6))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.6)))
    waitUntil(
      NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), app.buttons["whiteboard-send"], timeout: 8)
    app.buttons["whiteboard-send"].tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Larry: this is where it goes")).firstMatch
        .appears(within: 15), app.debugDescription)
    return app
  }

  /// Stories 1355, 1357: Larry's answer lands as his card, *Larry · <title>* over his words; a tap opens it read-only,
  /// and Collapse takes it to its title line.
  func testLarrysAnswerLandsAsHisCardAndFolds() throws {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-whiteboard-ui.sh") }
    let app = boardWithThread(cockpit)
    try post(cockpit, "/fake/larry-answers", ["title": "Gym", "text": "Renew it: you went three times a week."])
    let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Larry · Gym")).firstMatch
    XCTAssertTrue(card.appears(within: 10), app.debugDescription)
    XCTAssertEqual(card.label, "Larry · Gym, Renew it: you went three times a week.")
    let landed = XCTAttachment(screenshot: app.screenshot())
    landed.name = "answer-card-landed"
    landed.lifetime = .keepAlways
    add(landed)
    card.tap()
    XCTAssertTrue(app.staticTexts["Larry · Gym"].appears(within: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["whiteboard-question-send"].exists, "nothing to answer")
    app.buttons["whiteboard-question-close"].tap()
    let collapse = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "whiteboard-question-collapse-answer:")
    )
    .firstMatch
    XCTAssertTrue(collapse.appears(within: 5), app.debugDescription)
    collapse.tap()
    waitUntil(NSPredicate(format: "label == %@", "Larry · Gym"), card, timeout: 5)
  }

  /// Story 1356: an answer that names a question card folds it to *✓ <the answer's title>*, and the answer card lands
  /// under it, as on the web board.
  func testAnAnswerNamingAQuestionCardAnswersIt() throws {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-whiteboard-ui.sh") }
    let app = boardWithThread(cockpit)
    try post(cockpit, "/fake/larry-asks", ["ask": "igor2-88g.879"])
    let card = app.buttons["whiteboard-question-igor2-88g.879"]
    XCTAssertTrue(card.appears(within: 10), app.debugDescription)
    waitUntil(NSPredicate(format: "label == %@", "? Renew the gym for a year? ···"), card, timeout: 8)
    try post(
      cockpit, "/fake/larry-answers", ["title": "Renew", "text": "Yes, renew it.", "re": "igor2-88g.879", "y": 300])
    waitUntil(NSPredicate(format: "label == %@", "✓ Renew"), card, timeout: 10)
    let answer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Larry · Renew")).firstMatch
    XCTAssertTrue(answer.appears(within: 5), app.debugDescription)
    XCTAssertGreaterThan(answer.frame.minY, card.frame.minY, "the answer card is under the question")
    XCTAssertEqual(answer.frame.minX, card.frame.minX, accuracy: 2)
  }
}
