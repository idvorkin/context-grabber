//  Stories 954–958 on the iPad simulator: Play draws a board's strokes again in order, the bar pauses, skips and
//  changes speed, a tap on a stroke goes back to when it was drawn, and Done leaves the board as it was. The Pencil's own
//  pace and a big board's frame rate are the iPad's (`whiteboard` action: playback_start, playback_end). The tool picker
//  opens on the tool picked last, in an earlier launch too (story 1098), so the test picks the pen before it draws: a lane
//  left on the eraser by `WhiteboardEraserUITests` erased the first stroke (bead context-grabber-zj39).

import XCTest

final class WhiteboardPlaybackUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func launch() -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:65530"
    app.launch()
    return app
  }

  private func stroke(_ app: XCUIApplication, atHeight dy: CGFloat) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: dy))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: dy)))
  }

  /// The pen, unless it is already picked: a tap on the picked tool opens its options over the paper.
  private func pickPen(_ app: XCUIApplication) {
    let pen = app.buttons["Pen"]
    XCTAssertTrue(pen.appears(within: 10), "the tool picker: \(app.debugDescription)")
    if !pen.isSelected {
      pen.tap()
      sleep(1)
    }
    XCTAssertTrue(pen.isSelected, "the pen is picked: \(app.debugDescription)")
  }

  private func waitFor(_ element: XCUIElement, label: String, timeout: TimeInterval = 10) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: timeout)
  }

  private func keep(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  func testPlayDrawsTheBoardAgainAndDoneLeavesItAsItWas() {
    let app = launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let send = app.buttons["whiteboard-send"]
    XCTAssertTrue(send.appears(within: 10), app.debugDescription)
    XCTAssertFalse(app.buttons["whiteboard-play"].exists, "a board with no ink has no Play")
    sleep(2)
    pickPen(app)
    for (n, height) in [0.3, 0.5, 0.7].enumerated() {
      stroke(app, atHeight: height)
      waitFor(send, label: "Send to Larry, \(n + 1) strokes")
      sleep(1)
    }
    let page = app.staticTexts["whiteboard"]
    waitUntil(NSPredicate(format: "value == 'saved'"), page, timeout: 10)
    let undo = app.buttons["whiteboard-undo"].label

    // Story 958: Play empties the board and draws the three again; the board's bar is gone meanwhile.
    let play = app.buttons["whiteboard-play"]
    XCTAssertTrue(play.appears(within: 5), app.debugDescription)
    play.tap()
    let status = app.staticTexts["whiteboard-playback-status"]
    XCTAssertTrue(status.appears(within: 5), app.debugDescription)
    XCTAssertFalse(send.exists, "nothing on the board's bar can be tapped while it plays")
    waitFor(status, label: "Stroke 3 of 3, paused", timeout: 30)
    keep(app, "the board played back to its end")
    // Story 1111 (#1169): all three strokes are on the screen, so no label says the ink is above or below.
    XCTAssertFalse(app.descendants(matching: .any)["whiteboard-playback-offscreen"].exists, app.debugDescription)

    // Story 956: a tap on the second stroke goes back to when it began: the first showing, the second next.
    let second = app.descendants(matching: .any)["whiteboard-playback-stroke-2"]
    XCTAssertTrue(second.exists, app.debugDescription)
    second.tap()
    waitFor(status, label: "Stroke 1 of 3, paused")
    keep(app, "back to the second stroke")

    // Story 954: the speed steps from 1×, Play goes on to the end, 10 s back is the start.
    let speed = app.buttons["whiteboard-playback-speed"]
    waitFor(speed, label: "Speed 1×")
    speed.tap()
    waitFor(speed, label: "Speed 1.25×")
    app.buttons["whiteboard-playback-play"].tap()
    waitFor(status, label: "Stroke 3 of 3, paused", timeout: 30)
    app.buttons["whiteboard-playback-back"].tap()
    waitFor(status, label: "Stroke 0 of 3, paused")

    // Story 957: Done shows the board as it was: the same three strokes, saved, the same Undo, not sent.
    app.buttons["whiteboard-playback-done"].tap()
    XCTAssertTrue(send.appears(within: 5), app.debugDescription)
    XCTAssertFalse(status.exists)
    waitFor(send, label: "Send to Larry, 3 strokes")
    XCTAssertTrue(send.isEnabled, "nothing went to Larry")
    XCTAssertEqual(page.value as? String, "saved")
    XCTAssertEqual(app.buttons["whiteboard-undo"].label, undo, "playback made no undo step")
    keep(app, "the board as it was")
  }

  /// Story 1369 (#1553): on a phone's narrow bar Done keeps its full width (wider than tall, not squeezed into one
  /// letter a line), and a Back button at the top left leaves playback the same way.
  func testBackAndAFullWidthDoneLeavePlayback() {
    let app = launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let send = app.buttons["whiteboard-send"]
    XCTAssertTrue(send.appears(within: 10), app.debugDescription)
    sleep(2)
    pickPen(app)
    stroke(app, atHeight: 0.4)
    waitFor(send, label: "Send to Larry, 1 strokes")
    let play = app.buttons["whiteboard-play"]
    XCTAssertTrue(play.appears(within: 5), app.debugDescription)
    play.tap()
    let status = app.staticTexts["whiteboard-playback-status"]
    XCTAssertTrue(status.appears(within: 5), app.debugDescription)
    let done = app.buttons["whiteboard-playback-done"]
    XCTAssertTrue(done.exists, app.debugDescription)
    XCTAssertGreaterThan(done.frame.width, done.frame.height, "Done keeps its width: \(done.frame)")
    let back = app.buttons["whiteboard-playback-back-top"]
    XCTAssertTrue(back.exists, app.debugDescription)
    XCTAssertLessThan(back.frame.midX, app.frame.midX, "Back is at the left: \(back.frame)")
    XCTAssertGreaterThan(back.frame.width, back.frame.height, "Back keeps its width: \(back.frame)")
    keep(app, "playback with Back and a full-width Done")
    back.tap()
    XCTAssertTrue(send.appears(within: 5), app.debugDescription)
    XCTAssertFalse(status.exists)
  }
}
