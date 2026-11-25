//  Story 1140 (#1171) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): Larry's
//  three circles, each its own reply, kept one at a time with Keep, each its own thing; a finger tap on the first selects that circle alone (its Delete
//  takes it and leaves the other two), and one Undo puts it back. A finger drag of a selection is story 947's test. Where the circles sit is read from the screen's pixels (`PaperScreen`,
//  in WhiteboardPaperGhostsUITests.swift); what is selected, from the selection's label (story 1095). Which
//  strokes a tap reaches is `BoardOutlineTests.testAFingerTapOnOneThingOfLarrysTakesItAlone`.

import XCTest

final class WhiteboardTheirsTapUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  /// `separate`: each circle its own reply of his (story 1154: Keep beside a mark keeps its whole reply).
  private func larryDraws(_ count: Int, _ cockpit: String, separate: Bool = false) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/larry-draws")))
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"count": \#(count), "separate": \#(separate)}"#.utf8)
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

  /// A board with one stroke of mine sent to Larry, and his three circles in a row showing, faint, to keep.
  private func boardWithHisCircles(separate: Bool) throws -> XCUIApplication {
    let cockpit = try cockpit()
    let app = XCUIApplication.forTests(animated: true)
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
    if ghosts.label.hasPrefix("Ask at my pauses: on") { ghosts.tap() }  // Ghosts off: only Larry's marks show.
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    try WhiteboardWordsOnlyFixture.prepare(cockpit, for: self)
    app.buttons["whiteboard-send"].tap()
    XCTAssertTrue(WhiteboardWordsOnlyFixture.reply(in: app).appears(within: 15), app.debugDescription)
    try larryDraws(3, cockpit, separate: separate)
    XCTAssertTrue(toKeep(app, 3).appears(within: 10), app.debugDescription)
    return app
  }

  func testAFingerTapOnOneOfLarrysKeptMarksSelectsItAlone() throws {
    let app = try boardWithHisCircles(separate: true)
    let send = app.buttons["whiteboard-send"]
    // Three circles in a row, three replies of his, kept one at a time with Keep, each its own thing: three circles of one
    // reply would be kept as one group by any Keep (story 1154) or Keep all (story 995; bead context-grabber-yqau).
    let marks = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    let keep = app.buttons["whiteboard-mark-keep"]
    for circle in 0..<3 {
      PaperScreen.tap(app, CGPoint(x: marks.minX + CGFloat(circle) * marks.width / 3 + 0.003, y: marks.center.y))
      XCTAssertTrue(keep.appears(within: 5), "circle \(circle) chosen: \(app.debugDescription)")
      keep.tap()
      XCTAssertTrue(keep.waitForNonExistence(timeout: 5), "circle \(circle) kept")
    }
    XCTAssertFalse(toKeep(app, 1).exists, "none left to keep")
    waitUntil(NSPredicate(format: "label != %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    let label = send.label
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his three circles in his purple")
    let selected = app.selectionLabel
    XCTAssertFalse(selected.exists, "nothing selected yet")
    shot(app, "kept all")

    // The first circle's left side: the circles are 40 board points wide, touching, so the first is the left third.
    PaperScreen.tap(app, CGPoint(x: kept.minX + 0.003, y: kept.center.y))
    XCTAssertTrue(selected.appears(within: 5), "the tap selected ink: \(app.debugDescription)")
    sleep(2)  // past the selection PaperKit makes of the same tap, and its dot
    XCTAssertTrue(selected.exists, "still selected a beat later")
    XCTAssertEqual(send.label, label, "no dot drawn for the tap")
    shot(app, "one circle selected by a tap")

    // One circle is too small to drag by its middle (PaperKit's handles cover it, and a drag there resizes it), so its
    // Delete shows what the tap selected: the first circle goes, the other two stay.
    let delete = app.buttons["Delete"].firstMatch
    XCTAssertTrue(delete.appears(within: 5), app.debugDescription)
    delete.tap()
    let gone = PaperScreen.showing(app, { $0.larryKept }, { $0.minX > kept.minX + kept.width / 4 })
    shot(app, "the selected circle deleted")
    let after = try XCTUnwrap(gone, "his other two circles, after the Delete")
    XCTAssertEqual(after.maxX, kept.maxX, accuracy: 0.01, "the other two stayed: \(kept) to \(after)")
    XCTAssertEqual(after.width, kept.width * 2 / 3, accuracy: kept.width / 6, "one of three went: \(kept) to \(after)")

    let undo = app.buttons["whiteboard-undo"]
    waitUntil(NSPredicate(format: "isEnabled == true"), undo, timeout: 5)
    undo.tap()
    sleep(1)
    // The Undo selects the circle again, and To text beside it covers the other two: a tap on blank paper puts it away.
    PaperScreen.tap(app, CGPoint(x: kept.center.x, y: kept.maxY + 0.2))
    let back = PaperScreen.showing(app, { $0.larryKept }, { abs($0.width - kept.width) < 0.01 })
    shot(app, "after one undo")
    XCTAssertEqual(try XCTUnwrap(back).width, kept.width, accuracy: 0.01, "one Undo put it back")
  }

  /// Story 1154 (bead context-grabber-it0e): Keep beside one circle of a reply of three keeps all three, as one group, and
  /// one Undo takes all three back.
  func testKeepBesideOneMarkOfAReplyKeepsTheWholeReply() throws {
    let app = try boardWithHisCircles(separate: false)
    let marks = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    PaperScreen.tap(app, CGPoint(x: marks.minX + 0.003, y: marks.center.y))
    let keep = app.buttons["whiteboard-mark-keep"]
    XCTAssertTrue(keep.appears(within: 5), "the first circle chosen: \(app.debugDescription)")
    XCTAssertEqual(keep.label, "Keep group", "a reply of three is chosen whole (story 1285)")
    keep.tap()
    XCTAssertTrue(keep.waitForNonExistence(timeout: 5), "kept")
    XCTAssertTrue(toKeep(app, 1).waitForNonExistence(timeout: 5), "none of his reply left to keep")
    // Wait for the whole reply to show kept, not for any steady box: the three circles redraw in his purple one after
    // another, and a quarter second can pass with only the first redrawn (bead context-grabber-dud7, width 0.022 of
    // 0.077). On a timeout `showing` returns the last box, so the width assertion below still says what was there.
    let kept = try XCTUnwrap(
      PaperScreen.showing(app, { $0.larryKept }, { abs($0.width - marks.width) < marks.width / 6 }),
      "his circles in his purple")
    shot(app, "one Keep kept the reply")
    XCTAssertEqual(kept.width, marks.width, accuracy: marks.width / 6, "all three kept: \(marks) to \(kept)")
    XCTAssertEqual(kept.minX, marks.minX, accuracy: 0.01, "where they showed")

    let undo = app.buttons["whiteboard-undo"]
    waitUntil(NSPredicate(format: "isEnabled == true"), undo, timeout: 5)
    undo.tap()
    let gone = PaperScreen.showing(app, within: 5, { $0.larryKept }, { _ in true })
    shot(app, "after one undo")
    XCTAssertNil(gone, "one Undo took all three back")
  }

  /// Story 1286 (#1383): Dismiss group beside one circle of his reply takes all three.
  func testDismissGroupBesideOneMarkTakesTheWholeReply() throws {
    let app = try boardWithHisCircles(separate: false)
    let marks = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    PaperScreen.tap(app, CGPoint(x: marks.maxX - 0.003, y: marks.center.y))
    let dismiss = app.buttons["whiteboard-mark-dismiss"]
    XCTAssertTrue(dismiss.appears(within: 5), "the last circle chosen: \(app.debugDescription)")
    XCTAssertEqual(dismiss.label, "Dismiss group")
    dismiss.tap()
    XCTAssertTrue(dismiss.waitForNonExistence(timeout: 5), "dismissed")
    XCTAssertTrue(toKeep(app, 3).waitForNonExistence(timeout: 5), "none of his reply left to keep")
    sleep(1)  // the marks fade out over 0.3 s
    let left = PaperScreen.showing(app, within: 1, { $0.larryGhost }, { _ in true })
    shot(app, "Dismiss group took the reply")
    XCTAssertNil(left, "all three went")
    XCTAssertNil(PaperScreen.showing(app, within: 1, { $0.larryKept }, { _ in true }), "nothing kept")
  }
}
