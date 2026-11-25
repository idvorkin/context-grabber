//  A question card's looks (spec 2026-11-16-whiteboard-question-cards-design.md, *The card's looks*; stories 1319–1321,
//  #1387 part 3): Collapse, Open out and the double tap's cycle, from the card's strip or a tap on the board. The rules
//  are `WhiteboardQuestions`' collapseStep, openOut and cycle in ContextCore.

import ContextCore
import Foundation

extension WhiteboardQuestionsModel {
  /// *Collapse* on the strip: one look smaller.
  func collapseStep(_ card: WhiteboardQuestion) { step(card, "collapse") { $0.collapseStep(card.id) } }

  /// *Open out* on the strip, or a tap on a round: back to full.
  func openOut(_ card: WhiteboardQuestion) { step(card, "open_out") { $0.openOut(card.id) } }

  /// A double tap: Collapse, and from a round back to full.
  func cycle(_ card: WhiteboardQuestion) { step(card, "double_tap") { $0.cycle(card.id) } }

  private func step(
    _ card: WhiteboardQuestion, _ how: String, _ change: (inout WhiteboardQuestions) -> WhiteboardQuestion.Look?
  ) {
    var next = board
    guard let look = change(&next) else { return }
    self.change(next)
    log.event(
      "whiteboard_questions",
      [
        "action": "look", "board": boardID, "ask": card.ask, "how": how, "from": card.look.rawValue,
        "to": look.rawValue,
      ])
  }
}
