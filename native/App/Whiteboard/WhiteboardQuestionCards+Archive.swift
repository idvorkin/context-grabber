//  Question cards archive and think over on the board (spec 2026-11-16-whiteboard-question-cards-design.md, *Archiving a
//  card* and *Thinking it over*; stories 1314–1317, #1387): the board menu's list of archived questions with *Reopen*,
//  and the popup's *Talk it over*, the ask's own conversation with Larry. They draw `WhiteboardQuestionsModel`'s state
//  and decide nothing.

import BugKit
import ContextCore
import SwiftUI

/// Story 1315: the archived questions, newest archived first, each with its answer or *open*, and *Reopen*.
struct WhiteboardQuestionArchiveList: View {
  @ObservedObject var questions: WhiteboardQuestionsModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        ForEach(questions.board.archived) { card in
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
              Text(card.answered?.title ?? questions.title(of: card) ?? "Question")
                .font(.body.weight(.semibold))
              Text(card.answered.map(WhiteboardQuestions.answerText) ?? "open")
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reopen") { questions.reopen(card) }
              .buttonStyle(.bordered)
              .accessibilityIdentifier("whiteboard-archived-reopen-\(card.ask)")
          }
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier("whiteboard-archived-\(card.ask)")
        }
      }
      .overlay {
        if questions.board.archived.isEmpty {
          Text("No archived questions.").foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Archived questions")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }.accessibilityIdentifier("whiteboard-archived-close")
        }
      }
    }
    .presentationDetents([.medium, .large])
    .accessibilityIdentifier("whiteboard-archived")
  }
}

/// Stories 1316, 1317: *Talk it over*, under an open card's question once Igor taps *Thinking*: the ask's conversation,
/// newest last, read again every few seconds while it's up, and a field with Chat's mic and *Send*.
struct WhiteboardQuestionTalk: View {
  @ObservedObject var questions: WhiteboardQuestionsModel
  @ObservedObject var voice: ChatVoiceModel
  let logger: BugLogger
  let card: WhiteboardQuestion
  @State private var words = ""

  /// How often the conversation is read again while it's on screen.
  static let every: Duration = .seconds(4)

  var body: some View {
    let talk = questions.talk(card.ask)
    let thread = "board-question-talk:\(card.ask)"
    VStack(alignment: .leading, spacing: 8) {
      Label("Talk it over", systemImage: "bubble.left.and.bubble.right").font(.headline)
      if talk.messages.isEmpty {
        Text(talk.read ? "Say what you're thinking; Larry answers here." : "Loading the conversation…")
          .foregroundStyle(.secondary)
      }
      ForEach(talk.messages) { message in
        Text(message.text)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(message.fromIgor ? Color.accentColor.opacity(0.15) : Color(.secondarySystemGroupedBackground))
          )
          .frame(maxWidth: .infinity, alignment: message.fromIgor ? .trailing : .leading)
          .accessibilityLabel("\(message.fromIgor ? "You" : "Larry"): \(message.text)")
          .accessibilityIdentifier("whiteboard-question-talk-message")
      }
      ForEach([talk.problem, talk.sendProblem].compactMap { $0 }, id: \.self) { problem in
        BugProblemView(
          problem: .grabber(
            problem, context: "WhiteboardQuestionTalk",
            extra: [
              "ask": .string(card.ask), "messages": .int(talk.messages.count), "online": .bool(questions.reachable),
            ]
          ),
          logger: logger)
      }
      HStack(alignment: .bottom, spacing: 8) {
        TextField("Think it over with Larry", text: $words, axis: .vertical)
          .lineLimit(1...4)
          .textFieldStyle(.roundedBorder)
          .accessibilityIdentifier("whiteboard-question-talk-words")
        MicButton(voice: voice, thread: thread, draft: words, identifier: "whiteboard-question-talk-mic")
        Button {
          let said = words
          voice.sent(thread: thread)
          Task { if await questions.say(said, on: card) { words = "" } }
        } label: {
          Text("Send").frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(talk.sending || !questions.reachable || !ChatDecisions.canSend(words: words))
        .accessibilityIdentifier("whiteboard-question-talk-send")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("whiteboard-question-talk")
    .onChange(of: voice.words) { _, _ in
      if let heard = voice.take(thread: thread) { words = heard }
    }
    .onDisappear { voice.cancel(thread: thread, why: "left_question") }
    // Larry's replies come in while it's up.
    .task(id: card.ask) {
      while !Task.isCancelled {
        await questions.readTalk(card.ask)
        try? await Task.sleep(for: Self.every)
      }
    }
  }
}

/// Story 1315: the board menu's row for the archived questions, there only while some are. It watches the cards itself,
/// so archiving one shows it without the Board menu being rebuilt (story 1107).
struct WhiteboardArchivedQuestionsRow: View {
  @ObservedObject var questions: WhiteboardQuestionsModel

  var body: some View {
    let count = questions.board.archived.count
    if count > 0 {
      Button("Archived questions (\(count))", systemImage: "archivebox") { questions.archiveOpen = true }
        .accessibilityIdentifier("whiteboard-archived-questions")
    }
  }
}
