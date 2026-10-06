//  The places with no name yet, for the full-screen map (story 056): every "Place N" the stays found in a period,
//  with where it is, how long was spent there and each visit, and the radius the naming card suggests. Built from
//  the clustering's stays; nothing is clustered again.

import Foundation

public struct UnnamedPlace: Equatable, Sendable, Identifiable {
  /// "Place 3".
  public var placeId: String
  /// The stays' centres averaged, weighted by their points, as the clustering merges them.
  public var centroid: Coordinate
  /// Inside the period.
  public var totalMinutes: Int
  /// Each stay's part of the period, newest first.
  public var visits: [PlaceVisit]
  /// The farthest a stay's centre is from `centroid`, metres.
  public var spreadMeters: Double

  public var id: String { placeId }

  /// What the naming card fills in: the clustering's own radius plus the spread, up to the next ten metres.
  public var suggestedRadius: Double { UnnamedPlaces.suggestedRadius(spread: spreadMeters) }
}

public enum UnnamedPlaces {
  public static let maxSuggestedRadius = 250.0

  /// The unnamed places with time in [since, until], longest first (then by name, so the order is stable).
  public static func summarize(_ stays: [Stay], since: Double, until: Double) -> [UnnamedPlace] {
    var order: [String] = []
    var byId: [String: [Stay]] = [:]
    for stay in stays where PlaceStyle.isUnnamed(stay.placeId) {
      if min(until, stay.endTime) <= max(since, stay.startTime) { continue }
      if byId[stay.placeId] == nil { order.append(stay.placeId) }
      byId[stay.placeId, default: []].append(stay)
    }
    let places: [UnnamedPlace] = order.map { id in
      let stays = byId[id]!
      let weight = Double(max(1, stays.reduce(0) { $0 + $1.pointCount }))
      let centroid = Coordinate(
        latitude: stays.reduce(0) { $0 + $1.centroid.latitude * Double($1.pointCount) } / weight,
        longitude: stays.reduce(0) { $0 + $1.centroid.longitude * Double($1.pointCount) } / weight)
      let visits = stays.map { stay -> PlaceVisit in
        let s = max(since, stay.startTime)
        let e = min(until, stay.endTime)
        return PlaceVisit(placeId: id, startTime: s, endTime: e, durationMinutes: StayClustering.minutes(e - s))
      }.sorted { $0.startTime > $1.startTime }
      return UnnamedPlace(
        placeId: id, centroid: centroid,
        totalMinutes: StayClustering.minutes(visits.reduce(0) { $0 + ($1.endTime - $1.startTime) }), visits: visits,
        spreadMeters: stays.map { Geo.distance($0.centroid, centroid) }.max() ?? 0)
    }
    return places.sorted { ($0.totalMinutes, number($1.placeId)) > ($1.totalMinutes, number($0.placeId)) }
  }

  private static func number(_ placeId: String) -> Int { Int(placeId.dropFirst(6)) ?? 0 }

  /// 100 m plus the spread, rounded up to ten metres, at most 250 m. In the real fixture the visits' centres are at
  /// most 9 m apart and 2 338 of the unnamed stays' 2 340 points are within 100 m of their place's centre (the
  /// farthest 111 m), so the spread is only an allowance for wandering visits.
  public static func suggestedRadius(spread: Double) -> Double {
    min(maxSuggestedRadius, (ceil((StayClustering.stayRadius + max(0, spread)) / 10) * 10))
  }

  /// The grey dot's diameter in points: 10 for a few minutes, growing with the square root of the hours, 26 (about
  /// a named pin) from a day on.
  public static func dotDiameter(minutes: Int) -> Double {
    min(26, 10 + 3.3 * (Double(max(0, minutes)) / 60).squareRoot())
  }

  /// "Mon Mar 23 · 9:10 AM–11:40 AM · 2.5h": one line of the card.
  public static func visitLine(_ visit: PlaceVisit, calendar: Calendar = .current) -> String {
    let start = Geo.date(visit.startTime)
    let day = PlacesDaily.dayHeader(AccessoryLog.dateKey(start, calendar: calendar), calendar: calendar)
    let times = "\(AccessoryLog.clockTime(start, calendar: calendar))–\(AccessoryLog.clockTime(Geo.date(visit.endTime), calendar: calendar))"
    return "\(day) · \(times) · \(PlacesDaily.formatHours(visit.durationMinutes))"
  }

  /// "6.5h over 3 visits in the last 7 days".
  public static func summaryLine(_ place: UnnamedPlace, days: Int) -> String {
    let n = place.visits.count
    return "\(PlacesDaily.formatHours(place.totalMinutes)) over \(n) visit\(n == 1 ? "" : "s") in the last \(days) days"
  }
}
