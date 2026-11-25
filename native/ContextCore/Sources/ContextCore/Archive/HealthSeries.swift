//  Story 270, the heart-rate gaps (context-grabber-kseb, 2026-11-25): a workout's heart rate is a few stored
//  samples that each hold a run of readings, and Health hands its history over in stored order, so a restored phone
//  sends years of old history before the last year. Here: a stored series as one record per reading, and the
//  newest-first walk of a dense type's last days that runs beside the oldest-first history.
//  Spec: docs/superpowers/specs/2026-10-19-native-stats-archive-design.md, "Every heart-rate reading".

import Foundation

public enum ArchiveSeries {
  /// One reading a stored sample holds.
  public struct Reading: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var value: Double

    public init(start: Date, end: Date, value: Double) {
      self.start = start
      self.end = end
      self.value = value
    }
  }

  /// The readings of a stored sample as records of their own, beside the sample's own record: each keeps the
  /// sample's type, unit and source, names the sample it came from, and has a guid of its own (the sample and the
  /// reading's start), so a reading sent twice is one record.
  public static func records(parent: [String: Any], readings: [Reading]) -> [[String: Any]] {
    guard let parentGUID = parent["guid"] as? String else { return [] }
    let kept = ["type", "unit", "source", "source_bundle", "device"]
    return readings.map { reading in
      var record: [String: Any] = [
        "guid": ArchiveGUID.reading(parentGUID, start: reading.start), "series": parentGUID,
        "start": jsMillis(reading.start), "end": jsMillis(reading.end), "value": reading.value,
      ]
      for key in kept { if let value = parent[key] { record[key] = value } }
      return record
    }
  }
}

extension ArchiveGUID {
  /// One reading of a stored series sample: the sample's guid and the reading's start in UTC ms.
  public static func reading(_ sampleGUID: String, start: Date) -> String {
    "r:\(sampleGUID):\(Int64((start.timeIntervalSince1970 * 1000).rounded()))"
  }
}

/// The newest-first walk of a dense Health type's last `days` days, then what is new after it: the cursor of a
/// second pass over the type's stream, beside the anchored history that goes oldest-first in stored order.
public struct RecentSweep: Codable, Equatable, Sendable {
  public static let days = 400
  /// The Health types busy enough that their history takes weeks of runs: heart rate, steps, active energy and
  /// walking distance.
  public static let denseTypes: Set<String> = [
    "HKQuantityTypeIdentifierHeartRate", "HKQuantityTypeIdentifierStepCount",
    "HKQuantityTypeIdentifierActiveEnergyBurned", "HKQuantityTypeIdentifierDistanceWalkingRunning",
  ]

  /// Where the walk back stops (UTC ms), fixed when it starts.
  public var floor: Int64
  /// The oldest start sent going back; nil before the first page.
  public var oldest: Int64?
  /// The newest start sent; the walk forward asks for what started after it.
  public var newest: Int64?
  /// The walk back reached `floor`.
  public var done: Bool

  public init(floor: Int64, oldest: Int64? = nil, newest: Int64? = nil, done: Bool = false) {
    self.floor = floor
    self.oldest = oldest
    self.newest = newest
    self.done = done
  }

  public static func start(now: Int64) -> RecentSweep {
    RecentSweep(floor: now - Int64(days) * 86_400_000)
  }

  public enum Query: Equatable, Sendable {
    /// Samples starting in `from...through`, newest first.
    case back(from: Int64, through: Int64)
    /// Samples starting after `after`, oldest first.
    case forward(after: Int64)
  }

  public func next(now: Int64) -> Query {
    done ? .forward(after: newest ?? floor) : .back(from: floor, through: oldest ?? now)
  }

  /// The sweep after a page of `query` whose samples started at `starts`, and whether there is more to read.
  /// A full page going back moves `oldest` to its oldest start (one ms further when the page did not move it, so
  /// a run of samples on one instant cannot hold the walk), a short one ends the walk; going forward moves `newest`.
  public func after(_ query: Query, starts: [Int64], limit: Int) -> (sweep: RecentSweep, more: Bool) {
    var next = self
    if let top = starts.max() { next.newest = max(next.newest ?? top, top) }
    switch query {
    case .back(_, let through):
      if starts.count < limit {
        next.done = true
        if next.newest == nil { next.newest = through }
        return (next, true)
      }
      let low = starts.min() ?? through
      next.oldest = low < through ? low : through - 1
      if let oldest = next.oldest, oldest < floor { next.done = true }
      return (next, true)
    case .forward:
      return (next, starts.count >= limit)
    }
  }

  public var json: String {
    (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? ""
  }

  public init?(json: String?) {
    guard let data = json?.data(using: .utf8), let sweep = try? JSONDecoder().decode(RecentSweep.self, from: data)
    else { return nil }
    self = sweep
  }
}
