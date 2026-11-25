//  Question cards hide and move (spec 2026-11-16-whiteboard-question-cards-design.md, *Hiding a card* and *Moving a
//  card*; stories 1273, 1274; #1387): a card shrinks to a bare '?' and comes back, and a card, chip or '?' is dragged
//  anywhere on the page. The rules are `WhiteboardQuestions.hide` and `.move` in ContextCore.

import ContextCore
import Foundation

extension WhiteboardQuestionsModel {
  /// *Collapse* (first built as *Hide*) in a card's popup: the popup closes and the card is its '?'.
  /// Nothing is answered.
  func hide(_ card: WhiteboardQuestion) {
    if opened?.id == card.id { opened = nil }
    var next = board
    guard next.hide(card.id, true) else { return }
    change(next)
    log.event(
      "whiteboard_questions", ["action": "hide", "board": boardID, "ask": card.ask, "answered": card.answered != nil])
  }

  /// A tap on a '?': the card is back as it was, and no popup opens.
  func show(_ card: WhiteboardQuestion) {
    var next = board
    guard next.hide(card.id, false) else { return }
    change(next)
    log.event("whiteboard_questions", ["action": "show", "board": boardID, "ask": card.ask])
  }

  /// A drag let go: the card's top-left `by` board points from where it was, kept inside the page.
  func move(_ card: WhiteboardQuestion, by delta: CGSize) {
    var next = board
    guard let at = next.move(card.id, to: CGPoint(x: card.x + delta.width, y: card.y + delta.height)) else { return }
    change(next)
    log.event(
      "whiteboard_questions",
      [
        "action": "moved", "board": boardID, "ask": card.ask, "hidden": card.hidden, "x": Int(at.x.rounded()),
        "y": Int(at.y.rounded()),
      ])
  }
}
