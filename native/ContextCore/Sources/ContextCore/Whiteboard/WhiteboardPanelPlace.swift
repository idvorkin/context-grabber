//  Where the board's open conversation sits and how big it is (#1384, stories 1278, 1279; spec
//  2026-11-12-whiteboard-conversation-design.md, *Resize, and float or dock*): docked above the board at a height Igor
//  drags, or floating over it as a card he moves and sizes. Kept as shares of the page, so a turn of the iPad keeps them.

/// The conversation's size when docked, and its card when floating.
public enum WhiteboardPanelPlace {
  /// The tallest the docked panel goes: most of the board, never all of it.
  public static let tallest = 0.7

  /// The docked panel's height on a page `page` tall: the share Igor last dragged it to (`stored`), within about four
  /// lines and `tallest`; with none, a fifth, as before (story 837).
  public static func height(stored: Double?, page: Double) -> Double {
    guard let stored, page > 0 else { return WhiteboardNote.panelHeight(board: page) }
    return min(max(stored * page, WhiteboardNote.panelFloor), page * tallest)
  }

  /// The share of the page to keep after the grip is dragged `by` points from a panel `from` points tall.
  public static func resized(from: Double, by: Double, page: Double) -> Double {
    guard page > 0 else { return 0 }
    return min(max(from + by, WhiteboardNote.panelFloor), page * tallest) / page
  }

  /// The floating card: its top left and size, as shares of the board's area.
  public struct Card: Equatable, Sendable {
    public var x, y, width, height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
      (self.x, self.y, self.width, self.height) = (x, y, width, height)
    }

    /// Where a card first floats: at the board's top left, clear of ? and Feedback at its top right, a third of it wide
    /// and a quarter tall.
    public static let start = Card(x: 0.02, y: 0.025, width: 1.0 / 3, height: 0.25)
    /// About the start's gap from the edges, in points, on a board 1000 wide and 800 tall.
    public static let margin = 20.0
    /// The smallest card that still holds a few lines and its controls.
    public static let narrowest = 280.0
    public static let shortest = 180.0

    /// The card in points, on an area `area` big: never smaller than the smallest card, and wholly on the area.
    public func frame(in area: (width: Double, height: Double)) -> (x: Double, y: Double, width: Double, height: Double)
    {
      let w = min(max(width * area.width, Self.narrowest), area.width)
      let h = min(max(height * area.height, Self.shortest), area.height)
      let left = min(max(x * area.width, 0), area.width - w)
      let top = min(max(y * area.height, 0), area.height - h)
      return (left, top, w, h)
    }

    /// The card dragged by its top edge, `dx`, `dy` points, staying on the area.
    public func moved(dx: Double, dy: Double, in area: (width: Double, height: Double)) -> Card {
      let f = frame(in: area)
      return Self.card(x: f.x + dx, y: f.y + dy, width: f.width, height: f.height, in: area)
    }

    /// The card's top-left corner dragged `dx`, `dy` points (#1491): its bottom right stays put; no smaller than the
    /// smallest card, no further than the area's top or left edge.
    public func resized(dx: Double, dy: Double, in area: (width: Double, height: Double)) -> Card {
      let f = frame(in: area)
      let (right, bottom) = (f.x + f.width, f.y + f.height)
      let w = min(max(f.width - dx, Self.narrowest), right)
      let h = min(max(f.height - dy, Self.shortest), bottom)
      return Self.card(x: right - w, y: bottom - h, width: w, height: h, in: area)
    }

    private static func card(
      x: Double, y: Double, width: Double, height: Double, in area: (width: Double, height: Double)
    ) -> Card {
      guard area.width > 0, area.height > 0 else { return .start }
      let w = min(width, area.width)
      let h = min(height, area.height)
      return Card(
        x: min(max(x, 0), area.width - w) / area.width, y: min(max(y, 0), area.height - h) / area.height,
        width: w / area.width, height: h / area.height)
    }

    /// The card as kept between boards: four shares, comma-separated.
    public var stored: String { [x, y, width, height].map { String($0) }.joined(separator: ",") }

    /// A kept card; the start when there is none or it can't be read.
    public init(stored: String) {
      let parts = stored.split(separator: ",").compactMap { Double($0) }
      guard parts.count == 4, parts.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }) else {
        self = .start
        return
      }
      self.init(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }
  }
}
