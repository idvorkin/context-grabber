import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// #587, stories 495–499: which chats the share card offers, and a share picked into one going out as its next message.
final class ShareThreadsTests: XCTestCase {
  private var dir: URL!
  private var store: InboxStore { InboxStore(directory: dir) }
  private let cockpit = "https://cockpit.test"

  override func setUp() {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("share-\(UUID().uuidString)")
  }

  override func tearDown() { try? FileManager.default.removeItem(at: dir) }

  private func row(_ key: String, done: Bool = false, archived: Bool = false, pinned: Bool = false) -> ChatSummary {
    ChatSummary(
      key: key, title: key, lastTs: "2026-11-01T10:00:00+00:00", lastWho: "igor", lastText: "", done: done,
      archived: archived, pinned: pinned)
  }

  private func answer(_ status: Int, _ body: String) -> InboxSender.Transport {
    { request in ChatTests.answer(request, status, body) }
  }

  // MARK: Story 495: what the card offers

  func testTheCardOffersFiveLiveChatsInTheListsOrder() {
    let rows = [
      row("pinned", pinned: true), row("a"), row("done", done: true), row("archived", done: true, archived: true),
      row("b"), row("c"), row("d"), row("e"), row("f"),
    ]
    XCTAssertEqual(ShareThreads.rows(ShareThreads.live(rows)).map(\.key), ["pinned", "a", "b", "c", "d"])
  }

  func testAnArchivedRowTheCockpitDidNotMarkDoneIsStillNotOffered() {
    XCTAssertEqual(ShareThreads.live([row("archived", archived: true), row("a")]).map(\.key), ["a"])
  }

  func testTheListIsAskedOfTheChatRouteAndSortedWithThePinnedChatFirst() async {
    let body = """
      {"ok": true, "threads": [
        {"key": "old", "title": "Old", "last_ts": "2026-11-01T10:00:00+00:00"},
        {"key": "new", "title": "New", "last_ts": "2026-11-02T10:00:00+00:00"},
        {"key": "always", "title": "Larry", "last_ts": "", "pinned": true}
      ]}
      """
    let asked = Requests()
    let read = await ShareThreads.read(cockpit: cockpit) { request in
      await asked.add(request)
      return ChatTests.answer(request, 200, body)
    }
    guard case .threads(let rows) = read else { return XCTFail("\(read)") }
    XCTAssertEqual(rows.map(\.key), ["always", "new", "old"])
    let request = await asked.all.first
    XCTAssertEqual(request?.url?.path, "/chat")
    XCTAssertEqual(request?.httpMethod, "GET")
    XCTAssertEqual(request?.timeoutInterval, ShareThreads.timeout)
  }

  // MARK: Story 497: the list cannot be read

  func testAnErrorAnswerIsNewChatOnlyAndNamesTheStatus() async {
    let read = await ShareThreads.read(cockpit: cockpit, transport: answer(500, #"{"ok": false}"#))
    XCTAssertEqual(read, .problem("New chat only: the Cockpit answered HTTP 500."))
  }

  func testAnAnswerThatIsNotAListIsNewChatOnly() async {
    let read = await ShareThreads.read(cockpit: cockpit, transport: answer(200, "<html>login</html>"))
    XCTAssertEqual(read, .problem("New chat only: the Cockpit answered HTTP 200."))
  }

  func testNoAnswerSaysTheCockpitIsAwayAndKeepsTheReason() async {
    let read = await ShareThreads.read(cockpit: cockpit) { _ in throw URLError(.timedOut) }
    guard case .problem(let why) = read else { return XCTFail("\(read)") }
    XCTAssertTrue(why.hasPrefix("New chat only: the Cockpit isn't answering. ("), why)
    XCTAssertTrue(why.contains(URLError(.timedOut).localizedDescription), why)
  }

  func testAnotherFailureSaysTheChatsCouldNotBeRead() async {
    let read = await ShareThreads.read(cockpit: cockpit) { _ in throw URLError(.badServerResponse) }
    guard case .problem(let why) = read else { return XCTFail("\(read)") }
    XCTAssertTrue(why.hasPrefix("New chat only: the chats could not be read. ("), why)
  }

  func testNoLiveChatsIsNoProblem() async {
    let read = await ShareThreads.read(cockpit: cockpit, transport: answer(200, #"{"ok": true, "threads": []}"#))
    XCTAssertEqual(read, .threads([]))
  }

  // MARK: What the app's log hears

  func testWhatTheListHeldIsRecordedOnTheItemAndNeverGoesToTheCockpit() throws {
    XCTAssertEqual(ShareThreads.offered(nil), "reading")
    XCTAssertEqual(ShareThreads.offered(.threads([row("a"), row("b")])), "2 chats")
    XCTAssertEqual(ShareThreads.offered(.problem("New chat only: x")), "New chat only: x")

    var item = InboxItem(id: "share-1", kind: .text, sharedAt: 1, text: "hello", thread: "t1")
    item.offered = "2 chats"
    try store.add(item)
    XCTAssertEqual(store.item("share-1")?.offered, "2 chats")
    let body = try XCTUnwrap(ChatSend.messageRequest(item, attachment: nil, cockpit: cockpit).httpBody)
    XCTAssertFalse(String(decoding: body, as: UTF8.self).contains("2 chats"))
  }

  func testAnItemFromBeforeTheListStillReads() throws {
    let old = #"{"id": "old-1", "kind": "text", "shared_at": 1, "text": "hi"}"#
    let item = try JSONDecoder().decode(InboxItem.self, from: Data(old.utf8))
    XCTAssertNil(item.offered)
  }

  // MARK: Story 496: into the chat picked

  func testALinkPickedIntoAChatIsItsNextMessageWithNoNewThread() async throws {
    try store.add(
      InboxItem(
        id: "share-1", kind: .link, sharedAt: 1, url: "https://idvork.in/eulogy", note: "worth a read",
        thread: "igor2-88g.900"))
    let asked = Requests()
    let sender = InboxSender(store: store, cockpit: cockpit) { request in
      await asked.add(request)
      return ChatTests.answer(request, 200, #"{"ok": true, "thread": "igor2-88g.900"}"#)
    }
    let report = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(report.sent, ["share-1"])
    let requests = await asked.all
    XCTAssertEqual(requests.map { $0.url?.path }, ["/chat/igor2-88g.900"])
    let body = try XCTUnwrap(
      JSONSerialization.jsonObject(with: XCTUnwrap(requests[0].httpBody)) as? [String: Any])
    XCTAssertEqual(body["text"] as? String, "https://idvork.in/eulogy\n\nworth a read")
    XCTAssertEqual(body["id"] as? String, "share-1")
    XCTAssertNil(body["title"], "a chat that exists keeps its title")
    XCTAssertEqual(store.item("share-1")?.chatThread, "igor2-88g.900")
  }

  func testAPicturePickedIntoAChatIsUploadedThenPostedThere() async throws {
    let png = TestImages.png
    try store.add(
      InboxItem(id: "photo-1", kind: .image, sharedAt: 1, thread: "igor2-88g.900"), image: png, imageExtension: "png")
    let asked = Requests()
    let sender = InboxSender(store: store, cockpit: cockpit, readyImage: TestImages.asTheyAre) { request in
      await asked.add(request)
      return request.url?.path == "/attachments"
        ? ChatTests.answer(request, 200, #"{"ok": true, "ref": "2026-10-25/0123456789abcdef.png"}"#)
        : ChatTests.answer(request, 200, #"{"ok": true, "thread": "igor2-88g.900"}"#)
    }
    _ = await sender.sendWaiting { _, _ in }
    let paths = await asked.all.map { $0.url?.path }
    XCTAssertEqual(paths, ["/attachments", "/chat/igor2-88g.900"])
  }

  // MARK: Story 498: the chat has gone

  func testAShareIntoAGoneChatIsRefusedOnceAndStaysVisibleInTheList() async throws {
    try store.add(InboxItem(id: "share-1", kind: .text, sharedAt: 1, text: "hello", thread: "gone"))
    let asked = Requests()
    let sender = InboxSender(store: store, cockpit: cockpit) { request in
      await asked.add(request)
      return ChatTests.answer(request, 404, #"{"ok": false, "error": "no such thread"}"#)
    }
    let first = await sender.sendWaiting { _, _ in }
    XCTAssertEqual(first.refused, ["share-1"])
    _ = await sender.sendWaiting { _, _ in }
    let count = await asked.all.count
    XCTAssertEqual(count, 1, "never sent again")
    let items = store.items().items
    XCTAssertEqual(items.first?.refused, "no such thread")
    XCTAssertEqual(ChatWire.pendingThreads(items, listed: [row("other")]).map(\.id), ["share-1"])
  }

  func testTheListShowsWhatNoThreadOnScreenCouldShow() {
    var sent = InboxItem(id: "sent", kind: .text, sharedAt: 1, text: "x", thread: "unlisted")
    sent.delivery = .sent(at: 2, thread: "unlisted")
    let items = [
      InboxItem(id: "new", kind: .text, sharedAt: 1, text: "x"),
      InboxItem(id: "into-listed", kind: .text, sharedAt: 1, text: "x", thread: "listed"),
      InboxItem(id: "into-unlisted", kind: .text, sharedAt: 1, text: "x", thread: "unlisted"),
      sent,
    ]
    XCTAssertEqual(ChatWire.pendingThreads(items, listed: [row("listed")]).map(\.id), ["new", "into-unlisted"])
  }

  private actor Requests {
    var all: [URLRequest] = []
    func add(_ request: URLRequest) { all.append(request) }
  }
}
