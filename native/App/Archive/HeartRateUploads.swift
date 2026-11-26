//  context-grabber-jimz: heart rate, resting heart rate and HRV go to the archive when Health says they arrived,
//  instead of at the next four-hourly run. An observer query per type, with background delivery, wakes the app; the
//  run is the archive's ordinary one (every stream's delta, deduped by guid), so nothing is sent twice. A wake while
//  the phone is locked (Health is unreadable) waits for the next unlock. Each wake logs `hr_wake` with how many new
//  heart-rate samples there were and how old the newest was, so the phone shows the real cadence.

import ContextCore
import HealthKit
import UIKit

@MainActor
final class HeartRateUploads {
  static let types: [HKQuantityTypeIdentifier] = [.heartRate, .restingHeartRate, .heartRateVariabilitySDNN]

  private let health: HKHealthStore
  private let log: SessionLog
  private let archive: ArchiveModel
  private var wakes = HeartRateWake()
  private var queries: [HKObserverQuery] = []
  private var lastCountedAt = Date()
  private var unlockObserver: NSObjectProtocol?

  init(log: SessionLog, archive: ArchiveModel, health: HKHealthStore = HKHealthStore()) {
    self.health = health
    self.log = log
    self.archive = archive
  }

  /// At launch, so a background wake finds its handler. Nothing on a simulator or a Mac build, which send nothing.
  func start(sends: Bool) {
    #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
      log.event("hr_wake", ["action": "skipped", "reason": ChatCockpit.isMac ? "mac" : "simulator"])
    #else
      guard sends, HKHealthStore.isHealthDataAvailable(), queries.isEmpty else { return }
      unlockObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main
      ) { [weak self] _ in Task { @MainActor in self?.onUnlock() } }
      for identifier in Self.types {
        let type = HKQuantityType(identifier)
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
          Task { @MainActor in
            await self?.onWake(type: identifier.rawValue, error: error)
            completion()
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

  private func onWake(type: String, error: Error?) async {
    if let error {
      log.event("hr_wake", ["action": "error", "type": type, "message": "\(error)"])
      return
    }
    let unlocked = UIApplication.shared.isProtectedDataAvailable
    let decision = wakes.wake(nowMs: Int64(Date().timeIntervalSince1970 * 1000), unlocked: unlocked)
    var fields: [String: Any] = [
      "action": "wake", "type": type, "decision": decision.rawValue,
      "app_state": UIApplication.shared.applicationState == .active ? "active" : "background",
    ]
    if decision == .run {
      fields.merge(await newHeartRate()) { kept, _ in kept }
      log.event("hr_wake", fields)
      await archive.run(reason: "hr_wake", maxPages: 5).value
    } else {
      log.event("hr_wake", fields)
    }
  }

  private func onUnlock() {
    guard wakes.unlocked(nowMs: Int64(Date().timeIntervalSince1970 * 1000)) else { return }
    Task {
      var fields: [String: Any] = ["action": "unlock_run"]
      fields.merge(await newHeartRate()) { kept, _ in kept }
      log.event("hr_wake", fields)
      await archive.run(reason: "hr_wake", maxPages: 5).value
    }
  }

  /// How many heart-rate samples arrived since the last count and how old the newest is (Larry: a Series 12 may
  /// sample every 5 s all day; this says what the phone really gets).
  private func newHeartRate() async -> [String: Any] {
    let since = lastCountedAt
    lastCountedAt = Date()
    let descriptor = HKSampleQueryDescriptor(
      predicates: [
        .quantitySample(
          type: HKQuantityType(.heartRate),
          predicate: HKQuery.predicateForSamples(
            withStart: since.addingTimeInterval(-6 * 3600), end: nil))
      ],
      sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)])
    do {
      let samples = try await descriptor.result(for: health)
      let added = samples.filter { $0.endDate > since }.count
      var out: [String: Any] = ["samples": added, "since_s": Int(Date().timeIntervalSince(since))]
      if let newest = samples.first { out["newest_age_s"] = Int(Date().timeIntervalSince(newest.endDate)) }
      return out
    } catch {
      return ["count_error": "\(error)"]
    }
  }
}
