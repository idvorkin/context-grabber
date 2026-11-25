//  Stories 1604–1606 (bead context-grabber-3kgu) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh
//  starts it): with the Cockpit answering 502 the chat list and an open thread say *Cockpit not answering*, keep what
//  they last read under it, and lose the banner by themselves once it answers. When it shows, what it says and when it
//  goes are `CockpitDownTests` on the host. Each test brings the fake back up, as the other chat classes share it.

import XCTest

final class ChatCockpitDownUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  override func tearDown() {
    if let cockpit {
      try? down(cockpit, nil)
      try? slow(cockpit, 0)
    }
  }

  private var cockpit: String? {
    ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"].flatMap { $0.isEmpty ? nil : $0 }
  }

  private func fakeCockpit() throws -> String {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh") }
    return cockpit
  }

  /// The fake's chat reads answer `status` (nil: answer as usual).
  private func down(_ cockpit: String, _ status: Int?) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/down")))
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: status.map { ["status": $0] } ?? [:])
    let done = expectation(description: "the fake Cockpit took /fake/down")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// Story 1608: the fake's thread reads wait `seconds` before they answer (0: at once).
  private func slow(_ cockpit: String, _ seconds: Double) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/slow")))
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: ["seconds": seconds])
    let done = expectation(description: "the fake Cockpit took /fake/slow")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  private func banner(_ app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Cockpit not answering"))
      .firstMatch
  }

  private func launch(_ cockpit: String, _ environment: [String: String]) -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    for (key, value) in environment { app.launchEnvironment[key] = value }
    app.launch()
    return app
  }

  /// Stories 1604, 1606: a list that never read says so at once, then fills and loses the banner when the Cockpit is up.
  func testTheListSaysTheCockpitIsDownAndClearsItself() throws {
    let cockpit = try fakeCockpit()
    try down(cockpit, 502)
    let app = launch(cockpit, ["GRABBER_INBOX": "open"])

    let said = banner(app)
    XCTAssertTrue(said.appears(within: 20), app.debugDescription)
    XCTAssertTrue(said.label.contains("answered HTTP 502"), said.label)
    XCTAssertTrue(said.label.contains("no good read since the app opened"), said.label)

    try down(cockpit, nil)
    // The list's own retry, every 15 seconds, reads it: no pull.
    XCTAssertTrue(app.buttons["chat-thread-igor2-88g.900"].appears(within: 40), app.debugDescription)
    XCTAssertTrue(said.disappears(within: 10), app.debugDescription)
  }

  /// Stories 1604–1606: an open thread keeps its messages under the banner and loses it at the first read through.
  func testAThreadKeepsItsMessagesUnderTheBannerAndClearsItself() throws {
    let cockpit = try fakeCockpit()
    let app = launch(cockpit, ["GRABBER_LINK": "grabbernative://chat?thread=igor2-88g.900"])
    let larrys = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", "Every four seconds, and the list on each return")).firstMatch
    XCTAssertTrue(larrys.appears(within: 20), app.debugDescription)

    try down(cockpit, 502)
    let said = banner(app)
    XCTAssertTrue(said.appears(within: 20), app.debugDescription)
    XCTAssertTrue(said.label.contains("reading this chat answered HTTP 502"), said.label)
    XCTAssertTrue(said.label.contains("last good read"), said.label)
    XCTAssertTrue(larrys.exists, "the messages last read stay under the banner")

    try down(cockpit, nil)
    XCTAssertTrue(said.disappears(within: 20), app.debugDescription)
    XCTAssertTrue(larrys.exists)
  }

  /// Story 1608 (#1362): a thread whose first read is slow says it is loading, then shows its messages in its place.
  func testASlowFirstReadSaysItIsLoading() throws {
    let cockpit = try fakeCockpit()
    try slow(cockpit, 6)
    // A thread read before shows the device's copy at once; this one must be a first read.
    let app = launch(
      cockpit, ["GRABBER_LINK": "grabbernative://chat?thread=igor2-88g.900", "GRABBER_CHAT_COPIES": "off"])
    let loading = app.descendants(matching: .any)["chat-thread-loading"]
    XCTAssertTrue(loading.appears(within: 10), app.debugDescription)
    let larrys = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", "Every four seconds, and the list on each return")).firstMatch
    XCTAssertTrue(larrys.appears(within: 20), app.debugDescription)
    XCTAssertFalse(loading.exists, "the messages replace the loading line")
  }
}
