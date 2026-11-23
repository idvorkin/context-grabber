//  Story 910 on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): an arrow drawn
//  from one word to another, selected, offers Connect, and Connect leaves one clean arrow in its place. Where its ends
//  land, how it routes and how it follows are `BoardConnectorsTests` on the host; this checks the button reaches them on
//  paper. The simulator can't draw a lasso, so `GRABBER_WHITEBOARD_SELECT_NEWEST` selects the arrow as one would.

import XCTest

final class WhiteboardConnectUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func cockpit() throws -> String {
    try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
  }

  private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
  }

  private func wait(_ element: XCUIElement, label: String, timeout: TimeInterval = 10) {
    waitUntil(NSPredicate(format: "label == %@", label), element, timeout: timeout)
  }

  func testALassoedArrowBetweenTwoWordsConnectsThem() throws {
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit()
    app.launchEnvironment["GRABBER_WHITEBOARD_SELECT_NEWEST"] = "3"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    let ghosts = app.buttons["whiteboard-ghosts"]
    XCTAssertTrue(ghosts.appears(within: 10), app.debugDescription)
    if ghosts.label.hasPrefix("Ghosts on") { ghosts.tap() }
    sleep(1)
    // Two "words", then an arrow from the first's end to the second's start.
    point(app, 0.12, 0.30).press(forDuration: 0.05, thenDragTo: point(app, 0.25, 0.31))
    point(app, 0.60, 0.50).press(forDuration: 0.05, thenDragTo: point(app, 0.75, 0.51))
    let send = app.buttons["whiteboard-send"]
    wait(send, label: "Send to Larry, 2 strokes")
    point(app, 0.26, 0.31).press(forDuration: 0.05, thenDragTo: point(app, 0.59, 0.50))
    wait(send, label: "Send to Larry, 3 strokes")
    let connect = app.buttons["whiteboard-connect"]
    XCTAssertTrue(connect.appears(within: 5), "Connect beside the selected arrow: \(app.debugDescription)")
    // Story 1095: the label above it names it as an arrow Connect can join.
    let named = app.descendants(matching: .any)["whiteboard-selection-label"]
    XCTAssertTrue(named.appears(within: 5), "the selection's label: \(app.debugDescription)")
    XCTAssertEqual(named.label, "Selected: Arrow, Connect")
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "arrow selected, with Connect"
    picture.lifetime = .keepAlways
    add(picture)
    XCTContext.runActivity(named: "Connect: hittable \(connect.isHittable), frame \(connect.frame)") { _ in }
    connect.tap()
    // The drawn arrow goes and the connector takes its place: still three strokes, and Connect goes with the selection.
    // `waitUntil` reads a missing element as not yet, so going away is waited for here.
    let gone = Date().addingTimeInterval(5)
    while connect.exists, Date() < gone { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
    XCTAssertFalse(connect.exists, "Connect goes once it is used")
    wait(send, label: "Send to Larry, 3 strokes")
    let cockpit = try cockpit()
    let sent = try sends(cockpit).count
    app.buttons["whiteboard-send"].tap()
    let ids = try newSend(cockpit, after: sent)
    XCTAssertTrue(ids.contains { $0.hasPrefix("c-") }, "the connector goes to Larry under its name: \(ids)")
  }

  /// Story 918: Larry's reply carries a connector mark between two words: it shows as a ghost, and Keep all makes it a
  /// connector that goes back to him under its mark's name. How it routes and follows is `BoardConnectorsTests`.
  func testLarrysConnectorMarkKeepsAsAConnector() throws {
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
    if ghosts.label.hasPrefix("Ghosts off") { ghosts.tap() }
    sleep(2)
    point(app, 0.12, 0.30).press(forDuration: 0.05, thenDragTo: point(app, 0.25, 0.31))
    point(app, 0.60, 0.50).press(forDuration: 0.05, thenDragTo: point(app, 0.75, 0.51))
    let send = app.buttons["whiteboard-send"]
    wait(send, label: "Send to Larry, 2 strokes")
    try post(cockpit + "/fake/larry-ops", #"{"kind": "connector_marks"}"#)
    app.buttons["whiteboard-send"].tap()
    let keepAll = app.buttons["whiteboard-keep-all"]
    XCTAssertTrue(keepAll.appears(within: 15), "his connector shows as a ghost to keep: \(app.debugDescription)")
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "his connector as a ghost"
    picture.lifetime = .keepAlways
    add(picture)
    keepAll.tap()
    wait(send, label: "Send to Larry, 3 strokes")
    let sent = try sends(cockpit).count
    app.buttons["whiteboard-send"].tap()
    let ids = try newSend(cockpit, after: sent)
    XCTAssertTrue(ids.contains { $0.hasPrefix("m-") }, "the connector goes back under its mark's name: \(ids)")
  }

  private func post(_ url: String, _ body: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: url)))
    request.httpMethod = "POST"
    request.httpBody = Data(body.utf8)
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// The ids of the send after the first `count`, when it comes.
  private func newSend(_ cockpit: String, after count: Int) throws -> [String] {
    let until = Date().addingTimeInterval(15)
    while Date() < until {
      let all = try sends(cockpit)
      if all.count > count { return all[count] }
      Thread.sleep(forTimeInterval: 0.5)
    }
    XCTFail("no strokes reached the fake Cockpit")
    return []
  }

  /// The stroke ids of each POST /whiteboard/strokes so far.
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
}
