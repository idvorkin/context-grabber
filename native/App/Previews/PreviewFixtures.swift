//  SwiftUI previews' data (bead context-grabber-m6q, Igor 2026-11-24 "Add previews too"): fixture threads, messages,
//  an ask and the models behind them, built against ChatCockpit.nowhere so a preview never reaches the network, the
//  Cockpit or HealthKit. Debug builds only: none of this ships.

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
    /// No address: ChatModel and ChatDecisionsModel refuse every request against it, so nothing is fetched.
    static let inbox = InboxModel(log: log, database: database, cockpit: ChatCockpit.nowhere)
    static let chat: ChatModel = {
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
  }
#endif
