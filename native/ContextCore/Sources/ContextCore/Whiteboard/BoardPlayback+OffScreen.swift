//  Story 948 (#1169): in playback, where the stroke being drawn is when it is off the screen, above or below, and on
//  which page, so a label can say *Writing above, page 1*. Platform-free and host-tested.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension BoardPlayback {
  /// The stroke being drawn at `t`, or the one drawn last: its place in the drawing; nil before the first begins.
  public func latest(at t: TimeInterval) -> Int? {
    let k = begun(at: t)
    return k > 0 ? entries[k - 1].index : nil
  }

  /// Where ink off the screen is, and on which page.
  public enum OffScreen: Equatable, Sendable {
    case above(page: Int)
    case below(page: Int)

    public var page: Int {
      switch self {
      case .above(let page), .below(let page): page
      }
    }

    /// *Writing above, page 1*.
    public var text: String {
      switch self {
      case .above(let page): "Writing above, page \(page)"
      case .below(let page): "Writing below, page \(page)"
      }
    }
  }

  /// Ink wholly above or wholly below `visible` (board points), with the page its middle is on; nil when any of it is
  /// on the screen, or for no ink. Only above and below: the board is a column of pages, panned up and down.
  public static func offScreen(ink: CGRect, visible: CGRect, pages: BoardPages) -> OffScreen? {
    guard !ink.isNull, !ink.isInfinite, !visible.isNull, visible.height > 0 else { return nil }
    let page = pages.page(at: CGPoint(x: ink.midX, y: ink.midY))
    if ink.maxY <= visible.minY { return .above(page: page) }
    if ink.minY >= visible.maxY { return .below(page: page) }
    return nil
  }
}
