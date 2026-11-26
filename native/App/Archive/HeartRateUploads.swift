//  context-grabber-jimz: heart rate, resting heart rate and HRV go to the archive when Health says they arrived,
//  instead of at the next four-hourly run. An observer query per type, with background delivery, wakes the app; the
//  run is the archive's ordinary one (every stream's delta, deduped by guid), so nothing is sent twice. A wake while
//  the phone is locked (Health is unreadable) is kept in the settings and goes the next time the app runs unlocked:
//  a later Health wake, the unlock while the app is still alive, a launch or the foreground. Each wake logs `hr_wake` with how many new
//  heart-rate samples there were and how old the newest was, so the phone shows the real cadence.

import ContextCore
import HealthKit
import UIKit

@MainActor
final class HeartRateUploads {
  static let types: [HKQuantityTypeIdentifier] = [.heartRate, .restingHeartRate, .heartRateVariabilitySDNN]
  static let waitingKey = "hr_wake_waiting"
  static let countedAtKey = "hr_wake_counted_at_ms"
  /// The most samples one count reads: a Watch at 5 s fills a day with about 17,000.
  static let countLimit = 5000

  private let health: HKHealthStore
  private let log: SessionLog
  private let database: AppDatabase
  private let archive: ArchiveModel
  private var wakes: HeartRateWake
  private var queries: [HKObserverQuery] = []
  private var lastCountedAt: Date
  private var unlockObserver: NSObjectProtocol?
  private var assertion = UIBackgroundTaskIdentifier.invalid
  private var completion: (() -> Void)?
  private var sending = 0

  init(log: SessionLog, database: AppDatabase, archive: ArchiveModel, health: HKHealthStore = HKHealthStore()) {
    self.health = health
    self.log = log
    self.database = database
    self.archive = archive
    wakes = HeartRateWake(waitingForUnlock: database.setting(Self.waitingKey) == "1")
    lastCountedAt =
      database.setting(Self.countedAtKey).flatMap(Double.init).map { Date(timeIntervalSince1970: $0 / 1000) }
      ?? Date().addingTimeInterval(-3600)
  }

  /// At launch, so a background wake finds its handler. Nothing on a simulator or a Mac build, which send nothing.
  func start(sends: Bool) {
    #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
      log.event("hr_wake", ["action": "skipped", "reason": ChatCockpit.isMac ? "mac" : "simulator"])
    #else
      guard sends, HKHealthStore.isHealthDataAvailable(), queries.isEmpty else { return }
      unlockObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main
      ) { [weak self] _ in Task { @MainActor in self?.flushIfWaiting(trigger: "unlock") } }
      for identifier in Self.types {
        let type = HKQuantityType(identifier)
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
          Task { @MainActor in
            guard let self else { return completion() }
            self.onWake(type: identifier.rawValue, error: error, completion: completion)
          }
        }
        health.execute(query)
        queries.append(query)
        health.enableBackgroundDelivery(for: type, frequency: .immediate) { [log] ok, error in
          Task { @MainActor in
            log.event(
              "hr_wake",
              ["action": "background_delivery", "type": identifier.rawValue, "ok": ok]
                .merging(error.map { ["message": "\($0)"] } ?? [:]) { kept, _ in kept })
          }
        }
      }
    #endif
  }

  /// A launch, the foreground or the unlock: what a locked wake waited for goes now if the phone is unlocked.
  func flushIfWaiting(trigger: String = "foreground") {
    guard !queries.isEmpty else { return }
    let ran = wakes.flush(nowMs: Self.nowMs, unlocked: UIApplication.shared.isProtectedDataAvailable)
    saveWaiting()
    guard ran else { return }
    send(["action": "waited_run", "trigger": trigger], reason: "hr_wake_waited")
  }

  private func onWake(type: String, error: Error?, completion: @escaping () -> Void) {
    if let error {
      log.event("hr_wake", ["action": "error", "type": type, "message": "\(error)"])
      return completion()
    }
    let decision = wakes.wake(nowMs: Self.nowMs, unlocked: UIApplication.shared.isProtectedDataAvailable)
    saveWaiting()
    let fields: [String: Any] = [
      "action": "wake", "type": type, "decision": decision.rawValue,
      "app_state": UIApplication.shared.applicationState == .active ? "active" : "background",
    ]
    guard decision == .run else {
      log.event("hr_wake", fields)
      return completion()
    }
    send(fields, reason: "hr_wake", completion: completion)
  }

  /// A short run under a background assertion; Health's completion goes when it ends or the time runs out. A run
  /// already going carries the new samples, so the wake rides along and completes at once.
  private func send(_ fields: [String: Any], reason: String, completion: (() -> Void)? = nil) {
    guard !archive.isRunning else {
      log.event("hr_wake", fields.merging(["decision": "ride_along"]) { _, new in new })
      completion?()
      return
    }
    endSend(sending)
    sending += 1
    let mine = sending
    self.completion = completion
    let run = archive.run(reason: reason, maxPages: 5)
    assertion = UIApplication.shared.beginBackgroundTask(withName: "hr_wake") { [weak self] in
      MainActor.assumeIsolated {
        self?.log.event("hr_wake", ["action": "background_time_up"])
        self?.archive.cancel()
        self?.endSend(mine)
      }
    }
    Task {
      let counts = await newHeartRate()
      log.event("hr_wake", fields.merging(counts) { kept, _ in kept })
      await run.value
      endSend(mine)
    }
  }

  /// Health's completion and the assertion, once per send; a later send's are left alone.
  private func endSend(_ mine: Int) {
    guard mine == sending else { return }
    let done = completion
    completion = nil
    done?()
    if assertion != .invalid {
      UIApplication.shared.endBackgroundTask(assertion)
      assertion = .invalid
    }
  }

  private func saveWaiting() {
    database.setSetting(Self.waitingKey, wakes.waitingForUnlock ? "1" : "0")
  }

  private static var nowMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

  /// How many heart-rate samples end after the last count and how old the newest is (Larry: a Series 12 may
  /// sample every 5 s all day; this says what the phone really gets).
  private func newHeartRate() async -> [String: Any] {
    let since = lastCountedAt
    lastCountedAt = Date()
    database.setSetting(Self.countedAtKey, String(Self.nowMs))
    let predicate = HKSamplePredicate.quantitySample(
      type: HKQuantityType(.heartRate), predicate: HKQuery.predicateForSamples(withStart: since, end: nil))
    let newest = HKSampleQueryDescriptor(
      predicates: [predicate], sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
    let counted = HKSampleQueryDescriptor(predicates: [predicate], sortDescriptors: [], limit: Self.countLimit)
    do {
      let added = try await counted.result(for: health).count
      var out: [String: Any] = ["samples": added, "since_s": Int(Date().timeIntervalSince(since))]
      if added >= Self.countLimit { out["samples_capped"] = true }
      if let sample = try await newest.result(for: health).first {
        out["newest_age_s"] = Int(Date().timeIntervalSince(sample.endDate))
      }
      return out
    } catch {
      return ["count_error": "\(error)"]
    }
  }
}
