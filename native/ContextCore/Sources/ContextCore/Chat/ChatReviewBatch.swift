//  A blog-review batch in a message (spec 2026-10-25-native-chat-design.md, A blog-review batch in a message; story
//  748). The blog's annotate tool exports a page's notes as one JSON object; a message that is exactly that object
//  reads as one card, a header chip and a chip per note, instead of the JSON. The Cockpit's web chat reads it as a
//  card with the same labels (`reviewBatch` in the Cockpit's cockpit_core.js, rule on bead cockpit-3uc); a change to
//  what is a batch or to a label goes in both. The page link here is the batch's `url` alone.

import Foundation

public struct ChatReviewBatch: Equatable, Sendable {
  /// The header chip's words: the page's title, else its permalink, else its address; one line, cut at 60.
  public let title: String
  /// The page the header chip opens: the batch's `url` when it is http(s) with a host, else nil.
  public let page: URL?
  /// "1 note", "3 notes".
  public let count: String
  /// At least one, in the batch's order.
  public let notes: [Note]

  public struct Note: Equatable, Sendable {
    /// One of the tool's seven intents; *note* for anything else.
    public let intent: String
    /// The folded chip after its intent: the comment on one line, or the quote in curly quotes when it has none.
    public let text: String
    /// The folded chip: "fix · Say it once."
    public var label: String { "\(intent) · \(text)" }
    /// The words before the quote, "…" first; empty when there are none.
    public let before: String
    /// The quoted passage on one line.
    public let quote: String
    /// The words after the quote, "…" last; empty when there are none.
    public let after: String
    /// The whole comment, its line breaks kept, its ends trimmed.
    public let comment: String
  }

  public static let intents = ["fix", "cut", "rewrite", "expand", "check", "question", "note"]
  public static let defaultIntent = "note"
  /// Characters in a folded chip's text, and in the header's title.
  public static let labelLimit = 60
  public static let titleLimit = 60
  /// Characters of context shown either side of a quote: the tool's own.
  public static let contextLength = 30

  /// `text` as a batch when the whole of it, blank space aside, is one JSON object with a non-empty string
  /// `permalink` or `url`, and `annotations` a non-empty array whose every item has a string `quote` and `comment`.
  /// Anything else is nil and reads as written: words around the object, a code fence, broken JSON, other JSON.
  public static func parse(_ text: String) -> ChatReviewBatch? {
    let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard body.hasPrefix("{"), body.hasSuffix("}"), let data = body.data(using: .utf8),
      let wire = try? JSONDecoder().decode(Wire.self, from: data)
    else { return nil }
    let permalink = wire.permalink.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    let url = wire.url.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    guard permalink != nil || url != nil, !wire.annotations.isEmpty else { return nil }
    let title = [wire.title, permalink, url].lazy.compactMap { $0.map(squash) }.first { !$0.isEmpty } ?? ""
    let count = wire.annotations.count
    return ChatReviewBatch(
      title: clip(title, titleLimit), page: httpURL(url), count: count == 1 ? "1 note" : "\(count) notes",
      notes: wire.annotations.map(note))
  }

  private static func note(_ wire: WireNote) -> Note {
    let raw = (wire.intent ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let comment = squash(wire.comment)
    let quote = squash(wire.quote)
    // The text either side: runs of blank space as one space, the space against the quote kept; "…" only on a side
    // that has words.
    let before = oneSpaced(wire.prefix ?? "")
    let after = oneSpaced(wire.suffix ?? "")
    return Note(
      intent: intents.contains(raw) ? raw : defaultIntent,
      text: comment.isEmpty ? "“" + clip(quote, labelLimit - 2) + "”" : clip(comment, labelLimit),
      before: before.allSatisfy(\.isWhitespace) ? "" : "…" + String(before.suffix(contextLength)),
      quote: quote,
      after: after.allSatisfy(\.isWhitespace) ? "" : String(after.prefix(contextLength)) + "…",
      comment: wire.comment.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  /// Every run of blank space as one space, line breaks included.
  static func oneSpaced(_ text: String) -> String {
    var out = ""
    var inRun = false
    for character in text {
      if character.isWhitespace {
        if !inRun { out.append(" ") }
        inRun = true
      } else {
        out.append(character)
        inRun = false
      }
    }
    return out
  }

  static func squash(_ text: String) -> String { oneSpaced(text).trimmingCharacters(in: .whitespaces) }

  /// `text` when it is at most `limit` characters; else its first `limit - 1`, with no space left hanging, and "…".
  static func clip(_ text: String, _ limit: Int) -> String {
    guard text.count > limit else { return text }
    return String(String(text.prefix(limit - 1)).trimmingSuffix(" ")) + "…"
  }

  private static func httpURL(_ text: String?) -> URL? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), let url = URL(string: trimmed),
      let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http", url.host?.isEmpty == false
    else { return nil }
    return url
  }

  /// The tool's JSON. Only a note's `quote` and `comment` must be strings; every other field is read when it is a
  /// string and treated as absent when it is missing or another type, so one odd field never decides on its own.
  private struct Wire: Decodable {
    let permalink: String?
    let url: String?
    let title: String?
    let annotations: [WireNote]

    enum CodingKeys: String, CodingKey { case permalink, url, title, annotations }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      permalink = Wire.optional(container, .permalink)
      url = Wire.optional(container, .url)
      title = Wire.optional(container, .title)
      annotations = try container.decode([WireNote].self, forKey: .annotations)
    }

    static func optional<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> String? {
      (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil
    }
  }

  private struct WireNote: Decodable {
    let quote: String
    let comment: String
    let intent: String?
    let prefix: String?
    let suffix: String?

    enum CodingKeys: String, CodingKey { case quote, comment, intent, prefix, suffix }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      quote = try container.decode(String.self, forKey: .quote)
      comment = try container.decode(String.self, forKey: .comment)
      intent = Wire.optional(container, .intent)
      prefix = Wire.optional(container, .prefix)
      suffix = Wire.optional(container, .suffix)
    }
  }
}

extension StringProtocol {
  /// Without any run of `character` at its end.
  fileprivate func trimmingSuffix(_ character: Character) -> SubSequence {
    var end = endIndex
    while end > startIndex, self[index(before: end)] == character { end = index(before: end) }
    return self[startIndex..<end]
  }
}
