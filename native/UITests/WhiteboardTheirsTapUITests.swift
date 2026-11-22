//  Story 1140 (#1171) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): Larry's
//  three circles kept with Keep all, each its own thing; a finger tap on the first selects that circle alone (its Delete
//  takes it and leaves the other two), and one Undo puts it back. A finger drag of a selection is story 947's test. Where the circles sit is read from the screen's pixels (`PaperScreen`,
//  in WhiteboardPaperGhostsUITests.swift); what is selected, from To text, which shows beside the selected ink. Which
//  strokes a tap reaches is `BoardOutlineTests.testAFingerTapOnOneThingOfLarrysTakesItAlone`. Story 1143 (bead
//  context-grabber-hm7n): two of the three kept one at a time with plain Keep and the third with Keep all; a tap on the
//  first takes both plainly kept ones (one reply), and Keep all's stays its own (`testAFingerTapOnOnePieceOfAReplyTakesTheWholeReply`).

import XCTest

final class WhiteboardTheirsTapUITests: XCTestCase {
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

  /// A new board with Larry's three circles showing as ghosts, one reply of his; the Send button's label before.
  private func threeCircles() throws -> (app: XCUIApplication, send: XCUIElement) {
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
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }  // Ghosts off: only Larry's marks show.
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(toKeep(app, 2).appears(within: 15), app.debugDescription)
    try larryDraws(3, cockpit)
    XCTAssertTrue(toKeep(app, 3).appears(within: 10), app.debugDescription)
    return (app, send)
  }

  /// Story 1143: the first and second circles kept one at a time with plain Keep, the third with Keep all. A tap on the
  /// first selects both plainly kept circles: its Delete takes them, and the third, kept with Keep all, stays.
  func testAFingerTapOnOnePieceOfAReplyKeptWithKeepSelectsTheWholeReply() throws {
    let (app, send) = try threeCircles()
    let marks = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    let keep = app.buttons["whiteboard-mark-keep"]
    for third in [0.0, 1.0] {
      // A circle's middle, on its outline's left edge: the circles are touching, each a third of the row.
      PaperScreen.tap(app, CGPoint(x: marks.minX + marks.width * third / 3 + 0.003, y: marks.center.y))
      XCTAssertTrue(keep.appears(within: 5), "Keep beside circle \(Int(third) + 1): \(app.debugDescription)")
      keep.tap()
      XCTAssertTrue(toKeep(app, 2 - Int(third)).appears(within: 5), app.debugDescription)
    }
    let keepAll = app.buttons["whiteboard-keep-all"]
    XCTAssertTrue(keepAll.appears(within: 5), app.debugDescription)
    keepAll.tap()
    XCTAssertTrue(app.buttons["whiteboard-mark-keep"].waitForNonExistence(timeout: 5), "no ghosts left")
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his three circles in his purple")
    XCTAssertEqual(kept.width, marks.width, accuracy: marks.width / 6, "all three kept where they showed")
    let label = send.label
    let toText = app.buttons["whiteboard-to-text"]
    XCTAssertFalse(toText.exists, "nothing selected yet")
    shot(app, "two kept with Keep, one with Keep all")

    PaperScreen.tap(app, CGPoint(x: kept.minX + 0.003, y: kept.center.y))
    XCTAssertTrue(toText.appears(within: 5), "the tap selected ink: \(app.debugDescription)")
    sleep(2)  // past the selection PaperKit makes of the same tap, and its dot
    XCTAssertTrue(toText.exists, "still selected a beat later")
    XCTAssertEqual(send.label, label, "no dot drawn for the tap")
    shot(app, "the reply's two plainly kept circles selected by a tap")

    let delete = app.buttons["Delete"].firstMatch
    XCTAssertTrue(delete.appears(within: 5), app.debugDescription)
    delete.tap()
    let gone = PaperScreen.showing(app, { $0.larryKept }, { $0.minX > kept.minX + kept.width / 2 })
    shot(app, "the selected reply deleted")
    let after = try XCTUnwrap(gone, "his third circle, after the Delete")
    XCTAssertEqual(after.maxX, kept.maxX, accuracy: 0.01, "the third stayed: \(kept) to \(after)")
    XCTAssertEqual(after.width, kept.width / 3, accuracy: kept.width / 6, "two of three went: \(kept) to \(after)")
  }

  func testAFingerTapOnOneOfLarrysKeptMarksSelectsItAlone() throws {
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
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }  // Ghosts off: only Larry's marks show.
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(toKeep(app, 2).appears(within: 15), app.debugDescription)
    try larryDraws(3, cockpit)
    XCTAssertTrue(toKeep(app, 3).appears(within: 10), app.debugDescription)
    // Keep all: three circles in a row, each kept as its own thing, not grouped.
    let keepAll = app.buttons["whiteboard-keep-all"]
    XCTAssertTrue(keepAll.appears(within: 5), app.debugDescription)
    keepAll.tap()
    waitUntil(NSPredicate(format: "label != %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    let label = send.label
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his three circles in his purple")
    let toText = app.buttons["whiteboard-to-text"]
    XCTAssertFalse(toText.exists, "nothing selected yet")
    shot(app, "kept all")

    // The first circle's left side: the circles are 40 board points wide, touching, so the first is the left third.
    PaperScreen.tap(app, CGPoint(x: kept.minX + 0.003, y: kept.center.y))
    XCTAssertTrue(toText.appears(within: 5), "the tap selected ink: \(app.debugDescription)")
    sleep(2)  // past the selection PaperKit makes of the same tap, and its dot
    XCTAssertTrue(toText.exists, "still selected a beat later")
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
}
