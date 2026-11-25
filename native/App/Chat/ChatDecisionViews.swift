//  Decision cards in Chat (#878, spec 2026-11-14-chat-decision-cards-design.md): the card, drawn in its thread and on
//  Decisions, its ⋯ menu, and the Decisions screen. They draw `ChatDecisionsModel`'s state and decide nothing.

import BugKit
import ContextCore
import SwiftUI

/// The top of a thread: its ask's card, or the line the card gave way to; nothing for a thread with neither.
struct ChatDecisionSlot: View {
  @ObservedObject var decisions: ChatDecisionsModel
  let key: String
  let voice: ChatVoiceModel
  let logger: BugLogger
  /// Story 1603: the card's cap under its heading, from the thread's height.
  var bodyCap: CGFloat?

  var body: some View {
    if let ask = decisions.ask(on: key) {
      ChatDecisionFoldable(
        decisions: decisions, ask: ask, place: "thread", voice: voice, logger: logger, bodyCap: bodyCap
      )
      .id(ask.id)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Color(.systemGroupedBackground))
    } else if let line = decisions.line(on: key) {
      ChatDecisionLine(text: line)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
    }
  }
}

/// What a card gave way to: *You decided: …* and the rest.
struct ChatDecisionLine: View {
  let text: String

  var body: some View {
    Label(text, systemImage: "checkmark.circle")
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .accessibilityIdentifier("decision-line")
  }
}

struct ChatDecisionCard: View {
  @ObservedObject var decisions: ChatDecisionsModel
  let ask: ChatAsk
  /// thread or list, for the log and the problem's context.
  let place: String
  /// Chat's mic for *Other…* (story 1128); nil where the card has no *Other* of its own: the board's popup, whose own
  /// answer sits under the card (story 882). Larry's own-answer option is drawn there too (story 1130), and a tap on it
  /// calls `ownAnswer` to put the cursor in that field.
  let voice: ChatVoiceModel?
  let logger: BugLogger
  /// Where the board's popup takes a tap on Larry's own-answer option: its *Your own answer* field.
  let ownAnswer: (() -> Void)?
  /// What a verb came to, for a card that does more with it than Chat's: the board's question card (story 882).
  let done: (ChatDecisions.Verb, ChatDecisions.Outcome) -> Void
  let fold: () -> Void
  /// Story 1603: how tall the card under its heading may grow before it scrolls; nil draws it whole.
  let bodyCap: CGFloat?
  @Binding private var draft: Draft
  @State private var closing = false
  @State private var closeReason = ""

  private var state: ChatDecisionsModel.Card { decisions.card(ask.id) }

  init(
    decisions: ChatDecisionsModel, ask: ChatAsk, place: String, voice: ChatVoiceModel?, logger: @escaping BugLogger,
    ownAnswer: (() -> Void)? = nil, draft: Binding<Draft>, fold: @escaping () -> Void, bodyCap: CGFloat? = nil,
    done: @escaping (ChatDecisions.Verb, ChatDecisions.Outcome) -> Void = { _, _ in }
  ) {
    self.decisions = decisions
    self.ask = ask
    self.place = place
    self.voice = voice
    self.logger = logger
    self.ownAnswer = ownAnswer
    self._draft = draft
    self.fold = fold
    self.bodyCap = bodyCap
    self.done = done
  }

  /// What Igor opened and typed on the card, kept by its holder so a fold and a tap on the line bring it back.
  struct Draft {
    var contextOpen = false
    var otherOpen = false
    var otherWords = ""
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Image(systemName: "questionmark.bubble").foregroundStyle(.orange)
        Text(ask.title).font(.headline).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 8)
        ChatDecisionFoldButton(fold: fold)
        menu
          .disabled(state.sending)
      }
      // Story 1603: at the top of its thread, everything under the heading scrolls inside a bounded height.
      ChatDecisionCappedBody(cap: bodyCap) {
        VStack(alignment: .leading, spacing: 8) {
          if !ask.context.isEmpty {
            Text(ask.context)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(draft.contextOpen ? nil : 3)
              .onTapGesture { draft.contextOpen.toggle() }
              .accessibilityIdentifier("decision-context")
          }
          ForEach(ask.options) { option in
            Button {
              switch ChatDecisions.tap(option) {
              case .answer(let verb): go(verb)
              case .openOther: openOther()
              }
            } label: {
              HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                  Text(option.label).font(.body.weight(.semibold))
                  if !option.detail.isEmpty {
                    Text(option.detail).font(.caption).foregroundStyle(.secondary)
                  }
                }
                Spacer(minLength: 8)
                if let mark = ask.marked, mark.key == option.key {
                  Text(mark.word).font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .multilineTextAlignment(.leading)
            }
            .buttonStyle(.bordered)
            .disabled(state.sending)
            .accessibilityIdentifier("decision-option-\(option.key)")
          }
          if let voice {
            if ChatDecisions.addsOther(ask) {
              ChatDecisionOtherButton(action: openOther).disabled(state.sending)
            }
            if draft.otherOpen {
              ChatDecisionOtherField(
                voice: voice, ask: ask, words: $draft.otherWords, sending: state.sending, logger: logger
              ) { go(.ownWords(draft.otherWords)) }
            }
          }
          if let expiry = ChatDecisions.expiry(ask.expiresAt, now: Date()) {
            Text(expiry.text).font(.caption).foregroundStyle(expiry.expired ? Color.orange : .secondary)
              .accessibilityIdentifier("decision-expiry")
          }
          if let note = state.note {
            Text(note).font(.footnote).foregroundStyle(.orange).accessibilityIdentifier("decision-note")
          }
          if let problem = state.problem {
            BugProblemView(problem: problem, logger: logger)
          }
        }
      }
    }
    .padding(12)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("decision-card-\(ask.id)")
    .task(id: ask.id) {
      decisions.shown(ask, from: place, other: ChatDecisions.otherLogName(ask, addsOwn: voice != nil))
    }
    .alert("Close this decision", isPresented: $closing) {
      TextField("What finished it", text: $closeReason)
      Button("Close") { go(.close(reason: closeReason)) }
        .disabled(state.sending || !ChatDecisions.canClose(reason: closeReason))
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("One line, and it goes to Larry.")
    }
  }

  private var menu: some View {
    Menu {
      Menu("Snooze") {
        ForEach(ChatDecisions.Snooze.allCases, id: \.self) { preset in
          Button(preset.label) { go(.snooze(preset)) }
        }
      }
      Button("Close…") {
        closeReason = ""
        closing = true
        decisions.closeAsked(ask, from: place)
      }
      Menu("Abandon") {
        ForEach(ChatDecisions.abandonReasons, id: \.self) { reason in
          Button(reason) { go(.abandon(reason: reason)) }
        }
        Button("No reason") { go(.abandon(reason: nil)) }
      }
    } label: {
      Label("More", systemImage: "ellipsis.circle").labelStyle(.iconOnly)
    }
    .accessibilityIdentifier("decision-menu")
  }

  /// *Other…*, or Larry's own *Other*: the field opens (on the board, the popup's own field takes the cursor); nothing
  /// is answered until *Send*.
  private func openOther() {
    guard voice != nil else {
      decisions.otherOpened(ask, from: place)
      ownAnswer?()
      return
    }
    guard !draft.otherOpen else { return }
    draft.otherOpen = true
    decisions.otherOpened(ask, from: place)
  }

  private func go(_ verb: ChatDecisions.Verb) {
    Task {
      if let outcome = await decisions.run(verb, on: ask, from: place) { done(verb, outcome) }
    }
  }
}

/// The list's *Decisions (N)* row, under Larry's pinned thread.
struct ChatDecisionsRow: View {
  let count: Int

  var body: some View {
    Label("Decisions (\(count))", systemImage: "checklist")
      .font(.body.weight(.semibold))
      .foregroundStyle(.orange)
  }
}

/// Every open ask as a card: answerable here, each with its chat a tap away.
struct ChatDecisionsView: View {
  @ObservedObject var chat: ChatModel
  @ObservedObject var decisions: ChatDecisionsModel
  /// Story 1132: the search box's words and what they found.
  @StateObject private var search: ChatAskSearchModel
  let voice: ChatVoiceModel
  let logger: BugLogger

  init(chat: ChatModel, voice: ChatVoiceModel, logger: @escaping BugLogger) {
    self.chat = chat
    self.decisions = chat.decisions
    self.voice = voice
    self.logger = logger
    _search = StateObject(
      wrappedValue: ChatAskSearchModel(log: chat.decisions.log, inbox: chat.inbox, cockpit: chat.cockpit))
  }

  var body: some View {
    // A scroll view, not a List: a List row holding a link takes every tap on its buttons for the link.
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 14) {
        if search.active {
          ChatAskSearchResults(chat: chat, search: search, voice: voice, logger: logger)
        } else {
          cards
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Decisions")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("chat-decisions-list")
    // Above the rows, as the thread list's box is: not iOS's bottom toolbar on the iPhone (bead context-grabber-6d1b).
    .searchable(
      text: $search.query, placement: .navigationBarDrawer(displayMode: .always), prompt: ChatAskSearch.prompt
    )
    .onChange(of: search.query) { search.changed() }
    .onChange(of: search.answeredToo) { search.changed() }
    .refreshable { await decisions.refresh(reason: "pull") }
    .task { await decisions.refresh(reason: "decisions") }
    .onDisappear { decisions.leftDecisions() }
    .chatTextSize()
  }

  /// Every open ask as a card, and what the finished ones gave way to.
  @ViewBuilder private var cards: some View {
    if let problem = decisions.readProblem {
      BugProblemView(
        problem: .grabber(problem, context: "ChatDecisionsView.refresh", extra: ["cockpit": .string(chat.cockpit)]),
        logger: logger)
    }
    ForEach(decisions.shown) { ask in
      VStack(alignment: .leading, spacing: 4) {
        ChatDecisionFoldable(decisions: decisions, ask: ask, place: "list", voice: voice, logger: logger)
        NavigationLink {
          ChatThreadView(chat: chat, voice: voice, key: ask.chatToOpen, title: ask.title, logger: logger)
            .onAppear { decisions.openedChat(ask) }
        } label: {
          Label("Open chat", systemImage: "bubble.left.and.bubble.right").font(.footnote)
        }
        .accessibilityIdentifier("decision-open-chat-\(ask.id)")
        .padding(.leading, 12)
      }
    }
    // #1072: keyed apart from the cards. Under the ask's own id, in the one lazy stack, an answered ask's row took over
    // its card's view: the card stayed on screen, answered and still tappable, and nothing after it showed.
    ForEach(decisions.finished.map { (key: "finished-" + $0.id, id: $0.id, title: $0.title) }, id: \.key) { done in
      VStack(alignment: .leading, spacing: 2) {
        Text(done.title).font(.subheadline).foregroundStyle(.secondary)
        if let line = decisions.card(done.id).line { ChatDecisionLine(text: line) }
      }
      .padding(.horizontal, 12)
    }
    if decisions.shown.isEmpty && decisions.finished.isEmpty && decisions.readProblem == nil {
      Text("No decisions waiting.").foregroundStyle(.secondary)
    }
  }
}
