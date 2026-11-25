//  #1493, story 572 (home-screen spec, "The week at a glance"): the counter's week as a little graph by day, above
//  the seven rows of its sheet. Oldest on the left, today on the right in the counter's colour; no grid, no axis
//  numbers, no totals: a glance, not a score.

import Charts
import ContextCore
import SwiftUI

struct CounterWeekGraph: View {
  let week: CounterWeek
  let label: String
  let color: Color

  private var bars: [CounterWeek.Bar] { week.graph }

  var body: some View {
    Chart(bars, id: \.day) { bar in
      BarMark(x: .value("Day", bar.day), y: .value("Count", bar.count), width: .ratio(0.55))
        .foregroundStyle(bar.isToday ? color : color.opacity(0.55))
        .clipShape(.rect(cornerRadius: 4))
    }
    // The week's own top, at least 1, so an empty week sits flat on the baseline rather than filling the chart.
    .chartYScale(domain: 0...max(1, bars.map(\.count).max() ?? 0))
    .chartYAxis(.hidden)
    .chartXAxis {
      AxisMarks(values: bars.map(\.day)) { value in
        AxisValueLabel(centered: true) {
          if let day = value.as(String.self), let bar = bars.first(where: { $0.day == day }) {
            Text(bar.initial)
              .font(.caption2.weight(bar.isToday ? .bold : .regular))
              .foregroundStyle(bar.isToday ? Color.primary : Color.secondary)
          }
        }
      }
    }
    .animation(.snappy, value: bars)
    .frame(height: 72)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(label) this week")
    .accessibilityValue(week.graphLabel)  // "Thu 0, Fri 0, … Wed 1", which the UI test reads back too
    .accessibilityIdentifier("strip-week-graph")
  }
}

#if DEBUG
  private func previewWeek() -> CounterWeek? {
    // Igor's Balloons week on 2026-11-25, from #1493's screenshot: 0, 0, 0, 1, 1, 3, 0 from Thursday.
    guard let db = try? SQLiteDatabase(), let strip = try? DailyStrip(db: db) else { return nil }
    for (day, value) in [("2026-11-22", 1), ("2026-11-23", 1), ("2026-11-24", 3)] {
      try? strip.set(.balloons, day: day, value: value)
    }
    return try? CounterWeek(.balloons, today: "2026-11-25", strip: strip)
  }

  #Preview("Balloons week, light") {
    if let week = previewWeek() {
      CounterWeekGraph(week: week, label: "Balloons", color: .pink).padding()
    }
  }

  #Preview("Balloons week, dark") {
    if let week = previewWeek() {
      CounterWeekGraph(week: week, label: "Balloons", color: .pink).padding()
        .preferredColorScheme(.dark)
    }
  }
#endif
