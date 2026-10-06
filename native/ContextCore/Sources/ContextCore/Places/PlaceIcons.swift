//  Every known place's icon (story 057): an SF Symbol guessed from the name, else from the nearest Apple Maps point
//  of interest within the place's radius, else a plain pin; a chosen one wins over every guess and is never guessed
//  over. The deciding is here; asking Apple Maps and remembering the answer belong to the app.

import Foundation

/// Where a place's icon came from; the raw value is what is stored and logged.
public enum PlaceIconSource: String, Sendable, Codable, CaseIterable {
  case name, maps, `default`, chosen
}

/// An icon as remembered beside a known place: a chosen one, or Apple Maps' answer (a plain pin when it had none).
public struct StoredPlaceIcon: Equatable, Sendable {
  public var symbol: String
  public var source: PlaceIconSource
  /// The point of interest's category for a `maps` icon ("MKPOICategoryCafe").
  public var category: String?
  public init(symbol: String, source: PlaceIconSource, category: String? = nil) {
    self.symbol = symbol
    self.source = source
    self.category = category
  }
}

public struct PlaceIcon: Equatable, Sendable {
  public var symbol: String
  public var source: PlaceIconSource
  public var category: String?
  /// True while nothing decided it yet: the plain pin stands in until Apple Maps has been asked.
  public var needsLookup: Bool
}

/// A point of interest Apple Maps returned: its name, its category's raw value and where it is.
public struct PointOfInterest: Equatable, Sendable {
  public var name: String?
  public var category: String?
  public var coordinate: Coordinate
  public init(name: String? = nil, category: String?, coordinate: Coordinate) {
    self.name = name
    self.category = category
    self.coordinate = coordinate
  }
}

public enum PlaceIcons {
  public static let pin = "mappin"

  /// The picker's twenty, in its order.
  public static let choices = [
    "house.fill", "briefcase.fill", "dumbbell.fill", "cup.and.saucer.fill", "fork.knife",
    "cart.fill", "tree.fill", "graduationcap.fill", "cross.case.fill", "airplane",
    "beach.umbrella.fill", "building.columns.fill", "book.fill", "wineglass.fill", "bed.double.fill",
    "figure.pool.swim", "person.2.fill", "car.fill", "heart.fill", pin,
  ]

  private static let nameRules: [(words: Set<String>, symbol: String)] = [
    (["home", "house", "apartment", "apt", "condo"], "house.fill"),
    (["work", "office", "hq"], "briefcase.fill"),
    (["gym", "fitness", "crossfit", "yoga", "pilates", "dojo"], "dumbbell.fill"),
    (["coffee", "cafe", "café", "espresso", "starbucks"], "cup.and.saucer.fill"),
    (["restaurant", "diner", "bistro", "pizza", "sushi", "grill", "kitchen", "eatery"], "fork.knife"),
    (["store", "market", "grocery", "shop", "supermarket", "mall", "costco", "safeway", "qfc"], "cart.fill"),
    (["park", "trail", "garden", "forest"], "tree.fill"),
    (["school", "university", "college", "campus"], "graduationcap.fill"),
    (["hospital", "clinic", "doctor", "dentist", "medical"], "cross.case.fill"),
    (["airport"], "airplane"),
    (["beach"], "beach.umbrella.fill"),
    // SF Symbols has no church; the columns stand for any place of worship, and a museum.
    (["church", "temple", "synagogue", "mosque", "chapel", "cathedral", "museum"], "building.columns.fill"),
    (["library"], "book.fill"),
    (["bar", "pub", "brewery", "tavern", "winery"], "wineglass.fill"),
    (["hotel", "motel", "inn", "airbnb"], "bed.double.fill"),
    (["pool", "swim", "aquatic"], "figure.pool.swim"),
    (["parking", "garage"], "car.fill"),
  ]

  /// The icon a whole word of the name gives away ("Mom's House", not "Householder"); the first rule wins.
  public static func guess(fromName name: String) -> String? {
    let words = Set(name.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map(String.init))
    return nameRules.first { !$0.words.isDisjoint(with: words) }?.symbol
  }

  /// Apple Maps' categories (`MKPointOfInterestCategory` raw values) that say what a place is.
  public static let categorySymbols: [String: String] = [
    "MKPOICategoryFitnessCenter": "dumbbell.fill",
    "MKPOICategoryRockClimbing": "dumbbell.fill",
    "MKPOICategoryCafe": "cup.and.saucer.fill",
    "MKPOICategoryBakery": "cup.and.saucer.fill",
    "MKPOICategoryRestaurant": "fork.knife",
    "MKPOICategoryFoodMarket": "cart.fill",
    "MKPOICategoryStore": "cart.fill",
    "MKPOICategoryPark": "tree.fill",
    "MKPOICategoryNationalPark": "tree.fill",
    "MKPOICategoryCampground": "tree.fill",
    "MKPOICategoryHiking": "tree.fill",
    "MKPOICategorySchool": "graduationcap.fill",
    "MKPOICategoryUniversity": "graduationcap.fill",
    "MKPOICategoryHospital": "cross.case.fill",
    "MKPOICategoryPharmacy": "cross.case.fill",
    "MKPOICategoryAirport": "airplane",
    "MKPOICategoryBeach": "beach.umbrella.fill",
    "MKPOICategoryLibrary": "book.fill",
    "MKPOICategoryMuseum": "building.columns.fill",
    "MKPOICategoryBrewery": "wineglass.fill",
    "MKPOICategoryWinery": "wineglass.fill",
    "MKPOICategoryDistillery": "wineglass.fill",
    "MKPOICategoryNightlife": "wineglass.fill",
    "MKPOICategoryHotel": "bed.double.fill",
    "MKPOICategorySwimming": "figure.pool.swim",
    "MKPOICategoryParking": "car.fill",
    "MKPOICategoryGasStation": "car.fill",
    "MKPOICategoryEVCharger": "car.fill",
  ]

  /// "MKPOICategoryFitnessCenter" → "Fitness center", for the place's screen: a space before each capital that
  /// follows a lower-case letter ("EVCharger" is the one category that needs spelling out).
  public static func categoryName(_ raw: String) -> String {
    if raw == "MKPOICategoryEVCharger" { return "EV charger" }
    let bare = raw.hasPrefix("MKPOICategory") ? String(raw.dropFirst("MKPOICategory".count)) : raw
    var out = ""
    for ch in bare {
      if ch.isUppercase, let last = out.last, last.isLowercase { out += " " + ch.lowercased() } else { out.append(ch) }
    }
    return out
  }

  /// The search radius for Apple Maps: the place's own radius, at least 50 m.
  public static func searchRadius(for place: KnownPlace) -> Double { max(50, place.radiusMeters) }

  /// Letters and digits only, lower-cased: "Milstead & Co." → "milsteadco".
  static func normalized(_ name: String) -> String {
    String(name.lowercased().filter { $0.isLetter || $0.isNumber })
  }

  /// How far the business a place is named after may be from the place's centre. A name is strong evidence and a
  /// known place's centre can be off: Apple Maps puts "Milstead & Co." 251 m from the fixture's Milstead & Co.
  public static let nameMatchMeters = 500.0

  /// The business the place is named after, when Apple Maps finds it by that name within `nameMatchMeters` and its
  /// category has an icon: "Milstead & Co" is a café whatever stands next door.
  public static func byName(
    _ results: [PointOfInterest], for place: KnownPlace
  ) -> (symbol: String, category: String, distance: Double)? {
    let wanted = normalized(place.name)
    guard wanted.count >= 3 else { return nil }
    // The same name first ("Milstead & Co." for "Milstead & Co"), then one holding it ("Milstead & Co Parking").
    return results.compactMap { poi -> (symbol: String, category: String, distance: Double, exact: Bool)? in
      guard let category = poi.category, let symbol = categorySymbols[category], let name = poi.name.map(normalized),
        !name.isEmpty, name.contains(wanted) || wanted.contains(name)
      else { return nil }
      let d = Geo.distance(place.coordinate, poi.coordinate)
      return d <= nameMatchMeters ? (symbol, category, d, name == wanted) : nil
    }
    .min { ($0.exact ? 0 : 1, $0.distance) < ($1.exact ? 0 : 1, $1.distance) }
    .map { (symbol: $0.symbol, category: $0.category, distance: $0.distance) }
  }

  /// The nearest point of interest within `radius` of `center`, when its category has an icon. When the nearest
  /// one has none (often the place itself, uncategorised) nothing is guessed: the shop next door is not the place.
  public static func nearest(
    _ pois: [PointOfInterest], to center: Coordinate, within radius: Double
  ) -> (symbol: String, category: String, distance: Double)? {
    guard let (poi, d) = pois.map({ ($0, Geo.distance(center, $0.coordinate)) }).min(by: { $0.1 < $1.1 }), d <= radius,
      let category = poi.category, let symbol = categorySymbols[category]
    else { return nil }
    return (symbol, category, d)
  }

  /// What Apple Maps' answers are remembered as: the named business's icon, else the nearest point of interest's,
  /// else a plain pin, so the place is not asked again.
  public static func stored(named: [PointOfInterest], nearby: [PointOfInterest], for place: KnownPlace) -> StoredPlaceIcon {
    if let hit = byName(named, for: place) ?? nearest(nearby, to: place.coordinate, within: searchRadius(for: place)) {
      return StoredPlaceIcon(symbol: hit.symbol, source: .maps, category: hit.category)
    }
    return StoredPlaceIcon(symbol: pin, source: .default)
  }

  /// A place's icon now: chosen, else the name, else Apple Maps' remembered answer, else a plain pin waiting for it.
  public static func resolve(name: String, stored: StoredPlaceIcon?) -> PlaceIcon {
    if let stored, stored.source == .chosen {
      return PlaceIcon(symbol: stored.symbol, source: .chosen, category: nil, needsLookup: false)
    }
    if let symbol = guess(fromName: name) {
      return PlaceIcon(symbol: symbol, source: .name, category: nil, needsLookup: false)
    }
    if let stored {
      return PlaceIcon(symbol: stored.symbol, source: stored.source, category: stored.category, needsLookup: false)
    }
    return PlaceIcon(symbol: pin, source: .default, category: nil, needsLookup: true)
  }

  /// The line under the icon on the place's screen.
  public static func sourceText(_ icon: PlaceIcon) -> String {
    switch icon.source {
    case .chosen: return "Chosen"
    case .name: return "Guessed from the name"
    case .maps: return "From Apple Maps: \(icon.category.map(categoryName) ?? "a nearby place")"
    case .default: return icon.needsLookup ? "Asking Apple Maps…" : "No guess: a plain pin"
    }
  }
}
