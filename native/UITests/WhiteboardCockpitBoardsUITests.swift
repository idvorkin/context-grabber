//  Stories 1339-1340, 1344-1346 (cockpit-8kh) on an iPad simulator, against the fake Cockpit
//  (scripts/native/test-whiteboard-ui.sh starts it): with Boards from the Cockpit (beta) off, the boards list is as
//  before; on, a *From the Cockpit* section lists the store's boards with their versions, and a board opens on the
//  trial canvas: a stroke drawn is saved, a refused one goes back with its note, ink on a deleted board is kept. The requests, the rows and the sync pass are
//  `CockpitBoardStoreTests`, on the host.

import XCTest

final class WhiteboardCockpitBoardsUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private var cockpit: String {
    get throws {
      try XCTUnwrap(
        ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    }
  }

  /// A board in the fake's store, made the way a device makes one (`POST /boards`).
  private func makeBoard(_ id: String, name: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: try cockpit + "/boards")))
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: ["id": id, "name": name, "device": "web-3f9a"])
    let done = expectation(description: "the fake Cockpit made the board")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// POSTs `body` to one of the fake's own routes.
  private func fake(_ path: String, _ body: [String: Any]) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: try cockpit + path)))
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let done = expectation(description: "the fake Cockpit took \(path)")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// The fake's copy of a board: `GET /boards/<id>`.
  private func snapshot(_ id: String) throws -> [String: Any] {
    let url = try XCTUnwrap(URL(string: try cockpit + "/boards/" + id))
    var answer: [String: Any] = [:]
    let done = expectation(description: "the fake Cockpit gave the board")
    URLSession.shared.dataTask(with: url) { data, _, _ in
      answer = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    return answer
  }

  private func strokes(_ snapshot: [String: Any]) -> Int {
    ((snapshot["things"] as? [[String: Any]]) ?? []).filter { $0["kind"] as? String == "stroke" }.count
  }

  /// Opens the board from *From the Cockpit* and waits for its canvas.
  private func open(_ id: String, _ app: XCUIApplication) -> XCUIElement {
    let row = app.descendants(matching: .any)["cockpit-board-\(id)"]
    XCTAssertTrue(row.appears(within: 20), app.debugDescription)
    row.tap()
    let canvas = app.descendants(matching: .any)["cockpit-board-canvas"]
    XCTAssertTrue(canvas.appears(within: 15), app.debugDescription)
    return canvas
  }

  private func draw(on canvas: XCUIElement, at y: CGFloat) {
    canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: y))
      .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: y + 0.05)))
  }

  private func waitFor(_ label: String, on element: XCUIElement, _ app: XCUIApplication) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: 20)
  }

  private func launch(switchOn: Bool) throws -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit
    app.launchArguments += ["-whiteboard_boards_from_cockpit", switchOn ? "YES" : "NO"]
    app.launch()
    return app
  }

  /// Story 1339: off, the list is the iPad's own boards and nothing from the Cockpit.
  func testOffTheListHasNoCockpitSection() throws {
    try makeBoard("ui-store-off", name: "Not listed")
    let app = try launch(switchOn: false)
    XCTAssertTrue(app.buttons["whiteboard-new"].appears(within: 20), app.debugDescription)
    sleep(2)
    XCTAssertFalse(app.descendants(matching: .any)["cockpit-board-ui-store-off"].exists, app.debugDescription)
    XCTAssertFalse(app.staticTexts["From the Cockpit"].exists, app.debugDescription)
  }

  /// Story 1340: on, the Cockpit's board is listed above the iPad's own, with its versions.
  func testOnTheListShowsTheCockpitsBoards() throws {
    try makeBoard("ui-store-on", name: "Store trial")
    let app = try launch(switchOn: true)
    let row = app.descendants(matching: .any)["cockpit-board-ui-store-on"]
    XCTAssertTrue(row.appears(within: 20), app.debugDescription)
    XCTAssertTrue(row.label.contains("Store trial"), row.label)
    XCTAssertTrue(row.label.contains("versions"), row.label)
    XCTAssertTrue(app.staticTexts["From the Cockpit"].exists, app.debugDescription)
  }

  /// Stories 1344-1345: a stroke drawn is saved to the Cockpit; a stroke the Cockpit refuses goes back off the canvas,
  /// with a copyable note.
  func testADrawnStrokeIsSavedAndARefusedOneGoesBack() throws {
    let id = "ui-draw-" + UUID().uuidString.prefix(8).lowercased()
    try makeBoard(id, name: "Draw trial")
    let app = try launch(switchOn: true)
    let canvas = open(id, app)
    let status = app.staticTexts["cockpit-board-status"]
    let count = app.staticTexts["cockpit-board-strokes"]
    draw(on: canvas, at: 0.3)
    waitFor("Saved · version 1", on: status, app)
    XCTAssertEqual(strokes(try snapshot(id)), 1, "the Cockpit holds the stroke")

    try fake(
      "/fake/store-next",
      [
        "refused": [
          [
            "op": 0, "id": "s-x", "reason": "changed", "rev": 1, "device": "web-3f9a",
            "by": "igor", "at": "2026-11-25T10:00:00Z",
          ]
        ]
      ])
    draw(on: canvas, at: 0.6)
    waitFor("1 stroke", on: count, app)
    XCTAssertTrue(
      app.descendants(matching: .any)["cockpit-board-note"].firstMatch.appears(within: 10), app.debugDescription)
    XCTAssertEqual(strokes(try snapshot(id)), 1, "the refused stroke never reached the Cockpit")
  }

  /// Story 1346: ink drawn on a board deleted elsewhere is kept as a new board.
  func testInkOnADeletedBoardIsKeptAsANewBoard() throws {
    let id = "ui-gone-" + UUID().uuidString.prefix(8).lowercased()
    try makeBoard(id, name: "Gone trial")
    let app = try launch(switchOn: true)
    let canvas = open(id, app)
    waitFor("Saved · version 0", on: app.staticTexts["cockpit-board-status"], app)
    try fake(
      "/fake/store-remote", ["board": id, "device": "web-3f9a", "ops": [["op": "delete_board", "ids": ["@board"]]]])
    draw(on: canvas, at: 0.4)
    let keep = app.buttons["cockpit-board-keep-ink"]
    XCTAssertTrue(keep.appears(within: 20), app.debugDescription)
    keep.tap()
    waitFor("Gone trial (kept ink)", on: app.navigationBars.staticTexts.element(boundBy: 0), app)
    waitFor("Saved · version 1", on: app.staticTexts["cockpit-board-status"], app)
  }
}
