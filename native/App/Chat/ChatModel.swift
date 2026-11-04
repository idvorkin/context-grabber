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
  @Published private(set) var threads: [ChatSummary] = []
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
  /// The last archive from the list, offered back for five seconds (#589).
  @Published private(set) var undoArchive: [ChatSummary] = []
  /// Why the last archive or unarchive didn't take.
  @Published private(set) var archiveProblem: String?
  private var undoTask: Task<Void, Never>?
  /// Bumped by each archive change and its answer: a list read that started before one is stale (it would put the
  /// thread back where it was), so it is read again.
  private var archiveEpoch = 0
  /// The archive change on its way for a thread, shown over any list that comes back meanwhile.
  private var archiving: [String: Bool] = [:]
  /// Each thread's latest archive change: the next one waits for its answer.
  private var archiveChanges: [String: Task<(title: String, reason: String)?, Never>] = [:]
  /// The list is on screen: only then does a refresh count its replies as shown (local review).
  var listOnScreen = false
  /// #603, set by the app: why a board can't be opened (nil when it can), given the board and where it was asked from.
  var findBoard: @MainActor (String, String) async -> BugProblem? = { _, _ in nil }
  /// #603, set by the app: leaves the thread for that board.
  var openBoard: @MainActor (String) -> Void = { _ in }

  static let backgroundTask = "com.idvorkin.grabbernative.chat"
  static let notifiedKey = "chat_notified"
  static let askedKey = "chat_asked_notifications"
  /// How often an open thread is read again.
  static let pollSeconds = 4.0
  /// How soon iOS may run the next background check (it decides when).
  static let backgroundInterval: TimeInterval = 15 * 60

  let inbox: InboxModel
  private let log: SessionLog
  private let database: AppDatabase
  let cockpit: String
  private var poll: Task<Void, Never>?

  init(inbox: InboxModel, log: SessionLog, database: AppDatabase, cockpit: String) {
    self.inbox = inbox
    self.log = log
    self.database = database
    self.cockpit = cockpit
    inbox.didAdd = { [weak self] in self?.askForNotificationsOnce() }
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
    let epoch = archiveEpoch
    let (data, response) = try await URLSession.shared.data(for: try ChatWire.listRequest(cockpit: cockpit))
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard status == 200, let rows = ChatWire.summaries(data) else { return (nil, status) }
    if epoch != archiveEpoch { return try await readList() }
    return (rows.map { row in archiving[row.key].map(row.archiving) ?? row }, status)
  }

  private static let listFailure = "Could not read the chats from the Cockpit"

  private func listFailed(_ why: String, reason: String, problem: String? = nil) {
    listProblem = problem ?? "\(Self.listFailure): \(why)"
    log.event("chat", ["action": "refresh_failed", "why": reason, "reason": why])
  }

  // MARK: Archiving (#589)

  /// One change at a time per thread, so each answer settles the row before the next change looks at it: an Undo
  /// while the archive is unanswered waits for that answer.
  func setArchived(_ key: String, _ archive: Bool, from: String) async {
    await setArchived([key], archive, from: from)
  }

  /// Several threads together (#599): one problem names every thread that didn't take.
  func setArchived(_ keys: [String], _ archive: Bool, from: String) async {
    let changes = keys.map { key in
      if !archive { undoArchive.removeAll { $0.key == key } }
      let earlier = archiveChanges[key]
      let change = Task {
        _ = await earlier?.value
        return await applyArchived(key, archive, from: from)
      }
      archiveChanges[key] = change
      return change
    }
    var failed: [(title: String, reason: String)] = []
    for change in changes {
      guard let failure = await change.value else { continue }
      failed.append(failure)
      archiveProblem = ChatWire.archiveProblem(failed, archive: archive)
    }
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

  /// Story 522: a Yes or No the phone could not keep. Which one and where, never the words.
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
    undoArchive = []
    await setArchived(keys, true, from: "select")
  }

  /// Archives or brings back `key` at once on screen, then on the Cockpit; a refusal puts the row back and is returned.
  private func applyArchived(_ key: String, _ archive: Bool, from: String) async -> (title: String, reason: String)? {
    guard let index = threads.firstIndex(where: { $0.key == key }), threads[index].archived != archive else {
      return nil
    }
    let before = threads[index]
    threads[index] = before.archiving(archive)
    archiveEpoch += 1
    archiving[key] = archive
    archiveProblem = nil
    if archive, from == "swipe" || from == "select" {
      undoArchive = from == "swipe" ? [before] : undoArchive + [before]
      undoTask?.cancel()
      undoTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
        self?.undoArchive = []
      }
    }
    var failure: String?
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try ChatWire.archiveRequest(key, archive: archive, cockpit: cockpit))
      failure = ChatWire.archiveFailure(status: (response as? HTTPURLResponse)?.statusCode, body: body)
    } catch {
      failure = ChatWire.archiveFailure(status: nil, body: nil, error: error.localizedDescription)
    }
    archiving[key] = nil
    archiveEpoch += 1
    log.event(
      "chat",
      [
        "action": archive ? "archive" : "unarchive", "thread": key, "from": from, "ok": failure == nil,
        "reason": failure ?? "",
      ])
    guard let failure else {
      // The Cockpit may still call it done (an old thread): its list settles where the row belongs.
      if !archive { await refreshList(reason: "unarchive") }
      return nil
    }
    if let now = threads.firstIndex(where: { $0.key == key }) { threads[now] = before }
    undoArchive.removeAll { $0.key == key }
    return (before.title, failure)
  }

  // MARK: One thread

  func open(_ key: String) {
    openThread = key
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
      threadProblem[key] = nil
      if let last = rows.last, last.isError, last.id != before {
        log.event("chat", ["action": "reply_failed", "thread": key, "message": last.id, "skill": last.author ?? ""])
      }
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

  /// This phone's messages for a thread that the Cockpit does not list yet: waiting, or refused.
  func pending(in key: String) -> [InboxItem] {
    let known = Set((messages[key] ?? []).map(\.id))
    return inbox.items.filter { ($0.thread == key || $0.chatThread == key) && !known.contains($0.id) }
      .sorted { $0.sharedAt < $1.sharedAt }
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
    #if targetEnvironment(simulator)
      log.event("chat", ["action": "schedule_skipped", "reason": "simulator"])
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
