//  Stories 262–264, 274 and 301 (#536, #449) and 500–505 (#637) on the simulator: only what the real screen can show.
//  Against the fake Cockpit (scripts/native/test-chat-ui.sh starts it), a typed first Send starts the thread under its
//  first line, the bar holds the next back until it lands, the next goes into that thread, and the field empties with
//  the keyboard still up. The voice button's mic is tapped as the new chat opens, and the + opens the ordinary bar with
//  the keyboard up; a live call keeps the microphone from it. Where a Send goes, when Send is enabled, the bar's lines,
//  the title, what waits on the phone and the focus rule are `ChatNewThreadScreenTests` and `ChatNewThreadTests`, on
//  the host. Speaking and pasting are phone checks.

import XCTest

final class ChatNewThreadUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// The bar, found by labels: the thread's identifier covers its children.
  private func field(_ app: XCUIApplication) -> XCUIElement {
    app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Message Larry")).firstMatch
  }

  /// The list's "Not sent yet" section header and its rows' lines. A count against the one before, not "none": another
  /// test's unsent message can still sit in this simulator's outbox.
  private func notSentLines(_ app: XCUIApplication) -> Int {
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Not sent yet")).count
  }

  /// Story 262 and 263 against the fake Cockpit: the first Send starts the thread, the next one goes into it.
  func testAFirstMessageStartsTheThreadAndTheNextGoesIntoIt() throws {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let first = "New chat test \(Int(Date().timeIntervalSince1970))"
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_INBOX"] = "open"
    app.launch()
    let plus = app.buttons["inbox-add"]
    XCTAssertTrue(plus.appears(within: 20), app.debugDescription)
    plus.tap()
    let field = field(app)
    XCTAssertTrue(field.appears(within: 5), app.debugDescription)
    field.tap()
    field.typeText(first)
    app.buttons["Send"].tap()

    // The title is the first line at once; the bar holds the next message back while the Cockpit takes it (the
    // fake holds POST /chat two seconds), then lets go.
    XCTAssertTrue(app.navigationBars[first].appears(within: 5), app.debugDescription)
    let waiting = app.staticTexts["The next message goes once your first one reaches Larry."]
    XCTAssertTrue(waiting.appears(within: 3), "the hold-back line: \(app.debugDescription)")
    let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: waiting)
    wait(for: [gone], timeout: 20)
    // The first send asks for notifications (chat spec); a clean simulator shows the system alert over the keyboard.
    let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
    if allow.appears(within: 3) { allow.tap() }

    let second = "and the next one"
    field.tap()
    field.typeText(second)
    XCTAssertTrue(app.buttons["Send"].isEnabled, "the next message can go now")
    app.buttons["Send"].tap()

    // Story 274 (#449): the field empties, with the keyboard still up, and the next words go in with no tap.
    let empty = NSPredicate { _, _ in
      ((field.value as? String) ?? "").replacingOccurrences(of: "Message Larry", with: "").isEmpty
    }
    wait(for: [expectation(for: empty, evaluatedWith: field)], timeout: 5)
    XCTAssertTrue(app.keyboards.firstMatch.exists, "the keyboard stays up for the next message")
    field.typeText("third")
    XCTAssertTrue(app.buttons["Send"].isEnabled, "the words went into the field")

    // On the Cockpit: one thread under the first line, holding both messages.
    let deadline = Date().addingTimeInterval(20)
    var texts: [String] = []
    while Date() < deadline {
      if let key = try thread(titled: first, at: cockpit) { texts = try messages(in: key, at: cockpit) }
      if texts.contains(second) { break }
      Thread.sleep(forTimeInterval: 1)
    }
    XCTAssertTrue(texts.contains(first), "the first message started the thread: \(texts)")
    XCTAssertTrue(texts.contains(second), "the second went to POST /chat/<key>: \(texts)")
  }

  /// Stories 500, 502 and 504: the button beside the + opens the same new chat, and its mic has already been tapped.
  /// The simulator's first run asks for speech recognition; declining is story 504's copyable line, in the new chat's
  /// bar. Whichever way the recognizer goes, a tap was made for him: the mic is on its way, or it says why not.
  func testTheVoiceButtonOpensANewChatWithItsMicTapped() throws {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_INBOX"] = "open"
    app.launch()
    let plus = app.buttons["inbox-add"]
    let voice = app.buttons["inbox-add-voice"]
    XCTAssertTrue(voice.appears(within: 20), app.debugDescription)
    XCTAssertLessThanOrEqual(voice.frame.maxX, plus.frame.minX, "the voice button comes before the +")
    XCTAssertLessThanOrEqual(plus.frame.minX - voice.frame.maxX, 12, "right beside it")
    XCTAssertGreaterThanOrEqual(voice.frame.width, 44)
    XCTAssertGreaterThanOrEqual(voice.frame.height, 44)
    let notSentBefore = notSentLines(app)
    voice.tap()
    XCTAssertTrue(app.navigationBars["New chat"].appears(within: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["Send and start another"].exists, "no sheet")

    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let deadline = Date().addingTimeInterval(20)
    var answered = false
    while Date() < deadline, !answered {
      let decline = springboard.alerts.buttons["Don\u{2019}t Allow"]
      if decline.exists { decline.tap() }
      answered = micAnswered(app)
      if !answered { Thread.sleep(forTimeInterval: 0.5) }
    }
    XCTAssertTrue(answered, "the mic was tapped as it opened: \(app.debugDescription)")
    XCTAssertTrue(app.navigationBars["New chat"].exists, "nothing started a thread")
    XCTAssertFalse(app.descendants(matching: .any)["chat-new-waiting"].exists, "nothing was sent")

    // Story 502: back stops whatever was going and leaves no thread.
    app.navigationBars["New chat"].buttons.firstMatch.tap()
    XCTAssertTrue(plus.appears(within: 5), app.debugDescription)
    XCTAssertLessThanOrEqual(notSentLines(app), notSentBefore, "no new thread waits to go: \(app.debugDescription)")

    // Story 505: the + after it records nothing. Stories 262 and 301: it opens the ordinary bar, not the old sheet,
    // with the keyboard up.
    plus.tap()
    XCTAssertTrue(app.navigationBars["New chat"].appears(within: 5), app.debugDescription)
    let bar = field(app)
    XCTAssertTrue(bar.appears(within: 5), app.debugDescription)
    XCTAssertTrue(app.buttons["Speak a message"].appears(within: 5), "the + leaves the mic idle")
    XCTAssertFalse(app.buttons["Stop recording"].exists)
    XCTAssertTrue(app.buttons["Paste image"].exists, "Paste image is on the bar")
    XCTAssertTrue(app.buttons["Microphone: Automatic"].exists, "the microphone picker is on the bar")
    XCTAssertFalse(app.buttons["Send"].isEnabled, "nothing to send yet")
    XCTAssertFalse(app.buttons["Send and start another"].exists, "no sheet")
    XCTAssertFalse(app.buttons["Cancel"].exists, "no sheet")
    wait(for: [expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: bar)], timeout: 5)
  }

  /// Recording, on its way there, or its copyable line saying why not.
  private func micAnswered(_ app: XCUIApplication) -> Bool {
    if app.buttons["Stop recording"].exists { return true }
    let why = NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "off for this app", "could not start")
    return app.staticTexts.matching(why).firstMatch.exists
  }

  /// Story 503 with a real call, against the fake bridge test-chat-ui.sh starts: the button stands down and the new
  /// chat records nothing, says why and has the keyboard up.
  func testALiveCallKeepsTheMicFromTheVoiceButton() throws {
    guard let bridge = ProcessInfo.processInfo.environment["GRABBER_FAKE_BRIDGE"], !bridge.isEmpty else {
      throw XCTSkip("needs the fake bridge: run scripts/native/test-chat-ui.sh")
    }
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_CALL"] = bridge
    app.launchEnvironment["GRABBER_CALL_AUDIO"] = "synthetic"
    app.launchEnvironment["GRABBER_CALL_SECONDS"] = "120"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()
    let done = app.buttons["Done"]
    XCTAssertTrue(done.appears(within: 20), app.debugDescription)
    Thread.sleep(forTimeInterval: 2)  // the hook places the call a second after the screen opens
    done.tap()
    let tile = app.buttons["home-inbox"]
    XCTAssertTrue(tile.appears(within: 10), app.debugDescription)
    tile.tap()
    let voice = app.buttons["inbox-add-voice"]
    XCTAssertTrue(voice.appears(within: 10), app.debugDescription)
    voice.tap()
    XCTAssertTrue(app.navigationBars["New chat"].appears(within: 5), app.debugDescription)
    let line = app.staticTexts["A call with Larry is using the microphone. End it to speak a message."]
    XCTAssertTrue(line.appears(within: 5), "the bar says why: \(app.debugDescription)")
    XCTAssertTrue(app.buttons["Speak a message"].exists, "nothing is recording")
    XCTAssertFalse(app.buttons["Stop recording"].exists)
    let focus = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field(app))
    wait(for: [focus], timeout: 5)
  }

  private func get(_ url: String) throws -> [String: Any] {
    let data = try Data(contentsOf: XCTUnwrap(URL(string: url)))
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  private func thread(titled title: String, at cockpit: String) throws -> String? {
    let rows = try get(cockpit + "/chat")["threads"] as? [[String: Any]] ?? []
    return rows.first { $0["title"] as? String == title }?["key"] as? String
  }

  private func messages(in key: String, at cockpit: String) throws -> [String] {
    let rows = try get(cockpit + "/chat/" + key)["messages"] as? [[String: Any]] ?? []
    return rows.filter { $0["who"] as? String == "igor" }.compactMap { $0["text"] as? String }
  }
}
