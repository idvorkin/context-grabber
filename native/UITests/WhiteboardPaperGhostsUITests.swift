//  Stories 613–635 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): what paper
//  adds to the ghost turns. The bar, the note and the turns are the same on either canvas and run once, in
//  `WhiteboardTurnUITests`; these are what only a board on paper can show. A finger draws on the simulator; the Pencil and
//  what a finger does with one paired are the iPad's. The board isn't in the accessibility tree, so where ghosts and ink
//  sit is read from the screen's pixels.

import XCTest

/// What's on the screen, by colour, as parts of the window (0...1), between the bars.
struct PaperScreen {
  struct Box: Equatable {
    var minX: CGFloat
    var minY: CGFloat
    var maxX: CGFloat
    var maxY: CGFloat
    var center: CGPoint { CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2) }
    var width: CGFloat { maxX - minX }
  }

  private let width: Int
  private let height: Int
  private let bytes: [UInt8]
  /// Where the search starts, as a part of the screen's height: by default a fifth, clear of the bars.
  private let top: CGFloat
  /// Where the search stops on the right, as a part of the screen's width: by default the whole width.
  private let right: CGFloat

  /// `top`: start higher, for ink at the very top of a page (#845: an iPad's page puts it under the navigation bar).
  /// `right`: stop short of the page number, which a search that high would otherwise read as ink.
  init(_ app: XCUIApplication, top: CGFloat = 0.2, right: CGFloat = 1) {
    self.top = top
    self.right = right
    let image = app.screenshot().image.cgImage!
    width = image.width
    height = image.height
    var buffer = [UInt8](repeating: 0, count: width * height * 4)
    let (w, h) = (width, height)
    buffer.withUnsafeMutableBytes { raw in
      let context = CGContext(
        data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    bytes = buffer
  }

  private func box(_ matches: (Int, Int, Int) -> Bool) -> Box? {
    let started = Date()
    defer { print("ui-pixels: PaperScreen.box \(Int(Date().timeIntervalSince(started) * 1000)) ms") }
    // The extremes in pixels, turned into parts of the window once at the end.
    var (minX, minY, maxX, maxY) = (Int.max, Int.max, -1, -1)
    bytes.withUnsafeBufferPointer { bytes in
      // Clear of the bars and the page number above, and the tool picker below.
      for y in stride(from: Int(CGFloat(height) * top), to: height * 3 / 4, by: 2) {
        var i = y * width * 4
        for x in stride(from: 0, to: Int(CGFloat(width) * right), by: 2) {
          if matches(Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2])) {
            (minX, maxX) = (min(minX, x), max(maxX, x))
            (minY, maxY) = (min(minY, y), max(maxY, y))
          }
          i += 8
        }
      }
    }
    guard maxX >= 0 else { return nil }
    let (w, h) = (CGFloat(width), CGFloat(height))
    return Box(minX: CGFloat(minX) / w, minY: CGFloat(minY) / h, maxX: CGFloat(maxX) / w, maxY: CGFloat(maxY) / h)
  }

  /// A faint ghost of Claude's on pale paper, or a kept one at full strength.
  var orange: Box? { box { r, g, b in r > 225 && g > 120 && g < 225 && b < 170 && r - b > 80 } }
  /// Only a faint one.
  var ghost: Box? { box { r, g, b in r > 240 && g > 180 && g < 225 && b > 90 && b < 170 } }
  /// A kept one.
  var kept: Box? { box { r, g, b in r > 225 && g > 120 && g < 175 && b < 60 } }
  /// A picture pasted by mistake, in the tests' own red.
  var red: Box? { box { r, g, b in r > 240 && g < 40 && b < 40 } }
  /// Black ink.
  var ink: Box? { box { r, g, b in r < 70 && g < 70 && b < 70 } }

  static func tap(_ app: XCUIApplication, _ at: CGPoint) {
    app.coordinate(withNormalizedOffset: CGVector(dx: at.x, dy: at.y)).tap()
  }
}

extension PaperScreen {
  /// Story 673: what `look` finds once it has stopped changing, two looks a quarter second apart finding the same box,
  /// in place of a fixed wait before reading the screen. Nil when nothing settles within `timeout`.
  static func settled(
    _ app: XCUIApplication, top: CGFloat = 0.2, right: CGFloat = 1, within timeout: TimeInterval = 6,
    _ look: (PaperScreen) -> Box?
  ) -> Box? {
    let deadline = Date().addingTimeInterval(timeout)
    var last = look(PaperScreen(app, top: top, right: right))
    while Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
      let now = look(PaperScreen(app, top: top, right: right))
      if let now, now == last { return now }
      last = now
    }
    return nil
  }
}

final class WhiteboardPaperGhostsUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  /// A new board on paper, Ghosts on, that doesn't fade while a test looks at it.
  private func openBoard(way: String = "", _ extra: [String: String] = [:]) throws -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit() + way
    app.launchEnvironment["GRABBER_WHITEBOARD_GHOST_SECONDS"] = "600"
    for (key, value) in extra { app.launchEnvironment[key] = value }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts off") { ghosts.tap() }
    sleep(2)
    return app
  }

  private func stroke(_ app: XCUIApplication, atHeight dy: CGFloat = 0.5) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: dy))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: dy)))
  }

  private func wait(_ element: XCUIElement, label: String, timeout: TimeInterval = 10) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: timeout)
  }

  private func ghosts(_ app: XCUIApplication) -> XCUIElement { app.buttons["whiteboard-ghosts"] }
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

  /// A stroke and the ghost that answers it, settled.
  private func strokeBringsAGhost(_ app: XCUIApplication) -> PaperScreen.Box? {
    stroke(app)
    wait(ghosts(app), label: "Ghosts on, 1 showing", timeout: 10)
    // Past the note arriving above the board and the ghost drawing in.
    return PaperScreen.settled(app) { $0.ghost }
  }

  /// Stories 598, 613, 614, 615: the bar, a ghost that can be seen, and a tap on it that makes it ink of its colour.
  func testAGhostShowsOnThePaperAndATapKeepsIt() throws {
    let app = try openBoard()
    for id in ["whiteboard-ghosts", "whiteboard-mic", "whiteboard-larry", "whiteboard-send"] {
      XCTAssertTrue(app.buttons[id].exists, id)
    }
    XCTAssertTrue(app.buttons["whiteboard-paste"].exists, "and paste")
    let ghost = try XCTUnwrap(strokeBringsAGhost(app), "a faint orange ghost on screen")
    shot(app, "a ghost on paper")
    XCTAssertEqual(send(app).label, strokes(1), "a ghost isn't ink")

    PaperScreen.tap(app, ghost.center)
    wait(send(app), label: strokes(2))
    wait(ghosts(app), label: "Ghosts on")
    sleep(1)
    shot(app, "kept")
    let kept = try XCTUnwrap(PaperScreen(app).kept, "ink in Claude's orange")
    XCTAssertEqual(kept.center.x, ghost.center.x, accuracy: 0.03, "where the ghost was")
    XCTAssertEqual(kept.center.y, ghost.center.y, accuracy: 0.05, "where the ghost was")
  }

  /// Story 616: a tap off the ghosts dismisses them and leaves no dot, and then a finger draws again.
  func testATapOffDismissesLeavesNoDotAndAFingerDrawsAgain() throws {
    let app = try openBoard()
    _ = try XCTUnwrap(strokeBringsAGhost(app))
    PaperScreen.tap(app, CGPoint(x: 0.1, y: 0.72))
    wait(ghosts(app), label: "Ghosts on")
    sleep(1)
    XCTAssertEqual(send(app).label, strokes(1), "no dot")
    stroke(app, atHeight: 0.4)
    wait(send(app), label: strokes(2))
  }

  /// Story 614: pinched and moved, the ghost stays beside the ink, by the screen's own pixels. The same check on a sheet
  /// placed by hand would show any lag only while it moved, which is the iPad's (`paper_touch`'s ghost_slip).
  func testAGhostStaysOnTheInkWhenTheBoardMoves() throws {
    // `paper_touch` on an iPad simulator: fingers 2, travel 11 points, whatever scale is asked for: too little to zoom.
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "XCUITest's pinch barely moves on an iPad")
    let app = try openBoard()
    let ghost = try XCTUnwrap(strokeBringsAGhost(app))
    let ink = try XCTUnwrap(PaperScreen(app).ink, "black ink on screen")
    let gap = (ghost.center.x - ink.center.x) / ink.width
    shot(app, "before")

    app.pinch(withScale: 2, velocity: 1)
    _ = PaperScreen.settled(app) { $0.ink }  // The zoom over.
    shot(app, "zoomed in")
    let (ghostZoomed, inkZoomed) = (PaperScreen(app).ghost, PaperScreen(app).ink)
    let bigGhost = try XCTUnwrap(ghostZoomed, "the ghost is still on screen")
    let bigInk = try XCTUnwrap(inkZoomed, "and the ink")
    XCTAssertGreaterThan(bigInk.width, ink.width * 1.2, "the board zoomed")
    XCTAssertEqual(
      (bigGhost.center.x - bigInk.center.x) / bigInk.width, gap, accuracy: 0.1, "the ghost zoomed with the ink")
    XCTAssertEqual(ghosts(app).label, "Ghosts on, 1 showing")
    XCTAssertEqual(send(app).label, strokes(1), "a pinch isn't a stroke")
  }

  /// Stories 617, 630, 631: a kept ghost goes with one undo and comes back with one redo, and the undo after that takes his stroke,
  /// which is PaperKit's own step. A hook presses them, as a phone's tool picker has no Undo and keys reach only a run's
  /// first test.
  func testOneUndoTakesAKeptMarkBack() throws {
    let app = try openBoard(["GRABBER_WHITEBOARD_AFTER_KEEP": "4,undo,redo,undo,undo"])
    let ghost = try XCTUnwrap(strokeBringsAGhost(app))
    PaperScreen.tap(app, ghost.center)
    wait(send(app), label: strokes(2))
    shot(app, "kept")
    wait(send(app), label: strokes(1))
    XCTAssertNil(PaperScreen(app).kept, "the orange ink went")
    XCTAssertNotNil(PaperScreen(app).ink, "and his stroke stayed")
    shot(app, "after one undo")
    wait(send(app), label: strokes(2))
    XCTAssertNotNil(PaperScreen(app).kept, "redo brings it back")
    wait(send(app), label: strokes(1))
    wait(send(app), label: strokes(0))
    XCTAssertNil(PaperScreen(app).ink, "the next undo took his stroke")
    shot(app, "after his stroke too")
  }

  /// Stories 618, 632: a mark kept far down brings its pages in the one change, and one undo takes both. The fake's `/far`
  /// answers with a circle well below the last page: a hook keeps it, as it can't be reached to tap.
  func testAMarkKeptPastTheLastPageBringsItsPagesInOneUndo() throws {
    let app = try openBoard(
      way: "/far", ["GRABBER_WHITEBOARD_KEEP": "first", "GRABBER_WHITEBOARD_AFTER_KEEP": "5,undo"])
    stroke(app)
    wait(send(app), label: strokes(2), timeout: 12)
    wait(pageNumber(app), label: "Page 1 of 6")
    shot(app, "the kept mark's pages")
    wait(send(app), label: strokes(1))
    wait(pageNumber(app), label: "Page 1 of 2")
  }

  /// Story 619: the strokes keep their names, sent, closed, opened and sent again, the kept mark too. Larry's turn sends
  /// them to the fake Cockpit, which says what it got.
  func testAKeptMarkKeepsItsNameThroughAReopen() throws {
    let cockpit = try cockpit()
    let app = try openBoard()
    let ghost = try XCTUnwrap(strokeBringsAGhost(app))
    PaperScreen.tap(app, ghost.center)
    wait(send(app), label: strokes(2))
    let before = try sends(cockpit).count
    app.buttons["whiteboard-larry"].tap()
    let first = try strokeIDs(cockpit, after: before)
    XCTAssertEqual(first.count, 2, "\(first)")

    waitForTheSave(app)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let card = app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'On paper'")).firstMatch
    XCTAssertTrue(card.appears(within: 10), app.debugDescription)
    card.tap()
    wait(send(app), label: strokes(2))
    let larry = app.buttons["whiteboard-larry"]
    expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: larry)
    waitForExpectations(timeout: 10)
    let middle = try sends(cockpit).count
    larry.tap()
    let second = try strokeIDs(cockpit, after: middle)
    XCTAssertEqual(second, first, "the same names after coming back from the file")
  }

  /// Stories 620, 621: Larry's turn, his marks on the board in his colour, the kept one saved. Ghost text is the bar's, the
  /// same on either canvas (`WhiteboardTurnUITests`); here, that it can be seen and kept, and that a ghost left showing
  /// isn't saved.
  func testAGhostLeftShowingIsNotSaved() throws {
    let app = try openBoard()
    _ = try XCTUnwrap(strokeBringsAGhost(app))
    waitForTheSave(app)
    app.terminate()
    app.launch()
    let card = app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'On paper'")).firstMatch
    XCTAssertTrue(card.appears(within: 20), app.debugDescription)
    card.tap()
    wait(send(app), label: strokes(1))
  }

  /// Stories 433, 522 (#636): ink on page 1 and page 2 on screen is nothing to send, Send and Larry's turn both; ink on
  /// page 2 then goes as a picture of page 2 alone, by the frame the fake Cockpit got, and Larry's marks come back beside
  /// it. A hook moves the view, as XCUITest has no two-finger drag.
  func testThePictureIsThePageOnScreen() throws {
    let cockpit = try cockpit()
    let app = try openBoard(["GRABBER_WHITEBOARD_PAGE_AFTER_INK": "2"])
    // Ghosts off: a ghost showing would make the next finger a tap.
    ghosts(app).tap()
    wait(ghosts(app), label: "Ghosts off")
    stroke(app, atHeight: 0.3)
    wait(send(app), label: strokes(1))
    wait(pageNumber(app), label: "Page 2 of 2")
    sleep(1)
    shot(app, "page 2, blank")
    XCTAssertFalse(send(app).isEnabled, "page 1's ink is off screen: nothing to send")
    XCTAssertFalse(app.buttons["whiteboard-larry"].isEnabled, "nor a turn to hand him")

    stroke(app, atHeight: 0.6)
    wait(send(app), label: strokes(2))
    wait(pageNumber(app), label: "Page 2 of 3")
    expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: send(app))
    waitForExpectations(timeout: 5)
    let before = try pictureFrames(cockpit)
    send(app).tap()
    let frame = try newPictureFrame(cockpit, besides: before)
    let (top, bottom) = (BoardPage.height, 2 * BoardPage.height)
    XCTAssertGreaterThanOrEqual(frame.y, top, "page 2 only: \(frame)")
    XCTAssertLessThanOrEqual(frame.y + frame.h, bottom, "page 2 only: \(frame)")
    XCTAssertGreaterThanOrEqual(frame.scale, 1, "at a size Larry can read: \(frame)")
    wait(ghosts(app), label: "Ghosts off, 2 showing", timeout: 20)
    XCTAssertEqual(pageNumber(app).label, "Page 2 of 3", "his marks landed by the picture, on page 2")
    shot(app, "Larry's marks on page 2")
  }

  private enum BoardPage { static let height: Double = 1060 }

  private struct Frame: CustomStringConvertible {
    let id: String
    let y: Double
    let h: Double
    let scale: Double
    var description: String { "y \(y) h \(h) scale \(scale)" }
  }

  private func get(_ cockpit: String, _ path: String) throws -> [String: Any] {
    let url = try XCTUnwrap(URL(string: cockpit + path))
    var got: Data?
    let done = expectation(description: "the fake Cockpit answered \(path)")
    URLSession.shared.dataTask(with: url) { body, _, _ in
      got = body
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    return try XCTUnwrap(try JSONSerialization.jsonObject(with: try XCTUnwrap(got)) as? [String: Any])
  }

  /// Every board picture of Igor's on the fake's threads, with its frame.
  private func pictureFrames(_ cockpit: String) throws -> [Frame] {
    let threads = try XCTUnwrap(try get(cockpit, "/chat")["threads"] as? [[String: Any]])
    return try threads.compactMap { $0["key"] as? String }.flatMap { key -> [Frame] in
      let messages = try get(cockpit, "/chat/\(key)")["messages"] as? [[String: Any]] ?? []
      return messages.compactMap { m in
        guard m["who"] as? String == "igor", let id = m["picture_id"] as? String,
          let f = m["frame"] as? [String: Any], let y = f["y"] as? Double, let h = f["h"] as? Double
        else { return nil }
        return Frame(id: id, y: y, h: h, scale: f["scale"] as? Double ?? 0)
      }
    }
  }

  private func newPictureFrame(_ cockpit: String, besides before: [Frame]) throws -> Frame {
    let seen = Set(before.map(\.id))
    let until = Date().addingTimeInterval(15)
    while Date() < until {
      if let new = try pictureFrames(cockpit).first(where: { !seen.contains($0.id) }) { return new }
      Thread.sleep(forTimeInterval: 0.5)
    }
    return try XCTUnwrap(nil as Frame?, "no new board picture reached the fake Cockpit")
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

  /// The ids of the send after the first `count`, when it comes.
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
