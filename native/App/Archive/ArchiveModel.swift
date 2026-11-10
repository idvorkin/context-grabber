//  Story 270 (context-grabber-3il): everything the app collects goes to the Cockpit's archive on its own: the trail's
//  points, every Health sample type the mirror reads and the daily strip's days (story 271), as deltas every four hours
//  or so (a background refresh, and a foreground once that long has passed), an end-of-day batch (a background
//  processing task), and the whole history the first time, paged. Each stream's cursor (ArchiveCursorStore) moves only
//  after a 2xx, and the archive keeps one row per guid, so nothing is ever there twice. Spec:
//  docs/superpowers/specs/2026-10-19-native-stats-archive-design.md.

import BackgroundTasks
import Combine
import ContextCore
import HealthKit
import UIKit

@MainActor
final class ArchiveModel: ObservableObject {
  static let deviceKey = "archive_device_id"
  /// Pages per stream in a refresh or foreground run (seconds of background time), and in the end-of-day
  /// processing task (minutes): a backfill of years of heart rate takes a few of each.
  nonisolated static let refreshPages = 20
  static let dailyPages = 200

  private let log: SessionLog
  private let database: AppDatabase
  /// Where the batches go. Nil on a simulator or a Mac build launched without GRABBER_ARCHIVE_URL: both reach the
  /// tailnet too, and their fixture week and imported trail must never land in Igor's archive.
  private let cockpit: String?
  private let deviceId: String
  private let health = HKHealthStore()
  private var running: Task<Void, Never>?
  private var cancelled = false
  /// Story 304: when the last run ended, so an open Settings re-reads its Archive lines.
  @Published private(set) var lastRunEnded: Date?

  init(log: SessionLog, database: AppDatabase, environment: [String: String]) {
    self.log = log
    self.database = database
    cockpit = Self.destination(environment)
    // The vendor id, as the strip sync uses it: a backup restored onto another phone is another device.
    let id =
      UIDevice.current.identifierForVendor?.uuidString.lowercased() ?? database.setting(Self.deviceKey)
      ?? UUID().uuidString.lowercased()
    deviceId = id
    database.setSetting(Self.deviceKey, id)
  }

  /// Where the batches go: the Cockpit, or GRABBER_ARCHIVE_URL. On a simulator only the latter, nil otherwise: the
  /// simulator reaches the tailnet too, and its fixture week, imported trail and fake-bridge calls must never land in
  /// Igor's archive. The call's log (story 212) goes to the same place by the same rule. A Mac build too (#638).
  nonisolated static func destination(_ environment: [String: String]) -> String? {
    #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
      return environment["GRABBER_ARCHIVE_URL"]
    #else
      return environment["GRABBER_ARCHIVE_URL"] ?? CockpitPage.url
    #endif
  }

  /// Before the launch finishes (iOS refuses a handler registered later): the refresh and the end-of-day task.
  func registerBackgroundTasks() {
    let tasks = [
      (ArchiveSchedule.refreshTask, "refresh", Self.refreshPages),
      (ArchiveSchedule.dailyTask, "daily", Self.dailyPages),
    ]
    for (identifier, reason, pages) in tasks {
      let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) {
        [weak self] task in
        Task { @MainActor in self?.handle(task, reason: reason, maxPages: pages) }
      }
      if !registered { log.event("error", ["where": "archive_register", "task": identifier]) }
    }
  }

  /// At the launch's first activation: the next slots asked for, and a run if one is due.
  func launch() {
    Task { await schedule(reason: "launch") }
    runIfDue(reason: "launch")
  }

  /// A run when the last counted one says so (spec "When a run is due"): never run, four hours after one that got
  /// somewhere, at once after one that never reached the Cockpit.
  func runIfDue(reason: String) {
    var state = ArchiveState.never
    do {
      state = try ledger?.state() ?? .never
    } catch {
      log.event("error", ["where": "archive_state", "message": "\(error)"])
    }
    guard ArchiveSchedule.isDue(state, now: Date()) else { return }
    run(reason: reason)
  }

  private var ledger: ArchiveLedger? { database.settings.map(ArchiveLedger.init(settings:)) }

  /// A run now, whatever the clock says (a background task, the hook); the one in flight is shared.
  @discardableResult
  func run(reason: String, maxPages: Int = ArchiveModel.refreshPages) -> Task<Void, Never> {
    if let running { return running }
    cancelled = false
    let task = Task { [weak self] in
      await self?.perform(reason: reason, maxPages: maxPages)
      self?.running = nil
    }
    running = task
    return task
  }

  /// iOS is taking the background time back: the page in flight finishes or fails on its own, nothing after it
  /// starts, and the cursor stays wherever the last 2xx put it.
  func cancel() {
    cancelled = true
    running?.cancel()
  }

  private func handle(_ task: BGTask, reason: String, maxPages: Int) {
    task.expirationHandler = { [weak self] in Task { @MainActor in self?.cancel() } }
    let active = run(reason: reason, maxPages: maxPages)
    Task { [weak self] in
      await self?.schedule(reason: reason)
      await active.value
      task.setTaskCompleted(success: self?.cancelled == false)
    }
  }

  /// Asks iOS for the next refresh and preserves a daily batch iOS has not run yet, even past midnight.
  /// A simulator or a Mac build schedules nothing: it says so once and runs only while the app is open.
  func schedule(reason: String) async {
    #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
      log.event(
        "archive", ["action": "schedule_skipped", "why": reason, "reason": ChatCockpit.isMac ? "mac" : "simulator"])
    #else
      let pending = await BGTaskScheduler.shared.pendingTaskRequests()
      let pendingDaily = pending.first { $0.identifier == ArchiveSchedule.dailyTask }
      let refresh = BGAppRefreshTaskRequest(identifier: ArchiveSchedule.refreshTask)
      refresh.earliestBeginDate = Date().addingTimeInterval(ArchiveSchedule.interval)
      var requests: [BGTaskRequest] = [refresh]
      var dailyAt = pendingDaily?.earliestBeginDate
      if reason == "daily" || pendingDaily == nil {
        let daily = BGProcessingTaskRequest(identifier: ArchiveSchedule.dailyTask)
        dailyAt = ArchiveSchedule.nextDaily(after: Date(), calendar: .current)
        daily.earliestBeginDate = dailyAt
        daily.requiresNetworkConnectivity = true
        requests.append(daily)
      }
      var submitted: [String] = []
      for request in requests {
        do {
          try BGTaskScheduler.shared.submit(request)
          submitted.append(request.identifier)
        } catch {
          log.event("error", ["where": "archive_schedule", "task": request.identifier, "message": "\(error)"])
        }
      }
      log.event(
        "archive",
        [
          "action": "scheduled", "why": reason, "tasks": submitted,
          "daily_at": dailyAt.map { ISO8601DateFormatter().string(from: $0) } ?? "pending",
        ])
    #endif
  }

  /// The run itself is ArchiveRun's (host-tested); this supplies the phone's streams, its lock and HealthKit.
  private func perform(reason: String, maxPages: Int) async {
    guard let cockpit else {
      let place = ChatCockpit.isMac ? "a Mac build" : "the simulator"
      log.event("archive", ["action": "skipped", "why": reason, "reason": "no archive URL on \(place)"])
      return
    }
    guard let cursors = database.archiveCursors, let ledger else {
      log.event("error", ["where": "archive_run", "message": "no database"])
      return
    }
    var sources: [ArchiveSource] = []
    if let locations = database.locations { sources.append(LocationArchiveSource(store: locations)) }
    // Story 271: the strip's days, every device's taps merged as the strip shows them; readable while locked.
    if let strip = database.dailyStrip {
      sources += DailyItem.allCases.map { StripArchiveSource(strip: strip, item: $0) as ArchiveSource }
    }
    var uploader = ArchiveUploader(cursors: cursors, cockpit: cockpit, deviceId: deviceId) {
      try await URLSession.shared.data(for: $0)
    }
    uploader.maxPages = maxPages
    let run = ArchiveRun(
      reason: reason, sources: sources, healthSources: { [weak self] in await self?.healthSources() ?? [] },
      isUnlocked: { UIApplication.shared.isProtectedDataAvailable },
      isCancelled: { [weak self] in self?.cancelled ?? true }, ledger: ledger, uploader: uploader)
    _ = await run.perform { [log] type, fields in log.event(type, fields) }
    lastRunEnded = Date()
  }

  /// Story 304: the archive's lines for Settings, from the last run's outcome.
  func statusLines(now: Date = Date()) -> [ArchiveStatus.Line] {
    do {
      return try ledger?.statusLines(sends: cockpit != nil, now: Int64(now.timeIntervalSince1970 * 1000))
        ?? ArchiveStatus.lines(sends: cockpit != nil, outcome: nil, lastCaughtUp: nil, now: 0)
    } catch {
      log.event("error", ["where": "archive_status", "message": "\(error)"])
      return ArchiveStatus.lines(sends: cockpit != nil, outcome: nil, lastCaughtUp: nil, now: 0)
    }
  }

  /// One stream per type the mirror reads, only once Health has been asked about all of them (Today asks; an
  /// archive run never puts Health's sheet up). A type Igor denied answers nothing, and that is its archive.
  private func healthSources() async -> [ArchiveSource] {
    guard HKHealthStore.isHealthDataAvailable() else { return [] }
    let status: HKAuthorizationRequestStatus
    do {
      status = try await health.statusForAuthorizationRequest(toShare: [], read: HealthKitSource.readTypes)
    } catch {
      log.event("error", ["where": "archive_health_status", "message": "\(error)"])
      return []
    }
    guard status == .unnecessary else {
      log.event("archive", ["action": "health_skipped", "reason": "not asked yet: Today asks"])
      return []
    }
    return HealthKitSource.readTypes.compactMap { $0 as? HKSampleType }
      .sorted { $0.identifier < $1.identifier }
      .map { HealthArchiveSource(store: health, type: $0) }
  }
}
