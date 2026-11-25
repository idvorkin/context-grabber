//  Stories 307–309 (#589), 311–314 (#599), 823–824 (bead context-grabber-szom), 834–835 (bead
//  context-grabber-qp3m), 1138 (#1258) and 506 on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh
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
      ["GRABBER_CHAT_URL": cockpit, "GRABBER_INBOX": "open", "GRABBER_SILENT": "1"], for: self
    ) { app in
      // Back out of a thread to the list, as the launch hook lands.
      for _ in 0..<3 where !app.buttons["inbox-add"].exists {
        app.navigationBars.buttons.element(boundBy: 0).tap()
      }
    }
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

  /// The Done fold sits under every live row, and since the Inbox's All / New row (bead context-grabber-qp3m) that is
  /// below the screen, where the list hasn't built it yet: scrolled down to, as he would (bead context-grabber-zlfl).
  private func scrollDownTo(_ row: XCUIElement, _ app: XCUIApplication) {
    let origin = app.coordinate(withNormalizedOffset: .zero)
    for _ in 0..<6 where !row.exists {
      origin.withOffset(CGVector(dx: 30, dy: 600))
        .press(
          forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 30, dy: 300)), withVelocity: .slow,
          thenHoldForDuration: 0.3)
    }
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
    app.buttons["Archive"].tapWhenSettled()
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
    // #686: the ⋯ menu's rows exist before they stop moving; a tap then misses and leaves the menu open.
    app.buttons["Archive chat"].tapWhenSettled()
    let done = doneFold(app)
    XCTAssertTrue(app.buttons["inbox-add"].appears(within: 5), "back on the list: \(app.debugDescription)")
    scrollDownTo(done, app)
    XCTAssertTrue(done.appears(within: 5), "back on the list, under Done: \(app.debugDescription)")
    scrollClearOfTheBar(done, app)
    done.tap()
    let row = app.buttons["chat-thread-\(key)"]
    scrollDownTo(row, app)
    XCTAssertTrue(row.appears(within: 5), app.debugDescription)
    scrollClearOfTheBar(row, app)
    row.swipeLeft()
    app.buttons["Unarchive"].tapWhenSettled()
    assertBackInTheLiveList(app)
  }

  /// Stories 823 and 824 (bead context-grabber-szom): Review opens on *Recommendations*, with only what looks done shown;
  /// *All* shows the rest, and a tick made there survives the switch back and goes with *Archive (N)*.
  func testReviewShowsOnlyRecommendationsAndTicksSurviveTheSwitch() throws {
    let app = try openList()
    let review = app.buttons["chat-review-done"]
    XCTAssertTrue(review.appears(within: 10), app.debugDescription)
    review.tap()
    let filter = app.segmentedControls["chat-select-filter"]
    XCTAssertTrue(filter.appears(within: 5), app.debugDescription)
    XCTAssertTrue(filter.buttons["Recommendations"].isSelected, "Review opens on Recommendations")
    let (proposed, other) = (app.buttons["chat-tick-igor2-88g.593"], app.buttons["chat-tick-\(key)"])
    XCTAssertTrue(proposed.appears(within: 5), app.debugDescription)
    XCTAssertEqual(proposed.value as? String, "ticked")
    XCTAssertFalse(other.exists, "a chat that doesn't look done isn't shown")
    filter.buttons["All"].tap()
    XCTAssertTrue(other.appears(within: 5), app.debugDescription)
    other.tap()
    filter.buttons["Recommendations"].tap()
    XCTAssertTrue(other.waitForNonExistence(timeout: 5), app.debugDescription)
    let archive = app.buttons["chat-archive-selected"]
    XCTAssertEqual(archive.label, "Archive (2)", "the tick under All still counts")
    archive.tap()
    XCTAssertTrue(app.staticTexts["Archived 2 chats"].appears(within: 5), app.debugDescription)
    app.buttons["chat-archive-undo"].tap()
    assertBackInTheLiveList(app)
  }

  /// Story 1138 (#1258): while ticking, a hold's *Open chat* and the row's arrow each open the chat, ticking nothing,
  /// and Back returns to the same side of the switch with the same ticks.
  func testAChatOpenedWhileTickingComesBackToTheSameTicks() throws {
    let app = try openList()
    let review = app.buttons["chat-review-done"]
    XCTAssertTrue(review.appears(within: 10), app.debugDescription)
    review.tap()
    let filter = app.segmentedControls["chat-select-filter"]
    XCTAssertTrue(filter.appears(within: 5), app.debugDescription)
    filter.buttons["All"].tap()
    let (proposed, other) = (app.buttons["chat-tick-igor2-88g.593"], app.buttons["chat-tick-\(key)"])
    XCTAssertTrue(other.appears(within: 5), app.debugDescription)
    let archive = app.buttons["chat-archive-selected"]
    XCTAssertEqual(archive.label, "Archive (1)", "Review ticked the proposal")
    let more = app.buttons["chat-thread-more"]
    func back() {
      app.navigationBars.buttons.element(boundBy: 0).tap()
      XCTAssertTrue(filter.appears(within: 5), "back on the ticking list: \(app.debugDescription)")
    }

    other.press(forDuration: 1.2)
    // The context menu's item, not a row's arrow, which VoiceOver also reads as Open chat.
    let open = app.buttons.matching(
      NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH %@)", "Open chat", "chat-tick-open-")
    ).firstMatch
    XCTAssertTrue(open.appears(within: 5), "the hold offers Open chat: \(app.debugDescription)")
    open.tap()
    XCTAssertTrue(more.appears(within: 10), "the chat opened: \(app.debugDescription)")
    back()
    XCTAssertTrue(filter.buttons["All"].isSelected, "the same side of the switch")
    XCTAssertEqual(other.value as? String, "not ticked", "opening ticked nothing")
    XCTAssertEqual(proposed.value as? String, "ticked")
    XCTAssertEqual(archive.label, "Archive (1)")

    app.buttons["chat-tick-open-igor2-88g.593"].tap()
    XCTAssertTrue(more.appears(within: 10), "the arrow opened the chat: \(app.debugDescription)")
    back()
    XCTAssertEqual(proposed.value as? String, "ticked", "opening unticked nothing")
    XCTAssertEqual(archive.label, "Archive (1)")
    app.buttons["chat-select"].tap()
    XCTAssertTrue(app.buttons["chat-thread-\(key)"].appears(within: 5), "Cancel: \(app.debugDescription)")
  }

  /// Stories 834 and 835 (bead context-grabber-qp3m): *New* hides the chats with nothing unread (the pinned thread here
  /// has no message, so never a reply), *All* brings them back, and *New* survives a relaunch. Left on *All*.
  func testNewHidesWhatIsReadAndIsRememberedAcrossALaunch() throws {
    let app = try openList()
    let filter = app.segmentedControls["chat-inbox-filter"]
    XCTAssertTrue(filter.appears(within: 5), app.debugDescription)
    XCTAssertTrue(filter.buttons["All"].isSelected, "the list as it always was")
    let pinned = app.buttons["chat-thread-igor2-88g.1268"]
    XCTAssertTrue(pinned.appears(within: 5), app.debugDescription)
    addTeardownBlock { if filter.buttons["All"].exists { filter.buttons["All"].tap() } }
    filter.buttons["New"].tap()
    XCTAssertTrue(pinned.waitForNonExistence(timeout: 5), "nothing unread on the pinned thread")
    app.terminate()
    app.launch()
    XCTAssertTrue(filter.appears(within: 20), app.debugDescription)
    XCTAssertTrue(filter.buttons["New"].isSelected, "remembered across the launch")
    XCTAssertFalse(pinned.exists, app.debugDescription)
    filter.buttons["All"].tap()
    XCTAssertTrue(pinned.appears(within: 5), app.debugDescription)
  }

  /// Story 834: a chat opened from *New* is read, stays open while he reads it, and has left *New* when he comes back.
  func testAChatOpenedFromNewStaysOpenAndHasLeftNewOnceBack() throws {
    let app = try openList()
    let filter = app.segmentedControls["chat-inbox-filter"]
    XCTAssertTrue(filter.appears(within: 5), app.debugDescription)
    addTeardownBlock { if filter.buttons["All"].exists { filter.buttons["All"].tap() } }
    filter.buttons["New"].tap()
    let unread = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", "chat-thread-", "chat-thread-more")
    ).firstMatch
    XCTAssertTrue(unread.appears(within: 5), "a chat with an unread reply: \(app.debugDescription)")
    let row = app.buttons[unread.identifier]
    row.tap()
    let more = app.buttons["chat-thread-more"]
    XCTAssertTrue(more.appears(within: 10), app.debugDescription)
    Thread.sleep(forTimeInterval: 3)
    XCTAssertTrue(more.exists, "read, and still open: \(app.debugDescription)")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(filter.appears(within: 5), app.debugDescription)
    XCTAssertTrue(row.waitForNonExistence(timeout: 5), "read, so out of New: \(app.debugDescription)")
  }
}
