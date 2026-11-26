//  The buttons beside a chosen mark come from Larry's reply (spec 2026-11-01-whiteboard-shapes-design.md, *Larry
//  chooses the buttons beside his reply, and To question/answer*; stories 1352–1354, #1525), and *To question/answer*
//  keeps his reply and folds it under Igor's question.

import ContextCore
import SwiftUI

extension WhiteboardModel {
  /// The reply of Larry's that the chosen marks belong to, as it was drawn.
  private var chosenReply: WhiteboardMarks.Drawing? {
    guard let first = chosenMarks.first, first.who == .larry, let reply = WhiteboardMarks.reply(of: first.id) else {
      return nil
    }
    return marksHistory.showing.first { $0.id == reply }
  }

  /// The buttons beside the chosen marks, in the reply's order: Keep and Dismiss for a reply that names none, or for
  /// Claude's ghosts.
  var chosenOffers: [WhiteboardMarkActions.Offer] { chosenReply?.offers ?? WhiteboardMarkActions.standard }

  /// A button beside the chosen marks was pressed.
  func chooseMark(_ action: WhiteboardMarkActions.Action) {
    switch action {
    case .keep: keepChosen()
    case .dismiss: dismissChosen()
    case .questionAnswer: questionAnswerChosen()
    }
  }

  /// Story 1354: keep the reply, then make the first line of Igor's question in the picture Larry answered a header and
  /// fold the answer under it. With no writing of his there, the reply is kept and nothing folds.
  private func questionAnswerChosen() {
    let marks = chosenMarks
    let reply = chosenReply
    let question = reply?.frame
    // Larry (8abe63373b12): the question is the ink made since the turn before, up to the picture he answered.
    let taken = pictureTimes.taken(reply?.pictureID, board: board.id)
    let made = taken.map { (pictureTimes.before(reply?.pictureID, board: board.id).map { $0 + 1 } ?? 0)...$0 }
    let answer = marks.flatMap(\.lines).flatMap { $0 }.map(\.y).max()
    keepChosen()
    var folded = false
    if let question, let answer {
      folded =
        canvas?.changeOutline(named: "To question/answer") {
          $0.foldQuestion(in: question, made: made, answerBottom: answer, id: Self.newHeaderID()) != nil
        } ?? false
    }
    if !folded { pasteNote = "Nothing to fold under" }
    log.event(
      "whiteboard",
      [
        "action": "mark_choice", "board": board.id, "choice": "qa", "marks": marks.count, "folded": folded,
        "question_known": question != nil, "since_turn_before": made != nil,
      ])
  }
}
