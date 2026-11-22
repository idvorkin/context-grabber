//  A board on paper: a finger tap on one thing of Larry's he kept, outside any group, selects that one thing alone,
//  ready to drag (stories 1140–1142, #1171), or every piece of one reply of his kept with plain Keep (story 1143). It
//  goes on as a group's tap does (PaperBoard+GroupTap.swift).

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// Stories 1140–1142: the thing of Larry's (or Claude's) whose stroke is within a fingertip (22 screen points) of
  /// `at`, in board points, on a board he can draw on: every stroke made at its moment, or (story 1143) at any moment
  /// of the reply it came in. Nil where his own ink is nearer, on a group's stroke (story 947), and on a board with
  /// nothing of theirs.
  func tappedTheirs(at: CGPoint) -> TappedGroup? {
    guard model.editable, let markup = paper.markup else { return nil }
    let moments = model.opLedger.theirs(board: model.board.id)
    guard !moments.isEmpty else { return nil }
    let strokes = opStrokes(markup).strokes
    let slop = 22 / max(screenScale, 0.01)
    let replies = model.opLedger.replies(board: model.board.id)
    guard let hit = model.outline(of: strokes).theirs(at: at, slop: slop, moments: moments, replies: replies)
    else { return nil }
    let names = Set(hit.names)
    let ids = groupElements(names, in: markup)
    guard !ids.isEmpty else { return nil }
    let name = hit.reply.map { "theirs-reply-\($0)" } ?? "theirs-\(hit.moment)"
    return TappedGroup(name: name, names: names, selected: ids == paper.selection, kind: "theirs")
  }
}
