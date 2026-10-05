//  Distances, the retention cutoff and the trail's basic types (stories 040, 041). Ported from lib/geo.ts and
//  lib/location.ts; every timestamp is UTC unix milliseconds, as a Double because the React Native app stored the
//  fractional milliseconds iOS reports (the shared table holds REAL values in an INTEGER column).

import Foundation

/// One breadcrumb from the trail.
public struct LocationPoint: Equatable, Sendable, Codable {
  public var latitude: Double
  public var longitude: Double
  /// Metres, as CoreLocation reported it; nil when unknown.
  public var accuracy: Double?
  /// UTC unix milliseconds.
  public var timestamp: Double

  public init(latitude: Double, longitude: Double, accuracy: Double? = nil, timestamp: Double) {
    self.latitude = latitude
    self.longitude = longitude
    self.accuracy = accuracy
    self.timestamp = timestamp
  }
}

public struct Coordinate: Equatable, Sendable, Codable {
  public var latitude: Double
  public var longitude: Double
  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

public enum Geo {
  public static let earthRadiusMeters = 6_371_000.0
  private static let degToRad = Double.pi / 180

  /// Great-circle distance in metres.
  public static func distance(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
    let dLat = (lat2 - lat1) * degToRad
    let dLng = (lng2 - lng1) * degToRad
    let a =
      pow(sin(dLat / 2), 2) + cos(lat1 * degToRad) * cos(lat2 * degToRad) * pow(sin(dLng / 2), 2)
    return 2 * earthRadiusMeters * asin(sqrt(a))
  }

  public static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
    distance(a.latitude, a.longitude, b.latitude, b.longitude)
  }

  public static let dayMs = 86_400_000.0

  /// Points with a timestamp before this are pruned. Zero (or less) days prunes everything before `now`.
  public static func pruneThreshold(retentionDays: Int, now: Double) -> Double {
    now - Double(max(0, retentionDays)) * dayMs
  }

  /// Milliseconds since 1970 for a Date.
  public static func ms(_ date: Date) -> Double { date.timeIntervalSince1970 * 1000 }
  public static func date(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }
}
