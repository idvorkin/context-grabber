//  Story 270: one archive run, apart from HealthKit and BGTasks. The trail and the strip go whatever the phone's lock;
//  Health only while it is unlocked. A run stops early when iOS takes the time back or the Cockpit is out of reach,
//  and what it records (story 304's Settings lines, and whether the next foreground is due) comes from how it ended.
//  Spec: docs/superpowers/specs/2026-10-19-native-stats-archive-design.md, "When a run is due".

import Foundation

/// What the archive's runs have recorded in the app's settings.
public struct ArchiveLedger {
  /// How the last counted run ended (ArchiveOutcome JSON).
  public static let outcomeKey = "archive_last_outcome"
  /// When a run last caught every stream up, last made progress (ArchiveOutcome.madeProgress), and when the first
  /// run started.
  public static let caughtUpKey = "archive_last_caught_up"
  public static let progressKey = "archive_last_progress"
  public static let firstRunKey = "archive_first_run"
  /// When the last run that was not locked or cancelled started: written by builds before the state, read only when
  /// no outcome was stored.
  public static let legacyLastRunKey = "archive_last_run"

  let settings: SettingsStore

  public init(settings: SettingsStore) { self.settings = settings }

  public func outcome() throws -> ArchiveOutcome? { ArchiveOutcome(json: try settings.get(Self.outcomeKey)) }

  /// The state the last counted run left, which says whether a run is due.
  public func state() throws -> ArchiveState {
    if let outcome = try outcome() { return ArchiveState(outcome) }
    if let ms = try settings.get(Self.legacyLastRunKey).flatMap({ Int64($0) }) { return .caughtUp(at: ms) }
    return .never
  }

  public func lastCaughtUp() throws -> Int64? { try settings.get(Self.caughtUpKey).flatMap { Int64($0) } }
  public func lastProgress() throws -> Int64? { try settings.get(Self.progressKey).flatMap { Int64($0) } }
  public func firstRun() throws -> Int64? { try settings.get(Self.firstRunKey).flatMap { Int64($0) } }

  /// Settings' Archive lines from what is recorded.
  public func statusLines(sends: Bool, now: Int64) throws -> [ArchiveStatus.Line] {
    ArchiveStatus.lines(
      sends: sends, outcome: try outcome(), lastCaughtUp: try lastCaughtUp(), lastProgress: try lastProgress(),
      firstRun: try firstRun(), now: now)
  }

  func record(_ outcome: ArchiveOutcome) throws {
    try settings.set(Self.outcomeKey, outcome.json)
    if try settings.get(Self.firstRunKey) == nil { try settings.set(Self.firstRunKey, String(outcome.at)) }
    if outcome.caughtUp { try settings.set(Self.caughtUpKey, String(outcome.at)) }
    if outcome.madeProgress { try settings.set(Self.progressKey, String(outcome.at)) }
  }
}

@MainActor
public struct ArchiveRun {
  /// Why it runs (launch, foreground, refresh, daily, hook): on every log line.
  public var reason: String
  /// The streams readable while the phone is locked: the trail and the strip.
  public var sources: [ArchiveSource]
  /// Health's streams, asked for only while the phone is unlocked.
  public var healthSources: @MainActor () async -> [ArchiveSource]
  /// Whether the phone's protected data is readable (it is not while locked).
  public var isUnlocked: @MainActor () -> Bool
  /// iOS taking the background time back.
  public var isCancelled: @MainActor () -> Bool
  public var now: @Sendable () -> Date
  public var ledger: ArchiveLedger
  public var uploader: ArchiveUploader

  public init(
    reason: String, sources: [ArchiveSource], healthSources: @escaping @MainActor () async -> [ArchiveSource] = { [] },
    isUnlocked: @escaping @MainActor () -> Bool, isCancelled: @escaping @MainActor () -> Bool = { false },
    now: @escaping @Sendable () -> Date = { Date() }, ledger: ArchiveLedger, uploader: ArchiveUploader
  ) {
    self.reason = reason
    self.sources = sources
    self.healthSources = healthSources
    self.isUnlocked = isUnlocked
    self.isCancelled = isCancelled
    self.now = now
    self.ledger = ledger
    self.uploader = uploader
  }

  public struct Result: Equatable, Sendable {
    public var streams = 0
    public var pages = 0
    public var records = 0
    public var inserted = 0
    public var duplicate = 0
    public var stopped: [String: ArchiveStop] = [:]
    /// The phone was locked at the start or became so mid-run: nothing was recorded.
    public var locked = false
    /// What the run recorded for Settings and the next "is a run due"; nil when it recorded nothing.
    public var recorded: ArchiveOutcome?
  }

  /// `log` gets the uploader's `archive` lines, `health_skipped` when the phone is locked, and one `archive_run`.
  public func perform(log: (String, [String: Any]) -> Void) async -> Result {
    let started = now()
    var result = Result()
    var sources = self.sources
    if isUnlocked() {
      sources += await healthSources()
    } else {
      result.locked = true
      log("archive", ["action": "health_skipped", "why": reason, "reason": "phone locked"])
    }
    result.streams = sources.count
    var refused: [String: Int] = [:]
    for source in sources {
      if isCancelled() {
        result.stopped[source.stream] = .cancelled
        break
      }
      let report = await uploader.upload(source, now: now, isCancelled: isCancelled) { [reason] type, fields in
        log(type, fields.merging(["why": reason]) { $1 })
      }
      result.pages += report.pages
      result.records += report.records
      result.inserted += report.inserted
      result.duplicate += report.duplicate
      if let why = report.stopped { result.stopped[source.stream] = why }
      if let status = report.refusedStatus { refused[source.stream] = status }
      // The Cockpit is away: every stream after this one would fail the same way.
      if report.stopped == .cockpitAway { break }
      if report.stopped == .unreadable && !isUnlocked() {
        result.locked = true
        log("archive", ["action": "health_skipped", "why": reason, "reason": "phone locked"])
        break
      }
    }
    let startedMs = Int64(started.timeIntervalSince1970 * 1000)
    // Story 304 and "is a run due" read only runs that could read everything. Most background runs find the phone
    // locked and skip Health; recording those would read "Behind" until the next unlocked run, so they say nothing.
    // By design a locked run discards its whole outcome, the trail's and the strip's streams with it, even a
    // refusal or a Cockpit out of reach: the next unlocked run, at the latest the next foreground, says it.
    if !result.locked {
      let outcome = ArchiveOutcome(at: startedMs, stopped: result.stopped, refused: refused)
      do {
        try ledger.record(outcome)
        result.recorded = outcome
      } catch {
        log("error", ["where": "archive_record", "message": "\(error)"])
      }
    }
    log(
      "archive_run",
      [
        "why": reason, "streams": result.streams, "pages": result.pages, "records": result.records,
        "inserted": result.inserted, "duplicate": result.duplicate,
        "stopped": result.stopped.mapValues(\.rawValue), "ms": Int(now().timeIntervalSince(started) * 1000),
      ])
    return result
  }
}
