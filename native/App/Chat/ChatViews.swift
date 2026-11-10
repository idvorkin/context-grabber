//  Chat with Larry (spec 2026-10-25-native-chat-design.md): the list of threads, one thread as bubbles, and the bar
//  that writes to it. What is not on the Cockpit yet shows from this phone's outbox, marked Not sent yet.

import BugKit
import ContextCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatListView: View {
  @ObservedObject var chat: ChatModel
  @ObservedObject var inbox: InboxModel
  let voice: ChatVoiceModel
  let logger: BugLogger
  @State private var doneOpen = false
  /// #736: an iPad at full width and the Mac show each row's newest links; an iPhone's list is unchanged.
  @Environment(\.horizontalSizeClass) private var widthClass

  init(chat: ChatModel, voice: ChatVoiceModel, logger: @escaping BugLogger) {
    self.chat = chat
    self.inbox = chat.inbox
    self.voice = voice
    self.logger = logger
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
          problem: .grabber(problem, context: "ChatListView.refresh", extra: ["cockpit": .string(chat.cockpit)]),
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
      Section {
        ForEach(live) { thread in
          if !selection.selecting {
            threadLink(thread)
          } else if selection.shows(thread) {
            tickRow(thread)
          }
        }
      }
      if selection.showsDone(chat.threads) {
        Section {
          DisclosureGroup("Done (\(done.count))", isExpanded: $doneOpen) {
            ForEach(done) { thread in threadLink(thread) }
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
    .refreshable { await chat.refreshList(reason: "pull") }
    .task {
      await chat.refreshList(reason: "open")
      if selectHook {
        selectHook = false
        review(from: "hook")
        archivePicked()
      }
    }
    .onAppear { chat.listOnScreen = true }
    .onDisappear { chat.listOnScreen = false }
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
      isPresented: Binding(get: { chat.linkThread != nil }, set: { if !$0 { chat.linkThread = nil } })
    ) {
      if let key = chat.linkThread {
        ChatThreadView(chat: chat, voice: voice, key: key, title: chat.title(of: key), logger: logger)
      }
    }
    .chatTextSize()
  }

  private func review(from: String) {
    let count = selection.review(chat.threads)
    chat.logAction("select", ["from": from, "count": count])
  }

  private func archivePicked() {
    let keys = selection.archivePicked(chat.threads)
    Task { await chat.archiveSelected(keys) }
  }

  private func tickRow(_ thread: ChatSummary) -> some View {
    let ticked = selection.ticked(thread.key)
    return Button {
      selection.tick(thread.key)
    } label: {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(ticked ? Color.accentColor : .secondary)
        ThreadRow(thread: thread)
      }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("chat-tick-\(thread.key)")
    .accessibilityValue(ticked ? "ticked" : "not ticked")
    .accessibilityLabel(ticked ? "Ticked: \(thread.title)" : thread.title)
  }

  private func threadLink(_ thread: ChatSummary) -> some View {
    NavigationLink {
      ChatThreadView(chat: chat, voice: voice, key: thread.key, title: thread.title, logger: logger)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        ThreadRow(thread: thread)
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

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Circle().fill(thread.unread > 0 ? Color.accentColor : .clear).frame(width: 9, height: 9).padding(.top, 6)
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline) {
          if thread.pinned {
            Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary).accessibilityLabel("Pinned")
          }
          Text(thread.title).font(.body.weight(thread.unread > 0 ? .semibold : .regular)).lineLimit(2)
          Spacer(minLength: 8)
          if let at = thread.lastAt {
            Text(at, format: .relative(presentation: .numeric, unitsStyle: .abbreviated)).font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Text(thread.lastLine)
          .font(.subheadline)
          .foregroundStyle(.secondary).lineLimit(2)
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
    .accessibilityHint(link.url.absoluteString)
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
            Text(link.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(2)
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
  /// GRABBER_CHAT_HOLD=yes / no / quote / copy: that choice taps itself on Larry's newest message, for the simulator.
  @State private var holdHook = LaunchHooks.current.chat.hold
  @Environment(\.dismiss) private var dismiss

  init(chat: ChatModel, voice: ChatVoiceModel, key: String, title: String, logger: @escaping BugLogger) {
    self.chat = chat
    self.inbox = chat.inbox
    self.voice = voice
    self.fixedKey = key
    self.fixedTitle = title
    self.logger = logger
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
              problem: .grabber(problem, context: "ChatThreadView.load", extra: ["thread": .string(key)]),
              logger: logger)
          }
          let answerFailed = ChatWire.answerFailed(messages)
          ForEach(messages) { message in
            MessageBubble(
              message: message, thread: key ?? "", answerFailed: answerFailed.contains(message.id), chat: chat,
              logger: logger, react: { react($0, to: message) }, quote: { quote(message) }, copy: { copy(message) })
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
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
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
    .accessibilityIdentifier(fixedKey == nil ? "chat-new-thread" : "chat-thread")
    .onAppear { if let key { chat.open(key) } }
    .onDisappear { if let key { chat.close(key) } }
    // A new chat becomes its thread once the Cockpit has the first message: the same screen, now live.
    .onChange(of: first?.chatThread) { _, thread in
      if let landed = newThread.firstMoved(to: thread) { chat.open(landed) }
    }
    .onChange(of: messages.last?.id, initial: true) { runHoldHook() }
    .chatTextSize()
  }

  private func runHoldHook() {
    guard let hook = holdHook, let message = messages.last(where: { !$0.fromIgor }) else { return }
    holdHook = nil
    switch ChatHold(hook: hook) {
    case .quote: quote(message)
    case .copy: copy(message)
    case .react(let reaction): react(reaction, to: message)
    case nil: break
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

  /// Yes or No, sent at once as an ordinary message (#629). The bar's draft is left alone.
  private func react(_ reaction: ChatReaction, to message: ChatMessage) {
    guard let key else { return }
    // Something still on its way is newer than anything the Cockpit shows.
    let newest = pending.isEmpty && messages.last?.id == message.id
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
  let chat: ChatModel
  let logger: BugLogger
  let react: (ChatReaction) -> Void
  let quote: () -> Void
  let copy: () -> Void

  var body: some View {
    if message.isError { failure } else { bubble }
  }

  /// The skill's name and its letter, over what it wrote (#632).
  @ViewBuilder private var byline: some View {
    if let author = message.author, let initial = message.authorInitial {
      HStack(spacing: 6) {
        Text(initial).font(.caption.weight(.semibold)).foregroundStyle(.white)
          .frame(width: 22, height: 22)
          .background(Color.indigo, in: Circle())
          .accessibilityHidden(true)
        Text(author).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
      }
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
            "thread": .string(thread), "message": .string(message.id), "skill": .string(message.author ?? ""),
            "ts": .string(message.ts),
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
            ChatImage(url: url, message: message.id, board: message.board, chat: chat, logger: logger)
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
    .accessibilityIdentifier(message.fromIgor ? "chat-mine" : message.author == nil ? "chat-larry" : "chat-skill")
  }

  /// `ChatHold.choices`: answering himself means nothing, and a picture alone has no words to quote or copy (518).
  @ViewBuilder private var menu: some View {
    ForEach(ChatHold.choices(for: message), id: \.self) { choice in
      Button(choice.label, systemImage: choice.systemImage) {
        switch choice {
        case .react(let reaction): react(reaction)
        case .quote: quote()
        case .copy: copy()
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

  private func close(how: String) {
    full = false
    logger("ui", ["action": "close_chat_image", "message": .string(message), "how": .string(how)])
  }

  /// The board is found first, so a missing one leaves the picture open with the reason on it.
  private func jump(to board: String) {
    looking = true
    jumpProblem = nil
    Task {
      let problem = await chat.findBoard(board, "ChatThreadView.jumpToBoard")
      looking = false
      logger(
        "ui",
        [
          "action": "jump_to_board", "message": .string(message), "board": .string(board),
          "found": .string(problem == nil ? "yes" : "no"),
        ])
      guard full else { return }  // closed while it looked
      jumpProblem = problem
      if problem == nil {
        leaving = true
        full = false
      }
    }
  }

  private func coverDismissed() {
    jumpProblem = nil
    if leaving, let board { chat.openBoard(board) }
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
        AsyncImage(url: url) {
          $0.resizable().scaledToFit()
        } placeholder: {
          ProgressView()
        }
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
      .gesture(
        DragGesture(minimumDistance: ChatImageClose.minimumDrag).onEnded {
          if ChatImageClose.closes(dragHeight: $0.translation.height) { close(how: "swipe") }
        }
      )
      .onAppear { logger("ui", ["action": "open_chat_image", "message": .string(message)]) }
    }
  }
}

/// Links in a message are tappable; nothing else is interpreted (a message is never Markdown).
enum ChatText {
  static func linked(_ text: String) -> AttributedString {
    var out = AttributedString(text)
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return out }
    let ns = text as NSString
    for match in detector.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
      guard let url = match.url, let range = Range(match.range, in: text),
        let lower = AttributedString.Index(range.lowerBound, within: out),
        let upper = AttributedString.Index(range.upperBound, within: out)
      else { continue }
      out[lower..<upper].link = url
    }
    return out
  }
}

/// A message's words with its links as the strip's chips (story 743, `ChatBubbleLinks`): a line with no chip is one
/// text as before; a line with one flows word by word, so the chip sits where the link was written.
private struct BubbleText: View {
  let text: String
  let chat: ChatModel
  let thread: String
  @Environment(\.openURL) private var openURL

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
    chat.logLinkOpened(link, thread: thread, from: "bubble")
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
      if voice.thread == thread, let problem = voice.problem {
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
    draft.text = words
  }

  /// A recording writes over the bar from where it began, so it stops first, its words so far kept (story 541).
  private func take(quote message: ChatMessage) {
    takeWords()
    voice.sent(thread: thread, why: "quoted")
    draft.text = ChatQuote.appended(message, to: draft.text)
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
/// last words settle, dimmed during a call, when a tap says why instead.
private struct MicButton: View {
  @ObservedObject var voice: ChatVoiceModel
  let thread: String
  let draft: String

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
    .accessibilityIdentifier("chat-mic")
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
