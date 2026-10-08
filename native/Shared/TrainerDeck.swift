//  The stack the "Bundle the stack" phases copied into the app and the widget extension (#219;
//  scripts/native/bundle-trainer.sh): the card screen deals from it, and Today's hand draws its cards from it,
//  leaving out the easy ones when the card screen's *Skip easy cards* is on. Compiled into both.

import Foundation
import ThinkACardCore

enum TrainerDeck {
  static func load(from bundle: Bundle = .main) -> Result<Deck, Error> {
    guard let url = bundle.url(forResource: "deck", withExtension: "json") else { return .failure(Missing()) }
    return Result { try Deck(contentsOf: url) }
  }

  struct Missing: LocalizedError {
    var errorDescription: String? { "This build has no stack: the build copies it from igor2's secrets." }
  }

  /// The card screen's setting, kept in the App Group (the trainer's own key) so the widget can read it.
  static var defaults: UserDefaults { UserDefaults(suiteName: UsageTileStore.group) ?? .standard }
  static let skipEasyKey = "skipEasyCards"
  /// The trainer's reach around a breather (its story 011): two either side.
  static let easyReach = 2

  /// What the widget deals from: the whole stack, or with Skip easy cards on, what is clear of the breathers.
  static func pool(_ deck: Deck, skippingEasy: Bool = defaults.bool(forKey: skipEasyKey)) -> [Card] {
    let positions = skippingEasy ? deck.positions(clearOfBreathersBy: easyReach) : Array(1...Deck.size)
    return positions.map { deck.card(at: $0) }
  }
}
