import Foundation

// The random playing card on the widgets — a memdeck prompt.
// Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
//
// The card is the clock's, not the app's: every quarter hour has one card, the
// same on the lock screen and on both home-screen pages, with no shared state
// between them. Each run of 52 quarter hours is one shuffled deck, so no card
// repeats inside a run and every card comes up exactly once per thirteen hours;
// where two runs meet, a card that would repeat swaps with its neighbour.

struct PlayingCard: Equatable {
  enum Suit: String, CaseIterable {
    case spades = "♠", hearts = "♥", diamonds = "♦", clubs = "♣"
    var isRed: Bool { self == .hearts || self == .diamonds }
  }

  static let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

  let rank: String
  let suit: Suit

  var isRed: Bool { suit.isRed }
  /// "7♣" — the widget's label.
  var label: String { rank + suit.rawValue }

  /// The 52, in a fixed order; a deal is a permutation of the indices.
  static let deck: [PlayingCard] = Suit.allCases.flatMap { suit in
    ranks.map { PlayingCard(rank: $0, suit: suit) }
  }
}

enum CardDeal {
  /// One card per quarter hour.
  static let slotSeconds: TimeInterval = 15 * 60
  static let cardsPerRun = PlayingCard.deck.count

  static func card(at date: Date) -> PlayingCard {
    PlayingCard.deck[index(forSlot: slot(containing: date))]
  }

  /// The start of the quarter hour that `date` is in.
  static func slotStart(containing date: Date) -> Date {
    Date(timeIntervalSince1970: Double(slot(containing: date)) * slotSeconds)
  }

  /// `count` moments to show a card at: `from` itself, then each quarter-hour
  /// boundary after it — what a widget timeline wants.
  static func moments(from date: Date, count: Int) -> [Date] {
    guard count > 0 else { return [] }
    var out = [date]
    var next = slotStart(containing: date).addingTimeInterval(slotSeconds)
    while out.count < count {
      out.append(next)
      next = next.addingTimeInterval(slotSeconds)
    }
    return out
  }

  // MARK: - the deal

  static func slot(containing date: Date) -> Int {
    Int((date.timeIntervalSince1970 / slotSeconds).rounded(.down))
  }

  /// Index into `PlayingCard.deck` for a slot. Pure: the same slot is the same
  /// card in every process that asks.
  static func index(forSlot slot: Int) -> Int {
    let run = floorDiv(slot, cardsPerRun)
    let position = slot - run * cardsPerRun
    let deal = fixedDeal(run: run)
    return deal[position]
  }

  /// The run's shuffle, with its first two cards swapped when the first would
  /// repeat the previous run's last. Index 51 is never touched by the swap, so
  /// the previous run's last card is what its own `fixedDeal` shows too.
  static func fixedDeal(run: Int) -> [Int] {
    var deal = rawDeal(run: run)
    if deal[0] == rawDeal(run: run - 1)[cardsPerRun - 1] {
      deal.swapAt(0, 1)
    }
    return deal
  }

  /// Fisher–Yates over the 52 indices, seeded by the run number.
  static func rawDeal(run: Int) -> [Int] {
    var rng = SplitMix64(seed: UInt64(bitPattern: Int64(run)) &+ 0x6D65_6D64_6563_6B21)  // "memdeck!"
    var deal = Array(0..<cardsPerRun)
    var i = cardsPerRun - 1
    while i > 0 {
      let j = Int(rng.next() % UInt64(i + 1))
      deal.swapAt(i, j)
      i -= 1
    }
    return deal
  }

  private static func floorDiv(_ a: Int, _ b: Int) -> Int {
    let q = a / b
    return (a % b < 0) ? q - 1 : q
  }
}

/// A small, well-known generator — the deal must be identical on every device
/// and every OS version, which `SystemRandomNumberGenerator` cannot promise.
struct SplitMix64 {
  private var state: UInt64
  init(seed: UInt64) { state = seed }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
