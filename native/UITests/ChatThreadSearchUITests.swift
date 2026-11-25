//  Stories 1616-1618 (#1443) on the simulator, against the fake Cockpit's GET /chat?q (scripts/native/test-chat-ui.sh
//  starts it): the chat list's search box finds a thread by its title, finds one whose word is only in an older message
//  once the Cockpit answers, says *No chats match.*, keeps the phone's own matches under a copyable problem when the Cockpit's
//  search fails, and an emptied box brings the list back. The matching, merge and request are `ChatThreadSearchTests` on
//  the host. While the whiteboard work runs (Igor, 2026-11-22) it is run on the iPad's simulator.

import XCTest

final class ChatThreadSearchUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  override func tearDown() {
    if let cockpit {
      try? post(cockpit, "/fake/search-down", [:])
      try? post(cockpit, "/fake/search-thread", ["on": false])
    }
  }

  private var cockpit: String? {
    ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"].flatMap { $0.isEmpty ? nil : $0 }
  }

  private func post(_ cockpit: String, _ path: String, _ body: [String: Any]) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + path)))
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let done = expectation(description: "the fake Cockpit took \(path)")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  /// Empties the box and types the words, as Igor would.
  private func search(_ field: XCUIElement, _ words: String) {
    field.tap()
    if let typed = field.value as? String, !typed.isEmpty, typed != field.placeholderValue {
      field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
    }
    field.typeText(words)
  }

  /// Every thread row on screen. The fake Cockpit's list grows as other chat tests start threads, so a fixed row can sit
  /// out of view (bead context-grabber-bsvc, like 6d1b): the list is judged by its rows, never by one id's position.
  private func rows(_ app: XCUIApplication, except id: String? = nil) -> XCUIElementQuery {
    let thread = NSPredicate(format: "identifier BEGINSWITH %@", "chat-thread-")
    guard let id else { return app.buttons.matching(thread) }
    return app.buttons.matching(
      NSCompoundPredicate(andPredicateWithSubpredicates: [thread, NSPredicate(format: "identifier != %@", id)]))
  }

  /// True once `query` has `test(count)` true, looking every 0.1 s.
  private func count(_ query: XCUIElementQuery, within seconds: TimeInterval = 10, _ test: (Int) -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    repeat {
      if test(query.count) { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    } while Date() < deadline
    return test(query.count)
  }

  private func gone(_ element: XCUIElement, within seconds: TimeInterval = 10) -> Bool {
    let done = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
    return XCTWaiter().wait(for: [done], timeout: seconds) == .completed
  }

  func testSearchFindsThreadsByTitleAndBeadAndSurvivesTheCockpitDown() throws {
    guard let cockpit else { throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh") }
    try post(cockpit, "/fake/search-thread", ["on": true])
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_INBOX"] = "open"
    app.launch()

    let laptopsID = "chat-thread-igor2-88g.817"
    let laptops = app.buttons[laptopsID]
    let travel = app.buttons["chat-thread-igor2-88g.1443"]
    XCTAssertTrue(rows(app).firstMatch.appears(within: 20), "the list loaded: \(app.debugDescription)")
    // The box sits under the title and shows once the list is pulled down a little.
    let field = app.searchFields.firstMatch
    if !field.exists { app.collectionViews.firstMatch.swipeDown() }
    XCTAssertTrue(field.appears(within: 5), app.debugDescription)

    // Story 1616: a title's word, any case: only that thread.
    search(field, "LAPTOPS")
    XCTAssertTrue(laptops.appears(within: 10), app.debugDescription)
    XCTAssertTrue(
      count(rows(app, except: laptopsID)) { $0 == 0 }, "only the matching thread: \(app.debugDescription)")
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "chat-search-laptops"
    shot.lifetime = .keepAlways
    add(shot)

    // Story 1617: a word only in an older message, found once the Cockpit answers.
    search(field, "passport")
    XCTAssertTrue(travel.appears(within: 10), app.debugDescription)
    XCTAssertTrue(gone(laptops), app.debugDescription)

    // No match at all.
    search(field, "zebra")
    XCTAssertTrue(app.staticTexts["chat-search-empty"].appears(within: 10), app.debugDescription)
    XCTAssertEqual(app.staticTexts["chat-search-empty"].label, "No chats match.")

    // Story 1618: the Cockpit's search down: the phone's own match still shows, under the copyable problem.
    try post(cockpit, "/fake/search-down", ["status": 502])
    search(field, "laptops")
    XCTAssertTrue(laptops.appears(within: 10), app.debugDescription)
    let problem = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "HTTP 502"))
      .firstMatch
    XCTAssertTrue(problem.appears(within: 10), app.debugDescription)
    try post(cockpit, "/fake/search-down", [:])

    // An emptied box brings the list back; a tap on a result opens the thread.
    search(field, "")
    XCTAssertTrue(count(rows(app)) { $0 > 1 }, "the list is back: \(app.debugDescription)")
    search(field, "laptops")
    XCTAssertTrue(laptops.appears(within: 10), app.debugDescription)
    laptops.tap()
    XCTAssertTrue(
      app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Want the cheapest"))
        .firstMatch.appears(within: 10), "the thread opened: \(app.debugDescription)")
  }
}
