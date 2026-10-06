//  Place icons (story 057): the name's guess, Apple Maps' nearest category, the order they win in, and the icons
//  remembered beside the known places.

import XCTest

@testable import ContextCore

#if canImport(AppKit)
  import AppKit
#endif

final class PlaceIconsTests: XCTestCase {
  func testGuessFromTheName() {
    XCTAssertEqual(PlaceIcons.guess(fromName: "Home"), "house.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Mom's House"), "house.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Work"), "briefcase.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "My office"), "briefcase.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Kettlebility gym"), "dumbbell.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "24 Hour Fitness"), "dumbbell.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Milstead Coffee"), "cup.and.saucer.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Café Allegro"), "cup.and.saucer.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Gas Works Park"), "tree.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Lakeside School"), "graduationcap.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "PCC Market"), "cart.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Thai restaurant"), "fork.knife")
    XCTAssertEqual(PlaceIcons.guess(fromName: "SEA airport"), "airplane")
    XCTAssertEqual(PlaceIcons.guess(fromName: "St. Mark's Cathedral"), "building.columns.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Dr. Lee's clinic"), "cross.case.fill")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Golden Gardens Beach"), "beach.umbrella.fill")
    // Whole words only, and the first rule wins.
    XCTAssertNil(PlaceIcons.guess(fromName: "Homestead"))
    XCTAssertNil(PlaceIcons.guess(fromName: "Kettlebility"))
    XCTAssertNil(PlaceIcons.guess(fromName: "Milstead & Co"))
    XCTAssertNil(PlaceIcons.guess(fromName: "Barista"), "bar is a word, not a prefix")
    XCTAssertEqual(PlaceIcons.guess(fromName: "Home office"), "house.fill")
  }

  private let gym = KnownPlace(id: 13, name: "Kettlebility", latitude: 47.6762, longitude: -122.3187, radiusMeters: 100)

  /// A point `metres` north of the gym.
  private func north(_ metres: Double) -> Coordinate {
    Coordinate(latitude: gym.latitude + metres / 111_195, longitude: gym.longitude)
  }

  func testTheNearestPointOfInterestDecidesOnlyWhenItHasAnIcon() {
    let fitness = PointOfInterest(category: "MKPOICategoryFitnessCenter", coordinate: north(20))
    let cafe = PointOfInterest(category: "MKPOICategoryCafe", coordinate: north(60))
    let hit = PlaceIcons.nearest([cafe, fitness], to: gym.coordinate, within: 100)
    XCTAssertEqual(hit?.symbol, "dumbbell.fill")
    XCTAssertEqual(hit?.category, "MKPOICategoryFitnessCenter")
    XCTAssertEqual(hit?.distance ?? 0, 20, accuracy: 0.5)
    // Outside the radius: nothing.
    XCTAssertNil(PlaceIcons.nearest([PointOfInterest(category: "MKPOICategoryRestaurant", coordinate: north(150))], to: gym.coordinate, within: 100))
    // The real Kettlebility: the nearest thing is uncategorised (the gym itself), a food market 23 m away is not it.
    let real = [
      PointOfInterest(category: nil, coordinate: north(11)),
      PointOfInterest(category: "MKPOICategoryFoodMarket", coordinate: north(23)),
    ]
    XCTAssertNil(PlaceIcons.nearest(real, to: gym.coordinate, within: 100))
    XCTAssertNil(PlaceIcons.nearest([PointOfInterest(category: "MKPOICategoryBank", coordinate: north(5)), fitness], to: gym.coordinate, within: 100))
  }

  func testTheBusinessThePlaceIsNamedAfterWins() {
    // As Apple Maps answered on the simulator for the fixture's two unguessable places.
    let milstead = KnownPlace(id: 2, name: "Milstead & Co", latitude: gym.latitude, longitude: gym.longitude, radiusMeters: 50)
    let named = [
      PointOfInterest(name: "Milstead & Co.", category: "MKPOICategoryCafe", coordinate: north(251)),
      PointOfInterest(name: "Milstead & Co Parking", category: "MKPOICategoryParking", coordinate: north(30)),
    ]
    let nearby = [PointOfInterest(name: "Taco place", category: "MKPOICategoryRestaurant", coordinate: north(8))]
    XCTAssertEqual(PlaceIcons.byName(named, for: milstead)?.symbol, "cup.and.saucer.fill", "the same name beats a nearer one holding it")
    XCTAssertEqual(PlaceIcons.byName([named[1]], for: milstead)?.symbol, "car.fill", "a name holding the place's still matches")
    XCTAssertEqual(
      PlaceIcons.stored(named: [named[0]], nearby: nearby, for: milstead),
      StoredPlaceIcon(symbol: "cup.and.saucer.fill", source: .maps, category: "MKPOICategoryCafe"))
    // Too far to be the same place, or another name: the nearest point of interest decides.
    var far = named[0]
    far.coordinate = north(600)
    XCTAssertEqual(PlaceIcons.stored(named: [far], nearby: nearby, for: milstead).symbol, "fork.knife")
    let other = PointOfInterest(name: "Fremont Coffee", category: "MKPOICategoryCafe", coordinate: north(10))
    XCTAssertNil(PlaceIcons.byName([other], for: milstead))
    XCTAssertNil(PlaceIcons.byName([named[0]], for: KnownPlace(id: 3, name: "Co", latitude: 0, longitude: 0, radiusMeters: 50)), "too short a name to match on")
  }

  func testWhatALookupIsRememberedAs() {
    XCTAssertEqual(
      PlaceIcons.stored(named: [], nearby: [PointOfInterest(category: "MKPOICategoryFitnessCenter", coordinate: north(30))], for: gym),
      StoredPlaceIcon(symbol: "dumbbell.fill", source: .maps, category: "MKPOICategoryFitnessCenter"))
    XCTAssertEqual(PlaceIcons.stored(named: [], nearby: [], for: gym), StoredPlaceIcon(symbol: "mappin", source: .default))
    // A small place still searches 50 m.
    let tiny = KnownPlace(id: 1, name: "Somewhere", latitude: gym.latitude, longitude: gym.longitude, radiusMeters: 20)
    XCTAssertEqual(PlaceIcons.searchRadius(for: tiny), 50)
    XCTAssertEqual(
      PlaceIcons.stored(named: [], nearby: [PointOfInterest(category: "MKPOICategoryCafe", coordinate: north(40))], for: tiny).source, .maps)
  }

  func testChosenThenNameThenMapsThenAPinWaitingForMaps() {
    let chosen = StoredPlaceIcon(symbol: "heart.fill", source: .chosen)
    let maps = StoredPlaceIcon(symbol: "dumbbell.fill", source: .maps, category: "MKPOICategoryFitnessCenter")
    XCTAssertEqual(PlaceIcons.resolve(name: "Home", stored: chosen).symbol, "heart.fill", "a choice is never guessed over")
    XCTAssertEqual(PlaceIcons.resolve(name: "Home", stored: chosen).source, .chosen)
    XCTAssertEqual(PlaceIcons.resolve(name: "Home", stored: maps).source, .name, "a renamed place's name wins over old maps")
    XCTAssertEqual(PlaceIcons.resolve(name: "Kettlebility", stored: maps), PlaceIcon(symbol: "dumbbell.fill", source: .maps, category: "MKPOICategoryFitnessCenter", needsLookup: false))
    XCTAssertEqual(
      PlaceIcons.resolve(name: "Kettlebility", stored: StoredPlaceIcon(symbol: "mappin", source: .default)),
      PlaceIcon(symbol: "mappin", source: .default, category: nil, needsLookup: false))
    XCTAssertEqual(PlaceIcons.resolve(name: "Kettlebility", stored: nil), PlaceIcon(symbol: "mappin", source: .default, category: nil, needsLookup: true))
  }

  func testTheTextUnderTheIcon() {
    XCTAssertEqual(PlaceIcons.categoryName("MKPOICategoryFitnessCenter"), "Fitness center")
    XCTAssertEqual(PlaceIcons.categoryName("MKPOICategoryCafe"), "Cafe")
    XCTAssertEqual(PlaceIcons.categoryName("MKPOICategoryEVCharger"), "EV charger")
    XCTAssertEqual(
      PlaceIcons.sourceText(PlaceIcon(symbol: "dumbbell.fill", source: .maps, category: "MKPOICategoryFitnessCenter", needsLookup: false)),
      "From Apple Maps: Fitness center")
    XCTAssertEqual(PlaceIcons.sourceText(PlaceIcons.resolve(name: "Home", stored: nil)), "Guessed from the name")
    XCTAssertEqual(PlaceIcons.sourceText(PlaceIcons.resolve(name: "X", stored: nil)), "Asking Apple Maps…")
  }

  func testTwentyChoicesAndEverySymbolExists() {
    XCTAssertEqual(PlaceIcons.choices.count, 20)
    XCTAssertEqual(Set(PlaceIcons.choices).count, 20)
    // Every icon a guess can give is one the picker offers, so a guess can always be chosen back.
    let guessed = Set(PlaceIcons.categorySymbols.values).union(
      ["Home", "Work", "gym", "coffee", "pizza", "store", "park", "school", "clinic", "airport", "beach", "church", "library", "bar", "hotel", "pool", "parking"]
        .compactMap(PlaceIcons.guess(fromName:)))
    XCTAssertTrue(guessed.isSubset(of: Set(PlaceIcons.choices)), "\(guessed.subtracting(PlaceIcons.choices))")
    #if canImport(AppKit)
      for symbol in PlaceIcons.choices {
        XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), symbol)
      }
    #endif
  }

  func testIconsAreRememberedBesideTheKnownPlaces() throws {
    let store = try LocationStore(db: SQLiteDatabase(path: ":memory:"))
    let id = try store.addKnownPlace(name: "Kettlebility", latitude: gym.latitude, longitude: gym.longitude, radiusMeters: 100)
    let other = try store.addKnownPlace(name: "Home", latitude: 47.64, longitude: -122.30, radiusMeters: 100)
    let maps = StoredPlaceIcon(symbol: "dumbbell.fill", source: .maps, category: "MKPOICategoryFitnessCenter")
    try store.setPlaceIcon(maps, for: id)
    try store.setPlaceIcon(StoredPlaceIcon(symbol: "heart.fill", source: .chosen), for: other)
    XCTAssertEqual(try store.placeIcons(), [id: maps, other: StoredPlaceIcon(symbol: "heart.fill", source: .chosen)])
    // Growing a place forgets Apple Maps' answer for the old disc, but never a choice.
    try store.updateKnownPlace(id: id, circle: PlaceCircle(latitude: gym.latitude, longitude: gym.longitude, radiusMeters: 150))
    try store.updateKnownPlace(id: other, circle: PlaceCircle(latitude: 47.64, longitude: -122.30, radiusMeters: 150))
    XCTAssertEqual(try store.placeIcons(), [other: StoredPlaceIcon(symbol: "heart.fill", source: .chosen)])
    try store.clearPlaceIcon(for: other)
    XCTAssertEqual(try store.placeIcons(), [:])
    // Deleting a place deletes its icon; the known_places table itself is unchanged in shape.
    try store.setPlaceIcon(maps, for: id)
    try store.deleteKnownPlace(id: id)
    XCTAssertEqual(try store.placeIcons(), [:])
  }
}
