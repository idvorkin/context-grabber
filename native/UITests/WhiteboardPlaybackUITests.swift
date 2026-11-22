//  Stories 948, 954, 956–958 on the iPad simulator: Play draws a board's strokes again in order, the bar pauses, skips and
//  changes speed, a tap on a stroke goes back to when it was drawn, and Done leaves the board as it was. The Pencil's own
//  pace and a big board's frame rate are the iPad's (`whiteboard` action: playback_start, playback_end).

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
    // Story 948 (#1169): all three strokes are on the screen, so no label says the ink is above or below.
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
}
