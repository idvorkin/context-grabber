//  The colour language the map and the breakdown share (story 048), today's path (049) and the map's framing.
//  Ported from lib/places_colors.ts, lib/location.ts and StylizedMap's computeRegion; the icons are PlaceIcons.

import Foundation

public enum PlaceStyle {
  /// Hex RGB, assigned to named places in the order they first appear.
  public static let palette = [
    "#4361ee", "#f72585", "#4cc9f0", "#7209b7", "#3a86a7",
    "#f77f00", "#06d6a0", "#e63946", "#a8dadc", "#fca311",
  ]
  public static let unknownPlace = "#fca311"
  public static let transit = "#4cc9f0"
  public static let noData = "#555555"
  public static let future = "#2a2a40"
  public static let you = "#4cc9f0"

  /// "Place 3": a place the clustering found that has no name yet.
  public static func isUnnamed(_ placeId: String) -> Bool {
    guard placeId.hasPrefix("Place ") else { return false }
    let n = placeId.dropFirst(6)
    return !n.isEmpty && n.allSatisfy(\.isASCII) && n.allSatisfy(\.isNumber)
  }

  /// A stable colour per named place, by first appearance; unnamed places are skipped (they are always amber).
  public static func colors<S: Sequence>(for placeIds: S) -> [String: String] where S.Element == String {
    var map: [String: String] = [:]
    var i = 0
    for id in placeIds where !isUnnamed(id) && map[id] == nil {
      map[id] = palette[i % palette.count]
      i += 1
    }
    return map
  }

  /// The order the breakdown meets places in: day by day, newest first, longest first within a day.
  public static func colors(for days: [PlaceDaySummary]) -> [String: String] {
    colors(for: days.flatMap { $0.places.map(\.placeId) })
  }

  /// The colour of a place on both surfaces; a known place the last week never visited takes the next free slot.
  public static func color(_ placeId: String, in map: [String: String], fallbackIndex: Int = 0) -> String {
    if isUnnamed(placeId) { return unknownPlace }
    return map[placeId] ?? palette[fallbackIndex % palette.count]
  }

  // MARK: - today's path

  /// Today's breadcrumbs from local midnight to `now`, oldest first, thinned to at most `maxPoints` (first and
  /// last always kept); non-finite coordinates dropped. One point draws no line; a GPS silence is one straight
  /// segment between the last and next real points.
  public static func todaysRoute(
    _ points: [LocationPoint], now: Double, maxPoints: Int = 400, calendar: Calendar = .current
  ) -> [LocationPoint] {
    let start = Geo.ms(calendar.startOfDay(for: Geo.date(now)))
    let today = points.filter {
      $0.timestamp >= start && $0.timestamp <= now && $0.latitude.isFinite && $0.longitude.isFinite
    }.sorted { $0.timestamp < $1.timestamp }
    return thin(today, maxPoints)
  }

  static func thin<T>(_ items: [T], _ maxPoints: Int) -> [T] {
    if maxPoints < 2 || items.count <= maxPoints { return items }
    let stride = Double(items.count - 1) / Double(maxPoints - 1)
    var indices: [Int] = []
    for i in 0..<maxPoints {
      let j = Int(jsRound(Double(i) * stride))
      if indices.last != j { indices.append(j) }
    }
    return indices.map { items[$0] }
  }

  // MARK: - framing

  public struct Region: Equatable, Sendable {
    public var center: Coordinate
    public var latitudeDelta: Double
    public var longitudeDelta: Double
  }

  /// Framing for every pin, You and the path: their bounding box with 40% margin, never tighter than ~500 m.
  public static func region(places: [Coordinate], you: Coordinate?, path: [Coordinate]) -> Region? {
    let all = places + (you.map { [$0] } ?? []) + path.filter { $0.latitude.isFinite && $0.longitude.isFinite }
    guard let first = all.first else { return nil }
    var minLat = first.latitude, maxLat = first.latitude, minLng = first.longitude, maxLng = first.longitude
    for c in all {
      minLat = min(minLat, c.latitude)
      maxLat = max(maxLat, c.latitude)
      minLng = min(minLng, c.longitude)
      maxLng = max(maxLng, c.longitude)
    }
    return Region(
      center: Coordinate(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
      latitudeDelta: max(maxLat - minLat, 0.005) * 1.4,
      longitudeDelta: max(maxLng - minLng, 0.005) * 1.4)
  }

  /// The span the locate control zooms to: about a neighbourhood.
  public static let findMeDelta = 0.01

  /// "47.641901, -122.304481": what the copy control puts on the clipboard.
  public static func coordinateText(_ c: Coordinate) -> String {
    String(format: "%.6f, %.6f", c.latitude, c.longitude)
  }
}
