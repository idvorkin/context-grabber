// Searching the chat list (stories 1616-1618, #1443): which threads the phone matches itself, the Cockpit's /chat?q
// search, how the two merge, and what a failure says.

import XCTest

@testable import ContextCore

final class ChatThreadSearchTests: XCTestCase {
  private func thread(
    _ key: String, _ title: String, last: String = "", done: Bool = false, archived: Bool = false
  ) -> ChatSummary {
    ChatSummary(
      key: key, title: title, count: 1, lastTs: "2026-11-24T10:00:00-08:00", lastWho: "igor", lastText: last,
      done: done || archived, archived: archived)
  }

  // Story 1616: every word, any order, case ignored, in the title or the newest message.
  func testLocalMatchNeedsEveryWordInTitleOrNewestMessage() {
    let threads = [
      thread("a", "Ramen in Ashland"),
      thread("b", "Dinner", last: "ramen tonight?"),
      thread("c", "Ashland trip"),
    ]
    XCTAssertEqual(ChatThreadSearch.local(threads, terms: ["ashland", "ramen"]), ["a"])
    XCTAssertEqual(ChatThreadSearch.local(threads, terms: ["RAMEN"].map { $0.lowercased() }), ["a", "b"])
    XCTAssertEqual(ChatThreadSearch.local(threads, terms: []), [])
  }

  // Story 1617: the Cockpit's hits that are chats join the phone's; live ones first, then done/archived, list order kept.
  func testMergeKeepsListOrderLiveFirstAndOnlyChats() {
    let threads = [
      thread("old", "Passport renewal", done: true),
      thread("live", "Trip"),
      thread("arch", "Passport photo", archived: true),
      thread("other", "Groceries"),
    ]
    let rows = ChatThreadSearch.rows(threads, local: ["old"], cockpit: ["live", "arch", "not-a-chat"])
    XCTAssertEqual(rows.map(\.key), ["live", "old", "arch"])
  }

  func testRequestIsTheCockpitChatSearchEscaped() throws {
    let r = try XCTUnwrap(ChatThreadSearch.request(cockpit: "https://c.example", q: "  a+b & c#  "))
    XCTAssertEqual(r.httpMethod ?? "GET", "GET")
    XCTAssertEqual(r.url?.absoluteString, "https://c.example/chat?q=a%2Bb%20%26%20c%23")
    XCTAssertNil(try ChatThreadSearch.request(cockpit: "https://c.example", q: "   "))
    XCTAssertThrowsError(try ChatThreadSearch.request(cockpit: "nowhere", q: "x"))
  }

  func testOutcomeReadsTheKeysAndNamesFailures() {
    let body = Data(#"{"ok":true,"count":2,"threads":[{"key":"k1","root":{"title":"T"}},{"key":"k2"}]}"#.utf8)
    XCTAssertEqual(ChatThreadSearch.outcome(status: 200, body: body), .found(["k1", "k2"]))
    let down = Data(#"{"ok":false,"error":"bd: database is locked"}"#.utf8)
    XCTAssertEqual(
      ChatThreadSearch.outcome(status: 502, body: down), .failed("bd: database is locked (HTTP 502)", status: 502))
    XCTAssertEqual(
      ChatThreadSearch.outcome(status: nil, body: nil, error: "timed out"), .failed("timed out", status: nil))
    XCTAssertEqual(
      ChatThreadSearch.outcome(status: 200, body: Data("nope".utf8)),
      .failed("an answer that is not a search: unreadable", status: 200))
  }

  // Story 1618: what the screen says.
  func testLinesAndLogNeverCarryTheWords() {
    XCTAssertEqual(ChatThreadSearch.noMatch, "No chats match.")
    XCTAssertEqual(
      ChatThreadSearch.problem("bd: database is locked (HTTP 502)"),
      "Could not search the Cockpit for chats, so these are only the phone's own matches: bd: database is locked (HTTP 502)"
    )
    let fields = ChatThreadSearch.logFields(q: "ramen ashland")
    XCTAssertEqual(fields["terms"] as? Int, 2)
    XCTAssertEqual(fields["q_chars"] as? Int, 13)
    XCTAssertNil(fields["q"])
  }
}
