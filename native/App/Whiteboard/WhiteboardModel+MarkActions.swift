//  The buttons beside a chosen mark come from Larry's reply (spec 2026-11-01-whiteboard-shapes-design.md, *Larry
//  chooses the buttons beside his reply*; stories 1352, 1353, #1525).

import ContextCore

extension WhiteboardModel {
  var chosenOffers: [WhiteboardMarkActions.Offer] {
    chosen?.offers ?? WhiteboardMarkActions.standard
  }

  func logUnknownMarkActions(_ actions: [String], row: String) {
    guard !actions.isEmpty else { return }
    log.event(
      "whiteboard_marks",
      [
        "action": "mark_actions_unknown", "board": board.id, "row": row,
        "unknown": WhiteboardMarkActions.logged(actions), "count": actions.count,
      ])
  }

  func logNewTextMarkActions(_ batch: BoardOps.Batch, texts: [BoardOps.Text]) {
    guard !batch.unknownMarkActions.isEmpty else { return }
    let shown = Set(texts.map(\.id))
    if batch.ops.contains(where: {
      if case .addText(let text) = $0 { return shown.contains(text.id) }
      return false
    }) {
      logUnknownMarkActions(batch.unknownMarkActions, row: batch.key)
    }
  }
}
