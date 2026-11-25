//  SwiftUI previews' data (bead context-grabber-m6q, Igor 2026-11-24 "Add previews too"): fixture threads, messages,
//  an ask and the models behind them. A preview never reaches the network, the Cockpit or HealthKit: the healthy
//  models talk to `PreviewCockpit`, a stand-in answered in-process from these fixtures, and the `broken` models have
//  no address at all, so a reviewer sees the error state only where a preview asks for it. Debug builds only.

#if DEBUG
  import BugKit
  import Combine
  import ContextCore
  import Foundation

  @MainActor
  enum PreviewFixtures {
    /// One session log for every preview; it writes only to the preview's own sandbox.
    static let log = SessionLog()
    static let database = AppDatabase(log: log)
    /// The healthy models: every request goes to `PreviewCockpit`, which answers from the fixtures in-process.
    static let inbox: InboxModel = {
      PreviewCockpit.install()
      return InboxModel(log: log, database: database, cockpit: PreviewCockpit.address)
    }()
    static let chat: ChatModel = {
      let chat = ChatModel(inbox: inbox, log: log, database: database, cockpit: PreviewCockpit.address)
      chat.threads = threads
      return chat
    }()
    /// On purpose: no Cockpit address, so the list shows its "no Cockpit address" problem (the "is broken" picture).
    static let brokenChat: ChatModel = {
      let inbox = InboxModel(log: log, database: database, cockpit: ChatCockpit.nowhere)
      let chat = ChatModel(inbox: inbox, log: log, database: database, cockpit: ChatCockpit.nowhere)
      chat.threads = threads
      return chat
    }()
    static let voice = ChatVoiceModel(log: log, callLive: Just(false).eraseToAnyPublisher())
    static let logger: BugLogger = { _, _ in }

    static let threads: [ChatSummary] = [
      ChatSummary(
        key: "igor2-88g.1620", title: "Larry", count: 42, lastTs: "2026-11-24T21:10:00Z", lastWho: "larry",
        lastText: "Header patch is a branch you can fetch.", unread: 2, pinned: true, lastAuthor: "larry"),
      ChatSummary(
        key: "igor2-88g.1801", title: "How far from deploying?", count: 9, lastTs: "2026-11-24T16:55:00Z",
        lastWho: "agent", lastText: "Installed on the iPad and iPhone.", lastAuthor: "agent"),
      ChatSummary(
        key: "igor2-88g.1810", title: "Weekend plans", count: 3, lastTs: "2026-11-23T18:02:00Z", lastWho: "igor",
        lastText: "Harry Potter tickets for Saturday", looksDone: true, lastAuthor: "igor"),
    ]

    static let messages: [ChatMessage] = [
      ChatMessage(id: "m1", ts: "2026-11-24T21:00:00Z", who: "igor", text: "How far from deploying?", receipt: .done),
      ChatMessage(
        id: "m2", ts: "2026-11-24T21:01:00Z", who: "larry",
        text: "Main **a82a7722** is on the iPad. Next: the ipa on https://example.invalid/builds.", receipt: .done),
      ChatMessage(
        id: "m3", ts: "2026-11-24T21:02:00Z", who: "larry", text: "The Cockpit didn't answer.", isError: true),
    ]

    /// An open ask with a recommendation, as the Cockpit sends one.
    static let ask: ChatAsk = {
      let json = """
        {"id": "igor2-88g.9001", "title": "Who may draw on a board?",
         "context": "Boards move to the Cockpit; pick how two devices drawing at once are settled.",
         "options": [{"key": "a", "label": "The drawing device only"},
                     {"key": "b", "label": "Any device, last write wins"},
                     {"key": "c", "label": "Any device, clashes refused out loud", "detail": "Most work"}],
         "recommendation_key": "c", "status": "open", "updated_at": "2026-11-24T20:00:00Z",
         "thread": "igor2-88g.1620"}
        """
      // A fixture that doesn't decode is a programming error in this file, caught the first time a preview runs.
      // swiftlint:disable:next force_try
      return try! JSONDecoder().decode(ChatAsk.self, from: Data(json.utf8))
    }()

    /// The fixture threads as the Cockpit's GET /chat sends them.
    nonisolated static let listJSON: Data = {
      let rows: [[String: Any]] = [
        [
          "key": "igor2-88g.1620", "title": "Larry", "count": 42, "last_ts": "2026-11-24T21:10:00Z",
          "last_who": "larry", "last_text": "Header patch is a branch you can fetch.", "unread": 2, "pinned": true,
          "last_author": "larry",
        ],
        [
          "key": "igor2-88g.1801", "title": "How far from deploying?", "count": 9, "last_ts": "2026-11-24T16:55:00Z",
          "last_who": "agent", "last_text": "Installed on the iPad and iPhone.", "last_author": "agent",
        ],
        [
          "key": "igor2-88g.1810", "title": "Weekend plans", "count": 3, "last_ts": "2026-11-23T18:02:00Z",
          "last_who": "igor", "last_text": "Harry Potter tickets for Saturday", "looks_done": true,
          "last_author": "igor",
        ],
      ]
      return (try? JSONSerialization.data(withJSONObject: ["ok": true, "threads": rows])) ?? Data()
    }()
  }

  /// A Cockpit that lives in the preview: any request to `address` is answered in-process, so a healthy preview shows
  /// no outage and nothing leaves the machine. GET /chat gets the fixture threads; anything else gets an empty success.
  final class PreviewCockpit: URLProtocol {
    static let address = "https://preview.cockpit.invalid"
    private static let host = "preview.cockpit.invalid"
    private static let installed: Void = { URLProtocol.registerClass(PreviewCockpit.self) }()

    static func install() { _ = installed }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == host }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
      guard let url = request.url else { return }
      let body = url.path == "/chat" ? PreviewFixtures.listJSON : Data(#"{"ok": true, "threads": [], "asks": []}"#.utf8)
      let response = HTTPURLResponse(
        url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])
      if let response { client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
      client?.urlProtocol(self, didLoad: body)
      client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
  }
#endif
