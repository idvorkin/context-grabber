// The memdeck deal's promises, checked under plain swiftc: `just check-deal`.
// Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
import Foundation

// Checks the deal's promises from the spec: never twice in a row (on the clock
// and on a tap), every card once per run of 52, the same card for the same
// moment and tap count, boundaries on the five minutes, and that the run-end
// fix never disturbs a run's last card.

var failures = 0
func check(_ ok: Bool, _ what: String) {
  if !ok { failures += 1; print("FAIL: \(what)") }
}

check(CardDeal.slotSeconds == 300, "five-minute slots")

// 1. No repeats across 200k consecutive slots (≈ 2 years), including negatives,
//    for a few tap counts.
for nonce in [0, 1, 7, 12_345] {
  var prev = CardDeal.index(forSlot: -100_000, nonce: nonce)
  for s in (-99_999)...100_000 {
    let cur = CardDeal.index(forSlot: s, nonce: nonce)
    check(cur != prev, "repeat at slot \(s), nonce \(nonce)")
    prev = cur
  }
}

// 2. Every run of 52 is a full permutation, and the fix leaves index 51 alone.
for nonce in [0, 3] {
  for run in -50...50 {
    let base = run * CardDeal.cardsPerRun
    let seen = Set((0..<52).map { CardDeal.index(forSlot: base + $0, nonce: nonce) })
    check(seen.count == 52, "run \(run) nonce \(nonce) is not a permutation")
    check(CardDeal.fixedDeal(run: run, nonce: nonce)[51] == CardDeal.rawDeal(run: run, nonce: nonce)[51], "run \(run) last card moved")
  }
}

// 3. Same moment and tap count, same card; a tap changes it; the tap count
//    is what every surface reads, so agreement is by construction.
let t = CardDeal.slotStart(containing: Date(timeIntervalSince1970: 1_788_000_000))
check(CardDeal.card(at: t, nonce: 0) == CardDeal.card(at: t.addingTimeInterval(299), nonce: 0), "same slot, different card")
check(CardDeal.card(at: t, nonce: 0) != CardDeal.card(at: t.addingTimeInterval(300), nonce: 0), "next slot, same card")
check(CardDeal.card(at: t.addingTimeInterval(-1), nonce: 0) != CardDeal.card(at: t, nonce: 0), "previous slot, same card")

// 4. A tap always deals a different card, for any moment and any tap count,
//    and the tap count only ever goes up.
var maxBump = 0
for i in 0..<5_000 {
  let moment = Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 137)
  let nonce = i % 97
  let after = CardDeal.nonceAfterTap(at: moment, nonce: nonce)
  check(after > nonce, "tap did not raise the count")
  check(CardDeal.card(at: moment, nonce: after) != CardDeal.card(at: moment, nonce: nonce), "tap dealt the same card at \(i)")
  maxBump = max(maxBump, after - nonce)
}
check(maxBump <= 8, "a tap needed \(maxBump) tries")

// 5. Timeline moments: first is now, then five-minute boundaries.
let now = Date(timeIntervalSince1970: 1_788_000_123)
let m = CardDeal.moments(from: now, count: 5)
check(m.count == 5, "moment count")
check(m[0] == now, "first moment is now")
for i in 1..<5 {
  check(m[i].timeIntervalSince1970.truncatingRemainder(dividingBy: 300) == 0, "moment \(i) off the boundary")
  check(m[i] > m[i - 1], "moments not increasing")
}
check(m[1].timeIntervalSince1970 - now.timeIntervalSince1970 <= 300, "first boundary more than a slot away")

// 6. Fairness: over 52 000 slots each card shows 1000 times exactly.
var counts = [Int](repeating: 0, count: 52)
for s in 0..<52_000 { counts[CardDeal.index(forSlot: s, nonce: 0)] += 1 }
check(counts.allSatisfy { $0 == 1000 }, "not exactly uniform: \(counts.min()!)…\(counts.max()!)")

// 7. Labels look like cards.
check(PlayingCard.deck.count == 52, "deck size")
check(PlayingCard.deck.map(\.label).contains("10♦"), "ten of diamonds label")
check(PlayingCard(rank: "Q", suit: .hearts).isRed && !PlayingCard(rank: "A", suit: .spades).isRed, "colour")

print("next 12 cards from now, untapped:")
print(CardDeal.moments(from: Date(), count: 12).map { CardDeal.card(at: $0, nonce: 0).label }.joined(separator: " "))
print("three taps right now:", (0..<3).reduce(into: (nonce: 0, cards: [String]())) { acc, _ in
  acc.nonce = CardDeal.nonceAfterTap(at: Date(), nonce: acc.nonce)
  acc.cards.append(CardDeal.card(at: Date(), nonce: acc.nonce).label)
}.cards.joined(separator: " → "))
print(failures == 0 ? "ALL CHECKS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
