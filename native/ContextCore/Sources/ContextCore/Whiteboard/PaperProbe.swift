//  What a board on paper logs about a touch (whiteboard spec's "On paper: the default", stories 437, 439, 529, 532–534):
//  which ink a change moved, what came of a touch, and whether a finger tapped. PaperKit stays in the app. The trial on
//  paper that this began with is gone (2026-11-07); the real page geometry is `BoardPages`.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum PaperProbe {
  public struct InkMove: Equatable, Sendable {
    public var id: String
    public var dx: CGFloat
    public var dy: CGFloat
    /// It changed size too.
    public var resized: Bool

    public init(id: String, dx: CGFloat, dy: CGFloat, resized: Bool) {
      self.id = id
      self.dx = dx
      self.dy = dy
      self.resized = resized
    }
  }

  public struct InkChange: Equatable, Sendable {
    public var added: [String] = []
    public var removed: [String] = []
    public var moved: [InkMove] = []
    public var isEmpty: Bool { added.isEmpty && removed.isEmpty && moved.isEmpty }
  }

  /// What a change did to the ink, by each element's id and frame. Sorted by id, so the same change logs the same.
  public static func inkChange(before: [String: CGRect], after: [String: CGRect]) -> InkChange {
    var change = InkChange()
    change.added = after.keys.filter { before[$0] == nil }.sorted()
    change.removed = before.keys.filter { after[$0] == nil }.sorted()
    change.moved = after.keys.sorted().compactMap { id in
      guard let old = before[id], let new = after[id], !close(old, new) else { return nil }
      return InkMove(
        id: id, dx: new.minX - old.minX, dy: new.minY - old.minY,
        resized: abs(new.width - old.width) > tolerance || abs(new.height - old.height) > tolerance)
    }
    return change
  }

  private static let tolerance: CGFloat = 0.01

  private static func close(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance && abs(a.width - b.width) <= tolerance
      && abs(a.height - b.height) <= tolerance
  }

  /// What one touch, from its first finger down to its last up, is seen to have done.
  public struct TouchFacts: Equatable, Sendable {
    public var seconds: Double = 0
    /// The furthest a touch went from where it started, in screen points.
    public var travel: CGFloat = 0
    public var fingers: Int = 1
    /// The view moved, in board points.
    public var scrolled: CGFloat = 0
    public var zoomChanged: Bool = false
    public var selectionChanges: Int = 0
    public var inkAdded: Int = 0
    public var inkRemoved: Int = 0
    public var inkMoved: Int = 0
    public var beganDrawing: Bool = false

    public init() {}
  }

  /// A tap is short and stays put; the rest is whatever was seen, in a fixed order, or `nothing`.
  public static func outcome(_ facts: TouchFacts) -> [String] {
    var seen: [String] = []
    if facts.scrolled > 0.5 { seen.append("panned") }
    if facts.zoomChanged { seen.append("zoomed") }
    if facts.selectionChanges > 0 { seen.append("selected") }
    if facts.inkMoved > 0 { seen.append("moved_ink") }
    if facts.inkAdded > 0 || facts.beganDrawing { seen.append("drew") }
    if facts.inkRemoved > 0 { seen.append("erased") }
    return seen.isEmpty ? ["nothing"] : seen
  }

  public static func gesture(_ facts: TouchFacts) -> String {
    if facts.fingers > 1 { return "multi" }
    return facts.travel < 10 && facts.seconds < 0.5 ? "tap" : (facts.travel < 10 ? "press" : "drag")
  }

  /// Every touch in one run, from the first down to the last up (#825): a Pencil anywhere in it makes it the Pencil's,
  /// whatever touched first, so a palm landing before the Pencil doesn't turn its strokes into a finger's. The largest
  /// finger contact is kept so the log can tell a resting palm from a finger.
  public struct TouchTally: Equatable, Sendable {
    public private(set) var types: [String: Int] = [:]
    /// The largest finger contact's radius, in points; 0 with no finger.
    public private(set) var fingerRadius: CGFloat = 0
    private var seen: Set<Int> = []
    private var first: String?

    public init() {}

    /// The run's kind: pencil when any touch was the Pencil, else the first touch's; nil before any.
    public var type: String? { types["pencil", default: 0] > 0 ? "pencil" : first }

    public mutating func down(_ id: Int, _ kind: String, radius: CGFloat) {
      guard seen.insert(id).inserted else { return }
      if first == nil { first = kind }
      types[kind, default: 0] += 1
      if kind == "finger" { fingerRadius = max(fingerRadius, radius) }
    }
  }

  /// A finger's tap on a ghost: short, staying put, and the only finger, whatever a Pencil is doing beside it.
  public static func isFingerTap(travel: CGFloat, seconds: Double, fingers: Int) -> Bool {
    fingers == 1 && travel < 10 && seconds < 0.5
  }
}
