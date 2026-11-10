//  The Places screen's choices (stories 041, 047, 049, 052, 053, 055, 056, 059): the Today · 7 days switch and its
//  remembered setting, retention and the prune, the naming card, adding, growing and deleting known places, the import
//  and the export, the line under the map and the failure it can hold, and what is shown once the trail is read. The
//  app's model is the humble half: it runs the read off the main thread, asks Apple Maps about icons, opens files the
//  picker hands it and draws the map. Who wins when two of these disagree is in the Places spec ("Who wins").

import Foundation

/// What the naming card is showing (story 047); `radius` is what the name card fills in.
public enum NamingCard: Identifiable, Equatable, Sendable {
  case name(source: String, centroid: Coordinate, radius: Double)
  case merge(source: String, centroid: Coordinate, radius: Double, suggestion: KnownPlaces.MergeSuggestion)
  public var id: String {
    switch self {
    case .name(let s, _, _): return "name-\(s)"
    case .merge(let s, _, _, _): return "merge-\(s)"
    }
  }
}

/// A failure on the Places screen (#798, story 059): the message, the operation, and the state that explains it. The
/// app shows it as a copyable problem.
public struct PlacesProblem: Equatable, Sendable {
  public enum Detail: Equatable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
  }

  public var message: String
  public var context: String
  public var extra: [String: Detail]
}

/// What a read of the trail shows: the stays, the day cards, today's and the week's path, the unnamed places.
public struct PlacesShown: Sendable {
  public var stays: [Stay]
  public var days: [PlaceDaySummary]
  public var route: [LocationPoint]
  public var weekRoute: [LocationPoint]
  public var unnamed: [UnnamedPlace]

  /// The clustering and the cards, for the read's points at `now`; slow on a real trail, so the app runs it off the
  /// main thread.
  public static func build(_ read: PlacesRead, now: Double, calendar: Calendar = .current) -> PlacesShown {
    let dayCount = PlacesScreen.breakdownDays
    let clusters = StayClustering.cluster(read.points, knownPlaces: read.known)
    let days = PlacesDaily.build(stays: clusters.stays, points: read.points, days: dayCount, now: now)
    let route = PlaceStyle.todaysRoute(read.points, now: now)
    // A week of breadcrumbs is thousands; 1,200 is a point every few minutes, plenty for a line on a map.
    let weekRoute = PlaceStyle.route(read.points, now: now, days: dayCount, maxPoints: 1200)
    let since =
      calendar.date(byAdding: .day, value: 1 - dayCount, to: calendar.startOfDay(for: Geo.date(now))).map(Geo.ms)
      ?? now
    let unnamed = UnnamedPlaces.summarize(clusters.stays, since: since, until: now)
    return PlacesShown(stays: clusters.stays, days: days, route: route, weekRoute: weekRoute, unnamed: unnamed)
  }
}

/// A read of the trail in flight: what was read, and which read it is (only the newest is shown).
public struct PlacesRead: Sendable {
  public let points: [LocationPoint]
  public let known: [KnownPlace]
  public let reason: String
  let generation: Int
  let started: Date
  let readMs: Int
}

/// An action that changed the trail or the places: read the trail again, with this reason in the log.
public struct PlacesReread: Equatable, Sendable {
  public let reason: String
}

public struct PlacesScreen {
  public typealias Log = (String, [String: Any]) -> Void

  public static let breakdownDays = 7
  public static let routeDaysKey = "places_route_days"

  public private(set) var days: [PlaceDaySummary] = []
  public private(set) var stays: [Stay] = []
  public private(set) var knownPlaces: [KnownPlace] = []
  /// The places with no name yet in the last seven days, longest first: the full-screen map's grey dots (story 056).
  public private(set) var unnamed: [UnnamedPlace] = []
  /// The grey dot whose card is open on the full-screen map.
  public private(set) var selectedUnnamed: String?
  /// Today's path, and the last seven days' (#252); the map draws the one `routeDays` picks.
  public private(set) var route: [LocationPoint] = []
  public private(set) var weekRoute: [LocationPoint] = []
  /// 1 (today) or 7, remembered.
  public private(set) var routeDays = 1
  public var shownRoute: [LocationPoint] { routeDays == 7 ? weekRoute : route }
  public private(set) var colors: [String: String] = [:]
  public private(set) var pointCount = 0
  public private(set) var retentionDays = LocationStore.defaultRetentionDays
  public private(set) var loading = false
  /// The last thing an action said that is not a failure (progress, success, a hint about the input), shown
  /// under the map. Saying something new takes the last failure away, and so does starting another action.
  public private(set) var note = "" { didSet { problem = nil } }
  /// The last failure (#798, story 059): copyable, with the operation and the state that explains it.
  public private(set) var problem: PlacesProblem?
  /// The naming card; the sheet closing sets it to nil.
  public var naming: NamingCard?
  /// Set when the export file is ready for the share sheet; the sheet closing sets it to nil.
  public var exportFile: URL?

  /// nil when the database did not open this launch: nothing can be read, exported or imported.
  public let store: LocationStore?
  private let settings: SettingsStore?
  private let cursors: ArchiveCursorStore?
  /// Whether the archive has somewhere to send the trail (story 270); then a prune keeps what it has not taken.
  private let archiveSends: Bool
  private let log: Log
  private let clock: () -> Date
  private let exportDirectory: URL
  private var generation = 0

  public init(
    store: LocationStore?, settings: SettingsStore?, cursors: ArchiveCursorStore?, archiveSends: Bool,
    log: @escaping Log, clock: @escaping () -> Date = Date.init,
    exportDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("export", isDirectory: true)
  ) {
    self.store = store
    self.settings = settings
    self.cursors = cursors
    self.archiveSends = archiveSends
    self.log = log
    self.clock = clock
    self.exportDirectory = exportDirectory
    routeDays = setting(Self.routeDaysKey) == "7" ? 7 : 1
    retentionDays = (try? store?.retentionDays()) ?? LocationStore.defaultRetentionDays
  }

  /// The colour a place has on the map and in the bars.
  public func color(_ placeId: String) -> String {
    if let c = colors[placeId] { return c }
    let index = knownPlaces.firstIndex { $0.name == placeId } ?? 0
    return PlaceStyle.color(placeId, in: colors, fallbackIndex: colors.count + index)
  }

  // MARK: - reading the trail

  /// Reads the trail; `reason` goes in the log (open, foreground, import…). nil when it could not be read (the
  /// failure says why). Hand what `PlacesShown.build` makes of it to `show(_:for:)`.
  public mutating func startRead(reason: String) -> PlacesRead? {
    guard let store else {
      noDatabase(reason)
      return nil
    }
    let started = Date()
    let points: [LocationPoint]
    do {
      knownPlaces = try store.knownPlaces()
      retentionDays = try store.retentionDays()
      points = try store.points()
      // The trail reads again: a failure to read it is over (any other failure stays to be copied).
      if let context = problem?.context, context == "Places.read" || context == "Places.open" { problem = nil }
    } catch {
      log("error", ["where": "places_read", "message": "\(error)"])
      show("Could not read the trail: \(error)", context: "Places.read", extra: ["reason": .string(reason)], error)
      return nil
    }
    pointCount = points.count
    loading = true
    generation += 1
    return PlacesRead(
      points: points, known: knownPlaces, reason: reason, generation: generation, started: started,
      readMs: Int(Date().timeIntervalSince(started) * 1000))
  }

  /// Shows a read's answer, unless a newer read has started since; false when it was dropped.
  @discardableResult
  public mutating func show(_ shown: PlacesShown, for read: PlacesRead) -> Bool {
    guard read.generation == generation else { return false }
    stays = shown.stays
    days = shown.days
    route = shown.route
    weekRoute = shown.weekRoute
    unnamed = shown.unnamed
    // A named place leaves the list, and the numbers after it may move: close a card that no longer fits.
    if let open = selectedUnnamed, !unnamed.contains(where: { $0.placeId == open }) { selectedUnnamed = nil }
    colors = PlaceStyle.colors(for: days)
    loading = false
    log(
      "places_open",
      [
        "reason": read.reason, "points": read.points.count, "known": read.known.count, "stays": stays.count,
        "days": days.count, "today_points": route.count, "week_points": weekRoute.count, "unnamed": unnamed.count,
        "read_ms": read.readMs, "ms": Int(Date().timeIntervalSince(read.started) * 1000),
      ])
    return true
  }

  // MARK: - the map's range (#252, story 049)

  /// The map's Today · 7 days switch.
  public mutating func setRouteDays(_ days: Int) {
    guard days != routeDays else { return }
    routeDays = days
    setSetting(Self.routeDaysKey, String(days))
    log("ui", ["action": "map_range", "days": days, "points": shownRoute.count])
  }

  // MARK: - retention (story 041)

  public mutating func setRetention(_ days: Int, from source: String) -> PlacesReread? {
    let days = min(365, max(1, days))
    guard days != retentionDays else { return nil }
    let lowered = days < retentionDays
    do {
      try store?.setRetentionDays(days)
    } catch {
      log("error", ["where": "retention_setting", "message": "\(error)"])
    }
    log("ui", ["action": "retention", "days": days, "from": source])
    retentionDays = days
    guard lowered else { return nil }
    prune(reason: "lowered")
    return PlacesReread(reason: "retention")
  }

  /// Deletes points older than the retention that the archive has taken; logged even when nothing went. A point
  /// the archive has not taken yet stays whatever its age, and the line says how many did.
  public func prune(reason: String) {
    guard let store else { return }
    do {
      let days = try store.retentionDays()
      let started = Date()
      var archived: Int64?
      if archiveSends { archived = try cursors?.pointsArchivedThroughId() ?? 0 }
      let result = try store.prune(retentionDays: days, now: Geo.ms(clock()), archivedThroughId: archived)
      log(
        "prune",
        [
          "reason": reason, "retention_days": days, "removed": result.removed,
          "unarchived_kept": result.unarchivedKept, "archive": archiveSends,
          "ms": Int(Date().timeIntervalSince(started) * 1000),
        ])
    } catch {
      log("error", ["where": "prune", "reason": reason, "message": "\(error)"])
    }
  }

  // MARK: - naming a place (stories 047, 056)

  /// The ＋ on a "Place N" row: offer to grow a known place within 500 m of that place's longest stay that day,
  /// or go straight to naming.
  public mutating func startNaming(_ placeId: String, on day: PlaceDaySummary) {
    let visits = day.visits.filter { $0.placeId == placeId }
    guard let visit = visits.max(by: { $0.durationMinutes < $1.durationMinutes }),
      let stay = stays.first(where: {
        $0.placeId == placeId && $0.startTime <= visit.startTime && $0.endTime >= visit.endTime
      })
    else { return }
    offerNaming(placeId, at: stay.centroid, radius: 100, from: "day")
  }

  /// *Name this place* on a grey dot's card (story 056): the same offer, at the place's centre, with the radius
  /// that holds its visits.
  public mutating func startNaming(_ place: UnnamedPlace) {
    offerNaming(place.placeId, at: place.centroid, radius: place.suggestedRadius, from: "map")
  }

  private mutating func offerNaming(_ placeId: String, at centroid: Coordinate, radius: Double, from source: String) {
    problem = nil
    if let suggestion = KnownPlaces.suggestion(for: centroid, among: knownPlaces) {
      naming = .merge(source: placeId, centroid: centroid, radius: radius, suggestion: suggestion)
    } else {
      naming = .name(source: placeId, centroid: centroid, radius: radius)
    }
    log(
      "ui",
      [
        "action": "name_place", "place": placeId, "from": source, "radius": Int(radius),
        "offer": naming.map { if case .merge = $0 { "expand" } else { "name" } } ?? "",
      ])
  }

  /// A tap on a grey dot on the full-screen map (story 056); nil closes the card.
  public mutating func selectUnnamed(_ placeId: String?, from source: String) {
    selectedUnnamed = placeId
    guard let placeId, let place = unnamed.first(where: { $0.placeId == placeId }) else { return }
    log(
      "ui",
      [
        "action": "unnamed_place", "place": placeId, "minutes": place.totalMinutes, "visits": place.visits.count,
        "from": source,
      ])
  }

  /// *Create new place* on the merge card: the name card, at the same position and radius.
  public mutating func createNew(from card: NamingCard) {
    if case .merge(let source, let centroid, let radius, _) = card {
      naming = .name(source: source, centroid: centroid, radius: radius)
    }
  }

  public mutating func expand(_ suggestion: KnownPlaces.MergeSuggestion, source: String) -> PlacesReread? {
    problem = nil
    do {
      try store?.updateKnownPlace(id: suggestion.nearest.id, circle: suggestion.grown)
      log(
        "known_place",
        [
          "action": "expand", "name": suggestion.nearest.name, "from": source,
          "radius_from": Int(suggestion.nearest.radiusMeters.rounded()),
          "radius_to": Int(suggestion.grown.radiusMeters.rounded()),
          "shift_m": Int(suggestion.shift.rounded()),
        ])
      naming = nil
      return PlacesReread(reason: "expand")
    } catch {
      fail("expand", error)
      return nil
    }
  }

  // MARK: - known places (story 045)

  /// Adds a known place; nil (with `note` or `problem` saying why) when the input is not usable or the save failed.
  public mutating func addPlace(
    name: String, latitude: Double?, longitude: Double?, radius: Double?, from source: String
  ) -> PlacesReread? {
    problem = nil
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      note = "A place needs a name."
      return nil
    }
    guard let latitude, let longitude, (-90...90).contains(latitude), (-180...180).contains(longitude) else {
      note = "A place needs a latitude from -90 to 90 and a longitude from -180 to 180."
      return nil
    }
    let radius = (radius ?? 100) > 0 ? (radius ?? 100) : 100
    do {
      try store?.addKnownPlace(name: name, latitude: latitude, longitude: longitude, radiusMeters: radius)
      log("known_place", ["action": "add", "name": name, "radius": Int(radius.rounded()), "from": source])
      note = "Added \(name)."
      naming = nil
      return PlacesReread(reason: "add_place")
    } catch {
      fail("add_place", error)
      return nil
    }
  }

  public mutating func deletePlace(_ place: KnownPlace) -> PlacesReread? {
    problem = nil
    do {
      try store?.deleteKnownPlace(id: place.id)
      log("known_place", ["action": "delete", "name": place.name])
      return PlacesReread(reason: "delete_place")
    } catch {
      fail("delete_place", error)
      return nil
    }
  }

  public mutating func importPlacesJSON(_ text: String) -> PlacesReread? {
    problem = nil
    do {
      let places = try KnownPlaces.parseImportJSON(text)
      for p in places {
        try store?.addKnownPlace(
          name: p.name, latitude: p.latitude, longitude: p.longitude, radiusMeters: p.radius)
      }
      log("known_place", ["action": "import_json", "count": places.count])
      note =
        places.isEmpty
        ? "No valid places found in the JSON." : "Imported \(places.count) place\(places.count == 1 ? "" : "s")."
      return PlacesReread(reason: "import_places")
    } catch {
      log("known_place", ["action": "import_json", "ok": false, "message": "\(error)"])
      show("\(error)", context: "Places.import_places", extra: ["characters": .int(text.count)], error)
      return nil
    }
  }

  // MARK: - failures (story 059)

  /// An action is starting: the last failure goes.
  public mutating func clearProblem() {
    problem = nil
  }

  /// A failed operation, logged and on screen.
  public mutating func fail(_ what: String, _ error: Error) {
    log("error", ["where": what, "message": "\(error)"])
    show("Could not \(what.replacingOccurrences(of: "_", with: " ")): \(error)", context: "Places.\(what)", error)
  }

  /// No database this launch (the `error` where: database line says why): nothing can be read, exported or imported.
  private mutating func noDatabase(_ reason: String) {
    show(
      "The database did not open, so nothing can be shown. The session log has the error.", context: "Places.open",
      extra: ["reason": .string(reason)])
  }

  /// A failure on screen: the message, the operation, and the state that explains it (what was asked, the error,
  /// how much Places holds). The callers log; this only shows.
  private mutating func show(
    _ message: String, context: String, extra: [String: PlacesProblem.Detail] = [:], _ error: Error? = nil
  ) {
    var extra = extra
    if let error { extra["error"] = .string(String(describing: error)) }
    extra["points"] = .int(pointCount)
    extra["known_places"] = .int(knownPlaces.count)
    note = ""
    problem = PlacesProblem(message: message, context: context, extra: extra)
  }

  /// The file picker gave no file (the import never started).
  public mutating func importPickFailed(_ error: Error) {
    log("import", ["from": "picker", "ok": false, "message": error.localizedDescription])
    show("Could not open the file: \(error.localizedDescription)", context: "Places.pick_import_file", error)
  }

  // MARK: - export and import (stories 052, 055)

  /// A consistent copy of the whole database, named as Context Grabber names its export.
  public mutating func prepareExport(from source: String) {
    problem = nil
    guard let store else { return noDatabase("export") }
    let started = Date()
    let file = exportDirectory.appendingPathComponent("context-grabber.db")
    do {
      try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
      try? FileManager.default.removeItem(at: file)
      try store.exportSnapshot(to: file.path)
      let bytes = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
      log(
        "export",
        [
          "from": source, "ok": true, "bytes": bytes, "points": pointCount,
          "ms": Int(Date().timeIntervalSince(started) * 1000), "path": file.path,
        ])
      note = "Sharing \(bytes / 1024) KB…"
      exportFile = file
    } catch {
      log("export", ["from": source, "ok": false, "message": "\(error)"])
      show("Export failed: \(error)", context: "Places.export", extra: ["from": .string(source)], error)
    }
  }

  /// Imports another Context Grabber database (story 055) from a file the app can read (the app opens a
  /// security-scoped one first). `recent` moves the timestamps by whole days so the newest point falls in the last
  /// 24 hours (the simulator hook, for an old fixture).
  public mutating func importDatabase(_ url: URL, from source: String, recent: Bool = false) -> PlacesReread? {
    problem = nil
    guard let store else {
      noDatabase("import")
      return nil
    }
    let started = Date()
    let copy = FileManager.default.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString).db")
    defer { try? FileManager.default.removeItem(at: copy) }
    do {
      try FileManager.default.copyItem(at: url, to: copy)
      var shift = 0.0
      if recent,
        let newest = try? SQLiteDatabase(path: copy.path).run("SELECT MAX(timestamp) AS t FROM locations").first?["t"]?
          .doubleValue
      {
        shift = LocationStore.recentShiftMs(newest: newest, now: Geo.ms(clock()))
      }
      let r = try store.importDatabase(at: copy.path, shiftMs: shift)
      log(
        "import",
        [
          "from": source, "ok": true, "file": url.lastPathComponent, "points_added": r.pointsAdded,
          "points_already": r.pointsAlreadyHere, "places_added": r.placesAdded, "places_already": r.placesAlreadyHere,
          "shift_days": Int(shift / Geo.dayMs), "ms": Int(Date().timeIntervalSince(started) * 1000),
        ])
      prune(reason: "import")
      note =
        "Imported \(r.pointsAdded.formatted()) points (\(r.pointsAlreadyHere.formatted()) already here) and \(r.placesAdded) places (\(r.placesAlreadyHere) already here)."
      return PlacesReread(reason: "import")
    } catch {
      log("import", ["from": source, "ok": false, "file": url.lastPathComponent, "message": "\(error)"])
      show(
        "Import refused: \(error)", context: "Places.import",
        extra: ["from": .string(source), "file": .string(url.lastPathComponent), "recent": .bool(recent)], error)
      return nil
    }
  }

  // MARK: - settings

  private func setting(_ key: String) -> String? {
    do {
      return try settings?.get(key)
    } catch {
      log("error", ["where": "settings", "key": key, "message": "\(error)"])
      return nil
    }
  }

  private func setSetting(_ key: String, _ value: String) {
    do {
      try settings?.set(key, value)
    } catch {
      log("error", ["where": "settings", "key": key, "message": "\(error)"])
    }
  }
}
