//  The Places screen's state (stories 041, 043–047, 049, 052, 053, 055–057): the trail read back as stays and day
//  cards, the known places and what can be done to them, retention, the export and the import. ContextCore does
//  the deciding; this owns the database, the log and the work off the main thread.

import ContextCore
import CoreLocation
import SwiftUI

/// What the naming card is showing (story 047); `radius` is what the name card fills in.
enum NamingCard: Identifiable, Equatable {
  case name(source: String, centroid: Coordinate, radius: Double)
  case merge(source: String, centroid: Coordinate, radius: Double, suggestion: KnownPlaces.MergeSuggestion)
  var id: String {
    switch self {
    case .name(let s, _, _): return "name-\(s)"
    case .merge(let s, _, _, _): return "merge-\(s)"
    }
  }
}

@MainActor
final class PlacesModel: ObservableObject {
  static let breakdownDays = 7

  @Published private(set) var days: [PlaceDaySummary] = []
  @Published private(set) var stays: [Stay] = []
  @Published private(set) var knownPlaces: [KnownPlace] = []
  /// The places with no name yet in the last seven days, longest first: the full-screen map's grey dots (story 056).
  @Published private(set) var unnamed: [UnnamedPlace] = []
  /// Each known place's icon by its id (story 057).
  @Published private(set) var icons: [Int64: PlaceIcon] = [:]
  /// The grey dot whose card is open on the full-screen map.
  @Published var selectedUnnamed: String?
  /// Today's path, and the last seven days' (#252); the map draws the one `routeDays` picks.
  @Published private(set) var route: [LocationPoint] = []
  @Published private(set) var weekRoute: [LocationPoint] = []
  /// 1 (today) or 7, remembered.
  @Published private(set) var routeDays = 1
  static let routeDaysKey = "places_route_days"
  var shownRoute: [LocationPoint] { routeDays == 7 ? weekRoute : route }
  @Published private(set) var colors: [String: String] = [:]
  @Published private(set) var pointCount = 0
  @Published private(set) var retentionDays = LocationStore.defaultRetentionDays
  @Published private(set) var loading = false
  /// The last thing an action said (import, export, add place…), shown under the action.
  @Published var status = ""
  @Published var naming: NamingCard?
  /// Set when the export file is ready for the share sheet.
  @Published var exportFile: URL?

  private let log: SessionLog
  private let database: AppDatabase
  private var store: LocationStore? { database.locations }
  private var generation = 0
  /// Places Apple Maps is being asked about, and the icons already logged this launch (one line per change).
  private var lookingUp: Set<Int64> = []
  private var loggedIcons: [Int64: PlaceIcon] = [:]
  private var failedLookups: Set<Int64> = []

  init(log: SessionLog, database: AppDatabase) {
    self.log = log
    self.database = database
    routeDays = database.setting(Self.routeDaysKey) == "7" ? 7 : 1
    retentionDays = (try? store?.retentionDays()) ?? LocationStore.defaultRetentionDays
  }

  /// The colour a place has on the map and in the bars.
  func color(_ placeId: String) -> String {
    if let c = colors[placeId] { return c }
    let index = knownPlaces.firstIndex { $0.name == placeId } ?? 0
    return PlaceStyle.color(placeId, in: colors, fallbackIndex: colors.count + index)
  }

  // MARK: - reading the trail

  /// Reads the trail and recomputes everything; `reason` goes in the log (open, foreground, import…).
  func reload(reason: String) {
    guard let store else {
      status = "The database did not open, so nothing can be shown. The session log has the error."
      return
    }
    let started = Date()
    let points: [LocationPoint]
    do {
      knownPlaces = try store.knownPlaces()
      retentionDays = try store.retentionDays()
      points = try store.points()
      refreshIcons()
    } catch {
      log.event("error", ["where": "places_read", "message": "\(error)"])
      status = "Could not read the trail: \(error)"
      return
    }
    pointCount = points.count
    loading = true
    generation += 1
    let mine = generation
    let known = knownPlaces
    let readMs = Int(Date().timeIntervalSince(started) * 1000)
    let dayCount = Self.breakdownDays
    Task.detached(priority: .userInitiated) {
      let now = Geo.ms(Date())
      let clusters = StayClustering.cluster(points, knownPlaces: known)
      let days = PlacesDaily.build(stays: clusters.stays, points: points, days: dayCount, now: now)
      let route = PlaceStyle.todaysRoute(points, now: now)
      // A week of breadcrumbs is thousands; 1,200 is a point every few minutes, plenty for a line on a map.
      let weekRoute = PlaceStyle.route(points, now: now, days: dayCount, maxPoints: 1200)
      let calendar = Calendar.current
      let since = calendar.date(byAdding: .day, value: 1 - dayCount, to: calendar.startOfDay(for: Geo.date(now))).map(Geo.ms) ?? now
      let unnamed = UnnamedPlaces.summarize(clusters.stays, since: since, until: now)
      await MainActor.run {
        guard mine == self.generation else { return }
        self.stays = clusters.stays
        self.days = days
        self.route = route
        self.weekRoute = weekRoute
        self.unnamed = unnamed
        // A named place leaves the list, and the numbers after it may move: close a card that no longer fits.
        if let open = self.selectedUnnamed, !unnamed.contains(where: { $0.placeId == open }) { self.selectedUnnamed = nil }
        self.colors = PlaceStyle.colors(for: days)
        self.loading = false
        self.log.event(
          "places_open",
          [
            "reason": reason, "points": points.count, "known": known.count, "stays": clusters.stays.count,
            "days": days.count, "today_points": route.count, "week_points": weekRoute.count, "unnamed": unnamed.count, "read_ms": readMs,
            "ms": Int(Date().timeIntervalSince(started) * 1000),
          ])
      }
    }
  }

  // MARK: - icons (story 057)

  /// A place's icon; a plain pin until it is known.
  /// #252: the map's Today · 7 days switch.
  func setRouteDays(_ days: Int) {
    guard days != routeDays else { return }
    routeDays = days
    database.setSetting(Self.routeDaysKey, String(days))
    log.event("ui", ["action": "map_range", "days": days, "points": shownRoute.count])
  }

  func icon(_ place: KnownPlace) -> PlaceIcon {
    icons[place.id] ?? PlaceIcons.resolve(name: place.name, stored: nil)
  }

  /// Resolves every place's icon from the remembered ones, logs what changed, and asks Apple Maps about the places
  /// neither a choice, the name nor an earlier answer settles.
  private func refreshIcons() {
    let stored: [Int64: StoredPlaceIcon]
    do {
      stored = try store?.placeIcons() ?? [:]
    } catch {
      log.event("error", ["where": "place_icons", "message": "\(error)"])
      stored = [:]
    }
    var next: [Int64: PlaceIcon] = [:]
    for place in knownPlaces {
      let icon = PlaceIcons.resolve(name: place.name, stored: stored[place.id])
      next[place.id] = icon
      if !icon.needsLookup, loggedIcons[place.id] != icon {
        loggedIcons[place.id] = icon
        var fields: [String: Any] = ["action": "guess", "name": place.name, "symbol": icon.symbol, "source": icon.source.rawValue]
        if let category = icon.category { fields["category"] = category }
        log.event("place_icon", fields)
      }
      if icon.needsLookup { lookUp(place) }
    }
    icons = next
  }

  private func lookUp(_ place: KnownPlace) {
    guard !lookingUp.contains(place.id) else { return }
    lookingUp.insert(place.id)
    Task {
      let started = Date()
      defer { lookingUp.remove(place.id) }
      do {
        let answer = try await PlaceIconLookup.ask(about: place)
        let stored = PlaceIcons.stored(named: answer.named, nearby: answer.nearby, for: place)
        let radius = PlaceIcons.searchRadius(for: place)
        var fields: [String: Any] = [
          "action": "lookup", "name": place.name, "ok": true, "named": answer.named.count, "found": answer.nearby.count,
          "symbol": stored.symbol, "source": stored.source.rawValue, "radius": Int(radius),
          "ms": Int(Date().timeIntervalSince(started) * 1000),
        ]
        // The five nearest, whatever their category, so a wrong guess can be read from the log.
        fields["nearby"] = answer.nearby.map { ($0, Geo.distance(place.coordinate, $0.coordinate)) }.sorted { $0.1 < $1.1 }.prefix(5)
          .map { "\(PlaceIcons.categoryName($0.0.category ?? "none")) \(Int($0.1.rounded()))m" }.joined(separator: ", ")
        fields["named_top"] = answer.named.prefix(3)
          .map { "\($0.name ?? "?") (\(PlaceIcons.categoryName($0.category ?? "none")) \(Int(Geo.distance(place.coordinate, $0.coordinate).rounded()))m)" }
          .joined(separator: ", ")
        if let hit = PlaceIcons.byName(answer.named, for: place) {
          fields["by"] = "name"
          fields["category"] = hit.category
          fields["distance_m"] = Int(hit.distance.rounded())
        } else if let hit = PlaceIcons.nearest(answer.nearby, to: place.coordinate, within: radius) {
          fields["by"] = "nearest"
          fields["category"] = hit.category
          fields["distance_m"] = Int(hit.distance.rounded())
        }
        log.event("place_icon", fields)
        // The place may have been deleted, grown or given an icon meanwhile: only fill a gap that is still there.
        guard let current = knownPlaces.first(where: { $0.id == place.id }), current.coordinate == place.coordinate,
          current.radiusMeters == place.radiusMeters, icons[place.id]?.needsLookup ?? false
        else { return }
        try store?.setPlaceIcon(stored, for: place.id)
        refreshIcons()
      } catch {
        // Left unremembered: the plain pin stands and the next reload asks again. Said once per place per launch.
        guard failedLookups.insert(place.id).inserted else { return }
        log.event(
          "place_icon",
          ["action": "lookup", "name": place.name, "ok": false, "message": "\(error)", "ms": Int(Date().timeIntervalSince(started) * 1000)])
      }
    }
  }

  /// The known place whose screen is open.
  @Published var editing: KnownPlace?

  func edit(_ place: KnownPlace, from source: String) {
    editing = place
    log.event("ui", ["action": "edit_place", "name": place.name, "from": source, "symbol": icon(place).symbol, "source": icon(place).source.rawValue])
  }

  /// The picker on a place's screen: a symbol is chosen and remembered; nil gives the place back to the guess.
  func chooseIcon(_ symbol: String?, for place: KnownPlace) {
    do {
      if let symbol {
        try store?.setPlaceIcon(StoredPlaceIcon(symbol: symbol, source: .chosen), for: place.id)
      } else {
        try store?.clearPlaceIcon(for: place.id)
      }
      log.event("place_icon", ["action": symbol == nil ? "clear" : "choose", "name": place.name, "symbol": symbol ?? ""])
      refreshIcons()
    } catch {
      fail("place_icon", error)
    }
  }

  // MARK: - retention (story 041)

  func setRetention(_ days: Int, from source: String) {
    let days = min(365, max(1, days))
    guard days != retentionDays else { return }
    let lowered = days < retentionDays
    do {
      try store?.setRetentionDays(days)
    } catch {
      log.event("error", ["where": "retention_setting", "message": "\(error)"])
    }
    log.event("ui", ["action": "retention", "days": days, "from": source])
    retentionDays = days
    if lowered {
      prune(reason: "lowered")
      reload(reason: "retention")
    }
  }

  /// Deletes points older than the retention; logged even when nothing went.
  func prune(reason: String) {
    guard let store else { return }
    do {
      let days = try store.retentionDays()
      let started = Date()
      let removed = try store.prune(retentionDays: days, now: Geo.ms(Date()))
      log.event(
        "prune",
        ["reason": reason, "retention_days": days, "removed": removed, "ms": Int(Date().timeIntervalSince(started) * 1000)])
    } catch {
      log.event("error", ["where": "prune", "reason": reason, "message": "\(error)"])
    }
  }

  // MARK: - naming a place (story 047)

  /// The ＋ on a "Place N" row: offer to grow a known place within 500 m of that place's longest stay that day,
  /// or go straight to naming.
  func startNaming(_ placeId: String, on day: PlaceDaySummary) {
    let visits = day.visits.filter { $0.placeId == placeId }
    guard let visit = visits.max(by: { $0.durationMinutes < $1.durationMinutes }),
      let stay = stays.first(where: { $0.placeId == placeId && $0.startTime <= visit.startTime && $0.endTime >= visit.endTime })
    else { return }
    offerNaming(placeId, at: stay.centroid, radius: 100, from: "day")
  }

  /// *Name this place* on a grey dot's card (story 056): the same offer, at the place's centre, with the radius
  /// that holds its visits.
  func startNaming(_ place: UnnamedPlace) {
    offerNaming(place.placeId, at: place.centroid, radius: place.suggestedRadius, from: "map")
  }

  private func offerNaming(_ placeId: String, at centroid: Coordinate, radius: Double, from source: String) {
    if let suggestion = KnownPlaces.suggestion(for: centroid, among: knownPlaces) {
      naming = .merge(source: placeId, centroid: centroid, radius: radius, suggestion: suggestion)
    } else {
      naming = .name(source: placeId, centroid: centroid, radius: radius)
    }
    log.event(
      "ui",
      [
        "action": "name_place", "place": placeId, "from": source, "radius": Int(radius),
        "offer": naming.map { if case .merge = $0 { "expand" } else { "name" } } ?? "",
      ])
  }

  /// A tap on a grey dot on the full-screen map (story 056); nil closes the card.
  func selectUnnamed(_ placeId: String?, from source: String) {
    selectedUnnamed = placeId
    guard let placeId, let place = unnamed.first(where: { $0.placeId == placeId }) else { return }
    log.event(
      "ui", ["action": "unnamed_place", "place": placeId, "minutes": place.totalMinutes, "visits": place.visits.count, "from": source])
  }

  func createNew(from card: NamingCard) {
    if case .merge(let source, let centroid, let radius, _) = card { naming = .name(source: source, centroid: centroid, radius: radius) }
  }

  func expand(_ suggestion: KnownPlaces.MergeSuggestion, source: String) {
    do {
      try store?.updateKnownPlace(id: suggestion.nearest.id, circle: suggestion.grown)
      log.event(
        "known_place",
        [
          "action": "expand", "name": suggestion.nearest.name, "from": source,
          "radius_from": Int(suggestion.nearest.radiusMeters.rounded()), "radius_to": Int(suggestion.grown.radiusMeters.rounded()),
          "shift_m": Int(suggestion.shift.rounded()),
        ])
      naming = nil
      reload(reason: "expand")
    } catch {
      fail("expand", error)
    }
  }

  /// Adds a known place; returns false (with `status` saying why) when the input is not usable.
  @discardableResult
  func addPlace(name: String, latitude: Double?, longitude: Double?, radius: Double?, from source: String) -> Bool {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      status = "A place needs a name."
      return false
    }
    guard let latitude, let longitude, (-90...90).contains(latitude), (-180...180).contains(longitude) else {
      status = "A place needs a latitude from -90 to 90 and a longitude from -180 to 180."
      return false
    }
    let radius = (radius ?? 100) > 0 ? (radius ?? 100) : 100
    do {
      try store?.addKnownPlace(name: name, latitude: latitude, longitude: longitude, radiusMeters: radius)
      log.event("known_place", ["action": "add", "name": name, "radius": Int(radius.rounded()), "from": source])
      status = "Added \(name)."
      naming = nil
      reload(reason: "add_place")
      return true
    } catch {
      fail("add_place", error)
      return false
    }
  }

  func deletePlace(_ place: KnownPlace) {
    do {
      try store?.deleteKnownPlace(id: place.id)
      log.event("known_place", ["action": "delete", "name": place.name])
      reload(reason: "delete_place")
    } catch {
      fail("delete_place", error)
    }
  }

  func importPlacesJSON(_ text: String) {
    do {
      let places = try KnownPlaces.parseImportJSON(text)
      for p in places {
        try store?.addKnownPlace(name: p.name, latitude: p.latitude, longitude: p.longitude, radiusMeters: p.radius)
      }
      log.event("known_place", ["action": "import_json", "count": places.count])
      status = places.isEmpty ? "No valid places found in the JSON." : "Imported \(places.count) place\(places.count == 1 ? "" : "s")."
      reload(reason: "import_places")
    } catch {
      log.event("known_place", ["action": "import_json", "ok": false, "message": "\(error)"])
      status = "\(error)"
    }
  }

  private func fail(_ what: String, _ error: Error) {
    log.event("error", ["where": what, "message": "\(error)"])
    status = "Could not \(what.replacingOccurrences(of: "_", with: " ")): \(error)"
  }

  // MARK: - copy, export, import (stories 051–053, 055)

  func copyDailySummary() {
    UIPasteboard.general.string = PlacesDaily.text(days)
    log.event("ui", ["action": "copy_daily_summary", "days": days.count])
  }

  /// A consistent copy of the whole database, named as Context Grabber names its export.
  func prepareExport(from source: String) {
    guard let store else { return }
    let started = Date()
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("export", isDirectory: true)
    let file = dir.appendingPathComponent("context-grabber.db")
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      try? FileManager.default.removeItem(at: file)
      try store.exportSnapshot(to: file.path)
      let bytes = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
      log.event(
        "export",
        ["from": source, "ok": true, "bytes": bytes, "points": pointCount, "ms": Int(Date().timeIntervalSince(started) * 1000), "path": file.path])
      status = "Sharing \(bytes / 1024) KB…"
      exportFile = file
    } catch {
      log.event("export", ["from": source, "ok": false, "message": "\(error)"])
      status = "Export failed: \(error)"
    }
  }

  /// Imports another Context Grabber database (story 055). `url` may be security-scoped (Files, the share sheet).
  /// `recent` moves the timestamps by whole weeks so the newest point falls in the last seven days (the
  /// simulator hook, for an old fixture).
  func importDatabase(_ url: URL, from source: String, recent: Bool = false) {
    guard let store else { return }
    let started = Date()
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let copy = FileManager.default.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString).db")
    defer { try? FileManager.default.removeItem(at: copy) }
    do {
      try FileManager.default.copyItem(at: url, to: copy)
      var shift = 0.0
      if recent, let newest = try? SQLiteDatabase(path: copy.path).run("SELECT MAX(timestamp) AS t FROM locations").first?["t"]?.doubleValue {
        let week = 7 * Geo.dayMs
        shift = floor((Geo.ms(Date()) - newest) / week) * week
      }
      let r = try store.importDatabase(at: copy.path, shiftMs: shift)
      log.event(
        "import",
        [
          "from": source, "ok": true, "file": url.lastPathComponent, "points_added": r.pointsAdded,
          "points_already": r.pointsAlreadyHere, "places_added": r.placesAdded, "places_already": r.placesAlreadyHere,
          "shift_days": Int(shift / Geo.dayMs), "ms": Int(Date().timeIntervalSince(started) * 1000),
        ])
      prune(reason: "import")
      status =
        "Imported \(r.pointsAdded.formatted()) points (\(r.pointsAlreadyHere.formatted()) already here) and \(r.placesAdded) places (\(r.placesAlreadyHere) already here)."
      reload(reason: "import")
    } catch {
      log.event("import", ["from": source, "ok": false, "file": url.lastPathComponent, "message": "\(error)"])
      status = "Import refused: \(error)"
    }
  }
}
