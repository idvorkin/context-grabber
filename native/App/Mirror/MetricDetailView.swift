//  A metric's week (stories 003–012 as far as step 4 goes): today's value, a chart of seven days with today
//  marked, the average, and the days newest first. Sleep adds the source tabs, stages, debt, bedtime and wake,
//  onset and gap tags and a tapped night's zoom; Movement draws three normalized lines; Heart Rate carries resting
//  heart rate; Exercise lists the workouts under their day.

import Charts
import ContextCore
import SwiftUI

struct MetricDetailView: View {
  @ObservedObject var app: AppModel
  @ObservedObject var mirror: MirrorModel
  let metric: MetricKey
  @Environment(\.dismiss) private var dismiss
  @State private var source: String?
  @State private var selectedNight: String?

  private var config: MetricConfig { metric.config }
  private var color: Color { Color(hex: config.color) }
  private var snap: MirrorSnapshot? { mirror.snapshot }
  private var series: WeeklySeries? { snap?.weekly[metric] }
  private var clock: LocalClock { mirror.clock }
  private var todayKey: String { clock.dateKey(mirror.now()) }

  private var nights: [SleepDaily]? {
    guard metric == .sleep, let bundle = snap?.sleepBundle else { return nil }
    let tab = source ?? Sleep.pickDefaultSource(bundle)
    return tab == Sleep.allSources ? bundle.merged : bundle.bySource[tab] ?? bundle.merged
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          headline
          if metric == .sleep { sleepSection } else if metric == .movement { movementSection } else { chartSection }
          if let avg = MirrorText.average(metric, series: series, sleepNights: nights) {
            Text(avg).font(.subheadline.weight(.semibold)).accessibilityIdentifier("metric-average")
          }
          if metric == .heartRate { restingSection }
          rows
        }
        .padding(16)
      }
      .navigationTitle(config.label)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
          }
          .accessibilityLabel("Close")
        }
      }
    }
    .presentationDragIndicator(.visible)
    .onAppear { app.screen = "metric_\(metric.rawValue)" }
    .onDisappear { app.screen = "today" }
  }

  // MARK: - headline

  private var headline: some View {
    let card = mirror.cards.first { $0.key == metric || ($0.key == .exerciseMinutes && metric == .exerciseMinutes) }
    return VStack(alignment: .leading, spacing: 2) {
      Text(card?.value ?? MirrorText.none).font(.largeTitle.weight(.bold).monospacedDigit())
      Text(card?.sublabel ?? config.sublabel).font(.subheadline).foregroundStyle(.secondary)
      if series == nil && metric != .movement && mirror.grabbing {
        ProgressView().padding(.top, 8)
      }
    }
  }

  // MARK: - one value a day, or a day's range

  @ViewBuilder private var chartSection: some View {
    switch series {
    case .daily(let days)? where config.chartType == .bar:
      Chart(days, id: \.date) { d in
        BarMark(x: .value("Day", short(d.date)), y: .value(config.unit, d.value ?? 0))
          .foregroundStyle(color.opacity(d.date == todayKey ? 1 : 0.55))
      }
      .frame(height: 200)
    case .daily(let days)?:
      Chart(days.filter { $0.value != nil }, id: \.date) { d in
        LineMark(x: .value("Day", short(d.date)), y: .value(config.unit, d.value!)).foregroundStyle(color)
        PointMark(x: .value("Day", short(d.date)), y: .value(config.unit, d.value!)).foregroundStyle(color)
      }
      .chartXScale(domain: days.map { short($0.date) })
      .chartYScale(domain: .automatic(includesZero: false))
      .frame(height: 200)
    case .ranged(let days)?:
      RangeChart(days: days, color: color, unit: config.unit, todayKey: todayKey)
    case nil:
      EmptyView()
    }
  }

  // MARK: - Movement

  @ViewBuilder private var movementSection: some View {
    if let steps = snap?.weekly[.steps]?.daily, let dist = snap?.weekly[.walkingDistance]?.daily,
      let energy = snap?.weekly[.activeEnergy]?.daily
    {
      let o = Weekly.movementOverlay(steps: steps, distance: dist, energy: energy)
      let points = MovementPoint.points(o)
      Chart(points) { p in
        LineMark(x: .value("Day", short(p.date)), y: .value("Share of max", p.value))
          .foregroundStyle(by: .value("Series", p.series))
        PointMark(x: .value("Day", short(p.date)), y: .value("Share of max", p.value))
          .foregroundStyle(by: .value("Series", p.series))
      }
      .chartForegroundStyleScale([
        "Steps": Color(hex: MetricKey.steps.config.color), "Distance": Color(hex: MetricKey.walkingDistance.config.color),
        "Energy": Color(hex: MetricKey.activeEnergy.config.color),
      ])
      .chartXScale(domain: o.days.map { short($0.dateKey) })
      .chartYAxis(.hidden)
      .frame(height: 200)
      HStack(spacing: 12) {
        legend("Steps", o.stepsMax, "", .steps)
        legend("Distance", o.distanceMax, " km", .walkingDistance)
        legend("Energy", o.energyMax, " kcal", .activeEnergy)
      }
      .font(.caption)
    }
  }

  private func legend(_ name: String, _ max: Double, _ unit: String, _ key: MetricKey) -> some View {
    HStack(spacing: 4) {
      Circle().fill(Color(hex: key.config.color)).frame(width: 8, height: 8)
      Text("\(name) max \(SummaryText.formatNumber(max, maxFractionDigits: 2))\(unit)").foregroundStyle(.secondary)
    }
  }

  // MARK: - Heart Rate's resting rate

  @ViewBuilder private var restingSection: some View {
    let resting = snap?.weekly[.restingHeartRate]?.ranged ?? []
    let today = snap?.health.restingHeartRate
    if today != nil || resting.contains(where: { $0.avg != nil }) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Resting heart rate").font(.headline)
        Text(today.map { "\(SummaryText.js($0)) bpm latest" } ?? MirrorText.none).foregroundStyle(.secondary)
        Chart(resting.filter { $0.avg != nil }, id: \.date) { d in
          LineMark(x: .value("Day", short(d.date)), y: .value("bpm", d.avg!)).foregroundStyle(Color(hex: MetricKey.restingHeartRate.config.color))
          PointMark(x: .value("Day", short(d.date)), y: .value("bpm", d.avg!)).foregroundStyle(Color(hex: MetricKey.restingHeartRate.config.color))
        }
        .chartXScale(domain: resting.map { short($0.date) })
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 110)
      }
    }
  }

  // MARK: - Sleep

  @ViewBuilder private var sleepSection: some View {
    if let bundle = snap?.sleepBundle, let nights {
      let tabs = [Sleep.allSources] + bundle.bySource.keys.sorted()
      if tabs.count > 1 {
        Picker("Source", selection: Binding(get: { source ?? Sleep.pickDefaultSource(bundle) }, set: {
          source = $0
          app.log.event("ui", ["action": "sleep_source", "source": $0])
        })) {
          ForEach(tabs, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.segmented)
      }
      Chart {
        ForEach(nights, id: \.date) { n in
          ForEach(StageStyle.legend, id: \.1) { name, value in
            BarMark(x: .value("Night", short(n.date)), y: .value("Hours", hours(n, value)))
              .foregroundStyle(by: .value("Stage", name))
              .opacity(selectedNight == nil || selectedNight == n.date ? 1 : 0.4)
          }
          if (n.coreHours + n.deepHours + n.remHours) == 0, let total = n.totalHours {
            BarMark(x: .value("Night", short(n.date)), y: .value("Hours", total))
              .foregroundStyle(by: .value("Stage", "Asleep"))
          }
        }
      }
      .chartForegroundStyleScale([
        "Core": StageStyle.color(3), "Deep": StageStyle.color(4), "REM": StageStyle.color(5), "Awake": StageStyle.color(2),
        "Asleep": StageStyle.color(1),
      ])
      .chartXScale(domain: nights.map { short($0.date) })
      .chartOverlay { proxy in
        GeometryReader { _ in
          Rectangle().fill(.clear).contentShape(Rectangle()).onTapGesture { location in
            guard let label: String = proxy.value(atX: location.x),
              let night = nights.first(where: { short($0.date) == label })
            else { return }
            selectedNight = selectedNight == night.date ? nil : night.date
            app.log.event("ui", ["action": "sleep_night", "night": night.date, "open": selectedNight != nil])
          }
        }
      }
      .frame(height: 220)
      HStack(spacing: 8) {
        ForEach(nights.suffix(7), id: \.date) { n in
          Text(n.totalHours.map { "\(SummaryText.js($0))h" } ?? MirrorText.none)
            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }
      }
      if let date = selectedNight, let night = nights.first(where: { $0.date == date }) {
        NightCard(night: night, clock: clock)
      }
      let debt = Sleep.sleepDebt(nights, targetHours: mirror.sleepTarget)
      Text(MirrorText.sleepDebt(debt, target: mirror.sleepTarget))
        .font(.subheadline)
        .foregroundStyle(debt > 4 ? Color(hex: "#e63946") : debt > 2 ? Color(hex: "#f4845f") : .secondary)
      ConsistencyChart(nights: nights, clock: clock)
    } else if mirror.grabbing {
      ProgressView()
    }
  }

  private func hours(_ n: SleepDaily, _ stage: Int) -> Double {
    switch stage {
    case 3: return n.coreHours
    case 4: return n.deepHours
    case 5: return n.remHours
    default: return n.awakeHours
    }
  }

  // MARK: - the days, newest first

  @ViewBuilder private var rows: some View {
    VStack(spacing: 0) {
      if metric == .sleep, let nights {
        ForEach(nights.reversed(), id: \.date) { n in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(MirrorText.dayRow(n.date))
              Spacer()
              if let onset = MirrorText.onsetTag(n.onsetMinutes) { Text(onset).font(.caption).foregroundStyle(.secondary) }
              if let gap = MirrorText.gapTag(Sleep.trackingGap(n)) { Text("⚠ \(gap)").font(.caption).foregroundStyle(.orange) }
              Text(n.totalHours.map { "\(SummaryText.js($0))h" } ?? MirrorText.none).monospacedDigit()
            }
            StageStrip(night: n, height: 12, clock: clock)
          }
          .padding(.vertical, 8)
          .contentShape(Rectangle())
          .onTapGesture { selectedNight = selectedNight == n.date ? nil : n.date }
          Divider()
        }
      } else if metric == .movement, let steps = snap?.weekly[.steps]?.daily {
        let o = Weekly.movementOverlay(
          steps: steps, distance: snap?.weekly[.walkingDistance]?.daily ?? [], energy: snap?.weekly[.activeEnergy]?.daily ?? [])
        ForEach(o.days.reversed(), id: \.dateKey) { d in
          VStack(alignment: .leading, spacing: 2) {
            Text(MirrorText.dayRow(d.dateKey))
            Text(
              "Steps: \(d.steps.map { SummaryText.formatNumber($0) } ?? MirrorText.none)   Distance: \(d.distanceKm.map { "\(SummaryText.js($0)) km" } ?? MirrorText.none)   Energy: \(d.energyKcal.map { "\(SummaryText.formatNumber($0)) kcal" } ?? MirrorText.none)"
            )
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 8)
          Divider()
        }
      } else if let series {
        ForEach(Array(zip(series.dates, rowValues(series))).reversed(), id: \.0) { date, value in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(MirrorText.dayRow(date))
              Spacer()
              Text(value).monospacedDigit()
            }
            if metric == .exerciseMinutes {
              ForEach(Array((snap?.workoutsByDay[date] ?? []).enumerated()), id: \.offset) { _, w in
                Text(workoutLine(w)).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
          .padding(.vertical, 8)
          Divider()
        }
      }
    }
  }

  private func rowValues(_ s: WeeklySeries) -> [String] {
    switch s {
    case .daily(let d): return d.map { MirrorText.dailyValue($0, unit: config.unit) }
    case .ranged(let d): return d.map(MirrorText.heartRateRow)
    }
  }

  private func workoutLine(_ w: WorkoutEntry) -> String {
    var parts = ["\(w.activityType)", "\(SummaryText.js(w.durationMinutes)) min"]
    if let e = w.energyBurned { parts.append("\(SummaryText.js(e)) kcal") }
    if let d = w.distanceKm { parts.append("\(SummaryText.js(d)) km") }
    return parts.joined(separator: " · ")
  }

  /// "Mon", "Tue": the chart's day labels.
  private func short(_ dateKey: String) -> String { String(MirrorText.dayRow(dateKey).prefix(3)) + dateKey.suffix(2) }
}

/// One point of the Movement chart: a series' day as a share of its week's max.
struct MovementPoint: Identifiable {
  let series: String
  let date: String
  let value: Double
  var id: String { series + date }

  static func points(_ o: MovementOverlayData) -> [MovementPoint] {
    let lines: [(String, [Double?])] = [
      ("Steps", o.stepsNormalized), ("Distance", o.distanceNormalized), ("Energy", o.energyNormalized),
    ]
    return lines.flatMap { name, values in
      zip(o.days, values).compactMap { day, v in v.map { MovementPoint(series: name, date: day.dateKey, value: $0) } }
    }
  }
}

/// One point of the bedtime-and-wake chart, in minutes from the night's midnight (a 1am bedtime is 25h).
struct ConsistencyPoint: Identifiable {
  let date: String
  let kind: String
  let minutes: Double
  var id: String { kind + date }
}

/// Heart-rate-shaped days: each day's range as a thin rule, the middle half as a box, the average as a line.
struct RangeChart: View {
  let days: [HeartRateDaily]
  let color: Color
  let unit: String
  let todayKey: String

  var body: some View {
    let present = days.filter { $0.avg != nil }
    Chart {
      ForEach(present, id: \.date) { d in
        let x = PlottableValue.value("Day", label(d.date))
        if let lo = d.min, let hi = d.max {
          RuleMark(x: x, yStart: .value(unit, lo), yEnd: .value(unit, hi)).foregroundStyle(color.opacity(0.5))
        }
        if let q1 = d.q1, let q3 = d.q3 {
          RectangleMark(x: x, yStart: .value(unit, q1), yEnd: .value(unit, q3), width: 14)
            .foregroundStyle(color.opacity(d.date == todayKey ? 0.55 : 0.3))
        }
        LineMark(x: x, y: .value(unit, d.avg!)).foregroundStyle(color)
        PointMark(x: x, y: .value(unit, d.avg!)).foregroundStyle(color)
      }
    }
    .chartXScale(domain: days.map { label($0.date) })
    .chartYScale(domain: .automatic(includesZero: false))
    .frame(height: 200)
  }

  private func label(_ dateKey: String) -> String { String(MirrorText.dayRow(dateKey).prefix(3)) + dateKey.suffix(2) }
}

/// A tapped night, large: date, total, bedtime → wake, the stages with the hours under them, and the shares.
struct NightCard: View {
  let night: SleepDaily
  let clock: LocalClock

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(MirrorText.dayRow(night.date)).font(.headline)
        Spacer()
        Text(night.totalHours.map { "\(SummaryText.js($0))h" } ?? MirrorText.none).font(.headline.monospacedDigit())
      }
      if let bed = night.bedtime, let wake = night.wakeTime {
        Text("\(SummaryText.formatLocalTime(bed, clock: clock)) \u{2013} \(SummaryText.formatLocalTime(wake, clock: clock))")
          .foregroundStyle(.secondary)
        StageStrip(night: night, height: 28, hourLabels: true, clock: clock)
        let total = night.coreHours + night.deepHours + night.remHours + night.awakeHours
        if total > 0 {
          HStack(spacing: 10) {
            ForEach(StageStyle.legend, id: \.1) { name, value in
              HStack(spacing: 3) {
                Circle().fill(StageStyle.color(value)).frame(width: 7, height: 7)
                Text(share(name, value, total))
              }
            }
          }
          .font(.caption)
        }
      } else {
        Text("No sleep recorded this night.").foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    .accessibilityIdentifier("night-card")
  }

  private func share(_ name: String, _ stage: Int, _ total: Double) -> String {
    let hours: Double
    switch stage {
    case 3: hours = night.coreHours
    case 4: hours = night.deepHours
    case 5: hours = night.remHours
    default: hours = night.awakeHours
    }
    return "\(name) \(SummaryText.js(jsRound(hours / total * 100)))%"
  }
}

/// Bedtime and wake over the week as two lines, with how much each wanders.
struct ConsistencyChart: View {
  let nights: [SleepDaily]
  let clock: LocalClock

  var body: some View {
    let stats = Sleep.consistency(nights, clock: clock)
    let points: [ConsistencyPoint] = nights.flatMap { n -> [ConsistencyPoint] in
      var out: [ConsistencyPoint] = []
      if let b = n.bedtime.flatMap(parseISO) {
        var m = Double(clock.hour(b) * 60 + clock.minute(b))
        if m <= 12 * 60 { m += 24 * 60 }
        out.append(ConsistencyPoint(date: n.date, kind: "Bedtime", minutes: m))
      }
      if let w = n.wakeTime.flatMap(parseISO) {
        out.append(ConsistencyPoint(date: n.date, kind: "Wake", minutes: Double(clock.hour(w) * 60 + clock.minute(w)) + 24 * 60))
      }
      return out
    }
    VStack(alignment: .leading, spacing: 4) {
      Text("Bedtime and wake").font(.headline)
      Chart(points) { p in
        LineMark(x: .value("Night", String(MirrorText.dayRow(p.date).prefix(3)) + p.date.suffix(2)), y: .value("Time", p.minutes))
          .foregroundStyle(by: .value("Line", p.kind))
        PointMark(x: .value("Night", String(MirrorText.dayRow(p.date).prefix(3)) + p.date.suffix(2)), y: .value("Time", p.minutes))
          .foregroundStyle(by: .value("Line", p.kind))
      }
      .chartXScale(domain: nights.map { String(MirrorText.dayRow($0.date).prefix(3)) + $0.date.suffix(2) })
      .chartYScale(domain: .automatic(includesZero: false))
      .chartYAxis {
        AxisMarks { v in
          AxisGridLine()
          AxisValueLabel {
            if let m = v.as(Double.self) {
              let mins = Int(m) % (24 * 60)
              Text(SummaryText.clockLabel(mins / 60, mins % 60))
            }
          }
        }
      }
      .chartForegroundStyleScale(["Bedtime": Color(hex: "#7b2cbf"), "Wake": Color(hex: "#ff9e00")])
      .frame(height: 160)
      Text("Bedtime \(MirrorText.spread(stats.bedtimeStdevMinutes)) · Wake \(MirrorText.spread(stats.wakeStdevMinutes))")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}
