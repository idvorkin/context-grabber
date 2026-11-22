//  Larry's connector marks (spec 2026-11-16-whiteboard-board-ops-design.md, *Larry's connector marks*, stories
//  917–919): a reply's `kind: "connector"` shape shows as the arrow it would be on this board, and keeps as a real
//  connector that follows its ends, as on the web board.

import ContextCore
import PencilKit
import UIKit

extension WhiteboardModel {
  /// What keeping `ghost` puts on the board now; nil for a mark that isn't a connector.
  private func connectorKept(_ ghost: Ghost) -> BoardConnectors.Kept? {
    guard let connector = ghost.connector else { return nil }
    let strokes = opStrokes(drawing.strokes).strokes
    return BoardConnectors.keep(
      connector, strokes: strokes, texts: texts, metas: strokeMeta, folds: outline(of: strokes).tags)
  }

  /// Story 917: Larry's marks with each connector drawn as it would route on the board now; and the connectors that
  /// name nothing on it, which show nothing (story 919).
  func connectorGhosts(_ ghosts: [Ghost]) -> (shown: [Ghost], nowhere: [Ghost]) {
    var shown: [Ghost] = []
    var nowhere: [Ghost] = []
    for ghost in ghosts {
      guard let kept = connectorKept(ghost) else {
        shown.append(ghost)
        continue
      }
      guard let stroke = kept.stroke else {
        nowhere.append(ghost)
        continue
      }
      var drawn = ghost
      drawn.lines = [stroke.points]
      shown.append(drawn)
    }
    if !nowhere.isEmpty {
      sessionLog.event(
        "board_connectors",
        ["action": "mark_names_nothing", "board": board.id, "marks": nowhere.map(\.id)])
    }
    return (shown, nowhere)
  }

  /// Story 918: a kept connector mark's ink, routed on the board as it is now, its notes and its name taken in before it
  /// lands so the follow and Larry know it; nil for any other mark, or one whose end names nothing now (it keeps as
  /// nothing then).
  func connectorInk(_ ghost: Ghost, made: Date = Date()) -> [PKStroke]? {
    guard let kept = connectorKept(ghost) else { return nil }
    guard let stroke = kept.stroke, let connector = ghost.connector else {
      sessionLog.event(
        "board_connectors", ["action": "kept_nothing", "board": board.id, "mark": ghost.id, "missing": kept.missing])
      return []
    }
    let ink = Self.strokes([stroke.points], color: ghost.color, width: stroke.width, spacing: 4, made: made)
    var plan = BoardOps.Plan(pagesBefore: 1, pagesAfter: 1)
    plan.metas = kept.metas
    planPut(plan, drawn: ink.map { (Self.strokesForLarry(PKDrawing(strokes: [$0])).map(\.id), connector.id) })
    sessionLog.event(
      "board_connectors",
      [
        "action": "mark_kept", "board": board.id, "mark": ghost.id, "id": connector.id, "joins": kept.joins,
        "from": BoardConnector(stroke.meta)?.from ?? "", "to": BoardConnector(stroke.meta)?.to ?? "",
      ])
    return ink
  }
}
