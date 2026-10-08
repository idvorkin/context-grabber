// The memdeck deal's promises (story 129), the same ones `just check-deal` holds the old app's copy to.
import ContextCore
import XCTest

final class CardDealTests: XCTestCase {
  func testNeverTheSameCardTwiceInARow() {
    for nonce in [0, 1, 7, 12_345] {
      var prev = CardDeal.index(forSlot: -5_000, nonce: nonce)
      for s in (-4_999)...5_000 {
        let cur = CardDeal.index(forSlot: s, nonce: nonce)
        XCTAssertNotEqual(cur, prev, "repeat at slot \(s), nonce \(nonce)")
        prev = cur
      }
    }
  }

  func testEveryRunOf52IsTheWholeDeck() {
    for nonce in [0, 3] {
      for run in -20...20 {
        let base = run * CardDeal.cardsPerRun
        let seen = Set((0..<52).map { CardDeal.index(forSlot: base + $0, nonce: nonce) })
        XCTAssertEqual(seen.count, 52, "run \(run) nonce \(nonce)")
      }
    }
  }

  func testOneCardPerFiveMinutes() {
    let t = CardDeal.slotStart(containing: Date(timeIntervalSince1970: 1_788_000_000))
    XCTAssertEqual(CardDeal.card(at: t, nonce: 0), CardDeal.card(at: t.addingTimeInterval(299), nonce: 0))
    XCTAssertNotEqual(CardDeal.card(at: t, nonce: 0), CardDeal.card(at: t.addingTimeInterval(300), nonce: 0))
  }

  func testATapAlwaysDealsADifferentCard() {
    for i in 0..<2_000 {
      let moment = Date(timeIntervalSince1970: 1_700_000_000 + Double(i) * 137)
      let nonce = i % 97
      let after = CardDeal.nonceAfterTap(at: moment, nonce: nonce)
      XCTAssertGreaterThan(after, nonce)
      XCTAssertNotEqual(CardDeal.card(at: moment, nonce: after), CardDeal.card(at: moment, nonce: nonce))
    }
  }

  /// The old app's deal, unchanged: the same moment and tap count is the same card in both apps.
  func testTheDealMatchesTheOldApp() {
    let moment = Date(timeIntervalSince1970: 1_788_000_000)
    XCTAssertEqual(CardDeal.card(at: moment, nonce: 0).label, Self.oldAppCard)
  }

  func testLabelsAndColours() {
    XCTAssertEqual(PlayingCard.deck.count, 52)
    XCTAssertTrue(PlayingCard.deck.map(\.label).contains("10♦"))
    XCTAssertTrue(PlayingCard(rank: "Q", suit: .hearts).isRed)
    XCTAssertFalse(PlayingCard(rank: "A", suit: .spades).isRed)
  }

  static let oldAppCard = "10♥"  // the old app's PlayingCard.swift under swiftc
}

/// #219: the widget deals the trainer's stack, and with Skip easy cards on only part of it.
final class CardDealSubsetTests: XCTestCase {
  func testASmallerDeckKeepsThePromises() {
    for size in [3, 7, 37] {  // three at least: with two, the run-boundary swap moves a run's last card too
      var prev = CardDeal.index(forSlot: -500, nonce: 3, size: size)
      for s in (-499)...500 {
        let cur = CardDeal.index(forSlot: s, nonce: 3, size: size)
        XCTAssertNotEqual(cur, prev, "repeat at \(s), size \(size)")
        XCTAssertTrue((0..<size).contains(cur))
        prev = cur
      }
      for run in -5...5 {
        XCTAssertEqual(Set((0..<size).map { CardDeal.index(forSlot: run * size + $0, nonce: 3, size: size) }).count, size)
      }
      let moment = Date(timeIntervalSince1970: 1_788_000_000)
      let after = CardDeal.nonceAfterTap(at: moment, nonce: 0, size: size)
      XCTAssertNotEqual(
        CardDeal.index(forSlot: CardDeal.slot(containing: moment), nonce: after, size: size),
        CardDeal.index(forSlot: CardDeal.slot(containing: moment), nonce: 0, size: size))
    }
  }

  func testTheTimelineMatchesTheDeal() {
    let now = Date(timeIntervalSince1970: 1_788_000_123)
    for entry in CardDeal.timeline(from: now, nonce: 5, size: 37).prefix(60) {
      XCTAssertEqual(entry.index, CardDeal.index(forSlot: CardDeal.slot(containing: entry.date), nonce: 5, size: 37))
    }
  }
}
