import XCTest

@testable import ContextCore

/// Igor, 2026-11-25: "Chats load slow." The Cockpit's delta and ETag wire (its story 346): a thread poll asks for what
/// changed since the newest message held, a 304 keeps what is held, and anything unexpected starts over from a full read.
final class ChatThreadPollTests: XCTestCase {
  private func row(_ id: String, _ text: String, receipt: String = "sent") -> String {
    #"{"id":"\#(id)","ts":"2026-11-25T10:00:00Z","who":"igor","text":"\#(text)","receipt":{"state":"\#(receipt)"}}"#
  }

  private func answer(_ rows: [String], full: Bool?, cursor: String) -> Data {
    let fullField = full.map { #""full":\#($0),"# } ?? ""
    return Data(#"{"ok":true,\#(fullField)"cursor":"\#(cursor)","messages":[\#(rows.joined(separator: ","))]}"#.utf8)
  }

  func testAFullAnswerReplacesWhatIsHeldAndKeepsTheCursorAndETag() throws {
    var poll = ChatThreadPoll()
    let outcome = poll.apply(
      status: 200, etag: #"W/"a""#, body: answer([row("m1", "one"), row("m2", "two")], full: true, cursor: "m2"))
    XCTAssertEqual(outcome, .whole(count: 2))
    XCTAssertEqual(poll.messages?.map(\.id), ["m1", "m2"])
    XCTAssertEqual(poll.cursor, "m2")
    XCTAssertEqual(poll.etag, #"W/"a""#)
  }

  func testADeltaAppendsNewRowsAndReplacesAChangedOneInPlace() throws {
    var poll = ChatThreadPoll()
    _ = poll.apply(
      status: 200, etag: #"W/"a""#, body: answer([row("m1", "one"), row("m2", "two")], full: true, cursor: "m2"))
    let outcome = poll.apply(
      status: 200, etag: #"W/"b""#,
      body: answer([row("m1", "one", receipt: "done"), row("m3", "three")], full: false, cursor: "m3"))
    XCTAssertEqual(outcome, .changed(new: 1, changed: 1))
    XCTAssertEqual(poll.messages?.map(\.id), ["m1", "m2", "m3"])
    XCTAssertEqual(poll.messages?.first?.receipt, .done)
    XCTAssertEqual(poll.cursor, "m3")
    XCTAssertEqual(poll.etag, #"W/"b""#)
  }

  func testA304KeepsEverythingHeld() throws {
    var poll = ChatThreadPoll()
    _ = poll.apply(status: 200, etag: #"W/"a""#, body: answer([row("m1", "one")], full: true, cursor: "m1"))
    XCTAssertEqual(poll.apply(status: 304, etag: #"W/"a""#, body: Data()), .unchanged)
    XCTAssertEqual(poll.messages?.map(\.id), ["m1"])
    XCTAssertEqual(poll.cursor, "m1")
  }

  func testFullTrueOnAPollReplacesEverything() throws {
    var poll = ChatThreadPoll()
    _ = poll.apply(
      status: 200, etag: nil, body: answer([row("m1", "one"), row("m2", "two")], full: true, cursor: "m2"))
    let outcome = poll.apply(status: 200, etag: nil, body: answer([row("m9", "moved")], full: true, cursor: "m9"))
    XCTAssertEqual(outcome, .whole(count: 1))
    XCTAssertEqual(poll.messages?.map(\.id), ["m9"])
  }

  func testAnAnswerWithNoFullFieldIsTheWholeThread() throws {
    var poll = ChatThreadPoll()
    _ = poll.apply(status: 200, etag: nil, body: answer([row("m1", "one")], full: true, cursor: "m1"))
    XCTAssertEqual(
      poll.apply(status: 200, etag: nil, body: answer([row("m5", "x")], full: nil, cursor: "m5")), .whole(count: 1))
    XCTAssertEqual(poll.messages?.map(\.id), ["m5"])
  }

  func testAFailedReadDropsTheCursorAndETagButKeepsTheRows() throws {
    var poll = ChatThreadPoll()
    _ = poll.apply(status: 200, etag: #"W/"a""#, body: answer([row("m1", "one")], full: true, cursor: "m1"))
    XCTAssertEqual(poll.apply(status: 502, etag: nil, body: Data("bad".utf8)), .failed("HTTP 502"))
    XCTAssertNil(poll.cursor)
    XCTAssertNil(poll.etag)
    XCTAssertEqual(poll.messages?.map(\.id), ["m1"])
    XCTAssertEqual(poll.apply(status: 200, etag: nil, body: Data("{}".utf8)), .failed("unreadable answer"))
    XCTAssertNil(poll.cursor)
  }

  func testADeviceCopyTheAppCannotReadIsNoCopy() throws {
    let saved = Data(#"{"rows":[{"id":"m1","json":"e30="}],"cursor":"m1","etag":"x"}"#.utf8)
    XCTAssertNil(ChatThreadPoll(saved: saved))
  }

  func testOpeningAsksForTheWholeThreadButAPollAsksForWhatChanged() throws {
    var poll = ChatThreadPoll()
    _ = poll.apply(status: 200, etag: #"W/"a""#, body: answer([row("m1", "one")], full: true, cursor: "m1"))
    let open = try poll.request("igor2-88g.1620", cockpit: "https://c.example", opening: true)
    XCTAssertEqual(open.url?.absoluteString, "https://c.example/chat/igor2-88g.1620")
    XCTAssertEqual(open.value(forHTTPHeaderField: "If-None-Match"), #"W/"a""#)
    let next = try poll.request("igor2-88g.1620", cockpit: "https://c.example", opening: false)
    XCTAssertEqual(next.url?.absoluteString, "https://c.example/chat/igor2-88g.1620?after=m1")
    XCTAssertEqual(next.value(forHTTPHeaderField: "If-None-Match"), #"W/"a""#)
  }

  func testAFreshPollAsksPlainly() throws {
    let request = try ChatThreadPoll().request("k", cockpit: "https://c.example", opening: false)
    XCTAssertEqual(request.url?.absoluteString, "https://c.example/chat/k")
    XCTAssertNil(request.value(forHTTPHeaderField: "If-None-Match"))
  }

  func testTheDeviceCopyRoundTripsAndShowsAtOnce() throws {
    var poll = ChatThreadPoll()
    _ = poll.apply(
      status: 200, etag: #"W/"a""#, body: answer([row("m1", "one"), row("m2", "two")], full: true, cursor: "m2"))
    let saved = try XCTUnwrap(poll.saved)
    let back = try XCTUnwrap(ChatThreadPoll(saved: saved))
    XCTAssertEqual(back.messages?.map(\.id), ["m1", "m2"])
    XCTAssertEqual(back.etag, #"W/"a""#)
    XCTAssertNil(ChatThreadPoll(saved: Data("junk".utf8)))
  }

  func testTheListAsksForItsSlimFormWithItsETag() throws {
    var list = ChatListPoll()
    XCTAssertEqual(
      try list.request(cockpit: "https://c.example").url?.absoluteString, "https://c.example/chat?fields=summary")
    list.answered(status: 200, etag: #"W/"l""#)
    XCTAssertEqual(try list.request(cockpit: "https://c.example").value(forHTTPHeaderField: "If-None-Match"), #"W/"l""#)
    list.answered(status: 500, etag: nil)
    XCTAssertNil(try list.request(cockpit: "https://c.example").value(forHTTPHeaderField: "If-None-Match"))
  }
}
