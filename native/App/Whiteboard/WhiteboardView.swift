//  A whiteboard (spec 2026-11-01-whiteboard-design.md, stories 340–343, 347): a column of pages on PaperKit with the
//  system tool picker, saved a moment after each stroke, and sent to Larry on the board's chat thread holding its picture
//  (the Inbox's image path, so it waits in the outbox when the network is away). A board another device draws opens to
//  look at only. Claude's ghosts after a pause or spoken words and Larry's turn come back
//  as shapes, drawn faint until a tap keeps one (spec 2026-11-01-whiteboard-shapes-design.md, stories 344, 345, 349).
//  This file is the SwiftUI view; the model is WhiteboardModel.swift and its WhiteboardModel+<Feature>.swift files.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

/// One board, pushed from the list: drawn on here, or looked at when another device draws it.
struct WhiteboardView: View {
  @StateObject private var model: WhiteboardModel
  @ObservedObject private var inbox: InboxModel
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  /// The page's height, for the open panel's fifth (story 837).
  @State private var pageHeight: CGFloat = 0
  /// #1005 (story 1054): Paste shows only while there is text to paste.
  @State private var clipboardHasText = false
  /// Bead context-grabber-dbku, story 1206: the board's thread, slid in over the board by *Open in Chat* or the note.
  @State private var chatJump: ChatJump?
  /// Story 1279 (#1384): the conversation floats over the board as a card, or docks above it.
  @AppStorage(WhiteboardPanelKeys.floating) private var panelFloating = false
  @Environment(\.dismiss) private var dismiss
  /// Story 1225: the thread this board was slid in over, so *Open in Chat* on it goes back rather than piling up.
  private let cameFromThread: String?
  /// Story 1223: the boards set aside under this one, told when it comes and goes.
  private let under: BoardsUnder
  @State private var screenID = UUID().uuidString
  private let chat: ChatModel
  private let logger: BugLogger
  private let log: SessionLog
  private let callLive: AnyPublisher<Bool, Never>
  private let reportOpen: AnyPublisher<Bool, Never>
  /// Stories 952, 953: Feedback opens BugKit's report; its status after each save.
  private let report: () -> Void
  private let reportSaved: AnyPublisher<String, Never>
  /// Story 769: an iPhone has no conversation panel; a tap on the note opens the board's thread in Chat.
  private let onPhone: Bool

  /// #1005 (story 1055): a bar button a tap runs as always, and a long press names, in one word, with a row
  /// saying what the tap does (which does it too).
  private func named<L: View>(
    _ word: String, does: String, action: @escaping () -> Void, @ViewBuilder label: () -> L
  ) -> some View {
    Menu {
      Section(word) { Button(does, action: action) }
    } label: {
      label()
    } primaryAction: {
      action()
    }
  }

  /// #965: one of the bar's Undo and Redo, at least 44 points wide and the bar's own height, named for the step it acts on.
  private func undoButton(redo: Bool) -> some View {
    let state = redo ? model.undoButtons.redo : model.undoButtons.undo
    return Button {
      model.canvas?.pressedUndo(redo: redo)
    } label: {
      Label(redo ? "Redo" : "Undo", systemImage: redo ? "arrow.uturn.forward" : "arrow.uturn.backward")
        .labelStyle(.iconOnly)
        .frame(minWidth: BoardUndoButtons.side, minHeight: BoardUndoButtons.side)
        .contentShape(Rectangle())
    }
    .disabled(!state.enabled)
    .accessibilityLabel(state.label)
    .accessibilityIdentifier(redo ? "whiteboard-redo" : "whiteboard-undo")
  }
  private let openChat: (String) -> Void
  private let decisions: ChatDecisionsModel
  /// Story 889: a question card's own answer is spoken with Chat's mic.
  private let chatVoice: ChatVoiceModel

  init(
    board: BoardEntry, store: WhiteboardStore, app: AppModel, cameFromThread: String? = nil,
    under: BoardsUnder = BoardsUnder()
  ) {
    _model = StateObject(
      wrappedValue: WhiteboardModel(
        board: board, store: store, log: app.log, inbox: app.inbox, cockpit: app.chat.cockpit,
        callLive: { [weak app] in app?.call.snapshot.isActive ?? false }))
    inbox = app.inbox
    callLive = app.call.$snapshot.map(\.isActive).removeDuplicates().eraseToAnyPublisher()
    reportOpen = app.reporter.$flow.map(\.isPresented).removeDuplicates().eraseToAnyPublisher()
    report = { [weak app] in app?.startBugReport(from: "whiteboard") }
    reportSaved = app.reporter.$lastStatus.dropFirst().compactMap { $0 }.receive(on: RunLoop.main).eraseToAnyPublisher()
    logger = app.bugLogger
    log = app.log
    onPhone = store.onPhone
    openChat = { [weak app] key in app?.open(route: .chat(thread: key), from: "whiteboard") }
    self.cameFromThread = cameFromThread
    self.under = under
    chat = app.chat
    decisions = app.chat.decisions
    chatVoice = app.chatVoice
  }

  var body: some View {
    VStack(spacing: 0) {
      // Story 667: while Larry is looking the note begins with his clock, so it ticks once a second, as it does while a
      // message holds the middle (story 766); else it's still.
      // Story 1103 (#1139): while the mic is open, the microphone it hears and its level end the line.
      HStack(spacing: 0) {
        noteStrip
        if model.micOn {
          WhiteboardMicChip(dictation: model.dictation, hears: model.micHears) { model.pickMicrophone($0) }
        }
      }
      if let problem = model.problem {
        WhiteboardProblemRow(
          problem: problem, logger: logger, dismissSilence: { model.dismissProblem() },
          retryLarry: { model.retryLarry() }, dismissStuck: { model.dismissStuck() })
      }
      // Story 1048 (#1003): the conversation sits above the paper and pushes it down, so it never covers ink. Story 837
      // (#917): a fifth of the page at most; past that it scrolls rather than grows.
      // Story 1278 (#1384): a grip under it drags it taller or shorter, and the page moves with it.
      if model.conversationOpen, !onPhone, !panelFloating {
        WhiteboardConversationDocked(pageHeight: pageHeight) { height in
          conversationPanel(height: height)
        }
      }
      Group {
        PaperBoardCanvas(model: model, log: log)
      }
      // Story 1279 (#1384): floating, the conversation is a card over the board, where Igor last left it.
      .overlay(alignment: .topLeading) {
        if model.conversationOpen, !onPhone, panelFloating {
          GeometryReader { area in
            WhiteboardConversationCard(area: area.size) { height in conversationPanel(height: height) }
          }
        }
      }
      // Stories 950–953: ? and Feedback under the page number; off the top bar (#848) and the tool palette's bottom.
      // Stories 970–972: Larry's change was refused; a chip below them, over the board, so the paper never moves.
      .overlay(alignment: .topTrailing) {
        VStack(alignment: .trailing, spacing: 8) {
          BoardHelpButtons(
            editable: model.editable, log: log, board: model.board.id, report: report, saved: reportSaved,
            play: model.isEmpty ? nil : { model.startPlayback() })
          if model.blocked.showing { blockedChip.padding(.trailing, 20) }
          // Stories 1242, 1243: a session's review, only when there is something to look at.
          if let note = model.review.note {
            BoardReviewChip(note: note) { model.openReview() }.padding(.trailing, 20)
          }
        }
        // Story 1000: the chosen mark's buttons keep clear of this corner.
        .onGeometryChange(for: CGRect.self) {
          $0.frame(in: .global)
        } action: {
          model.cornerLaid($0)
        }
      }
      .ignoresSafeArea(edges: .bottom)
    }
    // Story 837 (#917): the panel's fifth is of the whole page, not of the paper it pushes down, so opening it doesn't
    // change its own limit.
    .onGeometryChange(for: CGFloat.self) {
      $0.size.height
    } action: {
      pageHeight = $0
    }
    .modifier(
      WhiteboardQuestionSheet(questions: model.questions, decisions: decisions, voice: chatVoice, logger: logger)
    )
    // Story 1160: its name as it is now, and a tap on it renames a board that draws here.
    .modifier(BoardTitleRename(board: model.board, store: model.store, editable: model.editable))
    .navigationBarTitleDisplayMode(.inline)
    // Stories 954, 956–958: playback over the whole board, its bars hidden.
    .modifier(WhiteboardPlaybackHost(model: model))
    .sheet(isPresented: $model.reviewListOpen) { BoardReviewList(model: model) }
    .toolbar {
      // #965 (stories 1008, 1009): Undo and Redo where a finger reaches them, after the way back, whatever the tool picker
      // is doing.
      if model.editable {
        // One item holding both: a bar button from a plain Label is the system's own size (39.5 points wide on the
        // iPad simulator), and only a view the bar hosts as it is keeps its 44-point width. The bar still hosts it at its own
        // 36-point height, whatever the frame asks (stories 1008, #965).
        ToolbarItem(placement: .topBarLeading) {
          HStack(spacing: 0) {
            undoButton(redo: false)
            undoButton(redo: true)
          }
        }
      }
      if model.editable {
        // The board's own settings, in one menu. Six items in an iPhone's top bar push Send under *More*,
        // so at that width this one goes to the bottom (story 402).
        ToolbarItem(placement: horizontalSizeClass == .compact ? .bottomBar : .topBarTrailing) {
          WhiteboardBoardMenu(model: model).equatable()
        }
      }
      if model.editable {
        // #1005 (story 1054): Paste beside the Board menu, in the board's own group, and only while the clipboard holds
        // text: dimmed, the system's button read as a hole in the bar.
        if clipboardHasText {
          ToolbarItem(placement: .topBarTrailing) {
            // The system's button: no *Allow Paste?* prompt.
            PasteButton(payloadType: String.self) { texts in
              Task { @MainActor in model.paste(texts.joined(separator: "\n")) }
            }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("whiteboard-paste")
          }
        }
        // #1005 (story 1054): the board's own things are a group of their own, like Undo and Redo.
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
          WhiteboardMicButton(model: model, dictation: model.dictation)
        }
        ToolbarItem(placement: .topBarTrailing) {
          // Story 1171 (bead context-grabber-4ic): once "Ghosts"; off, a pause asks no one, whoever answers the board.
          let asking = model.ghostsOn ? "Ask at my pauses: on" : "Ask at my pauses: off"
          let who = model.responder.shown.name
          named(
            "Ask at my pauses", does: model.ghostsOn ? "Stop asking \(who) at my pauses" : "Ask \(who) at my pauses",
            action: { model.setGhosts(!model.ghostsOn) },
            label: { Label(asking, systemImage: model.ghostsOn ? "sparkles" : "eye.slash") }
          )
          // How many show, for VoiceOver and the UI test (the board's own content is not in the accessibility tree,
          // and a toolbar button's accessibility value never reaches it).
          .accessibilityLabel(asking + (model.ghosts.isEmpty ? "" : ", \(model.ghosts.count) showing"))
          .accessibilityIdentifier("whiteboard-ghosts")
        }
      }
      // Every board, wherever it opens (story 1200).
      ToolbarItem(placement: .topBarTrailing) {
        named(
          "Send", does: "Send the board to Larry", action: { model.sendToLarry() },
          label: { Label("Send to Larry", systemImage: "paperplane") }
        )
        // How much is drawn, for VoiceOver and the UI test, in the label for the reason above.
        .accessibilityLabel("Send to Larry, \(model.drawing.strokes.count) strokes")
        // Story 1176: one button. On a board drawn here it is Larry's turn, dimmed while its picture waits in the
        // outbox, and once Larry has the board as it is until the next stroke (bead context-grabber-x3tm); a board
        // only looked at is dimmed after a send until other pages are on screen (story 343).
        .disabled(
          model.isEmpty || model.nothingOnScreen || model.larrySending || model.sendWaiting(in: inbox.items)
            || (!model.editable && model.sent != nil) || model.larryHasThis
        )
        .accessibilityHint(model.larryHasThis ? "Larry already has this board" : "")
        .accessibilityIdentifier("whiteboard-send")
      }
    }
    // #1005 (story 1054): asking whether the clipboard holds text never prompts; it can change while the app is away, and
    // inside it on a copy.
    .onAppear { clipboardHasText = UIPasteboard.general.hasStrings }
    .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
      clipboardHasText = UIPasteboard.general.hasStrings
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { clipboardHasText = UIPasteboard.general.hasStrings }
    }
    .task {
      var seen = UIPasteboard.general.changeCount
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        let count = UIPasteboard.general.changeCount
        if count != seen {
          seen = count
          clipboardHasText = UIPasteboard.general.hasStrings
        }
      }
    }
    .task {
      // XCUITest's taps never reach the system's paste button: the UI test pastes through this.
      guard let text = LaunchHooks.current.whiteboard.paste else { return }
      try? await Task.sleep(for: .seconds(1))
      model.paste(text)
    }
    .task {
      // Bead context-grabber-pbvt: the simulator's way of keeping, and its loop of three-stroke keeps.
      if let way = LaunchHooks.current.whiteboard.keepWay { PaperBoardController.keepWay = way }
      guard model.editable, LaunchHooks.current.whiteboard.keepLoop != nil else { return }
      try? await Task.sleep(for: .seconds(1))
      (model.canvas as? PaperBoardController)?.keepLoopForTests()
    }
    .task {
      // #965: the simulator presses the bar's own Undo and Redo, as a tap on them does.
      guard model.editable, let hook = LaunchHooks.current.whiteboard.barUndo else { return }
      try? await Task.sleep(for: .seconds(hook.delay))
      for press in hook.presses {
        model.canvas?.pressedUndo(redo: press == "redo")
        try? await Task.sleep(for: .seconds(3))
      }
    }
    .onAppear {
      under.appeared(screenID)
      model.backFromChat()
      model.opened()
      model.reviewOpened()
      model.startWatchingLarry()
    }
    .onDisappear {
      under.left(screenID)
      // Story 1223: its thread slid in over it; the board waits, saved, for Back.
      if chatJump != nil {
        model.setAsideForChat()
        return
      }
      model.endPlayback()  // story 957: closing the board ends playback, changing nothing
      model.stopMic(why: "closed")
      model.reviewClosed()
      model.close()
    }
    .navigationDestination(item: $chatJump) { jump in
      ChatThreadView(
        chat: chat, voice: chatVoice, key: jump.thread, title: chat.title(of: jump.thread), logger: logger,
        cameFromBoard: model.board.id, under: under.adding(model))
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        model.flush()
        model.stopMic(why: "background")
      }
      if phase == .active { model.startWatchingLarry() }
    }
    .onReceive(callLive) { live in if live { model.stopMic(why: "call") } }
    .onReceive(reportOpen) { open in if open { model.stopMic(why: "report") } }
  }

  /// Bead context-grabber-dbku: the board's thread slides in over it, or, when it is the thread this board was slid
  /// over, the board goes back to it.
  private func openThread(_ key: String, from: String) {
    let how = BoardChatJump.how(
      .thread(key), cameFrom: cameFromThread.map(BoardChatJump.Target.thread), openElsewhere: false)
    log.event(
      "jump",
      [
        "from": from, "board": model.board.id, "to": "thread", "thread": key, "how": how.rawValue,
        "through_list": how.throughList,
      ])
    switch how {
    case .wentBack: dismiss()
    case .slidIn: chatJump = ChatJump(thread: key)
    case .broughtForward: openChat(key)
    }
  }

  /// Story 1279 (#1384): float the conversation over the board, or dock it above, and say so in the log.
  private func placePanel(floating: Bool) {
    panelFloating = floating
    log.event("whiteboard", ["action": "conversation_place", "board": model.board.id, "floating": floating])
  }

  /// Stories 970–972: Larry's refused change, with Retry and ×. Each takes a finger's worth of the chip, all of it its
  /// own: on main the bare glyphs let a tap through to the paper, which drew a dot (story 970's Issues).
  private var blockedChip: some View {
    let larry = Color(UIColor(rgb: WhiteboardTurn.larryColor))
    return HStack(spacing: 0) {
      Button {
        model.retryBlocked()
      } label: {
        Text("\(BoardBlockedEdit.text) · Retry").padding(.leading, 12).padding(.trailing, 4)
          .frame(minHeight: 36).contentShape(Rectangle())
      }
      .accessibilityHint("Hands Larry the board again, so he looks and sends a fresh change")
      .accessibilityIdentifier("whiteboard-blocked-retry")
      Button {
        model.dismissBlocked()
      } label: {
        Image(systemName: "xmark").frame(width: 36, height: 36).contentShape(Rectangle())
      }
      .accessibilityLabel("Dismiss")
      .accessibilityIdentifier("whiteboard-blocked-dismiss")
    }
    .font(.footnote.weight(.semibold))
    .buttonStyle(.borderless)
    .foregroundStyle(larry)
    .background(larry.opacity(0.15), in: Capsule())
    .contentShape(Capsule())
    .onGeometryChange(for: CGRect.self) {
      $0.frame(in: .global)
    } action: {
      model.blockedLaid($0)
    }
  }

  /// The note's line (story 766), from the model's values; its taps go back to the model (#1039).
  private var noteStrip: some View {
    let model = model
    let onPhone = onPhone
    let openChat: (String) -> Void = { openThread($0, from: "board_note") }
    let shown: (ContinuousClock.Instant) -> WhiteboardNoteStrip.Shown = { now in
      WhiteboardNoteStrip.Shown(
        line: WhiteboardNote.line(
          larry: model.larry, now: now, cockpitAnswering: !model.larryAway, mark: model.larryMark(now: now),
          said: model.lastSaid, micOn: model.micOn, notice: model.notice, ghosts: model.ghosts.count,
          listening: model.larryListening),
        tap: WhiteboardNote.tap(onPhone: onPhone, thread: model.threadKey), conversationOpen: model.conversationOpen,
        keepAll: model.editable && model.larrysMarks > 0 ? { model.keepLarrysMarks() } : nil,
        interrupt: model.larryWait == .working ? { model.interruptLarry() } : nil)
    }
    return WhiteboardNoteStrip(
      current: shown(.now), shown: shown, ticks: WhiteboardNote.ticks(larry: model.larry, notice: model.notice),
      onPhone: onPhone,
      tapNote: { model.tapNote(onPhone: onPhone, openChat: openChat) })
  }

  /// The open note over the board on an iPad (story 768), from the model's values (#1039), at `height` when dragged to
  /// one (stories 1278, 1279).
  private func conversationPanel(height: CGFloat?) -> some View {
    let model = model
    let openChat: (String) -> Void = { openThread($0, from: "board_panel") }
    let live: (ContinuousClock.Instant) -> [WhiteboardNote.Row] = { now in
      WhiteboardNote.live(
        thread: model.thread, larry: model.larry, now: now, cockpitAnswering: !model.larryAway,
        mark: model.larryMark(now: now), said: model.lastSaid, micOn: model.micOn, listening: model.larryListening)
    }
    let openInChat: (() -> Void)? = model.threadKey.map { key in { openChat(key) } }
    return WhiteboardConversationPanel(
      rows: WhiteboardNote.recent(model.thread), ticks: WhiteboardNote.ticks(larry: model.larry, notice: nil),
      current: live(.now), live: live, pageHeight: pageHeight, openInChat: openInChat,
      linkOpened: { model.logLinkOpened($0) }, chat: chat, threadKey: model.threadKey, height: height,
      dock: WhiteboardPanelDock(floating: panelFloating) { placePanel(floating: !panelFloating) })
  }
}

/// Bead context-grabber-dbku: a board's thread to slide in over it.
struct ChatJump: Hashable, Identifiable {
  let thread: String
  var id: String { thread }
}
