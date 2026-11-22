//  Stories 950–953: the board's cheat sheet (?) and Feedback, one tap each at the board's top right (Larry's web board,
//  /ink, has them at the lower right, where the iPad's tool palette docks and takes the taps). Off the top bar, so the Board menu keeps its place (#848). Feedback is BugKit's own report sheet, the
//  one a shake opens; the board only says when it was saved.

import Combine
import SwiftUI

struct BoardHelpButtons: View {
  /// A look-only board shows no ?: its gestures don't apply there.
  let editable: Bool
  let log: SessionLog
  let board: String
  let report: () -> Void
  /// BugKit's status after each save.
  let saved: AnyPublisher<String, Never>
  /// Story 958: Play, on a board with ink (a look-only one too); nil on a board with none.
  var play: (() -> Void)?
  @State private var helpOpen = false
  @State private var confirmation: String?
  @State private var clearing: Task<Void, Never>?

  var body: some View {
    HStack(spacing: 8) {
      if let confirmation {
        Text(confirmation)
          .font(.footnote.weight(.semibold))
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(.regularMaterial, in: Capsule())
          .accessibilityIdentifier("whiteboard-feedback-logged")
      }
      if let play {
        Button("Play", systemImage: "play.fill", action: play)
          .accessibilityHint("Draws the board again in the order it was drawn")
          .accessibilityIdentifier("whiteboard-play")
      }
      if editable {
        Button {
          log.event("whiteboard", ["action": "help", "board": board])
          helpOpen = true
        } label: {
          Image(systemName: "questionmark").frame(minWidth: 20)
        }
        .accessibilityLabel("How this board works")
        .accessibilityIdentifier("whiteboard-help")
        .popover(isPresented: $helpOpen) { BoardHelpSheet { helpOpen = false } }
      }
      // Story 949 (#1162): the ladybug alone, as small as the ?; VoiceOver still reads Feedback.
      Button {
        log.event("whiteboard", ["action": "feedback", "board": board])
        report()
      } label: {
        Image(systemName: "ladybug").frame(minWidth: 20)
      }
      .accessibilityLabel("Feedback")
      .accessibilityIdentifier("whiteboard-feedback")
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .padding(.top, 36)
    .padding(.trailing, 20)
    .onReceive(saved) { status in
      // BugKit says "Problem logged. Thanks." once the report is saved and queued for iCloud; it never hears it arrive.
      confirmation = status.hasPrefix("Problem logged") ? "Feedback logged ✓" : status
      clearing?.cancel()
      clearing = Task {
        try? await Task.sleep(for: .seconds(5))
        if !Task.isCancelled { confirmation = nil }
      }
    }
  }
}

/// The board's gestures as they are now. Kept in step with the whiteboard specs: a gesture that changes changes here.
struct BoardHelpSheet: View {
  let done: () -> Void

  private struct Row: Identifiable {
    let gesture: String
    let does: String
    var id: String { gesture }
  }

  private static let sections: [(String, [Row])] = [
    (
      "In the left margin",
      [
        Row(gesture: "Tap beside a line", does: "Makes it a header (▾). A faint H marks a line that looks like one."),
        Row(gesture: "Tap a header's ▾", does: "Folds its section (▸ and how many lines); tap again to unfold."),
        Row(
          gesture: "Hold and drag down",
          does:
            "Makes room in whole lines, with a finger or the Pencil held still half a second. Up closes blank paper."),
        Row(gesture: "Hold still", does: "A menu: Make room here, Paste, Make header."),
        Row(gesture: "Hold a header's mark", does: "Fold all, collapse to 1, 2 or 3, Unfold all."),
      ]
    ),
    (
      "On the page",
      [
        Row(gesture: "Hold a finger still", does: "The same menu: Make room here, Paste, Make header."),
        Row(
          gesture: "Hold the Pencil on a word",
          does: "Picks it up: drag and lift to move it, or lift without moving to select it."),
        Row(
          gesture: "Underline a line, or start it with #",
          does: "Makes it a header (▾); ## and ### make a sub-header (▾ ##) inside the one above. "
            + "Undo takes the mark and the header. A rule across the page ends a section."),
        Row(gesture: "Fast zigzag over ink", does: "Scratches it out. Undo brings it back."),
        Row(gesture: "Lasso, then To text", does: "Turns the handwriting into typed text."),
        Row(
          gesture: "Select something",
          does:
            "A label above it says what it is and what applies: Ink · To text, Text · tap to reword, Group, Connector."),
        Row(
          gesture: "Hold the Pencil at a stroke's end",
          does: "Snaps it to a straight line, a rectangle or an ellipse. Undo gives your stroke back."),
      ]
    ),
    (
      "Larry's marks",
      [
        Row(gesture: "Keep all", does: "Beside the count of marks: keeps every one as ink, in the order he drew them."),
        Row(gesture: "Tidy overlaps", does: "In the Board menu: moves kept labels off your writing."),
      ]
    ),
    (
      "Feedback",
      [
        Row(
          gesture: "The ladybug, or shake the iPad",
          does: "A note, a picture of the screen and the recent log, for Larry and the Mac to file.")
      ]
    ),
  ]

  var body: some View {
    NavigationStack {
      List {
        ForEach(Self.sections, id: \.0) { title, rows in
          Section(title) {
            ForEach(rows) { row in
              VStack(alignment: .leading, spacing: 2) {
                Text(row.gesture).font(.subheadline.weight(.semibold))
                Text(row.does).font(.subheadline).foregroundStyle(.secondary)
              }
              .accessibilityElement(children: .combine)
            }
          }
        }
      }
      .navigationTitle("How this board works")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", action: done).accessibilityIdentifier("whiteboard-help-done")
        }
      }
    }
    .frame(idealWidth: 420, idealHeight: 640)
    .accessibilityIdentifier("whiteboard-help-sheet")
  }
}
