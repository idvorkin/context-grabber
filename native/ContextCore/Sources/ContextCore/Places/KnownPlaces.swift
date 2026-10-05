//  Known places: matching a point to the nearest named disc, and growing a disc to take in a nearby stay
//  (stories 045, 047). Ported from lib/places.ts.

import Foundation

public struct KnownPlace: Equatable, Sendable, Codable, Identifiable {
  /// The row id in `known_places`.
  public var id: Int64
  public var name: String
  public var latitude: Double
  public var longitude: Double
  public var radiusMeters: Double

  public init(id: Int64, name: String, latitude: Double, longitude: Double, radiusMeters: Double) {
    self.id = id
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.radiusMeters = radiusMeters
  }

  public var coordinate: Coordinate { Coordinate(latitude: latitude, longitude: longitude) }
}

public struct PlaceCircle: Equatable, Sendable {
  public var latitude: Double
  public var longitude: Double
  public var radiusMeters: Double
  public init(latitude: Double, longitude: Double, radiusMeters: Double) {
    self.latitude = latitude
    self.longitude = longitude
    self.radiusMeters = radiusMeters
  }
}

public enum KnownPlaces {
  /// The closest place whose disc holds the point: its index and distance, or nil.
  public static func match(
    latitude: Double, longitude: Double, in places: [KnownPlace]
  ) -> (index: Int, distance: Double)? {
    var best: (index: Int, distance: Double)?
    for (i, place) in places.enumerated() {
      let d = Geo.distance(latitude, longitude, place.latitude, place.longitude)
      if d <= place.radiusMeters && d < (best?.distance ?? .infinity) { best = (i, d) }
    }
    return best
  }

  /// For each point, the index of the known place it falls in, or -1.
  public static func label(_ points: [LocationPoint], with places: [KnownPlace]) -> [Int] {
    points.map { match(latitude: $0.latitude, longitude: $0.longitude, in: places)?.index ?? -1 }
  }

  /// The smallest disc holding the existing disc and the new centre, plus `buffer` metres. The centre moves along
  /// the straight line toward the new point (sub-kilometre distances: the flat error is under a centimetre). A
  /// point already inside the disc changes nothing.
  public static func grow(_ existing: PlaceCircle, toInclude point: Coordinate, buffer: Double = 50) -> PlaceCircle {
    let d = Geo.distance(existing.latitude, existing.longitude, point.latitude, point.longitude)
    if d <= existing.radiusMeters { return existing }
    let t = ((d - existing.radiusMeters) / 2) / d
    return PlaceCircle(
      latitude: existing.latitude + (point.latitude - existing.latitude) * t,
      longitude: existing.longitude + (point.longitude - existing.longitude) * t,
      radiusMeters: (d + existing.radiusMeters) / 2 + buffer)
  }

  /// How far a stay may be from a known place for the naming card to offer growing it rather than a new place.
  /// 50 m caught none of the ten unmatched stays in the real fixture; 500 m catches "Place 2", 160 m from Milstead.
  public static let mergeSuggestMeters = 500.0

  public struct MergeSuggestion: Equatable, Sendable {
    public let nearest: KnownPlace
    public let distance: Double
    /// Other known places within `mergeSuggestMeters`.
    public let others: Int
    public let grown: PlaceCircle
    /// How far the centre would move, metres.
    public let shift: Double
  }

  /// What the naming card offers for a stay centred at `centroid`: nil means go straight to naming.
  public static func suggestion(for centroid: Coordinate, among places: [KnownPlace]) -> MergeSuggestion? {
    let near = places.map { ($0, Geo.distance(centroid, $0.coordinate)) }
      .filter { $0.1 <= mergeSuggestMeters }
      .sorted { $0.1 < $1.1 }
    guard let (place, distance) = near.first else { return nil }
    let grown = grow(
      PlaceCircle(latitude: place.latitude, longitude: place.longitude, radiusMeters: place.radiusMeters),
      toInclude: centroid)
    let shift = Geo.distance(place.latitude, place.longitude, grown.latitude, grown.longitude)
    return MergeSuggestion(nearest: place, distance: distance, others: near.count - 1, grown: grown, shift: shift)
  }

  /// Places from the JSON the Import places field accepts: an array, or an object with `knownPlaces` / `places`;
  /// `lat`/`latitude`, `lon`/`lng`/`longitude`, `radiusMeters`/`radius_meters`/`radius` (100 by default). Entries
  /// without a name or with coordinates out of range are skipped. Throws when the JSON has no such array.
  public static func parseImportJSON(_ text: String) throws -> [(name: String, latitude: Double, longitude: Double, radius: Double)] {
    let json = try JSONSerialization.jsonObject(with: Data(text.utf8))
    let items: [Any]
    if let array = json as? [Any] {
      items = array
    } else if let object = json as? [String: Any], let array = (object["knownPlaces"] ?? object["places"]) as? [Any] {
      items = array
    } else {
      throw ImportJSONError.noArray
    }
    func number(_ any: Any?) -> Double? {
      if let n = any as? NSNumber { return n.doubleValue }
      if let s = any as? String { return Double(s.trimmingCharacters(in: .whitespaces)) }
      return nil
    }
    return items.compactMap { item in
      guard let p = item as? [String: Any] else { return nil }
      let name = (p["name"].map { "\($0)" } ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty, let lat = number(p["lat"] ?? p["latitude"]),
        let lng = number(p["lon"] ?? p["lng"] ?? p["longitude"]),
        (-90...90).contains(lat), (-180...180).contains(lng)
      else { return nil }
      let radius = number(p["radiusMeters"] ?? p["radius_meters"] ?? p["radius"]) ?? 100
      return (name, lat, lng, radius)
    }
  }

  public enum ImportJSONError: Error, CustomStringConvertible {
    case noArray
    public var description: String { "JSON must be an array or have a knownPlaces/places array" }
  }
}
