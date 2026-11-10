import XCTest

@testable import ContextCore

/// A thread's screen and its bar (#536, #449; stories 262–264, 274, 491), the decisions its view draws: where a Send
/// goes, when Send is enabled, the line under a new chat's field, the title, what waits on the phone, and the new chat
/// becoming its thread. The bar emptying after a send is `InboxDraftTests` (only a successful save clears the draft).
final class ChatNewThreadScreenTests: XCTestCase {
  private func item(
    _ id: String, thread: String? = nil, landed: String? = nil, refused: String? = nil, at: Int64 = 1,
    text: String = "first line\nmore"
  ) -> InboxItem {
    var item = InboxItem(id: id, kind: .text, sharedAt: at, text: text, thread: thread)
    if let refused { item.delivery = .refused(refused) }
    if let landed { item.delivery = .sent(at: at + 1, thread: landed) }
    return item
  }

  private func summary(_ key: String, title: String) -> ChatSummary {
    ChatSummary(key: key, title: title, lastTs: "", lastWho: "larry", lastText: "")
  }

  private func message(_ id: String) -> ChatMessage {
    ChatMessage(id: id, ts: "", who: "igor", text: "")
  }

  // MARK: A send

  func testASendInAThreadGoesThereAndStartsNothing() {
    var screen = ChatNewThread()
    XCTAssertEqual(screen.send(at: .thread("k1")), .thread("k1"))
    XCTAssertNil(screen.sent)
  }

  func testTheFirstSendOfANewChatStartsItAndTheScreenFollowsIt() {
    var screen = ChatNewThread()
    XCTAssertEqual(screen.send(at: .new, id: "a"), .start(id: "a"))
    XCTAssertEqual(screen.sent, "a")
    let target = ChatNewThread.target(fixedKey: nil, landed: screen.landed, first: item("a"))
    XCTAssertEqual(screen.send(at: target), .hold, "the next waits for the first to land")
    XCTAssertEqual(screen.sent, "a")
  }

  func testAfterARefusalTheNextSendStartsTheChatAgainUnderANewId() {
    var screen = ChatNewThread()
    _ = screen.send(at: .new, id: "a")
    let target = ChatNewThread.target(fixedKey: nil, landed: nil, first: item("a", refused: "too big"))
    guard case .start(let id) = screen.send(at: target) else { return XCTFail("starts again") }
    XCTAssertNotEqual(id, "a")
    XCTAssertEqual(screen.sent, id)
  }

  func testOnceLandedTheNextMessageGoesIntoThatThread() {
    var screen = ChatNewThread()
    _ = screen.send(at: .new, id: "a")
    XCTAssertEqual(screen.firstMoved(to: nil), nil, "still on the phone")
    XCTAssertEqual(screen.firstMoved(to: "k1"), "k1", "open it, once")
    XCTAssertNil(screen.firstMoved(to: "k1"))
    XCTAssertNil(screen.firstMoved(to: "k2"), "the screen keeps its thread")
    XCTAssertEqual(screen.key(fixedKey: nil), "k1")
    let target = ChatNewThread.target(fixedKey: nil, landed: screen.landed, first: nil)
    XCTAssertEqual(screen.send(at: target), .thread("k1"))
  }

  // MARK: The bar

  func testSendNeedsSomethingAndNeverGoesWhileTheFirstIsOnItsWay() {
    XCTAssertFalse(ChatNewThread.canSend(.new, draftReady: false), "an empty bar: nothing to send yet")
    XCTAssertTrue(ChatNewThread.canSend(.new, draftReady: true))
    XCTAssertFalse(ChatNewThread.canSend(.waiting, draftReady: true))
    XCTAssertTrue(ChatNewThread.canSend(.thread("k"), draftReady: true))
    XCTAssertTrue(ChatNewThread.canSend(.refused(reason: "x"), draftReady: true))
    var empty = InboxDraft()
    XCTAssertFalse(ChatNewThread.canSend(.thread("k"), draftReady: empty.canAdd), "after a send, nothing twice")
    empty.text = "  \n"
    XCTAssertFalse(empty.canAdd, "blank words are nothing")
  }

  func testTheBarSaysWhyTheNextMessageWaitsAndWhatARefusalMeans() {
    XCTAssertEqual(
      ChatNewThread.barLine(.waiting, first: nil), "The next message goes once your first one reaches Larry.")
    XCTAssertEqual(
      ChatNewThread.barLine(.refused(reason: "x"), first: item("a", refused: "x")),
      ChatSend.afterRefusal(of: item("a", refused: "x")))
    XCTAssertNil(ChatNewThread.barLine(.new, first: nil))
    XCTAssertNil(ChatNewThread.barLine(.thread("k"), first: nil))
  }

  func testANewChatOpensWithTheKeyboardUpUnlessItIsRecording() {
    XCTAssertTrue(ChatNewThread.focusesOnOpen(.new, recording: false))
    XCTAssertFalse(ChatNewThread.focusesOnOpen(.new, recording: true), "the voice button's chat is talking")
    XCTAssertFalse(ChatNewThread.focusesOnOpen(.thread("k"), recording: false), "a thread opens on its messages")
    XCTAssertTrue(ChatNewThread.takesVoiceOnOpen(.new))
    XCTAssertFalse(ChatNewThread.takesVoiceOnOpen(.waiting))
    XCTAssertFalse(ChatNewThread.takesVoiceOnOpen(.thread("k")))
  }

  // MARK: The screen

  func testTheTitleIsTheFirstLineThenTheListsOnceLanded() {
    var screen = ChatNewThread()
    XCTAssertEqual(screen.title(fixedKey: nil, fixedTitle: "New chat", threads: [], first: nil), "New chat")
    _ = screen.send(at: .new, id: "a")
    let first = item("a", text: "Plan the trip\nwith details")
    XCTAssertEqual(screen.title(fixedKey: nil, fixedTitle: "New chat", threads: [], first: first), "Plan the trip")
    _ = screen.firstMoved(to: "k1")
    XCTAssertEqual(
      screen.title(fixedKey: nil, fixedTitle: "New chat", threads: [summary("k1", title: "Trip")], first: nil), "Trip")
    XCTAssertEqual(
      screen.title(fixedKey: "k9", fixedTitle: "Fixed", threads: [summary("k9", title: "Other")], first: first),
      "Fixed", "a thread opened from the list keeps its title")
  }

  func testBackWithNothingSentLeavesNothingWaiting() {
    let screen = ChatNewThread()
    XCTAssertEqual(screen.pending(fixedKey: nil, items: [item("other")], messages: [:]), [])
    XCTAssertNil(screen.first(in: [item("other")]))
  }

  func testANewChatShowsItsFirstMessageWhileItIsOnThePhone() {
    var screen = ChatNewThread()
    _ = screen.send(at: .new, id: "a")
    let items = [item("other"), item("a")]
    XCTAssertEqual(screen.pending(fixedKey: nil, items: items, messages: [:]).map(\.id), ["a"])
    XCTAssertEqual(screen.pending(fixedKey: nil, items: [item("other")], messages: [:]), [], "deleted")
  }

  func testAThreadShowsWhatThePhoneHasNotDeliveredOldestFirst() {
    let items = [
      item("late", thread: "k", at: 5), item("early", thread: "k", at: 2), item("there", thread: "k", at: 1),
      item("sent", landed: "k", at: 3), item("elsewhere", thread: "j", at: 4),
    ]
    let held = ChatNewThread().pending(fixedKey: "k", items: items, messages: ["k": [message("there")]], now: 10)
    XCTAssertEqual(held.map(\.id), ["early", "sent", "late"], "the Cockpit's copy replaces the phone's")
    XCTAssertEqual(
      ChatWire.pending(in: "k", items: items, messages: nil, now: 10).map(\.id), ["there", "early", "sent", "late"])
  }
}
