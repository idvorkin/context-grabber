//  Stories 1361-1363 (cockpit-8kh) on an iPad simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it): with the beta switch on, a board made before it was on is sent to the Cockpit from its Board menu (its
//  own id, its ink, the original drawing as an asset) and a stroke drawn after it follows; a board made with + while the
//  switch is on is mirrored from its first save. The ids, the cut into saves and the gate are `CockpitBoardMirrorTests`, on the host.

import XCTest

final class WhiteboardStoreMirrorUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private var cockpit: String {
    get throws {
      try XCTUnwrap(
        ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    }
  }

  private func get(_ path: String) throws -> [String: Any] {
    let url = try XCTUnwrap(URL(string: try cockpit + path))
    var answer: [String: Any] = [:]
    let done = expectation(description: "the fake Cockpit answered \(path)")
    URLSession.shared.dataTask(with: url) { data, _, _ in
      answer = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    return answer
  }

  /// The fake's board named `name`, and how many strokes it holds; nil until the Cockpit has it.
  private func board(named name: String) throws -> (id: String, strokes: Int)? {
    let rows = (try get("/boards")["boards"] as? [[String: Any]]) ?? []
    guard let id = rows.first(where: { $0["name"] as? String == name })?["id"] as? String else { return nil }
    let things = (try get("/boards/" + id)["things"] as? [[String: Any]]) ?? []
    return (id, things.filter { $0["kind"] as? String == "stroke" }.count)
  }

  private func waitForStrokes(_ count: Int, named name: String) throws -> String {
    let deadline = Date().addingTimeInterval(30)
    while Date() < deadline {
      if let found = try board(named: name), found.strokes == count { return found.id }
      sleep(1)
    }
    XCTFail(
      "the Cockpit never had \(count) strokes on \(name): \(try board(named: name).map { "\($0)" } ?? "no board")")
    return ""
  }

  private func launch(switchOn: Bool = true) throws -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit
    app.launchArguments += ["-whiteboard_boards_from_cockpit", switchOn ? "YES" : "NO"]
    app.launch()
    return app
  }

  private func stroke(_ app: XCUIApplication, at y: CGFloat) {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: y))
    start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: y + 0.04)))
  }

  /// A new board, ghosts off so a stroke asks nothing of Larry, renamed to `name`.
  private func newBoard(_ app: XCUIApplication, named name: String) {
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ask at my pauses: on") { ghosts.tap() }
    let title = app.buttons["whiteboard-title"]
    XCTAssertTrue(title.appears(within: 10), app.debugDescription)
    let before = title.label
    title.tap()
    let field = app.alerts.textFields.firstMatch
    XCTAssertTrue(field.appears(within: 5), app.debugDescription)
    field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: before.count + 2) + name)
    app.alerts.buttons["Rename"].tap()
    waitUntil(NSPredicate(format: "label == %@", name), title, timeout: 8)
  }

  private func waitForStrokesSent(_ count: Int, _ app: XCUIApplication) {
    waitUntil(
      NSPredicate(format: "label == %@", "Send to Larry, \(count) strokes"), app.buttons["whiteboard-send"], timeout: 8)
  }

  /// Story 1361, with story 1362's stable ids under it: a board made before the switch was on is sent from its Board
  /// menu; the Cockpit has it under its own id with its ink and the original drawing, and a stroke after follows.
  func testABoardIsSentFromItsMenuAndAStrokeAfterFollows() throws {
    let name = "Main board \(UUID().uuidString.prefix(6))"
    var app = try launch(switchOn: false)
    newBoard(app, named: name)
    sleep(1)
    stroke(app, at: 0.35)
    stroke(app, at: 0.5)
    waitForStrokesSent(2, app)
    app.buttons["BackButton"].firstMatch.tap()
    sleep(2)
    app.terminate()
    XCTAssertNil(try board(named: name), "with the switch off, nothing went to the Cockpit")

    app = try launch(switchOn: true)
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    XCTAssertTrue(row.appears(within: 20), app.debugDescription)
    row.tap()
    XCTAssertTrue(app.buttons["whiteboard-board"].appears(within: 10), app.debugDescription)
    app.buttons["whiteboard-board"].tap()
    let send = app.buttons["whiteboard-mirror-send"]
    XCTAssertTrue(send.appears(within: 5), app.debugDescription)
    send.tap()
    let id = try waitForStrokes(2, named: name)

    let store = try get("/fake/store")
    XCTAssertFalse(((store["assets"] as? [String: Any]) ?? [:]).isEmpty, "the original drawing is kept: \(store)")
    let things = (try get("/boards/" + id)["things"] as? [[String: Any]]) ?? []
    let body = things.first { $0["id"] as? String == "@board" }?["body"] as? [String: Any]
    XCTAssertNotNil(body?["original_asset"], "the create names the original drawing: \(String(describing: body))")

    stroke(app, at: 0.65)
    _ = try waitForStrokes(3, named: name)
  }

  /// Story 1361: a board made with + while the switch is on is mirrored from its first save, with no tap.
  func testANewBoardWithTheSwitchOnIsMirroredFromItsFirstSave() throws {
    let app = try launch(switchOn: true)
    let name = "New board \(UUID().uuidString.prefix(6))"
    newBoard(app, named: name)
    sleep(1)
    stroke(app, at: 0.4)
    waitForStrokesSent(1, app)
    _ = try waitForStrokes(1, named: name)
    app.buttons["whiteboard-board"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["whiteboard-mirror-status"].appears(within: 10), app.debugDescription)
  }

  /// The fake's things of `kind` on board `id`.
  private func things(_ kind: String, on id: String) throws -> [[String: Any]] {
    ((try get("/boards/" + id)["things"] as? [[String: Any]]) ?? []).filter { $0["kind"] as? String == kind }
  }

  /// Story 1368: a mirrored board's header goes to the Cockpit over its strokes, and folding it changes only it.
  func testAMirroredBoardsHeaderAndFoldReachTheCockpit() throws {
    let app = try launch(switchOn: true)
    let name = "Meaning board \(UUID().uuidString.prefix(6))"
    newBoard(app, named: name)
    sleep(1)
    let at = { (x: CGFloat, y: CGFloat) in app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)) }
    at(0.12, 0.30).press(forDuration: 0.05, thenDragTo: at(0.4, 0.31))
    at(0.2, 0.36).press(forDuration: 0.05, thenDragTo: at(0.5, 0.37))
    waitForStrokesSent(2, app)
    let id = try waitForStrokes(2, named: name)
    // The margin's left 64 board points: a tap there beside the first line makes it a header (story 855).
    at(0.025, 0.305).tap()
    let deadline = Date().addingTimeInterval(30)
    var headers: [[String: Any]] = []
    while Date() < deadline {
      headers = try things("header", on: id)
      if !headers.isEmpty { break }
      sleep(1)
    }
    let seen = try get("/boards/" + id)
    XCTAssertEqual(headers.count, 1, "the header reached the Cockpit: \(seen)")
    let body = headers.first?["body"] as? [String: Any]
    XCTAssertEqual((body?["ids"] as? [String])?.count, 1, "over the first line's stroke: \(String(describing: body))")
    XCTAssertTrue((body?["ids"] as? [String] ?? []).allSatisfy { $0.hasPrefix("s-") }, "by the mirror's stroke ids")
    // A tap on its mark folds the indented line under it: the Cockpit's header gains `folded`.
    at(0.025, 0.305).tap()
    let foldBy = Date().addingTimeInterval(30)
    var folded: [String: Any]?
    while Date() < foldBy {
      folded = (try things("header", on: id).first?["body"] as? [String: Any])?["folded"] as? [String: Any]
      if folded != nil { break }
      sleep(1)
    }
    let after = try get("/boards/" + id)
    XCTAssertNotNil(folded, "the fold went with its header: \(after)")
  }
}
