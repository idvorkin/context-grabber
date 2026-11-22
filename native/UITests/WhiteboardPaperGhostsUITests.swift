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
  init(_ app: XCUIApplication) {
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

  private func box(in region: Box? = nil, _ matches: (Int, Int, Int) -> Bool) -> Box? {
    let started = Date()
    defer { print("ui-pixels: PaperScreen.box \(Int(Date().timeIntervalSince(started) * 1000)) ms") }
    // The extremes in pixels, turned into parts of the window once at the end.
    var (minX, minY, maxX, maxY) = (Int.max, Int.max, -1, -1)
    bytes.withUnsafeBufferPointer { bytes in
      // Clear of the bars and the page number above, and the tool picker below.
      for y in stride(from: height / 5, to: height * 3 / 4, by: 2) {
        var i = y * width * 4
        for x in stride(from: 0, to: width, by: 2) {
          if matches(Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2])), inside(x, y, region) {
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

  /// The pixel at `x`, `y` is in `region` (parts of the window), or there is no region.
  private func inside(_ x: Int, _ y: Int, _ region: Box?) -> Bool {
    guard let region else { return true }
    let (px, py) = (CGFloat(x) / CGFloat(width), CGFloat(y) / CGFloat(height))
    return px >= region.minX && px <= region.maxX && py >= region.minY && py <= region.maxY
  }

  /// Black ink inside `region`.
  func ink(in region: Box) -> Box? { box(in: region) { r, g, b in r < 70 && g < 70 && b < 70 } }

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
  /// A faint ghost of Larry's on white paper: his purple (#ba39e6) at half strength.
  var larryGhost: Box? { larryGhost(in: nil) }
  func larryGhost(in region: Box?) -> Box? {
    box(in: region) { r, g, b in r > 200 && r < 240 && g > 130 && g < 185 && b > 225 }
  }
  /// One of Larry's controls in the tests' green (the fake Cockpit's button).
  var green: Box? { box { r, g, b in r < 60 && g > 140 && b < 60 } }
  /// A kept mark of Larry's, at full strength.
  var larryKept: Box? { larryKept(in: nil) }
  func larryKept(in region: Box?) -> Box? {
    box(in: region) { r, g, b in r > 150 && r < 215 && g < 110 && b > 190 }
  }

  static func tap(_ app: XCUIApplication, _ at: CGPoint) {
    app.coordinate(withNormalizedOffset: CGVector(dx: at.x, dy: at.y)).tap()
  }
}

extension PaperScreen {
  /// What `look` finds goes away within `timeout`: a quarter second between looks.
  static func clears(_ app: XCUIApplication, within timeout: TimeInterval = 3, _ look: (PaperScreen) -> Box?) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while look(PaperScreen(app)) != nil {
      guard Date() < deadline else { return false }
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
    return true
  }

  /// What `look` finds once `holds` is true of it, two looks a quarter second apart finding the same box; else, after
  /// `timeout`, the last box found (nil when none), so the assertion after it says what was there.
  static func showing(
    _ app: XCUIApplication, within timeout: TimeInterval = 10, _ look: (PaperScreen) -> Box?, _ holds: (Box) -> Bool
  ) -> Box? {
    let deadline = Date().addingTimeInterval(timeout)
    var last = look(PaperScreen(app))
    while Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
      let now = look(PaperScreen(app))
      if let now, now == last, holds(now) { return now }
      last = now
    }
    return last
  }

  /// Story 673: what `look` finds once it has stopped changing, two looks a quarter second apart finding the same box,
  /// in place of a fixed wait before reading the screen. Nil when nothing settles within `timeout`.
  static func settled(_ app: XCUIApplication, within timeout: TimeInterval = 6, _ look: (PaperScreen) -> Box?) -> Box? {
    let deadline = Date().addingTimeInterval(timeout)
    var last = look(PaperScreen(app))
    while Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
      let now = look(PaperScreen(app))
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
  private func openBoard(_ extra: [String: String] = [:]) throws -> XCUIApplication {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit()
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

  /// Stories 825, 809: Keep beside the mark just tapped.
  private func keep(_ app: XCUIApplication) {
    let keep = app.buttons["whiteboard-mark-keep"]
    XCTAssertTrue(keep.appears(within: 5), app.debugDescription)
    keep.tap()
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

  /// A stroke and the ghost that answers it, settled.
  private func strokeBringsAGhost(_ app: XCUIApplication) -> PaperScreen.Box? {
    stroke(app)
    wait(ghosts(app), label: "Ghosts on, 1 showing", timeout: 10)
    // Past the note arriving above the board and the ghost drawing in.
    return PaperScreen.settled(app) { $0.ghost }
  }

  /// Stories 598, 613, 614, 615, 825, 809: the bar, a ghost that can be seen, and a tap on it and Keep that make it ink of its
  /// colour.
  func testAGhostShowsOnThePaperAndKeepMakesItInk() throws {
    // #1005 (story 1054): Paste shows only while the clipboard holds text.
    UIPasteboard.general.string = "HI"
    let app = try openBoard()
    for id in ["whiteboard-ghosts", "whiteboard-mic", "whiteboard-larry", "whiteboard-send"] {
      XCTAssertTrue(app.buttons[id].exists, id)
    }
    XCTAssertTrue(app.buttons["whiteboard-paste"].exists, "and paste")
    let ghost = try XCTUnwrap(strokeBringsAGhost(app), "a faint orange ghost on screen")
    shot(app, "a ghost on paper")
    XCTAssertEqual(send(app).label, strokes(1), "a ghost isn't ink")

    PaperScreen.tap(app, ghost.center)
    let keep = app.buttons["whiteboard-mark-keep"]
    XCTAssertTrue(keep.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.buttons["whiteboard-mark-dismiss"].exists)
    shot(app, "keep and dismiss")
    XCTAssertEqual(send(app).label, strokes(1), "a tap alone keeps nothing")
    keep.tap()
    wait(send(app), label: strokes(2))
    wait(ghosts(app), label: "Ghosts on")
    XCTAssertFalse(keep.exists, "the buttons went with the mark")
    sleep(1)
    shot(app, "kept")
    let kept = try XCTUnwrap(PaperScreen(app).kept, "ink in Claude's orange")
    XCTAssertEqual(kept.center.x, ghost.center.x, accuracy: 0.03, "where the ghost was")
    XCTAssertEqual(kept.center.y, ghost.center.y, accuracy: 0.05, "where the ghost was")
  }

  /// Stories 616, 808, 810: a tap off the ghosts changes nothing and leaves no dot; Dismiss removes the mark, and then a finger
  /// draws again.
  func testATapOffKeepsTheGhostDismissRemovesItAndAFingerDrawsAgain() throws {
    let app = try openBoard()
    let ghost = try XCTUnwrap(strokeBringsAGhost(app))
    PaperScreen.tap(app, CGPoint(x: 0.1, y: 0.72))
    sleep(1)
    XCTAssertEqual(ghosts(app).label, "Ghosts on, 1 showing", "a stray tap dismisses nothing")
    XCTAssertEqual(send(app).label, strokes(1), "no dot")
    PaperScreen.tap(app, ghost.center)
    let dismiss = app.buttons["whiteboard-mark-dismiss"]
    XCTAssertTrue(dismiss.appears(within: 5), app.debugDescription)
    dismiss.tap()
    wait(ghosts(app), label: "Ghosts on")
    sleep(1)
    XCTAssertEqual(send(app).label, strokes(1), "nothing kept")
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
  /// Story 896: Board → Tidy overlaps on a board with only his own ink moves nothing and says so. That a kept
  /// label on his ink moves under it, and only it, is `WhiteboardTidyTests`, on the host.
  func testTidyOverlapsOnATidyBoardSaysNothingOverlaps() throws {
    let app = try openBoard()
    ghosts(app).tap()
    stroke(app)
    wait(send(app), label: strokes(1))
    let before = PaperScreen.settled(app) { $0.ink }
    app.buttons["whiteboard-board"].tap()
    let tidy = app.descendants(matching: .any)["whiteboard-tidy"].firstMatch
    XCTAssertTrue(tidy.appears(within: 5), app.debugDescription)
    tidy.tapWhenSettled()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Nothing overlaps")).firstMatch
        .appears(within: 5), app.debugDescription)
    wait(send(app), label: strokes(1))
    XCTAssertEqual(PaperScreen.settled(app) { $0.ink }, before, "his ink didn't move")
  }

  /// first test.
  func testOneUndoTakesAKeptMarkBack() throws {
    let app = try openBoard(["GRABBER_WHITEBOARD_AFTER_KEEP": "4,undo,redo,undo,undo"])
    let ghost = try XCTUnwrap(strokeBringsAGhost(app))
    PaperScreen.tap(app, ghost.center)
    keep(app)
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

  /// Stories 619, 620, 621, 643: a kept mark and the strokes keep their names through the file, and a ghost left showing
  /// isn't saved. Claude's ghost is kept, Larry's turn sends both strokes to the fake Cockpit (which says what it got)
  /// and leaves his marks showing; the app is killed once the save is written, and after a relaunch the board holds
  /// only the two strokes, sent again under the same names. A paste's strokes go through the same keep and save, so
  /// this stands for them too (`WhiteboardStrokesTests` holds the names' rule).
  func testKeptInkKeepsItsNamesAndAGhostLeftShowingIsNotSaved() throws {
    let cockpit = try cockpit()
    let app = try openBoard()
    let ghost = try XCTUnwrap(strokeBringsAGhost(app))
    PaperScreen.tap(app, ghost.center)
    keep(app)
    wait(send(app), label: strokes(2))
    let before = try sends(cockpit).count
    app.buttons["whiteboard-larry"].tap()
    let first = try strokeIDs(cockpit, after: before)
    XCTAssertEqual(first.count, 2, "\(first)")
    // Larry's marks, ghosts nobody kept, on the board as it's saved.
    waitUntil(
      NSPredicate(format: "label BEGINSWITH 'Ghosts on, ' AND label ENDSWITH ' showing'"), ghosts(app), timeout: 15)
    shot(app, "his marks showing, not kept")

    waitForTheSave(app)
    app.terminate()
    app.launch()
    let card = app.buttons.matching(identifier: "whiteboard-card")
      .matching(NSPredicate(format: "label CONTAINS 'On paper'")).firstMatch
    XCTAssertTrue(card.appears(within: 20), app.debugDescription)
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

  // MARK: Larry's changes to the board (stories 814–818)

  /// The fake Cockpit's next board answer is a batch of Larry's changes: room below the middle of the picture he got,
  /// and a line of plain text in the gap; with `behind`, on the revision before the one the picture was of (story 961),
  /// with `stale`, on one before anything the board remembers.
  private func larryOps(_ cockpit: String, stale: Bool = false, behind: Bool = false) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/larry-ops")))
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"stale": \#(stale), "behind": \#(behind)}"#.utf8)
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// The fake Cockpit draws `count` circles in a row on the board's thread, unprompted, as one reply of Larry's.
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

  /// What each board message reported back to the fake Cockpit: its rev and op_result (story 818).
  private func opReports(_ cockpit: String) throws -> [[String: Any]] {
    let url = try XCTUnwrap(URL(string: cockpit + "/fake/ops"))
    var got: Data?
    let done = expectation(description: "the fake Cockpit answered")
    URLSession.shared.dataTask(with: url) { body, _, _ in
      got = body
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    let json = try JSONSerialization.jsonObject(with: try XCTUnwrap(got)) as? [String: Any]
    return try XCTUnwrap(json?["reports"] as? [[String: Any]])
  }

  /// The op_result on the board message after the first `count`, when it comes.
  private func opResult(_ cockpit: String, after count: Int) throws -> [String: Any]? {
    let until = Date().addingTimeInterval(15)
    while Date() < until {
      let all = try opReports(cockpit)
      if all.count > count { return all[count]["op_result"] as? [String: Any] }
      Thread.sleep(forTimeInterval: 0.5)
    }
    XCTFail("no board message reached the fake Cockpit")
    return nil
  }

  /// Ink above the picture's middle and ink below it, with Ghosts off so only Larry's text can show.
  private func inkAboveAndBelow(_ app: XCUIApplication) throws -> PaperScreen.Box {
    ghosts(app).tap()
    wait(ghosts(app), label: "Ghosts off")
    stroke(app, atHeight: 0.3)
    wait(send(app), label: strokes(1))
    stroke(app, atHeight: 0.55)
    wait(send(app), label: strokes(2))
    return try XCTUnwrap(PaperScreen.settled(app) { $0.ink }, "black ink on screen")
  }

  /// Every `POST /whiteboard/events` the fake Cockpit took (story 846).
  private func eventPosts(_ cockpit: String) throws -> [[String: Any]] {
    let url = try XCTUnwrap(URL(string: cockpit + "/fake/ops"))
    var got: Data?
    let done = expectation(description: "the fake Cockpit answered")
    URLSession.shared.dataTask(with: url) { body, _, _ in
      got = body
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
    let json = try JSONSerialization.jsonObject(with: try XCTUnwrap(got)) as? [String: Any]
    return try XCTUnwrap(json?["event_posts"] as? [[String: Any]])
  }

  /// Arms the fake Cockpit's next board answer as Larry's ink and a button (stories 840, 845).
  private func larryInkAndButton(_ cockpit: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/larry-ops")))
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"kind": "ink_and_button"}"#.utf8)
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

  /// The ink's box once `holds` is true of it, or nil when it isn't within `timeout`.
  private func ink(_ app: XCUIApplication, within timeout: TimeInterval, _ holds: (PaperScreen.Box) -> Bool)
    -> PaperScreen.Box?
  {
    let until = Date().addingTimeInterval(timeout)
    while Date() < until {
      if let box = PaperScreen(app).ink, holds(box) { return box }
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
    return nil
  }

  /// Stories 814, 816: Larry's push moves the ink below the line straight down, leaves the ink above, adds no stroke,
  /// and one undo puts it back; redo pushes it again. A hook presses them, as a phone's tool picker has no Undo. Which
  /// strokes move and the page growth are `BoardOpsTests`, on the host.
  func testLarrysPushMovesTheInkBelowAndOneUndoPutsItBack() throws {
    let cockpit = try cockpit()
    let app = try openBoard(["GRABBER_WHITEBOARD_AFTER_OPS": "6,undo,redo"])
    let before = try inkAboveAndBelow(app)
    shot(app, "ink above and below")
    try larryOps(cockpit)
    app.buttons["whiteboard-larry"].tap()
    // His text lands as the push does.
    XCTAssertTrue(toKeep(app, 1).appears(within: 15), app.debugDescription)
    let pushed = try XCTUnwrap(PaperScreen.settled(app) { $0.ink }, "the ink, settled after the push")
    shot(app, "pushed")
    XCTAssertEqual(pushed.minY, before.minY, accuracy: 0.01, "the ink above stayed")
    XCTAssertGreaterThan(pushed.maxY, before.maxY + 0.03, "the ink below moved down: \(before) to \(pushed)")
    XCTAssertEqual(pushed.center.x, before.center.x, accuracy: 0.01, "straight down")
    XCTAssertEqual(send(app).label, strokes(2), "moved, not added")

    let undone = ink(app, within: 12) { abs($0.maxY - before.maxY) < 0.01 }
    XCTAssertNotNil(undone, "one undo put it back")
    shot(app, "after one undo")
    let redone = ink(app, within: 8) { $0.maxY > before.maxY + 0.03 }
    XCTAssertNotNil(redone, "redo pushed it down again")
    XCTAssertEqual(send(app).label, strokes(2))
  }

  /// Story 995 (#942): beside one of Larry's marks, Keep group keeps his whole reply at once, in his purple, with nothing
  /// left to keep, and one undo takes all of it back. Its buttons are a finger's height. That the strokes are one group
  /// named for the reply, and move as one, is `WhiteboardKeepGroupTests` and `BoardMarksReplayTests`, on the host.
  func testKeepGroupKeepsHisWholeReplyAndOneUndoTakesItBack() throws {
    let cockpit = try cockpit()
    let app = try openBoard(["GRABBER_WHITEBOARD_AFTER_KEEP": "8,undo"])
    ghosts(app).tap()  // Ghosts off: only Larry's marks show.
    stroke(app)
    wait(send(app), label: strokes(1))
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(toKeep(app, 2).appears(within: 15), app.debugDescription)
    try larryDraws(3, cockpit)
    XCTAssertTrue(toKeep(app, 3).appears(within: 10), app.debugDescription)
    let marks = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    // The first circle's left side.
    PaperScreen.tap(app, CGPoint(x: marks.minX + 0.003, y: marks.center.y))
    let group = app.buttons["whiteboard-mark-keep-group"]
    XCTAssertTrue(group.appears(within: 5), app.debugDescription)
    XCTAssertTrue(group.label.hasPrefix("Keep group · 3"), group.label)
    for id in ["whiteboard-mark-keep", "whiteboard-mark-keep-group", "whiteboard-mark-dismiss"] {
      XCTAssertGreaterThanOrEqual(app.buttons[id].frame.height, 36, "\(id) a finger's height")
    }
    shot(app, "keep group beside his mark")
    group.tap()
    waitUntil(NSPredicate(format: "label != %@", strokes(1)), send(app), timeout: 10)
    XCTAssertFalse(toKeep(app, 3).exists, "none of his reply left to keep")
    XCTAssertNotNil(PaperScreen.settled(app) { $0.larryKept }, "ink in his purple")
    shot(app, "his reply kept as a group")
    wait(send(app), label: strokes(1), timeout: 12)
    XCTAssertNil(PaperScreen(app).larryKept, "one undo took all of it back")
    shot(app, "after one undo")
  }

  /// Stories 1008, 1009 (#965): the bar's Undo and Redo, a finger's size, dimmed with nothing to do, take a stroke back and
  /// bring it again; after Keep group, Undo names it and one press takes the whole group back. What each label says for
  /// each state of the stack is `BoardUndoButtonsTests`, on the host.
  func testTheBarsUndoAndRedoTakeAStepBackAndNameAKeptGroup() throws {
    let cockpit = try cockpit()
    let app = try openBoard()
    ghosts(app).tap()  // Ghosts off: only Larry's marks show.
    let undo = app.buttons["whiteboard-undo"]
    let redo = app.buttons["whiteboard-redo"]
    XCTAssertTrue(undo.appears(within: 5), app.debugDescription)
    for button in [undo, redo] {
      XCTAssertGreaterThanOrEqual(button.frame.width, 44, "\(button.identifier) a finger's width")
      // The nav bar hosts every item at its own height (36 points on the iPad), whatever the button asks for (#965).
      XCTAssertGreaterThanOrEqual(button.frame.height, 36, "\(button.identifier) the bar's own height")
    }
    XCTAssertFalse(undo.isEnabled, "nothing to undo on a new board")
    XCTAssertFalse(redo.isEnabled, "nothing to redo")

    stroke(app)
    wait(send(app), label: strokes(1))
    waitUntil(NSPredicate(format: "isEnabled == true"), undo, timeout: 5)
    XCTAssertEqual(undo.label, "Undo", "his own stroke has no name")
    undo.tap()
    wait(send(app), label: strokes(0))
    waitUntil(NSPredicate(format: "isEnabled == true"), redo, timeout: 5)
    redo.tap()
    wait(send(app), label: strokes(1))
    shot(app, "his stroke back by Redo")

    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(toKeep(app, 2).appears(within: 15), app.debugDescription)
    try larryDraws(3, cockpit)
    XCTAssertTrue(toKeep(app, 3).appears(within: 10), app.debugDescription)
    let marks = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    PaperScreen.tap(app, CGPoint(x: marks.minX + 0.003, y: marks.center.y))
    let group = app.buttons["whiteboard-mark-keep-group"]
    XCTAssertTrue(group.appears(within: 5), app.debugDescription)
    group.tap()
    waitUntil(NSPredicate(format: "label != %@", strokes(1)), send(app), timeout: 10)
    waitUntil(NSPredicate(format: "label == %@", "Undo Keep group"), undo, timeout: 5)
    undo.tap()
    wait(send(app), label: strokes(1), timeout: 10)
    XCTAssertNil(PaperScreen(app).larryKept, "one press took the whole group back")
    shot(app, "kept group undone from the bar")
  }

  /// #894 (stories 1004, 1005): a line Igor writes after the picture went, where Larry's reply lands. Keep group pushes
  /// the line down under the reply, his marks stay where they showed, and one undo puts the line back through them.
  func testKeepGroupPushesWhatIgorWroteSinceThePictureUnderTheReply() throws {
    let cockpit = try cockpit()
    let app = try openBoard(["GRABBER_WHITEBOARD_AFTER_KEEP": "8,undo"])
    ghosts(app).tap()  // Ghosts off: only Larry's marks show.
    stroke(app, atHeight: 0.3)
    wait(send(app), label: strokes(1))
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(toKeep(app, 2).appears(within: 15), app.debugDescription)
    try larryDraws(3, cockpit)
    XCTAssertTrue(toKeep(app, 3).appears(within: 10), app.debugDescription)
    let marks = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his three circles, faint")
    // Written after his picture, straight through his circles.
    app.coordinate(withNormalizedOffset: CGVector(dx: marks.minX - 0.03, dy: marks.center.y))
      .press(
        forDuration: 0.05,
        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: marks.maxX + 0.03, dy: marks.center.y)))
    wait(send(app), label: strokes(2))
    // Larry's picture is cut to the ink, so his circles land just above Igor's first line, which is in his picture and
    // shows under them: what tells the push is the newer line leaving his circles and the ink under them reaching lower.
    let under = PaperScreen.Box(minX: 0, minY: marks.maxY + 0.005, maxX: 1, maxY: marks.maxY + 0.25)
    XCTAssertNotNil(PaperScreen(app).ink(in: marks), "the new line runs through his circles")
    let before = try XCTUnwrap(PaperScreen(app).ink(in: under), "Igor's first line, just under his circles")
    shot(app, "a line written through his reply after the picture")
    PaperScreen.tap(app, CGPoint(x: marks.minX + 0.003, y: marks.minY + (marks.maxY - marks.minY) * 0.3))
    let group = app.buttons["whiteboard-mark-keep-group"]
    XCTAssertTrue(group.appears(within: 5), app.debugDescription)
    group.tap()
    waitUntil(NSPredicate(format: "label != %@", strokes(2)), send(app), timeout: 10)
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his reply as ink in his purple")
    XCTAssertEqual(kept.center.y, marks.center.y, accuracy: 0.02, "his marks stay where they showed")
    // A look the moment his purple settles can catch the paper's tiles mid-redraw; the settled board has nothing black
    // in his circles (rung 2, 2026-11-20: six looks over three seconds after the keep found none).
    XCTAssertTrue(PaperScreen.clears(app) { $0.ink(in: marks) }, "the newer line left his circles")
    let pushed = try XCTUnwrap(PaperScreen(app).ink(in: under), "the line went down under his reply")
    XCTAssertGreaterThan(pushed.maxY, before.maxY + 0.005, "what's under his reply reaches lower")
    shot(app, "the line pushed under his kept reply")
    waitUntil(NSPredicate(format: "label == %@", strokes(2)), send(app), timeout: 12)
    XCTAssertNil(PaperScreen.settled(app) { $0.larryKept }, "one undo took his reply back")
    XCTAssertNotNil(PaperScreen(app).ink(in: marks), "and put the line back where it was")
    let undone = try XCTUnwrap(PaperScreen(app).ink(in: under), "Igor's first line, back under his circles")
    XCTAssertEqual(undone.maxY, before.maxY, accuracy: 0.005, "back as it was before the keep")
    shot(app, "after one undo")
  }

  /// Stories 817, 818: Larry's text arrives as a ghost in his purple, keeps on a tap and Keep where it showed, goes back to
  /// him as one text under his id, and his next turn says the change applied. The text's typeface is for the eye, in
  /// the screenshots; folding its glyphs into one text is `BoardOpsTests`, on the host.
  func testLarrysTextArrivesAsAGhostAndKeepsAsOneText() throws {
    let cockpit = try cockpit()
    let app = try openBoard()
    _ = try inkAboveAndBelow(app)
    try larryOps(cockpit)
    let reported = try opReports(cockpit).count
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(toKeep(app, 1).appears(within: 15), app.debugDescription)
    let ghost = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his text, faint, in his purple")
    shot(app, "his text as a ghost")
    XCTAssertNil(PaperScreen(app).larryKept, "a ghost isn't ink")

    PaperScreen.tap(app, ghost.center)
    keep(app)
    waitUntil(NSPredicate(format: "label != %@", strokes(2)), send(app), timeout: 10)
    XCTAssertFalse(toKeep(app, 1).exists, "kept, it's no longer a ghost")
    // The canvas draws new ink in its own time, and on a busy Mac a part of it ("r", then "ro") can hold still for two
    // looks: what's read is his text once it's as wide as the ghost was, every glyph drawn (context-grabber-5uo2).
    let kept = try XCTUnwrap(
      PaperScreen.showing(app, { $0.larryKept }) { abs($0.width - ghost.width) < 0.03 }, "ink in his purple")
    shot(app, "his text kept")
    // context-grabber-ikya: narrower is glyphs not drawn in his purple (once, all but the first in black); the log's
    // `paper_kept_ink` says whether PaperKit held them so or only drew them so.
    XCTAssertEqual(kept.width, ghost.width, accuracy: 0.03, "every glyph in his purple")
    XCTAssertEqual(kept.center.x, ghost.center.x, accuracy: 0.03, "where the ghost was")
    XCTAssertEqual(kept.center.y, ghost.center.y, accuracy: 0.03, "where the ghost was")

    let sent = try sends(cockpit).count
    app.buttons["whiteboard-larry"].tap()
    let ids = try strokeIDs(cockpit, after: sent)
    XCTAssertTrue(ids.contains("fake-text-1"), "his text goes back under his id: \(ids)")
    XCTAssertEqual(ids.count, 3, "his text is one, beside the two strokes: \(ids)")
    let result = try XCTUnwrap(opResult(cockpit, after: reported + 1), "the next turn says what came of it")
    XCTAssertEqual(result["ok"] as? Bool, true, "\(result)")
    XCTAssertEqual(result["label"] as? String, "make room")
  }

  /// Stories 840, 842, 845, 846: Larry's ink lands as ink, not a ghost, and goes back to him under his name; his button
  /// shows at its place and is no stroke, and a tap on it reaches the Cockpit at once with its event. What the plan
  /// does and the fallback when the Cockpit has no events route are `BoardOpsInkTests` and `BoardOpsControlsTests`.
  func testLarrysInkAndButtonLandAndATapOnItReachesHim() throws {
    let cockpit = try cockpit()
    let app = try openBoard()
    _ = try inkAboveAndBelow(app)
    try larryInkAndButton(cockpit)
    let posted = try eventPosts(cockpit).count
    app.buttons["whiteboard-larry"].tap()
    wait(send(app), label: strokes(3), timeout: 15)
    let line = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his line, as ink in his purple")
    let button = try XCTUnwrap(PaperScreen.settled(app) { $0.green }, "his button, in its green")
    shot(app, "his ink and his button")
    XCTAssertLessThan(line.center.y, button.center.y, "the button sits under his line")

    PaperScreen.tap(app, button.center)
    let until = Date().addingTimeInterval(10)
    var posts = try eventPosts(cockpit)
    while posts.count <= posted, Date() < until {
      Thread.sleep(forTimeInterval: 0.5)
      posts = try eventPosts(cockpit)
    }
    let tap = try XCTUnwrap((posts.last?["events"] as? [[String: Any]])?.last, "the tap reached the Cockpit: \(posts)")
    XCTAssertEqual(tap["type"] as? String, "overlay_tap", "the type the Cockpit wakes him for")
    XCTAssertEqual(tap["target_id"] as? String, "fake-button-1")
    XCTAssertEqual((tap["event"] as? [String: Any])?["type"] as? String, "make_room", "his event as he wrote it")
    XCTAssertEqual(posts.last?["woke"] as? Bool, true, "and the fake Cockpit woke him")
    XCTAssertEqual(send(app).label, strokes(3), "a tap on his button draws nothing")

    let sent = try sends(cockpit).count
    app.buttons["whiteboard-larry"].tap()
    let ids = try strokeIDs(cockpit, after: sent)
    XCTAssertTrue(ids.contains("fake-line-1"), "his line goes back under his name: \(ids)")
    XCTAssertEqual(ids.count, 3, "and his button is no stroke: \(ids)")
  }

  /// Story 961: a push made on the revision before the picture's, naming nothing Igor moved since, still pushes, and
  /// his next turn says it applied on a newer board than he saw. The rule is `BoardOpsTests`, on the host.
  func testAPushFromAnOlderLookStillApplies() throws {
    let cockpit = try cockpit()
    let app = try openBoard()
    let before = try inkAboveAndBelow(app)
    try larryOps(cockpit, behind: true)
    let reported = try opReports(cockpit).count
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(toKeep(app, 1).appears(within: 15), app.debugDescription)
    let pushed = try XCTUnwrap(PaperScreen.settled(app) { $0.ink }, "the ink, settled after the push")
    shot(app, "a push from an older look")
    XCTAssertGreaterThan(pushed.maxY, before.maxY + 0.03, "the ink below moved down: \(before) to \(pushed)")

    let ghost = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his text, faint, in his purple")
    PaperScreen.tap(app, ghost.center)
    keep(app)
    waitUntil(NSPredicate(format: "label != %@", strokes(2)), send(app), timeout: 10)
    app.buttons["whiteboard-larry"].tap()
    let result = try XCTUnwrap(opResult(cockpit, after: reported + 1), "the next turn says what came of it")
    XCTAssertEqual(result["ok"] as? Bool, true, "\(result)")
    XCTAssertNotNil(result["rebased_from"] as? Int, "applied on a newer board than he saw: \(result)")
  }

  /// Story 816: a push on a revision the board no longer remembers moves nothing, and his next turn tells him it was
  /// stale. A conflict on a stroke Igor moved is `BoardOpsTests`, on the host (story 961); the chip it brings is the
  /// test below.
  func testAStalePushMovesNothingAndLarryIsTold() throws {
    let cockpit = try cockpit()
    let app = try openBoard()
    let before = try inkAboveAndBelow(app)
    try larryOps(cockpit, stale: true)
    let reported = try opReports(cockpit).count
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Larry: made room")).firstMatch
        .appears(within: 15), app.debugDescription)
    sleep(2)
    let after = try XCTUnwrap(PaperScreen.settled(app) { $0.ink })
    shot(app, "a stale push")
    XCTAssertEqual(after.maxY, before.maxY, accuracy: 0.01, "nothing moved")
    XCTAssertFalse(toKeep(app, 1).exists, "nor did his text show: the whole batch was refused")

    stroke(app, atHeight: 0.42)
    wait(send(app), label: strokes(3))
    app.buttons["whiteboard-larry"].tap()
    let result = try XCTUnwrap(opResult(cockpit, after: reported + 1), "the next turn says what came of it")
    XCTAssertEqual(result["ok"] as? Bool, false, "\(result)")
    XCTAssertEqual(result["reason"] as? String, "stale")
  }

  /// Stories 970–972: a refused push brings the chip; × puts it away asking nothing, and Retry hands Larry the board,
  /// his turn saying what came of his change. The chip's rules are `BoardBlockedEditTests`, on the host.
  func testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard() throws {
    let cockpit = try cockpit()
    let app = try openBoard()
    _ = try inkAboveAndBelow(app)
    let retry = app.buttons["whiteboard-blocked-retry"]
    XCTAssertFalse(retry.exists, "no chip before anything is refused")
    try larryOps(cockpit, stale: true)
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(retry.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertTrue(retry.label.contains("Larry's edit blocked"), retry.label)
    shot(app, "the blocked chip")
    let dismissed = try opReports(cockpit).count
    app.buttons["whiteboard-blocked-dismiss"].tap()
    XCTAssertTrue(retry.waitForNonExistence(timeout: 5), "× puts it away")
    sleep(2)
    XCTAssertEqual(try opReports(cockpit).count, dismissed, "and asks Larry nothing")

    try larryOps(cockpit, stale: true)
    app.buttons["whiteboard-larry"].tap()
    XCTAssertTrue(retry.waitForExistence(timeout: 15), "a second refusal brings it back")
    let reported = try opReports(cockpit).count
    retry.tap()
    XCTAssertTrue(retry.waitForNonExistence(timeout: 5), "Retry puts it away")
    let result = try XCTUnwrap(opResult(cockpit, after: reported), "Retry is Larry's turn")
    XCTAssertEqual(result["ok"] as? Bool, false, "\(result)")
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
