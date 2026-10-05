//  The Places journey's pure logic, translated from the jest suites (geo / location, places, clustering_v2,
//  places_summary), in a pinned time zone because days are local.

import XCTest

@testable import ContextCore

private let pacific: Calendar = {
  var c = Calendar(identifier: .gregorian)
  c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
  return c
}()

/// Local wall-clock time in the pinned zone, as UTC ms.
private func local(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0, _ ms: Int = 0) -> Double {
  Geo.ms(pacific.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s, nanosecond: ms * 1_000_000))!)
}

private let MIN = 60_000.0
private let HOUR = 3_600_000.0

private func pt(_ lat: Double, _ lng: Double, _ t: Double) -> LocationPoint {
  LocationPoint(latitude: lat, longitude: lng, accuracy: 10, timestamp: t)
}

private func stationary(_ lat: Double, _ lng: Double, _ start: Double, _ count: Int, _ interval: Double = 5 * MIN) -> [LocationPoint] {
  (0..<count).map { pt(lat, lng, start + Double($0) * interval) }
}

private let homeLat = 47.6419, homeLng = -122.3045
private let workLat = 47.6289, workLng = -122.3434
private let known = [
  KnownPlace(id: 17, name: "Home", latitude: homeLat, longitude: homeLng, radiusMeters: 100),
  KnownPlace(id: 18, name: "Work", latitude: workLat, longitude: workLng, radiusMeters: 200),
  KnownPlace(id: 13, name: "Kettlebility", latitude: 47.6762, longitude: -122.3187, radiusMeters: 100),
]

final class GeoTests: XCTestCase {
  func testPruneThreshold() {
    let now = 1_773_849_600_000.0
    XCTAssertEqual(now - Geo.pruneThreshold(retentionDays: 30, now: now), 30 * 86_400_000)
    XCTAssertEqual(Geo.pruneThreshold(retentionDays: 0, now: now), now, "0 days prunes everything before now")
    XCTAssertEqual(Geo.pruneThreshold(retentionDays: -3, now: now), now)
    XCTAssertGreaterThan(Geo.pruneThreshold(retentionDays: 7, now: now), Geo.pruneThreshold(retentionDays: 30, now: now))
    XCTAssertEqual(now - Geo.pruneThreshold(retentionDays: 1, now: now), 86_400_000)
  }

  func testHaversine() {
    let fifty = Geo.distance(47.6062, -122.3321, 47.60665, -122.3321)
    XCTAssertLessThan(fifty, 100)
    XCTAssertGreaterThan(fifty, 30)
    XCTAssertGreaterThan(Geo.distance(47.6062, -122.3321, 47.608, -122.3321), 100)
    XCTAssertEqual(Geo.distance(47.6, -122.3, 47.6, -122.3), 0)
  }

  func testJSRoundMatchesMathRound() {
    XCTAssertEqual(jsRound(2.5), 3)
    XCTAssertEqual(jsRound(-2.5), -2)
    XCTAssertEqual(jsRound(2.4999), 2)
    XCTAssertEqual(PlacesDaily.jsNumber(9), "9")
    XCTAssertEqual(PlacesDaily.jsNumber(1.5), "1.5")
  }
}

final class TodaysRouteTests: XCTestCase {
  let noon = local(2026, 5, 31, 12)
  func p(_ off: Double, _ msAgo: Double) -> LocationPoint { pt(47.6 + off, -122.3, noon - msAgo) }

  func testKeepsOnlyTodayInOrder() {
    let route = PlaceStyle.todaysRoute([p(0.02, HOUR), p(0.01, 2 * HOUR), p(0.5, 30 * HOUR)], now: noon, calendar: pacific)
    XCTAssertEqual(route.map(\.timestamp), [noon - 2 * HOUR, noon - HOUR])
    XCTAssertEqual(route[0].latitude, 47.61, accuracy: 1e-6)
    XCTAssertEqual(route[1].latitude, 47.62, accuracy: 1e-6)
  }

  func testDropsNonFiniteAndFuture() {
    let route = PlaceStyle.todaysRoute(
      [LocationPoint(latitude: .nan, longitude: -122.3, timestamp: noon - HOUR), p(0.01, 2 * HOUR), p(0.03, -HOUR)],
      now: noon, calendar: pacific)
    XCTAssertEqual(route.count, 1)
    XCTAssertEqual(route[0].latitude, 47.61, accuracy: 1e-9)
  }

  func testThinsKeepingEnds() {
    let pts = (0..<1000).map { pt(47.6 + Double($0) * 0.0001, -122.3, noon - Double(1000 - $0) * 1000) }
    let route = PlaceStyle.todaysRoute(pts, now: noon, maxPoints: 100, calendar: pacific)
    XCTAssertLessThanOrEqual(route.count, 100)
    XCTAssertEqual(route.first?.timestamp, pts[0].timestamp)
    XCTAssertEqual(route.last?.timestamp, pts[999].timestamp)
  }

  func testOneAndNone() {
    XCTAssertEqual(PlaceStyle.todaysRoute([p(0.01, HOUR)], now: noon, calendar: pacific).count, 1)
    XCTAssertEqual(PlaceStyle.todaysRoute([], now: noon, calendar: pacific), [])
  }

  func testRegionFramesEverything() {
    let r = PlaceStyle.region(
      places: [Coordinate(latitude: 47.60, longitude: -122.40)], you: Coordinate(latitude: 47.70, longitude: -122.30),
      path: [Coordinate(latitude: .nan, longitude: 0)])!
    XCTAssertEqual(r.center.latitude, 47.65, accuracy: 1e-9)
    XCTAssertEqual(r.latitudeDelta, 0.1 * 1.4, accuracy: 1e-9)
    XCTAssertNil(PlaceStyle.region(places: [], you: nil, path: []))
    XCTAssertEqual(PlaceStyle.region(places: [], you: Coordinate(latitude: 1, longitude: 1), path: [])!.latitudeDelta, 0.005 * 1.4, accuracy: 1e-12)
  }
}

final class PlaceStyleTests: XCTestCase {
  func testUnnamedAndColours() {
    XCTAssertTrue(PlaceStyle.isUnnamed("Place 3"))
    XCTAssertFalse(PlaceStyle.isUnnamed("Place"))
    XCTAssertFalse(PlaceStyle.isUnnamed("Placenta 3"))
    XCTAssertFalse(PlaceStyle.isUnnamed("Home"))
    let map = PlaceStyle.colors(for: ["Home", "Place 1", "Work", "Home", "Gym"])
    XCTAssertEqual(map, ["Home": "#4361ee", "Work": "#f72585", "Gym": "#4cc9f0"])
    XCTAssertEqual(PlaceStyle.color("Place 9", in: map), PlaceStyle.unknownPlace)
  }

  func testIcons() {
    XCTAssertEqual(PlaceStyle.icon(for: "Home"), "🏠")
    XCTAssertEqual(PlaceStyle.icon(for: "My office"), "💼")
    XCTAssertEqual(PlaceStyle.icon(for: "Kettlebility gym"), "🏋️")
    XCTAssertEqual(PlaceStyle.icon(for: "Milstead Coffee"), "☕")
    XCTAssertNil(PlaceStyle.icon(for: "Homestead"))
    XCTAssertNil(PlaceStyle.icon(for: "Milstead & Co"))
  }

  func testCoordinateText() {
    XCTAssertEqual(PlaceStyle.coordinateText(Coordinate(latitude: 47.6419012, longitude: -122.30448)), "47.641901, -122.304480")
  }
}

final class KnownPlacesTests: XCTestCase {
  let places = [
    KnownPlace(id: 1, name: "Home", latitude: 47.6062, longitude: -122.3321, radiusMeters: 100),
    KnownPlace(id: 2, name: "Work", latitude: 47.6200, longitude: -122.3500, radiusMeters: 200),
  ]

  func testMatch() {
    XCTAssertNil(KnownPlaces.match(latitude: 0, longitude: 0, in: places))
    XCTAssertNil(KnownPlaces.match(latitude: 47.6062, longitude: -122.3321, in: []))
    let exact = KnownPlaces.match(latitude: 47.6062, longitude: -122.3321, in: places)
    XCTAssertEqual(exact?.index, 0)
    XCTAssertEqual(exact?.distance, 0)
    let near = KnownPlaces.match(latitude: 47.6063, longitude: -122.3321, in: places)
    XCTAssertEqual(near?.index, 0)
    XCTAssertGreaterThan(near!.distance, 0)
    XCTAssertLessThan(near!.distance, 100)
    XCTAssertNil(KnownPlaces.match(latitude: 47.608, longitude: -122.3321, in: places))
    let overlapping = [
      KnownPlace(id: 1, name: "A", latitude: 47.6062, longitude: -122.3321, radiusMeters: 500),
      KnownPlace(id: 2, name: "B", latitude: 47.6065, longitude: -122.3321, radiusMeters: 500),
    ]
    XCTAssertEqual(KnownPlaces.match(latitude: 47.6066, longitude: -122.3321, in: overlapping)?.index, 1, "the closest wins")
  }

  func testLabel() {
    XCTAssertEqual(KnownPlaces.label([pt(47.6062, -122.3321, 1), pt(47.62, -122.35, 2)], with: []), [-1, -1])
    XCTAssertEqual(KnownPlaces.label([pt(47.6062, -122.3321, 1), pt(47.62, -122.35, 2), pt(0, 0, 3)], with: places), [0, 1, -1])
    XCTAssertEqual(
      KnownPlaces.label([pt(47.6062, -122.3321, 1), pt(47.6063, -122.3322, 2), pt(47.6061, -122.3320, 3)], with: places),
      [0, 0, 0])
  }

  // mergePlaceCircle, with the spec's worked examples.
  let center = Coordinate(latitude: 47.6062, longitude: -122.3321)
  func north(_ meters: Double) -> Coordinate {
    Coordinate(latitude: center.latitude + meters / Geo.earthRadiusMeters * 180 / .pi, longitude: center.longitude)
  }

  func testGrowSpecExamples() {
    for (r, d, want) in [(100.0, 110.0, 155.0), (100, 150, 175), (100, 200, 200), (50, 120, 135)] {
      let existing = PlaceCircle(latitude: center.latitude, longitude: center.longitude, radiusMeters: r)
      let point = north(d)
      let grown = KnownPlaces.grow(existing, toInclude: point)
      XCTAssertEqual(grown.radiusMeters, want, accuracy: 2, "r=\(r) d=\(d)")
      XCTAssertEqual(grown.longitude, existing.longitude, accuracy: 1e-10)
      XCTAssertGreaterThan(grown.latitude, existing.latitude)
      XCTAssertLessThan(grown.latitude, point.latitude)
      let toOld = Geo.distance(grown.latitude, grown.longitude, existing.latitude, existing.longitude)
      XCTAssertLessThanOrEqual(Geo.distance(grown.latitude, grown.longitude, point.latitude, point.longitude), grown.radiusMeters)
      XCTAssertLessThanOrEqual(toOld + r, grown.radiusMeters + 0.01, "the old disc is inside the new one")
    }
  }

  func testGrowInsideOrSameIsNoOp() {
    let existing = PlaceCircle(latitude: center.latitude, longitude: center.longitude, radiusMeters: 100)
    XCTAssertEqual(KnownPlaces.grow(existing, toInclude: north(40)), existing)
    XCTAssertEqual(KnownPlaces.grow(existing, toInclude: center), existing)
    let exact = KnownPlaces.grow(existing, toInclude: north(150), buffer: 0)
    XCTAssertEqual(exact.radiusMeters, 125, accuracy: 1)
  }

  /// Story 047's card: a stay 168 m from Milstead & Co (50 m) offers 50 → 159 m and a 57 m shift.
  func testSuggestion() {
    let milstead = KnownPlace(id: 15, name: "Milstead & Co", latitude: 47.6508, longitude: -122.3503, radiusMeters: 50)
    let stay = Coordinate(latitude: 47.6508 + 168 / Geo.earthRadiusMeters * 180 / .pi, longitude: -122.3503)
    let s = KnownPlaces.suggestion(for: stay, among: [milstead, known[0]])!
    XCTAssertEqual(s.nearest.name, "Milstead & Co")
    XCTAssertEqual(s.distance.rounded(), 168)
    XCTAssertEqual(s.grown.radiusMeters.rounded(), 159)
    XCTAssertEqual(s.shift.rounded(), 59)  // (168 − 50) / 2
    XCTAssertEqual(s.others, 0, "Home is kilometres away")
    XCTAssertNil(KnownPlaces.suggestion(for: Coordinate(latitude: 47.70, longitude: -122.35), among: [milstead]))
  }

  func testImportJSON() throws {
    let parsed = try KnownPlaces.parseImportJSON(
      #"{"places":[{"name":" Home ","lat":47.64,"lon":-122.30,"radiusMeters":120},{"name":"","lat":1,"lng":1},{"name":"Bad","latitude":91,"longitude":0},{"name":"Gym","latitude":"47.6","longitude":-122.3}]}"#)
    XCTAssertEqual(parsed.map(\.name), ["Home", "Gym"])
    XCTAssertEqual(parsed[0].radius, 120)
    XCTAssertEqual(parsed[1].radius, 100)
    XCTAssertThrowsError(try KnownPlaces.parseImportJSON(#"{"x":1}"#))
    XCTAssertThrowsError(try KnownPlaces.parseImportJSON("not json"))
  }
}

final class StayClusteringTests: XCTestCase {
  let now = local(2026, 4, 9, 10)

  func testEmpty() {
    XCTAssertEqual(StayClustering.cluster([], knownPlaces: []), StayClusters(stays: [], transit: []))
  }

  func testSinglePointIsNoStay() {
    XCTAssertTrue(StayClustering.cluster([pt(homeLat, homeLng, now)], knownPlaces: known).stays.isEmpty)
  }

  func testTwoPointsSixMinutesApart() {
    let r = StayClustering.cluster([pt(homeLat, homeLng, now), pt(homeLat + 0.0001, homeLng, now + 6 * MIN)], knownPlaces: known)
    XCTAssertEqual(r.stays.count, 1)
    XCTAssertEqual(r.stays[0].placeId, "Home")
    XCTAssertEqual(r.stays[0].pointCount, 2)
  }

  func testStationaryIsOneStay() {
    let r = StayClustering.cluster(stationary(homeLat, homeLng, now, 10, 10 * MIN), knownPlaces: known)
    XCTAssertEqual(r.stays.count, 1)
    XCTAssertEqual(r.stays[0].durationMinutes, 90)
    XCTAssertEqual(r.stays[0].pointCount, 10)
  }

  func testTwoPlacesAndTransit() {
    let r = StayClustering.cluster(
      stationary(homeLat, homeLng, now, 7, 10 * MIN) + stationary(workLat, workLng, now + 90 * MIN, 7, 10 * MIN),
      knownPlaces: known)
    XCTAssertEqual(r.stays.map(\.placeId), ["Home", "Work"])
    XCTAssertEqual(r.transit.count, 1)
    XCTAssertEqual(r.transit[0].fromPlaceId, "Home")
    XCTAssertEqual(r.transit[0].toPlaceId, "Work")
    XCTAssertEqual(r.transit[0].durationMinutes, 30)
    XCTAssertGreaterThan(r.transit[0].distanceKm, 0)
  }

  /// Story 044: a silent night at home is one stay.
  func testLongGapSamePlaceContinues() {
    let r = StayClustering.cluster(
      stationary(homeLat, homeLng, now, 3, 10 * MIN) + stationary(homeLat, homeLng, now + 8 * HOUR, 3, 10 * MIN),
      knownPlaces: known)
    XCTAssertEqual(r.stays.count, 1)
    XCTAssertEqual(r.stays[0].pointCount, 6)
    XCTAssertGreaterThan(r.stays[0].durationMinutes, 480)
  }

  func testLongGapWithMoveSplits() {
    let r = StayClustering.cluster(
      stationary(homeLat, homeLng, now, 3, 10 * MIN) + stationary(homeLat + 500 / 111_000, homeLng, now + 5 * HOUR, 3, 10 * MIN),
      knownPlaces: known)
    XCTAssertEqual(r.stays.count, 2)
    XCTAssertEqual(r.stays[0].placeId, "Home")
    XCTAssertNotEqual(r.stays[1].placeId, "Home")
  }

  func testShortVisitDropped() {
    let r = StayClustering.cluster(
      [pt(homeLat, homeLng, now), pt(homeLat, homeLng, now + 2 * MIN)] + stationary(workLat, workLng, now + 30 * MIN, 3),
      knownPlaces: known)
    XCTAssertEqual(r.stays.map(\.placeId), ["Work"])
  }

  func testBriefDepartureMerges() {
    let r = StayClustering.cluster(
      stationary(homeLat, homeLng, now, 4, 10 * MIN) + stationary(homeLat, homeLng, now + 45 * MIN, 4, 10 * MIN),
      knownPlaces: known)
    XCTAssertEqual(r.stays.count, 1)
    XCTAssertEqual(r.stays[0].pointCount, 8)
  }

  /// Story 043: "Place N" is stable across days.
  func testSameUnknownPlaceSameIdAcrossDays() {
    let day1 = local(2026, 3, 25, 10), day2 = local(2026, 3, 26, 10)
    let r = StayClustering.cluster(
      stationary(47.70, -122.35, day1, 5, 10 * MIN) + stationary(47.75, -122.40, day1 + 2 * HOUR, 5, 10 * MIN)
        + stationary(47.70, -122.35, day2, 5, 10 * MIN),
      knownPlaces: known)
    let target = r.stays.filter { abs($0.centroid.latitude - 47.70) + abs($0.centroid.longitude + 122.35) < 0.01 }
    XCTAssertGreaterThanOrEqual(target.count, 2)
    XCTAssertEqual(target[0].placeId, target[1].placeId)
    XCTAssertTrue(PlaceStyle.isUnnamed(target[0].placeId))
  }

  // Step 5 on its own.
  let t0 = local(2026, 4, 9, 20)
  func stay(_ id: String, _ start: Double, _ minutes: Int, _ count: Int = 5, lat: Double = homeLat, lng: Double = homeLng) -> Stay {
    Stay(placeId: id, centroid: Coordinate(latitude: lat, longitude: lng), startTime: start, endTime: start + Double(minutes) * MIN,
      durationMinutes: minutes, pointCount: count)
  }

  func testMergeConsecutive() {
    XCTAssertEqual(StayClustering.mergeConsecutiveSamePlace([]), [])
    let night = [stay("Home", t0, 120, 10), stay("Home", t0 + 11 * HOUR, 15, 3)]
    let merged = StayClustering.mergeConsecutiveSamePlace(night)
    XCTAssertEqual(merged.count, 1)
    XCTAssertEqual(merged[0].startTime, night[0].startTime)
    XCTAssertEqual(merged[0].endTime, night[1].endTime)
    XCTAssertEqual(merged[0].pointCount, 13)
    XCTAssertEqual(merged[0].centroid.latitude, homeLat, accuracy: 1e-5)
    XCTAssertEqual(merged[0].durationMinutes, Int(((night[1].endTime - night[0].startTime) / 60000).rounded()))

    XCTAssertEqual(
      StayClustering.mergeConsecutiveSamePlace([stay("Home", t0, 120), stay("Bar", t0 + 3 * HOUR, 60), stay("Home", t0 + 5 * HOUR, 120)])
        .map(\.placeId), ["Home", "Bar", "Home"])
    XCTAssertEqual(StayClustering.mergeConsecutiveSamePlace([stay("Home", t0, 120), stay("Work", t0 + 12 * HOUR, 480)]).count, 2)
    let three = StayClustering.mergeConsecutiveSamePlace([stay("Home", t0, 60), stay("Home", t0 + 24 * HOUR, 60), stay("Home", t0 + 48 * HOUR, 60)])
    XCTAssertEqual(three.count, 1)
    XCTAssertEqual(three[0].pointCount, 15)
    let work = StayClustering.mergeConsecutiveSamePlace([stay("Work", t0, 300), stay("Work", t0 + 9 * HOUR, 30)])
    XCTAssertEqual(work[0].endTime - work[0].startTime, 9 * HOUR + 30 * MIN)
    let weighted = StayClustering.mergeConsecutiveSamePlace([
      stay("Place 1", t0, 60, 9, lat: 47.6, lng: -122.3), stay("Place 1", t0 + 5 * HOUR, 60, 1, lat: 47.7, lng: -122.4),
    ])
    XCTAssertEqual(weighted[0].centroid.latitude, (47.6 * 9 + 47.7) / 10, accuracy: 1e-4)
    XCTAssertEqual(weighted[0].centroid.longitude, (-122.3 * 9 + -122.4) / 10, accuracy: 1e-4)
    XCTAssertEqual(weighted[0].pointCount, 10)
  }
}

final class PlacesDailyTests: XCTestCase {
  func stay(_ id: String, _ start: Double, _ minutes: Double) -> Stay {
    Stay(placeId: id, centroid: Coordinate(latitude: 47.6, longitude: -122.3), startTime: start, endTime: start + minutes * MIN,
      durationMinutes: Int(minutes), pointCount: 10)
  }
  func point(_ t: Double) -> LocationPoint { LocationPoint(latitude: 47.6, longitude: -122.3, accuracy: 20, timestamp: t) }
  func build(_ stays: [Stay], _ points: [LocationPoint], _ days: Int, _ now: Double) -> [PlaceDaySummary] {
    PlacesDaily.build(stays: stays, points: points, days: days, now: now, calendar: pacific)
  }
  let mar15 = local(2026, 3, 15), mar14 = local(2026, 3, 14)
  let noon15 = local(2026, 3, 15, 12), endOf15 = local(2026, 3, 15, 23, 59, 59, 999)

  func testEmpty() { XCTAssertEqual(build([], [], 7, noon15), []) }

  func testPlacesSortedByTime() {
    let base = mar15 + 8 * 60 * MIN
    let d = build([stay("Home", base, 120), stay("Office", base + 180 * MIN, 60), stay("Cafe", base + 300 * MIN, 180)], [], 7, endOf15)
      .first { $0.dateKey == "2026-03-15" }!
    XCTAssertEqual(d.places.map(\.placeId), ["Cafe", "Home", "Office"])
    XCTAssertEqual(d.places.map(\.totalMinutes), [180, 120, 60])
    XCTAssertEqual(d.totalStayMinutes, 360)
  }

  func testElapsed() {
    XCTAssertEqual(build([stay("Home", mar14 + 60 * MIN, 60)], [], 7, noon15).first { $0.dateKey == "2026-03-14" }!.elapsedMinutes, 1440)
    XCTAssertEqual(build([stay("Home", mar15, 60)], [], 1, mar15 + 360 * MIN)[0].elapsedMinutes, 360)
  }

  func testDaysNewestFirstAndLimited() {
    let keys = build(
      [stay("Home", local(2026, 3, 13, 1), 60), stay("Home", local(2026, 3, 15, 1), 90), stay("Home", local(2026, 3, 14, 1), 120)], [], 7,
      noon15
    ).map(\.dateKey)
    XCTAssertEqual(keys.first, "2026-03-15")
    XCTAssertTrue(keys.contains("2026-03-14") && keys.contains("2026-03-13"))
    let limited = build((10...14).map { stay("Home", local(2026, 3, $0, 1), 60) }, [], 3, local(2026, 3, 14, 12)).map(\.dateKey)
    XCTAssertEqual(limited, ["2026-03-14", "2026-03-13", "2026-03-12"])
  }

  func testTopTenAndSums() {
    let base = mar15 + 60 * MIN
    let many = (0..<15).map { stay("Place \($0)", base + Double($0) * 10 * MIN, Double(15 - $0) * 10) }
    XCTAssertEqual(build(many, [], 7, noon15)[0].places.count, 10)
    let d = build([stay("Home", base, 60), stay("Office", base + 120 * MIN, 30), stay("Home", base + 180 * MIN, 90)], [], 7, noon15)[0]
    XCTAssertEqual(d.places.map(\.placeId), ["Home", "Office"])
    XCTAssertEqual(d.places.map(\.totalMinutes), [150, 30])
  }

  func testNoPointsMeansNoData() {
    let d = build([stay("Home", mar15 + 600 * MIN, 120)], [], 1, mar15 + 18 * 60 * MIN)[0]
    XCTAssertEqual(d.totalStayMinutes, 120)
    XCTAssertEqual(d.transitMinutes, 0)
    XCTAssertEqual(d.noDataMinutes, 960)
    XCTAssertEqual(d.totalStayMinutes + d.transitMinutes + d.noDataMinutes, d.elapsedMinutes)
  }

  func testStayAcrossMidnightSplits() {
    let s = Stay(placeId: "Home", centroid: Coordinate(latitude: 47.6, longitude: -122.3), startTime: mar14 + 22 * HOUR,
      endTime: mar15 + 8 * HOUR, durationMinutes: 600, pointCount: 20)
    let r = build([s], [], 2, noon15)
    XCTAssertEqual(r.first { $0.dateKey == "2026-03-14" }!.totalStayMinutes, 120)
    XCTAssertEqual(r.first { $0.dateKey == "2026-03-15" }!.totalStayMinutes, 480)
  }

  func testOvernightSilenceIsNoDataNotTransit() {
    let d = build([stay("Home", mar15, 60), stay("Coffee", mar15 + 9 * HOUR, 30)], [], 1, mar15 + 10 * HOUR)[0]
    XCTAssertEqual(d.totalStayMinutes, 90)
    XCTAssertEqual(d.transitMinutes, 0)
    XCTAssertEqual(d.noDataMinutes, d.elapsedMinutes - 90)
  }

  func testDriveWithGPSIsTransit() {
    let pts = stride(from: 60.0, through: 120, by: 5).map { point(mar15 + $0 * MIN) }
    let d = build([stay("Home", mar15, 60), stay("Work", mar15 + 2 * HOUR, 60)], pts, 1, mar15 + 4 * HOUR)[0]
    XCTAssertEqual(d.totalStayMinutes, 120)
    XCTAssertTrue((58...62).contains(d.transitMinutes))
  }

  func testStrayPointIsTenMinutes() {
    let d = build([stay("A", mar15, 60), stay("B", mar15 + 3 * HOUR, 60)], [point(mar15 + 2 * HOUR)], 1, mar15 + 5 * HOUR)[0]
    XCTAssertTrue((8...12).contains(d.transitMinutes))
    XCTAssertGreaterThanOrEqual(d.noDataMinutes, 108)
  }

  func testTodayTruncatedAndInvariant() {
    let d = build([stay("Home", mar15, 120)], [], 1, mar15 + 6 * HOUR)[0]
    XCTAssertEqual(d.elapsedMinutes, 360)
    XCTAssertEqual(d.noDataMinutes, 240)
    let pts = (0..<20).map { point(mar15 + 90 * 60 * MIN + Double($0) * 7 * MIN) }
    let e = build([stay("Home", mar15 + 17_000, 37), stay("Work", mar15 + 23_400_000, 143)], pts, 1, endOf15)[0]
    XCTAssertLessThanOrEqual(abs(e.totalStayMinutes + e.transitMinutes + e.noDataMinutes - e.elapsedMinutes), 1)
  }

  func testOnlyPoints() {
    let pts = (0..<5).map { point(mar15 + 60 * MIN + Double($0) * 3 * MIN) }
    let r = build([], pts, 1, mar15 + 4 * HOUR)
    XCTAssertEqual(r.count, 1)
    XCTAssertEqual(r[0].totalStayMinutes, 0)
    XCTAssertTrue((20...24).contains(r[0].transitMinutes))
  }

  func assertTiles(_ d: PlaceDaySummary, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(d.stripSegments.first?.startOffsetMs, 0, file: file, line: line)
    XCTAssertEqual(d.stripSegments.last?.endOffsetMs, d.dayLengthMs, file: file, line: line)
    for i in 1..<d.stripSegments.count {
      XCTAssertEqual(d.stripSegments[i].startOffsetMs, d.stripSegments[i - 1].endOffsetMs, file: file, line: line)
    }
  }

  func testStripPastDay() {
    let d = build([stay("Home", mar14 + 8 * HOUR, 60)], [], 2, noon15).first { $0.dateKey == "2026-03-14" }!
    assertTiles(d)
    XCTAssertEqual(d.dayLengthMs, 86_400_000)
    XCTAssertFalse(d.stripSegments.contains { $0.kind == .future })
    XCTAssertEqual(d.stripSegments.first { $0.kind == .stay }?.placeId, "Home")
  }

  func testStripToday() {
    let d = build([stay("Home", mar15, 60)], [], 1, mar15 + 6 * HOUR)[0]
    assertTiles(d)
    XCTAssertEqual(d.stripSegments.last?.kind, .future)
    XCTAssertEqual(d.stripSegments.last?.startOffsetMs, 6 * HOUR)
  }

  func testStripKinds() {
    let pts = (0...4).map { point(mar15 + 120 * MIN + Double($0) * 5 * MIN) }
    let d = build([stay("Home", mar15, 60)], pts, 1, endOf15)[0]
    XCTAssertEqual(Set(d.stripSegments.map(\.kind)), [.stay, .transit, .noData, .future])
    let e = build([], [point(mar15 + HOUR)], 1, mar15 + 4 * HOUR)[0]
    assertTiles(e)
    XCTAssertEqual(e.stripSegments.last?.kind, .future)
  }

  /// The one departure from the TypeScript: the day the clocks go forward is 23 hours long.
  func testSpringForwardDayIs23Hours() {
    let d = build([stay("Home", local(2026, 3, 8, 1), 60)], [], 2, local(2026, 3, 9, 12)).first { $0.dateKey == "2026-03-08" }!
    XCTAssertEqual(d.elapsedMinutes, 23 * 60)
    XCTAssertEqual(d.dayLengthMs, 23 * HOUR)
    XCTAssertEqual(d.totalStayMinutes + d.transitMinutes + d.noDataMinutes, d.elapsedMinutes)
    assertTiles(d)
  }

  func testSegmentNonStay() {
    let none = PlacesDaily.segmentNonStay(start: 0, end: 60 * MIN, points: [])
    XCTAssertEqual(none.map(\.kind), [.noData])
    let one = PlacesDaily.segmentNonStay(start: 0, end: 60 * MIN, points: [point(30 * MIN)])
    XCTAssertEqual(one.map(\.kind), [.noData, .transit, .noData])
    XCTAssertEqual(one[0].end, one[1].start)
    XCTAssertEqual(one[2].end, 60 * MIN)
    let early = PlacesDaily.segmentNonStay(start: 0, end: 60 * MIN, points: [point(2 * MIN)])
    XCTAssertEqual(early[0].start, 0)
    XCTAssertEqual(early[0].end, 7 * MIN)
    XCTAssertEqual(early[0].kind, .transit)
    XCTAssertEqual(early[1].kind, .noData)
  }

  func testSplitNonStay() {
    let all = [(start: 0.0, end: 60 * MIN)]
    XCTAssertEqual(PlacesDaily.splitNonStay(all, []).transitMs, 0)
    XCTAssertEqual(PlacesDaily.splitNonStay(all, []).noDataMs, 60 * MIN)
    XCTAssertEqual(PlacesDaily.splitNonStay(all, [point(30 * MIN)]).transitMs, 10 * MIN)
    XCTAssertEqual(PlacesDaily.splitNonStay(all, [point(20 * MIN), point(28 * MIN), point(35 * MIN)]).transitMs, 25 * MIN)
    XCTAssertEqual(PlacesDaily.splitNonStay(all, [point(10 * MIN), point(30 * MIN)]).transitMs, 20 * MIN)
    XCTAssertEqual(PlacesDaily.splitNonStay(all, [point(2 * MIN)]).transitMs, 7 * MIN)
  }

  func testText() {
    func day(_ key: String, _ totals: [(String, Int)]) -> PlaceDaySummary {
      PlaceDaySummary(
        dateKey: key, places: totals.map { .init(placeId: $0.0, totalMinutes: $0.1) }, visits: [], elapsedMinutes: 1440,
        totalStayMinutes: 0, transitMinutes: 0, noDataMinutes: 0, stripSegments: [], dayLengthMs: 86_400_000)
    }
    XCTAssertEqual(PlacesDaily.text([day("2026-04-20", [("Home", 540), ("Office", 480), ("Gym", 60)])], calendar: pacific),
      "Mon Apr 20: Home 9h, Office 8h, Gym 1h")
    XCTAssertEqual(PlacesDaily.text([day("2026-04-21", [("Home", 600)]), day("2026-04-20", [("Office", 480)])], calendar: pacific),
      "Tue Apr 21: Home 10h\nMon Apr 20: Office 8h")
    XCTAssertEqual(PlacesDaily.text([day("2026-04-20", [("Home", 90), ("Cafe", 45)])], calendar: pacific), "Mon Apr 20: Home 1.5h, Cafe 45m")
    XCTAssertEqual(PlacesDaily.text([day("2026-04-20", [])], calendar: pacific), "Mon Apr 20: no known places")
  }
}
