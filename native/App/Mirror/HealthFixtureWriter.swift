//  The simulator's Health store is empty: this saves the mirror's fixture week into it (GRABBER_MIRROR=healthkit),
//  then reads back what Health holds, so the expected export is computed from exactly the numbers the app will
//  read. Never run on the phone: it writes to Health.

import ContextCore
import HealthKit

struct HealthFixtureWriter {
  let hk = HealthKitSource()
  /// One log event per step, so a hang on the simulator names its step.
  var note: (String, [String: Any]) -> Void = { _, _ in }

  /// Apps may not write Apple's exercise minutes.
  static let unwritable: Set<QuantityKind> = [.exerciseTime]

  var shareTypes: Set<HKSampleType> {
    var t = Set<HKSampleType>(
      QuantityKind.allCases.filter { !Self.unwritable.contains($0) }.map { HealthKitSource.type($0) })
    t.insert(HealthKitSource.sleepType)
    t.insert(HealthKitSource.mindfulType)
    t.insert(HKObjectType.workoutType())
    return t
  }

  func save(_ fx: HealthFixture) async throws -> (fixture: HealthFixture, count: Int, source: String, dropped: [String]) {
    note("mirror_fixture_step", ["step": "authorize"])
    try await hk.requestAuthorization(share: shareTypes)
    note("mirror_fixture_step", ["step": "delete_earlier"])
    let mine = HKQuery.predicateForObjects(from: HKSource.default())
    for type in shareTypes {
      _ = try? await hk.store.deleteObjects(of: type, predicate: mine)
    }
    var objects: [HKObject] = []
    for kind in QuantityKind.allCases where !Self.unwritable.contains(kind) {
      let type = HealthKitSource.type(kind)
      let unit = try await hk.unit(kind)
      for s in fx.quantities[kind] ?? [] {
        objects.append(
          HKQuantitySample(
            type: type, quantity: HKQuantity(unit: unit, doubleValue: s.quantity), start: jsDate(s.start), end: jsDate(s.end)))
      }
    }
    for s in fx.sleep {
      objects.append(HKCategorySample(type: HealthKitSource.sleepType, value: s.value ?? 1, start: jsDate(s.start), end: jsDate(s.end)))
    }
    for s in fx.mindful {
      objects.append(HKCategorySample(type: HealthKitSource.mindfulType, value: 0, start: jsDate(s.start), end: jsDate(s.end)))
    }
    for w in fx.workouts {
      objects.append(Self.workout(w))
    }
    note("mirror_fixture_step", ["step": "save", "objects": objects.count])
    for chunk in stride(from: 0, to: objects.count, by: 500) {
      try await hk.store.save(Array(objects[chunk..<min(chunk + 500, objects.count)]))
    }

    note("mirror_fixture_step", ["step": "read_back"])
    // What Health now holds, in the units the grab reads.
    var held = fx.asSavedBy(source: HKSource.default().name, dropping: Self.unwritable)
    let all = (-1e15, 1e15)
    for kind in QuantityKind.allCases where !Self.unwritable.contains(kind) {
      held.quantities[kind] = try await hk.samples(kind, from: all.0, to: all.1).reversed()
    }
    held.sleep = try await hk.sleep(from: all.0, to: all.1).reversed()
    held.mindful = try await hk.mindful(from: all.0, to: all.1).reversed()
    held.workouts = try await hk.workouts(from: all.0, to: all.1).reversed()
    return (held, objects.count, HKSource.default().name, Self.unwritable.map(\.rawValue))
  }

  @available(iOS, deprecated: 17.0)
  static func workout(_ w: WorkoutRecord) -> HKWorkout {
    HKWorkout(
      activityType: HKWorkoutActivityType(rawValue: UInt(w.activityType)) ?? .other, start: jsDate(w.start),
      end: jsDate(w.end), duration: w.durationSeconds,
      totalEnergyBurned: w.energyKcal.map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) },
      totalDistance: w.distanceMeters.map { HKQuantity(unit: .meter(), doubleValue: $0) }, metadata: nil)
  }
}
