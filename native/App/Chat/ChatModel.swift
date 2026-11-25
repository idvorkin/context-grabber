//  Chat with Larry (spec 2026-10-25-native-chat-design.md, plan 2026-10-25-native-chat-plan.md): the Cockpit's chat
//  threads read here, one thread polled while it is on screen, and Larry's replies noticed in the background. What
//  Igor writes goes through the Inbox's store and sender (`InboxModel`), so it works offline and lands once.

import BackgroundTasks
import BugKit
import ContextCore
import Foundation
import SwiftUI
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
  /// Story 1136: the Cockpit's outage as the reads see it; a problem from it files no report of its own.
  private var outage = CockpitOutage()
  /// Whether the list's problem, and each thread's, came from an outage (or the device offline): it files nothing.
  @Published private(set) var listQuiet = false
  @Published private(set) var threadQuiet: Set<String> = []
  /// Story 1136: while the list shows an outage's problem on screen, it reads again this often.
  static let listRetrySeconds = 15.0
  private var listRetry: Task<Void, Never>?
  /// Stories 1604–1606: the Cockpit down, as the list and each thread see it, for their *Cockpit not answering* banner.
  private var listDown = CockpitDown()
  private var threadDown: [String: CockpitDown] = [:]
  /// #603, set by the app: why a board can't be opened (nil when it can), given the board and where it was asked from.
  var findBoard: @MainActor (String, String) async -> BugProblem? = { _, _ in nil }
  /// #603, set by the app: leaves the thread for that board.
  var openBoard: @MainActor (String) -> Void = { _ in }
  /// Story 569 (#1454), set by the app: a web ink board's page in the browser, given where it was opened from, and the
  /// problem when it can't open. The app can't draw one, so it is never looked for among the app's boards.
  var openWebBoard: @MainActor (WebInkBoard, String) async -> BugProblem? = { _, _ in nil }
  /// Bead context-grabber-dbku, set by the app: the board's own screen, slid in over a thread, told which thread it was
  /// jumped from and the boards set aside under it; nil when the board isn't here.
  var boardScreen: @MainActor (_ board: String, _ fromThread: String?, _ under: BoardsUnder) -> AnyView? = {
    _, _, _ in nil
  }
  /// Bead context-grabber-dbku, story 1208, set by the app: the board is already open on this device (its own window,
  /// the whiteboard behind), so a jump brings that one forward instead of opening a second copy.
  var boardOpenElsewhere: @MainActor (String) -> Bool = { _ in false }
  /// The list or a thread has left the screen: when Chat is closing, a link waiting for it goes on (bead
  /// context-grabber-mzdf). It also leaves when a thread is pushed over it, which the stack tells apart.
  var viewGone: @MainActor () -> Void = {}
  /// Threads whose strip of links Igor folded away (#736), remembered across launches.
  @Published private(set) var foldedLinks: Set<String> = []
  /// Each thread's links (#736), from its last read: the open thread's strip and a wide list's rows.
  @Published private(set) var rowLinks: [String: [ChatLink]] = [:]
  /// The row's last activity each thread's links were read for: read again only when it changes.
  private var rowLinksAt: [String: String] = [:]
  /// Bead context-grabber-exg6: the list's reads, and each thread's, in order; only the newest finished one shows.
  private var listOrder = ChatReadOrder()
  private var threadOrder: [String: ChatReadOrder] = [:]

  static let backgroundTask = "com.idvorkin.grabbernative.chat"
  static let notifiedKey = "chat_notified"
  static let askedKey = "chat_asked_notifications"
  static let foldedLinksKey = "chat_links_folded"
  /// Larry's *Looks done* proposals turned down on this phone (#1098), remembered across launches.
  private var declined = ChatLooksDoneDeclined()
  /// How often an open thread is read again.
  static let pollSeconds = 4.0
  /// How soon iOS may run the next background check (it decides when).
  static let backgroundInterval: TimeInterval = 15 * 60

  let inbox: InboxModel
  /// Larry's open asks as decision cards (#878).
  let decisions: ChatDecisionsModel
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
    decisions = ChatDecisionsModel(log: log, inbox: inbox, cockpit: cockpit)
    inbox.didAdd = { [weak self] in self?.askForNotificationsOnce() }
    decisions.readThread = { [weak self] key in await self?.readAgain(key) }
    foldedLinks =
      database.setting(Self.foldedLinksKey)
      .flatMap { try? JSONDecoder().decode(Set<String>.self, from: Data($0.utf8)) } ?? []
    declined = .restored(database.setting(ChatLooksDoneDeclined.settingKey))
    restoreSiteNames()
  }

  // MARK: Turning down Larry's proposals (#1098)

  /// A swipe's *Not done*, or a Review's unticked proposals on *Archive (N)*: the mark goes at once and stays gone
  /// until the Cockpit drops that proposal.
  func declineLooksDone(_ keys: [String], from: String) {
    let new = declined.decline(keys)
    guard !new.isEmpty else { return }
    saveDeclined()
    threads = declined.masked(threads)
    for key in new { log.event("chat", ["action": "looks_done_declined", "thread": key, "from": from]) }
  }

  /// A list the Cockpit answered, with what this phone turned down taken off it.
  private func shown(_ rows: [ChatSummary]) -> [ChatSummary] {
    let before = declined
    let shown = declined.fresh(rows)
    if declined != before {
      saveDeclined()
      log.event("chat", ["action": "looks_done_forgotten", "threads": before.keys.subtracting(declined.keys).count])
    }
    return shown
  }

  private func saveDeclined() { database.setSetting(ChatLooksDoneDeclined.settingKey, declined.saved) }

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

  // MARK: Site names from the Cockpit (story 1135)

  private static let siteNamesKey = "chat_site_names"
  /// A Cockpit without the list (or down) is logged once a launch, not on every chat opened.
  private static var siteNamesFailed = false

  /// The last list the Cockpit gave, kept across launches; the shipped names until there is one.
  private func restoreSiteNames() {
    guard let saved = database.setting(Self.siteNamesKey), let names = ChatSiteNames.parse(Data(saved.utf8)) else {
      return
    }
    ChatSiteNames.current = names
  }

  /// Asks the Cockpit for its site names when a chat opens. A new list redraws the chips and is kept; a failure or an
  /// unreadable answer keeps what the chips read now, and only the log hears of it.
  private func readSiteNames() async {
    guard !inbox.offline, cockpit != ChatCockpit.nowhere else { return }
    do {
      let (data, response) = try await URLSession.shared.data(for: try ChatSiteNames.request(cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let names = ChatSiteNames.parse(data) else {
        siteNamesFailed(status == 200 ? "unreadable" : "HTTP \(status)")
        return
      }
      guard names != ChatSiteNames.current else { return }
      ChatSiteNames.current = names
      rowLinks = rowLinks.mapValues { $0.map(ChatLinks.relabeled) }
      database.setSetting(Self.siteNamesKey, String(decoding: names.saved, as: UTF8.self))
      objectWillChange.send()
      log.event("chat", ["action": "site_names_read", "sites": names.names.count])
    } catch is CancellationError {
    } catch let error as URLError where error.code == .cancelled {
    } catch {
      siteNamesFailed(error.localizedDescription)
    }
  }

  private func siteNamesFailed(_ why: String) {
    guard !Self.siteNamesFailed else { return }
    Self.siteNamesFailed = true
    log.event("chat", ["action": "site_names_failed", "reason": why])
  }

  func title(of key: String) -> String {
    threads.first { $0.key == key }?.title ?? movedTitles[key] ?? "Chat"
  }

  /// Who a message on this thread goes to: a skill's name on its thread (#632), otherwise Larry.
  func answeredBy(_ key: String?) -> String { threads.first { $0.key == key }?.answeredBy ?? "Larry" }

  /// Live threads with a reply Igor has not read, plus what has not left the phone: the tile's number.
  var badgeCount: Int { threads.filter { !$0.done && $0.unread > 0 }.count + inbox.waitingCount }

  // MARK: The list

  func refreshList(reason: String) async {
    inbox.reload()
    guard !inbox.offline else { return }
    guard cockpit != ChatCockpit.nowhere else {
      return listFailed(ChatCockpit.noAddress, reason: reason, kind: .other, problem: ChatCockpit.noAddress)
    }
    let ticket = listOrder.start()
    do {
      let (read, status) = try await readList()
      // An older read finishing after a newer one has shown never puts its answer or problem back (exg6).
      guard listOrder.mayShow(ticket) else {
        return log.event("chat", ["action": "refresh_stale", "why": reason])
      }
      guard let rows = read else {
        if CockpitDown.isDown(status: status) {
          return listDownFailed(CockpitDown.how(status: status), why: "HTTP \(status)", reason: reason)
        }
        return listFailed(
          "the Cockpit answered HTTP \(status)", reason: reason, kind: CockpitOutage.kind(status: status))
      }
      threads = shown(rows)
      readGotThrough()
      listDown.answered(now: Self.nowMs)
      listQuiet = false
      listProblem = nil
      if reason == "pull" { archiveProblem = nil }
      // #878: the rows' *Decision waiting* and the Decisions row come from the open asks.
      await decisions.refresh(reason: reason)
      // On screen is seen: a reply shown in the list never notifies later. A refresh behind Home does not count.
      if listOnScreen { recordShown(rows) }
      log.event(
        "chat",
        [
          "action": "refreshed", "why": reason, "threads": rows.count,
          "unread": rows.filter { !$0.done && $0.unread > 0 }.count,
        ])
    } catch  where ChatReadOrder.isCancellation(error) {
      // Leaving the list mid-read, or iOS cutting it short, is not a failure: what the list showed stays (exg6).
      log.event("chat", ["action": "refresh_cancelled", "why": reason])
    } catch {
      guard listOrder.mayShow(ticket) else {
        return log.event("chat", ["action": "refresh_stale", "why": reason])
      }
      if CockpitDown.isDown(error) {
        return listDownFailed(CockpitDown.how(error), why: error.localizedDescription, reason: reason)
      }
      listFailed(
        error.localizedDescription, reason: reason, kind: CockpitOutage.kind(error),
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

  private func listFailed(_ why: String, reason: String, kind: CockpitOutage.Kind, problem: String? = nil) {
    let shown = problem ?? "\(Self.listFailure): \(why)"
    listQuiet = readFailed(kind, problem: shown, context: "ChatListView.refresh", extra: ["cockpit": .string(cockpit)])
    listProblem = shown
    log.event("chat", ["action": "refresh_failed", "why": reason, "reason": why])
    if kind != .other { retryList() }
  }

  /// Stories 1604–1606: the list's read found the Cockpit down. The banner, with the rows last read kept under it,
  /// shows at once on an empty list, else at the second failure in a row; the list keeps reading meanwhile.
  private func listDownFailed(_ how: String, why: String, reason: String) {
    let shows = listDown.failed(how, loaded: !threads.isEmpty, now: Self.nowMs)
    let problem = listDown.problem(what: "reading the chats", timeZone: .current)
    let quiet = readFailed(
      .away, problem: problem, context: "ChatListView.refresh", extra: ["cockpit": .string(cockpit)])
    if shows {
      listQuiet = quiet
      listProblem = problem
    }
    log.event(
      "chat",
      [
        "action": "refresh_failed", "why": reason, "reason": why, "down": true, "shown": shows,
        "failures": listDown.failures,
      ])
    retryList()
  }

  /// Story 1602: while the Cockpit is away the list reads again until it reads or the list leaves the screen.
  private func retryList() {
    guard listOnScreen else { return }
    listRetry?.cancel()
    listRetry = Task { [weak self] in
      try? await Task.sleep(for: .seconds(Self.listRetrySeconds))
      guard let self, !Task.isCancelled, self.listOnScreen, self.listProblem != nil || self.listDown.since != nil
      else { return }
      await self.refreshList(reason: "retry")
    }
  }

  /// Story 1136: a read failed with `kind`. True when its problem on screen must file nothing (an outage, or the
  /// device offline); when the outage has lasted long enough, it files its one report here.
  private func readFailed(
    _ kind: CockpitOutage.Kind, problem: String, context: String, extra: [String: JSONValue]
  ) -> Bool {
    let verdict = outage.failed(kind, now: Self.nowMs)
    switch verdict {
    case .file: return false
    case .quiet: return true
    case .fileOutage(let ms, let failures):
      log.event(
        "chat", ["action": "cockpit_outage", "state": "filed", "ms": ms, "failures": failures, "where": context])
      var fields = extra
      fields["outage_ms"] = .int(Int(ms))
      fields["failures"] = .int(failures)
      let report = BugProblem.grabber(
        "\(problem) (the Cockpit has been away for \(ms / 60_000) minutes, \(failures) reads failed)",
        context: context, extra: fields)
      Task { await BugProblemFiler.current?.file(report) }
      return true
    }
  }

  /// Story 1136: a read got through, so any outage is over.
  private func readGotThrough() {
    guard let ended = outage.succeeded(now: Self.nowMs) else { return }
    log.event(
      "chat",
      ["action": "cockpit_outage", "state": "ended", "ms": ended.ms, "failures": ended.failures, "filed": ended.filed])
  }

  private static var nowMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

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
    // #878: the card at the top comes from the open asks, read once per open, not on every poll.
    decisions.threadOpened(key)
    Task { await decisions.refresh(reason: "thread") }
    Task { await readSiteNames() }
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

  /// #878: Igor's answer is now a row in the open thread; read it now rather than on the next poll.
  func readAgain(_ key: String) async {
    guard openThread == key else { return }
    await load(key, markSeen: false)
  }

  /// True once the thread was read and, when asked, marked seen.
  @discardableResult
  private func load(_ key: String, markSeen: Bool) async -> Bool {
    guard !inbox.offline else { return false }
    guard cockpit != ChatCockpit.nowhere else {
      threadFailed(key, ChatCockpit.noAddress, why: ChatCockpit.noAddress, kind: .other)
      return false
    }
    let ticket = threadOrder[key, default: ChatReadOrder()].start()
    do {
      let (data, response) = try await URLSession.shared.data(for: try ChatWire.threadRequest(key, cockpit: cockpit))
      // A poll, a send and an answered card can read at once: only the newest finished read shows (exg6).
      guard threadOrder[key, default: ChatReadOrder()].mayShow(ticket) else {
        log.event("chat", ["action": "thread_read_dropped", "thread": key, "reason": "stale"])
        return false
      }
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let rows = ChatWire.messages(data) else {
        if CockpitDown.isDown(status: status) {
          threadDownFailed(key, CockpitDown.how(status: status), why: "HTTP \(status)")
          return false
        }
        threadFailed(
          key, "\(Self.threadFailure): HTTP \(status)", why: "HTTP \(status)", kind: CockpitOutage.kind(status: status))
        return false
      }
      let before = messages[key]?.last?.id
      messages[key] = rows
      rowLinks[key] = ChatLinks.inThread(rows)
      readGotThrough()
      threadDown[key, default: CockpitDown()].answered(now: Self.nowMs)
      threadQuiet.remove(key)
      threadProblem[key] = nil
      if let last = rows.last, last.isError, last.id != before {
        log.event(
          "chat",
          [
            "action": "reply_failed", "thread": key, "message": last.id,
            "skill": ChatSpeaker.skillAuthor(last) ?? "",
          ])
      }
      logOutbox(key, rows)
      // A sent message the Cockpit's thread now holds is done with the outbox.
      let known = Set(rows.map(\.id))
      let delivered = inbox.items.filter { $0.status == .sent && $0.chatThread == key && known.contains($0.id) }
      if !delivered.isEmpty { inbox.forget(delivered) }
      // What is on screen is shown: it never notifies later.
      if let last = rows.last, !last.ts.isEmpty { notified[key] = last.ts }
      // A new reply on screen is read here and on the laptop.
      let reply = rows.last.map { $0.id != before && !$0.fromIgor && !$0.isSystem } ?? false
      if markSeen || (before != nil && reply) {
        return await seen(key)
      }
      return true
    } catch  where ChatReadOrder.isCancellation(error) {
      // Closing the thread mid-read is not a failure: no problem waits for it when it opens again (exg6).
      log.event("chat", ["action": "thread_read_dropped", "thread": key, "reason": "cancelled"])
      return false
    } catch {
      guard threadOrder[key, default: ChatReadOrder()].mayShow(ticket) else {
        log.event("chat", ["action": "thread_read_dropped", "thread": key, "reason": "stale"])
        return false
      }
      if CockpitDown.isDown(error) {
        threadDownFailed(key, CockpitDown.how(error), why: error.localizedDescription)
        return false
      }
      threadFailed(
        key, CockpitReach.problem(error, otherwise: Self.threadFailure), why: error.localizedDescription,
        kind: CockpitOutage.kind(error))
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
  private func threadFailed(_ key: String, _ problem: String, why: String, kind: CockpitOutage.Kind) {
    let quiet = readFailed(kind, problem: problem, context: "ChatThreadView.load", extra: ["thread": .string(key)])
    if quiet { threadQuiet.insert(key) } else { threadQuiet.remove(key) }
    if threadProblem[key] != problem { log.event("error", ["where": "chat_thread", "thread": key, "message": why]) }
    threadProblem[key] = problem
  }

  /// Stories 1604–1606: the thread's read found the Cockpit down. Its banner, the messages last read kept under it,
  /// shows at once on a thread never read, else at the second failed poll in a row; the poll goes on reading.
  private func threadDownFailed(_ key: String, _ how: String, why: String) {
    let shows = threadDown[key, default: CockpitDown()].failed(how, loaded: messages[key] != nil, now: Self.nowMs)
    let problem = threadDown[key, default: CockpitDown()].problem(what: "reading this chat", timeZone: .current)
    guard shows else {
      _ = readFailed(.away, problem: problem, context: "ChatThreadView.load", extra: ["thread": .string(key)])
      return log.event(
        "chat", ["action": "thread_read_failed", "thread": key, "reason": why, "down": true, "shown": false])
    }
    threadFailed(key, problem, why: why, kind: .away)
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

  // MARK: Send to new chat (context-grabber-9yo)

  /// A chat a message was just moved into, titled as the Cockpit answered until its list names it.
  private var movedTitles: [String: String] = [:]
  /// Messages whose move is on its way: a second tap meanwhile does nothing.
  private var moving: Set<String> = []

  /// Moves one of Igor's messages out of `thread` into a new chat. Nil when that message's move is already on its way.
  func sendToNewChat(_ message: ChatMessage, from thread: String) async -> ChatMove.Outcome? {
    guard moving.insert(message.id).inserted else { return nil }
    defer { moving.remove(message.id) }
    let outcome: ChatMove.Outcome
    if inbox.offline {
      outcome = .refused("the phone is offline")
    } else if cockpit == ChatCockpit.nowhere {
      outcome = .refused(ChatCockpit.noAddress)
    } else {
      outcome = await ChatMove.run(thread: thread, message: message.id, cockpit: cockpit) { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode)
      }
    }
    switch outcome {
    case .moved(let key, let title):
      movedTitles[key] = title
      log.event(
        "chat", ["action": "moved_to_new_chat", "thread": thread, "message": message.id, "ok": true, "to": key])
      // The new chat opens at once; the old one's moved line and the list follow.
      Task {
        await load(thread, markSeen: false)
        await refreshList(reason: "moved")
      }
    case .refused(let why):
      log.event(
        "chat", ["action": "moved_to_new_chat", "thread": thread, "message": message.id, "ok": false, "reason": why])
    }
    return outcome
  }

  // MARK: Writing

  /// The + (#536): an empty thread with the ordinary bar, not a sheet. `voice`: the button beside it (#637), the same
  /// thread with its mic tapped as it opens.
  func openNewChat(from source: String, voice: Bool = false) {
    // #1365: what the + found, so a tap that opens nothing says why. `was_open` is a new chat already flagged open.
    let wasOpen = newChatOpen
    log.event(
      "ui",
      [
        "action": "open_new_chat", "from": source, "voice": voice, "was_open": wasOpen, "list": listOnScreen,
        "thread": openThread ?? "",
      ])
    newChatVoice.open(voice: voice)
    newChatTap += 1
    let tap = newChatTap
    Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(HomeStack.coverSettles + 1500))
      self?.checkNewChatShown(tap: tap, wasOpen: wasOpen, from: source)
    }
    guard wasOpen else {
      newChatOpen = true
      return
    }
    newChatOpen = false
    Task {
      try? await Task.sleep(for: .milliseconds(HomeStack.coverSettles))
      newChatOpen = true
    }
  }

  /// #1365: the + taps so far, and the last one a new chat's screen came on for.
  private var newChatTap = 0
  private var newChatShownFor = 0

  /// A new chat's screen came on screen (or went): logged, and the last + counted as answered.
  func newChatScreen(shown: Bool, landed: String?) {
    if shown { newChatShownFor = newChatTap }
    log.event(
      "chat",
      ["action": shown ? "new_chat_shown" : "new_chat_gone", "landed": landed ?? "", "flag": newChatOpen])
  }

  /// #1365: a + whose new chat never came on screen, with the state that explains it. Only the latest tap reports.
  private func checkNewChatShown(tap: Int, wasOpen: Bool, from source: String) {
    guard tap == newChatTap, newChatShownFor < tap else { return }
    log.event(
      "chat",
      [
        "action": "new_chat_not_shown", "from": source, "was_open": wasOpen, "flag": newChatOpen,
        "list": listOnScreen, "thread": openThread ?? "",
      ])
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
    let ticket = listOrder.start()
    do {
      guard let rows = try await readList().rows else {
        log.event("chat", ["action": "background_check", "ok": false])
        return false
      }
      // A newer list already shown stays (exg6); what is due is still worked out from this read.
      if listOrder.mayShow(ticket) { threads = shown(rows) }
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
  /// #582, story 829: a held call's notification opens the call screen.
  var openCall: (@MainActor () -> Void)?
  var onScreen: (@MainActor () -> String?)?

  // The completion-handler forms, not the async ones: returning from an async one calls UIKit's completion off the main
  // thread, which raises "Call must be made on main thread" and kills the app on a tapped notification (#610).
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completion: @escaping () -> Void
  ) {
    let thread = response.notification.request.content.userInfo["thread"] as? String
    let call = response.notification.request.content.userInfo["call"] != nil
    Task { @MainActor in
      if let thread { open?(thread) }
      if call { openCall?() }
      completion()
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let thread = notification.request.content.userInfo["thread"] as? String
    // A held call's notice with the app in front: the mic is already starting, so it never shows.
    let call = notification.request.content.userInfo["call"] != nil
    Task { @MainActor in
      completion(call || (thread != nil && thread == onScreen?()) ? [] : [.banner, .list, .sound])
    }
  }
}
