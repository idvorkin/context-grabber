//  Question cards hide and move on the board (stories 1273, 1274; #1387): a hidden card's bare '?', and the drag that
//  carries a card, chip or '?' with the touch and puts it down where it's let go. They draw `WhiteboardQuestionsModel`'s
//  state and decide nothing.

import ContextCore
import SwiftUI

/// A round card: a '?' in Larry's purple for an open question, a grey '✓' for an answered one.
struct WhiteboardQuestionMarkFace: View {
  let card: WhiteboardQuestion
  let scale: CGFloat

  private static let larry = Color(uiColor: UIColor(rgb: WhiteboardTurn.larryColor))

  var body: some View {
    let done = card.answered != nil
    // #1387 part 3: an open round is a '?', an answered one a '✓', as on the web board.
    Text(WhiteboardQuestions.lines(card, title: nil).first ?? "?")
      .font(.system(size: max(8, 22 * scale), weight: .bold, design: .rounded))
      .foregroundStyle(done ? Color(white: 0.45) : Color(red: 0.29, green: 0.12, blue: 0.36))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Circle().fill(done ? Color(white: 0.953) : Color(red: 0.984, green: 0.957, blue: 1)))
      .overlay(Circle().stroke(done ? Color(white: 0.78) : Self.larry, lineWidth: max(1, 2 * scale)))
      .contentShape(Circle())
  }
}

/// Story 1274: the card follows a finger or the Pencil and lands where it's let go. The drag goes before the card's tap,
/// so a drag never opens the popup; a touch that doesn't move still taps. The eraser never moves a card.
struct WhiteboardQuestionDrag: ViewModifier {
  let questions: WhiteboardQuestionsModel
  let card: WhiteboardQuestion
  let scale: CGFloat
  let erasing: Bool
  @GestureState private var moved: CGSize = .zero

  func body(content: Content) -> some View {
    content
      .offset(moved)
      .highPriorityGesture(
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
          .updating($moved) { drag, moved, _ in moved = drag.translation }
          .onEnded { drag in
            let s = max(scale, 0.01)
            questions.move(card, by: CGSize(width: drag.translation.width / s, height: drag.translation.height / s))
          },
        isEnabled: !erasing
      )
  }
}
