//  Story 650 (context-grabber-ikya, context-grabber-qko5): whether a kept mark looks whole on screen a second after the
//  keep, from the colours a picture of its spot holds, and how the board draws it again when it doesn't.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

/// What a picture of a kept mark's spot holds, sorted against the paper: pixels near the ink's colour, near black, the
/// rest, and how wide and tall the ink's colour and every pixel unlike the paper span, in pixels.
public struct KeptInkColours: Equatable, Sendable {
  public var ink = 0
  public var dark = 0
  public var other = 0
  public var inkWidth = 0
  public var inkHeight = 0
  /// Every pixel unlike the paper, whatever its colour: how wide and tall the strokes span, soft edges included.
  public var allWidth = 0
  public var allHeight = 0
  public static let unread = KeptInkColours(ink: -1, dark: -1, other: -1)

  public init(
    ink: Int = 0, dark: Int = 0, other: Int = 0, inkWidth: Int = 0, inkHeight: Int = 0, allWidth: Int = 0,
    allHeight: Int = 0
  ) {
    self.ink = ink
    self.dark = dark
    self.other = other
    self.inkWidth = inkWidth
    self.inkHeight = inkHeight
    self.allWidth = allWidth
    self.allHeight = allHeight
  }
}

public enum WhiteboardKeptInk {
  /// A picture's pixels unlike the paper, sorted: near `ink`, near black, the rest; and the spans. `rgba`: `width` x
  /// `height` pixels, 4 bytes each, premultiplied. A transparent pixel is no colour at all and is skipped (pbvt: a view
  /// drawn alone leaves the rest of its picture transparent, and counted as black every layer read wholly dark).
  public static func sort(rgba: [UInt8], width w: Int, height h: Int, paper: [Int], ink: [Int]) -> KeptInkColours {
    var out = KeptInkColours()
    var inkX = (w, -1)
    var inkY = (h, -1)
    var allX = (w, -1)
    var allY = (h, -1)
    for y in 0..<h {
      for x in 0..<w {
        let i = (y * w + x) * 4
        guard i + 3 < rgba.count, rgba[i + 3] >= 8 else { continue }
        let px = [Int(rgba[i]), Int(rgba[i + 1]), Int(rgba[i + 2])]
        guard (0..<3).contains(where: { abs(px[$0] - paper[$0]) > 40 }) else { continue }
        allX = (min(allX.0, x), max(allX.1, x))
        allY = (min(allY.0, y), max(allY.1, y))
        if (0..<3).allSatisfy({ abs(px[$0] - ink[$0]) <= 50 }) {
          out.ink += 1
          inkX = (min(inkX.0, x), max(inkX.1, x))
          inkY = (min(inkY.0, y), max(inkY.1, y))
        } else if px.allSatisfy({ $0 < 80 }) {
          out.dark += 1
        } else {
          out.other += 1
        }
      }
    }
    out.inkWidth = max(inkX.1 - inkX.0 + 1, 0)
    out.inkHeight = max(inkY.1 - inkY.0 + 1, 0)
    out.allWidth = max(allX.1 - allX.0 + 1, 0)
    out.allHeight = max(allY.1 - allY.0 + 1, 0)
    return out
  }

  /// The soft edge, in view pixels, a whole mark's own colour falls short of every pixel its strokes touch: in the logs
  /// the view's colour spans 2 to 4 pixels less than the strokes drawn alone touch, each way (context-grabber-smmj).
  public static let softEdge = 4

  /// How wide and tall a whole mark's own colour spans on screen, judged from the same strokes drawn alone: their own
  /// colour's span, or every pixel they touch less the soft edge, whichever is more. Drawn alone, a thin text keeps
  /// little of its true colour and that span is noise (context-grabber-smmj: 71 one time and 149 the next for one
  /// 155-pixel text), while every pixel it touches spans the same each time (157); a thick mark's colour spans as far as
  /// it touches, so it's judged as before.
  public static func wholeSpan(_ expected: KeptInkColours) -> (width: Int, height: Int) {
    (
      max(expected.inkWidth, expected.allWidth - softEdge),
      max(expected.inkHeight, expected.allHeight - softEdge)
    )
  }

  /// Why a kept mark looks only partly drawn, or nil when it looks whole. **cut** when the view's ink colour spans under
  /// three quarters of what a whole mark's colour spans (`wholeSpan`, logged as `whole_span`: a tile left empty or drawn in another colour).
  /// Like is measured with like: a thin letter's true colour is only its middle, so against every pixel the strokes touch,
  /// soft edges and all, a small label drawn whole read as cut (context-grabber-qko5: 9 of 13 pixels tall), and against
  /// only the true colour the strokes keep drawn alone, a thin text cut at a tile edge could read as whole
  /// (context-grabber-smmj). **dark** when the spot has dark pixels the keep added and the ink isn't dark itself (a tile
  /// drawn black). Nothing is judged when the strokes drawn alone show none of their colour (a pen too thin to read).
  public static func partMissing(
    drawn: KeptInkColours, expected: KeptInkColours, darkBefore: Int, ink: [Int]
  ) -> String? {
    guard drawn.ink >= 0, expected.ink > 0, expected.inkWidth > 0, expected.inkHeight > 0 else { return nil }
    let whole = wholeSpan(expected)
    if drawn.inkWidth * 4 < whole.width * 3 || drawn.inkHeight * 4 < whole.height * 3 { return "cut" }
    let inkIsDark = ink.allSatisfy { $0 < 80 }
    if !inkIsDark, drawn.dark - darkBefore > max(20, drawn.ink / 10) { return "dark" }
    return nil
  }

  /// Nothing of a kept mark on screen, not even a faint pixel, and none of its colour when its strokes are drawn alone.
  public static func drewNothing(drawn: KeptInkColours, expected: KeptInkColours) -> Bool {
    drawn.ink == 0 && drawn.dark == 0 && drawn.other == 0 && expected.ink <= 0
  }

  /// How a mark found partly drawn at look `attempt` is drawn again: in place first (taken out of the markup and put
  /// back, a blink), and only if that look still finds it partly drawn, the view a screen away and back; none after two.
  public static func heal(afterLook attempt: Int) -> String? {
    switch attempt {
    case 0: "readd"
    case 1: "scroll"
    default: nil
    }
  }
}
