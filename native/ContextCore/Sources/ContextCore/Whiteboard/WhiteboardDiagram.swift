//  Larry's diagrams keep as boxes Igor can move (spec 2026-11-16-whiteboard-board-ops-design.md, *Larry's diagrams keep
//  as boxes Igor can move*, stories 1349–1351, #1528): among one reply's marks, a rectangle with labels inside it is a
//  box, kept as one thing, and a plain arrow from one box to another keeps as a connector joining them. Pure: the app
//  keeps what the plan says.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum WhiteboardDiagram {
  /// One of a reply's marks as Keep sees it: its id, what it is, and its lines in board points.
  public struct Mark: Equatable, Sendable {
    public var id: String
    public var kind: WhiteboardTurn.Shape.Kind
    public var lines: [[CGPoint]]

    public init(id: String, kind: WhiteboardTurn.Shape.Kind, lines: [[CGPoint]]) {
      self.id = id
      self.kind = kind
      self.lines = lines
    }

    var bounds: CGRect {
      let points = lines.flatMap { $0 }
      guard let first = points.first else { return .null }
      return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }
  }

  /// What keeping the marks makes: the box each mark goes into (by mark id, the box's name), each box's rectangle, and
  /// the arrows that keep as connectors joining two boxes (by the arrow's mark id).
  public struct Plan: Equatable, Sendable {
    public var boxOf: [String: String] = [:]
    public var boxes: [String: CGRect] = [:]
    public var connectors: [String: BoardConnector] = [:]

    public init() {}
  }

  /// A box's name, from its rectangle's mark id: `box-` and its letters, anything else a dash; a name the Cockpit
  /// takes.
  public static func boxName(rect mark: String) -> String {
    let letters = mark.map { c -> Character in c.isASCII && (c.isLetter || c.isNumber || c == "_") ? c : "-" }
    return String(("box-" + String(letters)).prefix(64))
  }

  /// The boxes and joined arrows among `marks`, all of one reply. A rectangle is a box when at least one label's middle
  /// is inside it; a label inside two goes with the smaller. An arrow is joined when its tail and head each land on a
  /// different box, within a connector end's reach: the
  /// nearest, an end inside nested boxes joining the smaller.
  public static func plan(_ marks: [Mark]) -> Plan {
    var plan = Plan()
    let rects = marks.filter { $0.kind == .rect }.map { (id: $0.id, box: $0.bounds) }.filter { !$0.box.isNull }
    for label in marks where label.kind == .text {
      let b = label.bounds
      guard !b.isNull else { continue }
      let middle = CGPoint(x: b.midX, y: b.midY)
      guard
        let home = rects.filter({ $0.box.contains(middle) }).min(by: {
          $0.box.width * $0.box.height < $1.box.width * $1.box.height
        })
      else { continue }
      let name = boxName(rect: home.id)
      plan.boxOf[label.id] = name
      plan.boxOf[home.id] = name
      plan.boxes[name] = home.box
    }
    let boxes = plan.boxes
    func box(at point: CGPoint) -> (name: String, box: CGRect)? {
      let reach = BoardConnectors.reach
      return
        boxes
        .filter { $0.value.insetBy(dx: -reach, dy: -reach).contains(point) }
        .min {
          let (a, b) = (distance(point, $0.value), distance(point, $1.value))
          if a != b { return a < b }
          let (areaA, areaB) = ($0.value.width * $0.value.height, $1.value.width * $1.value.height)
          return areaA != areaB ? areaA < areaB : $0.key < $1.key
        }
        .map { ($0.key, $0.value) }
    }
    for arrow in marks where arrow.kind == .arrow {
      guard let shaft = arrow.lines.first, let tail = shaft.first, let head = shaft.last,
        let from = box(at: tail), let to = box(at: head), from.name != to.name
      else { continue }
      let fromSide = BoardConnectors.facing(from.box, to.box)
      let toSide = BoardConnectors.facing(to.box, from.box)
      let others = boxes.filter { $0.key != from.name && $0.key != to.name }.map(\.value)
      let route = BoardConnectors.route(
        from: from.box, to: to.box, fromSide: fromSide, toSide: toSide, obstacles: others)
      plan.connectors[arrow.id] = BoardConnector(
        from: from.name, to: to.name, fromSide: fromSide, toSide: toSide, route: BoardConnectors.tenth(route))
    }
    return plan
  }

  /// How far `point` is from `box` (0 inside it).
  static func distance(_ point: CGPoint, _ box: CGRect) -> CGFloat {
    let dx = max(box.minX - point.x, 0, point.x - box.maxX)
    let dy = max(box.minY - point.y, 0, point.y - box.maxY)
    return (dx * dx + dy * dy).squareRoot()
  }
}
