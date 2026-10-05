//  Every day's hours add up (story 046): each local day split into stays, transit and no data, as bars and as a
//  time-ordered strip. Ported from lib/places_summary.ts, with one change: a day runs from one local midnight to
//  the next by the calendar, so the two days a year the clocks change are 23 and 25 hours long (the TypeScript
//  steps back exactly 24 hours, which is an hour off on those days).
//
//  Transit is not the clustering's gaps between stays: a gap counts as transit only where the raw trail has
//  evidence — runs of points at most ten minutes apart, each point standing for five minutes either side of it.
//  An overnight gap with a dead phone is no data, not eight hours of driving.

import Foundation

public struct PlaceVisit: Equatable, Sendable, Codable {
  public var placeId: String
  public var startTime: Double
  public var endTime: Double
  public var durationMinutes: Int
}

public struct DayStripSegment: Equatable, Sendable, Codable {
  public enum Kind: String, Sendable, Codable { case stay, transit, noData, future }
  /// Milliseconds from the day's start.
  public var startOffsetMs: Double
  public var endOffsetMs: Double
  public var kind: Kind
  /// Set for a stay.
  public var placeId: String?
}

public struct PlaceDaySummary: Equatable, Sendable, Codable {
  public struct PlaceTotal: Equatable, Sendable, Codable {
    public var placeId: String
    public var totalMinutes: Int
  }
  /// Local day, "YYYY-MM-DD".
  public var dateKey: String
  /// Longest first, at most ten.
  public var places: [PlaceTotal]
  /// Each stay's part of this day, in time order.
  public var visits: [PlaceVisit]
  /// The header: the whole day for a past day, so far for today.
  public var elapsedMinutes: Int
  public var totalStayMinutes: Int
  public var transitMinutes: Int
  public var noDataMinutes: Int
  /// Tiles the whole day, today's unlived part as `future`.
  public var stripSegments: [DayStripSegment]
  /// The day's length in milliseconds (24 h, or 23 / 25 when the clocks change): the strip's full width.
  public var dayLengthMs: Double
}

public enum PlacesDaily {
  struct Interval {
    var start: Double
    var end: Double
  }

  /// The most recent `days` local days, today first, from the stays and the raw trail. A day with neither a stay
  /// nor a point is left out (history from before tracking was on).
  public static func build(
    stays: [Stay], points rawPoints: [LocationPoint], days: Int, now: Double, calendar: Calendar = .current
  ) -> [PlaceDaySummary] {
    guard days > 0 else { return [] }
    let points = rawPoints.sorted { $0.timestamp < $1.timestamp }
    let todayStart = calendar.startOfDay(for: Geo.date(now))
    var out: [PlaceDaySummary] = []
    for i in 0..<days {
      guard let startDate = calendar.date(byAdding: .day, value: -i, to: todayStart),
        let nextDate = calendar.date(byAdding: .day, value: 1, to: startDate)
      else { continue }
      let dayStart = Geo.ms(startDate)
      let fullEnd = Geo.ms(nextDate)
      let dayEnd = min(fullEnd, now)
      if dayEnd <= dayStart { continue }

      var covered: [Interval] = []
      var placeMs: [(String, Double)] = []  // in first-seen order, as the TypeScript Map iterates
      var visits: [PlaceVisit] = []
      var stayMs = 0.0
      for stay in stays {
        let ov = max(0, min(dayEnd, stay.endTime) - max(dayStart, stay.startTime))
        if ov <= 0 { continue }
        stayMs += ov
        if let k = placeMs.firstIndex(where: { $0.0 == stay.placeId }) {
          placeMs[k].1 += ov
        } else {
          placeMs.append((stay.placeId, ov))
        }
        let s = max(stay.startTime, dayStart)
        let e = min(stay.endTime, dayEnd)
        covered.append(Interval(start: s, end: e))
        visits.append(PlaceVisit(placeId: stay.placeId, startTime: s, endTime: e, durationMinutes: StayClustering.minutes(ov)))
      }

      let split = splitNonStay(uncovered(covered, dayStart, dayEnd), points)
      let hasPoints = points.contains { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
      if stayMs == 0 && !hasPoints { continue }

      visits = visits.enumerated().sorted { ($0.element.startTime, $0.offset) < ($1.element.startTime, $1.offset) }
        .map(\.element)

      var strip: [DayStripSegment] = []
      var cursor = dayStart
      var vi = 0
      while cursor < dayEnd {
        if vi < visits.count, visits[vi].startTime <= cursor {
          let v = visits[vi]
          strip.append(DayStripSegment(startOffsetMs: cursor - dayStart, endOffsetMs: v.endTime - dayStart, kind: .stay, placeId: v.placeId))
          cursor = v.endTime
          vi += 1
        } else {
          let gapEnd = vi < visits.count ? visits[vi].startTime : dayEnd
          for sub in segmentNonStay(start: cursor, end: gapEnd, points: points) {
            strip.append(DayStripSegment(startOffsetMs: sub.start - dayStart, endOffsetMs: sub.end - dayStart, kind: sub.kind, placeId: nil))
          }
          cursor = gapEnd
        }
      }
      if dayEnd < fullEnd {
        strip.append(DayStripSegment(startOffsetMs: dayEnd - dayStart, endOffsetMs: fullEnd - dayStart, kind: .future, placeId: nil))
      }

      // Whole minutes; then make stay + transit + no data equal the header, trimming no data first, then transit,
      // so the stays stay truthful; a shortfall goes to no data.
      let elapsed = StayClustering.minutes(dayEnd - dayStart)
      let stayMin = StayClustering.minutes(stayMs)
      var transitMin = StayClustering.minutes(split.transitMs)
      var noDataMin = StayClustering.minutes(split.noDataMs)
      var delta = stayMin + transitMin + noDataMin - elapsed
      if delta > 0 {
        let d = min(delta, noDataMin)
        noDataMin -= d
        delta -= d
      }
      if delta > 0 {
        let d = min(delta, transitMin)
        transitMin -= d
        delta -= d
      }
      if delta < 0 { noDataMin += -delta }
      noDataMin = max(0, noDataMin)
      transitMin = max(0, transitMin)

      let places = placeMs.map { PlaceDaySummary.PlaceTotal(placeId: $0.0, totalMinutes: StayClustering.minutes($0.1)) }
        .enumerated().sorted { ($1.element.totalMinutes, $0.offset) < ($0.element.totalMinutes, $1.offset) }
        .map(\.element).prefix(10)

      out.append(
        PlaceDaySummary(
          dateKey: AccessoryLog.dateKey(startDate, calendar: calendar), places: Array(places), visits: visits,
          elapsedMinutes: elapsed, totalStayMinutes: places.reduce(0) { $0 + $1.totalMinutes },
          transitMinutes: transitMin, noDataMinutes: noDataMin, stripSegments: strip, dayLengthMs: fullEnd - dayStart))
    }
    return out
  }

  /// The parts of [dayStart, dayEnd] no interval covers.
  static func uncovered(_ covered: [Interval], _ dayStart: Double, _ dayEnd: Double) -> [Interval] {
    if dayEnd <= dayStart { return [] }
    let clamped = covered.map { Interval(start: max($0.start, dayStart), end: min($0.end, dayEnd)) }
      .filter { $0.end > $0.start }
      .sorted { $0.start < $1.start }
    var merged: [Interval] = []
    for iv in clamped {
      if let last = merged.last, iv.start <= last.end {
        merged[merged.count - 1].end = max(last.end, iv.end)
      } else {
        merged.append(iv)
      }
    }
    var gaps: [Interval] = []
    var cursor = dayStart
    for iv in merged {
      if iv.start > cursor { gaps.append(Interval(start: cursor, end: iv.start)) }
      cursor = max(cursor, iv.end)
    }
    if cursor < dayEnd { gaps.append(Interval(start: cursor, end: dayEnd)) }
    return gaps
  }

  /// Runs of evidence touching [start, end], each widened by the half window: the transit ranges, unclamped.
  static func evidenceRuns(start: Double, end: Double, points: [LocationPoint]) -> [Interval] {
    let half = StayClustering.looseHalfWindowMs
    var times: [Double] = []
    for p in points {
      if p.timestamp < start - half { continue }
      if p.timestamp > end + half { break }
      times.append(p.timestamp)
    }
    guard var runStart = times.first else { return [] }
    var runEnd = runStart
    var runs: [Interval] = []
    for t in times.dropFirst() {
      if t - runEnd <= StayClustering.looseMaxGapMs {
        runEnd = t
      } else {
        runs.append(Interval(start: runStart - half, end: runEnd + half))
        runStart = t
        runEnd = t
      }
    }
    runs.append(Interval(start: runStart - half, end: runEnd + half))
    return runs
  }

  /// How much of the non-stay time is transit (has evidence) and how much is no data. Points must be sorted.
  public static func splitNonStay(_ intervals: [(start: Double, end: Double)], _ points: [LocationPoint]) -> (transitMs: Double, noDataMs: Double) {
    splitNonStay(intervals.map { Interval(start: $0.start, end: $0.end) }, points)
  }

  static func splitNonStay(_ intervals: [Interval], _ points: [LocationPoint]) -> (transitMs: Double, noDataMs: Double) {
    var transit = 0.0
    var total = 0.0
    for iv in intervals where iv.end > iv.start {
      total += iv.end - iv.start
      for run in evidenceRuns(start: iv.start, end: iv.end, points: points) {
        let a = max(run.start, iv.start)
        let b = min(run.end, iv.end)
        if b > a { transit += b - a }
      }
    }
    transit = min(transit, total)
    return (transit, total - transit)
  }

  /// One non-stay gap as transit and no-data pieces that tile it exactly. Points must be sorted.
  public static func segmentNonStay(start: Double, end: Double, points: [LocationPoint]) -> [(start: Double, end: Double, kind: DayStripSegment.Kind)] {
    if end <= start { return [] }
    let runs = evidenceRuns(start: start, end: end, points: points)
      .map { Interval(start: max($0.start, start), end: min($0.end, end)) }
      .filter { $0.end > $0.start }
    if runs.isEmpty { return [(start, end, .noData)] }
    var out: [(start: Double, end: Double, kind: DayStripSegment.Kind)] = []
    var cursor = start
    for r in runs {
      if r.start > cursor { out.append((cursor, r.start, .noData)) }
      out.append((r.start, r.end, .transit))
      cursor = r.end
    }
    if cursor < end { out.append((cursor, end, .noData)) }
    return out
  }

  // MARK: - text

  /// 45 → "45m", 90 → "1.5h", 540 → "9h".
  public static func formatHours(_ minutes: Int) -> String {
    if minutes < 60 { return "\(minutes)m" }
    return "\(jsNumber(jsRound(Double(minutes) / 6) / 10))h"
  }

  /// A number as JavaScript prints it: no ".0" on a whole number.
  public static func jsNumber(_ x: Double) -> String {
    x == x.rounded() && abs(x) < 1e15 ? String(Int64(x)) : "\(x)"
  }

  /// One line per day for the coach: "Mon Apr 20: Home 9h, Office 8h, Gym 1h", or "…: no known places".
  public static func text(_ days: [PlaceDaySummary], calendar: Calendar = .current) -> String {
    days.map { day in
      let header = dayHeader(day.dateKey, calendar: calendar)
      if day.places.isEmpty { return "\(header): no known places" }
      return "\(header): " + day.places.map { "\($0.placeId) \(formatHours($0.totalMinutes))" }.joined(separator: ", ")
    }.joined(separator: "\n")
  }

  private static let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  /// "2026-04-20" → "Mon Apr 20".
  public static func dayHeader(_ dateKey: String, calendar: Calendar = .current) -> String {
    let parts = dateKey.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3, let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    else { return dateKey }
    return "\(weekdays[calendar.component(.weekday, from: date) - 1]) \(months[parts[1] - 1]) \(parts[2])"
  }
}
