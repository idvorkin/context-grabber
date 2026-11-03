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

  init(chat: ChatModel, voice: ChatVoiceModel, logger: @escaping BugLogger) {
    self.chat = chat
    self.inbox = chat.inbox
    self.voice = voice
    self.logger = logger
  }

  private var live: [ChatSummary] { chat.threads.filter { !$0.done } }
  private var done: [ChatSummary] { chat.threads.filter(\.done) }
  private var looksDone: [ChatSummary] { live.filter(\.looksDone) }
  /// *Select* is on: live rows tick instead of opening (#599).
  @State private var selecting = false
  @State private var picked: Set<String> = []
  /// What is ticked and still live: a refresh can finish or archive a ticked thread and take its row away.
  private var pickedLive: [String] { ChatWire.liveKeys(picked, in: chat.threads) }
  /// GRABBER_CHAT_SELECT=archive: once the list is read, *Review* and *Archive (N)* tap themselves, for the simulator.
  @State private var selectHook = ProcessInfo.processInfo.environment["GRABBER_CHAT_SELECT"] == "archive"

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
      if !chat.undoArchive.isEmpty {
        let undo = chat.undoArchive
        HStack {
          Text(undo.count == 1 ? "Archived \"\(undo[0].title)\"" : "Archived \(undo.count) chats").lineLimit(1)
          Spacer()
          Button("Undo") {
            Task { await chat.setArchived(undo.map(\.key), false, from: "undo") }
          }
          .accessibilityIdentifier("chat-archive-undo")
        }
        .font(.footnote)
      }
      if !selecting, !looksDone.isEmpty {
        HStack {
          Text(looksDone.count == 1 ? "1 chat looks done" : "\(looksDone.count) chats look done")
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
          if !selecting {
            threadLink(thread)
          } else if !thread.pinned {
            tickRow(thread)
          }
        }
      }
      if !done.isEmpty, !selecting {
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
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(selecting ? "Cancel" : "Select") {
          picked = []
          selecting.toggle()
          if selecting { chat.logAction("select", ["from": "toolbar"]) }
        }
        .disabled(!selecting && live.allSatisfy(\.pinned))
        .accessibilityIdentifier("chat-select")
      }
    }
    .safeAreaInset(edge: .bottom) {
      if selecting {
        Button("Archive (\(pickedLive.count))") { archivePicked() }
          .buttonStyle(.borderedProminent)
          .disabled(pickedLive.isEmpty)
          .padding(.bottom, 8)
          .accessibilityIdentifier("chat-archive-selected")
      }
    }
    // #424, story 262: a fixed thumb target. #637, story 506: in its own opaque bar, not floating over the list: a row behind
    // the two buttons could not be swiped from where they cover it.
    .safeAreaInset(edge: .bottom) {
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
      .padding(.top, 8)
      .padding([.horizontal, .bottom], 16)
      .frame(maxWidth: .infinity, alignment: .trailing)
      .background(Color(.systemGroupedBackground))
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("chat-new-bar")
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
  }

  private func review(from: String) {
    picked = Set(looksDone.map(\.key))
    selecting = true
    chat.logAction("select", ["from": from, "count": picked.count])
  }

  private func archivePicked() {
    let keys = pickedLive
    picked = []
    selecting = false
    Task { await chat.archiveSelected(keys) }
  }

  private func tickRow(_ thread: ChatSummary) -> some View {
    let ticked = picked.contains(thread.key)
    return Button {
      if ticked { picked.remove(thread.key) } else { picked.insert(thread.key) }
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
      ThreadRow(thread: thread)
    }
    .accessibilityIdentifier("chat-thread-\(thread.key)")
    // #589: a swipe left archives a live thread, or brings back an archived one.
    .swipeActions {
      if thread.archived {
        Button("Unarchive") { Task { await chat.setArchived(thread.key, false, from: "swipe") } }.tint(.blue)
      } else if !thread.done, !thread.pinned {
        Button("Archive") { Task { await chat.setArchived(thread.key, true, from: "swipe") } }.tint(.indigo)
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
        if thread.looksDone, !thread.done {
          Label("Looks done", systemImage: "checkmark.seal").font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
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

  private var key: String? { fixedKey ?? newThread.landed }
  /// A new chat's latest first message while it is still only on the phone.
  private var first: InboxItem? { newThread.sent.flatMap { id in inbox.items.first { $0.id == id } } }
  private var messages: [ChatMessage] { key.flatMap { chat.messages[$0] } ?? [] }
  private var answeredBy: String { chat.answeredBy(key) }
  private var pending: [InboxItem] {
    if let key { return chat.pending(in: key) }
    return first.map { [$0] } ?? []
  }
  /// A new chat takes its first message's first line as the title, as the Cockpit will.
  private var title: String {
    guard fixedKey == nil else { return fixedTitle }
    if let landed = newThread.landed, let known = chat.threads.first(where: { $0.key == landed }) {
      return known.title
    }
    return first.map { ChatSend.title(for: $0) } ?? fixedTitle
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
              logger: logger, react: { react($0, to: message) }, quote: { quoting = message })
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
        newThread.attempt(at: target)
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if let key, let thread = chat.threads.first(where: { $0.key == key }), !thread.pinned {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            if thread.archived {
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
      guard newThread.landed == nil, let thread else { return }
      newThread.land(in: thread)
      chat.open(thread)
    }
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

  private var hasWords: Bool { !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
          Text(ChatText.linked(message.text))
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

  /// Answering himself means nothing, and a picture alone has no words to quote or copy (story 445).
  @ViewBuilder private var menu: some View {
    if !message.fromIgor {
      ForEach(ChatReaction.allCases, id: \.self) { reaction in
        Button(reaction.label, systemImage: reaction == .yes ? "hand.thumbsup" : "hand.thumbsdown") { react(reaction) }
      }
    }
    if hasWords {
      Button("Quote in reply", systemImage: "text.quote", action: quote)
      Button("Copy", systemImage: "doc.on.doc") {
        UIPasteboard.general.string = message.text
        chat.logAction("copy", ["message": message.id])
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
  @State private var full = ProcessInfo.processInfo.environment["GRABBER_CHAT_IMAGE"] == "open"
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
      .gesture(DragGesture(minimumDistance: 30).onEnded { if $0.translation.height > 80 { close(how: "swipe") } })
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
  /// A new chat's next first message: a fresh id, now the one the screen follows.
  var startAttempt: () -> String? = { nil }
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
      if target == .waiting {
        Text("The next message goes once your first one reaches Larry.").font(.footnote).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("chat-new-waiting")
      } else if case .refused = target {
        Text(ChatSend.afterRefusal(of: first)).font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("chat-new-refused")
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
        Button(action: paste) {
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
          .id(field)
        MicButton(voice: voice, thread: thread, draft: draft.text)
        Button(action: send) {
          Image(systemName: "arrow.up.circle.fill").font(.title)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(!draft.canAdd || target == .waiting)
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
      guard target == .new else { return }
      // The voice button's new chat records as it opens (#637); the bar's own tap, so words and refusals land here.
      if chat.takeNewChatVoice() { voice.startNewChat(thread: thread, draft: draft.text) }
      // A new chat opens with the keyboard up (spec "A new chat", story 262), unless he is talking.
      if !voice.recording { focused = true }
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

  /// A recording writes over the bar from where it began, so it stops first, its words so far kept (story 448).
  private func take(quote message: ChatMessage) {
    takeWords()
    voice.sent(thread: thread, why: "quoted")
    draft.text = ChatQuote.appended(message, to: draft.text)
    focused = true
    quoting = nil
    chat.logAction("quote", ["thread": thread, "message": message.id])
  }

  private func paste() {
    guard let data = Self.clipboardImage(), let picture = InboxSend.thumbnail(data) else {
      failure = "The clipboard image could not be read. Copy the image again and try Paste image."
      return
    }
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
      switch target {
      case .thread(let key): try chat.send(&draft, thread: key)
      case .new, .refused:
        guard let id = startAttempt() else { return }
        try chat.send(&draft, thread: nil, id: id)
      case .waiting: return
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
