//  Chat with Larry (spec 2026-10-25-native-chat-design.md): the list of threads, one thread as bubbles, and the bar
//  that writes to it. What is not on the Cockpit yet shows from this phone's outbox, marked Not sent yet.

import BugKit
import ContextCore
import QuickLook
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatListView: View {
  @ObservedObject var chat: ChatModel
  @ObservedObject var inbox: InboxModel
  /// #878: the open asks, for the rows' *Decision waiting* and the Decisions row.
  @ObservedObject var decisions: ChatDecisionsModel
  let voice: ChatVoiceModel
  let logger: BugLogger
  @State private var doneOpen = false
  /// #736: an iPad at full width and the Mac show each row's newest links; an iPhone's list is unchanged.
  @Environment(\.horizontalSizeClass) private var widthClass
  /// #1443, stories 1616-1618: the words in the list's search box and the Cockpit's part of the answer.
  @StateObject private var search: ChatThreadSearchModel

  init(chat: ChatModel, voice: ChatVoiceModel, logger: @escaping BugLogger) {
    self.chat = chat
    self.inbox = chat.inbox
    self.decisions = chat.decisions
    self.voice = voice
    self.logger = logger
    _search = StateObject(
      wrappedValue: ChatThreadSearchModel(log: chat.decisions.log, inbox: chat.inbox, cockpit: chat.cockpit))
  }

  /// #1443: while words are in the box, the matching threads stand in for the list's picker, rows and Done.
  @ViewBuilder private var searchResults: some View {
    if let problem = search.problem {
      BugProblemView(problem: problem, logger: logger)
    }
    Section {
      let rows = search.rows(chat.threads)
      ForEach(rows) { thread in threadLink(thread, terms: search.terms) }
      if rows.isEmpty && !search.searching {
        Text(ChatThreadSearch.noMatch).foregroundStyle(.secondary).accessibilityIdentifier("chat-search-empty")
      }
    }
  }

  /// The chats whose bead is an open ask (#878).
  private var waiting: Set<String> { ChatDecisions.waiting(chat.threads, asks: decisions.shown) }

  /// #878: *Decisions (N)*, under Larry's pinned thread; none with no open ask, or while ticking.
  @ViewBuilder private var decisionsRow: some View {
    if !decisions.shown.isEmpty && !selection.selecting {
      NavigationLink {
        ChatDecisionsView(chat: chat, voice: voice, logger: logger)
      } label: {
        ChatDecisionsRow(count: decisions.shown.count)
      }
      .accessibilityIdentifier("chat-decisions")
    }
  }

  private var live: [ChatSummary] { ChatListSelection.live(chat.threads) }
  private var done: [ChatSummary] { ChatListSelection.done(chat.threads) }
  /// The PRs a wide list's rows show as chips, for their states (#736, option C); none on a narrow list.
  private var listRefs: [String] {
    guard widthClass == .regular else { return [] }
    let shown = (live + (doneOpen ? done : [])).flatMap { (chat.rowLinks[$0.key] ?? []).prefix(ChatLinks.rowLimit) }
    return ChatPRStates.refs(shown)
  }
  /// Select and Review (#599): what ticks, what *Archive (N)* takes, what shows meanwhile (`ChatListSelection`).
  @State private var selection = ChatListSelection()
  /// Bead context-grabber-qp3m: *All* or *New*, remembered on this device.
  @AppStorage(ChatInboxFilter.defaultsKey) private var inboxSaved = ChatInboxFilter.all.rawValue
  private var inboxFilter: ChatInboxFilter { ChatInboxFilter.restored(inboxSaved) }
  /// The chat open from this list: *New* keeps its row until the list is back on screen.
  @State private var openKey: String?
  /// Story 1138 (#1258): the chat opened from a ticking row; the ticks stay as they were behind it.
  @State private var peekKey: String?
  /// GRABBER_CHAT_SELECT=archive: once the list is read, *Review* and *Archive (N)* tap themselves, for the simulator.
  @State private var selectHook = LaunchHooks.current.chat.selectArchive

  var body: some View {
    List {
      if inbox.offline {
        Text("No network — what you write goes to Larry when you're back online").font(.footnote)
          .foregroundStyle(.secondary)
      }
      if inbox.store == nil {
        BugProblemView(
          problem: .grabber(
            "This build has no App Group, so nothing shared can reach Chat.", context: "ChatListView.load", extra: [:]),
          logger: logger)
      }
      if let problem = chat.archiveProblem {
        BugProblemView(
          problem: .grabber(problem, context: "ChatListView.archive", extra: ["cockpit": .string(chat.cockpit)]),
          logger: logger)
      }
      if let line = ChatArchiver.undoLine(chat.undoArchive) {
        let undo = chat.undoArchive
        HStack {
          Text(line).lineLimit(1)
          Spacer()
          Button("Undo") {
            Task { await chat.setArchived(undo.map(\.key), false, from: "undo") }
          }
          .accessibilityIdentifier("chat-archive-undo")
        }
        .font(.footnote)
      }
      if let line = selection.reviewLine(chat.threads) {
        HStack {
          Text(line)
          Spacer()
          Button("Review") { review(from: "looks_done") }
            .accessibilityIdentifier("chat-review-done")
        }
        .font(.footnote)
      }
      if let problem = chat.listProblem, !inbox.offline {
        BugProblemView(
          problem: .grabber(
            problem, context: "ChatListView.refresh", extra: ["cockpit": .string(chat.cockpit)],
            autoFile: !chat.listQuiet),
          logger: logger)
      }
      if !chat.pendingThreads.isEmpty {
        Section("Not sent yet") {
          ForEach(chat.pendingThreads) { item in
            PendingThreadRow(
              item: item, inbox: inbox, thumbnail: inbox.thumbnails[item.id], away: inbox.cockpitAway && !inbox.offline,
              logger: logger
            )
            .swipeActions { Button("Delete", role: .destructive) { inbox.delete(item) } }
          }
        }
      }
      if search.active && !selection.selecting {
        searchResults
      } else {
        if !selection.selecting && !chat.threads.isEmpty {
          Picker("Show", selection: Binding(get: { inboxFilter }, set: { showInbox($0) })) {
            ForEach(ChatInboxFilter.allCases, id: \.self) { Text($0.title).tag($0) }
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("chat-inbox-filter")
        }
        if selection.selecting {
          // Bead context-grabber-szom: Review opens on what looks done, Select on every live thread; ticks stay put.
          Picker("Show", selection: Binding(get: { selection.filter }, set: { showFilter($0) })) {
            ForEach(ChatListSelection.Filter.allCases, id: \.self) { Text($0.title).tag($0) }
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("chat-select-filter")
        }
        Section {
          let rows = selection.rows(chat.threads, inbox: inboxFilter, keeping: openKey)
          let decisionsAfter = ChatDecisions.rowAfter(rows)
          if decisionsAfter == nil { decisionsRow }
          ForEach(rows) { thread in
            if selection.selecting { tickRow(thread) } else { threadLink(thread) }
            if thread.key == decisionsAfter { decisionsRow }
          }
          if let line = selection.emptyLine(chat.threads, inbox: inboxFilter, keeping: openKey) {
            Text(line).foregroundStyle(.secondary).accessibilityIdentifier("chat-select-empty")
          }
        }
        if selection.showsDone(chat.threads, inbox: inboxFilter) {
          Section {
            DisclosureGroup("Done (\(done.count))", isExpanded: $doneOpen) {
              ForEach(done) { thread in threadLink(thread) }
            }
          }
        }
      }
      if !chat.earlierShares.isEmpty {
        Section {
          NavigationLink("Earlier shares (\(chat.earlierShares.count))") {
            EarlierSharesView(inbox: inbox, logger: logger)
          }
          .accessibilityIdentifier("chat-earlier-shares")
        }
      }
      if chat.threads.isEmpty && chat.pendingThreads.isEmpty && chat.listProblem == nil {
        Text("No chats yet. Tap + to start one, or share to Grabber Native from another app.")
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Chat")
    // Inline: the large title drew over the first row once the list had a problem row above it (simulator).
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("chat-list")
    .searchable(text: $search.query, prompt: ChatThreadSearch.prompt)
    .onChange(of: search.query) { search.changed(chat.threads) }
    .refreshable { await chat.refreshList(reason: "pull") }
    .task {
      await chat.refreshList(reason: "open")
      if selectHook {
        selectHook = false
        review(from: "hook")
        archivePicked()
      }
    }
    .onAppear {
      chat.listOnScreen = true
      openKey = nil
    }
    .onDisappear {
      chat.listOnScreen = false
      chat.viewGone()
    }
    .task(id: listRefs) { await chat.watchPRStates(listRefs, from: "list") }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(selection.toggleTitle) {
          if selection.toggle() { chat.logAction("select", ["from": "toolbar"]) }
        }
        .disabled(!selection.canToggle(chat.threads))
        .accessibilityIdentifier("chat-select")
      }
    }
    // #424, story 262: a fixed thumb target. #685, story 506: floating, so the list has the whole screen; its margin lets
    // the last row scroll clear of them.
    .contentMargins(.bottom, 76, for: .scrollContent)
    .overlay(alignment: .bottomTrailing) {
      HStack(spacing: 12) {
        NewChatVoiceButton(chat: chat, voice: voice)
        Button {
          chat.openNewChat(from: "chat")
        } label: {
          NewChatCircle(systemName: "plus", color: .accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New chat")
        .accessibilityIdentifier("inbox-add")
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
      }
      .padding([.horizontal, .bottom], 16)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("chat-new-bar")
    }
    .safeAreaInset(edge: .bottom) {
      if selection.selecting {
        Button(selection.archiveTitle(chat.threads)) { archivePicked() }
          .buttonStyle(.borderedProminent)
          .disabled(!selection.canArchive(chat.threads))
          .padding(.bottom, 8)
          .accessibilityIdentifier("chat-archive-selected")
      }
    }
    .navigationDestination(isPresented: $chat.newChatOpen) {
      ChatThreadView(newChat: chat, voice: voice, logger: logger)
    }
    .navigationDestination(
      isPresented: Binding(get: { peekKey != nil }, set: { if !$0 { peekKey = nil } })
    ) {
      if let key = peekKey {
        ChatThreadView(chat: chat, voice: voice, key: key, title: chat.title(of: key), logger: logger)
      }
    }
    .navigationDestination(
      isPresented: Binding(get: { chat.linkThread != nil }, set: { if !$0 { chat.linkThread = nil } })
    ) {
      if let key = chat.linkThread {
        ChatThreadView(chat: chat, voice: voice, key: key, title: chat.title(of: key), logger: logger)
      }
    }
    // Story 744: a wide row's Inbox chip opens its thread here too.
    .environment(
      \.openURL,
      OpenURLAction { url in
        switch ChatCockpitLink.jump(url, from: nil, known: Set(chat.threads.map(\.key))) {
        case .thread(let key):
          chat.linkThread = key
          return .handled
        case .web(let page): return .systemAction(page)
        case .here, nil: return .systemAction
        }
      }
    )
    .chatTextSize()
  }

  private func review(from: String) {
    let count = selection.review(chat.threads)
    chat.logAction("select", ["from": from, "count": count])
  }

  private func showInbox(_ filter: ChatInboxFilter) {
    guard filter != inboxFilter else { return }
    inboxSaved = filter.rawValue
    chat.logAction("inbox_filter", ["filter": filter.rawValue])
  }

  private func showFilter(_ filter: ChatListSelection.Filter) {
    guard filter != selection.filter else { return }
    selection.show(filter)
    chat.logAction("select_filter", ["filter": filter.rawValue])
  }

  private func archivePicked() {
    // #1098, story 314: a Review's proposals left unticked are turned down, so the next Review doesn't offer them again.
    chat.declineLooksDone(selection.declined(chat.threads), from: "review")
    let keys = selection.archivePicked(chat.threads)
    Task { await chat.archiveSelected(keys) }
  }

  private func tickRow(_ thread: ChatSummary) -> some View {
    let ticked = selection.ticked(thread.key)
    return HStack(alignment: .center, spacing: 8) {
      Button {
        selection.tick(thread.key)
      } label: {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(ticked ? Color.accentColor : .secondary)
          ThreadRow(thread: thread, decisionWaiting: waiting.contains(thread.key))
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("chat-tick-\(thread.key)")
      .accessibilityValue(ticked ? "ticked" : "not ticked")
      .accessibilityLabel(ticked ? "Ticked: \(thread.title)" : thread.title)
      // Story 1138 (#1258): the hold Igor reached for opens the chat; the ticks wait behind it.
      .contextMenu {
        Button("Open chat", systemImage: "bubble.left.and.text.bubble.right") { peek(thread, from: "hold") }
      }
      Button {
        peek(thread, from: "arrow")
      } label: {
        Image(systemName: "chevron.right.circle").imageScale(.large).foregroundStyle(.secondary)
          .frame(minWidth: 32, minHeight: 32)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Open chat")
      .accessibilityIdentifier("chat-tick-open-\(thread.key)")
    }
  }

  /// Story 1138 (#1258): a ticking row's chat, opened as from the list; Back returns to the same ticks.
  private func peek(_ thread: ChatSummary, from: String) {
    openKey = thread.key
    peekKey = thread.key
    chat.logAction("select_open_chat", ["thread": thread.key, "from": from, "ticked": selection.ticked(thread.key)])
  }

  private func threadLink(_ thread: ChatSummary, terms: [String] = []) -> some View {
    NavigationLink {
      ChatThreadView(chat: chat, voice: voice, key: thread.key, title: thread.title, logger: logger)
        .onAppear {
          openKey = thread.key
          if !terms.isEmpty { search.opened(thread.key) }
        }
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        ThreadRow(thread: thread, decisionWaiting: waiting.contains(thread.key), terms: terms)
        // Borderless chips take their own taps; the rest of the row still opens the thread.
        if widthClass == .regular, let links = chat.rowLinks[thread.key], !links.isEmpty {
          RowLinks(chat: chat, thread: thread.key, links: chat.withStates(links)).padding(.leading, 19)
        }
      }
      .task(id: "\(thread.lastTs) \(inbox.offline)") { if widthClass == .regular { await chat.readRowLinks(thread) } }
    }
    .accessibilityIdentifier("chat-thread-\(thread.key)")
    // #589: a swipe left archives a live thread, or brings back an archived one.
    .swipeActions {
      switch ChatArchiveAction.swipe(thread) {
      case .unarchive:
        Button("Unarchive") { Task { await chat.setArchived(thread.key, false, from: "swipe") } }.tint(.blue)
      case .archive:
        Button("Archive") { Task { await chat.setArchived(thread.key, true, from: "swipe") } }.tint(.indigo)
      case nil: EmptyView()
      }
    }
    // #1098, story 1120: a swipe from the leading edge turns Larry's *Looks done* down; the thread stays live.
    .swipeActions(edge: .leading) {
      if ChatLooksDoneSwipe.offers(thread) {
        Button("Not done") { chat.declineLooksDone([thread.key], from: "swipe") }.tint(.orange)
      }
    }
  }
}

/// One of the two round thumb targets at the list's lower right.
private struct NewChatCircle: View {
  let systemName: String
  let color: Color

  var body: some View {
    Image(systemName: systemName)
      .font(.title2.weight(.semibold))
      .foregroundStyle(.white)
      .frame(width: 56, height: 56)
      .background(color, in: Circle())
      .contentShape(Circle())
  }
}

/// A new chat already recording (#637, story 500). Its own view so only it redraws with the dictation; dimmed during a
/// call, when a tap still opens the new chat, whose bar says why nothing records (story 503).
private struct NewChatVoiceButton: View {
  let chat: ChatModel
  @ObservedObject var voice: ChatVoiceModel

  var body: some View {
    Button {
      chat.openNewChat(from: "chat", voice: true)
    } label: {
      NewChatCircle(systemName: "mic.fill", color: voice.callLive ? .secondary : .accentColor)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("New chat by voice")
    .accessibilityIdentifier("inbox-add-voice")
    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
  }
}

private struct ThreadRow: View {
  let thread: ChatSummary
  /// #878: the thread's bead is an open ask.
  var decisionWaiting = false
  /// #1443: a search's words, marked in the title and the message line; none outside a search.
  var terms: [String] = []

  private func text(_ s: String) -> Text {
    terms.isEmpty ? Text(s) : Text(ChatAskHitRow.marked(s, terms))
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Circle().fill(thread.unread > 0 ? Color.accentColor : .clear).frame(width: 9, height: 9).padding(.top, 6)
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline) {
          if thread.pinned {
            Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary).accessibilityLabel("Pinned")
          }
          text(thread.title).font(.body.weight(thread.unread > 0 ? .semibold : .regular)).lineLimit(2)
          Spacer(minLength: 8)
          if let at = thread.lastAt {
            Text(at, format: .relative(presentation: .numeric, unitsStyle: .abbreviated)).font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        text(thread.lastLine)
          .font(.subheadline)
          .foregroundStyle(.secondary).lineLimit(2)
        if decisionWaiting {
          Label("Decision waiting", systemImage: "questionmark.bubble").font(.caption).foregroundStyle(.orange)
        }
        if thread.showsLooksDone {
          Label("Looks done", systemImage: "checkmark.seal").font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Links in a thread (#736)

/// One link as a chip: a tap opens it where iOS opens that link.
private struct LinkChip: View {
  let link: ChatLink
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      HStack(spacing: 4) {
        Image(systemName: icon).foregroundStyle(tint ?? Color.accentColor)
        Text(link.label)
        if let state = link.state { Text(state.rawValue).foregroundStyle(tint ?? .secondary) }
      }
      .font(.caption.weight(.medium))
      .lineLimit(1)
      .padding(.horizontal, 10).padding(.vertical, 5)
      .background(Color(.tertiarySystemFill), in: Capsule())
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(link.chipText)
    .accessibilityHint(ChatLinks.address(link))
    .accessibilityIdentifier("chat-link-chip")
    .accessibilityValue(link.state?.rawValue ?? "")
  }

  /// Story 554: a PR's state in GitHub's colours; nil while it is unknown, and for any other link.
  private var tint: Color? {
    switch link.state {
    case .open: return .green
    case .draft: return .gray
    case .merged: return .purple
    case .closed: return .red
    case nil: return nil
    }
  }

  private var icon: String {
    switch link.kind {
    case .pullRequest: return "arrow.triangle.pull"
    case .gist: return "doc.text"
    case .web: return "link"
    case .inbox: return "tray"
    case .install: return "arrow.down.app"
    }
  }
}

/// Stories 549-552: the thread's links under its title, folded or not as this thread was left.
private struct ThreadLinksStrip: View {
  @ObservedObject var chat: ChatModel
  let thread: String
  let links: [ChatLink]
  @State private var allOpen = false
  /// GRABBER_CHAT_LINKS=fold / all: once the strip shows, *Links* or *All links* taps itself, for the simulator.
  @State private var linksHook = LaunchHooks.current.chat.links
  @Environment(\.openURL) private var openURL

  private var folded: Bool { chat.foldedLinks.contains(thread) }

  var body: some View {
    if !links.isEmpty {
      let strip = ChatLinks.strip(links)
      HStack(spacing: 8) {
        Button {
          chat.setLinksFolded(thread, !folded)
        } label: {
          Label(folded ? "Links (\(links.count))" : "Links", systemImage: folded ? "chevron.right" : "chevron.down")
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("chat-links-fold")
        .accessibilityValue(folded ? "folded" : "unfolded")
        if !folded {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              ForEach(strip.shown) { link in
                LinkChip(link: link) { open(link, from: "strip") }
              }
              if strip.more > 0 {
                Button("All links (\(links.count))") { allOpen = true }
                  .font(.caption.weight(.semibold))
                  .buttonStyle(.borderless)
                  .accessibilityIdentifier("chat-links-all")
              }
            }
          }
        } else {
          Spacer()
        }
      }
      .padding(.horizontal, 12).padding(.vertical, 6)
      .background(Color(.systemBackground).opacity(0.95))
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("chat-links")
      .sheet(isPresented: $allOpen) {
        AllLinksView(links: links) { open($0, from: "all") }
      }
      .task { runLinksHook() }
      .task(id: ChatPRStates.refs(links)) { await chat.watchPRStates(ChatPRStates.refs(links), from: "thread") }
    }
  }

  private func runLinksHook() {
    guard let hook = linksHook else { return }
    linksHook = nil
    switch hook {
    case "fold": chat.setLinksFolded(thread, !folded)
    case "all": allOpen = true
    default: break
    }
  }

  private func open(_ link: ChatLink, from place: String) {
    chat.logLinkOpened(link, thread: thread, from: place)
    openURL(link.url)
  }
}

/// Story 551: every link in the thread, newest first.
private struct AllLinksView: View {
  let links: [ChatLink]
  let open: (ChatLink) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List(links) { link in
        Button {
          dismiss()
          open(link)
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(link.chipText).font(.body)
            Text(ChatLinks.address(link)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
          }
        }
      }
      .navigationTitle("All links (\(links.count))")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
      .accessibilityIdentifier("chat-links-all-list")
    }
  }
}

/// Story 553: a wide list's row shows its thread's newest few links.
private struct RowLinks: View {
  let chat: ChatModel
  let thread: String
  let links: [ChatLink]
  @Environment(\.openURL) private var openURL

  var body: some View {
    HStack(spacing: 6) {
      ForEach(links.prefix(ChatLinks.rowLimit)) { link in
        LinkChip(link: link) {
          chat.logLinkOpened(link, thread: thread, from: "list")
          openURL(link.url)
        }
      }
    }
  }
}

/// What a refusal's copied problem carries; a file's name says which one it was (story 487).
private func refusalExtra(_ item: InboxItem) -> [String: JSONValue] {
  var extra: [String: JSONValue] = [
    "item": .string(item.id), "kind": .string(item.kind.rawValue), "thread": .string(item.thread ?? ""),
  ]
  if let name = item.fileName { extra["file"] = .string(name) }
  return extra
}

/// Story 488: a refused file goes again, the same message.
private struct SendAgainButton: View {
  let item: InboxItem
  let inbox: InboxModel

  var body: some View {
    if item.canSendAgain {
      Button("Send again") { inbox.sendAgain(item) }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("chat-send-again")
    }
  }
}

private struct PendingThreadRow: View {
  let item: InboxItem
  let inbox: InboxModel
  let thumbnail: CGImage?
  /// #565: the last send found the Cockpit not answering.
  let away: Bool
  let logger: BugLogger
  private var notSent: String { away ? "Not sent yet · the Cockpit isn't answering" : "Not sent yet" }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .top) {
        if let thumbnail {
          Image(decorative: thumbnail, scale: 1).resizable().scaledToFill().frame(width: 44, height: 44).clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(ChatSend.title(for: item)).lineLimit(2)
          if item.status == .waiting { Text(notSent).font(.caption).foregroundStyle(.orange) }
        }
      }
      if item.status == .refused {
        BugProblemView(
          problem: .grabber(ChatSend.refusal(of: item), context: "ChatListView.send", extra: refusalExtra(item)),
          logger: logger)
        SendAgainButton(item: item, inbox: inbox)
      }
    }
    .accessibilityIdentifier("chat-pending-\(item.status)")
  }
}

// MARK: - One thread

struct ChatThreadView: View {
  @ObservedObject var chat: ChatModel
  @ObservedObject var inbox: InboxModel
  let voice: ChatVoiceModel
  private let fixedKey: String?
  private let fixedTitle: String
  let logger: BugLogger
  /// A new chat (#536): the first message it follows (a fresh id per attempt) and the thread it landed in.
  @State private var newThread = ChatNewThread()
  /// A new chat's own name for the bar and the mic, the same across attempts and after it lands.
  @State private var screenID = UUID().uuidString.lowercased()
  /// Why the last Yes or No could not be kept on the phone (#629).
  @State private var reactionProblem: BugProblem?
  /// A message whose Quote in reply was tapped: the bar takes it (#629).
  @State private var quoting: ChatMessage?
  /// Why the last Send to new chat didn't take (context-grabber-9yo); the message stays where it was.
  @State private var moveProblem: BugProblem?
  /// GRABBER_CHAT_HOLD=yes / no / quote / copy: that choice taps itself on Larry's newest message, for the simulator;
  /// new-chat: *Send to new chat* on Igor's newest, the only ones that offer it.
  @State private var holdHook = LaunchHooks.current.chat.hold
  /// A Cockpit thread link tapped in a bubble (story 744): that thread, pushed over this one.
  @State private var jumpTo: String?
  /// #1091: *Board* is asking iCloud for the thread's board, and why the last tap couldn't open it.
  @State private var lookingForBoard = false
  @State private var boardProblem: BugProblem?
  /// Bead context-grabber-dbku: the board slid in over this thread by *Board* or a picture's *Jump to board*.
  @State private var boardJump: BoardJump?
  /// Story 1603: the thread's height, which bounds its decision card.
  @State private var threadHeight: CGFloat = 0
  @Environment(\.dismiss) private var dismiss
  /// Story 1207: the board this thread was slid in over, so *Board* on it goes back rather than opening a second copy.
  private var cameFromBoard: String?
  /// Story 1223: the boards set aside under this thread, told when it comes and goes.
  private var under = BoardsUnder()

  init(
    chat: ChatModel, voice: ChatVoiceModel, key: String, title: String, logger: @escaping BugLogger,
    cameFromBoard: String? = nil, under: BoardsUnder = BoardsUnder()
  ) {
    self.chat = chat
    self.inbox = chat.inbox
    self.voice = voice
    self.fixedKey = key
    self.fixedTitle = title
    self.logger = logger
    self.cameFromBoard = cameFromBoard
    self.under = under
  }

  /// The + (#536): an empty thread with the ordinary bar; its first Send starts the thread.
  init(newChat chat: ChatModel, voice: ChatVoiceModel, logger: @escaping BugLogger) {
    self.chat = chat
    self.inbox = chat.inbox
    self.voice = voice
    self.fixedKey = nil
    self.fixedTitle = "New chat"
    self.logger = logger
  }

  private var key: String? { newThread.key(fixedKey: fixedKey) }
  /// A new chat's latest first message while it is still only on the phone.
  private var first: InboxItem? { newThread.first(in: inbox.items) }
  private var messages: [ChatMessage] { key.flatMap { chat.messages[$0] } ?? [] }
  private var answeredBy: String { chat.answeredBy(key) }
  private var pending: [InboxItem] {
    newThread.pending(fixedKey: fixedKey, items: inbox.items, messages: chat.messages)
  }
  /// A new chat takes its first message's first line as the title, as the Cockpit will.
  private var title: String {
    newThread.title(fixedKey: fixedKey, fixedTitle: fixedTitle, threads: chat.threads, first: first)
  }
  private var target: ChatNewThread.Target {
    ChatNewThread.target(fixedKey: fixedKey, landed: newThread.landed, first: first)
  }
  /// The bar's and the mic's name for this screen, the same before and after a new chat lands.
  private var barKey: String { fixedKey ?? "new-" + screenID }

  var body: some View {
    ScrollViewReader { reader in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if let key, let problem = chat.threadProblem[key], !inbox.offline {
            BugProblemView(
              problem: .grabber(
                problem, context: "ChatThreadView.load", extra: ["thread": .string(key)],
                autoFile: !chat.threadQuiet.contains(key)),
              logger: logger)
          }
          if let key,
            ChatThreadLoading.shows(
              read: chat.messages[key] != nil, pending: pending.count,
              problem: chat.threadProblem[key] != nil, offline: inbox.offline)
          {
            // Story 1608 (#1362): a slow first read showed a blank page for as long as it took to time out.
            HStack(spacing: 8) {
              ProgressView()
              Text(ChatThreadLoading.words).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("chat-thread-loading")
            .onAppear { logger("chat", ["action": "thread_loading_shown", "thread": .string(key)]) }
          }
          let answerFailed = ChatWire.answerFailed(messages)
          let group = ChatSpeaker.isGroup(messages)
          ForEach(messages) { message in
            MessageBubble(
              message: message, thread: key ?? "", answerFailed: answerFailed.contains(message.id), group: group,
              chat: chat,
              logger: logger, react: { react($0, to: message) }, quote: { quote(message) }, copy: { copy(message) },
              sendToNewChat: { sendToNewChat(message) }, openMoved: openMoved)
          }
          // Their own ids: a message that reaches the Cockpit keeps its id, and a shared one in this LazyVStack
          // left the outbox bubble on screen after the Cockpit's had replaced it (seen on the simulator).
          ForEach(pending, id: \.pendingKey) { item in
            PendingBubble(
              item: item, inbox: inbox, thumbnail: inbox.thumbnails[item.id], away: inbox.cockpitAway && !inbox.offline,
              answeredBy: answeredBy, logger: logger
            )
            .contextMenu {
              Button("Delete", role: .destructive) { inbox.delete(item) }
            }
          }
          Color.clear.frame(height: 1).id("bottom")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
      }
      .defaultScrollAnchor(.bottom)
      .onChange(of: messages.count + pending.count) { _, _ in
        withAnimation { reader.scrollTo("bottom", anchor: .bottom) }
      }
    }
    // Not in the scroll view: it opens at the newest message, so a long thread would hide this.
    .safeAreaInset(edge: .top) {
      VStack(spacing: 0) {
        if let key {
          // #878: the ask whose bead this thread is, pinned above the links.
          ChatDecisionSlot(
            decisions: chat.decisions, key: key, voice: voice, logger: logger,
            bodyCap: ChatDecisions.threadCardBodyCap(threadHeight: threadHeight).map { CGFloat($0) })
          ThreadLinksStrip(chat: chat, thread: key, links: chat.withStates(chat.rowLinks[key] ?? []))
        }
        if let problem = chat.archiveProblem {
          BugProblemView(
            problem: .grabber(problem, context: "ChatThreadView.archive", extra: ["cockpit": .string(chat.cockpit)]),
            logger: logger
          )
          .padding(.horizontal, 12)
          .background(Color(.systemGroupedBackground))
        }
        if let reactionProblem {
          BugProblemView(problem: reactionProblem, logger: logger)
            .padding(.horizontal, 12)
            .background(Color(.systemGroupedBackground))
        }
        if let moveProblem {
          BugProblemView(problem: moveProblem, logger: logger)
            .padding(.horizontal, 12)
            .background(Color(.systemGroupedBackground))
        }
        if let boardProblem {
          BugProblemView(problem: boardProblem, logger: logger)
            .padding(.horizontal, 12)
            .background(Color(.systemGroupedBackground))
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      ComposeBar(
        chat: chat, voice: voice, thread: barKey, target: target, answeredBy: answeredBy, logger: logger, first: first,
        quoting: $quoting
      ) {
        newThread.send(at: target)
      }
    }
    .onGeometryChange(for: CGFloat.self) {
      $0.size.height
    } action: {
      threadHeight = $0
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if let board = threadBoard {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            openBoard(board)
          } label: {
            Label(lookingForBoard ? "Looking for the board…" : "Board", systemImage: "pencil.and.scribble")
              .labelStyle(.titleAndIcon)
          }
          .disabled(lookingForBoard)
          .accessibilityIdentifier("chat-thread-board")
        }
      }
      if let key, let action = chat.threads.first(where: { $0.key == key }).flatMap(ChatArchiveAction.menu) {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            if action == .unarchive {
              Button("Unarchive chat", systemImage: "tray.and.arrow.up") {
                Task { await chat.setArchived(key, false, from: "menu") }
              }
            } else {
              Button("Archive chat", systemImage: "archivebox") {
                Task { await chat.setArchived(key, true, from: "menu") }
                dismiss()
              }
            }
          } label: {
            Label("More", systemImage: "ellipsis.circle")
          }
          .accessibilityIdentifier("chat-thread-more")
        }
      }
    }
    // No identifier on the whole screen: SwiftUI hands it down over a contained element's own, and the decision
    // card's `decision-card-<id>` read as `chat-thread` (#878, on the simulator).
    .onAppear {
      under.appeared(screenID)
      if fixedKey == nil { chat.newChatScreen(shown: true, landed: key) }
      if let key { chat.open(key) }
    }
    .onDisappear {
      if fixedKey == nil { chat.newChatScreen(shown: false, landed: key) }
      if let key { chat.close(key) }
      chat.viewGone()
      under.left(screenID)
    }
    // A new chat becomes its thread once the Cockpit has the first message: the same screen, now live.
    .onChange(of: first?.chatThread) { _, thread in
      if let landed = newThread.firstMoved(to: thread) { chat.open(landed) }
    }
    .onChange(of: messages.last?.id, initial: true) { runHoldHook() }
    .navigationDestination(item: $jumpTo) { target in
      ChatThreadView(
        chat: chat, voice: voice, key: target, title: chat.title(of: target), logger: logger, under: under)
    }
    .navigationDestination(item: $boardJump) { jump in
      if let screen = chat.boardScreen(jump.board, key, under) { screen }
    }
    .environment(\.jumpToBoard, { board, from in go(toBoard: board, from: from) })
    // Story 744: an Inbox chip, in a bubble or the strip above, opens its thread here; any other link as ever.
    .environment(\.openURL, OpenURLAction(handler: openInApp))
    .chatTextSize()
  }

  /// #1091, story 1125: the board this thread belongs to, for *Board* in the bar.
  private var threadBoard: ChatThreadBoard? {
    ChatThreadBoard.find(thread: key, messages: messages, deviceThreads: WhiteboardThreads().all())
  }

  /// Stories 1122, 1123: iCloud is asked first, as for a picture's *Jump to board*; a board that can't open says why here.
  private func openBoard(_ found: ChatThreadBoard) {
    lookingForBoard = true
    boardProblem = nil
    let started = ProcessInfo.processInfo.systemUptime
    Task {
      let problem = await chat.findBoard(found.board, "ChatThreadView.openBoard")
      lookingForBoard = false
      logger(
        "ui",
        [
          "action": "thread_open_board", "thread": .string(key ?? ""), "board": .string(found.board),
          "via": .string(found.source.rawValue), "found": .string(problem == nil ? "yes" : "no"),
          "ms": .int(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)),
        ])
      boardProblem = problem
      if problem == nil { go(toBoard: found.board, from: "thread_board") }
    }
  }

  /// Bead context-grabber-dbku: a found board slides in over this thread, or, when it is the board this thread was
  /// slid over, this thread goes back to it; a board open elsewhere is brought forward as a link brings it.
  private func go(toBoard board: String, from: String) {
    let how = BoardChatJump.how(
      .board(board), cameFrom: cameFromBoard.map(BoardChatJump.Target.board),
      openElsewhere: chat.boardOpenElsewhere(board))
    logger(
      "jump",
      [
        "from": .string(from), "thread": .string(key ?? ""), "to": "board", "board": .string(board),
        "how": .string(how.rawValue), "through_list": .bool(how.throughList),
      ])
    switch how {
    case .wentBack: dismiss()
    case .broughtForward: chat.openBoard(board)
    case .slidIn: boardJump = BoardJump(board: board)
    }
  }

  /// Story 744: a Cockpit thread the list knows opens here, an unknown one on the Cockpit; any other link as before.
  private func openInApp(_ url: URL) -> OpenURLAction.Result {
    guard let jump = ChatCockpitLink.jump(url, from: key, known: Set(chat.threads.map(\.key))) else {
      return .systemAction
    }
    switch jump {
    case .here:
      chat.logAction("cockpit_link", ["thread": key ?? "", "opened": "here"])
      return .handled
    case .thread(let target):
      chat.logAction("cockpit_link", ["thread": key ?? "", "opened": "app"])
      jumpTo = target
      return .handled
    case .web(let page):
      chat.logAction("cockpit_link", ["thread": key ?? "", "opened": "browser"])
      return .systemAction(page)
    }
  }

  private func runHoldHook() {
    guard let choice = holdHook.flatMap(ChatHold.init(hook:)) else { return }
    let mine = choice == .sendToNewChat
    guard let message = messages.last(where: { $0.fromIgor == mine && !$0.isSystem }) else { return }
    holdHook = nil
    switch choice {
    case .quote: quote(message)
    case .copy: copy(message)
    case .react(let reaction): react(reaction, to: message)
    case .sendToNewChat: sendToNewChat(message)
    }
  }

  private func quote(_ message: ChatMessage) {
    quoting = message
    logHeld("quote", message)
  }

  private func copy(_ message: ChatMessage) {
    UIPasteboard.general.string = message.text
    logHeld("copy", message)
  }

  private func logHeld(_ action: String, _ message: ChatMessage) {
    guard let key else { return }
    chat.logAction(action, ["thread": key, "message": message.id])
  }

  /// Send to new chat (context-grabber-9yo): the message moves to a chat of its own, which opens over this one. A
  /// refusal leaves it here and says why.
  private func sendToNewChat(_ message: ChatMessage) {
    guard let key else { return }
    Task {
      switch await chat.sendToNewChat(message, from: key) {
      case .moved(let thread, _):
        moveProblem = nil
        jumpTo = thread
      case .refused(let why):
        moveProblem = .grabber(
          ChatMove.problem(why), context: "ChatThreadView.sendToNewChat",
          extra: ["thread": .string(key), "message": .string(message.id), "cockpit": .string(chat.cockpit)])
      case nil: break
      }
    }
  }

  /// The old chat's *Moved to a new chat* line: its new chat, over this one.
  private func openMoved(_ thread: String) {
    chat.logAction("moved_link", ["thread": key ?? "", "to": thread])
    jumpTo = thread
  }

  /// Yes or No, sent at once as an ordinary message (#629). The bar's draft is left alone.
  private func react(_ reaction: ChatReaction, to message: ChatMessage) {
    guard let key else { return }
    // Something still on its way is newer than anything the Cockpit shows.
    let newest = pending.isEmpty && messages.last(where: { !$0.isSystem })?.id == message.id
    var draft = InboxDraft()
    draft.text = reaction.text(answering: message, newest: newest)
    do {
      try chat.send(&draft, thread: key)
      reactionProblem = nil
      chat.logAction(
        "reaction", ["reaction": reaction.rawValue, "thread": key, "message": message.id, "newest": newest])
    } catch {
      reactionProblem = .grabber(
        "Your \(reaction.label) could not be kept on the phone: \(error.localizedDescription)",
        context: "ChatThreadView.react",
        extra: ["thread": .string(key), "message": .string(message.id), "reaction": .string(reaction.rawValue)])
      chat.logReactionFailure(error, reaction: reaction, thread: key, message: message.id)
    }
  }
}

private struct MessageBubble: View {
  let message: ChatMessage
  let thread: String
  /// A failure is all that followed it (#632): its receipt doesn't say done.
  let answerFailed: Bool
  /// Story 1614: more than one speaker besides Igor, so every reply says who wrote it.
  let group: Bool
  let chat: ChatModel
  let logger: BugLogger
  let react: (ChatReaction) -> Void
  let quote: () -> Void
  let copy: () -> Void
  let sendToNewChat: () -> Void
  /// A *Moved to a new chat* line's tap: that chat.
  let openMoved: (String) -> Void

  var body: some View {
    if let line = ChatMove.line(message) {
      systemLine(line)
    } else if message.isError {
      failure
    } else {
      bubble
    }
  }

  /// The Cockpit's own line (Send to new chat): quiet and centred, a link when it names the new chat.
  private func systemLine(_ line: ChatMove.Line) -> some View {
    HStack {
      Spacer(minLength: 0)
      if let moved = line.opens {
        Button {
          openMoved(moved)
        } label: {
          Label(line.words, systemImage: "arrowshape.turn.up.right")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("chat-moved")
      } else {
        Text(line.words).foregroundStyle(.secondary).accessibilityIdentifier("chat-system")
      }
      Spacer(minLength: 0)
    }
    .font(.caption)
    .padding(.vertical, 2)
  }

  /// The speaker's name and letter over what they wrote: always for a skill (#632) and for Tony, and for every
  /// reply in a group chat (story 1614), Larry's in his purple. A two-party thread with Larry shows none.
  @ViewBuilder private var byline: some View {
    let speaker = ChatSpeaker.of(message)
    if !message.fromIgor, speaker.tone != .agent || group {
      HStack(spacing: 6) {
        Text(speaker.initial).font(.caption.weight(.semibold)).foregroundStyle(.white)
          .frame(width: 22, height: 22)
          .background(Color.speaker(speaker.tone), in: Circle())
          .accessibilityHidden(true)
        Text(speaker.label).font(.caption.weight(.semibold))
          .foregroundStyle(speaker.tone == .agent ? Color.larry : Color.secondary)
      }
      .accessibilityIdentifier("chat-byline-\(speaker.tone.rawValue)")
    }
  }

  /// Why the skill could not answer, copyable; the Cockpit's own words.
  private var failure: some View {
    VStack(alignment: .leading, spacing: 4) {
      byline
      BugProblemView(
        problem: .grabber(
          message.text, context: "ChatThreadView.skillReply",
          extra: [
            "thread": .string(thread), "message": .string(message.id),
            "skill": .string(ChatSpeaker.skillAuthor(message) ?? ""), "ts": .string(message.ts),
          ]), logger: logger)
    }
  }

  private var bubble: some View {
    HStack {
      if message.fromIgor { Spacer(minLength: 48) }
      VStack(alignment: message.fromIgor ? .trailing : .leading, spacing: 4) {
        byline
        ForEach(message.attachments, id: \.self) { ref in
          if let url = ChatWire.attachmentURL(ref, cockpit: chat.cockpit) {
            switch ChatWire.attachment(ref) {
            case .document(let ext, let label):
              ChatDocument(
                url: url, name: ChatWire.documentName(ref, text: message.text), ext: ext, label: label,
                message: message.id, logger: logger)
            default:
              ChatImage(url: url, message: message.id, board: message.board, chat: chat, logger: logger)
            }
          }
        }
        if !message.text.isEmpty {
          BubbleText(text: message.text, chat: chat, thread: thread)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
              message.fromIgor ? Color.accentColor : Color(.secondarySystemBackground),
              in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundStyle(message.fromIgor ? Color.white : Color.primary)
            .tint(message.fromIgor ? .white : .accentColor)
        }
        if message.fromIgor { receipt }
      }
      // #629: on the bubble, not the row, so holding the empty side opens nothing. It replaces selecting the text,
      // whose long press would take the same gesture; Copy keeps what that was for.
      .contextMenu { menu }
      if !message.fromIgor { Spacer(minLength: 48) }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(
      message.fromIgor ? "chat-mine" : ChatSpeaker.skillAuthor(message) == nil ? "chat-larry" : "chat-skill")
  }

  /// `ChatHold.choices`: answering himself means nothing, and a picture alone has no words to quote or copy (518).
  @ViewBuilder private var menu: some View {
    ForEach(ChatHold.choices(for: message), id: \.self) { choice in
      Button(choice.label, systemImage: choice.systemImage) {
        switch choice {
        case .react(let reaction): react(reaction)
        case .quote: quote()
        case .copy: copy()
        case .sendToNewChat: sendToNewChat()
        }
      }
    }
  }

  @ViewBuilder private var receipt: some View {
    if answerFailed {
      Text(ChatMessage.Receipt.received.glyph ?? "").font(.caption)
    } else if let glyph = message.receipt.glyph {
      if message.receipt == .done {
        Text(glyph + (message.doneNote.map { " \($0)" } ?? "")).font(.caption).foregroundStyle(.secondary)
      } else {
        Text(glyph).font(.caption)
      }
    } else {
      Text("sent").font(.caption2).foregroundStyle(.secondary)
    }
  }
}

private struct PendingBubble: View {
  let item: InboxItem
  let inbox: InboxModel
  let thumbnail: CGImage?
  /// #565: the last send found the Cockpit not answering.
  let away: Bool
  /// Who the thread's messages go to: Larry, or its skill (#632).
  let answeredBy: String
  let logger: BugLogger

  var body: some View {
    HStack {
      Spacer(minLength: 48)
      VStack(alignment: .trailing, spacing: 4) {
        if let thumbnail {
          Image(decorative: thumbnail, scale: 1).resizable().scaledToFit().frame(maxWidth: 200, maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        let text = ChatSend.text(for: item)
        if !text.isEmpty {
          Text(ChatText.linked(text))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
        }
        if item.status == .refused {
          BugProblemView(
            problem: .grabber(
              ChatSend.refusal(of: item, answeredBy: answeredBy), context: "ChatThreadView.send",
              extra: refusalExtra(item)),
            logger: logger)
          SendAgainButton(item: item, inbox: inbox)
        } else {
          Text(away ? "Not sent yet · the Cockpit isn't answering" : "Not sent yet").font(.caption2)
            .foregroundStyle(.orange)
        }
      }
    }
    .accessibilityIdentifier("chat-pending")
  }
}

/// A delivered document (#633, spec "A delivered file in the thread"): a row that fetches it and opens the system's
/// preview, with a copyable problem under it when the fetch fails.
private struct ChatDocument: View {
  let url: URL
  let name: String
  let ext: String
  let label: String
  let message: String
  let logger: BugLogger
  @State private var loading = false
  @State private var preview: URL?
  @State private var problem: BugProblem?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Button(action: open) {
        HStack(spacing: 10) {
          Image(systemName: ext == "pdf" ? "doc.richtext" : "doc.text").font(.title2).foregroundStyle(.secondary)
          VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.callout).lineLimit(2).multilineTextAlignment(.leading)
            Text(label).font(.caption).foregroundStyle(.secondary)
          }
          if loading { ProgressView() }
        }
        .padding(10)
        .frame(maxWidth: 260, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator)))
      }
      .buttonStyle(.plain)
      .disabled(loading)
      .accessibilityLabel("\(name), \(label)")
      .accessibilityIdentifier("chat-file")
      if let problem { BugProblemView(problem: problem, logger: logger) }
    }
    .quickLookPreview($preview)
  }

  private func open() {
    loading = true
    problem = nil
    Task {
      var status: Int?
      var data = Data()
      var failure: String?
      do {
        let (body, response) = try await URLSession.shared.data(from: url)
        status = (response as? HTTPURLResponse)?.statusCode
        data = body
      } catch {
        failure = error.localizedDescription
      }
      var reason = ChatWire.documentProblem(name: name, status: status, bytes: data.count, error: failure)
      var local: URL?
      if reason == nil {
        // A folder per message, so two files of one name never meet, and the preview shows the file's own name.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("chat-files", isDirectory: true)
          .appendingPathComponent(message, isDirectory: true)
        let file = folder.appendingPathComponent(name)
        do {
          try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
          try data.write(to: file, options: .atomic)
          local = file
        } catch {
          reason = "\(name) could not be kept on this device to open: \(error.localizedDescription)"
        }
      }
      loading = false
      var fields: [String: JSONValue] = [
        "action": "open_chat_file", "message": .string(message), "file_type": .string(ext),
        "bytes": .int(data.count), "ok": .bool(local != nil),
      ]
      if let status { fields["status"] = .int(status) }
      logger("ui", fields)
      if let local {
        preview = local
      } else {
        problem = .grabber(
          reason ?? "\(name) could not be opened.", context: "ChatThreadView.file",
          extra: [
            "url": .string(url.absoluteString), "message": .string(message),
            "status": .string(status.map(String.init) ?? "none"),
          ])
      }
    }
  }
}

/// Bead context-grabber-dbku: a board to slide in over a thread.
struct BoardJump: Hashable, Identifiable {
  let board: String
  var id: String { board }
}

extension EnvironmentValues {
  /// Bead context-grabber-dbku: how a picture inside a thread jumps to its board, over that same thread (nil outside
  /// one, where the jump goes the link's way).
  @Entry var jumpToBoard: (@MainActor (_ board: String, _ from: String) -> Void)?
  /// Story 1277 (#1384): who logs a tapped chip in a bubble's text; nil logs it as Chat's own (story 1127).
  @Entry var bubbleLinkOpened: (@MainActor (ChatLink) -> Void)?
}

private struct ChatImage: View {
  let url: URL
  let message: String
  /// The whiteboard it was sent from: the full-size view offers Jump to board (#603).
  let board: String?
  let chat: ChatModel
  let logger: BugLogger
  /// GRABBER_CHAT_IMAGE=open: the thread's picture opens full size by itself, for the simulator.
  @State private var full = LaunchHooks.current.chat.imageOpen
  @State private var looking = false
  @State private var jumpProblem: BugProblem?
  /// The cover is going down for a jump: the board opens once it has, so no cover is left stuck.
  @State private var leaving = false
  @Environment(\.jumpToBoard) private var jumpToBoard

  private func close(how: String) {
    full = false
    logger("ui", ["action": "close_chat_image", "message": .string(message), "how": .string(how)])
  }

  /// The board is found first, so a missing one leaves the picture open with the reason on it.
  private func jump(to board: String) {
    looking = true
    jumpProblem = nil
    let started = ProcessInfo.processInfo.systemUptime
    Task {
      let problem = await chat.findBoard(board, "ChatThreadView.jumpToBoard")
      looking = false
      logger(
        "ui",
        [
          "action": "jump_to_board", "message": .string(message), "board": .string(board),
          "found": .string(problem == nil ? "yes" : "no"),
          "ms": .int(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)),
        ])
      guard full else { return }  // closed while it looked
      jumpProblem = problem
      if problem == nil {
        leaving = true
        // #1137: the cover goes down at once rather than sliding, so the board isn't kept waiting on it.
        var quick = Transaction()
        quick.disablesAnimations = true
        withTransaction(quick) { full = false }
      }
    }
  }

  private func coverDismissed() {
    jumpProblem = nil
    if leaving, let board {
      if let jumpToBoard { jumpToBoard(board, "picture") } else { chat.openBoard(board) }
    }
    leaving = false
  }

  var body: some View {
    AsyncImage(url: url) { phase in
      switch phase {
      case .success(let image):
        image.resizable().scaledToFit().frame(maxWidth: 220, maxHeight: 260)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .onTapGesture { full = true }
      case .failure(let error):
        BugProblemView(
          problem: .grabber(
            "The picture could not be loaded: \(error.localizedDescription)", context: "ChatThreadView.image",
            extra: ["url": .string(url.absoluteString), "message": .string(message)]), logger: logger)
      default:
        ProgressView().frame(width: 120, height: 90)
      }
    }
    .fullScreenCover(isPresented: $full, onDismiss: coverDismissed) {
      ZStack(alignment: .topTrailing) {
        Color.black.ignoresSafeArea()
        // Stories 821, 822 (#907): pinches, double taps, pans and shares; a swipe down closes it only when fitted.
        ChatImageFull(url: url, message: message, logger: logger) { close(how: "swipe") }
        if let board {
          VStack(spacing: 8) {
            Spacer()
            if let jumpProblem {
              BugProblemView(problem: jumpProblem, logger: logger)
                .padding(8).background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            Button {
              jump(to: board)
            } label: {
              Text(looking ? "Looking for the board…" : "Jump to board").font(.headline)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.black.opacity(0.65), in: Capsule())
            }
            .foregroundStyle(.white).disabled(looking).accessibilityIdentifier("chat-image-jump")
          }
          .padding().frame(maxWidth: .infinity)
        }
        // #592: on a white picture (a whiteboard Larry marked up) a bare white Done vanished and left no way back.
        Button {
          close(how: "done")
        } label: {
          Text("Done").font(.headline).padding(.horizontal, 16).padding(.vertical, 8)
            .background(.black.opacity(0.65), in: Capsule())
        }
        .foregroundStyle(.white).padding().accessibilityIdentifier("chat-image-done")
      }
      .onAppear { logger("ui", ["action": "open_chat_image", "message": .string(message)]) }
    }
  }
}

/// Links in a message's words are tappable; a table is the only Markdown a bubble reads (story 747).
enum ChatText {
  static func linked(_ text: String) -> AttributedString {
    var out = AttributedString(text)
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return out }
    let ns = text as NSString
    for match in detector.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
      guard let url = match.url, ChatLinks.tappableInWords(url), let range = Range(match.range, in: text),
        let lower = AttributedString.Index(range.lowerBound, within: out),
        let upper = AttributedString.Index(range.upperBound, within: out)
      else { continue }
      out[lower..<upper].link = url
    }
    return out
  }
}

/// A message as its words and tables (story 747, `ChatTables`): a table is a grid, the rest `BubbleWords`. The board's
/// conversation bubbles use it too (#1384, story 1277).
struct BubbleText: View {
  let text: String
  let chat: ChatModel
  let thread: String

  var body: some View {
    if let batch = ChatReviewBatch.parse(text) {
      ReviewBatchCard(batch: batch, chat: chat, thread: thread)
    } else {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(Array(ChatTables.blocks(in: text).enumerated()), id: \.offset) { _, block in
          switch block {
          case .text(let words): BubbleWords(text: words, chat: chat, thread: thread)
          case .table(let table): BubbleTable(table: table, chat: chat, thread: thread)
          }
        }
      }
    }
  }
}

/// A pasted blog-review batch (story 748, `ChatReviewBatch`): the page's chip and its count, a chip per note that
/// opens to the quote in its context and the whole comment.
private struct ReviewBatchCard: View {
  let batch: ChatReviewBatch
  let chat: ChatModel
  let thread: String
  @State private var open: Set<Int> = []
  /// GRABBER_CHAT_REVIEW=open: the card's first note opens by itself, for the simulator.
  @State private var openHook = LaunchHooks.current.chat.reviewOpen
  @Environment(\.openURL) private var openURL
  @Environment(\.bubbleLinkOpened) private var linkOpened

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        if let url = batch.page {
          let link = ChatLink(url: url, kind: .web, label: batch.title, id: url.absoluteString)
          LinkChip(link: link) {
            if let linkOpened { linkOpened(link) } else { chat.logLinkOpened(link, thread: thread, from: "review") }
            openURL(url)
          }
        } else {
          Text(batch.title).font(.caption.weight(.medium))
        }
        Text(batch.count).font(.caption).foregroundStyle(.secondary)
      }
      ForEach(Array(batch.notes.enumerated()), id: \.offset) { index, note in
        VStack(alignment: .leading, spacing: 4) {
          Button {
            toggle(index, from: "tap")
          } label: {
            HStack(spacing: 4) {
              Image(systemName: open.contains(index) ? "chevron.down" : "chevron.right")
              Text(note.label).lineLimit(1)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color(.tertiarySystemFill), in: Capsule())
          }
          .buttonStyle(.borderless)
          .accessibilityIdentifier("chat-review-note")
          if open.contains(index) {
            context(note).font(.callout)
            if !note.comment.isEmpty { Text(note.comment) }
          }
        }
      }
    }
    .accessibilityIdentifier("chat-review-card")
    .task { runOpenHook() }
  }

  /// The note's place in the batch goes to the log, never its words.
  private func toggle(_ index: Int, from place: String) {
    let opening = !open.contains(index)
    if opening { open.insert(index) } else { open.remove(index) }
    chat.logAction("review_note", ["thread": thread, "note": index, "open": opening, "from": place])
  }

  private func runOpenHook() {
    guard openHook else { return }
    openHook = false
    toggle(0, from: "hook")
  }

  /// "…the words before *the quote* the words after…", the context dimmed.
  private func context(_ note: ChatReviewBatch.Note) -> Text {
    let before = Text(note.before).foregroundStyle(.secondary)
    let after = Text(note.after).foregroundStyle(.secondary)
    return Text("\(before)\(Text(note.quote).italic())\(after)")
  }
}

/// A table in a bubble (story 747): the heading in bold, a line between rows, a long cell wrapping in its column, and
/// sideways scrolling when it is wider than the bubble.
private struct BubbleTable: View {
  let table: ChatTables.Table
  let chat: ChatModel
  let thread: String

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
        GridRow { cells(table.heading).bold() }
        ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
          Divider().gridCellUnsizedAxes(.horizontal)
          GridRow { cells(row) }
        }
      }
      .padding(.vertical, 2)
    }
    // A scroll view's cells are lost in the bubble's combined label, so the table says its rows itself.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(table.spoken)
  }

  private func cells(_ texts: [String]) -> some View {
    ForEach(Array(texts.enumerated()), id: \.offset) { column, text in
      let (grid, frame, words) = align(column)
      BubbleWords(text: text, chat: chat, thread: thread)
        .frame(maxWidth: 180, alignment: frame)
        .multilineTextAlignment(words)
        .gridColumnAlignment(grid)
    }
  }

  private func align(_ column: Int) -> (HorizontalAlignment, Alignment, TextAlignment) {
    switch column < table.alignments.count ? table.alignments[column] : .leading {
    case .leading: (.leading, .leading, .leading)
    case .center: (.center, .center, .center)
    case .trailing: (.trailing, .trailing, .trailing)
    }
  }
}

/// Words with their links as the strip's chips (story 743, `ChatBubbleLinks`): a line with no chip is one text as
/// before; a line with one flows word by word, so the chip sits where the link was written.
private struct BubbleWords: View {
  let text: String
  let chat: ChatModel
  let thread: String
  @Environment(\.openURL) private var openURL
  @Environment(\.bubbleLinkOpened) private var linkOpened

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(Array(ChatBubbleLinks.paragraphs(in: text).enumerated()), id: \.offset) { _, paragraph in
        switch paragraph {
        case .plain(let words):
          Text(ChatText.linked(words.isEmpty ? " " : words))
        case .flow(let tokens):
          WordFlow {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
              switch token {
              case .word(let word):
                Text(ChatText.linked(word))
              case .chip(let link, let leading, let trailing):
                HStack(spacing: 1) {
                  if !leading.isEmpty { Text(leading) }
                  LinkChip(link: chat.withStates([link]).first ?? link) { open(link) }
                  if !trailing.isEmpty { Text(trailing) }
                }
              }
            }
          }
        }
      }
    }
  }

  private func open(_ link: ChatLink) {
    if let linkOpened { linkOpened(link) } else { chat.logLinkOpened(link, thread: thread, from: "bubble") }
    openURL(link.url)
  }
}

/// Words and chips left to right, wrapping as text does (story 743).
/// ponytail: a single word wider than the bubble is not broken, it is squeezed to the bubble's width.
private struct WordFlow: Layout {
  var spacing: CGFloat = 4
  var lineSpacing: CGFloat = 4

  private struct Row {
    var items: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let laidOut = rows(width: proposal.width ?? .infinity, subviews)
    let height = laidOut.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, laidOut.count - 1))
    return CGSize(width: laidOut.map(\.width).max() ?? 0, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in rows(width: bounds.width, subviews) {
      var x = bounds.minX
      for index in row.items {
        var size = subviews[index].sizeThatFits(.unspecified)
        size.width = min(size.width, bounds.width)
        subviews[index].place(
          at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += row.height + lineSpacing
    }
  }

  private func rows(width: CGFloat, _ subviews: Subviews) -> [Row] {
    var rows: [Row] = []
    var row = Row()
    for index in subviews.indices {
      var size = subviews[index].sizeThatFits(.unspecified)
      size.width = min(size.width, width)
      if !row.items.isEmpty, row.width + spacing + size.width > width {
        rows.append(row)
        row = Row()
      }
      row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
      row.height = max(row.height, size.height)
      row.items.append(index)
    }
    if !row.items.isEmpty { rows.append(row) }
    return rows
  }
}

// MARK: - Writing

private struct ComposeBar: View {
  @ObservedObject var chat: ChatModel
  @ObservedObject var voice: ChatVoiceModel
  let thread: String
  /// Where a Send goes (#536): a thread, a new chat's first message, or nowhere yet.
  let target: ChatNewThread.Target
  /// Who the field says it writes to (#632).
  let answeredBy: String
  let logger: BugLogger
  /// A new chat's first message on the phone, for the bar's line when it was refused (story 491).
  let first: InboxItem?
  /// A message to quote into the bar (#629): taken as soon as it is set.
  @Binding var quoting: ChatMessage?
  /// What a Send does (`ChatNewThread.send`): into a thread, a new chat's fresh first message, or nothing yet.
  var sendAt: () -> ChatNewThread.Send = { .hold }
  @State private var draft = InboxDraft()
  @State private var preview: CGImage?
  @State private var hasImage = UIPasteboard.general.hasImages
  @State private var failure: String?
  @State private var picking = false
  /// Why the last pick didn't take, with what was picked (stories 493, 494).
  @State private var pickProblem: BugProblem?
  /// A new field after each send (#449): clearing the text alone could leave the old words in a field still editing.
  @State private var field = 0
  /// Two quick Returns at the end of the words send (story 749).
  @State private var enters = ChatDoubleEnter()
  /// GRABBER_CHAT_ENTER=<words>: the words and two new lines land in the bar as typing would, for the simulator.
  @State private var enterHook = LaunchHooks.current.chat.enter
  @FocusState private var focused: Bool

  var body: some View {
    VStack(spacing: 6) {
      if let failure {
        BugProblemView(
          problem: .grabber(
            failure, context: "ChatThreadView.send",
            extra: ["thread": .string(thread), "text_bytes": .int(draft.text.utf8.count)]), logger: logger)
      }
      if let pickProblem { BugProblemView(problem: pickProblem, logger: logger) }
      // #448: what the mic could not do, copyable, and its quieter line (a call has the mic, the five-minute stop),
      // each in the thread it came from only; then, in a new chat, where its next message stands (#536). All show.
      if voice.thread == thread, let problem = voice.problem() {
        BugProblemView(problem: problem, logger: logger)
      }
      if voice.thread == thread, let notice = voice.notice {
        Text(notice).font(.footnote).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("chat-voice-notice")
      }
      if let line = ChatNewThread.barLine(target, first: first) {
        Text(line).font(.footnote).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier(target == .waiting ? "chat-new-waiting" : "chat-new-refused")
      }
      if let preview {
        HStack {
          Image(decorative: preview, scale: 1).resizable().scaledToFit().frame(maxHeight: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          Button("Remove image", role: .destructive) {
            draft.image = nil
            self.preview = nil
          }
          .font(.caption)
          Spacer()
        }
      }
      if let file = draft.file {
        HStack {
          Label(file.name, systemImage: "doc").lineLimit(1).truncationMode(.middle)
            .accessibilityIdentifier("chat-file-draft")
          Text(file.size).font(.caption).foregroundStyle(.secondary)
          Spacer()
          Button("Remove file", role: .destructive) { draft.file = nil }.font(.caption)
        }
      }
      MicPicker(voice: voice)
      BugInputLevelMeter(level: voice.inputLevel, accessibilityIdentifier: "chat-mic-level")
        // Idle it is an empty track: VoiceOver skips it rather than read "0 percent" between the row and the bar.
        .accessibilityHidden(!voice.listening)
      HStack(alignment: .bottom, spacing: 8) {
        Button {
          picking = true
        } label: {
          Image(systemName: "paperclip").font(.title3)
        }
        .accessibilityLabel("Attach file")
        .accessibilityIdentifier("chat-attach")
        Button {
          paste(from: "button")
        } label: {
          Image(systemName: "photo.on.rectangle").font(.title3)
        }
        .disabled(!hasImage)
        .accessibilityLabel("Paste image")
        TextField("Message \(answeredBy)", text: $draft.text, axis: .vertical)
          .lineLimit(1...6)
          .padding(.horizontal, 12).padding(.vertical, 8)
          .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
          .accessibilityIdentifier("chat-compose")
          .focused($focused)
          .macEnterConfirms {
            if ChatNewThread.canSend(target, draftReady: draft.canAdd) { send() }
          }
          .macPastesImage { paste(from: "mac_paste") }
          .id(field)
        MicButton(voice: voice, thread: thread, draft: draft.text)
        Button(action: send) {
          Image(systemName: "arrow.up.circle.fill").font(.title)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(!ChatNewThread.canSend(target, draftReady: draft.canAdd))
        .accessibilityLabel("Send")
        .accessibilityIdentifier("chat-send")
      }
    }
    .padding(.horizontal, 12).padding(.vertical, 8)
    .background(Color(.systemGroupedBackground))
    .fileImporter(isPresented: $picking, allowedContentTypes: [.data]) { attach($0) }
    // The words stream into the draft as Igor speaks, after what was typed, for him to read before he sends (#448).
    .onChange(of: voice.words) { _, _ in takeWords() }
    .onChange(of: draft.text) { old, new in sendOnDoubleEnter(from: old, to: new) }
    .onChange(of: quoting) { _, message in
      if let message { take(quote: message) }
    }
    .onAppear {
      takeWords()
      // The voice button's new chat records as it opens (#637); the bar's own tap, so words and refusals land here.
      if ChatNewThread.takesVoiceOnOpen(target), chat.takeNewChatVoice() {
        voice.startNewChat(thread: thread, draft: draft.text)
      }
      // A new chat opens with the keyboard up (spec "A new chat", story 262), unless he is talking.
      if ChatNewThread.focusesOnOpen(target, recording: voice.recording) { focused = true }
      if let words = enterHook {
        enterHook = nil
        draft.text = words + "\n\n"
      }
    }
    .onDisappear { voice.cancel(thread: thread, why: "left_thread") }
    .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
      hasImage = UIPasteboard.general.hasImages
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
      hasImage = UIPasteboard.general.hasImages
    }
  }

  private func takeWords() {
    guard let words = voice.take(thread: thread) else { return }
    enters.willWrite(words)
    draft.text = words
  }

  /// A recording writes over the bar from where it began, so it stops first, its words so far kept (story 541).
  private func take(quote message: ChatMessage) {
    takeWords()
    voice.sent(thread: thread, why: "quoted")
    let quoted = ChatQuote.appended(message, to: draft.text)
    enters.willWrite(quoted)
    draft.text = quoted
    focused = true
    quoting = nil
  }

  /// `how`: the Paste image button, or on a Mac the paste key or menu (#730).
  private func paste(from how: String) {
    guard let data = Self.clipboardImage(), let picture = InboxSend.thumbnail(data) else {
      let board = UIPasteboard.general
      chat.logAction(
        "image_pasted",
        ["how": how, "read": false, "has_image": board.hasImages, "types": Array(board.types.prefix(8))])
      failure = "The clipboard image could not be read. Copy the image again and try Paste image."
      return
    }
    chat.logAction("image_pasted", ["how": how, "read": true, "bytes": data.count])
    draft.image = data
    draft.file = nil
    preview = picture
    clearProblems()
  }

  /// Story 482: one attachment to a message, the newer. A problem leaves the draft as it was (stories 493, 494).
  private func attach(_ result: Result<URL, Error>) {
    do {
      let url = try result.get()
      let bytes: Int
      switch try ChatFile.read(url) {
      case .image(let data):
        guard let picture = InboxSend.thumbnail(data) else {
          throw ChatFile.Problem.unreadable(name: url.lastPathComponent, reason: "the picture could not be drawn")
        }
        draft.image = data
        draft.file = nil
        preview = picture
        bytes = data.count
      case .file(let file):
        draft.file = file
        draft.image = nil
        preview = nil
        bytes = file.data.count
      }
      clearProblems()
      chat.logAction("file_picked", ["file_type": ChatFile.type(of: url.lastPathComponent), "bytes": bytes])
    } catch {
      pickProblem = .grabber(
        error.localizedDescription, context: "ChatThreadView.attach", extra: ["thread": .string(thread)])
      chat.logAttachFailure(error)
    }
  }

  private func clearProblems() {
    failure = nil
    pickProblem = nil
  }

  /// Story 749: the words, their blank lines off, go as Send would send them; what Send would refuse stays as typed.
  private func sendOnDoubleEnter(from old: String, to new: String) {
    let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
    guard let asked = enters.change(from: old, to: new, at: nowMs),
      ChatNewThread.canSend(target, draftReady: draft.canAdd)
    else { return }
    var fields: [String: Any] = ["thread": thread, "how": asked.gapMs == nil ? "one_change" : "two_changes"]
    if let gap = asked.gapMs { fields["gap_ms"] = Int(gap) }
    chat.logAction("double_enter_sent", fields)
    enters.willWrite(asked.text)
    draft.text = asked.text
    send()
  }

  private func send() {
    do {
      switch sendAt() {
      case .thread(let key): try chat.send(&draft, thread: key)
      case .start(let id): try chat.send(&draft, thread: nil, id: id)
      case .hold: return
      }
      // The message took the words heard so far: a recording still going stops, so none come back (#546).
      voice.sent(thread: thread)
      preview = nil
      clearProblems()
      let wasFocused = focused
      field += 1
      Task { @MainActor in
        if wasFocused { focused = true }
        chat.noteBarAfterSend(thread: thread, leftChars: draft.text.count)
      }
    } catch {
      failure = "The message could not be kept on the phone: \(error.localizedDescription)"
    }
  }

  /// The image's bytes as copied, so a photo keeps its format and its orientation; only an image with no bytes on
  /// the clipboard is drawn upright into a JPEG.
  static func clipboardImage() -> Data? {
    let board = UIPasteboard.general
    let types = board.types.compactMap(UTType.init).filter { $0.conforms(to: .image) }
    if let raw = types.lazy.compactMap({ board.data(forPasteboardType: $0.identifier) }).first(where: {
      InboxSend.thumbnail($0, maxPixels: 1) != nil
    }) {
      return raw
    }
    guard let image = board.image else { return nil }
    let format = UIGraphicsImageRendererFormat.preferred()
    format.scale = image.scale
    return UIGraphicsImageRenderer(size: image.size, format: format).jpegData(withCompressionQuality: 0.9) { _ in
      image.draw(at: .zero)
    }
  }
}

/// Tap to record, tap to stop (#448): red with the seconds while recording, a spinner while it starts and while the
/// last words settle, dimmed during a call, when a tap says why instead. Every field with a Send has it beside Send
/// (#625): a chat's bar, and a question card's own answer on a board (story 889).
struct MicButton: View {
  @ObservedObject var voice: ChatVoiceModel
  let thread: String
  let draft: String
  var identifier = "chat-mic"

  var body: some View {
    Button {
      voice.tap(thread: thread, draft: draft)
    } label: {
      Group {
        switch voice.phase {
        case .idle:
          Image(systemName: "mic").font(.title3)
            .foregroundStyle(voice.callLive ? Color.secondary : Color.accentColor)
        case .recording(let since):
          HStack(spacing: 3) {
            Image(systemName: "stop.circle.fill").font(.title3)
            TimelineView(.periodic(from: since, by: 1)) { context in
              Text(ChatVoice.elapsed(context.date.timeIntervalSince(since))).font(.caption.monospacedDigit())
            }
          }
          .foregroundStyle(.red)
        case .starting, .finishing:
          ProgressView()
        }
      }
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
    }
    .disabled(voice.phase == .starting || voice.phase == .finishing)
    .accessibilityLabel(label)
    .accessibilityIdentifier(identifier)
  }

  private var label: String {
    switch voice.phase {
    case .idle: return "Speak a message"
    case .recording: return "Stop recording"
    case .starting: return "Starting to listen"
    case .finishing: return "Transcribing"
    }
  }
}

/// Which microphone the next recording uses (#448, Igor 2026-10-26): Automatic or one of the phone's inputs, the
/// problem report's saved pick. Locked while recording and during a call. A full-width row a finger tall (#544), laid
/// out as BugKit's report microphone row. #531: BugKit's live input level under it, as the report shows. This menu
/// stays the app's own rather than BugKit's picker: the finger-tall row (#544), the call lock and the chat_voice lines.
private struct MicPicker: View {
  @ObservedObject var voice: ChatVoiceModel

  var body: some View {
    Menu {
      Button {
        voice.selectMicrophone(nil)
      } label: {
        if voice.selectedMicrophoneID == nil { Label("Automatic", systemImage: "checkmark") } else { Text("Automatic") }
      }
      ForEach(voice.microphones) { mic in
        Button {
          voice.selectMicrophone(mic.id)
        } label: {
          if voice.selectedMicrophoneID == mic.id {
            Label(mic.name, systemImage: "checkmark")
          } else {
            Text(mic.name)
          }
        }
      }
      Divider()
      Button("Find microphones", systemImage: "arrow.clockwise") { voice.findMicrophones() }
        .accessibilityIdentifier("chat-mic-find")
    } label: {
      HStack(spacing: 6) {
        Text("Microphone").lineLimit(1).layoutPriority(1)
        Spacer(minLength: 8)
        Text(voice.microphoneName).foregroundStyle(.secondary).lineLimit(1)
        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
      }
      .font(.subheadline)
      .frame(maxWidth: .infinity, minHeight: 44)
      .contentShape(Rectangle())
    }
    .disabled(!voice.canPickMicrophone)
    // After a relaunch the saved pick is an id until the inputs are listed: list them once so it reads by name.
    .onAppear { voice.pickerAppeared() }
    .accessibilityLabel("Microphone: \(voice.microphoneName)")
    .accessibilityIdentifier("chat-mic-picker")
  }
}

/// What went to Larry's inbox before chat, read-only (spec: What was in the Inbox).
private struct EarlierSharesView: View {
  @ObservedObject var inbox: InboxModel
  let logger: BugLogger

  var body: some View {
    List {
      ForEach(inbox.items.filter(\.isEarlierShare)) { item in
        VStack(alignment: .leading, spacing: 2) {
          Text(ChatSend.text(for: item).isEmpty ? "A picture" : ChatSend.text(for: item)).lineLimit(3)
          Text(
            Date(timeIntervalSince1970: Double(item.sharedAt) / 1000), format: .dateTime.month().day().hour().minute()
          )
          .font(.caption).foregroundStyle(.secondary)
        }
        .swipeActions { Button("Delete", role: .destructive) { inbox.delete(item) } }
      }
    }
    .navigationTitle("Earlier shares")
  }
}

extension InboxItem {
  fileprivate var pendingKey: String { "pending-" + id }
}

// MARK: - Previews (the private rows and bubbles; the screens' previews are in Previews/AppPreviews.swift)

#if DEBUG
  #Preview("Thread rows") {
    List {
      ForEach(PreviewFixtures.threads) { thread in
        ThreadRow(thread: thread, decisionWaiting: thread.key == "igor2-88g.1620")
      }
    }
  }

  #Preview("Message bubbles") {
    ScrollView {
      VStack(spacing: 8) {
        ForEach(PreviewFixtures.messages) { message in
          MessageBubble(
            message: message, thread: "igor2-88g.1801", answerFailed: false, group: false, chat: PreviewFixtures.chat,
            logger: PreviewFixtures.logger, react: { _ in }, quote: {}, copy: {}, sendToNewChat: {}, openMoved: { _ in }
          )
        }
      }
      .padding()
    }
  }
#endif
