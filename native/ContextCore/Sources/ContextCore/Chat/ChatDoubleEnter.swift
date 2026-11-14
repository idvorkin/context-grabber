//  Story 749: two quick Returns at the end of a chat message send it, the blank lines taken off (Igor, 2026-11-14:
//  "two enters and two enters very quickly"). The bar feeds every change of its text here; whatever wrote the change
//  (the on-screen keyboard, a hardware one, a dictation tool) looks the same, so the rule reads only the text and the
//  clock.

import Foundation

public struct ChatDoubleEnter: Sendable {
  /// How close, in milliseconds, the second Return must follow the first to send.
  public static let windowMs: Int64 = 400

  /// A send the Returns asked for: the words with their trailing blank lines and spaces taken off.
  public struct Send: Equatable, Sendable {
    public let text: String
    /// The gap between the two Returns, or nil when both new lines came in one change (a dictation tool, a paste).
    public let gapMs: Int64?
  }

  /// The last single Return at the end: when it came and how many new lines the end then held.
  private var armed: (at: Int64, newlines: Int)?
  /// Text the bar wrote itself (a quote, the chat mic's words), so its change is not read as Returns.
  private var written: String?

  public init() {}

  /// The bar is about to set its text to `text` itself: that change is not typing.
  public mutating func willWrite(_ text: String) {
    written = text
  }

  /// The text changed from `old` to `new` at `nowMs`. A send when this change is the second of two quick Returns at the
  /// end of words, or brought two new lines at the end at once; nil for anything else, an ordinary edit.
  public mutating func change(from old: String, to new: String, at nowMs: Int64) -> Send? {
    if let written {
      self.written = nil
      if written == new {
        armed = nil
        return nil
      }
    }
    let (words, newlines) = Self.split(new)
    // A change that shortens the text is a deletion, never a Return: cutting the last line of words can leave the
    // blank lines above it at the end, and that must not send the paragraph before it.
    guard !words.isEmpty, new.count >= old.count else {
      armed = nil
      return nil
    }
    let added = newlines - Self.split(old).newlines
    if added >= 2 {
      armed = nil
      return Send(text: words, gapMs: nil)
    }
    if added == 1 {
      if let armed, armed.newlines == newlines - 1, nowMs - armed.at >= 0, nowMs - armed.at <= Self.windowMs {
        self.armed = nil
        return Send(text: words, gapMs: nowMs - armed.at)
      }
      armed = (nowMs, newlines)
      return nil
    }
    armed = nil
    return nil
  }

  /// The text without its trailing whitespace, and how many new lines that trailing whitespace held.
  static func split(_ text: String) -> (words: String, newlines: Int) {
    var end = text.endIndex
    var newlines = 0
    while end > text.startIndex {
      let before = text.index(before: end)
      let character = text[before]
      guard character.isWhitespace else { break }
      if character.isNewline { newlines += 1 }
      end = before
    }
    return (String(text[..<end]), newlines)
  }
}
