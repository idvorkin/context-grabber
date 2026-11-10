import XCTest

@testable import ContextCore

/// A new chat from the + (#536, stories 262 and 263): each first-message attempt has its own id, and the bar's Send
/// is enabled or held back by what became of the last one.
final class ChatNewThreadTests: XCTestCase {
  private func item(_ id: String, refused: String? = nil, landed: String? = nil) -> InboxItem {
    var item = InboxItem(id: id, kind: .text, sharedAt: 1, text: "first line\nmore")
    if let refused { item.delivery = .refused(refused) }
    if let landed { item.delivery = .sent(at: 2, thread: landed) }
    return item
  }

  func testNothingSentYetStartsTheChat() {
    let state = ChatNewThread()
    XCTAssertEqual(ChatNewThread.target(fixedKey: nil, landed: state.landed, first: nil), .new)
  }

  func testWhileTheFirstIsOnItsWayTheNextWaits() {
    var state = ChatNewThread()
    let id = state.attempt(at: .new, id: "a")
    XCTAssertEqual(id, "a")
    XCTAssertEqual(state.sent, "a")
    let target = ChatNewThread.target(fixedKey: nil, landed: state.landed, first: item("a"))
    XCTAssertEqual(target, .waiting)
    XCTAssertFalse(target.startsChat)
    XCTAssertNil(state.attempt(at: target), "a waiting Send makes no message")
    XCTAssertEqual(state.sent, "a")
  }

  func testDeletedMidFlightThenSentAgainIsANewMessage() {
    var state = ChatNewThread()
    _ = state.attempt(at: .new, id: "a")
    // Swiped away before it left the phone: the phone has no copy, so the Send starts the chat again.
    let target = ChatNewThread.target(fixedKey: nil, landed: state.landed, first: nil)
    XCTAssertEqual(target, .new)
    let again = state.attempt(at: target)
    XCTAssertNotNil(again)
    XCTAssertNotEqual(again, "a", "never the deleted message's id, which the Cockpit would take as a duplicate")
    XCTAssertEqual(state.sent, again, "the screen follows the newest")
  }

  func testARefusedFirstMessageReenablesSendWithANewId() {
    var state = ChatNewThread()
    _ = state.attempt(at: .new, id: "a")
    let target = ChatNewThread.target(fixedKey: nil, landed: state.landed, first: item("a", refused: "too big"))
    XCTAssertEqual(target, .refused(reason: "too big"))
    XCTAssertTrue(target.startsChat, "Send is enabled")
    let again = state.attempt(at: target)
    XCTAssertNotNil(again)
    XCTAssertNotEqual(again, "a")
  }

  func testLandedIsTheThreadFromThenOn() {
    var state = ChatNewThread()
    _ = state.attempt(at: .new, id: "a")
    XCTAssertEqual(
      ChatNewThread.target(fixedKey: nil, landed: nil, first: item("a", landed: "k1")), .thread("k1"),
      "landed before the screen took note")
    state.land(in: "k1")
    state.land(in: "k2")
    XCTAssertEqual(state.landed, "k1", "kept once known")
    // The phone's copy goes once the thread lists it; the screen stays on its thread.
    let target = ChatNewThread.target(fixedKey: nil, landed: state.landed, first: nil)
    XCTAssertEqual(target, .thread("k1"))
    XCTAssertNil(state.attempt(at: target), "a Send in a thread makes no first message")
  }

  func testAnOpenThreadIsAlwaysItsThread() {
    XCTAssertEqual(ChatNewThread.target(fixedKey: "k9", landed: nil, first: nil), .thread("k9"))
  }
}
