//  Sleep, night by night (stories 006–009, 025): noon-to-noon nights, the main session picked out of noise,
//  stages merged across sources, per-source tabs with an All view, onset, tracking gaps, sleep debt and bedtime
//  consistency. Port of lib/sleep.ts.

import Foundation

public struct SleepDetails: Equatable, Sendable {
  public var bedtime: String?
  public var wakeTime: String?
}

/// One night: the noon-to-noon window starting at noon on `date`.
public struct SleepDaily: Equatable, Sendable {
  public var date: String
  /// Merged core + deep + REM (+ generic asleep) inside the main session, one decimal; nil for none.
  public var totalHours: Double?
  public var coreHours: Double = 0
  public var deepHours: Double = 0
  public var remHours: Double = 0
  public var awakeHours: Double = 0
  /// ISO 8601, the main session's first and last moment.
  public var bedtime: String?
  public var wakeTime: String?
  /// Awake time directly before falling asleep, minutes; nil when there was none.
  public var onsetMinutes: Double?
  /// The night's samples by start, for the stage strip.
  public var samples: [SleepSample] = []

  public init(date: String) { self.date = date }
}

public struct SleepConsistencyStats: Equatable, Sendable {
  public var bedtimeStdevMinutes: Double
  public var wakeStdevMinutes: Double
}

public struct SleepDetailedBundle: Equatable, Sendable {
  /// Per source, sources sorted by name.
  public var bySource: [String: [SleepDaily]]
  /// All sources merged.
  public var merged: [SleepDaily]
}

public enum Sleep {
  /// Awake further than this from the next known moment is noise, not onset; the same gap splits sessions.
  public static let onsetNoiseGapMs: Double = 60 * 60 * 1000
  public static let allSources = "All"

  /// Earliest start and latest end of whatever samples there are.
  public static func extractSleepDetails(_ samples: [SleepSample]?) -> SleepDetails {
    guard let samples, !samples.isEmpty else { return SleepDetails() }
    let sorted = stableSorted(samples) { $0.start < $1.start }
    return SleepDetails(bedtime: isoString(sorted[0].start), wakeTime: isoString(sorted[sorted.count - 1].end))
  }

  /// `days` nights ending with the night of `endDate`'s local date. A sample belongs to the night whose noon-to-noon
  /// window holds its start: before noon is the previous night.
  public static func aggregateDetailed(_ samples: [SleepSample]?, endDate: Double, days: Int = 7, clock: LocalClock)
    -> [SleepDaily]
  {
    let midnight = clock.setHours(endDate, 0)
    var buckets = (0..<days).reversed().map { i in SleepDaily(date: clock.dateKey(clock.addDays(midnight, -i))) }
    guard let samples, !samples.isEmpty else { return buckets }
    var index: [String: Int] = [:]
    for (i, b) in buckets.enumerated() { index[b.date] = i }

    for s in samples {
      var night = clock.setHours(s.start, 0)
      if clock.hour(s.start) < 12 { night = clock.addDays(night, -1) }
      if let i = index[clock.dateKey(night)] { buckets[i].samples.append(s) }
    }

    for i in buckets.indices where !buckets[i].samples.isEmpty {
      buckets[i].samples = stableSorted(buckets[i].samples) { $0.start < $1.start }
      let night = buckets[i].samples
      let main = pickMainSleepSession(Health.filterActualSleep(night))
      if let main {
        buckets[i].bedtime = isoString(main.start)
        buckets[i].wakeTime = isoString(main.end)
        buckets[i].onsetMinutes = onsetMinutes(night, firstSleep: main.start)
      }
      func hours(_ pool: [SleepSample]) -> Double {
        main.map { mergedHoursInRange(pool, $0.start, $0.end) } ?? mergedHours(pool)
      }
      buckets[i].coreHours = round1(hours(night.filter { $0.value == 3 }))
      buckets[i].deepHours = round1(hours(night.filter { $0.value == 4 }))
      buckets[i].remHours = round1(hours(night.filter { $0.value == 5 }))
      buckets[i].awakeHours = round1(hours(night.filter { $0.value == 2 }))
      let total = hours(night.filter { [1, 3, 4, 5].contains($0.value ?? -1) })
      buckets[i].totalHours = total > 0 ? round1(total) : nil
    }
    return buckets
  }

  /// The overnight session among a night's asleep samples: samples within an hour of each other are one session,
  /// and the one with the most staged (else any) sleep wins, ties to the later one.
  public static func pickMainSleepSession(_ asleep: [SleepSample]) -> (start: Double, end: Double)? {
    let sorted = stableSorted(asleep.filter { $0.end > $0.start }) { $0.start < $1.start }
    guard !sorted.isEmpty else { return nil }
    var clusters: [(start: Double, end: Double, samples: [SleepSample])] = []
    for s in sorted {
      if let last = clusters.last, s.start - last.end <= onsetNoiseGapMs {
        clusters[clusters.count - 1].end = max(last.end, s.end)
        clusters[clusters.count - 1].samples.append(s)
      } else {
        clusters.append((s.start, s.end, [s]))
      }
    }
    func merged(_ c: [SleepSample], _ values: Set<Int>) -> Double {
      let pool = c.filter { $0.value.map(values.contains) ?? false }
      guard !pool.isEmpty else { return 0 }
      return Health.mergedMillis(pool.map { ($0.start, $0.end) })
    }
    let staged: Set<Int> = [3, 4, 5]
    let anySleep: Set<Int> = [1, 3, 4, 5]
    let anyTyped = clusters.contains { merged($0.samples, staged) > 0 }
    func score(_ c: [SleepSample]) -> Double { merged(c, anyTyped ? staged : anySleep) }
    var best = clusters[0]
    var bestMs = score(best.samples)
    for c in clusters.dropFirst() {
      let ms = score(c.samples)
      if ms > bestMs || (ms == bestMs && c.end > best.end) {
        best = c
        bestMs = ms
      }
    }
    return (best.start, best.end)
  }

  static func mergedHoursInRange(_ samples: [SleepSample], _ from: Double, _ to: Double) -> Double {
    guard !samples.isEmpty, to > from else { return 0 }
    let clipped = samples.map { (max(from, $0.start), min(to, $0.end)) }.filter { $0.1 > $0.0 }
    guard !clipped.isEmpty else { return 0 }
    return Health.mergedMillis(clipped) / (1000 * 60 * 60)
  }

  static func mergedHours(_ samples: [SleepSample]) -> Double {
    let spans = samples.map { ($0.start, $0.end) }.filter { $0.1 > $0.0 }
    guard !spans.isEmpty else { return 0 }
    return Health.mergedMillis(spans) / (1000 * 60 * 60)
  }

  /// One series per source plus All; a source with no samples has no tab.
  public static func detailedBundle(_ samples: [SleepSample]?, endDate: Double, days: Int = 7, clock: LocalClock)
    -> SleepDetailedBundle
  {
    let merged = aggregateDetailed(samples, endDate: endDate, days: days, clock: clock)
    var bySource: [String: [SleepDaily]] = [:]
    guard let samples, !samples.isEmpty else { return SleepDetailedBundle(bySource: [:], merged: merged) }
    var groups: [String: [SleepSample]] = [:]
    for s in samples { groups[s.source ?? "Unknown", default: []].append(s) }
    for (source, group) in groups {
      bySource[source] = aggregateDetailed(group, endDate: endDate, days: days, clock: clock)
    }
    return SleepDetailedBundle(bySource: bySource, merged: merged)
  }

  /// The tab a Sleep sheet opens on: the source with the most stage detail, else All. Ties go alphabetically.
  public static func pickDefaultSource(_ bundle: SleepDetailedBundle) -> String {
    var best: (name: String, score: Double)?
    for name in bundle.bySource.keys.sorted() {
      let score = bundle.bySource[name]!.reduce(0.0) { $0 + $1.coreHours + $1.deepHours + $1.remHours }
      if score <= 0 { continue }
      if best == nil || score > best!.score { best = (name, score) }
    }
    return best?.name ?? allSources
  }

  /// Hours short of the target over the nights, one decimal; oversleeping earns nothing back, a missing night
  /// counts as none.
  public static func sleepDebt(_ nights: [SleepDaily], targetHours: Double) -> Double {
    guard targetHours > 0, !nights.isEmpty else { return 0 }
    var debt = 0.0
    for n in nights {
      let deficit = targetHours - (n.totalHours ?? 0)
      if deficit > 0 { debt += deficit }
    }
    return round1(debt)
  }

  /// Awake minutes right before the first sleep, walking back while each gap stays within an hour; nil for none.
  public static func onsetMinutes(_ samples: [SleepSample], firstSleep: Double) -> Double? {
    guard !samples.isEmpty else { return nil }
    let awake = stableSorted(
      samples.filter { $0.value == 2 }.map { ($0.start, $0.end) }.filter { $0.1 <= firstSleep && $0.1 > $0.0 }
    ) { $0.0 < $1.0 }
    guard !awake.isEmpty else { return nil }
    var merged: [(Double, Double)] = [awake[0]]
    for r in awake.dropFirst() {
      if r.0 <= merged[merged.count - 1].1 {
        merged[merged.count - 1].1 = max(merged[merged.count - 1].1, r.1)
      } else {
        merged.append(r)
      }
    }
    var total = 0.0
    var cursor = firstSleep
    for seg in merged.reversed() {
      if cursor - seg.1 > onsetNoiseGapMs { break }
      total += seg.1 - seg.0
      cursor = seg.0
    }
    guard total > 0 else { return nil }
    return jsRound(total / 60000)
  }

  /// Minutes in bed that no sample covers, when more than max(30 min, 10 % of the night); nil otherwise.
  public static func trackingGap(_ night: SleepDaily) -> Double? {
    guard let bedIso = night.bedtime, let wakeIso = night.wakeTime, let bed = parseISO(bedIso),
      let wake = parseISO(wakeIso), let total = night.totalHours, total > 0
    else { return nil }
    let inBed = (wake - bed) / 60000
    guard inBed > 0 else { return nil }
    let awake = night.samples.filter { $0.value == 2 }.map { (max($0.start, bed), min($0.end, wake)) }
      .filter { $0.1 > $0.0 }
    let awakeMs = awake.isEmpty ? 0 : Health.mergedMillis(awake)
    let gap = inBed - (total * 60 + awakeMs / 60000)
    guard gap > max(30, inBed * 0.1) else { return nil }
    return jsRound(gap)
  }

  /// Spread of bedtimes and wake times, minutes (a 1am bedtime sits next to 11pm, not 22 hours away).
  public static func consistency(_ nights: [SleepDaily], clock: LocalClock) -> SleepConsistencyStats {
    var bed: [Double] = []
    var wake: [Double] = []
    for n in nights {
      if let b = n.bedtime.flatMap(parseISO) {
        var m = Double(clock.hour(b) * 60 + clock.minute(b))
        if m <= 12 * 60 { m += 24 * 60 }
        bed.append(m)
      }
      if let w = n.wakeTime.flatMap(parseISO) {
        wake.append(Double(clock.hour(w) * 60 + clock.minute(w)))
      }
    }
    return SleepConsistencyStats(bedtimeStdevMinutes: stdev(bed), wakeStdevMinutes: stdev(wake))
  }

  static func stdev(_ v: [Double]) -> Double {
    guard v.count >= 2 else { return 0 }
    let mean = v.reduce(0, +) / Double(v.count)
    let variance = v.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(v.count)
    return jsRound(variance.squareRoot())
  }
}
