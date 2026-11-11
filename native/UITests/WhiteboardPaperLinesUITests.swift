//  Stories 434, 523, 538, 652–657 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it):
//  what the sheet under a board on paper shows: its lines and colours, by the screen's own pixels, as the board isn't in the
//  accessibility tree. The old canvas's are `WhiteboardTurnUITests`', and a board on paper staying light in dark mode is
//  `WhiteboardOnPaperUITests`'.

import XCTest

final class WhiteboardPaperLinesUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func openBoard(ghostsOn: Bool = false, _ extra: [String: String] = [:]) throws -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    for (key, value) in extra { app.launchEnvironment[key] = value }
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix(ghostsOn ? "Ghosts off" : "Ghosts on") { ghosts.tap() }
    return app
  }

  private func wait(_ element: XCUIElement, label: String, timeout: TimeInterval = 8) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: timeout)
  }

  private func stroke(_ app: XCUIApplication) {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
    start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.45)))
  }

  private func board(_ app: XCUIApplication) -> XCUIElement { app.buttons["whiteboard-board"] }
  private func send(_ app: XCUIApplication) -> XCUIElement { app.buttons["whiteboard-send"] }

  private func menu(_ app: XCUIApplication, _ item: String, expect: String) {
    board(app).tap()
    let choice = app.descendants(matching: .any)[item].firstMatch
    XCTAssertTrue(choice.appears(within: 5), app.debugDescription)
    choice.tapWhenSettled()
    wait(board(app), label: expect, timeout: 10)
    sleep(1)  // The menu gone and the sheet laid.
  }

  private func keep(_ name: String) {
    let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  /// The screen between the bars, as rows of pixels.
  private struct Screen {
    let width: Int
    let height: Int
    let bytes: [UInt8]

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

    private var rowsLooked: Range<Int> { height / 5..<(height * 3 / 4) }

    /// Lines running across, and lines running down, this screen has and `other` doesn't: rows or columns differing most of
    /// their length (a channel more than 3 apart). One pass over raw bytes: the UI tests are a Debug build, where a closure
    /// a pixel took seconds a call.
    func lines(against other: Screen) -> (across: Int, down: Int) {
      let started = Date()
      defer { print("ui-pixels: lines(against:) \(Int(Date().timeIntervalSince(started) * 1000)) ms") }
      let rows = rowsLooked
      var downCounts = [Int](repeating: 0, count: width)
      var across = 0
      bytes.withUnsafeBufferPointer { a in
        other.bytes.withUnsafeBufferPointer { b in
          downCounts.withUnsafeMutableBufferPointer { down in
            for y in rows {
              var differing = 0
              var i = y * width * 4
              for x in 0..<width {
                if abs(Int(a[i]) - Int(b[i])) > 3 || abs(Int(a[i + 1]) - Int(b[i + 1])) > 3
                  || abs(Int(a[i + 2]) - Int(b[i + 2])) > 3
                {
                  differing += 1
                  down[x] += 1
                }
                i += 4
              }
              if differing > width / 2 { across += 1 }
            }
          }
        }
      }
      return (across, downCounts.filter { $0 > rows.count / 2 }.count)
    }

    /// Pixels with more orange in them than `paper` has where nothing is drawn: a ghost on any colour.
    func warmer(than paper: Screen) -> Int {
      var count = 0
      for y in stride(from: rowsLooked.lowerBound, to: rowsLooked.upperBound, by: 2) {
        for x in stride(from: 0, to: width, by: 2) {
          let i = (y * width + x) * 4
          let warmth = Int(bytes[i]) - Int(bytes[i + 2]) - Int(paper.bytes[i]) + Int(paper.bytes[i + 2])
          if warmth > 20 { count += 1 }
        }
      }
      return count
    }
  }

  /// Stories 434, 523, 538, 652, 654: ruled lines run across only, the grid both ways, one takes the other's place, and they
  /// don't count as ink or as a step of undo.
  func testRuledLinesAndTheGridAreOneChoiceAndNeverInk() throws {
    let app = try openBoard()
    stroke(app)
    wait(send(app), label: "Send to Larry, 1 strokes")
    sleep(1)
    let plain = Screen(app)
    let ink = try XCTUnwrap(PaperScreen(app).ink, "the stroke on screen")

    menu(app, "Ruled lines", expect: "Board, Plain, ruled lines on")
    keep("ruled")
    let ruled = Screen(app).lines(against: plain)
    XCTAssertGreaterThan(ruled.across, 5, "ruled lines run across the page")
    XCTAssertEqual(ruled.down, 0, "and only across")

    menu(app, "Grid lines", expect: "Board, Plain, grid on")
    keep("grid")
    let grid = Screen(app).lines(against: plain)
    XCTAssertGreaterThan(grid.across, 5, "the grid runs across")
    XCTAssertGreaterThan(grid.down, 3, "and down")

    let now = try XCTUnwrap(PaperScreen(app).ink, "the stroke still on screen")
    XCTAssertEqual(now.center.x, ink.center.x, accuracy: 0.01, "where it was")
    XCTAssertEqual(now.center.y, ink.center.y, accuracy: 0.01, "where it was")
    XCTAssertEqual(send(app).label, "Send to Larry, 1 strokes", "lines aren't ink")
  }

  /// Stories 403, 653: a board on paper keeps its colour and ruled lines, and a new board starts without.
  func testRuledLinesStayWithTheBoardUnderTheInk() throws {
    let app = try openBoard()
    stroke(app)
    wait(send(app), label: "Send to Larry, 1 strokes")
    menu(app, "Cream", expect: "Board, Cream")
    menu(app, "Ruled lines", expect: "Board, Cream, ruled lines on")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let card = app.buttons.matching(identifier: "whiteboard-card").firstMatch
    XCTAssertTrue(card.appears(within: 10), app.debugDescription)
    card.tap()
    XCTAssertTrue(board(app).appears(within: 10), app.debugDescription)
    wait(board(app), label: "Board, Cream, ruled lines on")
    sleep(1)
    XCTAssertNotNil(PaperScreen(app).ink, "the ink is back with its colour and lines")

    app.navigationBars.buttons.element(boundBy: 0).tap()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 10), app.debugDescription)
    new.tap()
    XCTAssertTrue(board(app).appears(within: 10), app.debugDescription)
    wait(board(app), label: "Board, Plain")
  }

  /// Stories 655, 656: the colours show the page's end line and the grid, and changing either leaves pasted ink on screen.
  /// The lines are one grey at one strength on every colour, so they are hardest to see on the darkest paper: Lilac
  /// (`BoardPaper`'s light shades by luminance: Plain 1.0, Cream 0.90, Sage 0.83, Grey 0.82, Lilac 0.81). Lilac and back
  /// to Plain stand for all five; each colour's own shade against the ink is `BoardPaperTests`, on the host.
  func testEveryColourShowsItsLinesAndKeepsTheInk() throws {
    let app = try openBoard(["GRABBER_WHITEBOARD_PASTE": "HI"])
    wait(send(app), label: "Send to Larry, 2 strokes")
    sleep(2)
    let ink = try XCTUnwrap(PaperScreen(app).ink, "dark letters on screen")
    for colour in ["Lilac", "Plain"] {
      menu(app, colour, expect: "Board, \(colour)")
      let bare = Screen(app)
      let seen = try XCTUnwrap(PaperScreen(app).ink, "the letters on \(colour)")
      XCTAssertEqual(seen.center.x, ink.center.x, accuracy: 0.01, "\(colour): where they were")
      XCTAssertEqual(seen.center.y, ink.center.y, accuracy: 0.01, "\(colour): where they were")

      menu(app, "Grid lines", expect: "Board, \(colour), grid on")
      keep("grid on \(colour)")
      let grid = Screen(app).lines(against: bare)
      XCTAssertGreaterThan(grid.across, 5, "\(colour): the grid shows")
      XCTAssertNotNil(PaperScreen(app).ink, "\(colour): the letters with a grid")
      menu(app, "Grid lines", expect: "Board, \(colour)")
    }
    XCTAssertEqual(send(app).label, "Send to Larry, 2 strokes", "neither is ink")
  }

  /// Story 657: the first stroke after the menu draws, and after leaving the menu with no choice. One launch for the two.
  func testTheFirstStrokeAfterTheMenuDraws() throws {
    let app = try openBoard()
    menu(app, "Grey", expect: "Board, Grey")
    stroke(app)
    wait(send(app), label: "Send to Larry, 1 strokes")
    board(app).tap()
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.25)).tap()
    sleep(1)
    XCTAssertEqual(send(app).label, "Send to Larry, 1 strokes", "the tap that closes the menu draws nothing")
    stroke(app)
    wait(send(app), label: "Send to Larry, 2 strokes")
  }

  /// Story 657: choosing the colour the board already has costs no stroke either. Its own launch on a fresh board: chained
  /// after the cases above, on a board already Grey with two strokes, the menu tap missed the colour row (7 Nov).
  func testTheFirstStrokeAfterChoosingTheSameColourDraws() throws {
    let app = try openBoard()
    menu(app, "Plain", expect: "Board, Plain")
    stroke(app)
    wait(send(app), label: "Send to Larry, 1 strokes")
  }

  /// Story 655: a ghost shows on the colour furthest from white.
  func testAGhostShowsOnTheDarkestColours() throws {
    let app = try openBoard(ghostsOn: true)
    menu(app, "Grey", expect: "Board, Grey")
    let bare = Screen(app)
    stroke(app)
    wait(app.buttons["whiteboard-ghosts"], label: "Ghosts on, 1 showing", timeout: 10)
    sleep(1)
    keep("a ghost on Grey")
    XCTAssertGreaterThan(Screen(app).warmer(than: bare), 20, "an orange ghost on Grey")
  }
}
