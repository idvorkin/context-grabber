//  Story 1335 (bead context-grabber-lyr4): what's on a real board that the board won't keep. The board saves its ink
//  and nothing else, so anything on the page that isn't a stroke would be gone when the board reopens. When the page's
//  element count and its tally of strokes disagree, this names why, by kind: a PaperKit element that isn't ink (shape,
//  image, link, loupe), or two strokes sharing one id (which the tally counts once).

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardMarkupCensus: Equatable, Sendable {
  /// The kind logged for two strokes that share one id.
  public static let duplicateStroke = "duplicate_stroke"

  /// What the board wouldn't keep, by kind, and how many of each.
  public let kinds: [String: Int]

  /// - Parameters:
  ///   - strokes: every stroke on the page, a repeated id counted each time.
  ///   - uniqueStrokes: the strokes by id, as the board tallies them.
  ///   - otherKinds: the kind of each element that isn't a stroke.
  public init(strokes: Int, uniqueStrokes: Int, otherKinds: [String]) {
    var kinds: [String: Int] = [:]
    for kind in otherKinds { kinds[kind, default: 0] += 1 }
    if strokes > uniqueStrokes { kinds[Self.duplicateStroke] = strokes - uniqueStrokes }
    self.kinds = kinds
  }

  /// Nothing on the page the board wouldn't keep.
  public var isInkOnly: Bool { kinds.isEmpty }

  /// The kinds there are more of now than in `earlier` (all of them with none before), sorted.
  public func added(since earlier: BoardMarkupCensus?) -> [String] {
    kinds.filter { $0.value > (earlier?.kinds[$0.key] ?? 0) }.keys.sorted()
  }

  /// As the session log shows it: `image:1,shape:2`, sorted by kind; empty when ink only.
  public var text: String {
    kinds.keys.sorted().map { "\($0):\(kinds[$0] ?? 0)" }.joined(separator: ",")
  }
}
