//  Seven-segment glyphs and their geometry for the Gym Timer's LED display (story 108).
//
//  Segments are named the classic way:
//
//       a
//     f   b
//       g
//     e   c
//       d
//
//  A glyph is the set of lit segments. Letters are the spellings a gym clock would use (rESt, rEAdY, donE, GO);
//  anything not in the table is blank. `:` and `.` are not glyphs — the display draws them as dots.

import Foundation

public enum Segment: Character, CaseIterable, Sendable {
  case a = "a", b = "b", c = "c", d = "d", e = "e", f = "f", g = "g"
}

public enum SevenSegment {
  private static let lit: [Character: String] = [
    "0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg", "5": "acdfg", "6": "acdefg", "7": "abc",
    "8": "abcdefg", "9": "abcdfg",
    "A": "abcefg", "b": "cdefg", "C": "adef", "c": "deg", "d": "bcdeg", "E": "adefg", "F": "aefg", "G": "acdef",
    "H": "bcefg", "h": "cefg", "I": "bc", "J": "bcd", "L": "def", "n": "ceg", "O": "abcdef", "o": "cdeg",
    "P": "abefg", "r": "eg", "S": "acdfg", "t": "defg", "U": "bcdef", "u": "cde", "Y": "bcdfg", "-": "g", " ": "",
  ]
  private static let glyphs: [Character: Set<Segment>] = lit.mapValues { Set($0.compactMap(Segment.init)) }

  /// The lit segments for one character; blank for anything the display cannot spell.
  public static func segments(for ch: Character) -> Set<Segment> { glyphs[ch] ?? [] }

  /// True for the characters drawn as dots between digits rather than as segments.
  public static func isSeparator(_ ch: Character) -> Bool { ch == ":" || ch == "." }

  /// What a seven-segment display makes of a phase.
  public static func phaseWord(_ phase: TimerPhase) -> String {
    switch phase {
    case .prep: return "rEAdY"
    case .work: return "GO"
    case .rest: return "rESt"
    case .done: return "donE"
    case .idle: return ""
    }
  }

  /// What the display says when stopped mid-way (story 103).
  public static let pausedWord = "PAUSEd"
}

public struct LedRect: Equatable, Sendable {
  public var x, y, width, height: Double
}

/// Where everything sits, sized from the display's height: a digit is 0.55 × height wide, a bar 0.11 × height thick.
public enum LedLayout {
  public static let digitWidth = 0.55
  public static let bar = 0.11
  public static let gap = 0.13
  public static let separatorWidth = 0.18

  public static func charWidth(_ ch: Character, height: Double) -> Double {
    (SevenSegment.isSeparator(ch) ? separatorWidth : digitWidth) * height
  }

  public static func width(of text: String, height: Double) -> Double {
    guard !text.isEmpty else { return 0 }
    return text.reduce(0) { $0 + charWidth($1, height: height) } + Double(text.count - 1) * gap * height
  }

  /// The tallest whole height at which the string fits in `width`, never above `maxHeight`.
  public static func heightToFit(_ text: String, width: Double, maxHeight: Double) -> Double {
    let atOne = self.width(of: text, height: 1)
    return atOne > 0 ? max(0, min(maxHeight, width / atOne).rounded(.down)) : 0
  }

  /// Each bar's frame inside a digit of that height. Bars stop short of the corners so they read as separate LEDs.
  public static func segmentRects(height h: Double) -> [Segment: LedRect] {
    let w = digitWidth * h
    let t = bar * h
    let inset = t * 0.55
    let vHeight = h / 2 - inset - t / 2
    func horizontal(_ y: Double) -> LedRect { LedRect(x: inset, y: y, width: w - 2 * inset, height: t) }
    func vertical(_ x: Double, _ y: Double) -> LedRect { LedRect(x: x, y: y, width: t, height: vHeight) }
    return [
      .a: horizontal(0), .g: horizontal((h - t) / 2), .d: horizontal(h - t),
      .f: vertical(0, inset + t / 2), .b: vertical(w - t, inset + t / 2),
      .e: vertical(0, h / 2 + t / 2), .c: vertical(w - t, h / 2 + t / 2),
    ]
  }

  /// The dots of a separator inside its own box: two for a colon, one on the baseline for a point.
  public static func separatorDots(_ ch: Character, height h: Double) -> [LedRect] {
    let t = bar * h
    let x = (separatorWidth * h - t) / 2
    let tops = ch == ":" ? [h * 0.3 - t / 2, h * 0.7 - t / 2] : [h - t]
    return tops.map { LedRect(x: x, y: $0, width: t, height: t) }
  }
}
