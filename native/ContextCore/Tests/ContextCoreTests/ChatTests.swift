import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Chat with Larry (spec 2026-10-25-native-chat-design.md): what goes out, what comes back, who gets notified.
final class ChatTests: XCTestCase {
  private var dir: URL!
  private var store: InboxStore { InboxStore(directory: dir) }
  private let cockpit = "https://c-5004.squeaker-teeth.ts.net"

  override func setUp() {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("chat-\(UUID().uuidString)")
  }

  override func tearDown() { try? FileManager.default.removeItem(at: dir) }

  // MARK: What a message says, and a new thread's title

  func testALinkIsItsAddressThenTheNoteTextThenNoteAnImageItsNote() {
    let link = InboxItem(id: "l", kind: .link, sharedAt: 0, url: "https://idvork.in/eulogy", note: "for Larry")
    XCTAssertEqual(ChatSend.text(for: link), "https://idvork.in/eulogy\n\nfor Larry")
    XCTAssertEqual(ChatSend.text(for: InboxItem(id: "t", kind: .text, sharedAt: 0, text: " a thought ")), "a thought")
    XCTAssertEqual(ChatSend.text(for: InboxItem(id: "i", kind: .image, sharedAt: 0, note: "this one")), "this one")
    XCTAssertEqual(ChatSend.text(for: InboxItem(id: "i", kind: .image, sharedAt: 0)), "")
  }

  func testTheTitleIsTheNoteThenTheTextThenTheSiteThenAPhotoWithItsDate() {
    let pacific = TimeZone(identifier: "America/Los_Angeles")!
    let noted = InboxItem(id: "a", kind: .link, sharedAt: 0, url: "https://idvork.in/x", note: "\n read this \nlater")
    XCTAssertEqual(ChatSend.title(for: noted), "read this")
    XCTAssertEqual(
      ChatSend.title(for: InboxItem(id: "b", kind: .text, sharedAt: 0, text: "First line\nsecond")), "First line")
    XCTAssertEqual(
      ChatSend.title(for: InboxItem(id: "c", kind: .link, sharedAt: 0, url: "https://idvork.in/x")), "idvork.in")
    // 2026-10-25 09:00 Pacific.
    let photo = InboxItem(id: "d", kind: .image, sharedAt: 1_792_944_000_000)
    XCTAssertEqual(ChatSend.title(for: photo, timeZone: pacific), "Photo, Oct 25")
    let long = InboxItem(id: "e", kind: .text, sharedAt: 0, text: String(repeating: "word ", count: 40))
    let title = ChatSend.title(for: long)
    XCTAssertEqual(title.count, ChatSend.maxTitle)
    XCTAssertTrue(title.hasSuffix("…"))
  }

  // MARK: The requests

  func testAShareStartsANewThreadWithItsIdTitleAndTheAppAsSource() throws {
    let item = InboxItem(
      id: "0f6c1a2e-1111-4a8e-9c1d-aa00bb11cc22", kind: .link, sharedAt: 0, url: "https://example.com/a",
      note: "read on the plane")
    let request = try ChatSend.messageRequest(item, attachment: nil, cockpit: cockpit)
    XCTAssertEqual(request.url?.absoluteString, "\(cockpit)/chat")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), cockpit)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    let body = try json(request.httpBody)
    XCTAssertEqual(body["id"] as? String, item.id)
    XCTAssertEqual(body["title"] as? String, "read on the plane")
    XCTAssertEqual(body["text"] as? String, "https://example.com/a\n\nread on the plane")
    XCTAssertEqual(body["source"] as? String, "app")
    XCTAssertNil(body["attachments"])
    // The Cockpit's id shape.
    XCTAssertNotNil(item.id.range(of: "^[A-Za-z0-9_-]{8,64}$", options: .regularExpression))
  }

  func testAMessageOnAThreadGoesToThatThreadsPathWithNoTitle() throws {
    let item = InboxItem(
      id: "message-0001", kind: .text, sharedAt: 0, text: "and another thing", thread: "auto:note:2026-10-25")
    let request = try ChatSend.messageRequest(
      item, attachment: "2026-10-25/0123456789abcdef.jpg", cockpit: cockpit + "/")
    XCTAssertEqual(request.url?.absoluteString, "\(cockpit)/chat/auto:note:2026-10-25")
    let body = try json(request.httpBody)
    XCTAssertNil(body["title"])
    XCTAssertEqual(body["attachments"] as? [String], ["2026-10-25/0123456789abcdef.jpg"])
  }

  func testAThreadKeyCannotAddAPathSegment() {
    XCTAssertEqual(ChatWire.encode("igor2-88g.500"), "igor2-88g.500")
    XCTAssertEqual(ChatWire.encode("a/../b"), "a%2F..%2Fb")
    XCTAssertEqual(ChatWire.encode("with space"), "with%20space")
  }

  func testAnImageIsUploadedAsItsRawBytes() throws {
    let png = TestImages.png
    let request = try ChatSend.uploadRequest(image: png, cockpit: cockpit)
    XCTAssertEqual(request.url?.absoluteString, "\(cockpit)/attachments")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.httpBody, png)
    #if canImport(ImageIO)
      // The type is ImageIO's reading of the bytes; Linux has none, so it is the Mac's to say.
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/png")
    #endif
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), cockpit)
  }

  func testEveryAnswerClass() {
    let ref = Data(#"{"ok": true, "ref": "2026-10-25/0123456789abcdef.png", "url": "/attachments/x"}"#.utf8)
    XCTAssertEqual(ChatSend.upload(status: 200, body: ref), .ref("2026-10-25/0123456789abcdef.png"))
    XCTAssertEqual(
      ChatSend.upload(status: 400, body: Data(#"{"ok": false, "error": "not an image"}"#.utf8)),
      .refused(status: 400, reason: "not an image"))
    XCTAssertEqual(ChatSend.upload(status: 502, body: nil), .retry(reason: "HTTP 502"))
    XCTAssertEqual(ChatSend.upload(status: nil, body: nil, error: "offline"), .retry(reason: "offline"))

    let sent = Data(#"{"ok": true, "thread": "igor2-88g.500", "message": {}, "title": "x"}"#.utf8)
    let dup = Data(#"{"ok": true, "thread": "igor2-88g.500", "duplicate": true}"#.utf8)
    XCTAssertEqual(ChatSend.outcome(status: 200, body: sent), .sent(thread: "igor2-88g.500", duplicate: false))
    XCTAssertEqual(ChatSend.outcome(status: 200, body: dup), .sent(thread: "igor2-88g.500", duplicate: true))
    XCTAssertEqual(
      ChatSend.outcome(status: 404, body: Data(#"{"ok": false, "error": "no such thread"}"#.utf8)),
      .refused(status: 404, reason: "no such thread"))
    XCTAssertEqual(ChatSend.outcome(status: 403, body: nil), .refused(status: 403, reason: "HTTP 403"))
    XCTAssertEqual(
      ChatSend.outcome(status: 502, body: Data(#"{"ok": false, "error": "bd down"}"#.utf8)), .retry(reason: "bd down"))
    XCTAssertEqual(ChatSend.outcome(status: 200, body: Data(#"{"ok": true}"#.utf8)), .retry(reason: "HTTP 200"))
  }

  // MARK: The sender

  func testAShareBecomesAThreadAndAReplyGoesToItsThread() async throws {
    try store.add(InboxItem(id: "share-0001", kind: .text, sharedAt: 1, text: "new topic"))
    try store.add(InboxItem(id: "reply-0001", kind: .text, sharedAt: 2, text: "more", thread: "igor2-88g.7"))
    let seen = Requests()
    let sender = InboxSender(store: store, cockpit: cockpit) { request in
      await seen.add(request)
      let path = request.url?.path ?? ""
      let thread = path == "/chat" ? "igor2-88g.9" : "igor2-88g.7"
      return Self.answer(request, 200, #"{"ok": true, "thread": "\#(thread)"}"#)
    }
    var lines: [(String, [String: Any])] = []
    let report = await sender.sendWaiting(now: { Date(timeIntervalSince1970: 5) }, log: { lines.append(($0, $1)) })
    XCTAssertEqual(report.sent, ["share-0001", "reply-0001"])
    let paths = await seen.paths
    XCTAssertEqual(paths, ["/chat", "/chat/igor2-88g.7"])
    XCTAssertEqual(store.item("share-0001")?.chatThread, "igor2-88g.9")
    XCTAssertEqual(store.item("reply-0001")?.chatThread, "igor2-88g.7")
    XCTAssertEqual(store.item("share-0001")?.isEarlierShare, false)
    XCTAssertEqual(lines.map(\.0), ["chat", "chat"])
    XCTAssertEqual(lines.first?.1["thread"] as? String, "igor2-88g.9")
    XCTAssertFalse(lines.contains { $0.1.values.contains { "\($0)".contains("new topic") } }, "no content in the log")
  }

  func testAnImageIsUploadedThenNamedByItsRefInTheMessage() async throws {
    let png = TestImages.png
    try store.add(
      InboxItem(id: "photo-0001", kind: .image, sharedAt: 1, note: "look"), image: png, imageExtension: "png")
    let seen = Requests()
    let sender = InboxSender(store: store, cockpit: cockpit, readyImage: TestImages.asTheyAre) { request in
      await seen.add(request)
      if request.url?.path == "/attachments" {
        return Self.answer(request, 200, #"{"ok": true, "ref": "2026-10-25/0123456789abcdef.png"}"#)
      }
      return Self.answer(request, 200, #"{"ok": true, "thread": "igor2-88g.9"}"#)
    }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report.sent, ["photo-0001"])
    let requests = await seen.all
    XCTAssertEqual(requests.map { $0.url?.path }, ["/attachments", "/chat"])
    XCTAssertEqual(requests[0].httpBody, png)
    let body = try json(requests[1].httpBody)
    XCTAssertEqual(body["attachments"] as? [String], ["2026-10-25/0123456789abcdef.png"])
    XCTAssertEqual(body["text"] as? String, "look")
  }

  // Story 1176: deleted from the Inbox while its picture went up, it is never posted.
  func testAnItemDeletedDuringItsUploadIsNeverPosted() async throws {
    let store = store
    try store.add(
      InboxItem(id: "photo-0001", kind: .image, sharedAt: 1, note: "look"), image: TestImages.png,
      imageExtension: "png")
    let seen = Requests()
    let sender = InboxSender(store: store, cockpit: cockpit, readyImage: TestImages.asTheyAre) { request in
      await seen.add(request)
      if request.url?.path == "/attachments" {
        if let item = store.item("photo-0001") { try store.delete(item) }
        return Self.answer(request, 200, #"{"ok": true, "ref": "2026-10-25/0123456789abcdef.png"}"#)
      }
      return Self.answer(request, 200, #"{"ok": true, "thread": "igor2-88g.9"}"#)
    }
    var lines: [String] = []
    let report = await sender.sendWaiting { kind, _ in lines.append(kind) }
    let paths = await seen.paths
    XCTAssertEqual(paths, ["/attachments"], "no message after the delete")
    XCTAssertEqual(report.sent, [])
    XCTAssertEqual(report.refused, [])
    XCTAssertNil(store.item("photo-0001"))
    XCTAssertEqual(lines, [])
  }

  func testARefusedUploadRefusesTheMessageAndAFailedOneStopsTheRun() async throws {
    let png = TestImages.png
    try store.add(InboxItem(id: "photo-0001", kind: .image, sharedAt: 1), image: png, imageExtension: "png")
    try store.add(InboxItem(id: "photo-0002", kind: .image, sharedAt: 2), image: png, imageExtension: "png")
    try store.add(InboxItem(id: "text-0003", kind: .text, sharedAt: 3, text: "waits"))
    let calls = Requests()
    let sender = InboxSender(store: store, cockpit: cockpit, readyImage: TestImages.asTheyAre) { request in
      await calls.add(request)
      let count = await calls.all.count
      return count == 1
        ? Self.answer(request, 400, #"{"ok": false, "error": "not an image Cockpit accepts"}"#)
        : Self.answer(request, 503, "down")
    }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report.refused, ["photo-0001"])
    XCTAssertEqual(report.retry, "image upload: HTTP 503")
    XCTAssertEqual(store.item("photo-0001")?.refused, "not an image Cockpit accepts")
    XCTAssertEqual(store.item("photo-0002")?.status, .waiting)
    XCTAssertEqual(store.item("text-0003")?.status, .waiting, "nothing after an unreachable Cockpit is tried")
    let paths = await calls.paths
    XCTAssertEqual(paths, ["/attachments", "/attachments"], "a refused upload sends no message")
  }

  // #565: a timeout or no connection is the Cockpit away; an error it answers with is not.
  func testATimeoutIsTheCockpitAwayAndAServerErrorIsNot() async throws {
    try store.add(InboxItem(id: "text-0001", kind: .text, sharedAt: 1, text: "waits"))
    let away = InboxSender(store: store, cockpit: cockpit) { _ in throw URLError(.timedOut) }
    var lines: [[String: Any]] = []
    let report = await away.sendWaiting { lines.append($1) }
    XCTAssertNotNil(report.retry)
    XCTAssertTrue(report.unreachable)
    XCTAssertEqual(lines.first?["unreachable"] as? Bool, true)
    XCTAssertEqual(store.item("text-0001")?.status, .waiting)

    let down = InboxSender(store: store, cockpit: cockpit) { Self.answer($0, 503, "down") }
    let answered = await down.sendWaiting { _, _ in }
    XCTAssertEqual(answered.retry, "HTTP 503")
    XCTAssertFalse(answered.unreachable)
  }

  func testTheAwayLineKeepsTheReasonAndOtherFailuresKeepTheirOwn() {
    XCTAssertTrue(CockpitReach.isAway(URLError(.cannotConnectToHost)))
    XCTAssertFalse(CockpitReach.isAway(URLError(.badServerResponse)))
    XCTAssertFalse(CockpitReach.isAway(CocoaError(.fileReadCorruptFile)))
    let line = CockpitReach.problem(URLError(.timedOut), otherwise: "Could not read")
    XCTAssertTrue(line.hasPrefix(CockpitReach.away), line)
    XCTAssertTrue(line.contains(URLError(.timedOut).localizedDescription), line)
    let other = CockpitReach.problem(URLError(.badServerResponse), otherwise: "Could not read")
    XCTAssertTrue(other.hasPrefix("Could not read: "), other)
  }

  func testAnItemSentBeforeChatIsAnEarlierShare() throws {
    try store.add(InboxItem(id: "old-00001", kind: .text, sharedAt: 1, text: "from October"))
    try store.markSent("old-00001", at: 2)
    XCTAssertEqual(store.item("old-00001")?.isEarlierShare, true)
    XCTAssertEqual(store.waitingCount, 0)
    // Its file from before chat (no thread fields at all) still reads.
    let legacy = #"{"id":"legacy-0001","kind":"text","shared_at":1,"text":"x","sent_at":2}"#
    try Data(legacy.utf8).write(to: dir.appendingPathComponent("legacy-0001.json"))
    XCTAssertEqual(store.item("legacy-0001")?.isEarlierShare, true)
  }

  // MARK: Reading

  /// The shape `GET /chat` answers with (Cockpit serve.py `chat_list_payload`), two real-looking rows.
  func testTheThreadListDecodesAndSortsNewestFirst() throws {
    let body = #"""
      {"ok": true, "threads": [
        {"key": "igor2-88g.374", "count": 4, "last_ts": "2026-10-24T08:00:00-07:00", "last_who": "igor",
         "last_text": "does it poll?", "igor_receipt": null, "larry_ts": [], "title": "Cockpit chat tab",
         "unread": 0, "done": true},
        {"key": "auto:note:2026-10-25", "count": 2, "last_ts": "2026-10-25T09:00:00-07:00", "last_who": "larry",
         "last_text": "Yes, every ten seconds.", "larry_ts": ["2026-10-25T09:00:00-07:00"], "title": "notes",
         "unread": 1, "done": false}
      ]}
      """#
    let rows = try XCTUnwrap(ChatWire.summaries(Data(body.utf8)))
    XCTAssertEqual(rows.map(\.key), ["auto:note:2026-10-25", "igor2-88g.374"])
    XCTAssertEqual(rows[0].unread, 1)
    XCTAssertTrue(rows[0].larryHasLastWord)
    XCTAssertTrue(rows[1].done)
    XCTAssertEqual(rows[1].title, "Cockpit chat tab")
    XCTAssertNil(ChatWire.summaries(Data(#"{"ok": false, "error": "bd down"}"#.utf8)))
    XCTAssertNil(ChatWire.summaries(Data("<html>".utf8)))
  }

  /// #630: the Cockpit's receipt ladder. A state this build doesn't know is received, no receipt at all is sent.
  func testTheReceiptLadderDecodesAndDrawsTheCockpitsGlyphs() throws {
    let json = #"""
      {"ok": true, "messages": [
        {"id": "a", "ts": "", "who": "igor", "text": "", "receipt": {"state": "received", "received_ts": "x"}},
        {"id": "b", "ts": "", "who": "igor", "text": "", "receipt": {"state": "seen", "seen_ts": "x"}},
        {"id": "c", "ts": "", "who": "igor", "text": "", "receipt": {"state": "done", "done_ts": "x"}},
        {"id": "d", "ts": "", "who": "igor", "text": "", "receipt": {"state": "delivered"}},
        {"id": "e", "ts": "", "who": "igor", "text": "", "receipt": null},
        {"id": "f", "ts": "", "who": "igor", "text": ""}
      ]}
      """#
    let messages = try XCTUnwrap(ChatWire.messages(Data(json.utf8)))
    XCTAssertEqual(messages.map(\.receipt), [.received, .seen, .done, .received, .sent, .sent])
    XCTAssertEqual(messages.map(\.receipt.glyph), ["👀", "🫡", "🏆", "👀", nil, nil])
  }

  /// #603: the board a picture came from, echoed by the Cockpit; old rows have none.
  func testAMessageCarriesItsBoardWhenItHasOne() throws {
    let json = #"""
      {"ok": true, "messages": [
        {"id": "a", "ts": "", "who": "igor", "text": "", "attachments": ["2026-11-01/0000000000000592.png"], "board": "b-1"},
        {"id": "b", "ts": "", "who": "igor", "text": "old row"},
        {"id": "c", "ts": "", "who": "igor", "text": "", "board": ""},
        {"id": "d", "ts": "", "who": "igor", "text": "", "board": 7}
      ]}
      """#
    let messages = try XCTUnwrap(ChatWire.messages(Data(json.utf8)))
    XCTAssertEqual(messages.map(\.board), ["b-1", nil, nil, nil])
  }

  func testAThreadsMessagesCarryReceiptsAndImages() throws {
    let body = #"""
      {"ok": true, "thread": "igor2-88g.374", "messages": [
        {"id": "a1", "ts": "2026-10-25T09:00:00-07:00", "thread": "igor2-88g.374", "who": "igor",
         "text": "rename the export button", "source": "app",
         "receipt": {"state": "done", "seen_ts": "x", "done_ts": "y", "note": "renamed"}},
        {"id": "a2", "ts": "2026-10-25T09:01:00-07:00", "thread": "igor2-88g.374", "who": "larry",
         "text": "", "source": "cli", "attachments": ["2026-10-25/0123456789abcdef.png"]},
        {"id": "a3", "ts": "2026-10-25T09:02:00-07:00", "thread": "igor2-88g.374", "who": "igor", "text": "ok",
         "source": "cockpit"}
      ]}
      """#
    let messages = try XCTUnwrap(ChatWire.messages(Data(body.utf8)))
    XCTAssertEqual(messages.map(\.receipt), [.done, .sent, .sent])
    XCTAssertEqual(messages[0].doneNote, "renamed")
    XCTAssertTrue(messages[0].fromIgor)
    XCTAssertEqual(messages[1].attachments, ["2026-10-25/0123456789abcdef.png"])
    XCTAssertEqual(
      ChatWire.attachmentURL(messages[1].attachments[0], cockpit: cockpit)?.absoluteString,
      "\(cockpit)/attachments/2026-10-25/0123456789abcdef.png")
    XCTAssertNil(ChatWire.attachmentURL("../../etc/passwd", cockpit: cockpit))
  }

  /// #633, story 1125: a document the Cockpit minted (Cockpit story 167) is served and drawn as a file row.
  func testADeliveredDocumentIsAFileRowNamedFromTheMessage() {
    let pdf = "2026-11-21/0123456789abcdef.pdf"
    XCTAssertEqual(ChatWire.attachment(pdf), .document(ext: "pdf", label: "PDF"))
    XCTAssertEqual(ChatWire.attachment("2026-11-21/0123456789abcdef.png"), .image)
    XCTAssertEqual(ChatWire.attachment("2026-11-21/0123456789abcdef.txt"), .document(ext: "txt", label: "Text"))
    XCTAssertEqual(
      ChatWire.attachment("2026-11-21/0123456789abcdef.xlsx"), .document(ext: "xlsx", label: "Excel spreadsheet"))
    XCTAssertNil(ChatWire.attachment("2026-11-21/0123456789abcdef.zip"))
    XCTAssertNil(ChatWire.attachment("2026-11-21/0123456789abcdef.pdf.png/../x"))
    XCTAssertEqual(
      ChatWire.attachmentURL(pdf, cockpit: cockpit)?.absoluteString, "\(cockpit)/attachments/\(pdf)")
    // The phone sends the file's name first, then the words.
    XCTAssertEqual(ChatWire.documentName(pdf, text: "Lease.pdf\n\nread page 3"), "Lease.pdf")
    XCTAssertEqual(ChatWire.documentName(pdf, text: "LEASE.PDF"), "LEASE.PDF")
    // Words that are not a name of that type, a path, or nothing: the Cockpit's own name.
    XCTAssertEqual(ChatWire.documentName(pdf, text: "read this"), "0123456789abcdef.pdf")
    XCTAssertEqual(ChatWire.documentName(pdf, text: "notes.txt"), "0123456789abcdef.pdf")
    XCTAssertEqual(ChatWire.documentName(pdf, text: "../../x.pdf"), "0123456789abcdef.pdf")
    XCTAssertEqual(ChatWire.documentName(pdf, text: ".pdf"), "0123456789abcdef.pdf")
    XCTAssertEqual(ChatWire.documentName(pdf, text: ""), "0123456789abcdef.pdf")
  }

  /// Story 1126: a fetch that can't open says why; a good one says nothing.
  func testADocumentThatCannotBeFetchedSaysWhy() {
    XCTAssertNil(ChatWire.documentProblem(name: "Lease.pdf", status: 200, bytes: 10))
    XCTAssertEqual(
      ChatWire.documentProblem(name: "Lease.pdf", status: 404, bytes: 0),
      "The Cockpit no longer has Lease.pdf (HTTP 404).")
    XCTAssertEqual(
      ChatWire.documentProblem(name: "Lease.pdf", status: 502, bytes: 3),
      "Lease.pdf could not be fetched from the Cockpit (HTTP 502).")
    XCTAssertEqual(
      ChatWire.documentProblem(name: "Lease.pdf", status: 200, bytes: 0), "The Cockpit sent Lease.pdf back empty.")
    XCTAssertEqual(
      ChatWire.documentProblem(name: "Lease.pdf", status: nil, bytes: 0, error: "offline"),
      "Lease.pdf could not be fetched from the Cockpit: offline")
    XCTAssertEqual(
      ChatWire.documentProblem(name: "Lease.pdf", status: nil, bytes: 0),
      "Lease.pdf could not be fetched from the Cockpit: no answer")
  }

  func testOpeningAThreadMarksItSeenByKey() throws {
    let request = try ChatWire.seenRequest("auto:note:2026-10-25", cockpit: cockpit)
    XCTAssertEqual(request.url?.absoluteString, "\(cockpit)/chat-seen")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), cockpit)
    XCTAssertEqual(try json(request.httpBody)["thread"] as? String, "auto:note:2026-10-25")
    XCTAssertEqual(
      try ChatWire.threadRequest("auto:note:2026-10-25", cockpit: cockpit).url?.absoluteString,
      "\(cockpit)/chat/auto:note:2026-10-25")
  }

  // MARK: Hearing back

  func testOnlyANewUnreadReplyFromLarryIsNotifiedAndOnlyOnce() {
    let reply = ChatSummary(
      key: "a", title: "A", lastTs: "2026-10-25T09:00:00-07:00", lastWho: "larry", lastText: "hi", unread: 1)
    let mine = ChatSummary(
      key: "b", title: "B", lastTs: "2026-10-25T09:00:00-07:00", lastWho: "igor", lastText: "?", unread: 0)
    let readElsewhere = ChatSummary(
      key: "c", title: "C", lastTs: "2026-10-25T09:00:00-07:00", lastWho: "larry", lastText: "hi", unread: 0)
    let earlier = ["z": "2026-10-24T09:00:00-07:00"]
    XCTAssertEqual(ChatNotify.due([reply, mine, readElsewhere], notified: earlier).map(\.key), ["a"])
    let recorded = ChatNotify.record([reply, mine], into: earlier)
    XCTAssertEqual(recorded["a"], "2026-10-25T09:00:00-07:00")
    XCTAssertTrue(ChatNotify.due([reply], notified: recorded).isEmpty, "once per reply")
    let newer = ChatSummary(
      key: "a", title: "A", lastTs: "2026-10-25T10:00:00-07:00", lastWho: "larry", lastText: "and", unread: 2)
    XCTAssertEqual(ChatNotify.due([newer], notified: recorded).map(\.key), ["a"])
  }

  func testTheFirstCheckOnlyRecordsAndADoneThreadNeverNotifies() {
    let waiting = ChatSummary(
      key: "a", title: "A", lastTs: "2026-10-01T09:00:00-07:00", lastWho: "larry", lastText: "hi", unread: 3)
    XCTAssertTrue(ChatNotify.due([waiting], notified: [:]).isEmpty, "no burst on the first check")
    let done = ChatSummary(
      key: "d", title: "D", lastTs: "2026-10-25T09:00:00-07:00", lastWho: "larry", lastText: "done", unread: 1,
      done: true)
    XCTAssertTrue(ChatNotify.due([done], notified: ["a": waiting.lastTs]).isEmpty)
  }

  // MARK: Helpers

  private func json(_ data: Data?) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
  }

  static func answer(_ request: URLRequest, _ status: Int, _ body: String) -> (Data, URLResponse) {
    (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
  }

  private actor Requests {
    var all: [URLRequest] = []
    var paths: [String] { all.map { $0.url?.path ?? "" } }
    func add(_ request: URLRequest) { all.append(request) }
  }

  // MARK: Archiving (#589)

  func testAnArchivedRowReadsArchivedAndAnOldCockpitsRowIsNot() throws {
    let rows = try XCTUnwrap(
      ChatWire.summaries(
        Data(
          """
          {"ok": true, "threads": [
            {"key": "a", "title": "A", "archived": true, "done": true},
            {"key": "b", "title": "B"}
          ]}
          """.utf8)))
    XCTAssertEqual(rows.map(\.archived), [true, false])
    XCTAssertEqual(rows.map(\.done), [true, false])
  }

  func testArchivingARowFoldsItUnderDoneAndUnarchivingBringsItBack() {
    let row = ChatSummary(key: "k", title: "T", lastTs: "", lastWho: "larry", lastText: "hi", unread: 2)
    XCTAssertEqual(row.archiving(true).done, true)
    XCTAssertEqual(row.archiving(true).archived, true)
    XCTAssertEqual(row.archiving(true).archiving(false), row)
  }

  func testALooksDoneRowReadsAndAnOldCockpitsRowDoesNot() throws {
    let rows = try JSONDecoder().decode(
      [ChatSummary].self,
      from: Data(#"[{"key": "a", "title": "A", "looks_done": true}, {"key": "b", "title": "B"}]"#.utf8))
    XCTAssertEqual(rows.map(\.looksDone), [true, false])
    XCTAssertTrue(rows[0].archiving(true).looksDone, "archiving keeps the mark, for an Undo")
  }

  func testAPinnedRowReadsAndKeepsItsPin() throws {
    let rows = try JSONDecoder().decode(
      [ChatSummary].self,
      from: Data(#"[{"key": "a", "title": "Larry", "count": 0, "pinned": true}, {"key": "b", "title": "B"}]"#.utf8))
    XCTAssertEqual(rows.map(\.pinned), [true, false])
    XCTAssertTrue(rows[0].archiving(false).pinned)
  }

  func testAnEmptyPinnedRowComesFirstAheadOfNewerActivity() throws {
    let rows = try XCTUnwrap(
      ChatWire.summaries(
        Data(
          """
          {"ok": true, "threads": [
            {"key": "old", "title": "Old", "count": 1, "last_ts": "2026-10-20T09:00:00-07:00"},
            {"key": "new", "title": "New", "count": 1, "last_ts": "2026-11-01T09:00:00-07:00"},
            {"key": "pin", "title": "Larry", "count": 0, "last_ts": "", "pinned": true}
          ]}
          """.utf8)))
    XCTAssertEqual(rows.map(\.key), ["pin", "new", "old"])
  }

  // MARK: A skill's thread (#632, stories 512-516; the shapes are cockpit#90's contract)

  private static let skillList = #"""
    {"ok": true, "threads": [
      {"key": "new", "title": "New", "count": 1, "last_ts": "2026-11-03T12:00:00-07:00", "last_who": "larry",
       "last_author": "", "last_text": "hi", "skill": null, "pinned": false},
      {"key": "skill", "title": "idvorkin", "count": 2, "last_ts": "2026-11-03T11:00:00-07:00", "last_who": "larry",
       "last_author": "idvorkin", "last_text": "See the post.", "skill": "idvorkin", "pinned": true, "unread": 1},
      {"key": "pin", "title": "Larry", "count": 0, "last_ts": "", "last_who": "", "last_author": "", "skill": null,
       "pinned": true}
    ]}
    """#

  func testLarrysPinnedThreadSitsAboveASkillsHoweverNewAndBothAboveTheRest() throws {
    let rows = try XCTUnwrap(ChatWire.summaries(Data(Self.skillList.utf8)))
    XCTAssertEqual(rows.map(\.key), ["pin", "skill", "new"])
    XCTAssertEqual(rows.map(\.skill), [nil, "idvorkin", nil])
    XCTAssertEqual(rows.map(\.answeredBy), ["Larry", "idvorkin", "Larry"])
  }

  func testTheRowAndTheNotificationNameTheSkillWhenItSpokeLast() throws {
    let rows = try XCTUnwrap(ChatWire.summaries(Data(Self.skillList.utf8)))
    XCTAssertEqual(rows[1].lastLine, "idvorkin: See the post.")
    XCTAssertEqual(rows[1].lastSpeaker, "idvorkin")
    XCTAssertEqual(rows[2].lastLine, "Larry: hi")
    XCTAssertEqual(rows[0].lastLine, "Drop anything here")
    let empty = ChatSummary(key: "s", title: "s", count: 0, lastTs: "", lastWho: "", lastText: "", skill: "idvorkin")
    XCTAssertEqual(empty.lastLine, "Ask idvorkin")
    let mine = ChatSummary(key: "s", title: "s", lastTs: "", lastWho: "igor", lastText: "?", skill: "idvorkin")
    XCTAssertEqual(mine.lastLine, "You: ?")
    let due = ChatNotify.due(rows, notified: ["z": "2026-11-01T09:00:00-07:00"])
    XCTAssertEqual(due.map(\.key), ["skill"], "the skill's reply notifies as Larry's does")
  }

  func testReadingOrArchivingASkillsRowKeepsWhoseItIs() throws {
    let row = try XCTUnwrap(ChatWire.summaries(Data(Self.skillList.utf8)))[1]
    XCTAssertEqual(row.read().unread, 0)
    for copy in [row.read(), row.archiving(false)] {
      XCTAssertEqual(copy.skill, "idvorkin")
      XCTAssertEqual(copy.lastAuthor, "idvorkin")
      XCTAssertTrue(copy.pinned)
    }
  }

  func testAnOlderCockpitsAnswersReadAsLarry() throws {
    let rows = try XCTUnwrap(
      ChatWire.summaries(
        Data(
          #"{"ok": true, "threads": [{"key": "a", "title": "A", "count": 1, "last_who": "larry", "last_text": "hi"}]}"#
            .utf8)))
    XCTAssertNil(rows[0].skill)
    XCTAssertEqual(rows[0].lastLine, "Larry: hi")
    XCTAssertEqual(rows[0].answeredBy, "Larry")
    let messages = try XCTUnwrap(
      ChatWire.messages(Data(#"{"ok": true, "messages": [{"id": "a", "ts": "", "who": "larry", "text": "hi"}]}"#.utf8)))
    XCTAssertNil(messages[0].author)
    XCTAssertNil(messages[0].authorInitial)
    XCTAssertFalse(messages[0].isError)
  }

  func testASkillsRowsCarryTheirAuthorAndAFailureIsAnError() throws {
    let json = #"""
      {"ok": true, "skill": "idvorkin", "messages": [
        {"id": "r", "ts": "x", "thread": "k", "who": "larry", "author": "idvorkin", "text": "See it.", "source": "cockpit"},
        {"id": "e", "ts": "x", "thread": "k", "who": "larry", "author": "idvorkin", "error": true,
         "text": "The idvorkin skill could not answer: no key. Send again to retry.", "source": "cockpit"}
      ]}
      """#
    let messages = try XCTUnwrap(ChatWire.messages(Data(json.utf8)))
    XCTAssertEqual(messages.map(\.author), ["idvorkin", "idvorkin"])
    XCTAssertEqual(messages.map(\.authorInitial), ["I", "I"])
    XCTAssertEqual(messages.map(\.isError), [false, true])
    XCTAssertFalse(messages[0].fromIgor)
  }

  func testOnlyARealReplyAnswersAMessage() {
    func igor(_ id: String) -> ChatMessage { ChatMessage(id: id, ts: "", who: "igor", text: "", receipt: .done) }
    func reply(_ id: String) -> ChatMessage { ChatMessage(id: id, ts: "", who: "larry", text: "", author: "idvorkin") }
    func failure(_ id: String) -> ChatMessage {
      ChatMessage(id: id, ts: "", who: "larry", text: "", author: "idvorkin", isError: true)
    }
    XCTAssertEqual(ChatWire.answerFailed([igor("a"), failure("e")]), ["a"])
    XCTAssertEqual(ChatWire.answerFailed([igor("a"), failure("e"), igor("b"), failure("f")]), ["a", "b"])
    XCTAssertEqual(
      ChatWire.answerFailed([igor("a"), failure("e"), igor("b"), reply("r")]), [], "the retry answered both")
    XCTAssertEqual(ChatWire.answerFailed([igor("a"), reply("r"), igor("b"), failure("e")]), ["b"])
    XCTAssertEqual(
      ChatWire.answerFailed([igor("a"), reply("r"), failure("e")]), [], "a was answered before the failure")
    XCTAssertEqual(ChatWire.answerFailed([igor("a")]), [], "still waiting is not a failure")
  }

  func testAPinnedRowNeverLooksDone() throws {
    let rows = try JSONDecoder().decode(
      [ChatSummary].self,
      from: Data(#"[{"key": "a", "title": "Larry", "pinned": true, "looks_done": true}]"#.utf8))
    XCTAssertEqual(rows.map(\.looksDone), [false], "Review would tick it for an archive the Cockpit refuses")
  }

  func testTheArchiveRequestNamesTheThreadAndTheWay() throws {
    let archive = try ChatWire.archiveRequest("auto:note:1", archive: true, cockpit: "https://c.example/")
    XCTAssertEqual(archive.url?.absoluteString, "https://c.example/chat/auto:note:1/archive")
    XCTAssertEqual(archive.httpMethod, "POST")
    XCTAssertEqual(archive.value(forHTTPHeaderField: "Origin"), "https://c.example")
    let back = try ChatWire.archiveRequest("a/b", archive: false, cockpit: "https://c.example")
    XCTAssertEqual(back.url?.absoluteString, "https://c.example/chat/a%2Fb/unarchive")
    // The Cockpit's write boundary answers 415 to any other media type, an empty body included.
    XCTAssertEqual(archive.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(back.value(forHTTPHeaderField: "Content-Type"), "application/json")
  }

  func testTheCockpitsArchiveAnswers() {
    XCTAssertNil(ChatWire.archiveFailure(status: 200, body: Data(#"{"ok": true, "archived": true}"#.utf8)))
    XCTAssertEqual(
      ChatWire.archiveFailure(status: 404, body: Data(#"{"ok": false, "error": "no such thread"}"#.utf8)),
      "no such thread (HTTP 404)")
    XCTAssertEqual(ChatWire.archiveFailure(status: 502, body: nil), "HTTP 502")
    XCTAssertEqual(ChatWire.archiveFailure(status: nil, body: nil, error: "offline"), "offline")
  }

  func testABatchsProblemNamesEveryThreadAndItsReason() {
    XCTAssertEqual(
      ChatWire.archiveProblem([("A", "HTTP 502")], archive: true), #"Could not archive "A": HTTP 502"#,
      "one thread reads as it always did")
    XCTAssertEqual(
      ChatWire.archiveProblem([("A", "HTTP 502"), ("B", "no such thread (HTTP 404)")], archive: false),
      #"Could not unarchive 2 chats: "A": HTTP 502; "B": no such thread (HTTP 404)"#)
  }

  func testATickedThreadThatLeftTheLiveListIsNotArchived() {
    func row(_ key: String, done: Bool = false, archived: Bool = false) -> ChatSummary {
      ChatSummary(key: key, title: key, lastTs: "", lastWho: "larry", lastText: "", done: done, archived: archived)
    }
    let threads = [row("a"), row("done", done: true), row("archived", done: true, archived: true), row("b"), row("c")]
    XCTAssertEqual(
      ChatWire.liveKeys(["b", "a", "done", "archived", "gone"], in: threads), ["a", "b"],
      "only live rows, in list order; unticked c stays out")
  }
}
