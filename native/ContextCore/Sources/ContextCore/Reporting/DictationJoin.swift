//  #249: speaking the note after a pause must add to it, not replace it. iOS's recogniser can start a fresh
//  transcription after a pause (on-device recognition does), and each result then holds only the new stretch of
//  speech. This keeps what was said before: the note is what was typed, then every finished stretch, then the one
//  being heard. Pure, so the host tests can hold it.

import Foundation

public struct DictationJoin: Equatable, Sendable {
  /// What was typed when listening began, then every finished stretch of speech.
  public private(set) var kept: String
  /// The stretch being heard now, as the recogniser last gave it.
  public private(set) var current = ""
  private var currentStart: Double?
  /// When the stretch being heard last ended, in seconds from the start of listening.
  public private(set) var currentEnd: Double = 0

  public init(typed: String) { kept = typed.trimmingCharacters(in: .whitespacesAndNewlines) }

  /// The whole note so far.
  public var note: String { Self.join(kept, current) }

  /// One result from the recogniser: its text and when its first and last words were spoken, in seconds from the
  /// start of listening. Returns true when it began a new stretch (the one before it was kept).
  @discardableResult
  public mutating func update(text: String, firstStart: Double, lastEnd: Double) -> Bool {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    var fresh = false
    if let start = currentStart, !current.isEmpty, !text.isEmpty {
      // A result that starts after the last one ended is new speech; so is a shorter one that no longer begins
      // with the same word (the recogniser revises a stretch's words, it does not drop its start).
      let after = firstStart >= currentEnd - 0.05 && firstStart > start
      let restarted = text.count < current.count && Self.firstWord(text) != Self.firstWord(current)
      fresh = after || restarted
    }
    if fresh { kept = Self.join(kept, current) }
    current = text
    currentStart = firstStart
    currentEnd = lastEnd
    return fresh
  }

  private static func join(_ a: String, _ b: String) -> String {
    a.isEmpty ? b : b.isEmpty ? a : "\(a) \(b)"
  }

  private static func firstWord(_ s: String) -> Substring {
    s.split(separator: " ").first.map { $0.lowercased()[...] } ?? ""
  }
}
