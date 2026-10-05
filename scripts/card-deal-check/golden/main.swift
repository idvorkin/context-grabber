// Golden vectors from the old app's deal (ios/LiveActivity/PlayingCard.swift) for the native app's host test,
// CardDealTests.testTheNativeDealIsTheOldDeal. Regenerate (the numbers must not change unless both deals do):
//   out=$(mktemp -d); xcrun swiftc -O -module-name carddeal ios/LiveActivity/PlayingCard.swift \
//     scripts/card-deal-check/golden/main.swift -o "$out/golden" && "$out/golden"
import Foundation

/// FNV-1a over a list of integers, so thousands of deals fit in one number.
func fnv(_ values: [Int]) -> UInt64 {
  var h: UInt64 = 0xcbf2_9ce4_8422_2325
  for v in values {
    for byte in withUnsafeBytes(of: Int64(v).littleEndian, Array.init) {
      h ^= UInt64(byte)
      h &*= 0x0000_0100_0000_01B3
    }
  }
  return h
}

// 1. Slots across zero, for several tap counts.
for nonce in [0, 1, 7, 99, 12_345] {
  let indices = (-1500...1500).map { CardDeal.index(forSlot: $0, nonce: nonce) }
  print("slots nonce \(nonce): 0x\(String(fnv(indices), radix: 16))")
}

// 2. Real clock times (2023 to 2026), each with a tap count: the card shown and the count a tap moves to.
var pairs: [Int] = []
for i in 0..<5_000 {
  let moment = Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 18_911)
  let nonce = i % 97
  pairs.append(PlayingCard.deck.firstIndex(of: CardDeal.card(at: moment, nonce: nonce))!)
  pairs.append(CardDeal.nonceAfterTap(at: moment, nonce: nonce))
}
print("clock: 0x\(String(fnv(pairs), radix: 16))")

// 3. A few by name, readable in a failure.
for (seconds, nonce) in [(1_791_100_800, 0), (1_791_100_800, 1), (1_791_101_100, 0), (0, 0), (-300, 5)] {
  let d = Date(timeIntervalSince1970: TimeInterval(seconds))
  print("(\(seconds), \(nonce), \"\(CardDeal.card(at: d, nonce: nonce).label)\", \(CardDeal.nonceAfterTap(at: d, nonce: nonce))),")
}
