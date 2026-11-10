//  Chat with Larry (spec 2026-10-25-native-chat-design.md, plan 2026-10-25-native-chat-plan.md): the Cockpit's chat
//  threads read here, one thread polled while it is on screen, and Larry's replies noticed in the background. What
//  Igor writes goes through the Inbox's store and sender (`InboxModel`), so it works offline and lands once.

import BackgroundTasks
import BugKit
import ContextCore
import Foundation
import UserNotifications

@MainActor
final class ChatModel: ObservableObject {
  /// Settable for the archive (`ChatArchiver`), which moves a row at once and puts it back on a refusal.
  @Published var threads: [ChatSummary] = []
  /// Why the list could not be read; nil once it has been.
  @Published private(set) var listProblem: String?
  @Published private(set) var messages: [String: [ChatMessage]] = [:]
  @Published private(set) var threadProblem: [String: String] = [:]
  /// The thread on screen, polled while it is.
  @Published private(set) var openThread: String?
  /// A thread a link asked for (a notification's tap): pushed over the list when it opens.
  @Published var linkThread: String?
  /// The + (#536): a new, empty thread is on screen, its first Send starts it.
  @Published var newChatOpen = false
  private var newChatVoice = ChatNewChatVoice()
  /// The last archive from the list, offered back for five seconds (#589); the archive sets it.
  @Published var undoArchive: [ChatSummary] = []
  /// Why the last archive or unarchive didn't take; the archive sets it.
  @Published var archiveProblem: String?
  /// Archiving's rules (#589, #599), in ContextCore with its host tests: this model only holds what it changes.
  private lazy var archiver = ChatArchiver(
    list: self, cockpit: cockpit,
    transport: { request in
      let (data, response) = try await URLSession.shared.data(for: request)
      return (data, (response as? HTTPURLResponse)?.statusCode)
    })
  /// The list is on screen: only then does a refresh count its replies as shown (local review).
  var listOnScreen = false
  /// #603, set by the app: why a board can't be opened (nil when it can), given the board and where it was asked from.
  var findBoard: @MainActor (String, String) async -> BugProblem? = { _, _ in nil }
  /// #603, set by the app: leaves the thread for that board.
  var openBoard: @MainActor (String) -> Void = { _ in }
  /// Threads whose strip of links Igor folded away (#736), remembered across launches.
  @Published private(set) var foldedLinks: Set<String> = []
  /// Each thread's links (#736), from its last read: the open thread's strip and a wide list's rows.
  @Published private(set) var rowLinks: [String: [ChatLink]] = [:]
  /// The row's last activity each thread's links were read for: read again only when it changes.
  private var rowLinksAt: [String: String] = [:]

  static let backgroundTask = "com.idvorkin.grabbernative.chat"
  static let notifiedKey = "chat_notified"
  static let askedKey = "chat_asked_notifications"
  static let foldedLinksKey = "chat_links_folded"
  /// How often an open thread is read again.
  static let pollSeconds = 4.0
  /// How soon iOS may run the next background check (it decides when).
  static let backgroundInterval: TimeInterval = 15 * 60

  let inbox: InboxModel
  private let log: SessionLog
  private let database: AppDatabase
  let cockpit: String
  private var poll: Task<Void, Never>?
  /// #809: which of each open thread's reads log an `outbox_thread` line.
  private var outboxLogged: [String: ChatOutboxLook.ThreadLog] = [:]

  init(inbox: InboxModel, log: SessionLog, database: AppDatabase, cockpit: String) {
    self.inbox = inbox
    self.log = log
    self.database = database
    self.cockpit = cockpit
    inbox.didAdd = { [weak self] in self?.askForNotificationsOnce() }
    foldedLinks =
      database.setting(Self.foldedLinksKey)
      .flatMap { try? JSONDecoder().decode(Set<String>.self, from: Data($0.utf8)) } ?? []
  }

  // MARK: Links in a thread (#736)

  func setLinksFolded(_ key: String, _ folded: Bool) {
    if folded { foldedLinks.insert(key) } else { foldedLinks.remove(key) }
    if let data = try? JSONEncoder().encode(foldedLinks.sorted()) {
      database.setSetting(Self.foldedLinksKey, String(decoding: data, as: UTF8.self))
    }
    log.event("chat", ["action": "links_folded", "thread": key, "folded": folded])
  }

  /// Where a chip was tapped: the strip, All links, or the list. Never the link itself.
  func logLinkOpened(_ link: ChatLink, thread: String, from place: String) {
    log.event("chat", ["action": "link_opened", "thread": thread, "from": place, "kind": link.kind.logName])
  }

  /// A wide list's row reads its thread's links once per new activity; a failure only logs, the row shows none.
  func readRowLinks(_ thread: ChatSummary) async {
    guard thread.count > 0, rowLinksAt[thread.key] != thread.lastTs, !inbox.offline,
      cockpit != ChatCockpit.nowhere
    else { return }
    do {
      let request = try ChatWire.threadRequest(thread.key, cockpit: cockpit)
      let (data, response) = try await URLSession.shared.data(for: request)
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let rows = ChatWire.messages(data) else {
        return rowLinksFailed(thread, "HTTP \(status)")
      }
      rowLinksAt[thread.key] = thread.lastTs
      rowLinks[thread.key] = ChatLinks.inThread(rows)
    } catch is CancellationError {
    } catch let error as URLError where error.code == .cancelled {
    } catch {
      rowLinksFailed(thread, error.localizedDescription)
    }
  }

  /// Logged once per thread and activity; the next activity tries again. A read the row cancelled is tried again.
  private func rowLinksFailed(_ thread: ChatSummary, _ why: String) {
    rowLinksAt[thread.key] = thread.lastTs
    log.event("chat", ["action": "links_read_failed", "thread": thread.key, "reason": why])
  }

  // MARK: A pull request's state on its chip (#736, option C)

  /// What the Cockpit last said of each PR ref; a chip whose ref is missing shows its number alone.
  @Published private(set) var prStates: [String: ChatLink.PullRequestState] = [:]
  /// Set by a failed check, cleared by an answer: a Cockpit that stays down is logged once.
  private var prStatesFailing = false

  /// The links as their chips read, with the states known so far.
  func withStates(_ links: [ChatLink]) -> [ChatLink] { ChatPRStates.applied(prStates, to: links) }

  /// Asks the Cockpit for these PRs' states until cancelled: the open thread's and a wide list's `.task`.
  /// ponytail: polls every 30 s (5 s while a ref is pending); /pr-states/stream (SSE, snapshot then deltas, resumed by
  /// Last-Event-ID, ends after 10 min) would flip a chip at once — the upgrade if half a minute feels slow.
  func watchPRStates(_ refs: [String], from place: String) async {
    guard !refs.isEmpty else { return }
    while !Task.isCancelled {
      let pending = await readPRStates(refs, from: place)
      try? await Task.sleep(for: .seconds(pending ? ChatPRStates.pendingSeconds : ChatPRStates.pollSeconds))
    }
  }

  /// One check; true when the Cockpit is still looking a ref up. Offline or with no address it asks nothing.
  private func readPRStates(_ refs: [String], from place: String) async -> Bool {
    guard !inbox.offline, cockpit != ChatCockpit.nowhere else { return false }
    do {
      let (data, response) = try await URLSession.shared.data(for: try ChatPRStates.request(refs, cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let answer = ChatPRStates.parse(data) else {
        let said = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
        let why = status == 200 ? "bad answer: \(said ?? "unreadable")" : "HTTP \(status)"
        prStatesFailed(why, refs: refs.count, from: place)
        return false
      }
      prStatesFailing = false
      var next = prStates
      for ref in refs { next[ref] = answer.states[ref] }
      if next != prStates { prStates = next }
      return answer.pending
    } catch is CancellationError {
    } catch let error as URLError where error.code == .cancelled {
    } catch {
      prStatesFailed(error.localizedDescription, refs: refs.count, from: place)
    }
    return false
  }

  /// The chips keep what they showed; only the log hears of it, once until a check succeeds.
  private func prStatesFailed(_ why: String, refs: Int, from place: String) {
    guard !prStatesFailing else { return }
    prStatesFailing = true
    log.event("chat", ["action": "pr_states_failed", "reason": why, "refs": refs, "from": place])
  }

  func title(of key: String) -> String { threads.first { $0.key == key }?.title ?? "Chat" }

  /// Who a message on this thread goes to: a skill's name on its thread (#632), otherwise Larry.
  func answeredBy(_ key: String?) -> String { threads.first { $0.key == key }?.answeredBy ?? "Larry" }

  /// Live threads with a reply Igor has not read, plus what has not left the phone: the tile's number.
  var badgeCount: Int { threads.filter { !$0.done && $0.unread > 0 }.count + inbox.waitingCount }

  // MARK: The list

  func refreshList(reason: String) async {
    inbox.reload()
    guard !inbox.offline else { return }
    guard cockpit != ChatCockpit.nowhere else {
      return listFailed(ChatCockpit.noAddress, reason: reason, problem: ChatCockpit.noAddress)
    }
    do {
      let (read, status) = try await readList()
      guard let rows = read else {
        return listFailed("the Cockpit answered HTTP \(status)", reason: reason)
      }
      threads = rows
      listProblem = nil
      if reason == "pull" { archiveProblem = nil }
      // On screen is seen: a reply shown in the list never notifies later. A refresh behind Home does not count.
      if listOnScreen { recordShown(rows) }
      log.event(
        "chat",
        [
          "action": "refreshed", "why": reason, "threads": rows.count,
          "unread": rows.filter { !$0.done && $0.unread > 0 }.count,
        ])
    } catch {
      listFailed(
        error.localizedDescription, reason: reason,
        problem: CockpitReach.problem(error, otherwise: Self.listFailure))
    }
  }

  /// The Cockpit's list with this phone's archive changes over it, nil when it could not be read. The caller publishes
  /// it with no await in between.
  private func readList() async throws -> (rows: [ChatSummary]?, status: Int) {
    let epoch = archiver.epoch
    let (data, response) = try await URLSession.shared.data(for: try ChatWire.listRequest(cockpit: cockpit))
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard status == 200, let rows = ChatWire.summaries(data) else { return (nil, status) }
    // Started before an archive change or its answer, it would put the thread back where it was: read again.
    if !archiver.isCurrent(epoch) { return try await readList() }
    return (archiver.overlaid(rows), status)
  }

  private static let listFailure = "Could not read the chats from the Cockpit"

  private func listFailed(_ why: String, reason: String, problem: String? = nil) {
    listProblem = problem ?? "\(Self.listFailure): \(why)"
    log.event("chat", ["action": "refresh_failed", "why": reason, "reason": why])
  }

  // MARK: Archiving (#589)

  /// One change at a time per thread, so an Undo while the archive is unanswered waits for that answer.
  func setArchived(_ key: String, _ archive: Bool, from: String) async {
    await archiver.setArchived(key, archive, from: from)
  }

  /// Several threads together (#599): one problem names every thread that didn't take.
  func setArchived(_ keys: [String], _ archive: Bool, from: String) async {
    await archiver.setArchived(keys, archive, from: from)
  }

  func logAction(_ action: String, _ fields: [String: Any] = [:]) {
    log.event("chat", fields.merging(["action": action]) { _, new in new })
  }

  /// Story 493: a pick that didn't take. The problem's own fields, or for the picker's error its code: never the name.
  func logAttachFailure(_ error: Error) {
    let ns = error as NSError
    let fields = (error as? ChatFile.Problem)?.logFields ?? ["problem": "picker", "domain": ns.domain, "code": ns.code]
    log.event("error", fields.merging(["where": "chat_attach"]) { _, new in new })
  }

  /// Story 542: a Yes or No the phone could not keep. Which one and where, never the words.
  func logReactionFailure(_ error: Error, reaction: ChatReaction, thread: String, message: String) {
    log.event(
      "error",
      [
        "where": "chat_react", "thread": thread, "message": message, "reaction": reaction.rawValue,
        "reason": error.localizedDescription,
      ])
  }

  /// The ticked threads, together (#599). The undo offer covers only this batch.
  func archiveSelected(_ keys: [String]) async {
    await archiver.archiveSelected(keys)
  }

  // MARK: One thread

  func open(_ key: String) {
    openThread = key
    outboxLogged[key] = nil
    log.event(
      "ui",
      [
        "action": "open_chat_thread", "thread": key,
        "archived": threads.first { $0.key == key }.map { $0.archived ? "yes" : "no" } ?? "not_listed",
        "skill": threads.first { $0.key == key }?.skill ?? "",
      ])
    poll?.cancel()
    poll = Task { [weak self] in
      var seenOnce = false
      while !Task.isCancelled {
        guard let self, self.openThread == key else { return }
        // Until the first load lands and is marked seen, every poll tries again (local review).
        if await self.load(key, markSeen: !seenOnce) { seenOnce = true }
        try? await Task.sleep(for: .seconds(Self.pollSeconds))
      }
    }
  }

  func close(_ key: String) {
    guard openThread == key else { return }
    openThread = nil
    poll?.cancel()
    poll = nil
    Task { await refreshList(reason: "thread_closed") }
  }

  /// True once the thread was read and, when asked, marked seen.
  @discardableResult
  private func load(_ key: String, markSeen: Bool) async -> Bool {
    guard !inbox.offline else { return false }
    guard cockpit != ChatCockpit.nowhere else {
      threadFailed(key, ChatCockpit.noAddress, why: ChatCockpit.noAddress)
      return false
    }
    do {
      let (data, response) = try await URLSession.shared.data(for: try ChatWire.threadRequest(key, cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let rows = ChatWire.messages(data) else {
        threadFailed(key, "\(Self.threadFailure): HTTP \(status)", why: "HTTP \(status)")
        return false
      }
      let before = messages[key]?.last?.id
      messages[key] = rows
      rowLinks[key] = ChatLinks.inThread(rows)
      threadProblem[key] = nil
      if let last = rows.last, last.isError, last.id != before {
        log.event("chat", ["action": "reply_failed", "thread": key, "message": last.id, "skill": last.author ?? ""])
      }
      logOutbox(key, rows)
      // A sent message the Cockpit's thread now holds is done with the outbox.
      let known = Set(rows.map(\.id))
      let delivered = inbox.items.filter { $0.status == .sent && $0.chatThread == key && known.contains($0.id) }
      if !delivered.isEmpty { inbox.forget(delivered) }
      // What is on screen is shown: it never notifies later.
      if let last = rows.last, !last.ts.isEmpty { notified[key] = last.ts }
      // A new reply on screen is read here and on the laptop.
      if markSeen || (before != nil && rows.last?.id != before && rows.last?.fromIgor == false) {
        return await seen(key)
      }
      return true
    } catch {
      threadFailed(
        key, CockpitReach.problem(error, otherwise: Self.threadFailure), why: error.localizedDescription)
      return false
    }
  }

  /// #809: the thread's share of the outbox, once per open, again when the sent items it does not hold change, and
  /// once when one has stayed unheld for minutes.
  private func logOutbox(_ key: String, _ rows: [ChatMessage]) {
    let look = ChatOutboxLook.thread(
      key, items: inbox.items, messages: rows, now: Int64(Date().timeIntervalSince1970 * 1000))
    guard outboxLogged[key, default: .init()].logs(look) else { return }
    log.event("chat", look.logFields(thread: key))
  }

  private static let threadFailure = "Could not read this chat from the Cockpit"

  /// Logged once per spell: a poll that fails the same way again stays quiet.
  private func threadFailed(_ key: String, _ problem: String, why: String) {
    if threadProblem[key] != problem { log.event("error", ["where": "chat_thread", "thread": key, "message": why]) }
    threadProblem[key] = problem
  }

  @discardableResult
  private func seen(_ key: String) async -> Bool {
    do {
      let (_, response) = try await URLSession.shared.data(for: try ChatWire.seenRequest(key, cockpit: cockpit))
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        log.event("chat", ["action": "seen_failed", "thread": key, "reason": "not 200"])
        return false
      }
      if let i = threads.firstIndex(where: { $0.key == key }) { threads[i] = threads[i].read() }
      return true
    } catch {
      log.event("chat", ["action": "seen_failed", "thread": key, "reason": error.localizedDescription])
      return false
    }
  }

  /// This phone's messages for a thread that the Cockpit does not list yet: waiting, refused, or just sent.
  func pending(in key: String) -> [InboxItem] {
    ChatWire.pending(
      in: key, items: inbox.items, messages: messages[key], now: Int64(Date().timeIntervalSince1970 * 1000))
  }

  /// New threads not yet on the Cockpit (a share or a + that has not left the phone, or was refused), and a message
  /// for a chat the list does not hold (#587).
  var pendingThreads: [InboxItem] { ChatWire.pendingThreads(inbox.items, listed: threads) }

  var earlierShares: [InboxItem] { inbox.items.filter(\.isEarlierShare) }

  // MARK: Writing

  /// The + (#536): an empty thread with the ordinary bar, not a sheet. `voice`: the button beside it (#637), the same
  /// thread with its mic tapped as it opens.
  func openNewChat(from source: String, voice: Bool = false) {
    log.event("ui", ["action": "open_new_chat", "from": source, "voice": voice])
    newChatVoice.open(voice: voice)
    newChatOpen = true
  }

  /// Whether the new chat coming on screen should start recording, once per tap.
  func takeNewChatVoice() -> Bool { newChatVoice.take() }

  /// One message, kept on the phone first and sent through the Inbox's sender. `thread` nil starts a new one, under
  /// `id` so a new chat's screen can follow its first message to the thread it lands in.
  func send(_ draft: inout InboxDraft, thread: String?, id: String = UUID().uuidString.lowercased()) throws {
    try inbox.add(&draft, id: id, thread: thread)
    if let thread { Task { await load(thread, markSeen: false) } }
  }

  /// What the bar held one run-loop after a send (#449): anything left is text the field wrote back.
  func noteBarAfterSend(thread: String, leftChars: Int) {
    log.event("chat", ["action": "bar_after_send", "thread": thread, "left_chars": leftChars])
  }

  private func askForNotificationsOnce() {
    guard database.setting(Self.askedKey) == nil else { return }
    database.setSetting(Self.askedKey, "1")
    Task { [log] in
      let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]))
      log.event("chat", ["action": "notifications_asked", "granted": granted ?? false])
    }
  }

  // MARK: Hearing back

  private var notified: [String: String] {
    get {
      database.setting(Self.notifiedKey).flatMap {
        try? JSONDecoder().decode([String: String].self, from: Data($0.utf8))
      }
        ?? [:]
    }
    set {
      if let data = try? JSONEncoder().encode(newValue) {
        database.setSetting(Self.notifiedKey, String(decoding: data, as: UTF8.self))
      }
    }
  }

  private func recordShown(_ rows: [ChatSummary]) {
    notified = ChatNotify.record(rows, into: notified)
  }

  /// Before the launch finishes, or iOS refuses the handler.
  func registerBackgroundTask() {
    let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundTask, using: nil) {
      [weak self] task in
      Task { @MainActor in self?.handle(task) }
    }
    if !registered { log.event("error", ["where": "chat_register", "task": Self.backgroundTask]) }
  }

  func scheduleBackgroundCheck() {
    #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
      log.event("chat", ["action": "schedule_skipped", "reason": ChatCockpit.isMac ? "mac" : "simulator"])
    #else
      let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTask)
      request.earliestBeginDate = Date().addingTimeInterval(Self.backgroundInterval)
      do {
        try BGTaskScheduler.shared.submit(request)
      } catch {
        log.event("error", ["where": "chat_schedule", "message": "\(error)"])
      }
    #endif
  }

  private func handle(_ task: BGTask) {
    scheduleBackgroundCheck()
    let check = Task { [weak self] in await self?.backgroundCheck() ?? false }
    task.expirationHandler = { check.cancel() }
    Task {
      task.setTaskCompleted(success: await check.value)
    }
  }

  /// Reads the list and raises one notification per thread with a reply not yet shown or notified.
  @discardableResult
  func backgroundCheck() async -> Bool {
    do {
      guard let rows = try await readList().rows else {
        log.event("chat", ["action": "background_check", "ok": false])
        return false
      }
      threads = rows
      let due = ChatNotify.due(rows, notified: notified)
      for summary in due { await notify(summary) }
      notified = ChatNotify.record(rows, into: notified)
      log.event("chat", ["action": "background_check", "ok": true, "threads": rows.count, "notified": due.count])
      return true
    } catch {
      log.event("chat", ["action": "background_check", "ok": false, "reason": error.localizedDescription])
      return false
    }
  }

  private func notify(_ summary: ChatSummary) async {
    let content = UNMutableNotificationContent()
    content.title = summary.lastSpeaker
    content.subtitle = summary.title
    content.body = summary.lastText
    content.sound = .default
    content.threadIdentifier = summary.key
    content.userInfo = ["thread": summary.key]
    let request = UNNotificationRequest(
      identifier: "chat-\(summary.key)-\(summary.lastTs)", content: content, trigger: nil)
    do {
      try await UNUserNotificationCenter.current().add(request)
    } catch {
      log.event("error", ["where": "chat_notify", "thread": summary.key, "message": "\(error)"])
    }
  }
}

extension ChatModel: ChatArchiveList {
  func archiveLogged(_ event: ChatArchiver.Event) { log.event("chat", event.fields) }

  func archiveUnarchived() async { await refreshList(reason: "unarchive") }
}

/// A tap on a reply's notification opens its thread; one arriving while the app is open shows unless that thread
/// is already on screen.
final class ChatNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  var open: (@MainActor (String) -> Void)?
  var onScreen: (@MainActor () -> String?)?

  // The completion-handler forms, not the async ones: returning from an async one calls UIKit's completion off the main
  // thread, which raises "Call must be made on main thread" and kills the app on a tapped notification (#610).
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completion: @escaping () -> Void
  ) {
    let thread = response.notification.request.content.userInfo["thread"] as? String
    Task { @MainActor in
      if let thread { open?(thread) }
      completion()
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let thread = notification.request.content.userInfo["thread"] as? String
    Task { @MainActor in
      completion(thread != nil && thread == onScreen?() ? [] : [.banner, .list, .sound])
    }
  }
}
