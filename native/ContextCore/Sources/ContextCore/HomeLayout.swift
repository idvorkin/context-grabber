//  The home screen's launchers in Igor's order, some hidden (story 147). Stored as two comma-joined id lists in
//  the settings table; read against the ids this build has, so a new row shows at the end and a gone one is dropped.

import Foundation

public struct HomeLayout: Equatable, Sendable {
  public static let orderKey = "home_row_order"
  public static let hiddenKey = "home_rows_hidden"

  /// Every row this build has, in display order, hidden ones included (the sheet lists them all).
  public private(set) var order: [String]
  public private(set) var hidden: Set<String>

  /// The remembered order and hidden lists over `known` (the build's rows, in their default order). Unknown
  /// remembered ids are dropped; known ids the order does not name follow, in their default order, shown.
  public init(known: [String], storedOrder: String?, storedHidden: String?) {
    let knownSet = Set(known)
    var seen = Set<String>()
    var order: [String] = []
    for id in Self.decode(storedOrder) where knownSet.contains(id) && seen.insert(id).inserted {
      order.append(id)
    }
    order += known.filter { !seen.contains($0) }
    self.order = order
    hidden = Set(Self.decode(storedHidden)).intersection(knownSet)
  }

  /// The rows on the home screen.
  public var visible: [String] { order.filter { !hidden.contains($0) } }

  public func isShown(_ id: String) -> Bool { !hidden.contains(id) }

  public mutating func setShown(_ id: String, _ shown: Bool) {
    guard order.contains(id) else { return }
    if shown { hidden.remove(id) } else { hidden.insert(id) }
  }

  /// List-style move: the rows at `offsets` land before the row that was at `destination`.
  public mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
    let moving = offsets.filter { $0 < order.count }.map { order[$0] }
    let before = order.indices.filter { $0 < destination && !offsets.contains($0) }.count
    var rest = order.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
    rest.insert(contentsOf: moving, at: min(before, rest.count))
    order = rest
  }

  public var encodedOrder: String { order.joined(separator: ",") }
  /// Hidden ids in display order, so the stored value and the log read the same way each time.
  public var encodedHidden: String { order.filter(hidden.contains).joined(separator: ",") }

  private static func decode(_ value: String?) -> [String] {
    (value ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
  }

  /// Story 151: what the home screen draws from the visible launchers. Today becomes the card (when it is shown),
  /// the next four are tiles, the rest rows, all in Igor's order.
  public struct Arrangement: Equatable, Sendable {
    public var todayCard: Bool
    public var tiles: [String]
    public var rows: [String]
  }

  public static let tileCount = 4

  public var arrangement: Arrangement {
    let rest = visible.filter { $0 != "today" }
    return Arrangement(
      todayCard: visible.contains("today"), tiles: Array(rest.prefix(Self.tileCount)),
      rows: Array(rest.dropFirst(Self.tileCount)))
  }

  /// #225: launchers that share one line of rows, half each, when both are rows.
  public static let pairs: [(String, String)] = [("exercise_analyzer", "workout_supermix"), ("eulogy", "eulogy_song")]

  /// The rows as lines: a pair is one line where its first member comes in the order, the rest one each.
  public static func lines(_ rows: [String]) -> [[String]] {
    var partner: [String: String] = [:]
    for (a, b) in pairs where rows.contains(a) && rows.contains(b) {
      partner[a] = b
      partner[b] = a
    }
    var placed = Set<String>()
    var lines: [[String]] = []
    for id in rows where !placed.contains(id) {
      placed.insert(id)
      if let other = partner[id] {
        placed.insert(other)
        // The pair's own order, wherever in Igor's order it lands.
        lines.append(pairs.contains { $0.0 == id } ? [id, other] : [other, id])
      } else {
        lines.append([id])
      }
    }
    return lines
  }
}
