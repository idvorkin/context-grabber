//  What Larry gets (stories 020–029): the summary — today's headline and seven days, single-line JSON — and the
//  raw share, indented. The JSON is a contract: the same keys, order, units and numbers as the React Native
//  app's lib/share.ts, byte for byte (spec step 4).

import Foundation

/// The ten series of a week, as the export reads them.
public struct WeeklyDataMap: Equatable, Sendable {
  public var steps: [DailyValue]
  public var heartRate: [HeartRateDaily]
  public var sleep: [DailyValue]
  public var activeEnergy: [DailyValue]
  public var walkingDistance: [DailyValue]
  /// Pounds, whole.
  public var weight: [DailyValue]
  public var meditation: [DailyValue]
  public var hrv: [HeartRateDaily]
  public var restingHeartRate: [HeartRateDaily]
  public var exerciseMinutes: [DailyValue]

  public init(series: [MetricKey: WeeklySeries]) {
    steps = series[.steps]?.daily ?? []
    heartRate = series[.heartRate]?.ranged ?? []
    sleep = series[.sleep]?.daily ?? []
    activeEnergy = series[.activeEnergy]?.daily ?? []
    walkingDistance = series[.walkingDistance]?.daily ?? []
    weight = series[.weight]?.daily ?? []
    meditation = series[.meditation]?.daily ?? []
    hrv = series[.hrv]?.ranged ?? []
    restingHeartRate = series[.restingHeartRate]?.ranged ?? []
    exerciseMinutes = series[.exerciseMinutes]?.daily ?? []
  }
}

public struct MetricStatsExport: Equatable, Sendable {
  public var min, p5, p25, p50, p75, p95, max: Double
  init(_ s: BoxPlotStats) {
    (min, p5, p25, p50, p75, p95, max) = (s.min, s.p5, s.p25, s.p50, s.p75, s.p95, s.max)
  }
}

/// One logged accessory item as the coach reads it.
public struct AccessoryLogExportEntry: Equatable, Sendable {
  public var name: String
  public var timestamp: String
  public var date: String

  public var json: JSValue {
    .object([("name", .string(name)), ("timestamp", .string(timestamp)), ("date", .string(date))])
  }
}

/// The places section: text only, no coordinates. Filled once the native Places has its summaries.
public struct PlacesSummary: Equatable, Sendable {
  public var weekly: String
  public var recent: String
  public init(weekly: String, recent: String) {
    self.weekly = weekly
    self.recent = recent
  }
}

public enum ContextExport {
  static let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

  public static func dayOfWeek(_ dateKey: String, clock: LocalClock) -> String {
    dayNames[clock.weekday(clock.midnight(dateKey))]
  }

  /// Seven entries, oldest first as the series are (the React Native export keeps that order too).
  public static func dailyExport(_ data: WeeklyDataMap, clock: LocalClock) -> JSValue {
    .array(
      data.steps.enumerated().map { i, day in
        let hr = data.heartRate[safe: i]
        let heartRate: JSValue =
          hr.map { $0.avg != nil || $0.min != nil || $0.max != nil } == true
          ? .object([("avg", .num(hr!.avg)), ("min", .num(hr!.min)), ("max", .num(hr!.max))]) : .null
        return .object([
          ("date", .string(day.date)),
          ("dayOfWeek", .string(dayOfWeek(day.date, clock: clock))),
          ("steps", .num(day.value)),
          ("heartRate", heartRate),
          ("sleepHours", .num(data.sleep[safe: i]?.value)),
          ("activeEnergy", .num(data.activeEnergy[safe: i]?.value)),
          ("walkingDistanceKm", .num(data.walkingDistance[safe: i]?.value)),
          ("weightLbs", .num(data.weight[safe: i]?.value)),
          ("meditationMinutes", .num(data.meditation[safe: i]?.value)),
          ("hrvMs", .num(data.hrv[safe: i]?.avg)),
          ("restingHeartRate", .num(data.restingHeartRate[safe: i]?.avg)),
          ("exerciseMinutes", .num(data.exerciseMinutes[safe: i]?.value)),
        ])
      })
  }

  /// Today's headline from the live grab; bedtime and wake as short clock times.
  public static func todayHeadline(_ h: HealthData, dateKey: String, clock: LocalClock) -> JSValue {
    .object([
      ("date", .string(dateKey)),
      ("dayOfWeek", .string(dateKey.isEmpty ? "" : dayOfWeek(dateKey, clock: clock))),
      ("steps", .num(h.steps)),
      ("heartRate", .num(h.heartRate)),
      ("restingHeartRate", .num(h.restingHeartRate)),
      ("hrv", .num(h.hrv)),
      ("sleepHours", .num(h.sleepHours)),
      ("bedtime", .str(h.bedtime.map(SummaryText.formatTime))),
      ("wakeTime", .str(h.wakeTime.map(SummaryText.formatTime))),
      ("meditationMinutes", .num(h.meditationMinutes)),
      ("exerciseMinutes", .num(h.exerciseMinutes)),
      ("weightLbs", .num(h.weight.map { jsRound($0 * 2.20462) })),
      ("activeEnergy", .num(h.activeEnergy)),
      ("walkingDistanceKm", .num(h.walkingDistance)),
      ("workouts", .array(h.workouts.map(\.json))),
    ])
  }

  /// `roles` stays null until roles move to the native app (step 6); `places` until the native Places writes its
  /// summaries.
  public static func summary(
    _ data: WeeklyDataMap, health: HealthData, places: PlacesSummary?, roles: JSValue? = nil,
    accessory: [AccessoryLogExportEntry]?, clock: LocalClock
  ) -> JSValue {
    let todayDate = data.steps.last?.date ?? ""
    return .object([
      ("roles", roles ?? .null),
      ("today", todayHeadline(health, dateKey: todayDate, clock: clock)),
      ("days", dailyExport(data, clock: clock)),
      ("places", places.map { .object([("weekly", .string($0.weekly)), ("recent", .string($0.recent))]) } ?? .null),
      ("accessory", accessory.map { .array($0.map(\.json)) } ?? .null),
    ])
  }

  /// The accessory log, newest first; items saved together keep the order the React Native app's query returns
  /// them in (the later row first).
  public static func accessoryExport(_ entries: [AccessoryLogEntry]) -> [AccessoryLogExportEntry] {
    entries.sorted { ($0.loggedAt, $0.id) > ($1.loggedAt, $1.id) }.map {
      AccessoryLogExportEntry(name: $0.itemName, timestamp: isoString(Double($0.loggedAt)), date: $0.dateKey)
    }
  }

  /// The raw share: the whole grab, no point list. `location` and the clusters stay null until Places moves.
  public static func raw(timestamp: String, health: HealthData, location: JSValue? = nil, locationClusters: JSValue? = nil)
    -> JSValue
  {
    .object([
      ("timestamp", .string(timestamp)),
      ("health", health.json),
      ("location", location ?? .null),
      ("locationClusters", locationClusters ?? .null),
    ])
  }

  /// Per-metric box plots of the week (not in the summary; kept for the cards and a later comparison).
  public static func weeklyStats(_ data: WeeklyDataMap) -> [(String, MetricStatsExport?)] {
    func s(_ v: [Double]) -> MetricStatsExport? { Stats.boxPlot(v).map(MetricStatsExport.init) }
    return [
      ("steps", s(Stats.values(data.steps))),
      ("heartRate", s(data.heartRate.compactMap(\.avg))),
      ("sleepHours", s(Stats.values(data.sleep))),
      ("activeEnergy", s(Stats.values(data.activeEnergy))),
      ("walkingDistanceKm", s(Stats.values(data.walkingDistance))),
      ("weightLbs", s(Stats.values(data.weight))),
      ("meditationMinutes", s(Stats.values(data.meditation))),
      ("hrvMs", s(data.hrv.compactMap(\.avg))),
      ("restingHeartRate", s(data.restingHeartRate.compactMap(\.avg))),
      ("exerciseMinutes", s(Stats.values(data.exerciseMinutes))),
    ]
  }
}

extension Array {
  subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
