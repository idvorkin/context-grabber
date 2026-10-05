import XCTest

@testable import ContextCore

/// The deal's promises, carried over from `just check-deal` (scripts/card-deal-check/main.swift), plus the native deal
/// pinned to the old one. Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md.
final class CardDealTests: XCTestCase {
  func testFiveMinuteSlots() {
    XCTAssertEqual(CardDeal.slotSeconds, 300)
  }

  /// check-deal 1: never the same card twice in a row on the clock, across zero, for a few tap counts.
  func testNoRepeatsAcrossConsecutiveSlots() {
    for nonce in [0, 1, 7, 12_345] {
      let indices = slots(-100_000...100_000, nonce: nonce)
      let repeats = zip(indices, indices.dropFirst()).filter { $0 == $1 }.count
      XCTAssertEqual(repeats, 0, "nonce \(nonce)")
    }
  }

  /// check-deal 2: every run of 52 is the whole deck, and the run-end fix leaves a run's last card alone.
  func testEveryRunIsAPermutationAndTheFixLeavesTheLastCard() {
    for nonce in [0, 3] {
      for run in -50...50 {
        let base = run * CardDeal.cardsPerRun
        let seen = Set((0..<52).map { CardDeal.index(forSlot: base + $0, nonce: nonce) })
        XCTAssertEqual(seen.count, 52, "run \(run) nonce \(nonce)")
        XCTAssertEqual(
          CardDeal.fixedDeal(run: run, nonce: nonce)[51], CardDeal.rawDeal(run: run, nonce: nonce)[51],
          "run \(run) last card moved")
      }
    }
  }

  /// check-deal 3: one card for the whole five minutes, a different one either side.
  func testSameSlotSameCardNeighboursDiffer() {
    let t = CardDeal.slotStart(containing: Date(timeIntervalSince1970: 1_788_000_000))
    XCTAssertEqual(CardDeal.card(at: t, nonce: 0), CardDeal.card(at: t.addingTimeInterval(299), nonce: 0))
    XCTAssertNotEqual(CardDeal.card(at: t, nonce: 0), CardDeal.card(at: t.addingTimeInterval(300), nonce: 0))
    XCTAssertNotEqual(CardDeal.card(at: t.addingTimeInterval(-1), nonce: 0), CardDeal.card(at: t, nonce: 0))
  }

  /// check-deal 4: a tap always deals a different card, the count only goes up, and never by much.
  func testATapAlwaysChangesTheCard() {
    var maxBump = 0
    for i in 0..<5_000 {
      let moment = Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 137)
      let nonce = i % 97
      let after = CardDeal.nonceAfterTap(at: moment, nonce: nonce)
      XCTAssertGreaterThan(after, nonce)
      XCTAssertNotEqual(CardDeal.card(at: moment, nonce: after), CardDeal.card(at: moment, nonce: nonce), "at \(i)")
      maxBump = max(maxBump, after - nonce)
    }
    XCTAssertLessThanOrEqual(maxBump, 8)
  }

  /// The screen's deal is a tap: the new count, and the card it shows now.
  func testDealIsATap() {
    let now = Date(timeIntervalSince1970: 1_791_100_800)
    let dealt = CardDeal.deal(at: now, nonce: 4)
    XCTAssertEqual(dealt.nonce, CardDeal.nonceAfterTap(at: now, nonce: 4))
    XCTAssertEqual(dealt.card, CardDeal.card(at: now, nonce: dealt.nonce))
    XCTAssertNotEqual(dealt.card, CardDeal.card(at: now, nonce: 4))
  }

  /// check-deal 5: timeline moments are now, then each five-minute boundary.
  func testMoments() {
    let now = Date(timeIntervalSince1970: 1_788_000_123)
    let m = CardDeal.moments(from: now, count: 5)
    XCTAssertEqual(m.count, 5)
    XCTAssertEqual(m[0], now)
    for i in 1..<5 {
      XCTAssertEqual(m[i].timeIntervalSince1970.truncatingRemainder(dividingBy: 300), 0)
      XCTAssertGreaterThan(m[i], m[i - 1])
    }
    XCTAssertLessThanOrEqual(m[1].timeIntervalSince1970 - now.timeIntervalSince1970, 300)
    XCTAssertEqual(CardDeal.moments(from: now, count: 0), [])
  }

  /// check-deal 6: fair — over 52 000 slots each card shows exactly 1000 times.
  func testExactlyUniform() {
    var counts = [Int](repeating: 0, count: 52)
    for i in slots(0...51_999, nonce: 0) { counts[i] += 1 }
    XCTAssertTrue(counts.allSatisfy { $0 == 1000 }, "\(counts.min()!)…\(counts.max()!)")
  }

  /// check-deal 7: labels and colours look like cards; the face cards are J, Q, K.
  func testLabelsAndColours() {
    XCTAssertEqual(PlayingCard.deck.count, 52)
    XCTAssertEqual(Set(PlayingCard.deck).count, 52)
    XCTAssertTrue(PlayingCard.deck.map(\.label).contains("10♦"))
    XCTAssertTrue(PlayingCard(rank: "Q", suit: .hearts).isRed)
    XCTAssertFalse(PlayingCard(rank: "A", suit: .spades).isRed)
    XCTAssertEqual(PlayingCard.deck.filter(\.isFace).count, 12)
  }

  // MARK: - the same deal as the old app's widgets

  /// Vectors from ios/LiveActivity/PlayingCard.swift, taken by scripts/card-deal-check/golden/main.swift (which
  /// prints these numbers): the native deal is the old deal, card for card and tap for tap.
  func testTheNativeDealIsTheOldDeal() {
    let slotHashes: [Int: UInt64] = [
      0: 0xb13f_69cc_3ced_391c, 1: 0x7547_6ab1_e0e5_8bbe, 7: 0x97de_0aa8_ae84_5dad,
      99: 0x7960_d3d3_8753_7bc8, 12_345: 0xec40_1387_7731_f8d7,
    ]
    for (nonce, want) in slotHashes {
      XCTAssertEqual(fnv((-1500...1500).map { CardDeal.index(forSlot: $0, nonce: nonce) }), want, "nonce \(nonce)")
    }

    var pairs: [Int] = []
    for i in 0..<5_000 {
      let moment = Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 18_911)
      let nonce = i % 97
      pairs.append(PlayingCard.deck.firstIndex(of: CardDeal.card(at: moment, nonce: nonce))!)
      pairs.append(CardDeal.nonceAfterTap(at: moment, nonce: nonce))
    }
    XCTAssertEqual(fnv(pairs), 0xa47c_7708_41e3_0d75, "clock times 2023–2026 with tap counts 0–96")

    let named: [(Int, Int, String, Int)] = [
      (1_791_100_800, 0, "5♠", 1),
      (1_791_100_800, 1, "K♣", 2),
      (1_791_101_100, 0, "7♦", 1),
      (0, 0, "K♦", 1),
      (-300, 5, "2♣", 6),
    ]
    for (seconds, nonce, label, after) in named {
      let d = Date(timeIntervalSince1970: TimeInterval(seconds))
      XCTAssertEqual(CardDeal.card(at: d, nonce: nonce).label, label, "\(seconds) nonce \(nonce)")
      XCTAssertEqual(CardDeal.nonceAfterTap(at: d, nonce: nonce), after, "\(seconds) nonce \(nonce)")
    }
  }

  /// `CardDeal.index(forSlot:)` over a range, one shuffle per run instead of two per slot (a debug build is slow).
  private func slots(_ range: ClosedRange<Int>, nonce: Int) -> [Int] {
    var deals: [Int: [Int]] = [:]
    return range.map { s in
      let run = Int((Double(s) / Double(CardDeal.cardsPerRun)).rounded(.down))
      let deal = deals[run] ?? CardDeal.fixedDeal(run: run, nonce: nonce)
      deals[run] = deal
      return deal[s - run * CardDeal.cardsPerRun]
    }
  }

  func testTheTestsShortcutIsTheDeal() {
    let range = -300...300
    XCTAssertEqual(slots(range, nonce: 2), range.map { CardDeal.index(forSlot: $0, nonce: 2) })
  }

  private func fnv(_ values: [Int]) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for v in values {
      for byte in withUnsafeBytes(of: Int64(v).littleEndian, Array.init) {
        h ^= UInt64(byte)
        h &*= 0x0000_0100_0000_01B3
      }
    }
    return h
  }
}

final class ThinkCountTests: XCTestCase {
  func testCountsFiveFourThreeTwoOneThenReveals() {
    XCTAssertEqual(ThinkCount.left(elapsed: 0), 5)
    XCTAssertEqual(ThinkCount.left(elapsed: 0.99), 5)
    XCTAssertEqual(ThinkCount.left(elapsed: 1), 4)
    XCTAssertEqual(ThinkCount.left(elapsed: 3.5), 2)
    XCTAssertEqual(ThinkCount.left(elapsed: 4.99), 1)
    XCTAssertEqual(ThinkCount.left(elapsed: 5), 0)
    XCTAssertEqual(ThinkCount.left(elapsed: 60), 0)
    XCTAssertEqual(ThinkCount.left(elapsed: -2), 5, "a clock that stepped back still shows the full count")
  }
}
