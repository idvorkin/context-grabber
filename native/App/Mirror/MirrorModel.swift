//  The mirror's state (stories 002–009, 013, 019, 020–029): the last grab, a grab in progress, and the two
//  exports. Today and the sheets draw from it; ContextCore does the math.

import ContextCore
import SwiftUI

@MainActor
final class MirrorModel: ObservableObject {
  @Published private(set) var snapshot: MirrorSnapshot?
  /// "Health access", "Today", "Week" while a grab runs; nil otherwise.
  @Published private(set) var phase: String?
  @Published private(set) var grabStartedAt: Date?
  /// The last grab's failure, shown with its state and a copy button.
  @Published var problem: MirrorProblem?
  @Published var sleepTarget: Double = 8
  /// The fixture hook's state, on screen for the simulator's UI test: "running", then "done" or "failed".
  @Published var hookStatus: String?

  let clock = LocalClock.current
  private let app: AppModel
  private var source: HealthSource
  /// Set by the fixture hook: the grab's "now" (the fixture's week moved to this week).
  private var fixedNow: Double?
  /// Set by the fixture hook: the accessory log the export reads instead of the app's.
  private var fixtureAccessory: [AccessoryLogEntry]?
  /// Set by the fixture hook: a cache of its own, so one mode's cached days never answer for the other's
  /// (a healthkit run caches days without exercise minutes, which Health will not let an app write).
  private var fixtureCache: HealthCache?
  private var grabTask: Task<Void, Never>?

  static let lastSnapshotKey = "last_snapshot"
  static let sleepTargetKey = "sleep_target_hours"

  init(app: AppModel) {
    self.app = app
    source = HealthKitSource()
    if let raw = app.database.setting(Self.sleepTargetKey), let v = Double(raw), v > 0 { sleepTarget = v }
    if let raw = app.database.setting(Self.lastSnapshotKey), let json = JSValue.parse(raw),
      let stamp = json["timestamp"]?.string, let health = json["health"].flatMap(HealthData.init(json:))
    {
      snapshot = MirrorSnapshot(timestamp: stamp, health: health)
    }
  }

  var grabbing: Bool { phase != nil }

  var cards: [MetricCard] {
    MirrorText.cards(snapshot?.health, weekly: snapshot?.weekly ?? [:], now: now(), clock: clock)
  }

  func now() -> Double { fixedNow ?? jsMillis(Date()) }

  func setSleepTarget(_ hours: Double) {
    sleepTarget = hours
    app.database.setSetting(Self.sleepTargetKey, SummaryText.js(hours))
    app.log.event("ui", ["action": "sleep_target", "hours": hours])
  }

  // MARK: - grabbing

  /// One grab at a time; a second request while one runs is dropped (the running one is as fresh).
  func grab(reason: String) {
    guard grabTask == nil, hookStatus != "running" else { return }
    grabTask = Task { [weak self] in
      await self?.runGrab(reason: reason)
      self?.grabTask = nil
    }
  }

  func grabNow(reason: String) async {
    if let running = grabTask {
      await running.value
      return
    }
    let task = Task { await runGrab(reason: reason) }
    grabTask = task
    await task.value
    grabTask = nil
  }

  private func runGrab(reason: String) async {
    let started = Date()
    grabStartedAt = started
    let log = app.log
    log.event("mirror_grab", ["reason": reason, "source": source is HealthKitSource ? "healthkit" : "fixture"])
    if let hk = source as? HealthKitSource {
      phase = "Health access"
      guard HealthKitSource.isAvailable else {
        log.event("health_auth", ["ok": false, "message": "Health is not available on this device"])
        problem = MirrorProblem(message: "Health is not available on this device.", context: "Today.grab", extra: [:])
        phase = nil
        return
      }
      do {
        try await hk.requestAuthorization()
        log.event("health_auth", ["ok": true])
      } catch {
        // Not fatal: every query then fails on its own and reads "—".
        log.event("health_auth", ["ok": false, "message": "\(error)"])
      }
    }
    let grab = MirrorGrab(source: source, cache: fixtureCache ?? app.database.healthCache, clock: clock)
    let now = now()
    phase = "Today"
    let health = await grab.health(now: now)
    let stamp = fixedNow ?? jsMillis(Date())
    var snap = MirrorSnapshot(timestamp: isoString(stamp), health: health, weekly: snapshot?.weekly ?? [:],
      sleepBundle: snapshot?.sleepBundle, workoutsByDay: snapshot?.workoutsByDay ?? [:])
    snapshot = snap  // today shows before the week arrives; stale bars beat none
    phase = "Week"
    let week = await grab.weekly(now: now)
    snap.weekly = week.series
    snap.sleepBundle = week.sleepBundle
    snap.workoutsByDay = await grab.workoutsByDay(now: now)
    snapshot = snap
    phase = nil
    grabStartedAt = nil
    let failures = grab.takeFailures()
    for f in failures { log.event("health_query_failed", ["query": f.query, "message": f.message]) }
    if failures.isEmpty {
      problem = nil
    } else {
      problem = MirrorProblem(
        message: "Health did not answer \(failures.count) of the grab's questions; those read \u{2014}.",
        context: "Today.grab", extra: Dictionary(failures.map { ($0.query, $0.message) }, uniquingKeysWith: { a, _ in a }))
    }
    let ms = Int(Date().timeIntervalSince(started) * 1000)
    log.event(
      "mirror_grabbed",
      [
        "ms": ms, "steps": health.steps as Any, "sleep_hours": health.sleepHours as Any,
        "heart_rate": health.heartRate as Any, "workouts": health.workouts.count,
        "series": snap.weekly.count, "days_with_steps": (snap.weekly[.steps]?.daily ?? []).filter { $0.value != nil }.count,
        "failed_queries": failures.count,
      ])
    let stored = JSValue.object([
      ("timestamp", .string(snap.timestamp)), ("health", health.json), ("location", .null), ("locationHistory", .array([])),
    ])
    app.database.setSetting(Self.lastSnapshotKey, stored.stringify())
  }

  // MARK: - exports

  func accessoryEntries() -> [AccessoryLogEntry]? {
    if let fixtureAccessory { return fixtureAccessory }
    guard let log = app.database.accessoryLog else { return nil }
    do {
      return try log.entries(since: jsDate(now() - Double(AccessoryLog.windowDays) * 24 * 3600 * 1000))
    } catch {
      app.log.event("error", ["where": "accessory_history", "message": "\(error)"])
      return nil
    }
  }

  /// The summary (single line) or the raw share (indented), written to Documents/exports/ as well so a report or
  /// the simulator check can read exactly what went out.
  func export(_ kind: ExportKind) -> String? {
    guard let snap = snapshot else { return nil }
    let text: String =
      kind == .summary
      ? MirrorGrab.summaryJSON(snap, accessory: accessoryEntries(), clock: clock) : MirrorGrab.rawJSON(snap)
    let file = Self.exportsDir.appendingPathComponent("\(kind.rawValue).json")
    do {
      try FileManager.default.createDirectory(at: Self.exportsDir, withIntermediateDirectories: true)
      try text.write(to: file, atomically: true, encoding: .utf8)
    } catch {
      app.log.event("error", ["where": "export_file", "kind": kind.rawValue, "message": "\(error)"])
    }
    app.log.event("export", ["kind": kind.rawValue, "bytes": text.utf8.count, "grabbed": snap.timestamp])
    return text
  }

  static var exportsDir: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("exports")
  }

  // MARK: - the simulator's fixture hook

  /// GRABBER_MIRROR=fixture: the bundled week, moved to this week, answered without HealthKit.
  /// GRABBER_MIRROR=healthkit: the same week saved into this device's Health store, then grabbed from HealthKit.
  /// Either way the fixture as grabbed goes to Documents/exports/fixture.json and both exports are written, for
  /// `make-mirror-expected.mjs --fixture` to compare against.
  func runFixtureHook(_ mode: String) async {
    hookStatus = "running"
    await run(mode)
    if hookStatus == "running" { hookStatus = "failed" }
  }

  private func run(_ mode: String) async {
    let log = app.log
    let parsed = await Task.detached { () -> HealthFixture? in
      guard let url = Bundle.main.url(forResource: "mirror-fixture", withExtension: "json"),
        let text = try? String(contentsOf: url, encoding: .utf8)
      else { return nil }
      return HealthFixture(json: text)
    }.value
    guard let base = parsed else {
      log.event("error", ["where": "mirror_fixture", "message": "mirror-fixture.json missing from the bundle"])
      return
    }
    let day = 86_400_000.0
    let days = ((jsMillis(Date()) - base.now) / day).rounded(.down)
    var fx = base.shifted(by: days * day, clock: clock)
    fx.timeZone = TimeZone.current.identifier
    if mode == "healthkit" {
      var writer = HealthFixtureWriter()
      writer.note = { name, fields in log.event(name, fields) }
      do {
        let saved = try await writer.save(fx)
        fx = saved.fixture
        log.event("mirror_fixture_saved", ["samples": saved.count, "source": saved.source, "dropped": saved.dropped])
      } catch {
        log.event("error", ["where": "mirror_fixture_save", "message": "\(error)"])
        return
      }
    } else {
      source = FixtureHealthSource(fx)
    }
    fixedNow = fx.now
    fixtureCache = try? HealthCache(db: SQLiteDatabase())
    let db = try? SQLiteDatabase()
    if let db, let acc = try? AccessoryLog(db: db) {
      for a in fx.accessory {
        _ = try? db.run(
          "INSERT INTO accessory_log (item_id, item_name, logged_at, date_key) VALUES (?, ?, ?, ?)",
          [.text(a.itemId), .text(a.itemName), .int(a.loggedAt), .text(a.dateKey)])
      }
      fixtureAccessory = try? acc.entries(since: jsDate(fx.now - Double(AccessoryLog.windowDays) * day))
    }
    do {
      try FileManager.default.createDirectory(at: Self.exportsDir, withIntermediateDirectories: true)
      try (fx.json.stringify() + "\n").write(
        to: Self.exportsDir.appendingPathComponent("fixture.json"), atomically: true, encoding: .utf8)
    } catch {
      log.event("error", ["where": "mirror_fixture_file", "message": "\(error)"])
    }
    let grabTask = Task { await runGrab(reason: "hook") }
    self.grabTask = grabTask
    await grabTask.value
    self.grabTask = nil
    _ = export(.summary)
    _ = export(.raw)
    log.event("mirror_fixture_done", ["mode": mode, "now": isoString(fx.now), "time_zone": fx.timeZone])
    hookStatus = "done"
  }
}

enum ExportKind: String {
  case summary, raw
}

/// A failure on screen: the message, where it happened and the state around it, copyable.
struct MirrorProblem: Equatable {
  var message: String
  var context: String
  var extra: [String: String]

  var copyText: String {
    ([message, "context: \(context)", "build: \(BuildInfo.sha) \(BuildInfo.branch)"]
      + extra.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }).joined(separator: "\n")
  }
}
