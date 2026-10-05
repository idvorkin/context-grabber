//  What the cards and the detail sheets say (stories 002–009): each card's value, sublabel and box plots, and a
//  sheet's day rows, average, sleep debt and tags. Ported from App.tsx's card list and
//  components/MetricDetailSheet.tsx so the two apps read the same; the views only draw these.

import Foundation

public struct MetricCard: Equatable, Sendable {
  public var key: MetricKey
  public var label: String
  /// "—" when there is nothing.
  public var value: String
  public var sublabel: String
  /// "#rrggbb"
  public var color: String
  /// One box plot, or three for Movement (steps, distance, energy), each with its colour.
  public var boxPlots: [(BoxPlotStats, String)]

  public var isEmpty: Bool { value == MirrorText.none }

  public static func == (a: MetricCard, b: MetricCard) -> Bool {
    a.key == b.key && a.label == b.label && a.value == b.value && a.sublabel == b.sublabel && a.color == b.color
      && a.boxPlots.map(\.0) == b.boxPlots.map(\.0)
  }
}

public enum MirrorText {
  public static let none = "\u{2014}"

  /// The Body cards, in the current app's order.
  public static func cards(_ h: HealthData?, weekly: [MetricKey: WeeklySeries], now: Double, clock: LocalClock)
    -> [MetricCard]
  {
    func plot(_ k: MetricKey) -> [(BoxPlotStats, String)] {
      weekly[k]?.boxPlot.map { [($0, k.config.color)] } ?? []
    }
    func since(_ k: MetricKey) -> String {
      switch Weekly.daysSinceLast(weekly[k]?.daily, now: now, clock: clock) {
      case nil: return "7+ days ago"
      case 0: return "today"
      case 1: return "yesterday"
      case let d?: return "\(d) days ago"
      }
    }
    let movementSub =
      "\(h?.walkingDistance.map { "\(SummaryText.js($0)) km" } ?? "\(none) km") \u{00B7} "
      + "\(h?.activeEnergy.map { "\(SummaryText.formatNumber($0)) kcal" } ?? "\(none) kcal")"
    let exerciseSub: String = {
      if let w = h?.workouts, !w.isEmpty { return w.map { "\($0.activityType) \(SummaryText.js($0.durationMinutes))m" }.joined(separator: ", ") }
      if let m = h?.exerciseMinutes, m > 0 { return "today" }
      return since(.exerciseMinutes)
    }()
    let sleepSub: String = {
      let bed = h?.bedtime.flatMap(parseISO)
      let wake = h?.wakeTime.flatMap(parseISO)
      if let bed, let wake {
        let inBed = (wake - bed) / 3_600_000
        if inBed > 0, let asleep = h?.sleepHours {
          // toFixed(1) takes a half up, as Math.round does; "%.1f" alone would round 7.25 to even.
          return String(format: "%.1fh bed \u{00B7} %@%% eff", round1(inBed), SummaryText.js(jsRound(asleep / inBed * 100)))
        }
        return "\(SummaryText.formatLocalTime(h!.bedtime!, clock: clock)) \u{2013} \(SummaryText.formatLocalTime(h!.wakeTime!, clock: clock))"
      }
      if let b = h?.bedtime { return "\(SummaryText.formatLocalTime(b, clock: clock)) \u{2013}" }
      if let w = h?.wakeTime { return "\u{2013} \(SummaryText.formatLocalTime(w, clock: clock))" }
      return "last night"
    }()
    let movementPlots: [(BoxPlotStats, String)] = plot(.steps) + plot(.walkingDistance) + plot(.activeEnergy)
    return [
      MetricCard(
        key: .movement, label: "Movement", value: h?.steps.map { SummaryText.formatNumber($0) } ?? none,
        sublabel: movementSub, color: MetricKey.movement.config.color, boxPlots: movementPlots),
      MetricCard(
        key: .exerciseMinutes, label: "Exercise",
        value: h?.exerciseMinutes.flatMap { $0 > 0 ? "\(SummaryText.js($0)) min" : nil } ?? none, sublabel: exerciseSub,
        color: MetricKey.exerciseMinutes.config.color, boxPlots: plot(.exerciseMinutes)),
      MetricCard(
        key: .heartRate, label: "Heart Rate", value: h?.heartRate.map { "\(SummaryText.js($0)) bpm" } ?? none,
        sublabel: "latest", color: MetricKey.heartRate.config.color, boxPlots: plot(.heartRate)),
      MetricCard(
        key: .hrv, label: "HRV", value: h?.hrv.map { "\(SummaryText.js($0)) ms" } ?? none, sublabel: "latest",
        color: MetricKey.hrv.config.color, boxPlots: plot(.hrv)),
      MetricCard(
        key: .sleep, label: "Sleep", value: h?.sleepHours.map { "\(SummaryText.js($0))h asleep" } ?? none,
        sublabel: sleepSub, color: MetricKey.sleep.config.color, boxPlots: plot(.sleep)),
      MetricCard(
        key: .meditation, label: "Meditation", value: h?.meditationMinutes.map { "\(SummaryText.js($0)) min" } ?? none,
        sublabel: "today", color: MetricKey.meditation.config.color, boxPlots: plot(.meditation)),
      MetricCard(
        key: .weight, label: "Weight", value: h?.weight.map { "\(SummaryText.js(jsRound($0 * 2.20462))) lbs" } ?? none,
        sublabel: h?.weightDaysLast7.map { "\(SummaryText.js($0))/7 days weighed" } ?? since(.weight),
        color: MetricKey.weight.config.color, boxPlots: plot(.weight)),
    ]
  }

  static let shortDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  /// "Sun, Mar 15"
  public static func dayRow(_ dateKey: String) -> String {
    let p = dateKey.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return dateKey }
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    guard let d = utc.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { return dateKey }
    return "\(shortDays[utc.component(.weekday, from: d) - 1]), \(shortMonths[p[1] - 1]) \(p[2])"
  }

  /// "72 avg (55–140)"
  public static func heartRateRow(_ d: HeartRateDaily) -> String {
    guard let avg = d.avg else { return none }
    if let lo = d.min, let hi = d.max {
      return "\(SummaryText.js(jsRound(avg))) avg (\(SummaryText.js(jsRound(lo)))\u{2013}\(SummaryText.js(jsRound(hi))))"
    }
    return SummaryText.js(jsRound(avg))
  }

  /// "8,241 steps", "5.23 km"
  public static func dailyValue(_ d: DailyValue, unit: String) -> String {
    guard let v = d.value else { return none }
    return "\(number(v)) \(unit)"
  }

  static func number(_ v: Double) -> String {
    v == v.rounded() ? SummaryText.formatNumber(v) : SummaryText.formatNumber(v, maxFractionDigits: 2)
  }

  /// "Avg: 8,241 steps/day"; Sleep averages the nights on screen (the selected source), never the export's days.
  public static func average(_ key: MetricKey, series: WeeklySeries?, sleepNights: [SleepDaily]?) -> String? {
    let unit = key.config.unit
    if key == .sleep {
      let hours = (sleepNights ?? []).compactMap(\.totalHours)
      guard !hours.isEmpty else { return nil }
      return "Avg: \(SummaryText.js(round1(hours.reduce(0, +) / Double(hours.count)))) \(unit)/day"
    }
    guard let series else { return nil }
    switch series {
    case .ranged(let days):
      guard let avg = Weekly.average(days.map { DailyValue(date: $0.date, value: $0.avg) }) else { return nil }
      return "Avg: \(SummaryText.formatNumber(jsRound(avg))) \(unit)/day"
    case .daily(let days):
      guard let avg = Weekly.average(days) else { return nil }
      return "Avg: \(number(avg)) \(unit)/day"
    }
  }

  /// "Sleep debt: −3h 12m over 7 days (target 8h)"
  public static func sleepDebt(_ debt: Double, target: Double) -> String {
    if debt <= 0 { return "Sleep debt: 0m (caught up!)" }
    let h = Int(debt.rounded(.down))
    let m = Int(jsRound((debt - Double(h)) * 60))
    let text = h > 0 && m > 0 ? "\(h)h \(m)m" : h > 0 ? "\(h)h" : "\(m)m"
    return "Sleep debt: \u{2212}\(text) over 7 days (target \(SummaryText.js(target))h)"
  }

  /// "onset 25m", "gap 1h 35m": the tags on a night's row. Onset shows from ten minutes.
  public static func onsetTag(_ minutes: Double?) -> String? {
    guard let m = minutes, m >= 10 else { return nil }
    return "onset \(duration(Int(m)))"
  }

  public static func gapTag(_ minutes: Double?) -> String? {
    guard let m = minutes else { return nil }
    return "gap \(duration(Int(m)))"
  }

  static func duration(_ m: Int) -> String {
    m >= 60 ? "\(m / 60)h\(m % 60 != 0 ? " \(m % 60)m" : "")" : "\(m)m"
  }

  /// "±18m" under the bedtime-and-wake chart.
  public static func spread(_ minutes: Double) -> String { "\u{00B1}\(SummaryText.js(minutes))m" }
}
