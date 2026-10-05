//  The map (stories 048–051): Apple Maps with a pin per known place in its colour, You, and today's path, framed
//  to hold all of them; locate, copy and expand in the corners. The same view embedded and full screen.

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

  private var region: MKCoordinateRegion? {
    PlaceStyle.region(
      places: places.knownPlaces.map(\.coordinate), you: you,
      path: places.route.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
    ).map {
      MKCoordinateRegion(center: $0.center.cl, span: MKCoordinateSpan(latitudeDelta: $0.latitudeDelta, longitudeDelta: $0.longitudeDelta))
    }
  }

  var body: some View {
    Map(position: $position) {
      if places.route.count > 1 {
        MapPolyline(coordinates: places.route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
          .stroke(Color(hex: PlaceStyle.you).opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      ForEach(places.knownPlaces) { place in
        Annotation("", coordinate: place.coordinate.cl, anchor: .center) {
          PlacePin(name: place.name, color: Color(hex: places.color(place.name)))
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
    .overlay(alignment: .bottomLeading) {
      if let you {
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
    .onAppear(perform: frame)
    .onChange(of: places.knownPlaces) { _, _ in frame() }
    .onChange(of: places.route.count) { _, _ in frame() }
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

/// A known place: its icon in a ring of its colour, or a dot with a name chip.
struct PlacePin: View {
  let name: String
  let color: Color

  var body: some View {
    if let icon = PlaceStyle.icon(for: name) {
      Text(icon).font(.system(size: 16)).frame(width: 30, height: 30)
        .background(Circle().fill(Color(white: 0.1).opacity(0.85)))
        .overlay(Circle().stroke(color, lineWidth: 3))
        .accessibilityLabel(name)
    } else {
      VStack(spacing: 2) {
        Circle().fill(color).frame(width: 14, height: 14).overlay(Circle().stroke(.white, lineWidth: 2))
        Text(name).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
          .padding(.horizontal, 5).padding(.vertical, 2).background(Color.black.opacity(0.65), in: Capsule())
      }
    }
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
