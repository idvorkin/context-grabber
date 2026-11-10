import XCTest

@testable import ContextCore

/// #809: the outbox's counts for the log (`chat` outbox_thread and outbox), which settle whether a sent message its
/// thread never returns stays pending on the phone.
final class ChatOutboxLookTests: XCTestCase {
  private let hour: Int64 = 3_600_000

  private func item(_ id: String, thread: String? = nil, landed: String? = nil, sentAt: Int64? = nil) -> InboxItem {
    var item = InboxItem(id: id, kind: .text, sharedAt: 1, text: "secret words", thread: thread)
    if let sentAt { item.delivery = .sent(at: sentAt, thread: landed) }
    return item
  }

  private func message(_ id: String) -> ChatMessage { ChatMessage(id: id, ts: "", who: "igor", text: "") }

  func testAThreadCountsItsItemsSentOnesAndTheSentOnesItDoesNotHold() {
    let now = 100 * hour
    let items = [
      item("waiting", thread: "k"),
      item("delivered", thread: "k", landed: "k", sentAt: now - hour),
      item("stuck-old", thread: "k", landed: "k", sentAt: now - 50 * hour),
      item("stuck-new", landed: "k", sentAt: now - 2 * hour),
      item("elsewhere", thread: "j", landed: "j", sentAt: now - 90 * hour),
      item("earlier-share", sentAt: now - 99 * hour),
    ]
    let look = ChatOutboxLook.thread("k", items: items, messages: [message("delivered")], now: now)
    XCTAssertEqual(
      look, .init(items: 4, sent: 3, pending: 1, sentPending: 2, unconfirmed: 2, oldestSentPendingHours: 50),
      "the two stuck ones are hours old: unconfirmed, so no bubbles")
    XCTAssertEqual(
      look.pending, ChatWire.pending(in: "k", items: items, messages: [message("delivered")], now: now).count)
  }

  // #809: the audit's scratch test, flipped. A sent message the thread doesn't return stopped being a bubble.
  func testAThirtyDayOldSentItemTheThreadDoesNotReturnIsNoBubble() {
    let item = item("m1", thread: "t1", landed: "t1", sentAt: 2)
    let other = ChatMessage(id: "someone-else", ts: "", who: "larry", text: "")
    let now = 2 + 30 * 24 * hour
    XCTAssertEqual(ChatWire.pending(in: "t1", items: [item], messages: [other], now: now), [])
    let look = ChatOutboxLook.thread("t1", items: [item], messages: [other], now: now)
    XCTAssertEqual(look.pending, 0)
    XCTAssertEqual(look.sentPending, 1, "still counted for the log")
    XCTAssertEqual(look.unconfirmed, 1)
  }

  func testASentMessageIsABubbleForFiveMinutesThenUnconfirmed() {
    let item = item("m1", thread: "t1", landed: "t1", sentAt: 10 * hour)
    let justUnder = 10 * hour + InboxItem.unconfirmedAfterMs - 1
    XCTAssertEqual(ChatWire.pending(in: "t1", items: [item], messages: [], now: justUnder).map(\.id), ["m1"])
    XCTAssertEqual(ChatOutboxLook.thread("t1", items: [item], messages: [], now: justUnder).unconfirmed, 0)
    let atFive = 10 * hour + InboxItem.unconfirmedAfterMs
    XCTAssertEqual(ChatWire.pending(in: "t1", items: [item], messages: [], now: atFive), [])
    XCTAssertEqual(
      ChatWire.pending(in: "t1", items: [item], messages: [], now: 0).map(\.id), ["m1"],
      "a clock set back makes it younger, never older")
  }

  func testWaitingAndRefusedMessagesStayBubblesHoweverOld() {
    var refused = item("r", thread: "t1")
    refused.delivery = .refused("too big")
    let items = [item("w", thread: "t1"), refused]
    XCTAssertEqual(
      ChatWire.pending(in: "t1", items: items, messages: [], now: 400 * 24 * hour).map(\.id).sorted(), ["r", "w"])
  }

  func testAThreadWithNothingStuckCarriesNoAge() {
    let items = [item("waiting", thread: "k"), item("delivered", landed: "k", sentAt: 5)]
    let look = ChatOutboxLook.thread("k", items: items, messages: [message("delivered")], now: 10 * hour)
    XCTAssertEqual(
      look, .init(items: 2, sent: 1, pending: 1, sentPending: 0, unconfirmed: 0, oldestSentPendingHours: nil))
    XCTAssertNil(look.logFields(thread: "k")["oldest_sent_pending_hours"])
    XCTAssertEqual(ChatOutboxLook.thread("k", items: [], messages: nil, now: 1), .init())
  }

  func testAThreadNotReadYetCountsEverySentItemAsPending() {
    let look = ChatOutboxLook.thread("k", items: [item("a", landed: "k", sentAt: 0)], messages: nil, now: 60_000)
    XCTAssertEqual(
      look, .init(items: 1, sent: 1, pending: 1, sentPending: 1, unconfirmed: 0, oldestSentPendingHours: 0))
  }

  func testAgesAreTenthsOfAnHourAndNeverNegative() {
    let items = [item("a", landed: "k", sentAt: 10 * hour)]
    XCTAssertEqual(
      ChatOutboxLook.thread("k", items: items, messages: nil, now: 10 * hour + 15 * 60_000).oldestSentPendingHours,
      0.3, "15 minutes, rounded")
    XCTAssertEqual(ChatOutboxLook.thread("k", items: items, messages: nil, now: 0).oldestSentPendingHours, 0)
  }

  func testAnOpenThreadLogsItsFirstReadAChangeAndOnceWhenASentItemTurnsUnconfirmed() {
    func look(_ sentPending: Int, unconfirmed: Int = 0) -> ChatOutboxLook.Thread {
      .init(
        items: sentPending, sent: sentPending, pending: sentPending - unconfirmed, sentPending: sentPending,
        unconfirmed: unconfirmed)
    }
    var log = ChatOutboxLook.ThreadLog()
    XCTAssertTrue(log.logs(look(0)), "the first read")
    XCTAssertFalse(log.logs(look(0)), "a poll with nothing new")
    XCTAssertTrue(log.logs(look(1)), "a send the thread does not hold yet")
    XCTAssertFalse(log.logs(look(1)))
    XCTAssertTrue(log.logs(look(1, unconfirmed: 1)), "still not held five minutes later: unconfirmed, said once")
    XCTAssertFalse(log.logs(look(1, unconfirmed: 1)))
    XCTAssertTrue(log.logs(look(0)), "the thread returned it")
    XCTAssertTrue(log.logs(look(1)))
    XCTAssertTrue(log.logs(look(1, unconfirmed: 1)), "each one turning is said")

    var old = ChatOutboxLook.ThreadLog()
    XCTAssertTrue(old.logs(look(2, unconfirmed: 2)), "already unconfirmed at the open: the first read says so")
    XCTAssertFalse(old.logs(look(2, unconfirmed: 2)), "and no second line for it")
  }

  func testTheWholeOutboxCountsSentItemsAndTellsEarlierSharesFromChats() {
    let now = 200 * hour
    let items = [
      item("waiting", thread: "k"), item("new-chat"),
      item("in-chat", landed: "k", sentAt: now - 30 * hour),
      item("in-chat-2", landed: "j", sentAt: now - 3 * hour),
      item("earlier-share", sentAt: now - 150 * hour),
    ]
    XCTAssertEqual(
      ChatOutboxLook.whole(items, now: now),
      .init(items: 5, sent: 3, sentInChats: 2, oldestSentHours: 150, oldestSentInChatsHours: 30))
    XCTAssertEqual(ChatOutboxLook.whole([], now: now), .init())
  }

  func testTheLogLinesCarryCountsAndNeverTheWords() throws {
    let now = 10 * hour
    let items = [item("a", thread: "k", landed: "k", sentAt: now - 4 * hour)]
    let thread = ChatOutboxLook.thread("k", items: items, messages: [], now: now).logFields(thread: "k")
    XCTAssertEqual(
      thread.keys.sorted(),
      ["action", "items", "oldest_sent_pending_hours", "pending", "sent", "sent_pending", "thread", "unconfirmed"])
    XCTAssertEqual(thread["action"] as? String, "outbox_thread")
    XCTAssertEqual(thread["thread"] as? String, "k")
    XCTAssertEqual(thread["sent_pending"] as? Int, 1)
    XCTAssertEqual(thread["unconfirmed"] as? Int, 1)
    XCTAssertEqual(thread["oldest_sent_pending_hours"] as? Double, 4)
    let whole = ChatOutboxLook.whole(items, now: now).logFields(why: "foreground")
    XCTAssertEqual(
      whole.keys.sorted(),
      ["action", "items", "oldest_sent_hours", "oldest_sent_in_chats_hours", "sent", "sent_in_chats", "why"])
    XCTAssertEqual(whole["action"] as? String, "outbox")
    XCTAssertEqual(whole["why"] as? String, "foreground")
    for fields in [thread, whole] {
      let line = String(decoding: SessionLogLine.encode(type: "chat", t: 1, fields: fields), as: UTF8.self)
      XCTAssertFalse(line.contains("secret"), line)
    }
  }
}
