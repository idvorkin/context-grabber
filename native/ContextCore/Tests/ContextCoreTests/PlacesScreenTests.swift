//  The Places screen's choices on real SQLite (a temp file) and, where geometry matters, the real export: the Today ·
//  7 days switch and its remembered setting (story 049, #252), retention (041), the naming card (047, 056), and the
//  line under the map with the failure it can hold (059, #798). Who wins is in the Places spec ("Who wins"). These
//  replace PlacesRangeUITests and PlacesProblemUITests, which took two launches and an import on the simulator.

import XCTest

@testable import ContextCore

private let fixture = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  .deletingLastPathComponent().appendingPathComponent("__tests__/fixtures/context-grabber.db")

private final class Lines {
  var all: [(type: String, fields: [String: Any])] = []
  func of(_ type: String) -> [[String: Any]] { all.filter { $0.type == type }.map(\.fields) }
}

final class PlacesScreenTests: XCTestCase {
  /// Per test: XCTest makes a new instance for each one.
  private let dir = FileManager.default.temporaryDirectory.appendingPathComponent("places-screen-\(UUID().uuidString)")
  private var opened: SQLiteDatabase?
  private let lines = Lines()
  private let now = Date()

  override func tearDownWithError() throws {
    opened = nil
    try? FileManager.default.removeItem(at: dir)
  }

  /// This test's database, a file (ATTACH and VACUUM INTO need one), opened once.
  private func db() throws -> SQLiteDatabase {
    if let opened { return opened }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let db = try SQLiteDatabase(path: dir.appendingPathComponent("app.db").path)
    opened = db
    return db
  }

  /// A file that is not a database, as the old UI test used /etc/hosts.
  private func notADatabase() throws -> URL {
    _ = try db()
    let file = dir.appendingPathComponent("hosts")
    try Data("127.0.0.1 localhost\n".utf8).write(to: file)
    return file
  }

  /// The screen as the app makes it, on this test's database; a second call is the next launch.
  private func screen(archiveSends: Bool = false) throws -> PlacesScreen {
    let lines = self.lines
    let now = self.now
    return PlacesScreen(
      store: try LocationStore(db: db()), settings: try SettingsStore(db: db()),
      cursors: try ArchiveCursorStore(db: db()),
      archiveSends: archiveSends, log: { lines.all.append(($0, $1)) }, clock: { now },
      exportDirectory: dir.appendingPathComponent("export"))
  }

  /// The read the app runs off the main thread, here at once.
  private func read(_ s: inout PlacesScreen, reason: String = "test") throws {
    let read = try XCTUnwrap(s.startRead(reason: reason), "the trail reads")
    XCTAssertTrue(s.show(PlacesShown.build(read, now: Geo.ms(now)), for: read))
  }

  /// The real export, moved into the last day as the simulator's hook does, then read.
  private func withTheRealExport() throws -> PlacesScreen {
    var s = try screen()
    let next = s.importDatabase(fixture, from: "hook", recent: true)
    XCTAssertEqual(next, PlacesReread(reason: "import"), "\(String(describing: s.problem))")
    try read(&s)
    return s
  }

  private func points(daysOld ages: Range<Int>) -> [LocationPoint] {
    ages.map {
      LocationPoint(latitude: 47.6, longitude: -122.3, accuracy: 5, timestamp: Geo.ms(now) - Double($0) * Geo.dayMs - 1)
    }
  }

  // MARK: - the Today · 7 days switch (story 049, #252)

  func testTheRangeStartsOnTodayWithNothingRemembered() throws {
    XCTAssertEqual(try screen().routeDays, 1)
  }

  func testSevenDaysIsRememberedAtTheNextLaunchAndSoIsTodayAgain() throws {
    var s = try screen()
    s.setRouteDays(7)
    XCTAssertEqual(s.routeDays, 7)
    var next = try screen()
    XCTAssertEqual(next.routeDays, 7, "remembered after a relaunch")
    next.setRouteDays(1)
    XCTAssertEqual(try screen().routeDays, 1, "and back to today, remembered too")
  }

  func testARememberedValueItDoesNotKnowOpensOnToday() throws {
    let settings = try SettingsStore(db: db())
    for value in ["14", "", "seven", "7 "] {
      try settings.set(PlacesScreen.routeDaysKey, value)
      XCTAssertEqual(try screen().routeDays, 1, "'\(value)'")
    }
  }

  func testTappingTheRangeAlreadyChosenDoesNothingAndLogsNothing() throws {
    var s = try screen()
    s.setRouteDays(1)
    XCTAssertTrue(lines.of("ui").isEmpty)
    s.setRouteDays(7)
    s.setRouteDays(7)
    XCTAssertEqual(lines.of("ui").count, 1)
    XCTAssertEqual(lines.of("ui").first?["action"] as? String, "map_range")
    XCTAssertEqual(lines.of("ui").first?["days"] as? Int, 7)
  }

  func testARangeThatCannotBeSavedStillMovesAndTheLogSaysWhy() throws {
    var s = try screen()
    try db().execute("DROP TABLE settings")
    s.setRouteDays(7)
    XCTAssertEqual(s.routeDays, 7, "the switch moves for this visit")
    XCTAssertEqual(lines.of("error").first?["where"] as? String, "settings")
    XCTAssertEqual(lines.of("error").first?["key"] as? String, PlacesScreen.routeDaysKey)
  }

  /// On the real export: Today draws today's path, 7 days the week's (thinned to 1,200), and the switch logs how many
  /// points it now draws. The day cards do not change with it.
  func testTheRealExportsPathFollowsTheRange() throws {
    var s = try withTheRealExport()
    let days = s.days
    XCTAssertEqual(s.shownRoute, s.route)
    s.setRouteDays(7)
    XCTAssertEqual(s.shownRoute, s.weekRoute)
    XCTAssertGreaterThan(s.weekRoute.count, s.route.count)
    XCTAssertLessThanOrEqual(s.weekRoute.count, 1200)
    XCTAssertEqual(lines.of("ui").last?["points"] as? Int, s.weekRoute.count)
    XCTAssertEqual(s.days, days, "the day cards stay as they were")
  }

  /// Who wins: an import (the launch hook's included) never picks the range; the remembered one stands.
  func testAnImportLeavesTheRememberedRangeAlone() throws {
    var s = try screen()
    s.setRouteDays(7)
    var next = try screen()
    _ = next.importDatabase(fixture, from: "hook", recent: true)
    try read(&next, reason: "import")
    XCTAssertEqual(next.routeDays, 7)
    XCTAssertEqual(try screen().routeDays, 7)
  }

  // MARK: - retention (story 041)

  func testRetentionIsKeptFrom1To365AndLoweringItPrunesAtOnce() throws {
    let store = try LocationStore(db: db())
    try store.insert(points(daysOld: 0..<40))
    var s = try screen()
    XCTAssertNil(s.setRetention(500, from: "stepper"), "raising deletes nothing")
    XCTAssertEqual(s.retentionDays, 365)
    XCTAssertEqual(try store.count(), 40)
    XCTAssertNil(s.setRetention(365, from: "stepper"), "the same number does nothing")
    XCTAssertEqual(s.setRetention(0, from: "stepper"), PlacesReread(reason: "retention"))
    XCTAssertEqual(s.retentionDays, 1)
    XCTAssertEqual(try store.retentionDays(), 1)
    XCTAssertEqual(try store.count(), 1)
    XCTAssertEqual(lines.of("prune").last?["reason"] as? String, "lowered")
    XCTAssertEqual(lines.of("prune").last?["removed"] as? Int, 39)
  }

  /// With an archive, the prune keeps what it has not taken, however old.
  func testLoweringRetentionKeepsWhatTheArchiveHasNotTaken() throws {
    let store = try LocationStore(db: db())
    try store.insert(points(daysOld: 0..<40))
    var s = try screen(archiveSends: true)
    _ = s.setRetention(7, from: "hook")
    XCTAssertEqual(try store.count(), 40)
    XCTAssertEqual(lines.of("prune").last?["unarchived_kept"] as? Int, 33)
  }

  // MARK: - the naming card (stories 047, 056)

  /// On the real export: naming a grey dot far from every known place opens the name card with the suggested radius;
  /// saving it closes the card, re-reads, the dot is gone and its card closes by itself. The highest-numbered such
  /// place, so its number goes too: naming a lower one renumbers the next into its id and the card stays open on the
  /// other place (found here, filed as a GitHub issue; this change keeps behaviour as it is).
  func testNamingAGreyDotOnTheRealExport() throws {
    var s = try withTheRealExport()
    let number = { (place: UnnamedPlace) in Int(place.placeId.dropFirst("Place ".count)) ?? 0 }
    let far = try XCTUnwrap(
      s.unnamed.filter { place in s.knownPlaces.allSatisfy { Geo.distance($0.coordinate, place.centroid) > 500 } }
        .max { number($0) < number($1) },
      "the real export has an unnamed place far from its four known places")
    s.selectUnnamed(far.placeId, from: "tap")
    s.startNaming(far)
    XCTAssertEqual(s.naming, .name(source: far.placeId, centroid: far.centroid, radius: far.suggestedRadius))
    XCTAssertTrue([100, 110].contains(far.suggestedRadius), "the spec's real-data radius: \(far.suggestedRadius)")
    let next = s.addPlace(
      name: "Park", latitude: far.centroid.latitude, longitude: far.centroid.longitude, radius: far.suggestedRadius,
      from: "name_place")
    XCTAssertEqual(next, PlacesReread(reason: "add_place"))
    XCTAssertNil(s.naming)
    XCTAssertEqual(s.note, "Added Park.")
    try read(&s, reason: "add_place")
    XCTAssertFalse(s.unnamed.contains { $0.placeId == far.placeId }, "its number is gone")
    XCTAssertFalse(
      s.unnamed.contains { Geo.distance($0.centroid, far.centroid) < 100 }, "the grey dot became a named place")
    XCTAssertNil(s.selectedUnnamed, "its card closed by itself")
    XCTAssertTrue(s.stays.contains { $0.placeId == "Park" })
  }

  /// On the real export: a stay within 500 m of a known place offers to grow it first; *Create new* turns that into
  /// the name card at the same place and radius, and nothing turns a name card back.
  func testNearAKnownPlaceTheOfferToGrowItComesFirst() throws {
    var s = try withTheRealExport()
    let near = try XCTUnwrap(
      s.days.lazy.flatMap { day in day.visits.map { (day, $0) } }.first { _, visit in
        guard PlaceStyle.isUnnamed(visit.placeId),
          let stay = s.stays.first(where: { $0.placeId == visit.placeId })
        else { return false }
        return KnownPlaces.suggestion(for: stay.centroid, among: s.knownPlaces) != nil
      }, "the real export has an unnamed stay within 500 m of a known place (Place 2, by Milstead & Co)")
    s.startNaming(near.1.placeId, on: near.0)
    guard case .merge(let source, let centroid, let radius, let suggestion)? = s.naming else {
      return XCTFail("the merge card: \(String(describing: s.naming))")
    }
    XCTAssertEqual(source, near.1.placeId)
    XCTAssertEqual(radius, 100, "a day card's ＋ names with 100 m")
    XCTAssertLessThanOrEqual(suggestion.distance, 500)
    let card = try XCTUnwrap(s.naming)
    s.createNew(from: card)
    XCTAssertEqual(s.naming, .name(source: source, centroid: centroid, radius: radius))
    let nameCard = try XCTUnwrap(s.naming)
    s.createNew(from: nameCard)
    XCTAssertEqual(s.naming, nameCard, "a name card stays a name card")
    XCTAssertEqual(lines.of("ui").last?["offer"] as? String, "expand")
  }

  func testExpandGrowsThePlaceClosesTheCardAndRereads() throws {
    let store = try LocationStore(db: db())
    try store.addKnownPlace(name: "Cafe", latitude: 47.6, longitude: -122.3, radiusMeters: 50)
    var s = try screen()
    try read(&s)
    let stayAt = Coordinate(latitude: 47.6015, longitude: -122.3)  // ~167 m north
    let suggestion = try XCTUnwrap(KnownPlaces.suggestion(for: stayAt, among: s.knownPlaces))
    s.naming = .merge(source: "Place 1", centroid: stayAt, radius: 100, suggestion: suggestion)
    XCTAssertEqual(s.expand(suggestion, source: "Place 1"), PlacesReread(reason: "expand"))
    XCTAssertNil(s.naming)
    XCTAssertEqual(try store.knownPlaces().first?.radiusMeters, suggestion.grown.radiusMeters)
  }

  func testAddPlaceRefusesABlankNameOrAPositionOffTheGlobeWithAPlainLine() throws {
    var s = try screen()
    s.naming = .name(source: "Place 1", centroid: Coordinate(latitude: 1, longitude: 2), radius: 100)
    XCTAssertNil(s.addPlace(name: "  \n", latitude: 1, longitude: 2, radius: nil, from: "form"))
    XCTAssertEqual(s.note, "A place needs a name.")
    let offTheGlobe: [(Double?, Double?)] = [(91, 0), (0, -181), (nil, 0)]
    for (lat, lng) in offTheGlobe {
      XCTAssertNil(s.addPlace(name: "X", latitude: lat, longitude: lng, radius: nil, from: "form"))
      XCTAssertEqual(s.note, "A place needs a latitude from -90 to 90 and a longitude from -180 to 180.")
    }
    XCTAssertNil(s.problem, "a hint about the input, not a failure")
    XCTAssertNotNil(s.naming, "the card stays open")
    XCTAssertTrue(try LocationStore(db: db()).knownPlaces().isEmpty)
  }

  func testARadiusLeftBlankZeroOrNegativeIs100Metres() throws {
    var s = try screen()
    let radii: [Double?] = [nil, 0, -5, 42]
    for (i, radius) in radii.enumerated() {
      XCTAssertNotNil(s.addPlace(name: "P\(i)", latitude: 47, longitude: -122, radius: radius, from: "form"))
    }
    XCTAssertEqual(try LocationStore(db: db()).knownPlaces().map(\.radiusMeters), [100, 100, 100, 42])
  }

  func testAFailedSaveKeepsTheCardOpenWithTheFailure() throws {
    var s = try screen()
    s.naming = .name(source: "Place 1", centroid: Coordinate(latitude: 1, longitude: 2), radius: 100)
    try db().execute("DROP TABLE known_places")
    XCTAssertNil(s.addPlace(name: "Home", latitude: 1, longitude: 2, radius: 100, from: "name_place"))
    XCTAssertNotNil(s.naming)
    XCTAssertEqual(s.problem?.context, "Places.add_place")
    XCTAssertEqual(s.problem?.message.hasPrefix("Could not add place: "), true)
    XCTAssertEqual(lines.of("error").last?["where"] as? String, "add_place")
  }

  /// Starting a naming takes the last failure away.
  func testStartingANamingTakesTheLastFailureAway() throws {
    var s = try withTheRealExport()
    _ = try s.importDatabase(notADatabase(), from: "picker")
    XCTAssertNotNil(s.problem)
    let place = try XCTUnwrap(s.unnamed.first)
    s.startNaming(place)
    XCTAssertNil(s.problem)
  }

  // MARK: - the line under the map and its failure (story 059, #798)

  func testARefusedImportIsACopyableFailureAndChangesNothing() throws {
    var s = try screen()
    XCTAssertNil(try s.importDatabase(notADatabase(), from: "picker", recent: true))
    let problem = try XCTUnwrap(s.problem)
    XCTAssertTrue(problem.message.hasPrefix("Import refused"), problem.message)
    XCTAssertEqual(problem.context, "Places.import")
    XCTAssertEqual(problem.extra["file"], .string("hosts"))
    XCTAssertEqual(problem.extra["from"], .string("picker"))
    XCTAssertEqual(problem.extra["recent"], .bool(true))
    XCTAssertEqual(problem.extra["points"], .int(0))
    XCTAssertEqual(problem.extra["known_places"], .int(0))
    XCTAssertNotNil(problem.extra["error"])
    XCTAssertEqual(s.note, "", "the failure, not a plain line")
    XCTAssertEqual(try LocationStore(db: db()).count(), 0)
    XCTAssertEqual(lines.of("import").last?["ok"] as? Bool, false)
  }

  /// Who wins: a good import after a refused one ends with the good one's line; a refusal after a good one ends with
  /// the refusal. A second import of the same file adds nothing.
  func testTheLatestImportWins() throws {
    var s = try screen()
    _ = s.setRetention(365, from: "test")  // so the second import finds every point the first brought
    _ = try s.importDatabase(notADatabase(), from: "picker")
    XCTAssertNotNil(s.problem)
    XCTAssertNotNil(s.importDatabase(fixture, from: "picker", recent: true))
    XCTAssertNil(s.problem)
    XCTAssertTrue(s.note.hasPrefix("Imported 36"), s.note)
    XCTAssertTrue(s.note.hasSuffix("and 4 places (0 already here)."), s.note)
    XCTAssertNotNil(s.importDatabase(fixture, from: "picker", recent: true))
    XCTAssertTrue(s.note.hasPrefix("Imported 0 points"), s.note)
    XCTAssertTrue(s.note.hasSuffix("and 0 places (4 already here)."), s.note)
    XCTAssertEqual(lines.of("prune").last?["reason"] as? String, "import", "an import prunes like any other")
    XCTAssertNil(try s.importDatabase(notADatabase(), from: "picker"))
    XCTAssertEqual(s.note, "")
    XCTAssertEqual(s.problem?.context, "Places.import")
  }

  /// Who wins: reading the trail again keeps a refused import's failure (only a failure to read goes).
  func testARereadKeepsARefusedImportButTakesAReadFailureAway() throws {
    var s = try screen()
    _ = try s.importDatabase(notADatabase(), from: "picker")
    try read(&s, reason: "pull")
    XCTAssertEqual(s.problem?.context, "Places.import", "still there to be copied")

    try db().execute("DROP TABLE locations")
    XCTAssertNil(s.startRead(reason: "foreground"))
    XCTAssertEqual(s.problem?.context, "Places.read")
    XCTAssertEqual(s.problem?.extra["reason"], .string("foreground"))
    _ = try LocationStore(db: db())  // the table again
    try read(&s, reason: "open")
    XCTAssertNil(s.problem, "the trail reads again: the read failure is over")
  }

  func testWithoutADatabaseEveryReadImportAndExportSaysSo() throws {
    var s = PlacesScreen(store: nil, settings: nil, cursors: nil, archiveSends: false, log: { _, _ in })
    XCTAssertNil(s.startRead(reason: "open"))
    XCTAssertEqual(s.problem?.context, "Places.open")
    XCTAssertEqual(s.problem?.extra["reason"], .string("open"))
    XCTAssertNil(s.importDatabase(fixture, from: "picker"))
    XCTAssertEqual(s.problem?.extra["reason"], .string("import"))
    s.prepareExport(from: "button")
    XCTAssertEqual(s.problem?.extra["reason"], .string("export"))
    XCTAssertNil(s.exportFile)
  }

  /// A plain line takes the failure away; JSON that parses to nothing is a plain line, JSON that does not parse a
  /// failure.
  func testImportingPlacesAsJSON() throws {
    var s = try screen()
    XCTAssertNil(s.importPlacesJSON("{"))
    XCTAssertEqual(s.problem?.context, "Places.import_places")
    XCTAssertEqual(s.problem?.extra["characters"], .int(1))
    XCTAssertNotNil(s.importPlacesJSON("[]"))
    XCTAssertNil(s.problem)
    XCTAssertEqual(s.note, "No valid places found in the JSON.")
    XCTAssertNotNil(s.importPlacesJSON(#"[{"name":"Home","lat":47.64,"lon":-122.30,"radiusMeters":100}]"#))
    XCTAssertEqual(s.note, "Imported 1 place.")
  }

  func testAFilePickerThatGaveNoFileIsAFailure() throws {
    struct Cancelled: LocalizedError { var errorDescription: String? { "The operation couldn't be completed." } }
    var s = try screen()
    s.importPickFailed(Cancelled())
    XCTAssertEqual(s.problem?.context, "Places.pick_import_file")
    XCTAssertEqual(s.problem?.message, "Could not open the file: The operation couldn't be completed.")
  }

  func testAFailedDeleteIsAFailureAndAGoodOneRereads() throws {
    let store = try LocationStore(db: db())
    try store.addKnownPlace(name: "Home", latitude: 47, longitude: -122, radiusMeters: 100)
    var s = try screen()
    try read(&s)
    let home = try XCTUnwrap(s.knownPlaces.first)
    XCTAssertEqual(s.deletePlace(home), PlacesReread(reason: "delete_place"))
    try db().execute("DROP TABLE known_places")
    XCTAssertNil(s.deletePlace(home))
    XCTAssertEqual(s.problem?.context, "Places.delete_place")
  }

  func testTheExportIsAFileReadyToShare() throws {
    try LocationStore(db: db()).insert(points(daysOld: 0..<3))
    var s = try screen()
    try read(&s)
    s.prepareExport(from: "button")
    let file = try XCTUnwrap(s.exportFile)
    XCTAssertEqual(file.lastPathComponent, "context-grabber.db")
    XCTAssertEqual(try LocationStore(db: SQLiteDatabase(path: file.path)).count(), 3)
    XCTAssertTrue(s.note.hasPrefix("Sharing "), s.note)
    XCTAssertEqual(lines.of("export").last?["points"] as? Int, 3)
  }

  // MARK: - reads

  /// Who wins: when the trail is read again before the last read has finished, only the newest read is shown.
  func testOnlyTheNewestReadIsShown() throws {
    let store = try LocationStore(db: db())
    var s = try screen()
    let first = try XCTUnwrap(s.startRead(reason: "open"))
    try store.insert(points(daysOld: 0..<1))
    let second = try XCTUnwrap(s.startRead(reason: "import"))
    XCTAssertTrue(s.loading)
    XCTAssertTrue(s.show(PlacesShown.build(second, now: Geo.ms(now)), for: second))
    XCTAssertFalse(s.show(PlacesShown.build(first, now: Geo.ms(now)), for: first), "the older read is dropped")
    XCTAssertFalse(s.loading)
    XCTAssertEqual(s.pointCount, 1)
    XCTAssertEqual(lines.of("places_open").map { $0["reason"] as? String }, ["import"])
  }
}
