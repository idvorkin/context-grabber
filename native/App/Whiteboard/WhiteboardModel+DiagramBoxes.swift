//  Larry's diagrams keep as boxes Igor can move (spec 2026-11-16-whiteboard-board-ops-design.md, *Larry's diagrams keep
//  as boxes Igor can move*, stories 1349–1351, #1528): Keep all, or Keep beside a mark of a reply, keeps each of the
//  reply's rectangles with the labels inside it as one box, and its arrows between two boxes as connectors joining them,
//  which follow a moved box. The rules are `WhiteboardDiagram`'s; here they meet the ghosts and the ink.

import ContextCore
import PencilKit
import UIKit

extension WhiteboardModel {
  /// The boxes and joined arrows among `marks`, reply by reply: a box or an arrow never spans two replies.
  func diagramPlan(_ marks: [Ghost]) -> WhiteboardDiagram.Plan {
    var plan = WhiteboardDiagram.Plan()
    let byReply = Dictionary(grouping: marks.filter { $0.text == nil && $0.connector == nil }) {
      WhiteboardMarks.reply(of: $0.id) ?? ""
    }
    for (reply, ghosts) in byReply where !reply.isEmpty {
      let one = WhiteboardDiagram.plan(ghosts.map { .init(id: $0.id, kind: $0.kind, lines: $0.lines) })
      plan.boxOf.merge(one.boxOf) { a, _ in a }
      plan.boxes.merge(one.boxes) { a, _ in a }
      plan.connectors.merge(one.connectors) { a, _ in a }
    }
    if !plan.boxes.isEmpty {
      log.event(
        "board_diagram",
        [
          "action": "keep", "board": board.id, "boxes": plan.boxes.count, "connectors": plan.connectors.count,
          "box_marks": plan.boxOf.count,
        ])
    }
    return plan
  }

  /// A joined arrow's ink: one stroke along its connector's route, head and all, as a connector is drawn; nil for any
  /// other mark.
  func diagramArrowInk(_ ghost: Ghost, plan: WhiteboardDiagram.Plan, made: Date) -> [PKStroke]? {
    guard let connector = plan.connectors[ghost.id] else { return nil }
    return Self.strokes(
      [BoardConnectors.polyline(connector.route)], color: ghost.color, width: ghost.width, spacing: 4, made: made)
  }

  /// The notes a kept diagram's strokes take (`names` are each mark's strokes' names): a box's strokes its box's group,
  /// a joined arrow's its connector. Returns the names it noted, which no reply group then takes.
  func noteDiagram(_ plan: WhiteboardDiagram.Plan, names: [String: [String]]) -> Set<String> {
    var noted: Set<String> = []
    for (mark, strokes) in names {
      if let box = plan.boxOf[mark] {
        for name in strokes {
          var object = strokeMeta[name]?.object as? [String: Any] ?? [:]
          object["group"] = box
          if let note = BoardMeta(object) { strokeMeta.set(note, for: name) }
          noted.insert(name)
        }
      } else if let connector = plan.connectors[mark] {
        for name in strokes {
          strokeMeta.set(connector.meta(over: strokeMeta[name]), for: name)
          noted.insert(name)
        }
      }
    }
    return noted
  }
}
