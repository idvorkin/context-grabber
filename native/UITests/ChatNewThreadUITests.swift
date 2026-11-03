//  Stories 262–264 and 301 (#536) on the simulator: Chat's + opens a new, empty thread with the ordinary bar (the field,
//  Paste image, the mic), not the old New chat sheet. Against the fake Cockpit (scripts/native/test-chat-ui.sh starts
//  it), the first Send starts the thread under its first line, the bar holds the next message back until it lands,
//  and the next one goes into that thread. The voice button beside the + (#637, stories 470–474) too: its mic is
//  tapped as it opens, and a live call keeps the microphone from it. Speaking and pasting are phone checks.

import XCTest

final class ChatNewThreadUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// The bar, found by labels: the thread's identifier covers its children.
  private func field(_ app: XCUIApplication) -> XCUIElement {
    app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Message Larry")).firstMatch
  }

  func testThePlusOpensANewThreadWithTheOrdinaryBar() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_INBOX"] = "open"
    app.launch()
    let plus = app.buttons["inbox-add"]
    XCTAssertTrue(plus.waitForExistence(timeout: 20), app.debugDescription)
    plus.tap()
    XCTAssertTrue(app.navigationBars["New chat"].waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertTrue(field(app).waitForExistence(timeout: 5), "the ordinary bar's field: \(app.debugDescription)")
    XCTAssertTrue(app.buttons["Paste image"].exists, "Paste image is on the bar")
    XCTAssertTrue(app.buttons["Speak a message"].exists, "the chat mic is on the bar")
    XCTAssertTrue(app.buttons["Microphone: Automatic"].exists, "the microphone picker is on the bar")
    XCTAssertFalse(app.buttons["Send"].isEnabled, "nothing to send yet")
    XCTAssertFalse(app.buttons["Send and start another"].exists, "no sheet")
    XCTAssertFalse(app.buttons["Cancel"].exists, "no sheet")

    // Back with nothing sent leaves no thread behind.
    app.navigationBars["New chat"].buttons.firstMatch.tap()
    XCTAssertTrue(plus.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.descendants(matching: .any)["chat-pending-waiting"].exists, "no new thread waits to go")
  }

  /// GRABBER_CHAT_NEW=open: Chat with its + tapped, the new chat's field ready to type in.
  func testTheHookOpensANewChatWithTheFieldFocused() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_CHAT_NEW"] = "open"
    app.launch()
    XCTAssertTrue(app.navigationBars["New chat"].waitForExistence(timeout: 20), app.debugDescription)
    let field = field(app)
    XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
    let focused = NSPredicate(format: "hasKeyboardFocus == true")
    let focus = expectation(for: focused, evaluatedWith: field)
    wait(for: [focus], timeout: 5)
  }

  /// Story 262 and 263 against the fake Cockpit: the first Send starts the thread, the next one goes into it.
  func testAFirstMessageStartsTheThreadAndTheNextGoesIntoIt() throws {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let first = "New chat test \(Int(Date().timeIntervalSince1970))"
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_INBOX"] = "open"
    app.launch()
    let plus = app.buttons["inbox-add"]
    XCTAssertTrue(plus.waitForExistence(timeout: 20), app.debugDescription)
    plus.tap()
    let field = field(app)
    XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
    field.tap()
    field.typeText(first)
    app.buttons["Send"].tap()

    // The title is the first line at once; the bar holds the next message back while the Cockpit takes it (the
    // fake holds POST /chat three seconds), then lets go.
    XCTAssertTrue(app.navigationBars[first].waitForExistence(timeout: 5), app.debugDescription)
    let waiting = app.staticTexts["The next message goes once your first one reaches Larry."]
    XCTAssertTrue(waiting.waitForExistence(timeout: 3), "the hold-back line: \(app.debugDescription)")
    let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: waiting)
    wait(for: [gone], timeout: 20)

    let second = "and the next one"
    field.tap()
    field.typeText(second)
    XCTAssertTrue(app.buttons["Send"].isEnabled, "the next message can go now")
    app.buttons["Send"].tap()

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

  /// Stories 470, 472 and 474: the button beside the + opens the same new chat, and its mic has already been tapped.
  /// The simulator's first run asks for speech recognition; declining is story 474's copyable line, in the new chat's
  /// bar. Whichever way the recognizer goes, a tap was made for him: the mic is on its way, or it says why not.
  func testTheVoiceButtonOpensANewChatWithItsMicTapped() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_INBOX"] = "open"
    app.launch()
    let plus = app.buttons["inbox-add"]
    let voice = app.buttons["inbox-add-voice"]
    XCTAssertTrue(voice.waitForExistence(timeout: 20), app.debugDescription)
    XCTAssertLessThanOrEqual(voice.frame.maxX, plus.frame.minX, "the voice button comes before the +")
    XCTAssertLessThanOrEqual(plus.frame.minX - voice.frame.maxX, 12, "right beside it")
    XCTAssertGreaterThanOrEqual(voice.frame.width, 44)
    XCTAssertGreaterThanOrEqual(voice.frame.height, 44)
    voice.tap()
    XCTAssertTrue(app.navigationBars["New chat"].waitForExistence(timeout: 5), app.debugDescription)
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

    // Story 472: back stops whatever was going and leaves no thread.
    app.navigationBars["New chat"].buttons.firstMatch.tap()
    XCTAssertTrue(plus.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.descendants(matching: .any)["chat-pending-waiting"].exists, "no new thread waits to go")

    // Story 470: the + after it records nothing.
    plus.tap()
    XCTAssertTrue(field(app).waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertTrue(app.buttons["Speak a message"].waitForExistence(timeout: 5), "the + leaves the mic idle")
    XCTAssertFalse(app.buttons["Stop recording"].exists)
  }

  /// Recording, on its way there, or its copyable line saying why not.
  private func micAnswered(_ app: XCUIApplication) -> Bool {
    if app.buttons["Stop recording"].exists { return true }
    let why = NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "off for this app", "could not start")
    return app.staticTexts.matching(why).firstMatch.exists
  }

  /// Story 473 with a real call, against the fake bridge test-chat-ui.sh starts: the button stands down and the new
  /// chat records nothing, says why and has the keyboard up.
  func testALiveCallKeepsTheMicFromTheVoiceButton() throws {
    guard let bridge = ProcessInfo.processInfo.environment["GRABBER_FAKE_BRIDGE"], !bridge.isEmpty else {
      throw XCTSkip("needs the fake bridge: run scripts/native/test-chat-ui.sh")
    }
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_CALL"] = bridge
    app.launchEnvironment["GRABBER_CALL_AUDIO"] = "synthetic"
    app.launchEnvironment["GRABBER_CALL_SECONDS"] = "120"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()
    let done = app.buttons["Done"]
    XCTAssertTrue(done.waitForExistence(timeout: 20), app.debugDescription)
    Thread.sleep(forTimeInterval: 2)  // the hook places the call a second after the screen opens
    done.tap()
    let tile = app.buttons["home-inbox"]
    XCTAssertTrue(tile.waitForExistence(timeout: 10), app.debugDescription)
    tile.tap()
    let voice = app.buttons["inbox-add-voice"]
    XCTAssertTrue(voice.waitForExistence(timeout: 10), app.debugDescription)
    voice.tap()
    XCTAssertTrue(app.navigationBars["New chat"].waitForExistence(timeout: 5), app.debugDescription)
    let line = app.staticTexts["A call with Larry is using the microphone. End it to speak a message."]
    XCTAssertTrue(line.waitForExistence(timeout: 5), "the bar says why: \(app.debugDescription)")
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
