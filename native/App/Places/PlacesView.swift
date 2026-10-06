//  The Places screen (stories 040–053, 055): the map, the last seven days, the known places, tracking and
//  retention, the copy / export / import actions. One screen where Context Grabber has a tab and a sheet.

import ContextCore
import SwiftUI
import UniformTypeIdentifiers

struct PlacesView: View {
  @ObservedObject var app: AppModel
  @ObservedObject var places: PlacesModel
  @ObservedObject var tracker: LocationTracker
  let onExit: () -> Void

  @State private var expandedDay: String?
  @State private var showImporter = false
  @State private var addName = ""
  @State private var addLat = ""
  @State private var addLng = ""
  @State private var addRadius = "100"
  @State private var gpsStatus = ""
  @State private var importJSON = ""
  @State private var copiedSummary = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          PlacesMapView(places: places, tracker: tracker, log: app.log, fullscreen: false) { app.showPlacesMap = true }
            .frame(height: 280)
            .listRowInsets(EdgeInsets())
          if !places.status.isEmpty {
            Text(places.status).font(.footnote).foregroundStyle(.secondary)
          }
        }

        Section {
          if places.days.isEmpty {
            Text(places.loading ? "Reading the trail…" : "No points in the last seven days. Turn on Background Tracking below, or import Context Grabber's database.")
              .font(.callout).foregroundStyle(.secondary)
          }
          ForEach(places.days, id: \.dateKey) { day in
            DayCard(day: day, places: places, expanded: expandedDay == day.dateKey) {
              withAnimation { expandedDay = expandedDay == day.dateKey ? nil : day.dateKey }
            }
          }
        } header: {
          Text("Last seven days")
        }

        knownPlacesSection
        trackingSection

        Section {
          Button(copiedSummary ? "Copied" : "Copy daily summary") {
            places.copyDailySummary()
            copiedSummary = true
            Task {
              try? await Task.sleep(for: .milliseconds(1500))
              copiedSummary = false
            }
          }
          .disabled(places.days.isEmpty)
          Button("Export database") { places.prepareExport(from: "button") }
          Button("Import from Context Grabber") { showImporter = true }
        } header: {
          Text("History")
        } footer: {
          Text("Import copies the points and known places from Context Grabber's Export Database file. Importing the same file again adds nothing.")
        }
      }
      .navigationTitle("Places")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) { Button("Done", action: onExit) }
      }
      .refreshable { places.reload(reason: "pull") }
    }
    .fileImporter(isPresented: $showImporter, allowedContentTypes: [.database, .item]) { result in
      switch result {
      case .success(let url): places.importDatabase(url, from: "picker")
      case .failure(let error): places.status = "Could not open the file: \(error.localizedDescription)"
      }
    }
    // While the full-screen map is up it presents the naming card itself (a sheet cannot open under another).
    .sheet(item: Binding(get: { app.showPlacesMap ? nil : places.naming }, set: { places.naming = $0 })) { card in
      NamingSheet(card: card, places: places).presentationDetents([.medium])
    }
    .sheet(isPresented: Binding(get: { places.exportFile != nil }, set: { if !$0 { places.exportFile = nil } })) {
      if let file = places.exportFile { ShareSheet(items: [file]) }
    }
    .sheet(isPresented: $app.showPlacesMap) {
      PlacesMapView(places: places, tracker: tracker, log: app.log, fullscreen: true) { app.showPlacesMap = false }
        .ignoresSafeArea(edges: .bottom)
        .presentationDragIndicator(.visible)
        .sheet(item: $places.naming) { card in NamingSheet(card: card, places: places).presentationDetents([.medium]) }
    }
  }

  // MARK: - known places (story 045)

  private var knownPlacesSection: some View {
    Section {
      ForEach(places.knownPlaces) { place in
        HStack(spacing: 12) {
          Circle().fill(Color(hex: places.color(place.name))).frame(width: 10, height: 10)
          VStack(alignment: .leading, spacing: 2) {
            Text("\(PlaceStyle.icon(for: place.name).map { "\($0) " } ?? "")\(place.name)").font(.body.weight(.semibold))
            Text(String(format: "%.4f, %.4f · r %d m", place.latitude, place.longitude, Int(place.radiusMeters.rounded())))
              .font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      .onDelete { offsets in offsets.map { places.knownPlaces[$0] }.forEach(places.deletePlace) }

      DisclosureGroup("Add place") {
        TextField("Name", text: $addName)
        HStack {
          TextField("Latitude", text: $addLat).keyboardType(.numbersAndPunctuation)
          TextField("Longitude", text: $addLng).keyboardType(.numbersAndPunctuation)
        }
        HStack {
          TextField("Radius (m)", text: $addRadius).keyboardType(.numberPad)
          Button("Use current") { useCurrent() }.buttonStyle(.bordered)
        }
        if !gpsStatus.isEmpty { Text(gpsStatus).font(.caption).foregroundStyle(.secondary) }
        Button("Add place") {
          if places.addPlace(name: addName, latitude: Double(addLat), longitude: Double(addLng), radius: Double(addRadius), from: "form") {
            addName = ""
            addLat = ""
            addLng = ""
            addRadius = "100"
            gpsStatus = ""
          }
        }
      }
      DisclosureGroup("Import places (JSON)") {
        TextField(#"[{"name":"Home","lat":47.64,"lon":-122.30,"radiusMeters":100}]"#, text: $importJSON, axis: .vertical)
          .font(.caption.monospaced()).lineLimit(3...6)
        Button("Import places") {
          places.importPlacesJSON(importJSON)
          importJSON = ""
        }
        .disabled(importJSON.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    } header: {
      Text("Known places (\(places.knownPlaces.count))")
    }
  }

  /// A fresh precise fix for the form; one older than thirty seconds is refused, with how old it was.
  private func useCurrent() {
    gpsStatus = "Getting a fresh GPS fix…"
    tracker.requestFix(reason: "use_current") { location in
      guard let location else {
        gpsStatus = tracker.authorization == .denied ? "Location permission denied." : "No fix: try again outdoors."
        return
      }
      let age = -location.timestamp.timeIntervalSinceNow
      if age > 30 {
        gpsStatus = "GPS reading is \(Int(age))s old — try again outdoors."
        return
      }
      addLat = String(format: "%.6f", location.coordinate.latitude)
      addLng = String(format: "%.6f", location.coordinate.longitude)
      gpsStatus = "Got fix: ±\(Int(location.horizontalAccuracy.rounded())) m accuracy."
    }
  }

  // MARK: - tracking and retention (stories 040, 041)

  private var trackingSection: some View {
    Section {
      Toggle("Background tracking", isOn: Binding(get: { tracker.trackingOn }, set: { tracker.setTracking($0, from: "switch") }))
      if !tracker.trackingNote.isEmpty {
        Text(tracker.trackingNote).font(.footnote).foregroundStyle(.orange)
      }
      Stepper(value: Binding(get: { places.retentionDays }, set: { places.setRetention($0, from: "stepper") }), in: 1...365) {
        LabeledContent("Keep", value: "\(places.retentionDays) day\(places.retentionDays == 1 ? "" : "s")")
      }
      LabeledContent("Points stored", value: "\(places.pointCount)")
      LabeledContent("Location access", value: tracker.permissionText)
    } header: {
      Text("Tracking")
    } footer: {
      Text("Points stay on the phone. Older ones than the retention are deleted when the app opens and when the number is lowered.")
    }
  }
}

// MARK: - a day card (story 046)

struct DayCard: View {
  let day: PlaceDaySummary
  @ObservedObject var places: PlacesModel
  let expanded: Bool
  let onTap: () -> Void

  private var maxMinutes: Int {
    max(day.places.first?.totalMinutes ?? 0, day.transitMinutes, day.noDataMinutes, 1)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(PlacesDaily.dayHeader(day.dateKey)).font(.headline)
        Spacer()
        Text(PlacesDaily.formatHours(day.elapsedMinutes)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
      }
      strip
      ForEach(day.places, id: \.placeId) { place in
        row(
          place.placeId, minutes: place.totalMinutes, color: Color(hex: places.color(place.placeId)),
          name: PlaceStyle.isUnnamed(place.placeId) ? { places.startNaming(place.placeId, on: day) } : nil)
      }
      if day.transitMinutes > 0 { row("—transit—", minutes: day.transitMinutes, color: Color(hex: PlaceStyle.transit).opacity(0.55), dim: true) }
      if day.noDataMinutes > 0 { row("—no data—", minutes: day.noDataMinutes, color: Color(hex: PlaceStyle.noData), dim: true) }
      if expanded {
        Divider()
        ForEach(Array(day.visits.enumerated()), id: \.offset) { _, v in
          HStack(spacing: 8) {
            Circle().fill(Color(hex: places.color(v.placeId))).frame(width: 8, height: 8)
            Text("\(AccessoryLog.clockTime(Geo.date(v.startTime)))–\(AccessoryLog.clockTime(Geo.date(v.endTime)))")
              .font(.caption.monospacedDigit()).frame(width: 110, alignment: .leading)
            Text(v.placeId).font(.caption).lineLimit(1)
            Spacer()
            Text(PlacesDaily.formatHours(v.durationMinutes)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
          }
        }
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: onTap)
    .padding(.vertical, 4)
  }

  /// The day in time order: stays in their colour, transit faded, no data grey, the rest of today dimmest.
  private var strip: some View {
    GeometryReader { geo in
      HStack(spacing: 0) {
        ForEach(Array(day.stripSegments.enumerated()), id: \.offset) { _, seg in
          Rectangle().fill(color(seg))
            .frame(width: max(0, geo.size.width * (seg.endOffsetMs - seg.startOffsetMs) / day.dayLengthMs))
        }
      }
    }
    .frame(height: 10).clipShape(RoundedRectangle(cornerRadius: 3))
  }

  private func color(_ seg: DayStripSegment) -> Color {
    switch seg.kind {
    case .stay: return Color(hex: places.color(seg.placeId ?? ""))
    case .transit: return Color(hex: PlaceStyle.transit).opacity(0.55)
    case .noData: return Color(hex: PlaceStyle.noData)
    case .future: return Color(hex: PlaceStyle.future)
    }
  }

  private func row(_ label: String, minutes: Int, color: Color, dim: Bool = false, name: (() -> Void)? = nil) -> some View {
    HStack(spacing: 8) {
      GeometryReader { geo in
        RoundedRectangle(cornerRadius: 2).fill(color)
          .frame(width: max(geo.size.width * Double(minutes) / Double(maxMinutes), geo.size.width * 0.02))
      }
      .frame(width: 90, height: 8)
      Text(label).font(.subheadline).foregroundStyle(dim ? .secondary : .primary).lineLimit(1)
      Spacer()
      Text(PlacesDaily.formatHours(minutes)).font(.subheadline.monospacedDigit()).foregroundStyle(dim ? .secondary : .primary)
      if let name {
        Button(action: name) { Image(systemName: "plus.circle.fill").foregroundStyle(Color(hex: PlaceStyle.unknownPlace)) }
          .buttonStyle(.borderless)
          .accessibilityLabel("Name \(label)")
      }
    }
  }
}

// MARK: - naming a place (story 047)

struct NamingSheet: View {
  let card: NamingCard
  @ObservedObject var places: PlacesModel
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var radius: String

  init(card: NamingCard, places: PlacesModel) {
    self.card = card
    self.places = places
    switch card {
    case .name(_, _, let r), .merge(_, _, let r, _): _radius = State(initialValue: String(Int(r.rounded())))
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        switch card {
        case .name(let source, let centroid, _):
          Section {
            TextField("Place name", text: $name)
            TextField("Radius (m)", text: $radius).keyboardType(.numberPad)
          } header: {
            Text("Name \(source)")
          } footer: {
            Text(String(format: "%.5f, %.5f", centroid.latitude, centroid.longitude)).font(.caption.monospaced())
          }
          Section {
            Button("Save") {
              places.addPlace(name: name, latitude: centroid.latitude, longitude: centroid.longitude, radius: Double(radius), from: "name_place")
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
          }
        case .merge(let source, _, _, let s):
          Section {
            Text("**\(source)** is \(Int(s.distance.rounded())) m from **\(s.nearest.name)**.")
            Text(
              "Expanding would grow radius \(Int(s.nearest.radiusMeters.rounded())) m → \(Int(s.grown.radiusMeters.rounded())) m and shift the centre \(Int(s.shift.rounded())) m."
            )
            if s.others > 0 { Text("(+\(s.others) more within 500 m)").font(.caption).foregroundStyle(.secondary) }
          } header: {
            Text("Nearby known place")
          }
          Section {
            Button("Expand \(s.nearest.name)") { places.expand(s, source: source) }
            Button("Create new place") { places.createNew(from: card) }
          }
        }
      }
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
  }
}

/// The system share sheet for the export.
struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
