//  Story 1203 (bead context-grabber-9bll) on the iPad simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it): after an Undo, ink near the change that the view doesn't show is drawn again, and Undo and Redo still take
//  one step each. The simulator misses only now and then, so `GRABBER_WHITEBOARD_UNDO_LOOK=miss` makes the first look
//  after a step take what it checks as missing, and the heal runs every time. Igor's line is read from the screen's
//  pixels (`PaperScreen`, in WhiteboardPaperGhostsUITests.swift), in black; Larry's kept marks in his purple.

import XCTest

final class WhiteboardUndoRedrawUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  private func post(_ path: String, _ body: String, _ cockpit: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + path)))
    request.httpMethod = "POST"
    request.httpBody = Data(body.utf8)
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// A line of Igor's across the middle, Larry's three circles kept as one group, Ghosts off, and a second line lower down.
  private func linesAndKeptGroup(_ app: XCUIApplication) throws {
    let cockpit = try cockpit()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_WHITEBOARD_GHOST_SECONDS"] = "600"
    app.launchEnvironment["GRABBER_WHITEBOARD_UNDO_LOOK"] = "miss"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    // d455: the switch was renamed from "Ghosts" to "Ask at my pauses" (767aabac), so a "Ghosts on" check never
    // matched and the board asked at every pause: on a loaded Mac a pause turn's circle made "4 to keep", not 3.
    if ghosts.label.hasPrefix("Ask at my pauses: on") { ghosts.tap() }
    let off = NSPredicate(format: "label BEGINSWITH %@", "Ask at my pauses: off")
    XCTAssertEqual(
      XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: off, object: ghosts)], timeout: 5), .completed,
      "Ask at my pauses is off, so no pause turn: \(ghosts.label)")
    let pen = app.buttons["Pen"]
    XCTAssertTrue(pen.appears(within: 10), "the tool picker: \(app.debugDescription)")
    if !pen.isSelected { pen.tap() }
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    try WhiteboardWordsOnlyFixture.prepare(cockpit, for: self)
    send.tap()
    XCTAssertTrue(WhiteboardWordsOnlyFixture.reply(in: app).appears(within: 15), app.debugDescription)
    try post("/fake/larry-draws", #"{"count": 3}"#, cockpit)
    let toKeep = app.staticTexts.matching(NSPredicate(format: "label == %@", "3 to keep")).firstMatch
    XCTAssertTrue(toKeep.appears(within: 10), app.debugDescription)
    let keepAll = app.buttons["whiteboard-keep-all"]
    XCTAssertTrue(keepAll.appears(within: 5), app.debugDescription)
    keepAll.tap()
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 4 strokes"), send, timeout: 10)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.65))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.65)))
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 5 strokes"), send, timeout: 10)
  }

  /// My lower line's two halves, left and right of the screen's middle (the right one is where the simulator left a tile
  /// blank, context-grabber-9bll).
  private func half(_ right: Bool) -> (PaperScreen) -> PaperScreen.Box? {
    { $0.ink(in: PaperScreen.Box(minX: right ? 0.5 : 0, minY: 0.58, maxX: right ? 1 : 0.5, maxY: 1)) }
  }

  func testAnUndoThatLeavesInkUndrawnDrawsItAgainAndRedoStillWorks() throws {
    let app = XCUIApplication.forTests(animated: true)
    try linesAndKeptGroup(app)
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his circles kept")
    let left = try XCTUnwrap(PaperScreen.settled(app, half(false)), "my lower line, left of the middle")
    let right = try XCTUnwrap(PaperScreen.settled(app, half(true)), "my lower line, right of the middle")

    // A tap on one circle selects the group (story 947); a finger drags it down onto my lower line.
    PaperScreen.tap(app, CGPoint(x: kept.minX + 0.003, y: kept.center.y))
    XCTAssertTrue(app.selectionLabel.appears(within: 5), "the tap selected it: \(app.debugDescription)")
    sleep(2)
    let dy = left.center.y - kept.center.y
    let from = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y))
    let to = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y + dy))
    from.press(forDuration: 0.3, thenDragTo: to, withVelocity: 200, thenHoldForDuration: 0.5)
    let dropped = PaperScreen.showing(app, within: 10, { $0.larryKept }, { $0.minY > kept.maxY + 0.05 })
    shot(app, "dropped near my line")
    let down = try XCTUnwrap(dropped, "the group moved down")

    let undo = app.buttons["whiteboard-undo"]
    let redo = app.buttons["whiteboard-redo"]
    waitUntil(NSPredicate(format: "isEnabled == true"), undo, timeout: 5)
    undo.tap()
    // The forced miss, the strokes put back, and the look after them finding everything drawn.
    let look = app.staticTexts["whiteboard-undo-look"]
    waitUntil(NSPredicate(format: "label BEGINSWITH %@", "missing,whole"), look, timeout: 10)
    XCTAssertEqual(look.value as? String, "1", "one heal, the strokes taken out and put back")
    let groupBack = PaperScreen.showing(app, within: 10, { $0.larryKept }, { abs($0.minY - kept.minY) < 0.01 })
    let leftBack = PaperScreen.showing(app, within: 10, half(false), { abs($0.minY - left.minY) < 0.01 })
    let rightBack = PaperScreen.showing(app, within: 10, half(true), { abs($0.maxX - right.maxX) < 0.01 })
    shot(app, "after one undo")
    XCTAssertEqual(groupBack?.minY ?? -1, kept.minY, accuracy: 0.01, "one Undo put the group back")
    XCTAssertEqual(leftBack?.minY ?? -1, left.minY, accuracy: 0.01, "my line's left half is drawn")
    XCTAssertEqual(rightBack?.maxX ?? -1, right.maxX, accuracy: 0.01, "and its right half, to its end")
    XCTAssertEqual(app.buttons["whiteboard-send"].label, "Send to Larry, 5 strokes", "nothing added or lost")

    // Redo takes the one step back down, and Undo the one step up again: the heal added none.
    waitUntil(NSPredicate(format: "isEnabled == true"), redo, timeout: 5)
    redo.tap()
    let again = PaperScreen.showing(app, within: 10, { $0.larryKept }, { abs($0.minY - down.minY) < 0.02 })
    shot(app, "after redo")
    XCTAssertEqual(again?.minY ?? -1, down.minY, accuracy: 0.02, "Redo took it down again")
    undo.tap()
    let upAgain = PaperScreen.showing(app, within: 10, { $0.larryKept }, { abs($0.minY - kept.minY) < 0.01 })
    XCTAssertEqual(upAgain?.minY ?? -1, kept.minY, accuracy: 0.01, "and Undo back up, one step each")
    XCTAssertEqual(app.buttons["whiteboard-send"].label, "Send to Larry, 5 strokes", "nothing added or lost")
  }
}
