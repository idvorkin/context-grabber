//  Breadcrumbs become stays (stories 043, 044): a temporal walk through the trail, not a spatial clustering.
//  Ported faithfully from lib/clustering_v2.ts — the same steps, thresholds and arithmetic order, so the same
//  trail gives the same stays in both apps (checked against the real fixture by PlacesFixtureTests). The text
//  summaries that file also builds belong to Grab Context's export and move with it (step 4).
//
//  1. label each point with the known place it falls in;
//  2. walk the points: a stay grows while points stay within 100 m of its running centre (a gap over four hours
//     still extends it when the next point is within 100 m), and ends on a move or on a known-place change;
//     stays under five minutes are dropped;
//  3. merge neighbours within 100 m (or at the same known place) that are at most 30 minutes apart;
//  4. name each stay: its known place, else a known disc its centre falls in, else "Place N" — numbered by first
//     visit, the same N for a later stay within 100 m of that place's running centre;
//  5. merge consecutive stays with the same name, whatever the gap: iOS sends nothing while the phone sits still,
//     so a night at home is two stays bracketing hours of silence;
//  6. the gaps between stays are transit segments.

import Foundation

public struct Stay: Equatable, Sendable, Codable {
  /// "Home", "Place 3".
  public var placeId: String
  public var centroid: Coordinate
  public var startTime: Double
  public var endTime: Double
  public var durationMinutes: Int
  public var pointCount: Int

  public init(
    placeId: String, centroid: Coordinate, startTime: Double, endTime: Double, durationMinutes: Int, pointCount: Int
  ) {
    self.placeId = placeId
    self.centroid = centroid
    self.startTime = startTime
    self.endTime = endTime
    self.durationMinutes = durationMinutes
    self.pointCount = pointCount
  }
}

public struct TransitSegment: Equatable, Sendable, Codable {
  public var startTime: Double
  public var endTime: Double
  public var durationMinutes: Int
  /// One decimal.
  public var distanceKm: Double
  public var fromPlaceId: String
  public var toPlaceId: String
}

public struct StayClusters: Equatable, Sendable {
  public var stays: [Stay]
  public var transit: [TransitSegment]
}

/// JavaScript's Math.round: the nearest integer, halves toward +infinity.
@inlinable func jsRound(_ x: Double) -> Double {
  let f = floor(x)
  return x - f >= 0.5 ? f + 1 : f
}

public enum StayClustering {
  public static let stayRadius = 100.0  // metres
  public static let minStayMs = 5 * 60 * 1000.0
  public static let mergeGapMs = 30 * 60 * 1000.0
  /// The transit / no-data split: points at most this far apart are one run of evidence...
  public static let looseMaxGapMs = 10 * 60 * 1000.0
  /// ...and each point stands for this long either side of itself.
  public static let looseHalfWindowMs = 5 * 60 * 1000.0

  struct RawStay {
    var lat: Double
    var lng: Double
    var start: Double
    var end: Double
    var count: Int
    var known: Int  // index into the known places, or -1
  }

  public static func cluster(_ points: [LocationPoint], knownPlaces: [KnownPlace] = []) -> StayClusters {
    if points.isEmpty { return StayClusters(stays: [], transit: []) }
    // A stable sort, as JavaScript's is: points sharing a timestamp keep their stored order.
    let sorted = points.enumerated().sorted { ($0.element.timestamp, $0.offset) < ($1.element.timestamp, $1.offset) }
      .map(\.element)
    let labels = knownPlaces.isEmpty ? Array(repeating: -1, count: sorted.count) : KnownPlaces.label(sorted, with: knownPlaces)
    let raw = mergeStays(detectStays(sorted, labels))
    let stays = mergeConsecutiveSamePlace(assignPlaces(raw, knownPlaces))
    return StayClusters(stays: stays, transit: buildTransit(stays))
  }

  static func detectStays(_ points: [LocationPoint], _ labels: [Int]) -> [RawStay] {
    guard let first = points.first else { return [] }
    var stays: [RawStay] = []
    var cur = RawStay(lat: first.latitude, lng: first.longitude, start: first.timestamp, end: first.timestamp, count: 1, known: labels[0])

    func finalize() {
      if cur.end - cur.start >= minStayMs { stays.append(cur) }
    }
    func extend(_ p: LocationPoint, _ label: Int) {
      cur.count += 1
      cur.end = p.timestamp
      cur.lat = (cur.lat * Double(cur.count - 1) + p.latitude) / Double(cur.count)
      cur.lng = (cur.lng * Double(cur.count - 1) + p.longitude) / Double(cur.count)
      if cur.known == -1 && label != -1 { cur.known = label }
    }

    for i in 1..<points.count {
      let p = points[i]
      let dist = Geo.distance(cur.lat, cur.lng, p.latitude, p.longitude)
      let labelChanged = labels[i] != -1 && cur.known != -1 && labels[i] != cur.known
      if labelChanged || dist > stayRadius {
        // A known-place change is a boundary even within the radius; so is a move, after any gap.
        finalize()
        cur = RawStay(lat: p.latitude, lng: p.longitude, start: p.timestamp, end: p.timestamp, count: 1, known: labels[i])
      } else {
        // Within the radius: extends the stay after a gap of any length. (The TypeScript tests the gap against
        // four hours first, but both of its branches end the same way.)
        extend(p, labels[i])
      }
    }
    finalize()
    return stays
  }

  static func mergeStays(_ stays: [RawStay]) -> [RawStay] {
    guard let first = stays.first else { return [] }
    var merged = [first]
    for curr in stays.dropFirst() {
      let prev = merged[merged.count - 1]
      let dist = Geo.distance(prev.lat, prev.lng, curr.lat, curr.lng)
      let gap = curr.start - prev.end
      let sameKnown = prev.known != -1 && prev.known == curr.known
      if (dist <= stayRadius || sameKnown) && gap <= mergeGapMs {
        var m = prev
        let total = prev.count + curr.count
        m.lat = (prev.lat * Double(prev.count) + curr.lat * Double(curr.count)) / Double(total)
        m.lng = (prev.lng * Double(prev.count) + curr.lng * Double(curr.count)) / Double(total)
        m.end = curr.end
        m.count = total
        if m.known == -1 { m.known = curr.known }
        merged[merged.count - 1] = m
      } else {
        merged.append(curr)
      }
    }
    return merged
  }

  static func minutes(_ ms: Double) -> Int { Int(jsRound(ms / 60000)) }

  static func assignPlaces(_ stays: [RawStay], _ known: [KnownPlace]) -> [Stay] {
    struct Discovered {
      let id: String
      var lat: Double
      var lng: Double
      var stayCount: Int
    }
    var discovered: [Discovered] = []
    var next = 1
    return stays.map { raw in
      var placeId: String
      if raw.known != -1 {
        placeId = known[raw.known].name
      } else if let k = KnownPlaces.match(latitude: raw.lat, longitude: raw.lng, in: known) {
        placeId = known[k.index].name
      } else if let i = discovered.firstIndex(where: { Geo.distance(raw.lat, raw.lng, $0.lat, $0.lng) <= stayRadius }) {
        placeId = discovered[i].id
        discovered[i].stayCount += 1
        let n = Double(discovered[i].stayCount)
        discovered[i].lat = (discovered[i].lat * (n - 1) + raw.lat) / n
        discovered[i].lng = (discovered[i].lng * (n - 1) + raw.lng) / n
      } else {
        placeId = "Place \(next)"
        discovered.append(Discovered(id: placeId, lat: raw.lat, lng: raw.lng, stayCount: 1))
        next += 1
      }
      return Stay(
        placeId: placeId, centroid: Coordinate(latitude: raw.lat, longitude: raw.lng), startTime: raw.start,
        endTime: raw.end, durationMinutes: minutes(raw.end - raw.start), pointCount: raw.count)
    }
  }

  /// Step 5: consecutive stays with the same name become one, whatever the gap between them. "Consecutive"
  /// already means nothing else happened in between: a visit elsewhere would be a stay in the list.
  public static func mergeConsecutiveSamePlace(_ stays: [Stay]) -> [Stay] {
    guard let first = stays.first else { return stays }
    var result = [first]
    for curr in stays.dropFirst() {
      var prev = result[result.count - 1]
      if prev.placeId == curr.placeId {
        let total = prev.pointCount + curr.pointCount
        prev.centroid = Coordinate(
          latitude: (prev.centroid.latitude * Double(prev.pointCount) + curr.centroid.latitude * Double(curr.pointCount))
            / Double(total),
          longitude: (prev.centroid.longitude * Double(prev.pointCount) + curr.centroid.longitude * Double(curr.pointCount))
            / Double(total))
        prev.endTime = curr.endTime
        prev.pointCount = total
        prev.durationMinutes = minutes(prev.endTime - prev.startTime)
        result[result.count - 1] = prev
      } else {
        result.append(curr)
      }
    }
    return result
  }

  static func buildTransit(_ stays: [Stay]) -> [TransitSegment] {
    guard stays.count > 1 else { return [] }
    return (1..<stays.count).compactMap { i in
      let prev = stays[i - 1]
      let curr = stays[i]
      let gap = curr.startTime - prev.endTime
      guard gap > 0 else { return nil }
      let km = Geo.distance(prev.centroid, curr.centroid) / 1000
      return TransitSegment(
        startTime: prev.endTime, endTime: curr.startTime, durationMinutes: minutes(gap),
        distanceKm: jsRound(km * 10) / 10, fromPlaceId: prev.placeId, toPlaceId: curr.placeId)
    }
  }
}
