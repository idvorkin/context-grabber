//  Stories 1349–1351 (#1528) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it):
//  Larry's diagram, two boxes (a rectangle with a label inside) and an arrow between them, kept with Keep all. A tap on
//  one box selects it alone, a finger drags it, the other box stays, and the arrow follows the moved box. Where the ink
//  sits is read from the screen's pixels (`PaperScreen`, in WhiteboardPaperGhostsUITests.swift). Which marks make a box
//  is `WhiteboardDiagramTests`.

import XCTest

final class WhiteboardDiagramBoxesUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  private func larryDrawsADiagram(_ cockpit: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/larry-draws")))
    request.httpMethod = "POST"
    request.httpBody = Data(#"{"diagram": true}"#.utf8)
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = name
    picture.lifetime = .keepAlways
    add(picture)
  }

  /// Larry's diagram kept with Keep all on a new board, Ghosts off: where all of it shows.
  private func keptDiagram(_ app: XCUIApplication) throws -> PaperScreen.Box {
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
    if ghosts.label.hasPrefix("Ask at my pauses: on") { ghosts.tap() }  // Ghosts off: only Larry's marks show.
    let pen = app.buttons["Pen"]
    XCTAssertTrue(pen.appears(within: 10), "the tool picker: \(app.debugDescription)")
    if !pen.isSelected { pen.tap() }
    sleep(2)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.7)))
    let send = app.buttons["whiteboard-send"]
    waitUntil(NSPredicate(format: "label == %@", "Send to Larry, 1 strokes"), send, timeout: 10)
    try WhiteboardWordsOnlyFixture.prepare(cockpit, for: self)
    app.buttons["whiteboard-send"].tap()
    XCTAssertTrue(WhiteboardWordsOnlyFixture.reply(in: app).appears(within: 15), app.debugDescription)
    try larryDrawsADiagram(cockpit)
    let keepAll = app.buttons["whiteboard-keep-all"]
    XCTAssertTrue(keepAll.appears(within: 15), app.debugDescription)
    _ = try XCTUnwrap(PaperScreen.settled(app) { $0.larryGhost }, "his diagram, faint")
    shot(app, "his diagram as ghosts")
    keepAll.tap()
    let kept = try XCTUnwrap(PaperScreen.settled(app) { $0.larryKept }, "his diagram kept, in his purple")
    shot(app, "kept")
    return kept
  }

  private func strip(_ kept: PaperScreen.Box, from: CGFloat, to: CGFloat, below: CGFloat = 0.3) -> PaperScreen.Box {
    PaperScreen.Box(
      minX: kept.minX + kept.width * from, minY: kept.minY - 0.02, maxX: kept.minX + kept.width * to,
      maxY: kept.maxY + below)
  }

  /// Stories 1349 and 1351: the left box drags on its own; the right box stays; the arrow follows the left one down.
  func testABoxDragsAsOneThingAndItsArrowFollows() throws {
    let app = XCUIApplication.forTests(animated: true)
    let kept = try keptDiagram(app)
    let leftStrip = strip(kept, from: 0, to: 0.3)
    let rightStrip = strip(kept, from: 0.7, to: 1)
    let middleStrip = strip(kept, from: 0.4, to: 0.6)
    let screen = PaperScreen(app)
    let left = try XCTUnwrap(screen.larryKept(in: leftStrip), "the left box")
    let right = try XCTUnwrap(screen.larryKept(in: rightStrip), "the right box")
    let arrow = try XCTUnwrap(screen.larryKept(in: middleStrip), "the arrow between them")

    PaperScreen.tap(app, CGPoint(x: left.minX + 0.002, y: left.center.y))
    XCTAssertTrue(app.selectionLabel.appears(within: 5), "the tap selected the box: \(app.debugDescription)")
    shot(app, "the left box selected")
    let from = app.coordinate(withNormalizedOffset: CGVector(dx: left.center.x, dy: left.center.y))
    let to = app.coordinate(withNormalizedOffset: CGVector(dx: left.center.x, dy: left.center.y + 0.15))
    from.press(forDuration: 0.3, thenDragTo: to, withVelocity: 200, thenHoldForDuration: 0.5)
    sleep(1)

    let moved = PaperScreen.settled(app, within: 10) { screen in
      guard let box = screen.larryKept(in: leftStrip), abs(box.minY - left.minY - 0.15) < 0.03 else { return nil }
      return box
    }
    shot(app, "dragged")
    XCTAssertNotNil(moved, "the left box, label and all, moved down from \(left)")
    let stayed = try XCTUnwrap(PaperScreen(app).larryKept(in: rightStrip), "the right box")
    XCTAssertEqual(stayed.minY, right.minY, accuracy: 0.01, "the right box stayed where it was")
    XCTAssertEqual(stayed.maxY, right.maxY, accuracy: 0.01, "the right box stayed where it was")
    let followed = PaperScreen.settled(app, within: 10) { screen in
      guard let ink = screen.larryKept(in: middleStrip), ink.maxY > arrow.maxY + 0.03 else { return nil }
      return ink
    }
    XCTAssertNotNil(followed, "the arrow re-routed toward the moved box, below where it was (\(arrow))")
  }
}
