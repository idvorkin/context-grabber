//  Asking Apple Maps what is at a known place (story 057): the business it is named after, searched by name around
//  it, and the points of interest within its radius; PlaceIcons decides from both. A failure (no network, MapKit
//  throttling) is thrown, so the caller can leave the place to be asked again; an empty answer is an answer.

import ContextCore
import MapKit

enum PlaceIconLookup {
  struct Answer {
    var named: [PointOfInterest]
    var nearby: [PointOfInterest]
  }

  static func ask(about place: KnownPlace) async throws -> Answer {
    let radius = PlaceIcons.searchRadius(for: place)
    let byName = MKLocalSearch.Request()
    byName.naturalLanguageQuery = place.name
    byName.resultTypes = .pointOfInterest
    byName.region = MKCoordinateRegion(
      center: place.coordinate.cl, latitudinalMeters: 2 * PlaceIcons.nameMatchMeters, longitudinalMeters: 2 * PlaceIcons.nameMatchMeters)
    async let named = run(MKLocalSearch(request: byName))
    async let nearby = run(MKLocalSearch(request: MKLocalPointsOfInterestRequest(center: place.coordinate.cl, radius: radius)))
    return try await Answer(named: named, nearby: nearby)
  }

  private static func run(_ search: MKLocalSearch) async throws -> [PointOfInterest] {
    do {
      return try await search.start().mapItems.map { item in
        let c: CLLocationCoordinate2D
        if #available(iOS 26, *) { c = item.location.coordinate } else { c = item.placemark.coordinate }
        return PointOfInterest(
          name: item.name, category: item.pointOfInterestCategory?.rawValue,
          coordinate: Coordinate(latitude: c.latitude, longitude: c.longitude))
      }
    } catch let error as MKError where error.code == .placemarkNotFound {
      // MapKit's way of saying "nothing here": an answer, not a failure.
      return []
    }
  }
}
