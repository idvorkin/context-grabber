//  A long label of Larry's wraps to the right edge of the picture he was sent (story 1348, #1526; spec
//  2026-11-01-whiteboard-shapes-design.md, "A long label wraps to the picture's width"). The breaking is plain text
//  over a measure, so it runs anywhere; the measure is the letters' widths, none on Linux, where nothing wraps.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension WhiteboardTurn {
  /// How far inside the picture's right edge a wrapped label stops, in board points.
  public static let labelMargin: CGFloat = 12

  /// A wrapped label's line pitch, as a share of its letters' height: the Cockpit's TEXT_LINE (board/strokes.py), so the
  /// server's placer and the board agree.
  public static let labelLinePitch: CGFloat = 1.2

  /// The fewest letter heights of room a row gets, so a label placed at the edge still holds a few words to a line.
  static let labelLeastRoom: CGFloat = 6

  /// `text` broken into rows that each measure at most `room`: between words, at a newline, and inside a word only
  /// when the word alone is longer than the room. No room (zero or less) is no wrap.
  static func wrap(_ text: String, room: CGFloat, measure: (String) -> CGFloat) -> [String] {
    guard room > 0 else { return [text] }
    var rows: [String] = []
    for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
      var line = ""
      for word in paragraph.split(separator: " ") {
        var rest = String(word)
        let joined = line.isEmpty ? rest : line + " " + rest
        if measure(joined) <= room {
          line = joined
          continue
        }
        if !line.isEmpty {
          rows.append(line)
          line = ""
        }
        while rest.count > 1, measure(rest) > room {
          var n = 1
          while n < rest.count, measure(String(rest.prefix(n + 1))) <= room { n += 1 }
          rows.append(String(rest.prefix(n)))
          rest = String(rest.dropFirst(n))
        }
        line = rest
      }
      rows.append(line)
    }
    return rows
  }

  /// One row of a wrapped label: its text and its top-left on the board.
  public struct LabelRow: Equatable {
    public var text: String
    public var x: CGFloat
    public var y: CGFloat
  }

  /// A label's rows on the board. With a picture (`frame` not empty), a label that would cross its right edge less
  /// `labelMargin` goes on to further rows, each `labelLinePitch` letter heights below the last; a label that fits,
  /// or one with no picture behind it, is one row of its text as written.
  static func wrappedRows(
    _ shape: Shape, frame: CGRect, scale: CGFloat, lettering: LetterStyle = .single
  ) -> [LabelRow] {
    guard let first = shape.points.first else { return [] }
    let at = CGPoint(x: frame.minX + first.x / scale, y: frame.minY + first.y / scale)
    let size = (shape.size ?? 28) / scale
    let height = textHeight(shape, scale: scale)
    let top = CGPoint(x: at.x, y: at.y + ascent(shape.face) * (size - height))
    let text = shape.text ?? ""
    let whole = [LabelRow(text: text, x: top.x, y: top.y)]
    guard frame.width > 0 else { return whole }
    let style = shape.lettering ?? lettering
    let room = max(frame.maxX - labelMargin - top.x, height * labelLeastRoom)
    let rows = wrap(text, room: room) {
      lettered($0, topLeft: .zero, height: height, face: shape.face, lettering: style).width
    }
    guard rows.count > 1 else { return whole }
    return rows.enumerated().map { i, row in
      LabelRow(text: row, x: top.x, y: top.y + CGFloat(i) * height * labelLinePitch)
    }
  }
}
