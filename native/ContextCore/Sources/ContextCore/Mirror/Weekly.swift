//  Seven days per metric (stories 003–005): local-day buckets, heart-rate days with their range, meditation and
//  weight per day, and the normalized Movement overlay. Port of lib/weekly.ts.

import Foundation

public enum MetricKey: String, CaseIterable, Sendable {
  case steps, heartRate, sleep, activeEnergy, walkingDistance, weight, meditation, hrv, restingHeartRate,
    exerciseMinutes, movement

  /// The ten series a grab and the export read (Movement is drawn from three of them).
  public static let series: [MetricKey] = [
    .steps, .heartRate, .sleep, .activeEnergy, .walkingDistance, .weight, .meditation, .hrv, .restingHeartRate,
    .exerciseMinutes,
  ]

  public var config: MetricConfig { MetricConfig.all[self]! }
  /// Heart-rate-shaped days (avg, range, quartiles) rather than one value a day.
  public var isRanged: Bool { self == .heartRate || self == .hrv || self == .restingHeartRate }
}

public enum ChartType: Sendable { case bar, line }

public struct MetricConfig: Sendable {
  public let label: String
  public let unit: String
  /// "#rrggbb"
  public let color: String
  public let chartType: ChartType
  public let sublabel: String

  static let all: [MetricKey: MetricConfig] = [
    .steps: MetricConfig(label: "Steps", unit: "steps", color: "#4cc9f0", chartType: .bar, sublabel: "today"),
    .heartRate: MetricConfig(label: "Heart Rate", unit: "bpm", color: "#f72585", chartType: .line, sublabel: "latest"),
    .sleep: MetricConfig(label: "Sleep", unit: "hrs", color: "#7b2cbf", chartType: .bar, sublabel: "last night"),
    .activeEnergy: MetricConfig(label: "Active Energy", unit: "kcal", color: "#ff9e00", chartType: .bar, sublabel: "today"),
    .walkingDistance: MetricConfig(
      label: "Walking Distance", unit: "km", color: "#06d6a0", chartType: .bar, sublabel: "today"),
    .weight: MetricConfig(label: "Weight", unit: "lbs", color: "#4895ef", chartType: .line, sublabel: "latest"),
    .meditation: MetricConfig(label: "Meditation", unit: "min", color: "#e0aaff", chartType: .bar, sublabel: "today"),
    .hrv: MetricConfig(label: "HRV", unit: "ms", color: "#48bfe3", chartType: .line, sublabel: "latest"),
    .restingHeartRate: MetricConfig(
      label: "Resting HR", unit: "bpm", color: "#f4845f", chartType: .line, sublabel: "latest"),
    .exerciseMinutes: MetricConfig(label: "Exercise", unit: "min", color: "#57cc99", chartType: .bar, sublabel: "today"),
    .movement: MetricConfig(label: "Movement", unit: "", color: "#4cc9f0", chartType: .line, sublabel: "today"),
  ]
}

public struct DailyValue: Equatable, Sendable {
  public var date: String
  public var value: Double?
  public init(date: String, value: Double?) {
    self.date = date
    self.value = value
  }

  public var json: JSValue { .object([("date", .string(date)), ("value", .num(value))]) }
  public init?(json: JSValue) {
    guard let date = json["date"]?.string else { return nil }
    self.date = date
    value = json["value"]?.double
  }
}

public struct TimedReading: Equatable, Sendable {
  public var value: Double
  /// ISO 8601.
  public var time: String
}

/// A heart-rate-shaped day: average, range and quartiles of the day's readings.
public struct HeartRateDaily: Equatable, Sendable {
  public var date: String
  public var avg: Double?
  public var min: Double?
  public var max: Double?
  public var q1: Double?
  public var median: Double?
  public var q3: Double?
  public var count: Double = 0
  /// The day's readings, by value.
  public var raw: [TimedReading] = []

  public init(date: String) { self.date = date }

  public var json: JSValue {
    .object([
      ("date", .string(date)), ("avg", .num(avg)), ("min", .num(min)), ("max", .num(max)), ("q1", .num(q1)),
      ("median", .num(median)), ("q3", .num(q3)), ("count", .number(count)),
      ("raw", .array(raw.map { .object([("value", .number($0.value)), ("time", .string($0.time))]) })),
    ])
  }

  public init?(json: JSValue) {
    guard let date = json["date"]?.string else { return nil }
    self.date = date
    avg = json["avg"]?.double
    min = json["min"]?.double
    max = json["max"]?.double
    q1 = json["q1"]?.double
    median = json["median"]?.double
    q3 = json["q3"]?.double
    count = json["count"]?.double ?? 0
    raw = (json["raw"]?.array ?? []).compactMap { r in
      guard let v = r["value"]?.double, let t = r["time"]?.string else { return nil }
      return TimedReading(value: v, time: t)
    }
  }
}

/// One metric's week: plain days or heart-rate-shaped days.
public enum WeeklySeries: Equatable, Sendable {
  case daily([DailyValue])
  case ranged([HeartRateDaily])

  public var dates: [String] {
    switch self {
    case .daily(let d): return d.map(\.date)
    case .ranged(let d): return d.map(\.date)
    }
  }

  /// One number a day: the value, or the day's average.
  public var dailyValues: [DailyValue] {
    switch self {
    case .daily(let d): return d
    case .ranged(let d): return d.map { DailyValue(date: $0.date, value: $0.avg) }
    }
  }

  public var daily: [DailyValue]? { if case .daily(let d) = self { return d } else { return nil } }
  public var ranged: [HeartRateDaily]? { if case .ranged(let d) = self { return d } else { return nil } }

  /// The card's box plot: values, or the days' averages.
  public var boxPlot: BoxPlotStats? { Stats.boxPlot(Stats.values(dailyValues)) }
}

public struct MovementSeriesDay: Equatable, Sendable {
  public var dateKey: String
  public var steps: Double?
  public var distanceKm: Double?
  public var energyKcal: Double?
}

public struct MovementOverlayData: Equatable, Sendable {
  public var days: [MovementSeriesDay]
  public var stepsMax: Double
  public var distanceMax: Double
  public var energyMax: Double
  public var stepsNormalized: [Double?]
  public var distanceNormalized: [Double?]
  public var energyNormalized: [Double?]
}

public enum Weekly {
  /// The `days` local dates ending with `endDate`'s, oldest first.
  public static func dateKeys(endDate: Double, days: Int = 7, clock: LocalClock) -> [String] {
    (0..<days).reversed().map { clock.dateKey(clock.addDays(endDate, -$0)) }
  }

  /// Samples into local-day buckets by start; a day with no samples is null.
  public static func bucketByDay<T>(
    _ samples: [T], start: (T) -> Double, endDate: Double, days: Int, clock: LocalClock,
    aggregate: ([T]) -> Double?
  ) -> [DailyValue] {
    let keys = dateKeys(endDate: endDate, days: days, clock: clock)
    let keySet = Set(keys)
    var grouped: [String: [T]] = [:]
    for s in samples {
      let key = clock.dateKey(start(s))
      if keySet.contains(key) { grouped[key, default: []].append(s) }
    }
    return keys.map { key in
      DailyValue(date: key, value: grouped[key].flatMap { $0.isEmpty ? nil : aggregate($0) })
    }
  }

  /// Days since the newest day with a positive value (0 = today); nil when there is none.
  public static func daysSinceLast(_ values: [DailyValue]?, now: Double, clock: LocalClock) -> Int? {
    guard let values, !values.isEmpty else { return nil }
    let today = clock.setHours(now, 0)
    for v in values.reversed() {
      guard let x = v.value, x > 0 else { continue }
      return Int(jsRound((today - clock.midnight(v.date)) / 86_400_000))
    }
    return nil
  }

  /// Mean of the non-null values, one decimal.
  public static func average(_ values: [DailyValue]) -> Double? {
    let present = values.compactMap(\.value)
    guard !present.isEmpty else { return nil }
    return round1(present.reduce(0, +) / Double(present.count))
  }

  /// Heart-rate-shaped days over a window: average (one decimal), min, max and R-7 quartiles of each day's readings.
  public static func aggregateHeartRate(_ samples: [QuantityReading], endDate: Double, days: Int = 7, clock: LocalClock)
    -> [HeartRateDaily]
  {
    let keys = dateKeys(endDate: endDate, days: days, clock: clock)
    let keySet = Set(keys)
    var grouped: [String: [TimedReading]] = [:]
    for s in samples {
      let key = clock.dateKey(s.start)
      if keySet.contains(key) { grouped[key, default: []].append(TimedReading(value: s.quantity, time: isoString(s.start))) }
    }
    return keys.map { key in
      var day = HeartRateDaily(date: key)
      guard let readings = grouped[key], !readings.isEmpty else { return day }
      let sorted = stableSorted(readings) { $0.value < $1.value }
      let vals = sorted.map(\.value)
      day.count = Double(vals.count)
      day.avg = round1(vals.reduce(0, +) / Double(vals.count))
      day.min = vals[0]
      day.max = vals[vals.count - 1]
      day.median = quantile(vals, 0.5)
      day.q1 = quantile(vals, 0.25)
      day.q3 = quantile(vals, 0.75)
      day.raw = sorted
      return day
    }
  }

  static func quantile(_ sorted: [Double], _ p: Double) -> Double {
    if sorted.count == 1 { return sorted[0] }
    let idx = p * Double(sorted.count - 1)
    let lo = Int(idx.rounded(.down))
    let hi = Int(idx.rounded(.up))
    if lo == hi { return sorted[lo] }
    return round1(sorted[lo] + (idx - Double(lo)) * (sorted[hi] - sorted[lo]))
  }

  /// Sleep hours per local day of the sample's start, sources merged — midnight to midnight, as the React Native
  /// app's export counts them (the sheet counts noon to noon; see the spec's step 4).
  public static func aggregateSleep(_ samples: [SleepSample], endDate: Double, days: Int = 7, clock: LocalClock)
    -> [DailyValue]
  {
    bucketByDay(samples, start: \.start, endDate: endDate, days: days, clock: clock) { Health.sleepHours($0) }
  }

  /// Mindful minutes per day, one decimal, sessions summed.
  public static func aggregateMeditation(_ sessions: [TimeSpan], endDate: Double, days: Int = 7, clock: LocalClock)
    -> [DailyValue]
  {
    bucketByDay(sessions, start: \.start, endDate: endDate, days: days, clock: clock) { day in
      round1(day.reduce(0.0) { $0 + max(0, $1.end - $1.start) } / (1000 * 60))
    }
  }

  /// The day's latest reading (weight), two decimals.
  public static func pickLatestPerDay(_ samples: [QuantityReading], endDate: Double, days: Int = 7, clock: LocalClock)
    -> [DailyValue]
  {
    let keys = dateKeys(endDate: endDate, days: days, clock: clock)
    let keySet = Set(keys)
    var latest: [String: (ts: Double, quantity: Double)] = [:]
    for s in samples {
      let key = clock.dateKey(s.start)
      guard keySet.contains(key) else { continue }
      if let e = latest[key], !(s.start > e.ts) { continue }
      latest[key] = (s.start, s.quantity)
    }
    return keys.map { DailyValue(date: $0, value: latest[$0].map { round2($0.quantity) }) }
  }

  /// Steps, distance and energy on one chart, each scaled to its own week's max.
  public static func movementOverlay(steps: [DailyValue], distance: [DailyValue], energy: [DailyValue])
    -> MovementOverlayData
  {
    let dist = Dictionary(distance.map { ($0.date, $0.value) }, uniquingKeysWith: { _, b in b })
    let en = Dictionary(energy.map { ($0.date, $0.value) }, uniquingKeysWith: { _, b in b })
    let days = steps.map {
      MovementSeriesDay(dateKey: $0.date, steps: $0.value, distanceKm: dist[$0.date] ?? nil, energyKcal: en[$0.date] ?? nil)
    }
    func maxOf(_ v: [Double?]) -> Double { v.reduce(0.0) { m, x in x.map { $0 > m ? $0 : m } ?? m } }
    func normalize(_ v: [Double?], _ m: Double) -> [Double?] { v.map { $0.map { $0 / (m > 0 ? m : 1) } } }
    let s = days.map(\.steps), d = days.map(\.distanceKm), e = days.map(\.energyKcal)
    let sm = maxOf(s), dm = maxOf(d), em = maxOf(e)
    return MovementOverlayData(
      days: days, stepsMax: sm, distanceMax: dm, energyMax: em, stepsNormalized: normalize(s, sm),
      distanceNormalized: normalize(d, dm), energyNormalized: normalize(e, em))
  }
}
