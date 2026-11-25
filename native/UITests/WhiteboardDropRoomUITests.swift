//  Story 1172 (bead context-grabber-9uj2) on the iPad simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it): a kept group of Larry's dragged onto Igor's writing pushes the writing down, and one Undo puts both back.
//  Where things sit is read from the screen's pixels (`PaperScreen`, in WhiteboardPaperGhostsUITests.swift): Igor's line
//  in black, Larry's kept marks in his purple. On the simulator a tap selects the group, so this is the selected path;
//  the iPad's drag from PaperKit's handwriting view with nothing selected is `PaperProbePickupTests` on the host.

import XCTest

final class WhiteboardDropRoomUITests: XCTestCase {
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

  private func toKeep(_ app: XCUIApplication, _ count: Int) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label == %@", "\(count) to keep")).firstMatch
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// A line of Igor's across the middle, and Larry's three circles kept as one group, Ghosts off.
  private func lineAndKeptGroup(_ app: XCUIApplication) throws {
    let cockpit = try cockpit()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_WHITEBOARD_GHOST_SECONDS"] = "600"
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
    XCTAssertTrue(toKeep(app, 3).appears(within: 10), app.debugDescription)
    XCTAssertNotNil(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    let keepAll = app.buttons["whiteboard-keep-all"]
    XCTAssertTrue(keepAll.appears(within: 5), app.debugDescription)
    keepAll.tap()
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 4 strokes"), send, timeout: 10)
  }

  /// Black ink below `y`, right of the group and its menu and label: the line the group is dropped on.
  private func lower(below y: CGFloat) -> (PaperScreen) -> PaperScreen.Box? {
    { $0.ink(in: PaperScreen.Box(minX: 0.5, minY: y, maxX: 1, maxY: 1)) }
  }

  func testAGroupDroppedOnMyLinePushesItDownAndOneUndoPutsBothBack() throws {
    let app = XCUIApplication.forTests(animated: true)
    try lineAndKeptGroup(app)
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his circles kept")
    // His circles sit by the line he answered; a second line lower down is the one the group is dropped on.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.65))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.65)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 5 strokes"), send, timeout: 10)
    let first = try XCTUnwrap(
      PaperScreen.settled(app) { $0.ink(in: PaperScreen.Box(minX: 0, minY: 0, maxX: 1, maxY: 0.58)) })
    let mine = try XCTUnwrap(PaperScreen.settled(app, lower(below: 0.58)), "my second line")
    shot(app, "my lines and the kept group")

    // A tap on one circle selects the group (story 947); a finger drags it onto my second line.
    PaperScreen.tap(app, CGPoint(x: kept.minX + 0.003, y: kept.center.y))
    XCTAssertTrue(app.selectionLabel.appears(within: 5), "the tap selected it: \(app.debugDescription)")
    sleep(2)
    // PaperKit holds a drag about 20 points before the group starts to move (bead context-grabber-o1x8: 213 points of
    // finger moved it 193 to 196). Aimed centre on centre it landed about 20 points high and only grazed the line, 2
    // points either side of opening no room. Aim that much further so it lands across the line.
    let slop = 20 / app.frame.height
    let dy = mine.center.y - kept.center.y + slop
    let from = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y))
    let to = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y + dy))
    from.press(forDuration: 0.3, thenDragTo: to, withVelocity: 200, thenHoldForDuration: 0.5)

    let dropped = PaperScreen.showing(app, within: 10, { $0.larryKept }, { abs($0.center.y - mine.center.y) < 0.03 })
    let pushed = PaperScreen.showing(
      app, within: 10, lower(below: 0.58),
      { box in box.minY > mine.minY + 0.01 && (dropped.map { box.minY > $0.maxY } ?? false) })
    shot(app, "dropped on my line")
    let group = try XCTUnwrap(dropped, "the group stays where I let go")
    let line = try XCTUnwrap(pushed, "my second line went down clear of the group (a drop that missed opens no room)")
    XCTAssertGreaterThan(line.minY, group.maxY, "my line moved down clear of the group: \(line) under \(group)")
    XCTAssertEqual(line.maxX, mine.maxX, accuracy: 0.01, "straight down")
    let above = PaperScreen(app).ink(in: PaperScreen.Box(minX: 0, minY: 0, maxX: 1, maxY: 0.58))
    XCTAssertEqual(above?.minY ?? -1, first.minY, accuracy: 0.005, "the line above the cut stays")
    XCTAssertEqual(send.label, "Send to Larry, 5 strokes", "moved, not drawn")

    let undo = app.buttons["whiteboard-undo"]
    waitUntil(NSPredicate(format: "isEnabled == true"), undo, timeout: 5)
    undo.tap()
    let lineBack = PaperScreen.showing(app, within: 10, lower(below: 0.58), { abs($0.minY - mine.minY) < 0.01 })
    let groupBack = PaperScreen.showing(app, within: 10, { $0.larryKept }, { abs($0.minY - kept.minY) < 0.01 })
    shot(app, "after one undo")
    XCTAssertEqual(lineBack?.minY ?? -1, mine.minY, accuracy: 0.01, "one Undo put my line back")
    XCTAssertEqual(groupBack?.minY ?? -1, kept.minY, accuracy: 0.01, "and the group back where it was")
  }
}
