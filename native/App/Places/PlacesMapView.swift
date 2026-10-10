//  The map (stories 048–051): Apple Maps with a pin per known place in its colour, You, and today's path, framed
//  to hold all of them; locate, copy and expand in the corners. The same view embedded and full screen; full
//  screen it also shows the places with no name yet as grey dots, a tap opening their visits (story 056).

import ContextCore
import MapKit
import SwiftUI

extension Coordinate {
  var cl: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

struct PlacesMapView: View {
  @ObservedObject var places: PlacesModel
  @ObservedObject var tracker: LocationTracker
  let log: SessionLog
  let fullscreen: Bool
  let onToggleFullscreen: () -> Void

  @State private var position: MapCameraPosition = .automatic
  @State private var framed = false
  @State private var copied = false

  private var you: Coordinate? {
    tracker.you.map { Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
  }

  /// The grey dots: full screen only, so the embedded map stays uncluttered.
  private var unnamed: [UnnamedPlace] { fullscreen ? places.unnamed : [] }

  private var selected: UnnamedPlace? {
    places.selectedUnnamed.flatMap { id in unnamed.first { $0.placeId == id } }
  }

  private var region: MKCoordinateRegion? {
    PlaceStyle.region(
      places: places.knownPlaces.map(\.coordinate) + unnamed.map(\.centroid), you: you,
      path: places.shownRoute.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
    ).map {
      MKCoordinateRegion(center: $0.center.cl, span: MKCoordinateSpan(latitudeDelta: $0.latitudeDelta, longitudeDelta: $0.longitudeDelta))
    }
  }

  var body: some View {
    Map(position: $position) {
      if places.shownRoute.count > 1 {
        MapPolyline(coordinates: places.shownRoute.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
          .stroke(Color(hex: PlaceStyle.you).opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      // Drawn first, so a named pin sits on top where they meet.
      ForEach(unnamed) { place in
        Annotation("", coordinate: place.centroid.cl, anchor: .center) {
          UnnamedPin(place: place, selected: place.placeId == places.selectedUnnamed) {
            places.selectUnnamed(place.placeId == places.selectedUnnamed ? nil : place.placeId, from: "tap")
          }
        }
      }
      ForEach(places.knownPlaces) { place in
        Annotation("", coordinate: place.coordinate.cl, anchor: .center) {
          PlacePin(name: place.name, symbol: places.icon(place).symbol, color: Color(hex: places.color(place.name)))
        }
      }
      if let you {
        Annotation("", coordinate: you.cl, anchor: .center) { YouPin() }
      }
    }
    .mapStyle(.standard(pointsOfInterest: .excludingAll))
    .overlay(alignment: .topTrailing) {
      VStack(spacing: 8) {
        control(fullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", label: fullscreen ? "Collapse map" : "Expand map") {
          log.event("ui", ["action": fullscreen ? "map_collapse" : "map_expand"])
          onToggleFullscreen()
        }
        if you != nil {
          control("location.fill", label: "Find me") { findMe() }
        }
      }
      .padding(8)
    }
    .overlay(alignment: .bottom) {
      if let selected {
        UnnamedPlaceCard(place: selected, days: PlacesModel.breakdownDays) {
          places.startNaming(selected)
        } onClose: {
          places.selectUnnamed(nil, from: "close")
        }
        .padding(.horizontal, 12).padding(.bottom, fullscreen ? 28 : 8)
      }
    }
    .overlay(alignment: .bottomLeading) {
      if let you, selected == nil {
        Button {
          UIPasteboard.general.string = PlaceStyle.coordinateText(you)
          log.event("ui", ["action": "copy_coordinates", "accuracy": Int(tracker.you?.horizontalAccuracy.rounded() ?? -1)])
          copied = true
          Task {
            try? await Task.sleep(for: .milliseconds(1500))
            copied = false
          }
        } label: {
          Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
            .font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityLabel("Copy coordinates")
        .padding(8)
      }
    }
    .overlay(alignment: .bottomTrailing) {
      // #252: which path the map draws.
      if selected == nil {
        HStack(spacing: 0) {
          rangeButton("Today", days: 1)
          rangeButton("7 days", days: 7)
        }
        .padding(2)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(8)
      }
    }
    .onAppear(perform: frame)
    .onChange(of: places.knownPlaces) { _, _ in frame() }
    .onChange(of: places.shownRoute.count) { _, _ in frame() }
    .onChange(of: places.routeDays) { _, _ in framed = false; frame() }  // a new range: frame it afresh
    .onChange(of: places.unnamed.count) { _, _ in frame() }
  }

  private func rangeButton(_ title: String, days: Int) -> some View {
    let on = places.routeDays == days
    return Button {
      withAnimation(.snappy) { places.setRouteDays(days) }
    } label: {
      Text(title).font(.caption.weight(.semibold))
        .padding(.horizontal, 9).padding(.vertical, 4)
        .foregroundStyle(on ? Color.white : Color.primary)
        .background(on ? Color(hex: PlaceStyle.you) : Color.clear, in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(on ? .isSelected : [])
    .accessibilityIdentifier("places-range-\(days)")
  }

  /// Frames every pin, You and the path, until Igor moves the map himself.
  private func frame() {
    guard let region else { return }
    if !framed || position.positionedByUser == false {
      position = .region(region)
      framed = true
    }
  }

  private func findMe() {
    guard let you else { return }
    log.event("ui", ["action": "find_me"])
    withAnimation {
      position = .region(
        MKCoordinateRegion(center: you.cl, span: MKCoordinateSpan(latitudeDelta: PlaceStyle.findMeDelta, longitudeDelta: PlaceStyle.findMeDelta)))
    }
  }

  private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).frame(width: 36, height: 36)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    .accessibilityLabel(label)
  }
}

/// A known place: its icon in a ring of its colour (story 057), and its name in a small chip under it.
struct PlacePin: View {
  let name: String
  let symbol: String
  let color: Color

  var body: some View {
    VStack(spacing: 2) {
      Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
        .frame(width: 30, height: 30)
        .background(Circle().fill(Color(white: 0.1).opacity(0.85)))
        .overlay(Circle().stroke(color, lineWidth: 3))
      Text(name).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
        .padding(.horizontal, 5).padding(.vertical, 2).background(Color.black.opacity(0.65), in: Capsule())
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(name)
    .accessibilityIdentifier("place-\(name)")
    .accessibilityValue(symbol)
  }
}

/// A place with no name yet: a grey dot sized by the hours there and a small chip saying them. Quieter than a
/// named pin on purpose; white-ringed while its card is open.
struct UnnamedPin: View {
  let place: UnnamedPlace
  let selected: Bool
  let onTap: () -> Void

  var body: some View {
    let size = UnnamedPlaces.dotDiameter(minutes: place.totalMinutes)
    Button(action: onTap) {
      VStack(spacing: 2) {
        Circle().fill(Color(white: 0.55).opacity(0.8)).frame(width: size, height: size)
          .overlay(Circle().stroke(selected ? .white : Color(white: 0.85).opacity(0.7), lineWidth: selected ? 3 : 1.5))
        Text(PlacesDaily.formatHours(place.totalMinutes)).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.9))
          .padding(.horizontal, 4).padding(.vertical, 1).background(Color.black.opacity(0.45), in: Capsule())
      }
      // A finger-sized target around even the smallest dot.
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(place.placeId), \(PlacesDaily.formatHours(place.totalMinutes))")
    .accessibilityIdentifier("unnamed-\(place.placeId)")
  }
}

/// The card a grey dot opens: when and how long, and *Name this place*.
struct UnnamedPlaceCard: View {
  static let maxVisits = 5
  let place: UnnamedPlace
  let days: Int
  let onName: () -> Void
  let onClose: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(place.placeId).font(.headline)
          Text(UnnamedPlaces.summaryLine(place, days: days)).font(.subheadline).foregroundStyle(.secondary)
        }
        Spacer()
        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
        }
        .accessibilityLabel("Close")
      }
      VStack(alignment: .leading, spacing: 3) {
        ForEach(Array(place.visits.prefix(Self.maxVisits).enumerated()), id: \.offset) { _, visit in
          Text(UnnamedPlaces.visitLine(visit)).font(.caption.monospacedDigit())
        }
        if place.visits.count > Self.maxVisits {
          Text("+\(place.visits.count - Self.maxVisits) earlier").font(.caption).foregroundStyle(.secondary)
        }
      }
      Button(action: onName) {
        Label("Name this place", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("name-this-place")
    }
    .padding(14)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
  }
}

/// You: a cyan diamond with a halo.
struct YouPin: View {
  var body: some View {
    ZStack {
      Circle().fill(Color(hex: PlaceStyle.you).opacity(0.25)).frame(width: 34, height: 34)
      Rectangle().fill(Color(hex: PlaceStyle.you)).frame(width: 13, height: 13).rotationEffect(.degrees(45))
        .overlay(Rectangle().stroke(.white, lineWidth: 2).frame(width: 13, height: 13).rotationEffect(.degrees(45)))
    }
    .accessibilityLabel("You")
  }
}

/// #160: where the stay being named is, at the top of the naming card. A picture for looking, not for picking: it
/// does not pan or zoom. The name card's circle follows the radius as it is typed; the merge card adds the nearest
/// known place and its circle as it is now.
struct NamingMap: View {
  let centre: Coordinate
  /// The circle the new place would cover, metres; nil on the merge card.
  let radius: Double?
  var nearest: KnownPlace?

  var body: some View {
    Map(initialPosition: .region(region), interactionModes: []) {
      if let radius, radius > 0 {
        MapCircle(center: centre.cl, radius: radius).foregroundStyle(.orange.opacity(0.2)).stroke(.orange, lineWidth: 2)
      }
      if let nearest {
        let at = CLLocationCoordinate2D(latitude: nearest.latitude, longitude: nearest.longitude)
        MapCircle(center: at, radius: nearest.radiusMeters).foregroundStyle(.blue.opacity(0.15)).stroke(.blue, lineWidth: 2)
        Marker(nearest.name, coordinate: at).tint(.blue)
      }
      Marker("Here", systemImage: "mappin", coordinate: centre.cl).tint(.orange)
    }
    .frame(height: 180)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityIdentifier("naming-map")
  }

  /// Room for the circle (or both places) with a margin.
  private var region: MKCoordinateRegion {
    guard let nearest else {
      let span = max(4 * (radius ?? 100), 400)
      return MKCoordinateRegion(center: centre.cl, latitudinalMeters: span, longitudinalMeters: span)
    }
    let mid = CLLocationCoordinate2D(
      latitude: (centre.latitude + nearest.latitude) / 2, longitude: (centre.longitude + nearest.longitude) / 2)
    let apart = CLLocation(latitude: centre.latitude, longitude: centre.longitude)
      .distance(from: CLLocation(latitude: nearest.latitude, longitude: nearest.longitude))
    let span = max(2.5 * (apart + nearest.radiusMeters), 400)
    return MKCoordinateRegion(center: mid, latitudinalMeters: span, longitudinalMeters: span)
  }
}
