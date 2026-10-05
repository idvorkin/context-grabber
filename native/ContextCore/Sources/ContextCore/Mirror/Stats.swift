//  Box-plot statistics for the cards (story 004): R-7 percentiles (NumPy's and Excel's default), one decimal.
//  Port of lib/stats.ts.

import Foundation

public struct BoxPlotStats: Equatable, Sendable {
  public var min: Double
  public var p5: Double
  public var p25: Double
  public var p50: Double
  public var p75: Double
  public var p95: Double
  public var max: Double
  /// Sorted, rounded to one decimal.
  public var values: [Double]
}

public enum Stats {
  /// Linear interpolation between closest ranks (R-7). `p` is a fraction, 0.5 for the median. Nil for no values.
  public static func percentile(_ sorted: [Double], _ p: Double) -> Double? {
    guard !sorted.isEmpty else { return nil }
    if sorted.count == 1 { return sorted[0] }
    let index = p * Double(sorted.count - 1)
    let lower = Int(index.rounded(.down))
    let upper = Int(index.rounded(.up))
    if lower == upper { return sorted[lower] }
    let fraction = index - Double(lower)
    return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
  }

  /// Nil when no value is finite.
  public static func boxPlot(_ values: [Double]) -> BoxPlotStats? {
    let sorted = values.filter { $0.isFinite }.sorted()
    guard let first = sorted.first, let last = sorted.last else { return nil }
    func p(_ q: Double) -> Double { round1(percentile(sorted, q) ?? 0) }
    return BoxPlotStats(
      min: round1(first), p5: p(0.05), p25: p(0.25), p50: p(0.5), p75: p(0.75), p95: p(0.95), max: round1(last),
      values: sorted.map(round1))
  }

  /// The non-null values of a daily series.
  public static func values(_ days: [DailyValue]) -> [Double] { days.compactMap(\.value) }
}
