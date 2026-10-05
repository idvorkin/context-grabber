//  The arithmetic the React Native app's lib/ does with JavaScript numbers and Dates, done the same way here so
//  the export matches byte for byte: Math.round (halves up), times as milliseconds since 1970 (a Date's value is
//  whole milliseconds), toISOString, and the local calendar of `new Date()` / setHours / setDate / getHours.

import Foundation

/// JavaScript's Math.round: the nearest integer, halves toward +∞ (Swift's .rounded() takes halves away from 0).
@inline(__always)
public func jsRound(_ x: Double) -> Double {
  guard x.isFinite else { return x }
  let floor = x.rounded(.down)
  return x - floor >= 0.5 ? floor + 1 : floor
}

/// Math.round(x * 10) / 10, the one-decimal rounding lib/ uses everywhere.
@inline(__always) public func round1(_ x: Double) -> Double { jsRound(x * 10) / 10 }
/// Math.round(x * 100) / 100.
@inline(__always) public func round2(_ x: Double) -> Double { jsRound(x * 100) / 100 }

/// A JavaScript Date's value for an instant: milliseconds, truncated as `new Date(ms)` truncates.
public func jsMillis(_ date: Date) -> Double {
  (date.timeIntervalSince1970 * 1000).rounded(.towardZero)
}

public func jsDate(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

/// Date.prototype.toISOString: "2026-05-03T13:27:38.089Z".
public func isoString(_ ms: Double) -> String {
  let total = Int64(ms.rounded(.down))
  var days = total / 86_400_000
  var rem = total % 86_400_000
  if rem < 0 { rem += 86_400_000; days -= 1 }
  let (y, m, d) = civilFromDays(days)
  let h = rem / 3_600_000
  let mi = (rem / 60_000) % 60
  let s = (rem / 1000) % 60
  let msPart = rem % 1000
  return String(format: "%04lld-%02lld-%02lldT%02lld:%02lld:%02lld.%03lldZ", y, m, d, h, mi, s, msPart)
}

/// Parses an ISO 8601 UTC instant ("…Z", with or without milliseconds) back to milliseconds.
public func parseISO(_ s: String) -> Double? {
  let b = Array(s.utf8)
  func num(_ from: Int, _ len: Int) -> Int64? {
    guard from + len <= b.count else { return nil }
    var v: Int64 = 0
    for c in b[from..<from + len] {
      guard c >= 48 && c <= 57 else { return nil }
      v = v * 10 + Int64(c - 48)
    }
    return v
  }
  guard b.count >= 20, let y = num(0, 4), let mo = num(5, 2), let d = num(8, 2), let h = num(11, 2),
    let mi = num(14, 2), let sec = num(17, 2)
  else { return nil }
  var ms: Int64 = 0
  if b.count > 20, b[19] == UInt8(ascii: "."), let f = num(20, 3) { ms = f }
  let days = daysFromCivil(y, mo, d)
  return Double(days * 86_400_000 + h * 3_600_000 + mi * 60_000 + sec * 1000 + ms)
}

// Howard Hinnant's civil-calendar algorithms (proleptic Gregorian, days since 1970-01-01).
private func civilFromDays(_ z0: Int64) -> (Int64, Int64, Int64) {
  let z = z0 + 719_468
  let era = (z >= 0 ? z : z - 146_096) / 146_097
  let doe = z - era * 146_097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = mp < 10 ? mp + 3 : mp - 9
  return (m <= 2 ? y + 1 : y, m, d)
}

private func daysFromCivil(_ y0: Int64, _ m: Int64, _ d: Int64) -> Int64 {
  let y = m <= 2 ? y0 - 1 : y0
  let era = (y >= 0 ? y : y - 399) / 400
  let yoe = y - era * 400
  let doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  return era * 146_097 + doe - 719_468
}

/// The device's local calendar as lib/ sees it through `Date`: local days, hours and wall-clock arithmetic. The
/// tests pin a time zone; the app uses the phone's.
public struct LocalClock: Sendable {
  public let calendar: Calendar

  public init(timeZone: TimeZone = .current) {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = timeZone
    calendar = c
  }

  public static let current = LocalClock()

  /// formatDateKey: "YYYY-MM-DD" of the local day.
  public func dateKey(_ ms: Double) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: jsDate(ms))
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  /// `new Date(y, m - 1, d)` / `new Date(dateKey + "T00:00:00")`: local midnight of a date key.
  public func midnight(_ dateKey: String) -> Double {
    let p = dateKey.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return .nan }
    return localTime(year: p[0], month: p[1], day: p[2])
  }

  /// `new Date(dateKey + "T23:59:59.999")`.
  public func endOfDay(_ dateKey: String) -> Double {
    let p = dateKey.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return .nan }
    return localTime(year: p[0], month: p[1], day: p[2], hour: 23, minute: 59, second: 59, ms: 999)
  }

  public func localTime(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0, ms: Int = 0)
    -> Double
  {
    let date = calendar.date(
      from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))
    return (date.map { jsMillis($0) } ?? .nan) + Double(ms)
  }

  /// `d.setHours(h, 0, 0, 0)` on the local day of `ms`.
  public func setHours(_ ms: Double, _ hour: Int) -> Double {
    let c = calendar.dateComponents([.year, .month, .day], from: jsDate(ms))
    return localTime(year: c.year ?? 0, month: c.month ?? 1, day: c.day ?? 1, hour: hour)
  }

  /// `d.setDate(d.getDate() + n)`: the same wall-clock time `n` local days away.
  public func addDays(_ ms: Double, _ n: Int) -> Double {
    let date = jsDate(ms)
    let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
    let msPart = ms - (ms / 1000).rounded(.down) * 1000
    guard let d = calendar.date(
      from: DateComponents(
        year: c.year, month: c.month, day: (c.day ?? 1) + n, hour: c.hour, minute: c.minute, second: c.second))
    else { return .nan }
    return jsMillis(d) + msPart
  }

  public func hour(_ ms: Double) -> Int { calendar.component(.hour, from: jsDate(ms)) }
  public func minute(_ ms: Double) -> Int { calendar.component(.minute, from: jsDate(ms)) }
  /// getDay(): 0 = Sunday.
  public func weekday(_ ms: Double) -> Int { calendar.component(.weekday, from: jsDate(ms)) - 1 }
}
