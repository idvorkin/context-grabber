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
      if let problem = chat.listProblem, !inbox.offline {
        BugProblemView(
          problem: .grabber(problem, context: "ChatListView.refresh", extra: ["cockpit": .string(chat.cockpit)]),
          logger: logger)
      }
      if !chat.pendingThreads.isEmpty {
        Section("Not sent yet") {
          ForEach(chat.pendingThreads) { item in
            PendingThreadRow(
              item: item, thumbnail: inbox.thumbnails[item.id], away: inbox.cockpitAway && !inbox.offline,
              logger: logger
            )
            .swipeActions { Button("Delete", role: .destructive) { inbox.delete(item) } }
          }
        }
      }
      Section {
        ForEach(live) { thread in threadLink(thread) }
      }
      if !done.isEmpty {
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
    .task { await chat.refreshList(reason: "open") }
    .onAppear { chat.listOnScreen = true }
    .onDisappear { chat.listOnScreen = false }
    // #424, story 262: a fixed thumb target; the last row can scroll fully clear of it.
    .contentMargins(.bottom, 88, for: .scrollContent)
    .overlay(alignment: .bottomTrailing) {
      Button {
        chat.openNewChat(from: "chat")
      } label: {
        Image(systemName: "plus")
          .font(.title2.weight(.semibold))
          .foregroundStyle(.white)
          .frame(width: 56, height: 56)
          .background(Color.accentColor, in: Circle())
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("New chat")
      .accessibilityIdentifier("inbox-add")
      .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
      .padding(16)
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

  private func threadLink(_ thread: ChatSummary) -> some View {
    NavigationLink {
      ChatThreadView(chat: chat, voice: voice, key: thread.key, title: thread.title, logger: logger)
    } label: {
      ThreadRow(thread: thread)
    }
    .accessibilityIdentifier("chat-thread-\(thread.key)")
  }
}

private struct ThreadRow: View {
  let thread: ChatSummary

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Circle().fill(thread.unread > 0 ? Color.accentColor : .clear).frame(width: 9, height: 9).padding(.top, 6)
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline) {
          Text(thread.title).font(.body.weight(thread.unread > 0 ? .semibold : .regular)).lineLimit(2)
          Spacer(minLength: 8)
          if let at = thread.lastAt {
            Text(at, format: .relative(presentation: .numeric, unitsStyle: .abbreviated)).font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Text("\(thread.larryHasLastWord ? "Larry" : "You"): \(thread.lastText)").font(.subheadline)
          .foregroundStyle(.secondary).lineLimit(2)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

private struct PendingThreadRow: View {
  let item: InboxItem
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
      if let reason = item.refused {
        BugProblemView(
          problem: .grabber(
            "Larry refused it: \(reason)", context: "ChatListView.send",
            extra: ["item": .string(item.id), "kind": .string(item.kind.rawValue)]), logger: logger)
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
          ForEach(messages) { message in
            MessageBubble(message: message, cockpit: chat.cockpit, logger: logger)
          }
          // Their own ids: a message that reaches the Cockpit keeps its id, and a shared one in this LazyVStack
          // left the outbox bubble on screen after the Cockpit's had replaced it (seen on the simulator).
          ForEach(pending, id: \.pendingKey) { item in
            PendingBubble(
              item: item, thumbnail: inbox.thumbnails[item.id], away: inbox.cockpitAway && !inbox.offline,
              logger: logger
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
    .safeAreaInset(edge: .bottom) {
      ComposeBar(chat: chat, voice: voice, thread: barKey, target: target, logger: logger) {
        newThread.attempt(at: target)
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
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
}

private struct MessageBubble: View {
  let message: ChatMessage
  let cockpit: String
  let logger: BugLogger

  var body: some View {
    HStack {
      if message.fromIgor { Spacer(minLength: 48) }
      VStack(alignment: message.fromIgor ? .trailing : .leading, spacing: 4) {
        ForEach(message.attachments, id: \.self) { ref in
          if let url = ChatWire.attachmentURL(ref, cockpit: cockpit) {
            ChatImage(url: url, message: message.id, logger: logger)
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
            .textSelection(.enabled)
        }
        if message.fromIgor { receipt }
      }
      if !message.fromIgor { Spacer(minLength: 48) }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(message.fromIgor ? "chat-mine" : "chat-larry")
  }

  @ViewBuilder private var receipt: some View {
    switch message.receipt {
    case .sent: Text("sent").font(.caption2).foregroundStyle(.secondary)
    case .seen: Text("👀").font(.caption)
    case .done:
      Text("🏆" + (message.doneNote.map { " \($0)" } ?? "")).font(.caption).foregroundStyle(.secondary)
    }
  }
}

private struct PendingBubble: View {
  let item: InboxItem
  let thumbnail: CGImage?
  /// #565: the last send found the Cockpit not answering.
  let away: Bool
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
        if let reason = item.refused {
          BugProblemView(
            problem: .grabber(
              "Larry refused it: \(reason)", context: "ChatThreadView.send",
              extra: ["item": .string(item.id), "thread": .string(item.thread ?? "")]), logger: logger)
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
  let logger: BugLogger
  @State private var full = false

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
    .fullScreenCover(isPresented: $full) {
      ZStack(alignment: .topTrailing) {
        Color.black.ignoresSafeArea()
        AsyncImage(url: url) {
          $0.resizable().scaledToFit()
        } placeholder: {
          ProgressView()
        }
        Button("Done") { full = false }.padding().foregroundStyle(.white)
      }
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
  let logger: BugLogger
  /// A new chat's next first message: a fresh id, now the one the screen follows.
  var startAttempt: () -> String? = { nil }
  @State private var draft = InboxDraft()
  @State private var preview: CGImage?
  @State private var hasImage = UIPasteboard.general.hasImages
  @State private var failure: String?
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
      // #448: what the mic could not do, copyable, or its quieter line (a call has the mic, the five-minute stop),
      // each in the thread it came from only; then, in a new chat, where its next message stands (#536). Both show.
      if voice.thread == thread, let problem = voice.problem {
        BugProblemView(problem: problem, logger: logger)
      } else if voice.thread == thread, let notice = voice.notice {
        Text(notice).font(.footnote).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("chat-voice-notice")
      }
      if target == .waiting {
        Text("The next message goes once your first one reaches Larry.").font(.footnote).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("chat-new-waiting")
      } else if case .refused = target {
        Text("Larry refused your first message, so the next one starts the chat again.").font(.footnote)
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
      MicPicker(voice: voice)
      HStack(alignment: .bottom, spacing: 8) {
        Button(action: paste) {
          Image(systemName: "photo.on.rectangle").font(.title3)
        }
        .disabled(!hasImage)
        .accessibilityLabel("Paste image")
        MicButton(voice: voice, thread: thread, draft: draft.text)
        TextField("Message Larry", text: $draft.text, axis: .vertical)
          .lineLimit(1...6)
          .padding(.horizontal, 12).padding(.vertical, 8)
          .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
          .accessibilityIdentifier("chat-compose")
          .focused($focused)
          .id(field)
        Button(action: send) {
          Image(systemName: "arrow.up.circle.fill").font(.title)
        }
        .disabled(!draft.canAdd || target == .waiting)
        .accessibilityLabel("Send")
        .accessibilityIdentifier("chat-send")
      }
    }
    .padding(.horizontal, 12).padding(.vertical, 8)
    .background(.bar)
    // The words stream into the draft as Igor speaks, after what was typed, for him to read before he sends (#448).
    .onChange(of: voice.words) { _, _ in takeWords() }
    .onAppear {
      takeWords()
      // A new chat opens with the keyboard up (spec "A new chat", story 262).
      if target == .new { focused = true }
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

  private func paste() {
    guard let data = Self.clipboardImage(), let picture = InboxSend.thumbnail(data) else {
      failure = "The clipboard image could not be read. Copy the image again and try Paste image."
      return
    }
    draft.image = data
    preview = picture
    failure = nil
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
      failure = nil
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
/// out as BugKit's report microphone row.
// ponytail: no input-level meter yet — bug-kit is adding a public picker + live meter view; swap this menu for it
// when that release is pinned.
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
