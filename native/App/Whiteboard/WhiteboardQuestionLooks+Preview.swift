//  Every look of a question card on the board, side by side (#1387 part 3, stories 1319–1321): the picture the design
//  pass compares before and after, rendered with `just render-preview App/Whiteboard/WhiteboardQuestionLooks+Preview.swift`.

import ContextCore
import SwiftUI

#if DEBUG
  /// One row per look, at the board's normal zoom: open, thought over, answered full, answered short, and the rounds.
  struct WhiteboardQuestionLooks: View {
    private static let title = "Renew the gym for a year?"
    private static let answer = WhiteboardQuestion.Answer(
      title: title, label: "Renew", note: "month to month after March")

    private static func card(answered: Bool = false, short: Bool = false, round: Bool = false, thinking: Bool = false)
      -> WhiteboardQuestion
    {
      WhiteboardQuestion(
        id: "c", ask: "a", x: 0, y: 0, answered: answered ? answer : nil, collapsed: short, hidden: round,
        thinking: thinking)
    }

    private static let looks: [(String, WhiteboardQuestion)] = [
      ("Open", card()), ("Thought over", card(thinking: true)), ("Answered", card(answered: true)),
      ("Answered, short", card(answered: true, short: true)), ("Open, round", card(round: true)),
      ("Answered, round", card(answered: true, round: true)),
    ]

    var body: some View {
      VStack(alignment: .leading, spacing: 22) {
        ForEach(Array(Self.looks.enumerated()), id: \.offset) { _, look in
          VStack(alignment: .leading, spacing: 6) {
            Text(look.0).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
              face(look.1).frame(
                width: WhiteboardQuestions.box(look.1).width, height: WhiteboardQuestions.box(look.1).height)
              if look.1.look != .round {
                strip(look.1).offset(
                  x: WhiteboardQuestions.strip(look.1).x - look.1.x, y: WhiteboardQuestions.strip(look.1).y - look.1.y)
              }
            }
            .frame(width: WhiteboardQuestions.width, alignment: .leading)
          }
        }
      }
      .padding(28)
      .frame(width: 700, alignment: .leading)
      .background(Color(red: 0.99, green: 0.99, blue: 0.97))
    }

    /// The strip's icons as the board draws them (story 1321), not live.
    private func strip(_ card: WhiteboardQuestion) -> some View {
      HStack(spacing: WhiteboardQuestions.controlGap) {
        ForEach(WhiteboardQuestion.Control.allCases, id: \.self) { control in
          Image(systemName: WhiteboardQuestionStrip.icon(control))
            .font(.system(size: WhiteboardQuestions.control * 0.45, weight: .medium))
            .foregroundStyle(control == .thinking && card.thinking ? Color.white : Color(white: 0.35))
            .frame(width: WhiteboardQuestions.control, height: WhiteboardQuestions.control)
            .background(
              Circle().fill(
                control == .thinking && card.thinking ? Color(uiColor: UIColor(rgb: WhiteboardTurn.larryColor)) : .white
              )
            )
            .overlay(Circle().stroke(Color(white: 0.75), lineWidth: 1))
            .opacity(WhiteboardQuestions.controls(card).contains(control) ? 1 : 0)
        }
      }
    }

    @ViewBuilder private func face(_ card: WhiteboardQuestion) -> some View {
      if card.hidden {
        WhiteboardQuestionMarkFace(card: card, scale: 1)
      } else {
        WhiteboardQuestionCardFace(card: card, title: Self.title, scale: 1)
      }
    }
  }

  #Preview("Question card looks", traits: .sizeThatFitsLayout) { WhiteboardQuestionLooks() }
#endif
