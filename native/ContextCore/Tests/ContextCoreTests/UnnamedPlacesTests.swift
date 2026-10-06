//  The full-screen map's unnamed places (story 056): which "Place N" are in the period, where each sits, how long,
//  its visits and the radius the naming card suggests — on invented stays and on the real fixture.

import XCTest

@testable import ContextCore

private let pacific: Calendar = {
  var c = Calendar(identifier: .gregorian)
  c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
  return c
}()

private let HOUR = 3_600_000.0

private func stay(_ id: String, _ lat: Double, _ lng: Double, _ start: Double, hours: Double, points: Int = 10) -> Stay {
  Stay(
    placeId: id, centroid: Coordinate(latitude: lat, longitude: lng), startTime: start, endTime: start + hours * HOUR,
    durationMinutes: Int(hours * 60), pointCount: points)
}

final class UnnamedPlacesTests: XCTestCase {
  let t0 = 1_773_849_600_000.0

  func testOnlyUnnamedPlacesInThePeriodLongestFirst() {
    let stays = [
      stay("Home", 47.64, -122.30, t0, hours: 8),
      stay("Place 1", 47.60, -122.33, t0 - 30 * HOUR, hours: 2),  // before the period
      stay("Place 2", 47.61, -122.34, t0 + 9 * HOUR, hours: 1),
      stay("Place 3", 47.62, -122.35, t0 + 11 * HOUR, hours: 3),
      stay("Place 2", 47.61, -122.34, t0 + 20 * HOUR, hours: 1),
    ]
    let got = UnnamedPlaces.summarize(stays, since: t0, until: t0 + 48 * HOUR)
    XCTAssertEqual(got.map(\.placeId), ["Place 3", "Place 2"])
    XCTAssertEqual(got[1].totalMinutes, 120)
    XCTAssertEqual(got[1].visits.count, 2)
    XCTAssertEqual(got[1].visits.map(\.startTime), [t0 + 20 * HOUR, t0 + 9 * HOUR], "newest first")
  }

  func testVisitsAreClippedToThePeriod() {
    let stays = [stay("Place 4", 47.6, -122.3, t0 - 2 * HOUR, hours: 3)]
    let got = UnnamedPlaces.summarize(stays, since: t0, until: t0 + 10 * HOUR)
    XCTAssertEqual(got.first?.totalMinutes, 60)
    XCTAssertEqual(got.first?.visits.first?.startTime, t0)
  }

  func testTiesKeepPlaceNumberOrder() {
    let stays = [
      stay("Place 10", 47.6, -122.3, t0, hours: 1),
      stay("Place 9", 47.7, -122.3, t0 + 2 * HOUR, hours: 1),
    ]
    XCTAssertEqual(UnnamedPlaces.summarize(stays, since: t0, until: t0 + 5 * HOUR).map(\.placeId), ["Place 9", "Place 10"])
  }

  func testCentroidIsWeightedByPointsAndSpreadIsTheFarthestStay() {
    let stays = [
      stay("Place 1", 47.6000, -122.3, t0, hours: 1, points: 30),
      stay("Place 1", 47.6004, -122.3, t0 + 5 * HOUR, hours: 1, points: 10),
    ]
    let place = UnnamedPlaces.summarize(stays, since: t0, until: t0 + 10 * HOUR)[0]
    XCTAssertEqual(place.centroid.latitude, 47.6001, accuracy: 1e-9)
    // 0.0003° of latitude is about 33 m.
    XCTAssertEqual(place.spreadMeters, 33.4, accuracy: 0.5)
    XCTAssertEqual(place.suggestedRadius, 140)
  }

  func testSuggestedRadius() {
    XCTAssertEqual(UnnamedPlaces.suggestedRadius(spread: 0), 100)
    XCTAssertEqual(UnnamedPlaces.suggestedRadius(spread: 9), 110)
    XCTAssertEqual(UnnamedPlaces.suggestedRadius(spread: 10), 110)
    XCTAssertEqual(UnnamedPlaces.suggestedRadius(spread: 400), 250)
  }

  func testDotGrowsWithTimeAndStopsAtAPinsSize() {
    XCTAssertEqual(UnnamedPlaces.dotDiameter(minutes: 0), 10)
    XCTAssertLessThan(UnnamedPlaces.dotDiameter(minutes: 5), UnnamedPlaces.dotDiameter(minutes: 60))
    XCTAssertLessThan(UnnamedPlaces.dotDiameter(minutes: 60), UnnamedPlaces.dotDiameter(minutes: 600))
    XCTAssertEqual(UnnamedPlaces.dotDiameter(minutes: 24 * 60), 26)
    XCTAssertEqual(UnnamedPlaces.dotDiameter(minutes: 72 * 60), 26)
  }

  func testCardText() {
    let start = Geo.ms(pacific.date(from: DateComponents(year: 2026, month: 3, day: 23, hour: 9, minute: 10))!)
    let visit = PlaceVisit(placeId: "Place 3", startTime: start, endTime: start + 2.5 * HOUR, durationMinutes: 150)
    XCTAssertEqual(UnnamedPlaces.visitLine(visit, calendar: pacific), "Mon Mar 23 · 9:10am–11:40am · 2.5h")
    let place = UnnamedPlace(
      placeId: "Place 3", centroid: Coordinate(latitude: 0, longitude: 0), totalMinutes: 390, visits: [visit, visit, visit],
      spreadMeters: 0)
    XCTAssertEqual(UnnamedPlaces.summaryLine(place, days: 7), "6.5h over 3 visits in the last 7 days")
    var one = place
    one.visits = [visit]
    one.totalMinutes = 45
    XCTAssertEqual(UnnamedPlaces.summaryLine(one, days: 7), "45m over 1 visit in the last 7 days")
  }

  /// The real fixture: its unnamed places all come out, each visit's centre within 10 m of its place's, so the
  /// suggestion is the default 100 m or a step over it, and that disc holds the place's points.
  func testTheRealFixture() throws {
    let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let repo = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let points = try JSONDecoder().decode(
      [LocationPoint].self, from: Data(contentsOf: repo.appendingPathComponent("__tests__/fixtures/locations.json")))
    struct Expected: Decodable { let knownPlaces: [KnownPlace] }
    let known = try JSONDecoder().decode(Expected.self, from: Data(contentsOf: here.appendingPathComponent("Fixtures/places-expected.json")))
      .knownPlaces
    let stays = StayClustering.cluster(points, knownPlaces: known).stays
    let all = UnnamedPlaces.summarize(stays, since: -.infinity, until: .infinity)
    XCTAssertEqual(Set(all.map(\.placeId)), Set(stays.map(\.placeId).filter(PlaceStyle.isUnnamed)))
    XCTAssertEqual(all.count, 7)
    var total = 0
    var outside = 0
    for place in all {
      XCTAssertLessThanOrEqual(place.spreadMeters, StayClustering.stayRadius)
      XCTAssertTrue([100, 110].contains(place.suggestedRadius), "\(place.placeId): \(place.suggestedRadius)")
      // The suggested disc holds the place's points: all but 2 of the 2 340 (Place 2's farthest is 111 m out).
      for v in place.visits {
        for p in points where p.timestamp >= v.startTime && p.timestamp <= v.endTime {
          let d = Geo.distance(place.centroid, Coordinate(latitude: p.latitude, longitude: p.longitude))
          total += 1
          if d > place.suggestedRadius { outside += 1 }
        }
      }
    }
    XCTAssertEqual(total, 2_340)
    XCTAssertLessThanOrEqual(outside, 2)
    // The last seven days of the fixture (the period the map shows) still has unnamed places to draw.
    let newest = points.map(\.timestamp).max()!
    let lastWeek = UnnamedPlaces.summarize(stays, since: newest - 7 * Geo.dayMs, until: newest)
    XCTAssertGreaterThanOrEqual(lastWeek.count, 3)
  }
}
