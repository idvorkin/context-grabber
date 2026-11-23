//  Story 947 (#947) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): a finger
//  tap on one stroke of a kept group selects the whole group, a finger drags it as one, and one Undo puts it back. Where
//  the group sits is read from the screen's pixels (`PaperScreen`, in WhiteboardPaperGhostsUITests.swift); what is
//  selected, from To text, which shows beside the selected ink. Which strokes a tap reaches is `BoardOutlineTests`.

import XCTest

final class WhiteboardGroupTapUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  private func larryDraws(_ count: Int, _ cockpit: String) throws {
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

  private func toKeep(_ app: XCUIApplication, _ count: Int) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label == %@", "\(count) to keep")).firstMatch
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// Larry's three circles kept as one group on a new board, Ghosts off, and the original ghost bounds.
  private func keptGroup(_ app: XCUIApplication) throws -> PaperScreen.Box {
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
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }  // Ghosts off: only Larry's marks show.
    // The picker opens on the tool an earlier launch left (story 1098): the finger draws with the pen.
    let pen = app.buttons["Pen"]
    XCTAssertTrue(pen.appears(within: 10), "the tool picker: \(app.debugDescription)")
    if !pen.isSelected { pen.tap() }  // a tap on the picked pen opens its options over the board
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    try WhiteboardWordsOnlyFixture.prepare(cockpit, for: self)
    app.buttons["whiteboard-send"].tap()
    XCTAssertTrue(WhiteboardWordsOnlyFixture.reply(in: app).appears(within: 15), app.debugDescription)
    try larryDraws(3, cockpit)
    XCTAssertTrue(toKeep(app, 3).appears(within: 10), app.debugDescription)
    let marks = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    PaperScreen.tap(app, CGPoint(x: marks.minX + 0.003, y: marks.center.y))
    let group = app.buttons["whiteboard-mark-keep-group"]
    XCTAssertTrue(group.appears(within: 5), app.debugDescription)
    group.tap()
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 4 strokes"), send, timeout: 10)
    XCTAssertTrue(toKeep(app, 1).waitForNonExistence(timeout: 5) || !toKeep(app, 1).exists)
    return marks
  }

  private func visibleGroup(
    _ app: XCUIApplication, at expected: PaperScreen.Box, dy: CGFloat = 0, yTolerance: CGFloat = 0.01
  ) -> PaperScreen.Box? {
    PaperScreen.settled(app, within: 10) { screen in
      guard let bounds = screen.larryKept,
        abs(bounds.minX - expected.minX) < 0.01, abs(bounds.maxX - expected.maxX) < 0.01,
        abs(bounds.minY - expected.minY - dy) < yTolerance, abs(bounds.maxY - expected.maxY - dy) < yTolerance
      else { return nil }
      let width = expected.width / 3
      for circle in 0..<3 {
        let center = expected.minX + (CGFloat(circle) + 0.5) * width
        let strip = PaperScreen.Box(
          minX: center - width / 4, minY: bounds.minY, maxX: center + width / 4, maxY: bounds.maxY)
        guard let ink = screen.larryKept(in: strip),
          abs(ink.minY - bounds.minY) < 0.01, abs(ink.maxY - bounds.maxY) < 0.01
        else { return nil }
      }
      return bounds
    }
  }

  func testAFingerTapOnAGroupsStrokeSelectsItAllAndItDragsAsOne() throws {
    let app = XCUIApplication.forTests(animated: true)
    let marks = try keptGroup(app)
    let send = app.buttons["whiteboard-send"]
    let kept = try XCTUnwrap(visibleGroup(app, at: marks), "all three circles kept at their ghost positions")
    let toText = app.buttons["whiteboard-to-text"]
    XCTAssertFalse(toText.exists, "nothing selected yet")
    shot(app, "kept group")

    // The first circle's left side: one stroke of the three.
    PaperScreen.tap(app, CGPoint(x: kept.minX + 0.003, y: kept.center.y))
    XCTAssertTrue(toText.appears(within: 5), "the tap selected ink: \(app.debugDescription)")
    sleep(2)  // past the selection PaperKit makes of the same tap, and its dot
    XCTAssertTrue(toText.exists, "still selected a beat later")
    let window = app.windows.firstMatch.frame
    let selected = toText.frame
    shot(app, "the group selected by a tap")
    XCTAssertEqual(send.label, "Send to Larry, 4 strokes", "no dot drawn for the tap")
    // To text sits beside the selection, so it spans the whole group, not one circle.
    XCTAssertGreaterThan(selected.maxX / window.width, kept.maxX - 0.05, "the whole group selected: \(selected)")

    // A finger drags it down by a tenth of the window, from inside the selection (its edges are PaperKit's handles).
    let from = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y))
    let to = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y + 0.1))
    // Slow, and held before the lift: on a busy simulator a quick drag reached PaperKit as one late jump and the lift,
    // and the selection moved 2 points or not at all (bead context-grabber-z93g).
    from.press(forDuration: 0.3, thenDragTo: to, withVelocity: 200, thenHoldForDuration: 0.5)
    let moved = visibleGroup(app, at: kept, dy: 0.1, yTolerance: 0.03)
    shot(app, "dragged")
    XCTAssertNotNil(moved, "all three circles moved down together from \(kept)")
    XCTAssertEqual(send.label, "Send to Larry, 4 strokes", "moved, not drawn")

    let undo = app.buttons["whiteboard-undo"]
    waitUntil(NSPredicate(format: "isEnabled == true"), undo, timeout: 5)
    undo.tap()
    let back = visibleGroup(app, at: kept)
    shot(app, "after one undo")
    XCTAssertNotNil(back, "one Undo put all three circles back at \(kept)")
  }

  /// Stories 945, 946 (bead context-grabber-4nnh): the simulator's stand-in for the iPad's handwriting popover
  /// (`GRABBER_WHITEBOARD_FAKE_OFFER`) comes over the tapped group and empties its selection without a callback; the
  /// board puts the popover away and the group back, and a finger drag still moves all of it.
  func testTheHandwritingOfferIsPutAwayAndTheTappedGroupStillDrags() throws {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD_FAKE_OFFER"] = "1"
    let marks = try keptGroup(app)
    let kept = try XCTUnwrap(visibleGroup(app, at: marks), "all three circles kept at their ghost positions")
    PaperScreen.tap(app, CGPoint(x: kept.minX + 0.003, y: kept.center.y))
    XCTAssertTrue(app.buttons["whiteboard-to-text"].appears(within: 5), "the tap selected ink: \(app.debugDescription)")
    sleep(2)  // past the stand-in offer, shown 0.6 s after the tap
    shot(app, "after the offer")
    XCTAssertFalse(
      app.staticTexts["whiteboard-fake-handwriting-offer"].exists, "the offer put away: \(app.debugDescription)")
    let from = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y))
    let to = app.coordinate(withNormalizedOffset: CGVector(dx: kept.center.x, dy: kept.center.y + 0.1))
    from.press(forDuration: 0.3, thenDragTo: to, withVelocity: 200, thenHoldForDuration: 0.5)
    let moved = visibleGroup(app, at: kept, dy: 0.1, yTolerance: 0.03)
    shot(app, "dragged")
    XCTAssertNotNil(moved, "all three circles moved down together from \(kept)")
  }

  /// Off every group the tap does what it did: nothing is selected.
  func testATapBesideTheGroupSelectsNothing() throws {
    let app = XCUIApplication.forTests(animated: true)
    _ = try keptGroup(app)
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his reply in his purple")
    PaperScreen.tap(app, CGPoint(x: kept.center.x, y: kept.maxY + 0.08))
    sleep(2)
    XCTAssertFalse(app.buttons["whiteboard-to-text"].exists, "blank paper beside it selects nothing")
  }
}
