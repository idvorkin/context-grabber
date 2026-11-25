//  A board on paper: a finger tap on one thing of Larry's he kept, outside any group, selects that one thing alone,
//  ready to drag (stories 1140–1142, #1171). It goes on as a group's tap does (PaperBoard+GroupTap.swift).

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// Stories 1140–1142: the thing of Larry's (or Claude's) whose stroke is within a fingertip (`WhiteboardTurn.tapReach`) of
  /// `at`, in board points, on a board he can draw on: every stroke made at its moment. Nil where his own ink is
  /// nearer, on a group's stroke (story 947), and on a board with nothing of theirs.
  func tappedTheirs(at: CGPoint) -> TappedGroup? {
    guard model.editable, let markup = paper.markup else { return nil }
    let moments = model.opLedger.theirs(board: model.board.id)
    guard !moments.isEmpty else { return nil }
    let strokes = opStrokes(markup).strokes
    let slop = WhiteboardTurn.tapReach / max(screenScale, 0.01)
    guard let hit = model.outline(of: strokes).theirs(at: at, slop: slop, moments: moments) else { return nil }
    let names = Set(hit.names)
    let ids = groupElements(names, in: markup)
    guard !ids.isEmpty else { return nil }
    return TappedGroup(name: "theirs-\(hit.moment)", names: names, selected: ids == paper.selection, kind: "theirs")
  }
}
