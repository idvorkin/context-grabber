//  A question card's looks on the board (spec 2026-11-16-whiteboard-question-cards-design.md, *The card's looks*;
//  stories 1319–1321, #1387 part 3): the double tap, an answered card drawn as text, and the strip of controls that sits
//  in one place whatever the look. They draw `WhiteboardQuestionsModel`'s state and decide nothing.

import ContextCore
import SwiftUI

/// Story 1319: a double tap steps the look; a single tap opens the popup, or a round out to full. The double tap goes
/// first, so a single tap waits for it to fail.
struct WhiteboardQuestionTaps: ViewModifier {
  let questions: WhiteboardQuestionsModel
  let card: WhiteboardQuestion

  func body(content: Content) -> some View {
    content
      .contentShape(Rectangle())
      .gesture(
        TapGesture(count: 2).onEnded { questions.cycle(card) }
          .exclusively(before: TapGesture().onEnded { tap() })
      )
      .accessibilityElement(children: .ignore)
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { tap() }
      .accessibilityAction(named: card.look == .round ? "Open out" : "Collapse") { questions.cycle(card) }
  }

  private func tap() {
    if card.hidden { questions.openOut(card) } else { questions.tap(card) }
  }
}

/// Story 1320: an answered card as text on the board: the question small and grey over the answer, a thin grey rule on
/// its left, no card's fill or edge. Short, the question alone.
struct WhiteboardQuestionAnsweredFace: View {
  let card: WhiteboardQuestion
  let scale: CGFloat

  var body: some View {
    let lines = WhiteboardQuestions.lines(card, title: nil)
    HStack(alignment: .center, spacing: 10 * scale) {
      Capsule().fill(Color(white: 0.78)).frame(width: max(1.5, 3 * scale))
      VStack(alignment: .leading, spacing: 1 * scale) {
        ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
          Text(line)
            .font(.system(size: max(6, (i == 0 && lines.count > 1 ? 13 : 16) * scale)))
            .foregroundStyle(i == 0 && lines.count > 1 ? Color(white: 0.5) : Color(white: 0.16))
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
    }
    .padding(.vertical, 2 * scale)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }
}

/// Story 1321: a card's controls as icons, just past a full card's right end, top-aligned, in one order; only those its
/// look allows, and none on a round.
struct WhiteboardQuestionStrip: View {
  @ObservedObject var questions: WhiteboardQuestionsModel
  @ObservedObject var place: WhiteboardBoardPlace
  let card: WhiteboardQuestion

  var body: some View {
    let controls = WhiteboardQuestions.controls(card)
    let at = WhiteboardQuestions.strip(card)
    let size = max(24, WhiteboardQuestions.control * place.scale)
    let gap = WhiteboardQuestions.controlGap * place.scale
    let corner = place.rect(CGRect(origin: at, size: .zero)).origin
    if !controls.isEmpty, !place.erasing {
      HStack(spacing: gap) {
        // Each control in its own slot, the strip's order, so an icon never moves between looks (Igor: "use icons
        // all in same spot"); a slot the look doesn't allow is left empty.
        ForEach(WhiteboardQuestion.Control.allCases, id: \.self) { control in
          if !controls.contains(control) {
            Color.clear.frame(width: size, height: size).accessibilityHidden(true)
          } else {
            Button {
              act(control)
            } label: {
              Image(systemName: Self.icon(control))
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(lit(control) ? Color.white : Color(white: 0.35))
                .frame(width: size, height: size)
                .background(
                  Circle().fill(lit(control) ? Color(uiColor: UIColor(rgb: WhiteboardTurn.larryColor)) : .white)
                )
                .overlay(Circle().stroke(Color(white: 0.75), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Self.name(control))
            .accessibilityIdentifier("whiteboard-question-\(control.rawValue)-\(card.ask)")
          }
        }
      }
      .fixedSize()
      .position(x: corner.x + width(WhiteboardQuestion.Control.allCases.count, size, gap) / 2, y: corner.y + size / 2)
    }
  }

  private func width(_ n: Int, _ size: CGFloat, _ gap: CGFloat) -> CGFloat {
    CGFloat(n) * size + CGFloat(max(0, n - 1)) * gap
  }

  /// Thinking is lit while the card is being thought over.
  private func lit(_ control: WhiteboardQuestion.Control) -> Bool { control == .thinking && card.thinking }

  private func act(_ control: WhiteboardQuestion.Control) {
    switch control {
    case .collapse: questions.collapseStep(card)
    case .openOut: questions.openOut(card)
    case .archive: questions.archive(card)
    case .thinking:
      if !card.thinking { questions.think(card) }
      questions.tap(card)
    }
  }

  static func icon(_ control: WhiteboardQuestion.Control) -> String {
    switch control {
    case .collapse: return "arrow.down.right.and.arrow.up.left"
    case .openOut: return "arrow.up.left.and.arrow.down.right"
    case .archive: return "archivebox"
    case .thinking: return "bubble.left.and.bubble.right"
    }
  }

  static func name(_ control: WhiteboardQuestion.Control) -> String {
    switch control {
    case .collapse: return "Collapse"
    case .openOut: return "Open out"
    case .archive: return "Archive"
    case .thinking: return "Thinking"
    }
  }
}
