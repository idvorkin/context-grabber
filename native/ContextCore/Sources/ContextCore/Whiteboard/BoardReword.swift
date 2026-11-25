//  Rewording a kept text (spec 2026-11-17-whiteboard-reword-and-live-snap-design.md, stories 940–942; the web board's
//  `rewordText` in cockpit assets/ink/board.mjs): what the edited words mean, how wide the text wraps, and where its new
//  lines go. Board points throughout. PaperKit, the field and the undo stay in the app.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif
#if canImport(CoreText)
  import CoreText
#endif

public enum BoardReword {
  /// The most a text holds: the board's paste cap, as on the web board.
  public static let maxText = BoardToText.maxText
  /// The web board's text width (`PASTE_W`): a text wraps no narrower, unless the page is.
  public static let webWidth: CGFloat = 480
  /// No text wraps narrower than this, however near the page's edge it starts (the web board's To text floor).
  public static let narrowest: CGFloat = 160
  /// Board points kept clear of the page's right edge.
  public static let air: CGFloat = 20
  /// Undo's names for the two changes.
  public static let undoName = "Edit text"
  public static let deleteName = "Delete text"

  public enum Outcome: Equatable, Sendable {
    /// The same words: no change and no undo step.
    case unchanged
    /// Emptied: the text goes.
    case delete
    /// New words, trimmed and capped.
    case reword(String)
  }

  /// Story 940 (bead context-grabber-4ief): a Return in the field is done, and the new line isn't kept. The field wraps, so
  /// Return types a line into it; this finds one in what changed since `before` and gives the words without it, or nil
  /// while the words are still being edited. Letters that arrive with the Return in one change (fast typing, a paste or
  /// dictation ending in a line, a busy device) are kept: the field read "hello" and then "hello world\n" in one step on
  /// the iPad simulator under load, and a check for a single typed character left the line in and the field open. Only
  /// a change that ends in a line is done: a paste with a line inside it keeps that line and the field stays open. The
  /// text's own line breaks, outside what changed, stay.
  public static func typedReturn(before: String, after: String) -> String? {
    let a = Array(after)
    let b = Array(before)
    var head = 0
    while head < a.count, head < b.count, a[head] == b[head] { head += 1 }
    var tail = 0
    while tail < a.count - head, tail < b.count - head, a[a.count - 1 - tail] == b[b.count - 1 - tail] { tail += 1 }
    var added = a[head..<(a.count - tail)]
    guard added.last?.isNewline == true else { return nil }
    while added.last?.isNewline == true { added.removeLast() }
    return String(a[..<head]) + String(added) + String(a[(a.count - tail)...])
  }

  /// What done with `edited` in the field means for a text that read `old`.
  public static func outcome(old: String, edited: String) -> Outcome {
    let trimmed = String(edited.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxText))
    if trimmed.isEmpty { return .delete }
    return trimmed == old.trimmingCharacters(in: .whitespacesAndNewlines) ? .unchanged : .reword(trimmed)
  }

  /// The width the words wrap to: the wider of the text's own (`box`) and the web board's, never past the page's right
  /// edge less `air`, never under `narrowest`.
  public static func width(box: CGRect, pageRight: CGFloat) -> CGFloat {
    let room = pageRight - air - box.minX
    return max(narrowest, min(max(box.width, webWidth), room))
  }

  #if canImport(CoreText)
    /// `text` as the rows it draws in: its own line breaks kept, each wrapped by word to `width` in `face` at letter
    /// height `size`, a word longer than a row broken. Empty lines between paragraphs stay; trailing ones go. Measured
    /// in `lettering`, the text's own (#950).
    public static func rows(
      _ text: String, width: CGFloat, size: CGFloat, face: WhiteboardTurn.Face,
      lettering: WhiteboardTurn.LetterStyle = .single
    ) -> [String] {
      let fits = { (s: String) in measure(s, size: size, face: face, lettering: lettering) <= width }
      var out: [String] = []
      for para in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
        var line = ""
        for var word in para.split(whereSeparator: \.isWhitespace).map(String.init) {
          while !fits(word), word.count > 1 {
            if !line.isEmpty {
              out.append(line)
              line = ""
            }
            var n = word.count - 1
            while n > 1, !fits(String(word.prefix(n))) { n -= 1 }
            out.append(String(word.prefix(n)))
            word = String(word.dropFirst(n))
          }
          if line.isEmpty {
            line = word
          } else if fits(line + " " + word) {
            line += " " + word
          } else {
            out.append(line)
            line = word
          }
        }
        out.append(line)
      }
      while out.count > 1, out.last?.isEmpty == true { out.removeLast() }
      return out
    }

    /// A row's width in `face` at letter height `size`.
    public static func measure(
      _ text: String, size: CGFloat, face: WhiteboardTurn.Face, lettering: WhiteboardTurn.LetterStyle = .single
    ) -> CGFloat {
      WhiteboardTurn.lettered(text, topLeft: .zero, height: size, face: face, lettering: lettering).width
    }

    /// Where a text's lines start, from where its letters are: the box its glyphs drew (`box`) less how far the letters
    /// of `text` sit inside their own lines, laid out as the board lays a text.
    public static func topLeft(
      of text: String, size: CGFloat, face: WhiteboardTurn.Face, box: CGRect,
      lettering: WhiteboardTurn.LetterStyle = .single
    ) -> CGPoint {
      let rows = text.split(whereSeparator: \.isNewline).map(String.init)
      let own = bounds(
        lines(rows, topLeft: .zero, size: size, face: face, lettering: lettering).flatMap {
          WhiteboardTurn.lines($0, frame: .zero, scale: 1)
        }
      )
      guard !own.isNull, !box.isNull else { return box.isNull ? .zero : box.origin }
      return CGPoint(x: box.minX - own.minX, y: box.minY - own.minY)
    }

    /// The marks that draw `rows` from `topLeft`, a row every `BoardToText.leading` letter heights, as To text lays them.
    public static func lines(
      _ rows: [String], topLeft: CGPoint, size: CGFloat, face: WhiteboardTurn.Face,
      lettering: WhiteboardTurn.LetterStyle = .single
    ) -> [WhiteboardTurn.Shape] {
      rows.enumerated().compactMap { i, row in
        guard !row.isEmpty else { return nil }
        let top = topLeft.y + CGFloat(i) * size * BoardToText.leading
        return WhiteboardTurn.Shape(
          kind: .text, points: [CGPoint(x: topLeft.x, y: top)], text: row, size: size, face: face, lettering: lettering)
      }
    }

    static func bounds(_ lines: [[CGPoint]]) -> CGRect {
      let points = lines.joined()
      guard let first = points.first else { return .null }
      return points.reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }
  #endif
}
