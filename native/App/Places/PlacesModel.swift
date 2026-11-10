//  The Places screen's model (stories 041, 043–047, 049, 052, 053, 055–057): `PlacesScreen` in ContextCore does the
//  deciding (the range, retention, the naming card, import and export and their failures, what is shown); this is
//  the humble half. It reads the trail off the main thread, asks Apple Maps about icons, opens the files the picker
//  hands it, puts the daily summary on the clipboard and turns a failure into BugKit's copyable problem.

import BugKit
import ContextCore
import CoreLocation
import SwiftUI

@MainActor
final class PlacesModel: ObservableObject {
  static let breakdownDays = PlacesScreen.breakdownDays

  /// The screen's state and choices; every view reads it through the properties below.
  @Published private(set) var screen: PlacesScreen
  /// Each known place's icon by its id (story 057).
  @Published private(set) var icons: [Int64: PlaceIcon] = [:]
  /// The known place whose screen is open.
  @Published var editing: KnownPlace?

  var days: [PlaceDaySummary] { screen.days }
  var stays: [Stay] { screen.stays }
  var knownPlaces: [KnownPlace] { screen.knownPlaces }
  var unnamed: [UnnamedPlace] { screen.unnamed }
  var selectedUnnamed: String? { screen.selectedUnnamed }
  var routeDays: Int { screen.routeDays }
  var shownRoute: [LocationPoint] { screen.shownRoute }
  var pointCount: Int { screen.pointCount }
  var retentionDays: Int { screen.retentionDays }
  var loading: Bool { screen.loading }
  var note: String { screen.note }
  /// The last failure (#798, story 059), as BugKit's copyable problem.
  var problem: BugProblem? {
    screen.problem.map { p in
      BugProblem.grabber(
        p.message, context: p.context,
        extra: p.extra.mapValues {
          switch $0 {
          case .string(let s): return .string(s)
          case .int(let i): return .int(i)
          case .bool(let b): return .bool(b)
          }
        })
    }
  }
  var naming: NamingCard? {
    get { screen.naming }
    set { screen.naming = newValue }
  }
  var exportFile: URL? {
    get { screen.exportFile }
    set { screen.exportFile = newValue }
  }

  private let log: SessionLog
  /// For the Copy error button, in the sheets too.
  var bugLogger: BugLogger { log.bugLogger }
  private var store: LocationStore? { screen.store }
  /// Places Apple Maps is being asked about, and the icons already logged this launch (one line per change).
  private var lookingUp: Set<Int64> = []
  private var loggedIcons: [Int64: PlaceIcon] = [:]
  private var failedLookups: Set<Int64> = []

  init(log: SessionLog, database: AppDatabase, archiveSends: Bool) {
    self.log = log
    screen = PlacesScreen(
      store: database.locations, settings: database.settings, cursors: database.archiveCursors,
      archiveSends: archiveSends, log: { [log] in log.event($0, $1) })
  }

  /// The colour a place has on the map and in the bars.
  func color(_ placeId: String) -> String { screen.color(placeId) }

  // MARK: - reading the trail

  /// Reads the trail and recomputes everything off the main thread; `reason` goes in the log (open, foreground…).
  func reload(reason: String) {
    guard let read = screen.startRead(reason: reason) else { return }
    refreshIcons()
    Task.detached(priority: .userInitiated) {
      let shown = PlacesShown.build(read, now: Geo.ms(Date()))
      await MainActor.run { self.screen.show(shown, for: read) }
    }
  }

  private func reread(_ next: PlacesReread?) {
    if let next { reload(reason: next.reason) }
  }

  /// #252: the map's Today · 7 days switch.
  func setRouteDays(_ days: Int) { screen.setRouteDays(days) }

  // MARK: - icons (story 057)

  /// A place's icon; a plain pin until it is known.
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
        var fields: [String: Any] = [
          "action": "guess", "name": place.name, "symbol": icon.symbol, "source": icon.source.rawValue,
        ]
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
        fields["nearby"] = answer.nearby.map { ($0, Geo.distance(place.coordinate, $0.coordinate)) }.sorted {
          $0.1 < $1.1
        }.prefix(5)
          .map { "\(PlaceIcons.categoryName($0.0.category ?? "none")) \(Int($0.1.rounded()))m" }.joined(separator: ", ")
        fields["named_top"] = answer.named.prefix(3)
          .map {
            "\($0.name ?? "?") (\(PlaceIcons.categoryName($0.category ?? "none")) \(Int(Geo.distance(place.coordinate, $0.coordinate).rounded()))m)"
          }
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
          [
            "action": "lookup", "name": place.name, "ok": false, "message": "\(error)",
            "ms": Int(Date().timeIntervalSince(started) * 1000),
          ])
      }
    }
  }

  func edit(_ place: KnownPlace, from source: String) {
    screen.clearProblem()
    editing = place
    log.event(
      "ui",
      [
        "action": "edit_place", "name": place.name, "from": source, "symbol": icon(place).symbol,
        "source": icon(place).source.rawValue,
      ])
  }

  /// The picker on a place's screen: a symbol is chosen and remembered; nil gives the place back to the guess.
  func chooseIcon(_ symbol: String?, for place: KnownPlace) {
    screen.clearProblem()
    do {
      if let symbol {
        try store?.setPlaceIcon(StoredPlaceIcon(symbol: symbol, source: .chosen), for: place.id)
      } else {
        try store?.clearPlaceIcon(for: place.id)
      }
      log.event(
        "place_icon", ["action": symbol == nil ? "clear" : "choose", "name": place.name, "symbol": symbol ?? ""])
      refreshIcons()
    } catch {
      screen.fail("place_icon", error)
    }
  }

  // MARK: - retention (story 041)

  func setRetention(_ days: Int, from source: String) { reread(screen.setRetention(days, from: source)) }

  func prune(reason: String) { screen.prune(reason: reason) }

  // MARK: - naming a place (stories 047, 056)

  func startNaming(_ placeId: String, on day: PlaceDaySummary) { screen.startNaming(placeId, on: day) }
  func startNaming(_ place: UnnamedPlace) { screen.startNaming(place) }
  func selectUnnamed(_ placeId: String?, from source: String) { screen.selectUnnamed(placeId, from: source) }
  func createNew(from card: NamingCard) { screen.createNew(from: card) }
  func expand(_ suggestion: KnownPlaces.MergeSuggestion, source: String) {
    reread(screen.expand(suggestion, source: source))
  }

  /// Adds a known place; returns false (with `note` or `problem` saying why) when the input is not usable.
  @discardableResult
  func addPlace(name: String, latitude: Double?, longitude: Double?, radius: Double?, from source: String) -> Bool {
    let next = screen.addPlace(name: name, latitude: latitude, longitude: longitude, radius: radius, from: source)
    reread(next)
    return next != nil
  }

  func deletePlace(_ place: KnownPlace) { reread(screen.deletePlace(place)) }
  func importPlacesJSON(_ text: String) { reread(screen.importPlacesJSON(text)) }
  /// The file picker gave no file (the import never started).
  func importPickFailed(_ error: Error) { screen.importPickFailed(error) }

  // MARK: - copy, export, import (stories 051–053, 055)

  func copyDailySummary() {
    UIPasteboard.general.string = PlacesDaily.text(days)
    log.event("ui", ["action": "copy_daily_summary", "days": days.count])
  }

  /// A consistent copy of the whole database, named as Context Grabber names its export.
  func prepareExport(from source: String) { screen.prepareExport(from: source) }

  /// Imports another Context Grabber database (story 055). `url` may be security-scoped (Files, the share sheet).
  /// `recent` moves the timestamps by whole days so the newest point falls in the last 24 hours (the simulator
  /// hook, for an old fixture).
  func importDatabase(_ url: URL, from source: String, recent: Bool = false) {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    reread(screen.importDatabase(url, from: source, recent: recent))
  }
}
