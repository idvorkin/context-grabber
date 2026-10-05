//  What a grab asks Health, as an interface: the app answers from HealthKit, the tests and the simulator's
//  fixture hook from a fixture. The answers follow the React Native Health library's: samples newest first by
//  start, a date range matches every sample that overlaps it, a sum over no samples is nil, and quantities come in
//  the unit the phone prefers (weight is always kilograms).

import Foundation

public enum QuantityKind: String, CaseIterable, Sendable {
  case steps, heartRate, activeEnergy, distance, bodyMass, hrv, restingHeartRate, exerciseTime
}

public struct QuantitySampleRecord: Equatable, Sendable {
  public var start: Double
  public var end: Double
  public var quantity: Double
  public var source: String?
  public init(start: Double, end: Double, quantity: Double, source: String? = nil) {
    self.start = start
    self.end = end
    self.quantity = quantity
    self.source = source
  }
}

public struct WorkoutRecord: Equatable, Sendable {
  /// Health's activity type number.
  public var activityType: Int
  public var start: Double
  public var end: Double
  public var durationSeconds: Double
  public var energyKcal: Double?
  public var distanceMeters: Double?
  public init(
    activityType: Int, start: Double, end: Double, durationSeconds: Double, energyKcal: Double?, distanceMeters: Double?
  ) {
    self.activityType = activityType
    self.start = start
    self.end = end
    self.durationSeconds = durationSeconds
    self.energyKcal = energyKcal
    self.distanceMeters = distanceMeters
  }

  public var entry: WorkoutEntry {
    WorkoutEntry(
      activityType: activityType, start: start, durationSeconds: durationSeconds, energyKcal: energyKcal,
      distanceMeters: distanceMeters)
  }
}

public protocol HealthSource: Sendable {
  /// The cumulative sum over the range; nil when nothing was recorded.
  func sum(_ kind: QuantityKind, from: Double, to: Double) async throws -> Double?
  /// The newest sample's value, whenever it was; nil when there is none.
  func latest(_ kind: QuantityKind) async throws -> Double?
  func samples(_ kind: QuantityKind, from: Double, to: Double) async throws -> [QuantitySampleRecord]
  func sleep(from: Double, to: Double) async throws -> [SleepSample]
  func mindful(from: Double, to: Double) async throws -> [TimeSpan]
  func workouts(from: Double, to: Double) async throws -> [WorkoutRecord]
}

/// The mirror's fixture (`mirror-fixture.json`): a week of samples, answered the way Health answers.
public struct HealthFixture: Sendable {
  public var timeZone: String
  /// "Now" for the grab, JavaScript milliseconds.
  public var now: Double
  public var quantities: [QuantityKind: [QuantitySampleRecord]]
  public var sleep: [SleepSample]
  public var mindful: [TimeSpan]
  public var workouts: [WorkoutRecord]
  public var accessory: [(itemId: String, itemName: String, loggedAt: Int64, dateKey: String)]

  public init?(json text: String) {
    guard let root = JSValue.parse(text), let tz = root["timeZone"]?.string, let now = root["now"]?.double else {
      return nil
    }
    timeZone = tz
    self.now = now
    var q: [QuantityKind: [QuantitySampleRecord]] = [:]
    for kind in QuantityKind.allCases {
      q[kind] = (root["quantity"]?[kind.rawValue]?.array ?? []).compactMap { s in
        guard let start = s["start"]?.double, let end = s["end"]?.double, let v = s["value"]?.double else { return nil }
        return QuantitySampleRecord(start: start, end: end, quantity: v, source: s["source"]?.string)
      }
    }
    quantities = q
    sleep = (root["sleep"]?.array ?? []).compactMap { s in
      guard let start = s["start"]?.double, let end = s["end"]?.double else { return nil }
      return SleepSample(start: start, end: end, value: s["value"]?.double.map { Int($0) }, source: s["source"]?.string)
    }
    mindful = (root["mindful"]?.array ?? []).compactMap { s in
      guard let start = s["start"]?.double, let end = s["end"]?.double else { return nil }
      return TimeSpan(start: start, end: end)
    }
    workouts = (root["workouts"]?.array ?? []).compactMap { w in
      guard let type = w["activityType"]?.double, let start = w["start"]?.double, let end = w["end"]?.double,
        let duration = w["durationSeconds"]?.double
      else { return nil }
      return WorkoutRecord(
        activityType: Int(type), start: start, end: end, durationSeconds: duration, energyKcal: w["energyKcal"]?.double,
        distanceMeters: w["distanceMeters"]?.double)
    }
    accessory = (root["accessory"]?.array ?? []).compactMap { a in
      guard let id = a["itemId"]?.string, let name = a["itemName"]?.string, let at = a["loggedAt"]?.double,
        let key = a["dateKey"]?.string
      else { return nil }
      return (id, name, Int64(at), key)
    }
  }

  /// Every instant moved by `ms` (the simulator hook moves the week to this week); accessory days re-keyed.
  public func shifted(by ms: Double, clock: LocalClock) -> HealthFixture {
    var f = self
    f.now += ms
    f.quantities = quantities.mapValues { $0.map { var s = $0; s.start += ms; s.end += ms; return s } }
    f.sleep = sleep.map { var s = $0; s.start += ms; s.end += ms; return s }
    f.mindful = mindful.map { TimeSpan(start: $0.start + ms, end: $0.end + ms) }
    f.workouts = workouts.map { var w = $0; w.start += ms; w.end += ms; return w }
    f.accessory = accessory.map {
      ($0.itemId, $0.itemName, $0.loggedAt + Int64(ms), clock.dateKey(Double($0.loggedAt) + ms))
    }
    return f
  }
}

/// Health answered from a fixture, with the library's rules (see the top of this file).
public struct FixtureHealthSource: HealthSource {
  public let fixture: HealthFixture
  public init(_ fixture: HealthFixture) { self.fixture = fixture }

  static func overlaps(_ start: Double, _ end: Double, _ from: Double, _ to: Double) -> Bool {
    start <= to && end >= from
  }

  /// Newest first by start; ties keep the fixture's order.
  static func newestFirst<T>(_ items: [T], _ start: (T) -> Double) -> [T] {
    stableSorted(items) { start($0) > start($1) }
  }

  public func sum(_ kind: QuantityKind, from: Double, to: Double) async throws -> Double? {
    let hits = try await samples(kind, from: from, to: to)
    return hits.isEmpty ? nil : hits.reduce(0) { $0 + $1.quantity }
  }

  public func latest(_ kind: QuantityKind) async throws -> Double? {
    Self.newestFirst(fixture.quantities[kind] ?? [], \.start).first?.quantity
  }

  public func samples(_ kind: QuantityKind, from: Double, to: Double) async throws -> [QuantitySampleRecord] {
    Self.newestFirst((fixture.quantities[kind] ?? []).filter { Self.overlaps($0.start, $0.end, from, to) }, \.start)
  }

  public func sleep(from: Double, to: Double) async throws -> [SleepSample] {
    Self.newestFirst(fixture.sleep.filter { Self.overlaps($0.start, $0.end, from, to) }, \.start)
  }

  public func mindful(from: Double, to: Double) async throws -> [TimeSpan] {
    Self.newestFirst(fixture.mindful.filter { Self.overlaps($0.start, $0.end, from, to) }, \.start)
  }

  public func workouts(from: Double, to: Double) async throws -> [WorkoutRecord] {
    Self.newestFirst(fixture.workouts.filter { Self.overlaps($0.start, $0.end, from, to) }, \.start)
  }
}
