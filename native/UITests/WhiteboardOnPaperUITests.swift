//  Stories 590–612 and 658 on the simulator, its ghosts in `WhiteboardPaperGhostsUITests`: a new board is a real board on
//  paper, and a board drawn on the old canvas opens look-only on paper. How the Pencil feels and what a finger does with one paired are the iPad's (`whiteboard` action: paper_touch).
//  A finger draws on the simulator.

import XCTest

final class WhiteboardOnPaperUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func launch(_ environment: [String: String] = [:]) -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:65530"
    for (key, value) in environment { app.launchEnvironment[key] = value }
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

  private func newBoard(_ app: XCUIApplication) {
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    XCTAssertTrue(app.buttons["whiteboard-send"].appears(within: 10), app.debugDescription)
  }

  /// By its words: the board's screen gives its own id to what's inside it.
  private func pageNumber(_ app: XCUIApplication) -> XCUIElement {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Page '")).firstMatch
  }

  private func copyError(_ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label == 'Copy error'")).firstMatch
  }

  private func row(_ app: XCUIApplication, _ text: String) -> XCUIElement {
    app.buttons.matching(identifier: "whiteboard-card").matching(NSPredicate(format: "label CONTAINS %@", text))
      .firstMatch
  }

  /// Stories 590–593, 597, 598, 603, 651: a new board is on paper (there's no switch, 2026-11-07), what its menu offers,
  /// and its ink through a relaunch.
  func testANewBoardIsOnPaperAndKeepsItsInk() {
    var app = launch()
    newBoard(app)
    let page = pageNumber(app)
    XCTAssertTrue(page.appears(within: 10), app.debugDescription)
    waitFor(page, label: "Page 1 of 1")
    XCTAssertTrue(app.buttons["whiteboard-board"].exists, "the colours are still there")
    sleep(2)
    keep(app, "a new board on paper")

    let send = app.buttons["whiteboard-send"]
    stroke(app, atHeight: 0.3)
    waitFor(send, label: "Send to Larry, 1 strokes")
    waitFor(page, label: "Page 1 of 2")
    keep(app, "ink brings the next page")

    // Story 597.
    let colours = app.buttons["whiteboard-board"]
    colours.tap()
    let sage = app.descendants(matching: .any)["Sage"].firstMatch
    XCTAssertTrue(sage.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.descendants(matching: .any)["Grid lines"].exists, "story 652: the grid")
    XCTAssertTrue(app.descendants(matching: .any)["Ruled lines"].exists, "story 434: ruled lines")
    sage.tapWhenSettled()
    waitFor(colours, label: "Board, Sage")
    sleep(1)
    keep(app, "the paper in sage")
    sleep(1)  // Past the second the board waits before it saves, and it's the save that's being looked at.

    // Killed, not closed: what's on the board is what the save wrote a moment after the stroke.
    app.terminate()
    app = launch()
    let saved = row(app, "On paper")
    XCTAssertTrue(saved.appears(within: 20), app.debugDescription)
    saved.tap()
    XCTAssertTrue(send.appears(within: 10), app.debugDescription)
    waitFor(send, label: "Send to Larry, 1 strokes")
    waitFor(page, label: "Page 1 of 2")
    keep(app, "the same ink after a relaunch")

    // Story 603: another stroke, and it stays where it was drawn.
    sleep(1)
    stroke(app, atHeight: 0.4)
    waitFor(send, label: "Send to Larry, 2 strokes")
  }

  /// Story 658: a board drawn on the old canvas opens on paper to look at only: its ink on the first page, the bar saying
  /// why, and no tools, no Board menu and no Send. A finger drag pans; nothing draws.
  func testAnOldCanvasBoardOpensLookOnlyOnPaper() throws {
    // A fresh id, so runs on one simulator don't meet each other's boards; opened by its link, as the list holds many.
    let id = "old-canvas-\(UUID().uuidString.lowercased())"
    let app = launch([
      "GRABBER_BOARD_FIXTURE": id, "GRABBER_BOARD_FIXTURE_OLD_INK": "40",
      "GRABBER_LINK": "grabbernative://whiteboard?board=\(id)",
    ])
    let page = pageNumber(app)
    XCTAssertTrue(page.appears(within: 10), app.debugDescription)
    let note = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Drawn on the old canvas: look only"))
    XCTAssertTrue(note.firstMatch.appears(within: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["whiteboard-send"].exists, "nothing to send")
    XCTAssertFalse(app.buttons["whiteboard-board"].exists, "no Board menu")
    XCTAssertFalse(app.buttons["whiteboard-ghosts"].exists, "no ghosts")
    sleep(2)
    keep(app, "an old-canvas board, look only")
    // The old ink is a row at the page's very top: search from just under the navigation bar (#845), left of the page
    // number, whose black text would otherwise pass for ink.
    let window = app.windows.firstMatch.frame
    let top = app.navigationBars.firstMatch.frame.maxY / window.height + 0.01
    let right = page.frame.minX / window.width
    let ink = try XCTUnwrap(PaperScreen(app, top: top, right: right).ink, "the old ink on the first page")

    // Right to left: since iOS 26 a swipe to the right anywhere is Back, and on an iPad the page fits the width, so
    // nothing scrolls sideways to take it first (#845).
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.75))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.75)))
    sleep(2)
    let after = try XCTUnwrap(PaperScreen(app, top: top, right: right).ink, "the old ink still there")
    XCTAssertEqual(after.maxY - after.minY, ink.maxY - ink.minY, accuracy: 0.02, "a drag below the ink drew nothing")
  }

  /// Story 609: in dark mode new ink can be seen. PaperKit left to itself draws it black on black. Read off the screenshot:
  /// the canvas isn't in the accessibility tree.
  func testInkShowsInDarkMode() throws {
    let mode = XCUIDevice.shared.appearance
    addTeardownBlock { XCUIDevice.shared.appearance = mode }
    XCUIDevice.shared.appearance = .dark
    let app = launch()
    newBoard(app)
    sleep(2)
    // The first stroke brings page 2, and on a phone that moves the view: the second is the one that stays put.
    stroke(app, atHeight: 0.3)
    waitFor(app.buttons["whiteboard-send"], label: "Send to Larry, 1 strokes")
    sleep(1)
    stroke(app, atHeight: 0.5)
    waitFor(app.buttons["whiteboard-send"], label: "Send to Larry, 2 strokes")
    sleep(1)
    let shot = app.screenshot()
    keep(app, "ink in dark mode")
    let image = try XCTUnwrap(shot.image.cgImage)
    let context = try XCTUnwrap(
      CGContext(
        data: nil, width: 1, height: 200, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    // One pixel wide and 200 tall, through the middle of the stroke, from the screen's own pixels.
    let (x, y) = (CGFloat(image.width) * 0.45, CGFloat(image.height) * 0.5)
    let strip = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y - 100, width: 1, height: 200)))
    context.draw(strip, in: CGRect(x: 0, y: 0, width: 1, height: 200))
    let data = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: 800)
    let brightness = (0..<200).map { Int(data[$0 * 4]) }
    let (lightest, darkest) = (brightness.max() ?? 0, brightness.min() ?? 0)
    XCTAssertGreaterThan(lightest, 200, "the paper is its pale shade")
    XCTAssertLessThan(darkest, 90, "and the ink on it is dark enough to see")

    // The list goes back to the device's mode.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["whiteboard-new"].appears(within: 10), app.debugDescription)
    sleep(2)  // Past the board sliding away, whose screen is still light.
    keep(app, "the list after a board on paper, in dark mode")
    let list = try XCTUnwrap(app.screenshot().image.cgImage)
    let corner = try XCTUnwrap(list.cropping(to: CGRect(x: 4, y: list.height / 2, width: 1, height: 1)))
    context.draw(corner, in: CGRect(x: 0, y: 0, width: 1, height: 200))
    XCTAssertLessThan(Int(data[0]), 60, "the boards list is dark again")
  }

  /// Stories 599, 612: a failed save is a problem that can be copied, on the board, and on the list if he then leaves.
  func testAFailedSaveShowsAndDoesNotVanishOnLeaving() {
    let app = launch([
      "GRABBER_WHITEBOARD_SAVE_FAILS": "1"
    ])
    newBoard(app)
    sleep(2)
    stroke(app, atHeight: 0.3)
    let copy = copyError(app)
    XCTAssertTrue(copy.appears(within: 10), "on the board" + app.debugDescription)
    keep(app, "a failed save on the board")
    sleep(1)
    stroke(app, atHeight: 0.4)
    sleep(1)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["whiteboard-new"].appears(within: 10), app.debugDescription)
    XCTAssertTrue(copy.appears(within: 10), "on the list" + app.debugDescription)
    keep(app, "a failed save on the list")
  }
}
