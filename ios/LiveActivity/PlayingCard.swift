import Foundation

// The random playing card on the widgets — a memdeck prompt.
// Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
//
// The card is a function of two things and nothing else: the clock, and how
// many times the card has been tapped (one number in the App Group). So the
// lock screen and both home-screen pages deal the same card without talking
// to each other. Every five minutes has one card; each run of 52 of them is
// one shuffled deck, so no card repeats inside a run and every card comes up
// once per run; where two runs meet, a would-be repeat swaps with its
// neighbour. A tap bumps the number until the card in hand changes, and the
// clock deals on from there.

/// Compiled into the app and the widget extension alike: the one home of
/// the names both sides use.
enum AppGroup {
  static let suite = "group.com.idvorkin.contextgrabber"
}

enum WidgetKind {
  static let today = "TodayWidget"
  static let memdeckCard = "MemdeckCardWidget"
}

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
  /// One card per five minutes.
  static let slotSeconds: TimeInterval = 5 * 60
  static let cardsPerRun = PlayingCard.deck.count

  /// The card for a moment, given the tap count. Pure.
  static func card(at date: Date, nonce: Int) -> PlayingCard {
    PlayingCard.deck[index(forSlot: slot(containing: date), nonce: nonce)]
  }

  /// The start of the five minutes that `date` is in.
  static func slotStart(containing date: Date) -> Date {
    Date(timeIntervalSince1970: Double(slot(containing: date)) * slotSeconds)
  }

  /// A widget timeline's worth of entries: twelve hours of five-minute slots,
  /// in case iOS never honours the reload policy. Deals are computed once per
  /// run of 52, not once per entry.
  static let timelineSlots = 144

  static func timeline(from now: Date, nonce: Int) -> [(date: Date, card: PlayingCard)] {
    var deals: [Int: [Int]] = [:]
    return moments(from: now, count: timelineSlots).map { moment in
      let s = slot(containing: moment)
      let run = floorDiv(s, cardsPerRun)
      let deal = deals[run] ?? {
        let d = fixedDeal(run: run, nonce: nonce)
        deals[run] = d
        return d
      }()
      return (moment, PlayingCard.deck[deal[s - run * cardsPerRun]])
    }
  }

  /// `count` moments to show a card at: `from` itself, then each five-minute
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

  /// A tap: the first count above `nonce` whose card for `date` is not the
  /// one showing. Every surface that reads the new count deals the same card.
  static func nonceAfterTap(at date: Date, nonce: Int) -> Int {
    let s = slot(containing: date)
    let showing = index(forSlot: s, nonce: nonce)
    var next = nonce &+ 1
    while index(forSlot: s, nonce: next) == showing {
      next &+= 1
    }
    return next
  }

  // MARK: - the deal

  static func slot(containing date: Date) -> Int {
    Int((date.timeIntervalSince1970 / slotSeconds).rounded(.down))
  }

  /// Index into `PlayingCard.deck` for a slot and a tap count. Pure: the same
  /// inputs are the same card in every process that asks.
  static func index(forSlot slot: Int, nonce: Int) -> Int {
    let run = floorDiv(slot, cardsPerRun)
    let position = slot - run * cardsPerRun
    return fixedDeal(run: run, nonce: nonce)[position]
  }

  /// The run's shuffle, with its first two cards swapped when the first would
  /// repeat the previous run's last. Index 51 is never touched by the swap, so
  /// the previous run's last card is what its own `fixedDeal` shows too.
  static func fixedDeal(run: Int, nonce: Int) -> [Int] {
    var deal = rawDeal(run: run, nonce: nonce)
    if deal[0] == rawDeal(run: run - 1, nonce: nonce)[cardsPerRun - 1] {
      deal.swapAt(0, 1)
    }
    return deal
  }

  /// Fisher–Yates over the 52 indices, seeded by the run number and the tap
  /// count.
  static func rawDeal(run: Int, nonce: Int) -> [Int] {
    let seed = (UInt64(bitPattern: Int64(run)) &* 0x9E37_79B9_7F4A_7C15)
      ^ (UInt64(bitPattern: Int64(nonce)) &* 0xBF58_476D_1CE4_E5B9)
      &+ 0x6D65_6D64_6563_6B21  // "memdeck!"
    var rng = SplitMix64(seed: seed)
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

/// The tap count, shared through the App Group so every widget deals alike.
/// Missing (a fresh install) reads as zero, which is a deal like any other.
enum DealStore {
  static let key = "memdeckDealNonce"

  static func nonce() -> Int {
    UserDefaults(suiteName: AppGroup.suite).map(nonce(in:)) ?? 0
  }

  /// From a suite the caller already holds open.
  static func nonce(in defaults: UserDefaults) -> Int {
    defaults.object(forKey: key) as? Int ?? 0
  }

  static func set(_ nonce: Int) {
    UserDefaults(suiteName: AppGroup.suite)?.set(nonce, forKey: key)
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
