//  Searching the asks (story 1132, bead context-grabber-4dme; spec 2026-11-14-chat-decision-cards-design.md,
//  *Searching the asks*): the Cockpit's `GET /asks/search?q=<words>[&all=1]` (cockpit story 206), read as its Inbox's
//  own search reads it — the rows, both counts, the matched-field lines and the terms to highlight. A row is the
//  Cockpit's `/threads` row, not an `/asks` one: its title is under `root`, and it carries no options.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// One ask the search found: open (waiting on Igor, snoozed too) or answered and closed.
public struct ChatAskHit: Decodable, Equatable, Sendable, Identifiable {
  /// Where a word matched past the title: `context`, `option`, `answer`, `note` or `thread`, and about 140
  /// characters around it, with … where cut.
  public struct Match: Decodable, Equatable, Sendable {
    public let field: String
    public let snippet: String

    public init(field: String, snippet: String) {
      self.field = field
      self.snippet = snippet
    }

    /// The word before the snippet, as the Cockpit's Inbox labels it.
    public var label: String { field == "thread" ? "in thread" : field }
  }

  public let key: String
  public let title: String
  /// Waiting on Igor, snoozed included; false for an answered or closed ask.
  public let open: Bool
  /// When a snoozed ask wakes, or nil.
  public let snoozedUntil: String?
  /// At most three; empty when the words matched the title alone.
  public let matches: [Match]

  public var id: String { key }

  public init(key: String, title: String, open: Bool, snoozedUntil: String? = nil, matches: [Match] = []) {
    self.key = key
    self.title = title
    self.open = open
    self.snoozedUntil = snoozedUntil
    self.matches = matches
  }

  enum CodingKeys: String, CodingKey {
    case key, root, matches, open
    case needsIgor = "needs_igor"
  }

  struct Root: Decodable {
    let title: String?
    let snoozedUntil: String?

    enum CodingKeys: String, CodingKey {
      case title
      case snoozedUntil = "snoozed_until"
    }

    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      title = try? c.decode(String.self, forKey: .title)
      snoozedUntil = try? c.decode(String.self, forKey: .snoozedUntil)
    }
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    key = try c.decode(String.self, forKey: .key)
    let root = try? c.decode(Root.self, forKey: .root)
    title = root?.title.flatMap { $0.isEmpty ? nil : $0 } ?? key
    snoozedUntil = root?.snoozedUntil.flatMap { $0.isEmpty ? nil : $0 }
    // The Cockpit sorts open from answered by `needs_igor`; `open` stands in for a row without it.
    open = (try? c.decode(Bool.self, forKey: .needsIgor)) ?? (try? c.decode(Bool.self, forKey: .open)) ?? false
    let raw = (try? c.decode([RawMatch].self, forKey: .matches)) ?? []
    matches = raw.compactMap { m in
      guard let snippet = m.snippet, !snippet.isEmpty else { return nil }
      return Match(field: m.field ?? "", snippet: snippet)
    }
  }

  struct RawMatch: Decodable {
    let field: String?
    let snippet: String?
  }
}

/// One search's answer: the rows and the counts the line beside the box says.
public struct ChatAskSearchResult: Decodable, Equatable, Sendable {
  public let q: String
  /// The lowercased words, for highlighting.
  public let terms: [String]
  /// The open asks the Inbox has, never the result's count.
  public let inbox: Int
  /// Matching open asks, snoozed included.
  public let open: Int
  /// Matching answered or closed asks, counted whether or not they are shown.
  public let answered: Int
  /// Whether the answered ones are in `threads`.
  public let all: Bool
  public let threads: [ChatAskHit]

  public init(
    q: String, terms: [String], inbox: Int = 0, open: Int, answered: Int, all: Bool, threads: [ChatAskHit]
  ) {
    self.q = q
    self.terms = terms
    self.inbox = inbox
    self.open = open
    self.answered = answered
    self.all = all
    self.threads = threads
  }

  enum CodingKeys: String, CodingKey { case q, terms, inbox, open, answered, all, threads }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    q = (try? c.decode(String.self, forKey: .q)) ?? ""
    terms = ((try? c.decode([String].self, forKey: .terms)) ?? ChatAskSearch.terms(q)).map { $0.lowercased() }
    inbox = (try? c.decode(Int.self, forKey: .inbox)) ?? 0
    threads = try c.decode([ChatAskHit].self, forKey: .threads)
    open = (try? c.decode(Int.self, forKey: .open)) ?? threads.filter(\.open).count
    answered = (try? c.decode(Int.self, forKey: .answered)) ?? threads.filter { !$0.open }.count
    all = (try? c.decode(Bool.self, forKey: .all)) ?? false
  }

  /// The line beside the box: *0 open · 3 answered (tick to show)*, the tick's hint only while answered ones are hidden.
  public var countLine: String {
    "\(open) open · \(answered) answered" + (answered > 0 && !all ? " (tick to show)" : "")
  }

  /// What the list says with no row to show.
  public var emptyLine: String? { threads.isEmpty ? ChatAskSearch.noMatch : nil }
}

public enum ChatAskSearch {
  public static let noMatch = "No asks match."
  public static let prompt = "Search asks: title, context, options, answers"
  /// How long typing rests before a search goes.
  public static let pause: Duration = .milliseconds(300)

  /// The words a search needs, as the Cockpit splits them: on whitespace, lowercased. None means no search.
  public static func terms(_ q: String) -> [String] {
    q.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
  }

  /// Every character but the unreserved ones escaped, so `+`, `&`, `#` and `=` reach the Cockpit as typed.
  static let queryAllowed = CharacterSet(
    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

  /// `GET /asks/search?q=<words>[&all=1]`; nil for a query with no words, which never goes.
  public static func request(cockpit: String, q: String, all: Bool) throws -> URLRequest? {
    guard !terms(q).isEmpty else { return nil }
    guard URL(string: cockpit)?.host != nil else { throw URLError(.badURL) }
    let words = q.trimmingCharacters(in: .whitespacesAndNewlines)
    let escaped = words.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? words
    return try ChatWire.get(cockpit, "/asks/search?q=\(escaped)" + (all ? "&all=1" : ""))
  }

  public enum Outcome: Equatable, Sendable {
    case found(ChatAskSearchResult)
    /// Why not, with the HTTP status when there was one, for the copyable problem.
    case failed(String, status: Int?)
  }

  public static func outcome(status: Int?, body: Data?, error: String? = nil) -> Outcome {
    guard let status else { return .failed(error ?? "no answer from the Cockpit", status: nil) }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    if status == 200, json?["ok"] as? Bool == true, let body,
      let result = try? JSONDecoder().decode(ChatAskSearchResult.self, from: body)
    {
      return .found(result)
    }
    let said = (json?["error"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    if status == 200 { return .failed("an answer that is not a search: \(said ?? "unreadable")", status: status) }
    return .failed("\(said ?? "the Cockpit refused it") (HTTP \(status))", status: status)
  }

  public static func problem(_ why: String) -> String { "Could not search the asks: \(why)" }

  // MARK: Highlights

  public struct Piece: Equatable, Sendable {
    public let text: String
    public let hit: Bool

    public init(_ text: String, hit: Bool) {
      self.text = text
      self.hit = hit
    }
  }

  /// The text in runs, each term's every place marked: the earliest first, the longest where two start together, case
  /// ignored. Text whose lowercase changes its length is left unmarked rather than marked in the wrong place (the
  /// Cockpit's `AskSearch.pieces`).
  public static func pieces(_ text: String, terms: [String]) -> [Piece] {
    let words = terms.map { $0.lowercased() }.filter { !$0.isEmpty }
    let chars = Array(text)
    let low = Array(text.lowercased())
    guard !words.isEmpty, low.count == chars.count else { return [Piece(text, hit: false)] }
    let needles = words.map(Array.init)
    var out: [Piece] = []
    var i = 0
    while i < chars.count {
      var at = -1
      var len = 0
      for needle in needles {
        guard let k = find(needle, in: low, from: i) else { continue }
        if at < 0 || k < at || (k == at && needle.count > len) {
          at = k
          len = needle.count
        }
      }
      if at < 0 { break }
      if at > i { out.append(Piece(String(chars[i..<at]), hit: false)) }
      out.append(Piece(String(chars[at..<at + len]), hit: true))
      i = at + len
    }
    if i < chars.count { out.append(Piece(String(chars[i...]), hit: false)) }
    return out
  }

  private static func find(_ needle: [Character], in hay: [Character], from start: Int) -> Int? {
    guard !needle.isEmpty, hay.count - needle.count >= start else { return nil }
    for k in start...(hay.count - needle.count) where hay[k] == needle[0] {
      if Array(hay[k..<k + needle.count]) == needle { return k }
    }
    return nil
  }

  // MARK: A tap on a row

  public enum Opens: Equatable, Sendable {
    /// That chat, in the app.
    case thread(String)
    /// The ask's page on the Cockpit, for one no chat here holds.
    case web(URL)
  }

  /// An open ask on the list of open ones opens the chat it continues, where its card is; any other opens its own
  /// thread in the app when the chat list knows it, or else its page on the Cockpit, as an Inbox link does.
  public static func opens(_ hit: ChatAskHit, asks: [ChatAsk], known: Set<String>) -> Opens {
    if let ask = asks.first(where: { $0.id == hit.key }) { return .thread(ask.chatToOpen) }
    if known.contains(hit.key) { return .thread(hit.key) }
    return ChatCockpitLink.webURL(hit.key).map(Opens.web) ?? .thread(hit.key)
  }

  /// The `chat` event's fields for a search: how many words and characters, never the words.
  public static func logFields(q: String, all: Bool) -> [String: Any] {
    ["terms": terms(q).count, "q_chars": q.count, "all": all]
  }
}
