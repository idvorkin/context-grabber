//  Stories 307–309 (#589), 311–314 (#599) and 506 on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh
//  starts it): only what the real list can show. A real swipe archives a thread and its Undo brings it back; Select's
//  ticks and Archive (N) archive two with one Undo; the thread's ⋯ menu archives and goes back, and a swipe under Done
//  unarchives; the + and the voice button float over the list with the pinned thread on top. Which row offers what,
//  Review, Cancel, the counts, refusals, the five seconds and an Undo racing its archive are `ChatArchiverTests`, on the
//  host (the views draw those rules and decide nothing). Each test leaves the thread live: the fake Cockpit outlives a
//  test.

import XCTest

final class ChatArchiveUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private let key = "igor2-88g.592"

  private func openList() throws -> XCUIApplication {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let app = SharedApp.open(
      ["GRABBER_CHAT_URL": cockpit, "GRABBER_INBOX": "open", "GRABBER_SILENT": "1"], route: "chat", for: self)
    let row = app.buttons["chat-thread-\(key)"]
    XCTAssertTrue(row.appears(within: 20), app.debugDescription)
    return app
  }

  private func doneFold(_ app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Done (")).firstMatch
  }

  /// With the only archived thread back, the fold is gone and the row is in the live list.
  private func assertBackInTheLiveList(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(doneFold(app).waitForNonExistence(timeout: 10), app.debugDescription, file: file, line: line)
    XCTAssertTrue(app.buttons["chat-thread-\(key)"].isHittable, "back in the live list", file: file, line: line)
  }

  /// The Done fold, or a row just opened under it, can be below the buttons' bar, where a tap lands on the bar: scrolled
  /// up clear of it, as he would. A swipe's Undo line pushes the whole list down for five seconds as well.
  private func scrollClearOfTheBar(_ row: XCUIElement, _ app: XCUIApplication) {
    let bar = app.otherElements["chat-new-bar"]
    let origin = app.coordinate(withNormalizedOffset: .zero)
    for _ in 0..<6 where row.frame.maxY > bar.frame.minY {
      origin.withOffset(CGVector(dx: 30, dy: 450))
        .press(
          forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 30, dy: 300)), withVelocity: .slow,
          thenHoldForDuration: 0.3)
    }
    XCTAssertLessThanOrEqual(row.frame.maxY, bar.frame.minY, "scrolled clear: \(app.debugDescription)")
  }

  /// Story 506 (#685): the + and the voice button float over the list, which runs to the foot of the screen, with no bar
  /// across it. The pinned thread (#598) is first, and its row says so to VoiceOver.
  func testTheNewChatButtonsFloatOverTheListAndThePinnedThreadLeadsIt() throws {
    let app = try openList()
    let bar = app.otherElements["chat-new-bar"]
    XCTAssertTrue(bar.appears(within: 5), app.debugDescription)
    XCTAssertLessThan(bar.frame.width, app.windows.firstMatch.frame.width / 2, "only the buttons, not a bar")
    let list = app.collectionViews.firstMatch
    XCTAssertGreaterThanOrEqual(list.frame.maxY, app.buttons["inbox-add"].frame.maxY, "the list runs beneath them")
    let pinned = app.buttons["chat-thread-igor2-88g.1268"]
    XCTAssertTrue(pinned.appears(within: 5), app.debugDescription)
    XCTAssertLessThan(pinned.frame.minY, app.buttons["chat-thread-\(key)"].frame.minY, "first in the list")
    XCTAssertTrue(pinned.label.contains("Pinned"), pinned.label)
    XCTAssertTrue(pinned.label.contains("Drop anything here"), pinned.label)
  }

  /// A real swipe and its Undo, then Select's real ticks and Archive (N) with one Undo for both.
  func testASwipeOrSelectArchivesAndUndoBringsItBack() throws {
    let app = try openList()
    app.buttons["chat-thread-\(key)"].swipeLeft()
    app.buttons["Archive"].tap()
    let undo = app.buttons["chat-archive-undo"]
    XCTAssertTrue(undo.appears(within: 5), app.debugDescription)
    undo.tap()
    assertBackInTheLiveList(app)

    let select = app.buttons["chat-select"]
    select.tap()
    let (one, two) = (app.buttons["chat-tick-\(key)"], app.buttons["chat-tick-igor2-88g.593"])
    XCTAssertTrue(one.appears(within: 5), app.debugDescription)
    one.tap()
    two.tap()
    let archive = app.buttons["chat-archive-selected"]
    XCTAssertEqual(archive.label, "Archive (2)", "both taps ticked")
    XCTAssertFalse(archive.frame.intersects(app.otherElements["chat-new-bar"].frame), "clear of the floating buttons")
    archive.tap()
    XCTAssertTrue(app.staticTexts["Archived 2 chats"].appears(within: 5), app.debugDescription)
    undo.tap()
    assertBackInTheLiveList(app)
  }

  /// The thread's ⋯ menu archives it and goes back to the list; under Done, a real swipe brings it back.
  func testTheThreadsMenuArchivesAndASwipeUnderDoneUnarchives() throws {
    let app = try openList()
    app.buttons["chat-thread-\(key)"].tap()
    let more = app.buttons["chat-thread-more"]
    XCTAssertTrue(more.appears(within: 10), app.debugDescription)
    more.tap()
    app.buttons["Archive chat"].tap()
    let done = doneFold(app)
    XCTAssertTrue(done.appears(within: 5), "back on the list, under Done: \(app.debugDescription)")
    scrollClearOfTheBar(done, app)
    done.tap()
    let row = app.buttons["chat-thread-\(key)"]
    XCTAssertTrue(row.appears(within: 5), app.debugDescription)
    scrollClearOfTheBar(row, app)
    row.swipeLeft()
    app.buttons["Unarchive"].tap()
    assertBackInTheLiveList(app)
  }
}
