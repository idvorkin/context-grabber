//  Stories 512-515 (#632) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh starts it): a skill's
//  thread pinned under Larry's, its replies under its name, a failure as a copyable error that leaves Igor's message
//  without 🏆, and the list naming the skill. That a pinned row can't be archived is ChatArchiverTests' (host). The fake
//  Cockpit outlives a test: the empty thread is looked at first, by name, before the next test writes to it.

import XCTest

final class ChatSkillThreadUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private let skill = "igor2-88g.632"

  private func openList() throws -> XCUIApplication {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    try addSkillThread(on: cockpit)
    // Story 672: one app for the class; a later test backs out of a thread to the list, as the launch hook lands.
    let app = SharedApp.open(
      ["GRABBER_CHAT_URL": cockpit, "GRABBER_INBOX": "open", "GRABBER_SILENT": "1"], for: self
    ) { app in
      for _ in 0..<3 where !app.buttons["inbox-add"].exists {
        app.navigationBars.buttons.element(boundBy: 0).tap()
      }
    }
    XCTAssertTrue(app.buttons["chat-thread-\(skill)"].appears(within: 20), app.debugDescription)
    return app
  }

  /// The fake Cockpit has no skill thread until asked, as an older Cockpit has none.
  private func addSkillThread(on cockpit: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: cockpit + "/fake/skill-thread")))
    request.httpMethod = "POST"
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }

  private func send(_ text: String, _ app: XCUIApplication) {
    let field = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Message idvorkin")).firstMatch
    XCTAssertTrue(field.appears(within: 10), "the bar names the skill: \(app.debugDescription)")
    field.tap()
    field.typeText(text)
    app.buttons["Send"].tap()  // by label: the thread's identifier covers its children
  }

  private func any(_ app: XCUIApplication, labelContains text: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
  }

  func testASkillsThreadIsPinnedUnderLarrysAboveTheRest() throws {
    let app = try openList()
    let thread = app.buttons["chat-thread-\(skill)"]
    let larrys = app.buttons["chat-thread-igor2-88g.1268"]
    let other = app.buttons["chat-thread-igor2-88g.592"]
    XCTAssertTrue(larrys.appears(within: 5), app.debugDescription)
    XCTAssertTrue(other.appears(within: 5), app.debugDescription)
    XCTAssertLessThan(larrys.frame.minY, thread.frame.minY, "under Larry's")
    XCTAssertLessThan(thread.frame.minY, other.frame.minY, "above the rest")
    XCTAssertTrue(thread.label.contains("Pinned"), thread.label)
    XCTAssertTrue(thread.label.contains("Ask idvorkin"), thread.label)
    // A pinned row has no swipe, no tick and no menu to archive it from: ChatArchiverTests
    // (`testASwipeArchivesALiveThreadAndBringsBackAnArchivedOne`, `testThePinnedThreadHasNoTickAndSelectNeedsAnotherThread`,
    // `testTheMenuArchivesOrUnarchivesAndThePinnedThreadHasNone`). Here it is the skill's row that comes pinned.
  }

  func testTheReplyNamesTheSkillAFailureIsAnErrorAndTheListSaysWho() throws {
    let app = try openList()
    app.buttons["chat-thread-\(skill)"].tap()

    send("please fail", app)
    XCTAssertTrue(any(app, labelContains: "could not answer").appears(within: 15), app.debugDescription)
    XCTAssertTrue(app.buttons["copy-error"].appears(within: 2), "copyable: \(app.debugDescription)")
    let mine = any(app, labelContains: "please fail")
    XCTAssertTrue(mine.appears(within: 5), app.debugDescription)
    XCTAssertFalse(mine.label.contains("🏆"), "a failure is not an answer: \(mine.label)")
    XCTAssertTrue(mine.label.contains("👀"), mine.label)

    send("hello there", app)
    let reply = any(app, labelContains: "idvorkin heard")
    XCTAssertTrue(reply.appears(within: 15), app.debugDescription)
    XCTAssertTrue(reply.label.contains("idvorkin"), reply.label)
    let answered = NSPredicate(format: "label CONTAINS %@", "🏆")
    wait(for: [expectation(for: answered, evaluatedWith: mine)], timeout: 10)

    app.navigationBars.buttons.element(boundBy: 0).tap()
    let row = app.buttons["chat-thread-\(skill)"]
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
    let named = NSPredicate(format: "label CONTAINS %@", "idvorkin: idvorkin heard")
    wait(for: [expectation(for: named, evaluatedWith: row)], timeout: 10)
  }
}
