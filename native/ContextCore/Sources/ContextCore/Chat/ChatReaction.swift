//  Press and hold a message in Chat (#629, chat spec "Press and hold a message", stories 500-504): what Yes, No and
//  Quote in reply write. The Cockpit has no reactions, so a reaction is an ordinary message and a quote is its text.

import Foundation

public enum ChatReaction: String, CaseIterable, Sendable {
  case yes, no

  public var label: String { self == .yes ? "Yes" : "No" }

  /// The message a reaction sends. A bare word answers whatever was said last, so one on an older message goes under a
  /// quote of what it answers.
  public func text(answering message: ChatMessage, newest: Bool) -> String {
    newest ? label : ChatQuote.quoted(message) + "\n\n" + label
  }
}

public enum ChatQuote {
  /// The most of a message a quote carries: a long reply would otherwise fill the bar and bury the answer.
  public static let maxCharacters = 280
  /// What stands in for a message that is only a picture.
  public static let picture = "A picture"

  /// Its words with each line marked `> `; a blank line is a bare `>`, so the quote holds together.
  public static func quoted(_ message: ChatMessage) -> String {
    let words = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
    let kept =
      words.count > maxCharacters
      ? String(words.prefix(maxCharacters - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
      : words.isEmpty ? picture : words
    return kept.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
      .map { $0.isEmpty ? ">" : "> " + $0 }
      .joined(separator: "\n")
  }

  /// The bar after a quote: what it held, then the quote, then the blank line the reply starts on.
  public static func appended(_ message: ChatMessage, to draft: String) -> String {
    let held = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    return (held.isEmpty ? "" : held + "\n\n") + quoted(message) + "\n\n"
  }
}
