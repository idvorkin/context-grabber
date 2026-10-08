//  Health answered from HealthKit, the way the React Native app's Health library answers (HealthSource in
//  ContextCore spells the rules out): newest first by start, a range matches overlapping samples, quantities in
//  the phone's preferred unit except weight in kilograms. Instants come back as JavaScript milliseconds.

import ContextCore
import HealthKit

final class HealthKitSource: HealthSource, @unchecked Sendable {
  let store = HKHealthStore()
  private let lock = NSLock()
  private var units: [HKQuantityType: HKUnit] = [:]

  static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

  static func type(_ kind: QuantityKind) -> HKQuantityType {
    switch kind {
    case .steps: return HKQuantityType(.stepCount)
    case .heartRate: return HKQuantityType(.heartRate)
    case .activeEnergy: return HKQuantityType(.activeEnergyBurned)
    case .distance: return HKQuantityType(.distanceWalkingRunning)
    case .bodyMass: return HKQuantityType(.bodyMass)
    case .hrv: return HKQuantityType(.heartRateVariabilitySDNN)
    case .restingHeartRate: return HKQuantityType(.restingHeartRate)
    case .exerciseTime: return HKQuantityType(.appleExerciseTime)
    }
  }

  static let sleepType = HKCategoryType(.sleepAnalysis)
  static let mindfulType = HKCategoryType(.mindfulSession)

  /// What the current app reads (App.tsx grabContext).
  static var readTypes: Set<HKObjectType> {
    var types = Set<HKObjectType>(QuantityKind.allCases.map { type($0) })
    types.insert(sleepType)
    types.insert(mindfulType)
    types.insert(HKObjectType.workoutType())
    return types
  }

  /// Asks once; Health shows its sheet only for types not yet asked about. `share` is for the simulator hook.
  func requestAuthorization(share: Set<HKSampleType> = []) async throws {
    try await store.requestAuthorization(toShare: share, read: Self.readTypes)
  }

  /// Story 242: a breathing session as a Mindful Session. Never asks: Health's sheet does not show over the
  /// breathing screen's cover (the request waited forever, 2026-10-08), so Today asks. Throws when writing is not
  /// allowed, or not asked yet.
  func saveMindful(_ span: TimeSpan) async throws {
    let status = store.authorizationStatus(for: Self.mindfulType)
    guard status == .sharingAuthorized else { throw HealthWriteRefused(asked: status != .notDetermined) }
    let sample = HKCategorySample(
      type: Self.mindfulType, value: HKCategoryValue.notApplicable.rawValue, start: jsDate(span.start),
      end: jsDate(span.end))
    try await store.save(sample)
  }

  /// The unit a query reports in: weight in kilograms (as the current app asks), the rest as the phone prefers.
  func unit(_ kind: QuantityKind) async throws -> HKUnit {
    if kind == .bodyMass { return .gramUnit(with: .kilo) }
    let type = Self.type(kind)
    lock.lock()
    let cached = units[type]
    lock.unlock()
    if let cached { return cached }
    let preferred = try await store.preferredUnits(for: [type])
    let unit = preferred[type] ?? Self.fallbackUnit(kind)
    lock.lock()
    units[type] = unit
    lock.unlock()
    return unit
  }

  static func fallbackUnit(_ kind: QuantityKind) -> HKUnit {
    switch kind {
    case .steps: return .count()
    case .heartRate, .restingHeartRate: return .count().unitDivided(by: .minute())
    case .activeEnergy: return .kilocalorie()
    case .distance: return .meterUnit(with: .kilo)
    case .bodyMass: return .gramUnit(with: .kilo)
    case .hrv: return .secondUnit(with: .milli)
    case .exerciseTime: return .minute()
    }
  }

  static func range(_ from: Double, _ to: Double) -> NSPredicate {
    HKQuery.predicateForSamples(withStart: jsDate(from), end: jsDate(to), options: [])
  }

  static func newestFirst<T: HKSample>() -> [SortDescriptor<T>] { [SortDescriptor(\T.startDate, order: .reverse)] }

  // MARK: HealthSource

  func sum(_ kind: QuantityKind, from: Double, to: Double) async throws -> Double? {
    let type = Self.type(kind)
    let unit = try await unit(kind)
    let descriptor = HKStatisticsQueryDescriptor(
      predicate: HKSamplePredicate.quantitySample(type: type, predicate: Self.range(from, to)), options: .cumulativeSum)
    return try await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: unit)
  }

  func latest(_ kind: QuantityKind) async throws -> Double? {
    let unit = try await unit(kind)
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.quantitySample(type: Self.type(kind))], sortDescriptors: Self.newestFirst(), limit: 1)
    return try await descriptor.result(for: store).first?.quantity.doubleValue(for: unit)
  }

  func samples(_ kind: QuantityKind, from: Double, to: Double) async throws -> [QuantitySampleRecord] {
    let unit = try await unit(kind)
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.quantitySample(type: Self.type(kind), predicate: Self.range(from, to))],
      sortDescriptors: Self.newestFirst())
    return try await descriptor.result(for: store).map {
      QuantitySampleRecord(
        start: jsMillis($0.startDate), end: jsMillis($0.endDate), quantity: $0.quantity.doubleValue(for: unit),
        source: $0.sourceRevision.source.name)
    }
  }

  func sleep(from: Double, to: Double) async throws -> [SleepSample] {
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.categorySample(type: Self.sleepType, predicate: Self.range(from, to))],
      sortDescriptors: Self.newestFirst())
    return try await descriptor.result(for: store).map {
      SleepSample(
        start: jsMillis($0.startDate), end: jsMillis($0.endDate), value: $0.value, source: $0.sourceRevision.source.name)
    }
  }

  func mindful(from: Double, to: Double) async throws -> [TimeSpan] {
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.categorySample(type: Self.mindfulType, predicate: Self.range(from, to))],
      sortDescriptors: Self.newestFirst())
    return try await descriptor.result(for: store).map { TimeSpan(start: jsMillis($0.startDate), end: jsMillis($0.endDate)) }
  }

  func workouts(from: Double, to: Double) async throws -> [WorkoutRecord] {
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.workout(Self.range(from, to))], sortDescriptors: Self.newestFirst())
    return try await descriptor.result(for: store).map { w in
      // The current app reads the workout's own totals (kcal, meters), not per-type statistics.
      WorkoutRecord(
        activityType: Int(w.workoutActivityType.rawValue), start: jsMillis(w.startDate), end: jsMillis(w.endDate),
        durationSeconds: w.duration, energyKcal: Self.total(w, .activeEnergyBurned, .kilocalorie()),
        distanceMeters: Self.total(w, .distanceWalkingRunning, .meter()))
    }
  }

  @available(iOS, deprecated: 18.0)
  static func legacyTotals(_ w: HKWorkout) -> (energy: HKQuantity?, distance: HKQuantity?) {
    (w.totalEnergyBurned, w.totalDistance)
  }

  static func total(_ w: HKWorkout, _ id: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? {
    let legacy = legacyTotals(w)
    if id == .activeEnergyBurned { return legacy.energy?.doubleValue(for: unit) }
    return legacy.distance?.doubleValue(for: unit)
  }
}

struct HealthWriteRefused: LocalizedError {
  var asked: Bool
  var errorDescription: String? {
    asked
      ? "Health does not allow Grabber Native to write Mindful Minutes"
      : "not asked yet: Today asks to write Mindful Minutes the next time it opens"
  }
}
