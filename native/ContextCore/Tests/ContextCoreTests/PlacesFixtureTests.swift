//  The cross-check on real data: the 36 601-point fixture trail with its four real known places, clustered by the
//  native port, must give exactly what the TypeScript gives (Fixtures/places-expected.json, written by
//  scripts/native/make-places-expected.mjs from lib/clustering_v2.ts and lib/places_summary.ts) — the same stays
//  with the same names, starts, ends and point counts, the same transit, the same fourteen day cards and strips.
//  And the real database export imports in full, once.

import XCTest

@testable import ContextCore

private let repo = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  .deletingLastPathComponent()
private let fixtures = repo.appendingPathComponent("__tests__/fixtures")

private struct Expected: Decodable {
  struct Day: Decodable {
    struct Total: Decodable {
      let placeId: String
      let totalMinutes: Int
    }
    struct Segment: Decodable {
      let startOffsetMs: Double
      let endOffsetMs: Double
      let kind: String
      let placeId: String?
    }
    let dateKey: String
    let places: [Total]
    let visits: [PlaceVisit]
    let elapsedMinutes: Int
    let totalStayMinutes: Int
    let transitMinutes: Int
    let noDataMinutes: Int
    let stripSegments: [Segment]
  }
  let timeZone: String
  let now: Double
  let knownPlaces: [KnownPlace]
  let stays: [Stay]
  let transit: [TransitSegment]
  let days: [Day]
  let text: String
}

final class PlacesFixtureTests: XCTestCase {
  private func load() throws -> (Expected, [LocationPoint], Calendar) {
    let expected = try JSONDecoder().decode(
      Expected.self,
      from: Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/places-expected.json")))
    let points = try JSONDecoder().decode([LocationPoint].self, from: Data(contentsOf: fixtures.appendingPathComponent("locations.json")))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: expected.timeZone)!
    return (expected, points, calendar)
  }

  func testStaysMatchTheTypeScript() throws {
    let (expected, points, _) = try load()
    XCTAssertEqual(points.count, 36_601)
    let got = StayClustering.cluster(points, knownPlaces: expected.knownPlaces)
    XCTAssertEqual(got.stays.count, expected.stays.count)
    for (g, e) in zip(got.stays, expected.stays) {
      XCTAssertEqual(g.placeId, e.placeId)
      XCTAssertEqual(g.startTime, e.startTime)
      XCTAssertEqual(g.endTime, e.endTime)
      XCTAssertEqual(g.durationMinutes, e.durationMinutes)
      XCTAssertEqual(g.pointCount, e.pointCount, "\(e.placeId) at \(e.startTime)")
      XCTAssertEqual(g.centroid.latitude, e.centroid.latitude, accuracy: 1e-9)
      XCTAssertEqual(g.centroid.longitude, e.centroid.longitude, accuracy: 1e-9)
    }
    XCTAssertEqual(got.transit.count, expected.transit.count)
    for (g, e) in zip(got.transit, expected.transit) {
      XCTAssertEqual(g, e)
    }
    // Story 044 on real data: the overnight silences at home are inside Home stays, never "no data" holes
    // between two of them.
    for (a, b) in zip(got.stays, got.stays.dropFirst()) {
      XCTAssertNotEqual(a.placeId, b.placeId, "consecutive stays at one place are merged")
    }
  }

  func testDayCardsMatchTheTypeScript() throws {
    let (expected, points, calendar) = try load()
    let stays = StayClustering.cluster(points, knownPlaces: expected.knownPlaces).stays
    let sorted = points.enumerated().sorted { ($0.element.timestamp, $0.offset) < ($1.element.timestamp, $1.offset) }.map(\.element)
    let days = PlacesDaily.build(stays: stays, points: sorted, days: 14, now: expected.now, calendar: calendar)
    XCTAssertEqual(days.map(\.dateKey), expected.days.map(\.dateKey))
    for (g, e) in zip(days, expected.days) {
      XCTAssertEqual(g.places.map(\.placeId), e.places.map(\.placeId), e.dateKey)
      XCTAssertEqual(g.places.map(\.totalMinutes), e.places.map(\.totalMinutes), e.dateKey)
      XCTAssertEqual(g.visits, e.visits, e.dateKey)
      XCTAssertEqual(
        [g.elapsedMinutes, g.totalStayMinutes, g.transitMinutes, g.noDataMinutes],
        [e.elapsedMinutes, e.totalStayMinutes, e.transitMinutes, e.noDataMinutes], e.dateKey)
      XCTAssertEqual(g.stripSegments.count, e.stripSegments.count, e.dateKey)
      for (gs, es) in zip(g.stripSegments, e.stripSegments) {
        XCTAssertEqual(gs.startOffsetMs, es.startOffsetMs, e.dateKey)
        XCTAssertEqual(gs.endOffsetMs, es.endOffsetMs, e.dateKey)
        XCTAssertEqual(gs.kind.rawValue, es.kind, e.dateKey)
        XCTAssertEqual(gs.placeId, es.placeId, e.dateKey)
      }
      // Within a minute, as in the TypeScript: the stay row is the sum of each place's rounded minutes.
      XCTAssertLessThanOrEqual(abs(g.totalStayMinutes + g.transitMinutes + g.noDataMinutes - g.elapsedMinutes), 1, "every day adds up")
    }
    XCTAssertEqual(PlacesDaily.text(days, calendar: calendar), expected.text)
  }

  /// Story 055: the real export imports in full, and a second import adds nothing.
  func testImportTheRealExportTwice() throws {
    let target = FileManager.default.temporaryDirectory.appendingPathComponent("places-import-\(UUID().uuidString).db")
    defer { try? FileManager.default.removeItem(at: target) }
    let store = try LocationStore(db: SQLiteDatabase(path: target.path))
    let source = fixtures.appendingPathComponent("context-grabber.db").path
    let first = try store.importDatabase(at: source)
    XCTAssertEqual(first, ImportResult(pointsAdded: 36_601, pointsAlreadyHere: 0, placesAdded: 4, placesAlreadyHere: 0))
    let second = try store.importDatabase(at: source)
    XCTAssertEqual(second, ImportResult(pointsAdded: 0, pointsAlreadyHere: 36_601, placesAdded: 0, placesAlreadyHere: 4))
    XCTAssertEqual(try store.count(), 36_601)
    XCTAssertEqual(try store.knownPlaces().map(\.name), ["Home", "Kettlebility", "Milstead & Co", "Work"])
    // The imported trail clusters exactly as the JSON copy of it does.
    let (expected, _, _) = try load()
    let stays = StayClustering.cluster(try store.points(), knownPlaces: expected.knownPlaces).stays
    XCTAssertEqual(stays.map(\.placeId), expected.stays.map(\.placeId))
    XCTAssertEqual(stays.map(\.pointCount), expected.stays.map(\.pointCount))
  }
}
