//  Stories 637–650 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): what a page
//  adds to a paste. The text's layout, caps and note are `WhiteboardPasteTests`, on the host, and ⌘V and ⌘Z on paper are
//  `WhiteboardPasteUITests`' one keys test. XCUITest's taps never reach the system's paste button, so these go through hooks.

import XCTest

final class WhiteboardPaperPasteUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  /// A new board on paper, with Ghosts off so nothing else lands on it.
  private func openBoard(_ extra: [String: String] = [:]) throws -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit()
    for (key, value) in extra { app.launchEnvironment[key] = value }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }
    return app
  }

  private func wait(_ element: XCUIElement, label: String, timeout: TimeInterval = 10) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: timeout)
  }

  private func send(_ app: XCUIApplication) -> XCUIElement { app.buttons["whiteboard-send"] }
  private func strokes(_ count: Int) -> String { "Send to Larry, \(count) strokes" }

  private func pageNumber(_ app: XCUIApplication) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Page '")).firstMatch
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  private func stroke(_ app: XCUIApplication, atHeight dy: CGFloat = 0.3) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: dy))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: dy)))
  }

  /// Story 641: strokes copied on a board on paper, and no text. Hooks copy and press: the simulator can't work the lasso, and
  /// keys reach one test per boot.
  func testCopiedStrokesPaste() throws {
    let app = try openBoard(["GRABBER_WHITEBOARD_AFTER_INK": "copy,paste"])
    sleep(2)
    stroke(app)
    wait(send(app), label: strokes(1))
    wait(send(app), label: strokes(2), timeout: 12)
    shot(app, "copied strokes pasted")
  }

  /// Story 644: a picture on the clipboard leaves the board alone. A hook presses Paste, as above.
  func testAPictureIsNotPasted() throws {
    UIPasteboard.general.image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
    }
    let app = try openBoard(["GRABBER_WHITEBOARD_AFTER_INK": "paste"])
    sleep(2)
    stroke(app)
    wait(send(app), label: strokes(1))
    sleep(4)
    shot(app, "a picture on the clipboard")
    XCTAssertEqual(send(app).label, strokes(1))
    XCTAssertNil(PaperScreen(app).red, "no picture on the sheet")
  }

  /// Stories 637, 645: in the middle of the paper on screen, by the screen's own pixels, and the first ink's next page.
  func testAPasteLandsInTheMiddleOfThePaperOnScreen() throws {
    let app = try openBoard(["GRABBER_WHITEBOARD_PASTE": "HI"])
    wait(send(app), label: strokes(2))
    wait(pageNumber(app), label: "Page 1 of 2")
    var seen: PaperScreen.Box?
    for _ in 0..<8 where seen == nil {
      sleep(1)
      seen = PaperScreen(app).ink
    }
    shot(app, "pasted")
    let ink = try XCTUnwrap(seen, "dark letters on screen")
    XCTAssertEqual(ink.center.x, 0.5, accuracy: 0.03, "across the middle")
    XCTAssertEqual(ink.width, 0.1, accuracy: 0.08, "at a size that reads")
  }

  /// Stories 639, 640, 646: a tall paste brings its pages, and one undo takes both back, and one redo brings them. The
  /// lines are from a hook's presses, as a phone's tool picker has no Undo.
  func testATallPasteBringsItsPagesInOneUndo() throws {
    let tall = Array(repeating: "HI", count: 40).joined(separator: "\n")
    let app = try openBoard([
      "GRABBER_WHITEBOARD_PASTE": tall, "GRABBER_WHITEBOARD_AFTER_KEEP": "5,undo,redo",
    ])
    wait(send(app), label: strokes(80))
    let many = pageNumber(app)
    expectation(
      for: NSPredicate(format: "NOT (label ENDSWITH ' of 1') AND NOT (label ENDSWITH ' of 2')"), evaluatedWith: many)
    waitForExpectations(timeout: 5)
    let brought = many.label
    shot(app, "a tall paste")
    wait(send(app), label: strokes(0))
    wait(many, label: "Page 1 of 1")
    wait(send(app), label: strokes(80))
    wait(many, label: brought)
  }

  /// Story 643: the letters reach Larry as strokes, with the same names after closing and opening the board.
  func testAPastesStrokesKeepTheirNamesForLarry() throws {
    let cockpit = try cockpit()
    let app = try openBoard(["GRABBER_WHITEBOARD_PASTE": "HI"])
    wait(send(app), label: strokes(2))
    let larry = app.buttons["whiteboard-larry"]
    let before = try sends(cockpit).count
    larry.tap()
    let first = try strokeIDs(cockpit, after: before)
    XCTAssertEqual(first.count, 2, "\(first)")

    sleep(2)  // Past the save.
    app.terminate()
    app.launchEnvironment["GRABBER_WHITEBOARD_PASTE"] = nil
    app.launch()
    let card = app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'On paper'")).firstMatch
    XCTAssertTrue(card.appears(within: 20), app.debugDescription)
    card.tap()
    wait(send(app), label: strokes(2))
    expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: larry)
    waitForExpectations(timeout: 10)
    let middle = try sends(cockpit).count
    larry.tap()
    XCTAssertEqual(try strokeIDs(cockpit, after: middle), first, "the same names after coming back from the file")
  }

  private func sends(_ cockpit: String) throws -> [[String]] {
    let url = try XCTUnwrap(URL(string: cockpit + "/fake/strokes"))
    var got: Data?
    let done = expectation(description: "the fake Cockpit answered")
    URLSession.shared.dataTask(with: url) { body, _, _ in
      got = body
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    let json = try JSONSerialization.jsonObject(with: try XCTUnwrap(got)) as? [String: Any]
    return try XCTUnwrap(json?["sends"] as? [[String]])
  }

  private func strokeIDs(_ cockpit: String, after count: Int) throws -> [String] {
    let until = Date().addingTimeInterval(15)
    while Date() < until {
      let all = try sends(cockpit)
      if all.count > count { return all[count] }
      Thread.sleep(forTimeInterval: 0.5)
    }
    XCTFail("no strokes reached the fake Cockpit")
    return []
  }
}
