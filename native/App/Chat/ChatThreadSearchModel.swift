//  Searching the chat list (stories 1616-1618, #1443; spec 2026-10-25-native-chat-design.md, *Searching the threads*):
//  the words in the list's box, the Cockpit's Stream search for them once typing rests, and why it failed. The phone's
//  own matches and the merge are `ChatThreadSearch`; they need no answer, so they show at once.

import BugKit
import ContextCore
import Foundation

@MainActor
final class ChatThreadSearchModel: ObservableObject {
  /// What is in the box.
  @Published var query = ""
  /// The keys the Cockpit found for the words in the box; empty until it answers, or when it failed.
  @Published private(set) var cockpitKeys: Set<String> = []
  /// Why the Cockpit's part failed: its words and status in the copyable problem.
  @Published private(set) var problem: BugProblem?
  /// The Cockpit's part is on its way.
  @Published private(set) var searching = false

  private let log: SessionLog
  private let inbox: InboxModel
  let cockpit: String
  /// Counts the searches; an answer to an older one is dropped (each keystroke starts another).
  private var generation = 0
  private var pending: Task<Void, Never>?
  private let transport: ChatDecisions.Transport = { request in
    let (data, response) = try await URLSession.shared.data(for: request)
    return (data, (response as? HTTPURLResponse)?.statusCode)
  }

  init(log: SessionLog, inbox: InboxModel, cockpit: String) {
    self.log = log
    self.inbox = inbox
    self.cockpit = cockpit
  }

  /// The lowercased words in the box.
  var terms: [String] { ChatAskSearch.terms(query) }
  /// Words in the box: the list shows the search, not the threads.
  var active: Bool { !terms.isEmpty }

  /// The result rows for the list's threads now.
  func rows(_ threads: [ChatSummary]) -> [ChatSummary] {
    ChatThreadSearch.rows(threads, local: ChatThreadSearch.local(threads, terms: terms), cockpit: cockpitKeys)
  }

  /// The box changed: the Cockpit's search goes once typing rests. An emptied box brings the list back at once.
  func changed(_ threads: [ChatSummary]) {
    pending?.cancel()
    generation += 1
    cockpitKeys = []
    guard active else {
      problem = nil
      searching = false
      return
    }
    let ticket = generation
    let words = query
    searching = true
    pending = Task { [weak self] in
      try? await Task.sleep(for: ChatAskSearch.pause)
      guard !Task.isCancelled else { return }
      await self?.search(words, ticket: ticket, threads: threads)
    }
  }

  private func search(_ words: String, ticket: Int, threads: [ChatSummary]) async {
    let outcome: ChatThreadSearch.Outcome
    if inbox.offline {
      outcome = .failed("the phone is offline", status: nil)
    } else if cockpit == ChatCockpit.nowhere {
      outcome = .failed(ChatCockpit.noAddress, status: nil)
    } else {
      do {
        guard let request = try ChatThreadSearch.request(cockpit: cockpit, q: words) else { return }
        let (data, status) = try await transport(request)
        outcome = ChatThreadSearch.outcome(status: status, body: data)
      } catch is CancellationError {
        return
      } catch let error as URLError where error.code == .cancelled {
        return
      } catch {
        outcome = ChatThreadSearch.outcome(status: nil, body: nil, error: error.localizedDescription)
      }
    }
    guard ticket == generation else { return }
    searching = false
    var fields = ChatThreadSearch.logFields(q: words)
    fields["action"] = "thread_search"
    fields["local"] = ChatThreadSearch.local(threads, terms: ChatAskSearch.terms(words)).count
    switch outcome {
    case .found(let keys):
      cockpitKeys = keys
      problem = nil
      fields["outcome"] = "ok"
      fields["cockpit"] = keys.count
      fields["count"] =
        ChatThreadSearch.rows(
          threads, local: ChatThreadSearch.local(threads, terms: ChatAskSearch.terms(words)), cockpit: keys
        ).count
    case .failed(let why, let status):
      var extra: [String: JSONValue] = ["q": .string(words), "cockpit": .string(cockpit)]
      if let status {
        extra["status"] = .int(status)
        fields["status"] = status
      }
      problem = .grabber(ChatThreadSearch.problem(why), context: "ChatListView.search", extra: extra)
      fields["outcome"] = "failed"
      fields["reason"] = why
    }
    log.event("chat", fields)
  }

  /// A result row was tapped: which thread (never the words).
  func opened(_ key: String) {
    log.event("chat", ["action": "thread_search_open", "thread": key])
  }
}
