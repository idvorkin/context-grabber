//  Today's health numbers from what Health returned (stories 002, 020, 025–028). Port of lib/health.ts: sleep
//  merged across sources before summing, weight and meditation, per-source sleep, and HealthData built from
//  query results where any one failure is a null for that metric, never a failed grab.
//
//  Times are JavaScript milliseconds (see JSTime.swift) so every sum and rounding matches the React Native app.

import Foundation

/// One Health sleep-analysis sample. `value`: 0 in bed, 1 asleep, 2 awake, 3 core, 4 deep, 5 REM.
public struct SleepSample: Equatable, Sendable {
  public var start: Double
  public var end: Double
  public var value: Int?
  public var source: String?

  public init(start: Double, end: Double, value: Int? = nil, source: String? = nil) {
    self.start = start
    self.end = end
    self.value = value
    self.source = source
  }
}

/// A mindful session: only its span counts.
public struct TimeSpan: Equatable, Sendable {
  public var start: Double
  public var end: Double
  public init(start: Double, end: Double) {
    self.start = start
    self.end = end
  }
}

/// A timed quantity reading (heart rate, weight in kg, …).
public struct QuantityReading: Equatable, Sendable {
  public var start: Double
  public var quantity: Double
  public init(start: Double, quantity: Double) {
    self.start = start
    self.quantity = quantity
  }
}

public struct SourceSleepSummary: Equatable, Sendable {
  public var bedtime: String
  public var wakeTime: String
  public var coreHours: Double
  public var deepHours: Double
  public var remHours: Double
  public var awakeHours: Double

  public var json: JSValue {
    .object([
      ("bedtime", .string(bedtime)), ("wakeTime", .string(wakeTime)), ("coreHours", .number(coreHours)),
      ("deepHours", .number(deepHours)), ("remHours", .number(remHours)), ("awakeHours", .number(awakeHours)),
    ])
  }
}

public struct WorkoutEntry: Equatable, Sendable {
  /// "Running", "Functional Strength", …
  public var activityType: String
  public var durationMinutes: Double
  public var energyBurned: Double?
  public var distanceKm: Double?
  public var startTime: String?
  public var endTime: String?

  public init(
    activityType: String, durationMinutes: Double, energyBurned: Double?, distanceKm: Double?,
    startTime: String? = nil, endTime: String? = nil
  ) {
    self.activityType = activityType
    self.durationMinutes = durationMinutes
    self.energyBurned = energyBurned
    self.distanceKm = distanceKm
    self.startTime = startTime
    self.endTime = endTime
  }

  /// A workout as Health describes it: activity type number, start, duration in seconds, kcal and meters.
  public init(activityType: Int, start: Double, durationSeconds: Double, energyKcal: Double?, distanceMeters: Double?) {
    self.activityType = Health.workoutActivityName(activityType)
    durationMinutes = jsRound(durationSeconds / 60)
    // `quantity ? … : null`: zero reads as none, as in the React Native app.
    energyBurned = energyKcal.flatMap { $0 != 0 ? jsRound($0) : nil }
    distanceKm = distanceMeters.flatMap { $0 != 0 ? jsRound($0 / 10) / 100 : nil }
    startTime = isoString(start)
    endTime = isoString(start + durationSeconds * 1000)
  }

  public var json: JSValue {
    var fields: [(String, JSValue)] = [
      ("activityType", .string(activityType)), ("durationMinutes", .number(durationMinutes)),
      ("energyBurned", .num(energyBurned)), ("distanceKm", .num(distanceKm)),
    ]
    if let startTime { fields.append(("startTime", .string(startTime))) }
    if let endTime { fields.append(("endTime", .string(endTime))) }
    return .object(fields)
  }
}

public struct HealthData: Equatable, Sendable {
  public var steps: Double?
  public var heartRate: Double?
  public var sleepHours: Double?
  public var bedtime: String?
  public var wakeTime: String?
  /// Sources in the order Health first returned them (newest sample first).
  public var sleepBySource: [(String, SourceSleepSummary)]?
  public var activeEnergy: Double?
  public var walkingDistance: Double?
  /// Kilograms.
  public var weight: Double?
  public var weightDaysLast7: Double?
  public var meditationMinutes: Double?
  public var hrv: Double?
  public var restingHeartRate: Double?
  public var exerciseMinutes: Double?
  public var workouts: [WorkoutEntry] = []

  public init() {}

  public static func == (a: HealthData, b: HealthData) -> Bool { a.json == b.json }

  public var json: JSValue {
    .object([
      ("steps", .num(steps)), ("heartRate", .num(heartRate)), ("sleepHours", .num(sleepHours)),
      ("bedtime", .str(bedtime)), ("wakeTime", .str(wakeTime)),
      ("sleepBySource", sleepBySource.map { .object($0.map { ($0.0, $0.1.json) }) } ?? .null),
      ("activeEnergy", .num(activeEnergy)), ("walkingDistance", .num(walkingDistance)), ("weight", .num(weight)),
      ("weightDaysLast7", .num(weightDaysLast7)), ("meditationMinutes", .num(meditationMinutes)),
      ("hrv", .num(hrv)), ("restingHeartRate", .num(restingHeartRate)), ("exerciseMinutes", .num(exerciseMinutes)),
      ("workouts", .array(workouts.map(\.json))),
    ])
  }

  /// Reads back what `json` wrote (the last grab, kept for the next open).
  public init?(json: JSValue) {
    guard case .object = json else { return nil }
    steps = json["steps"]?.double
    heartRate = json["heartRate"]?.double
    sleepHours = json["sleepHours"]?.double
    bedtime = json["bedtime"]?.string
    wakeTime = json["wakeTime"]?.string
    if case .object(let sources)? = json["sleepBySource"] {
      sleepBySource = sources.compactMap { name, v in
        guard let bed = v["bedtime"]?.string, let wake = v["wakeTime"]?.string else { return nil }
        return (
          name,
          SourceSleepSummary(
            bedtime: bed, wakeTime: wake, coreHours: v["coreHours"]?.double ?? 0, deepHours: v["deepHours"]?.double ?? 0,
            remHours: v["remHours"]?.double ?? 0, awakeHours: v["awakeHours"]?.double ?? 0)
        )
      }
    }
    activeEnergy = json["activeEnergy"]?.double
    walkingDistance = json["walkingDistance"]?.double
    weight = json["weight"]?.double
    weightDaysLast7 = json["weightDaysLast7"]?.double
    meditationMinutes = json["meditationMinutes"]?.double
    hrv = json["hrv"]?.double
    restingHeartRate = json["restingHeartRate"]?.double
    exerciseMinutes = json["exerciseMinutes"]?.double
    workouts = (json["workouts"]?.array ?? []).compactMap { w in
      guard let type = w["activityType"]?.string, let minutes = w["durationMinutes"]?.double else { return nil }
      return WorkoutEntry(
        activityType: type, durationMinutes: minutes, energyBurned: w["energyBurned"]?.double,
        distanceKm: w["distanceKm"]?.double, startTime: w["startTime"]?.string, endTime: w["endTime"]?.string)
    }
  }
}

/// What the eleven queries of a grab returned. `nil` is a failed query (a rejected promise); a query that found
/// nothing is a success with no value. Order and meaning follow lib/health.ts's HealthQueryResults.
public struct HealthQueryResults: Sendable {
  public var stepsSum: Result<Double?, HealthQueryError>
  public var latestHeartRate: Result<Double?, HealthQueryError>
  public var activeEnergySum: Result<Double?, HealthQueryError>
  public var distanceSum: Result<Double?, HealthQueryError>
  public var sleep: Result<[SleepSample], HealthQueryError>
  /// Kilograms.
  public var latestWeight: Result<Double?, HealthQueryError>
  public var mindful: Result<[TimeSpan], HealthQueryError>
  public var weightSamples: Result<[QuantityReading], HealthQueryError>
  public var latestHRV: Result<Double?, HealthQueryError>
  public var latestRestingHeartRate: Result<Double?, HealthQueryError>
  public var exerciseSum: Result<Double?, HealthQueryError>

  public init(
    stepsSum: Result<Double?, HealthQueryError>, latestHeartRate: Result<Double?, HealthQueryError>,
    activeEnergySum: Result<Double?, HealthQueryError>, distanceSum: Result<Double?, HealthQueryError>,
    sleep: Result<[SleepSample], HealthQueryError>, latestWeight: Result<Double?, HealthQueryError>,
    mindful: Result<[TimeSpan], HealthQueryError>, weightSamples: Result<[QuantityReading], HealthQueryError>,
    latestHRV: Result<Double?, HealthQueryError>, latestRestingHeartRate: Result<Double?, HealthQueryError>,
    exerciseSum: Result<Double?, HealthQueryError>
  ) {
    self.stepsSum = stepsSum
    self.latestHeartRate = latestHeartRate
    self.activeEnergySum = activeEnergySum
    self.distanceSum = distanceSum
    self.sleep = sleep
    self.latestWeight = latestWeight
    self.mindful = mindful
    self.weightSamples = weightSamples
    self.latestHRV = latestHRV
    self.latestRestingHeartRate = latestRestingHeartRate
    self.exerciseSum = exerciseSum
  }
}

public struct HealthQueryError: Error, Equatable, Sendable, CustomStringConvertible {
  public var message: String
  public init(_ message: String) { self.message = message }
  public var description: String { message }
}

public enum Health {
  /// Asleep values: everything but in bed (0) and awake (2).
  static let sleepValues: Set<Int> = [1, 3, 4, 5]

  public static func sleepCategoryName(_ value: Int?) -> String {
    guard let value else { return "Asleep" }
    return [0: "InBed", 1: "Asleep", 2: "Awake", 3: "Core", 4: "Deep", 5: "REM"][value] ?? "Unknown"
  }

  /// Distinct local days with a weigh-in; nil for none.
  public static func countWeightDays(_ samples: [QuantityReading]?, clock: LocalClock) -> Double? {
    guard let samples, !samples.isEmpty else { return nil }
    return Double(Set(samples.map { clock.dateKey($0.start) }).count)
  }

  /// Per source: first start, last end, and hours per stage (one decimal). Sources in first-seen order.
  public static func sleepBySource(_ samples: [SleepSample]?) -> [(String, SourceSleepSummary)]? {
    guard let samples, !samples.isEmpty else { return nil }
    var order: [String] = []
    var bySource: [String: [SleepSample]] = [:]
    for s in samples {
      let src = s.source ?? "Unknown"
      if bySource[src] == nil { order.append(src) }
      bySource[src, default: []].append(s)
    }
    return order.map { source in
      let sorted = stableSorted(bySource[source]!) { $0.start < $1.start }
      var core = 0.0, deep = 0.0, rem = 0.0, awake = 0.0
      for s in sorted {
        let hours = max(0, s.end - s.start) / (1000 * 60 * 60)
        switch s.value {
        case 2: awake += hours
        case 3: core += hours
        case 4: deep += hours
        case 5: rem += hours
        default: break
        }
      }
      return (
        source,
        SourceSleepSummary(
          bedtime: isoString(sorted[0].start), wakeTime: isoString(sorted[sorted.count - 1].end),
          coreHours: round1(core), deepHours: round1(deep), remHours: round1(rem), awakeHours: round1(awake))
      )
    }
  }

  /// Only actual sleep; samples with no value at all (old data) are all kept.
  public static func filterActualSleep(_ samples: [SleepSample]) -> [SleepSample] {
    guard samples.contains(where: { $0.value != nil }) else { return samples }
    return samples.filter { $0.value.map { sleepValues.contains($0) } ?? false }
  }

  /// Merged asleep hours, one decimal; nil for no samples or none asleep, 0 when every span is empty.
  public static func sleepHours(_ samples: [SleepSample]?) -> Double? {
    guard let samples, !samples.isEmpty else { return nil }
    let asleep = filterActualSleep(samples)
    guard !asleep.isEmpty else { return nil }
    let spans = asleep.map { ($0.start, $0.end) }.filter { $0.1 > $0.0 }
    guard !spans.isEmpty else { return 0 }
    return round1(mergedMillis(spans) / (1000 * 60 * 60))
  }

  /// Total minutes, one decimal; negative spans count as zero; nil for none.
  public static func meditationMinutes(_ sessions: [TimeSpan]?) -> Double? {
    guard let sessions, !sessions.isEmpty else { return nil }
    let total = sessions.reduce(0.0) { $0 + max(0, $1.end - $1.start) }
    return round1(total / (1000 * 60))
  }

  public static func extractWeight(_ kg: Double?) -> Double? { kg.map(round2) }

  /// HealthData from the grab's query results; a failed query is a null for that metric.
  public static func buildHealthData(_ r: HealthQueryResults, clock: LocalClock) -> HealthData {
    func value(_ x: Result<Double?, HealthQueryError>) -> Double? { (try? x.get()) ?? nil }
    let sleep = try? r.sleep.get()
    let details = Sleep.extractSleepDetails(sleep)
    var h = HealthData()
    h.steps = value(r.stepsSum).map(jsRound)
    // `heartRate.value ? …`: a sample is an object, so a zero reading still counts.
    h.heartRate = value(r.latestHeartRate).map(jsRound)
    h.sleepHours = sleepHours(sleep)
    h.bedtime = details.bedtime
    h.wakeTime = details.wakeTime
    h.sleepBySource = sleepBySource(sleep)
    h.activeEnergy = value(r.activeEnergySum).map(jsRound)
    h.walkingDistance = value(r.distanceSum).map(round2)
    h.weight = extractWeight(value(r.latestWeight))
    h.weightDaysLast7 = (try? r.weightSamples.get()).flatMap { countWeightDays($0, clock: clock) }
    h.meditationMinutes = (try? r.mindful.get()).flatMap(meditationMinutes)
    h.hrv = value(r.latestHRV).map(round1)
    h.restingHeartRate = value(r.latestRestingHeartRate).map(jsRound)
    h.exerciseMinutes = value(r.exerciseSum).map(jsRound)
    return h
  }

  /// Health's activity types by number, named as the React Native app names them.
  public static func workoutActivityName(_ type: Int) -> String {
    workoutNames[type] ?? "Workout \(type)"
  }

  static let workoutNames: [Int: String] = [
    1: "Football", 2: "Archery", 3: "Australian Football", 4: "Badminton",
    5: "Baseball", 6: "Basketball", 7: "Bowling", 8: "Boxing", 9: "Climbing",
    10: "Cricket", 11: "Cross Training", 12: "Curling", 13: "Cycling",
    14: "Dance", 15: "Dance Training", 16: "Elliptical", 17: "Equestrian",
    18: "Fencing", 19: "Fishing", 20: "Functional Strength", 21: "Golf",
    22: "Gymnastics", 23: "Handball", 24: "Hiking", 25: "Hockey",
    26: "Hunting", 27: "Lacrosse", 28: "Martial Arts", 29: "Mind & Body",
    30: "Mixed Cardio", 31: "Paddle Sports", 32: "Play",
    33: "Stretching", 34: "Racquetball", 35: "Rowing", 36: "Rugby",
    37: "Running", 38: "Sailing", 39: "Skating", 40: "Snow Sports",
    41: "Soccer", 42: "Softball", 43: "Squash", 44: "Stair Climbing",
    45: "Surfing", 46: "Swimming", 47: "Table Tennis", 48: "Tennis",
    49: "Track & Field", 50: "Strength Training", 51: "Volleyball",
    52: "Walking", 53: "Water Fitness", 54: "Water Polo", 55: "Water Sports",
    56: "Wrestling", 57: "Yoga", 58: "Barre", 59: "Core Training",
    60: "Cross-Country Skiing", 61: "Downhill Skiing", 62: "Flexibility",
    63: "HIIT", 64: "Jump Rope", 65: "Kickboxing", 66: "Pilates",
    67: "Snowboarding", 68: "Stairs", 69: "Step Training",
    70: "Wheelchair Walk", 71: "Wheelchair Run", 72: "Tai Chi",
    73: "Mixed Cardio", 74: "Hand Cycling", 75: "Disc Sports",
    76: "Fitness Gaming", 77: "Cardio Dance", 78: "Social Dance",
    79: "Pickleball", 80: "Cooldown", 82: "Triathlon", 83: "Transition",
    84: "Underwater Diving", 3000: "Other",
  ]

  /// Total of overlapping spans merged (spans sorted inside), in milliseconds.
  static func mergedMillis(_ spans: [(Double, Double)]) -> Double {
    let sorted = stableSorted(spans) { $0.0 < $1.0 }
    var merged: [(Double, Double)] = []
    for s in sorted {
      if let last = merged.last, s.0 <= last.1 {
        merged[merged.count - 1].1 = max(last.1, s.1)
      } else {
        merged.append(s)
      }
    }
    return merged.reduce(0) { $0 + ($1.1 - $1.0) }
  }
}

/// Array.prototype.sort is stable; Swift's sort is not promised to be. Ties keep their order here.
func stableSorted<T>(_ items: [T], by less: (T, T) -> Bool) -> [T] {
  items.enumerated().sorted { a, b in
    if less(a.element, b.element) { return true }
    if less(b.element, a.element) { return false }
    return a.offset < b.offset
  }.map(\.element)
}
