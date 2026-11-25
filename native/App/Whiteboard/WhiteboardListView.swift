//  The boards (spec 2026-11-01-whiteboard-design.md, stories 348, 396–401): what the Whiteboard tile opens. A row per
//  board, newest change first, + New board, a swipe or long press to delete any board, or to rename this device's own
//  (story 836); every device's boards come down from iCloud when the list opens, comes forward, or is pulled.

import BugKit
import ContextCore
import SwiftUI

struct WhiteboardListView: View {
  /// AppModel's, so the boards outlive this screen and every window shares one store (#819).
  @ObservedObject private var store: WhiteboardStore
  @Environment(\.scenePhase) private var scenePhase
  @State private var path: [String] = []
  @State private var renaming: BoardEntry?
  @State private var newName = ""
  @State private var deleting: BoardEntry?
  /// A link named a board that isn't here (#603).
  @State private var linkProblem: BugProblem?
  /// #1163, story 1097: the board whose chat the iPhone is looking for, and why the last look found none.
  @State private var findingChat: String?
  @State private var chatProblem: BugProblem?
  /// Bead context-grabber-dbku: a row's thread, slid in over the list by its chat bubble; Back comes back to the list.
  @State private var listChat: ChatJump?
  /// Stories 1339-1340: Boards from the Cockpit (beta), off by default; on, the store's boards are listed below.
  @AppStorage(WhiteboardCockpitBoards.key) private var cockpitBoardsOn = false
  @StateObject private var cockpitBoards: CockpitBoardsModel
  private let app: AppModel
  private let onDone: () -> Void

  init(app: AppModel, onDone: @escaping () -> Void) {
    _store = ObservedObject(wrappedValue: app.whiteboards)
    _cockpitBoards = StateObject(wrappedValue: CockpitBoardsModel(cockpit: app.chat.cockpit, log: app.log))
    self.app = app
    self.onDone = onDone
  }

  /// #603: the board a link named, as it is now, unless a board was opened while iCloud was asked.
  private func followLink() async {
    guard let linked = app.whiteboardLink else { return }
    app.whiteboardLink = nil
    let before = path
    linkProblem = await store.find(linked, context: "WhiteboardListView.link")
    if linkProblem == nil, path == before { path = [linked] }
  }

  var body: some View {
    NavigationStack(path: $path) {
      List {
        if let problem = store.problem { BugProblemView(problem: problem, logger: app.bugLogger) }
        if let linkProblem { BugProblemView(problem: linkProblem, logger: app.bugLogger) }
        if let chatProblem { BugProblemView(problem: chatProblem, logger: app.bugLogger) }
        if let note = store.syncNote { Text(note).font(.footnote).foregroundStyle(.secondary) }
        // Story 1340: first, so a long list of the iPad's own boards never hides it.
        if cockpitBoardsOn { CockpitBoardsSection(model: cockpitBoards, logger: app.bugLogger) }
        // Bead context-grabber-1jb4: a board whose first drawing hasn't come down isn't a row yet.
        if store.index.shown.isEmpty {
          ContentUnavailableView(
            "No boards yet", systemImage: "scribble.variable", description: Text("Tap + to start one."))
        } else {
          ForEach(store.index.shown) { board in row(board) }
        }
      }
      .listStyle(.plain)
      .refreshable {
        await store.sync(reason: "pull")
        if cockpitBoardsOn { await cockpitBoards.refresh(reason: "pull") }
      }
      .navigationTitle("Boards")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Done", action: onDone).accessibilityIdentifier("whiteboard-done")
        }
        // Story 746: an iPhone only looks at boards.
        if store.startsBoards {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              path.append(store.create())
            } label: {
              Label("New board", systemImage: "plus")
            }
            .accessibilityIdentifier("whiteboard-new")
          }
        }
      }
      .navigationDestination(for: String.self) { id in
        if let board = store.index.board(id) { WhiteboardView(board: board, store: store, app: app) }
      }
      .navigationDestination(item: $listChat) { jump in
        ChatThreadView(
          chat: app.chat, voice: app.chatVoice, key: jump.thread, title: app.chat.title(of: jump.thread),
          logger: app.bugLogger)
      }
    }
    .accessibilityIdentifier("whiteboard-list")
    .task {
      if app.whiteboardLink != nil {
        await followLink()
      } else {
        await store.sync(reason: "open")
      }
      if cockpitBoardsOn { await cockpitBoards.refresh(reason: "open") }
      if store.onPhone, let id = LaunchHooks.current.whiteboard.listChat, let board = store.index.board(id) {
        await openChat(board)
      }
    }
    // #634: in a window of its own the list is already up when a link arrives. The first value is the task's.
    .onReceive(app.$whiteboardLink.dropFirst().compactMap { $0 }) { _ in Task { await followLink() } }
    // #722: the Mac's New Board, as the list comes up or while it is up.
    .onReceive(app.$whiteboardNewBoard.filter { $0 }) { _ in
      Task {
        app.whiteboardNewBoard = false
        path = [store.create()]
      }
    }
    .onChange(of: cockpitBoardsOn) { _, on in
      if on { Task { await cockpitBoards.refresh(reason: "switched_on") } }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await store.sync(reason: "foreground") } }
    }
    // Story 233: the open board names the window (*Whiteboard · Board, Nov 22*), and its rename renames it.
    .onAppear { app.whiteboardOnScreen = path.last }
    .onChange(of: path) { _, open in app.whiteboardOnScreen = open.last }
    .onChange(of: path.last.flatMap { store.index.board($0)?.title }) { _, _ in app.nameWindows() }
    .onDisappear { app.whiteboardOnScreen = nil }
    .alert(
      "Rename board",
      isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
      presenting: renaming
    ) { board in
      TextField("Name", text: $newName)
      Button("Rename") { store.rename(board.id, to: newName, from: "list") }.macDefaultAction()
      Button("Cancel", role: .cancel) {}
    }
    .confirmationDialog(
      "Delete this board from every device?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      titleVisibility: .visible, presenting: deleting
    ) { board in
      Button("Delete \(board.title)", role: .destructive) { store.delete(board.id) }
    }
  }

  private func row(_ board: BoardEntry) -> some View {
    HStack(spacing: 0) {
      card(board)
      // Story 1097 (#1163): an iPhone has no conversation panel; the bubble opens the board's thread in Chat.
      if store.onPhone { chatBubble(board) }
    }
    // Tinted, not `role: .destructive`: that role takes the row away before the question is answered.
    .swipeActions {
      Button("Delete") { deleting = board }.tint(.red)
      // Story 836 (#916): the long press alone wasn't found.
      if store.editable(board) {
        Button("Rename") {
          newName = board.title
          renaming = board
        }
      }
    }
    .contextMenu {
      if store.editable(board) {
        Button {
          newName = board.title
          renaming = board
        } label: {
          Label("Rename", systemImage: "pencil")
        }
      }
      Button(role: .destructive) {
        deleting = board
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  private func card(_ board: BoardEntry) -> some View {
    Button {
      path.append(board.id)
    } label: {
      HStack(spacing: 12) {
        BoardPicture(url: store.pictureURL(board.id), version: store.pictures, paper: board.paper).frame(width: 120)
        VStack(alignment: .leading, spacing: 6) {
          Text(board.title).font(.headline).lineLimit(1)
          Text(subtitle(board)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        Spacer(minLength: 0)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("whiteboard-card")
  }

  /// Story 1097: quiet, its own 44-point target beside the card, so a tap on it never opens the board.
  private func chatBubble(_ board: BoardEntry) -> some View {
    Button {
      Task { await openChat(board) }
    } label: {
      Group {
        if findingChat == board.id {
          ProgressView()
        } else {
          Image(systemName: "bubble.left").foregroundStyle(.secondary)
        }
      }
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .disabled(findingChat != nil)
    .accessibilityLabel("Open \(board.title) in Chat")
    .accessibilityIdentifier("whiteboard-card-chat")
  }

  /// Story 1097: the board's thread wherever it was started, or why there is none, copyably.
  private func openChat(_ board: BoardEntry) async {
    guard findingChat == nil else { return }
    findingChat = board.id
    defer { findingChat = nil }
    chatProblem = nil
    let answer = await BoardThreadLookup.find(
      board: board.id, title: board.title, icloud: store.index.board(board.id)?.thread ?? board.thread,
      drawnHere: store.editable(board), cockpit: app.chat.cockpit, log: app.log, from: "list")
    switch answer {
    case .thread(let key):
      app.log.event(
        "jump",
        [
          "from": "list_bubble", "board": board.id, "to": "thread", "thread": key,
          "how": BoardChatJump.How.slidIn.rawValue, "through_list": false,
        ])
      listChat = ChatJump(thread: key)
    case .problem(let problem): chatProblem = problem
    case .busy: break
    }
  }

  private func subtitle(_ board: BoardEntry) -> String {
    let when = RelativeDateTimeFormatter().localizedString(
      for: Date(timeIntervalSince1970: Double(board.updated) / 1000), relativeTo: Date())
    guard store.editable(board) else { return "Changed \(when) · Drawn on \(board.deviceName)" }
    return board.onPages == true ? "Changed \(when) · On paper" : "Changed \(when)"
  }
}

/// A board's picture on its colour's pale shade, as the ink is dark whatever the mode; blank for an empty board.
private struct BoardPicture: View {
  let url: URL?
  /// Changes when a picture on disk does, so this one is read again.
  let version: Int
  let paper: BoardPaper

  var body: some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(Color(uiColor: UIColor(rgb: paper.light)))
      .overlay {
        if let url, let image = UIImage(contentsOfFile: url.path) {
          Image(uiImage: image).resizable().scaledToFit().padding(8)
        }
      }
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
      .aspectRatio(4 / 3, contentMode: .fit)
      .id(version)
  }
}
