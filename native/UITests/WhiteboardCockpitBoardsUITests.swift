//  Stories 1339-1340 (cockpit-8kh) on an iPad simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it): with Boards from the Cockpit (beta) off, the boards list is as before; on, a *From the Cockpit* section
//  lists the store's boards with their versions. The requests, the rows and the sync pass are
//  `CockpitBoardStoreTests`, on the host.

import XCTest

final class WhiteboardCockpitBoardsUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private var cockpit: String {
    get throws {
      try XCTUnwrap(
        ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    }
  }

  /// A board in the fake's store, made the way a device makes one (`POST /boards`).
  private func makeBoard(_ id: String, name: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: try cockpit + "/boards")))
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: ["id": id, "name": name, "device": "web-3f9a"])
    let done = expectation(description: "the fake Cockpit made the board")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  private func launch(switchOn: Bool) throws -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = try cockpit
    app.launchArguments += ["-whiteboard_boards_from_cockpit", switchOn ? "YES" : "NO"]
    app.launch()
    return app
  }

  /// Story 1339: off, the list is the iPad's own boards and nothing from the Cockpit.
  func testOffTheListHasNoCockpitSection() throws {
    try makeBoard("ui-store-off", name: "Not listed")
    let app = try launch(switchOn: false)
    XCTAssertTrue(app.buttons["whiteboard-new"].appears(within: 20), app.debugDescription)
    sleep(2)
    XCTAssertFalse(app.descendants(matching: .any)["cockpit-board-ui-store-off"].exists, app.debugDescription)
    XCTAssertFalse(app.staticTexts["From the Cockpit"].exists, app.debugDescription)
  }

  /// Story 1340: on, the Cockpit's board is listed above the iPad's own, with its versions.
  func testOnTheListShowsTheCockpitsBoards() throws {
    try makeBoard("ui-store-on", name: "Store trial")
    let app = try launch(switchOn: true)
    let row = app.descendants(matching: .any)["cockpit-board-ui-store-on"]
    XCTAssertTrue(row.appears(within: 20), app.debugDescription)
    XCTAssertTrue(row.label.contains("Store trial"), row.label)
    XCTAssertTrue(row.label.contains("versions"), row.label)
    XCTAssertTrue(app.staticTexts["From the Cockpit"].exists, app.debugDescription)
  }
}
