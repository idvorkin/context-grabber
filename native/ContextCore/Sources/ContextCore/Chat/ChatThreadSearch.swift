//  Searching the chat list (stories 1616-1618, #1443; spec 2026-10-25-native-chat-design.md, *Searching the threads*):
//  the threads the phone matches itself on their title and newest message, joined by the Cockpit's chat search
//  (`GET /chat?q=<words>`, cockpit story 335: GET /chat's rows, kept when every word is in the title or any message's
//  text). Only threads on the chat list show; the words split as `ChatAskSearch.terms` splits them.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum ChatThreadSearch {
  public static let noMatch = "No chats match."
  public static let prompt = "Search chats"

  /// The threads whose title or newest message holds every term (terms already lowercased), in list order.
  public static func local(_ threads: [ChatSummary], terms: [String]) -> [String] {
    guard !terms.isEmpty else { return [] }
    return threads.filter { t in
      let hay = (t.title + "\n" + t.lastText).lowercased()
      return terms.allSatisfy { hay.contains($0) }
    }
    .map(\.key)
  }

  /// The result rows: the list's threads the phone or the Cockpit matched, live ones first, then done and archived,
  /// each part in the list's own order. A Cockpit hit that is not a chat here is left out.
  public static func rows(_ threads: [ChatSummary], local: [String], cockpit: Set<String>) -> [ChatSummary] {
    let hit = Set(local).union(cockpit)
    let found = threads.filter { hit.contains($0.key) }
    return found.filter { !$0.done } + found.filter(\.done)
  }

  /// `GET /chat?q=<words>`, archived and done threads included; nil for a query with no words.
  public static func request(cockpit: String, q: String) throws -> URLRequest? {
    guard !ChatAskSearch.terms(q).isEmpty else { return nil }
    guard URL(string: cockpit)?.host != nil else { throw URLError(.badURL) }
    let words = q.trimmingCharacters(in: .whitespacesAndNewlines)
    let escaped = words.addingPercentEncoding(withAllowedCharacters: ChatAskSearch.queryAllowed) ?? words
    return try ChatWire.get(cockpit, "/chat?q=\(escaped)")
  }

  public enum Outcome: Equatable, Sendable {
    /// The keys of the threads the Cockpit found.
    case found(Set<String>)
    /// Why not, with the HTTP status when there was one, for the copyable problem.
    case failed(String, status: Int?)
  }

  public static func outcome(status: Int?, body: Data?, error: String? = nil) -> Outcome {
    guard let status else { return .failed(error ?? "no answer from the Cockpit", status: nil) }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    if status == 200, json?["ok"] as? Bool == true, let rows = json?["threads"] as? [[String: Any]] {
      return .found(Set(rows.compactMap { $0["key"] as? String }))
    }
    let said = (json?["error"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    if status == 200 { return .failed("an answer that is not a search: \(said ?? "unreadable")", status: status) }
    return .failed("\(said ?? "the Cockpit refused it") (HTTP \(status))", status: status)
  }

  public static func problem(_ why: String) -> String {
    "Could not search the Cockpit for chats, so these are only the phone's own matches: \(why)"
  }

  /// The `chat` event's fields for a search: how many words and characters, never the words.
  public static func logFields(q: String) -> [String: Any] {
    ["terms": ChatAskSearch.terms(q).count, "q_chars": q.count]
  }
}
