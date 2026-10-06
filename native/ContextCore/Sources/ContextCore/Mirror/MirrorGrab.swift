//  A grab (stories 002, 013, 020): today's numbers live, the week from the cache plus Health, and the two exports.
//  The queries, windows, roundings and caching are the React Native app's (App.tsx: grabHealthData,
//  fetchDayFromHealthKit, grabWeeklyRangeQuery, grabWeeklyData), so the same Health data gives the same export.

import Foundation

/// What one grab saw.
public struct MirrorSnapshot: Equatable, Sendable {
  /// When the grab finished, ISO 8601.
  public var timestamp: String
  public var health: HealthData
  /// The ten series; a series Health would not give is missing.
  public var weekly: [MetricKey: WeeklySeries]
  /// Noon-to-noon nights for the Sleep sheet.
  public var sleepBundle: SleepDetailedBundle?
  /// Each week's workouts by local day of their start (the Exercise sheet).
  public var workoutsByDay: [String: [WorkoutEntry]]

  public init(
    timestamp: String, health: HealthData, weekly: [MetricKey: WeeklySeries] = [:],
    sleepBundle: SleepDetailedBundle? = nil, workoutsByDay: [String: [WorkoutEntry]] = [:]
  ) {
    self.timestamp = timestamp
    self.health = health
    self.weekly = weekly
    self.sleepBundle = sleepBundle
    self.workoutsByDay = workoutsByDay
  }

  public var weeklyData: WeeklyDataMap { WeeklyDataMap(series: weekly) }
}

/// A query that failed, for the log: which, and what Health said.
public struct MirrorFailure: Equatable, Sendable {
  public var query: String
  public var message: String
}

public final class MirrorGrab: @unchecked Sendable {
  let source: HealthSource
  let cache: HealthCache?
  let clock: LocalClock
  private let lock = NSLock()
  private var _failures: [MirrorFailure] = []

  public init(source: HealthSource, cache: HealthCache?, clock: LocalClock) {
    self.source = source
    self.cache = cache
    self.clock = clock
  }

  /// Failures since the last call, oldest first.
  public func takeFailures() -> [MirrorFailure] {
    lock.lock()
    defer { lock.unlock() }
    let f = _failures
    _failures = []
    return f
  }

  private func fail(_ query: String, _ error: Error) {
    lock.lock()
    _failures.append(MirrorFailure(query: query, message: "\(error)"))
    lock.unlock()
  }

  private func settle<T>(_ query: String, _ body: () async throws -> T) async -> Result<T, HealthQueryError> {
    do {
      return .success(try await body())
    } catch {
      fail(query, error)
      return .failure(HealthQueryError("\(error)"))
    }
  }

  // MARK: - today

  /// Today's numbers: sums since local midnight, the newest heart rate, HRV, resting rate and weight, last night
  /// noon to noon, the week's weigh-in days, and today's workouts (one that began yesterday counts).
  public func health(now: Double) async -> HealthData {
    let startOfDay = clock.setHours(now, 0)
    let todayNoon = clock.setHours(now, 12)
    let yesterdayNoon = todayNoon - 24 * 60 * 60 * 1000
    let sevenDaysAgo = now - 7 * 24 * 60 * 60 * 1000
    let s = source

    async let steps = settle("steps") { try await s.sum(.steps, from: startOfDay, to: now) }
    async let hr = settle("heart_rate") { try await s.latest(.heartRate) }
    async let energy = settle("active_energy") { try await s.sum(.activeEnergy, from: startOfDay, to: now) }
    async let distance = settle("distance") { try await s.sum(.distance, from: startOfDay, to: now) }
    async let sleep = settle("sleep") { try await s.sleep(from: yesterdayNoon, to: todayNoon) }
    async let weight = settle("weight") { try await s.latest(.bodyMass) }
    async let mindful = settle("mindful") { try await s.mindful(from: startOfDay, to: now) }
    async let weights = settle("weight_week") {
      try await s.samples(.bodyMass, from: sevenDaysAgo, to: now).map { QuantityReading(start: $0.start, quantity: $0.quantity) }
    }
    async let hrv = settle("hrv") { try await s.latest(.hrv) }
    async let resting = settle("resting_heart_rate") { try await s.latest(.restingHeartRate) }
    async let exercise = settle("exercise") { try await s.sum(.exerciseTime, from: startOfDay, to: now) }

    let results = await HealthQueryResults(
      stepsSum: steps, latestHeartRate: hr, activeEnergySum: energy, distanceSum: distance, sleep: sleep,
      latestWeight: weight, mindful: mindful, weightSamples: weights, latestHRV: hrv, latestRestingHeartRate: resting,
      exerciseSum: exercise)
    var health = Health.buildHealthData(results, clock: clock)
    if case .success(let workouts) = await settle("workouts", { try await s.workouts(from: startOfDay, to: now) }) {
      health.workouts = workouts.map(\.entry)
    }
    return health
  }

  // MARK: - the week

  /// The ten series over the week ending today, and the Sleep sheet's nights.
  public func weekly(now: Double) async -> (series: [MetricKey: WeeklySeries], sleepBundle: SleepDetailedBundle?) {
    var out: [MetricKey: WeeklySeries] = [:]
    var bundle: SleepDetailedBundle?
    await withTaskGroup(of: (MetricKey, WeeklySeries?, SleepDetailedBundle?).self) { group in
      for metric in MetricKey.series {
        group.addTask {
          if metric == .weight || metric == .sleep {
            let r = await self.rangeQuery(metric, now: now)
            return (metric, r.series, r.bundle)
          }
          return (metric, await self.perDay(metric, now: now), nil)
        }
      }
      for await (metric, series, b) in group {
        if let series { out[metric] = series }
        if let b { bundle = b }
      }
    }
    return (out, bundle)
  }

  /// Weight and sleep: one query over the week (weigh-ins are rare, nights cross midnight).
  func rangeQuery(_ metric: MetricKey, now: Double) async -> (series: WeeklySeries?, bundle: SleepDetailedBundle?) {
    let todayKey = clock.dateKey(now)
    let from = now - Double(metric == .sleep ? 8 : 7) * 24 * 60 * 60 * 1000
    let s = source
    var days: [DailyValue]
    var raw: [(start: Double, json: JSValue)]
    var bundle: SleepDetailedBundle?
    if metric == .weight {
      guard case .success(let samples) = await settle("weight_range", { try await s.samples(.bodyMass, from: from, to: now) })
      else { return (nil, nil) }
      let readings = samples.map { QuantityReading(start: $0.start, quantity: $0.quantity) }
      raw = readings.map {
        ($0.start, .object([("startDate", .string(isoString($0.start))), ("quantity", .number($0.quantity))]))
      }
      days = Weekly.pickLatestPerDay(readings, endDate: now, clock: clock)
    } else {
      guard case .success(let samples) = await settle("sleep_range", { try await s.sleep(from: from, to: now) })
      else { return (nil, nil) }
      raw = samples.map { sample in
        var fields: [(String, JSValue)] = [
          ("startDate", .string(isoString(sample.start))), ("endDate", .string(isoString(sample.end))),
          ("value", .int(sample.value)),
        ]
        if let src = sample.source { fields.append(("source", .string(src))) }
        return (sample.start, .object(fields))
      }
      days = Weekly.aggregateSleep(samples, endDate: now, clock: clock)
      bundle = Sleep.detailedBundle(samples, endDate: now, clock: clock)
    }
    if let cache {
      do {
        for day in days where day.date != todayKey {
          try cache.putComputed(metric, day.date, day.json)
          let dayRaw = raw.filter { clock.dateKey($0.start) == day.date }.map(\.json)
          if !dayRaw.isEmpty { try cache.putRaw(metric, day.date, .array(dayRaw)) }
        }
      } catch {
        fail("cache_write", error)
      }
    }
    if metric == .weight {
      days = days.map { DailyValue(date: $0.date, value: $0.value.map { jsRound($0 * 2.20462) }) }
    }
    return (.daily(days), bundle)
  }

  /// Every other series: past days from the cache, the rest (today always) from Health one day at a time.
  func perDay(_ metric: MetricKey, now: Double) async -> WeeklySeries {
    let todayKey = clock.dateKey(now)
    let keys = Weekly.dateKeys(endDate: now, clock: clock)
    var cached: [String: JSValue] = [:]
    if let cache {
      do { cached = try cache.computed(metric, keys) } catch { fail("cache_read", error) }
    }
    let (hits, fetch) = HealthCache.partition(todayKey: todayKey, dateKeys: keys, cached: cached)
    var fresh: [String: (computed: JSValue, raw: JSValue)] = [:]
    await withTaskGroup(of: (String, (JSValue, JSValue)?).self) { group in
      for key in fetch {
        group.addTask { (key, await self.fetchDay(metric, key)) }
      }
      for await (key, result) in group {
        if let result { fresh[key] = result }
      }
    }
    if let cache {
      do {
        for key in fetch where key != todayKey {
          guard let r = fresh[key] else { continue }
          try cache.putComputed(metric, key, r.computed)
          try cache.putRaw(metric, key, r.raw)
        }
      } catch {
        fail("cache_write", error)
      }
    }
    let merged = keys.map { fresh[$0]?.computed ?? hits[$0] }
    if metric.isRanged {
      return .ranged(zip(keys, merged).map { key, v in v.flatMap(HeartRateDaily.init(json:)) ?? HeartRateDaily(date: key) })
    }
    return .daily(zip(keys, merged).map { key, v in v.flatMap(DailyValue.init(json:)) ?? DailyValue(date: key, value: nil) })
  }

  /// One day from Health: the computed day and the raw rows the cache keeps. Nil when Health failed.
  func fetchDay(_ metric: MetricKey, _ dateKey: String) async -> (JSValue, JSValue)? {
    let dayStart = clock.midnight(dateKey)
    let dayEnd = clock.endOfDay(dateKey)
    let s = source
    switch metric {
    case .steps, .activeEnergy, .walkingDistance:
      let kind: QuantityKind = metric == .steps ? .steps : metric == .activeEnergy ? .activeEnergy : .distance
      // A failed sum is a day with no value, as in the React Native app.
      let sum = (try? await s.sum(kind, from: dayStart, to: dayEnd)) ?? nil
      let value = sum.map(round2)
      return (
        DailyValue(date: dateKey, value: value).json,
        .array([.object([("date", .string(dateKey)), ("value", .num(value)), ("source", .string("statistics"))])])
      )
    case .exerciseMinutes:
      guard case .success(let samples) = await settle("exercise_day", { try await s.samples(.exerciseTime, from: dayStart, to: dayEnd) })
      else { return nil }
      let total = samples.reduce(0.0) { $0 + $1.quantity }
      let value = total > 0 ? jsRound(total) : nil
      let raw: [JSValue] = samples.map {
        .object([
          ("startDate", .string(isoString($0.start))), ("endDate", .string(isoString($0.end))),
          ("quantity", .number($0.quantity)), ("source", .string($0.source ?? "unknown")),
        ])
      }
      return (DailyValue(date: dateKey, value: value).json, .array(raw))
    case .heartRate, .hrv, .restingHeartRate:
      let kind: QuantityKind = metric == .heartRate ? .heartRate : metric == .hrv ? .hrv : .restingHeartRate
      guard case .success(let samples) = await settle("\(metric.rawValue)_day", { try await s.samples(kind, from: dayStart, to: dayEnd) })
      else { return nil }
      let readings = samples.map { QuantityReading(start: $0.start, quantity: $0.quantity) }
      let day = Weekly.aggregateHeartRate(readings, endDate: dayEnd, days: 1, clock: clock)[0]
      let raw: [JSValue] = readings.map {
        .object([("startDate", .string(isoString($0.start))), ("quantity", .number($0.quantity))])
      }
      return (day.json, .array(raw))
    case .meditation:
      guard case .success(let sessions) = await settle("mindful_day", { try await s.mindful(from: dayStart, to: dayEnd) })
      else { return nil }
      let day = Weekly.aggregateMeditation(sessions, endDate: dayEnd, days: 1, clock: clock)[0]
      let raw: [JSValue] = sessions.map {
        .object([("startDate", .string(isoString($0.start))), ("endDate", .string(isoString($0.end)))])
      }
      return (day.json, .array(raw))
    case .weight, .sleep, .movement:
      return nil  // range queries / composite
    }
  }

  /// The week's workouts by the local day they began (the Exercise sheet's lists).
  public func workoutsByDay(now: Double) async -> [String: [WorkoutEntry]] {
    let s = source
    guard case .success(let workouts) = await settle("workouts_week", { try await s.workouts(from: now - 7 * 24 * 60 * 60 * 1000, to: now) })
    else { return [:] }
    var byDay: [String: [WorkoutEntry]] = [:]
    for w in workouts { byDay[clock.dateKey(w.start), default: []].append(w.entry) }
    return byDay
  }

  // MARK: - a whole grab

  /// Today, the week and the workouts. `finished` stamps the snapshot (the React Native app stamps it after the
  /// health and location reads).
  public func grab(now: Double, finished: () -> Double = { jsMillis(Date()) }) async -> MirrorSnapshot {
    let health = await health(now: now)
    let stamp = finished()
    let week = await weekly(now: now)
    let workouts = await workoutsByDay(now: now)
    return MirrorSnapshot(
      timestamp: isoString(stamp), health: health, weekly: week.series, sleepBundle: week.sleepBundle,
      workoutsByDay: workouts)
  }

  // MARK: - exports

  /// The summary Larry gets, single-line JSON.
  public static func summaryJSON(
    _ snap: MirrorSnapshot, accessory: [AccessoryLogEntry]?, activities: [ActivityEntry]? = nil, clock: LocalClock
  ) -> String {
    ContextExport.summary(
      snap.weeklyData, health: snap.health, places: nil, accessory: accessory.map(ContextExport.accessoryExport),
      activities: activities, clock: clock
    ).stringify()
  }

  /// The raw share, indented.
  public static func rawJSON(_ snap: MirrorSnapshot) -> String {
    ContextExport.raw(timestamp: snap.timestamp, health: snap.health).stringify(indent: 2)
  }
}
