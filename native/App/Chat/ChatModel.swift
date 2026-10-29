//  Chat with Larry (spec 2026-10-25-native-chat-design.md, plan 2026-10-25-native-chat-plan.md): the Cockpit's chat
//  threads read here, one thread polled while it is on screen, and Larry's replies noticed in the background. What
//  Igor writes goes through the Inbox's store and sender (`InboxModel`), so it works offline and lands once.

import BackgroundTasks
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
  /// The list is on screen: only then does a refresh count its replies as shown (local review).
  var listOnScreen = false

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

  init(inbox: InboxModel, log: SessionLog, database: AppDatabase, cockpit: String = CockpitPage.url) {
    self.inbox = inbox
    self.log = log
    self.database = database
    self.cockpit = cockpit
    inbox.didAdd = { [weak self] in self?.askForNotificationsOnce() }
  }

  func title(of key: String) -> String { threads.first { $0.key == key }?.title ?? "Chat" }

  /// Live threads with a reply Igor has not read, plus what has not left the phone: the tile's number.
  var badgeCount: Int { threads.filter { !$0.done && $0.unread > 0 }.count + inbox.waitingCount }

  // MARK: The list

  func refreshList(reason: String) async {
    inbox.reload()
    guard !inbox.offline else { return }
    do {
      let (data, response) = try await URLSession.shared.data(for: try ChatWire.listRequest(cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let rows = ChatWire.summaries(data) else {
        return listFailed("the Cockpit answered HTTP \(status)", reason: reason)
      }
      threads = rows
      listProblem = nil
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

  private static let listFailure = "Could not read the chats from the Cockpit"

  private func listFailed(_ why: String, reason: String, problem: String? = nil) {
    listProblem = problem ?? "\(Self.listFailure): \(why)"
    log.event("chat", ["action": "refresh_failed", "why": reason, "reason": why])
  }

  // MARK: One thread

  func open(_ key: String) {
    openThread = key
    log.event("ui", ["action": "open_chat_thread", "thread": key])
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
      if let i = threads.firstIndex(where: { $0.key == key }) {
        let t = threads[i]
        threads[i] = ChatSummary(
          key: t.key, title: t.title, count: t.count, lastTs: t.lastTs, lastWho: t.lastWho, lastText: t.lastText,
          unread: 0, done: t.done)
      }
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

  /// New threads not yet on the Cockpit: a share or a + that has not left the phone, or was refused.
  var pendingThreads: [InboxItem] { inbox.items.filter { $0.thread == nil && $0.status != .sent } }

  var earlierShares: [InboxItem] { inbox.items.filter(\.isEarlierShare) }

  // MARK: Writing

  /// The + (#536): an empty thread with the ordinary bar, not a sheet.
  func openNewChat(from source: String) {
    log.event("ui", ["action": "open_new_chat", "from": source])
    newChatOpen = true
  }

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
      let (data, response) = try await URLSession.shared.data(for: try ChatWire.listRequest(cockpit: cockpit))
      guard (response as? HTTPURLResponse)?.statusCode == 200, let rows = ChatWire.summaries(data) else {
        log.event("chat", ["action": "background_check", "ok": false])
        return false
      }
      let due = ChatNotify.due(rows, notified: notified)
      for summary in due { await notify(summary) }
      notified = ChatNotify.record(rows, into: notified)
      threads = rows
      log.event("chat", ["action": "background_check", "ok": true, "threads": rows.count, "notified": due.count])
      return true
    } catch {
      log.event("chat", ["action": "background_check", "ok": false, "reason": error.localizedDescription])
      return false
    }
  }

  private func notify(_ summary: ChatSummary) async {
    let content = UNMutableNotificationContent()
    content.title = "Larry"
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

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    guard let thread = response.notification.request.content.userInfo["thread"] as? String else { return }
    await MainActor.run { open?(thread) }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    let thread = notification.request.content.userInfo["thread"] as? String
    let showing = await MainActor.run { onScreen?() }
    return thread != nil && thread == showing ? [] : [.banner, .list, .sound]
  }
}
