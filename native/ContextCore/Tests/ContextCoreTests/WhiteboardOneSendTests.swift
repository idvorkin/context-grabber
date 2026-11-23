import Foundation
import XCTest

@testable import ContextCore

/// Story 1176 (bead context-grabber-rtl): one Send button. A Send waiting in the outbox holds the turn, says
/// *Waiting to send*, never times out or reads stuck, and lets nothing else go; when the outbox sends it his clock
/// starts; refused or deleted, the turn is free and its words wait.
final class WhiteboardOneSendTests: XCTestCase {
  private let t0 = ContinuousClock.now

  private func at(_ seconds: Int) -> ContinuousClock.Instant { t0 + .seconds(seconds) }

  /// A tap at `seconds` whose picture went into the outbox.
  private func waiting(at seconds: Int = 0, version: Int = 1) -> WhiteboardLarryTurn {
    var turn = WhiteboardLarryTurn()
    XCTAssertEqual(turn.tapped(version: version, now: at(seconds)), .send(words: nil))
    turn.waitsInOutbox()
    return turn
  }

  func testWhileItWaitsTheBoardSaysSoAndNotHisClock() {
    let turn = waiting()
    XCTAssertTrue(turn.waitingToSend)
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(12), cockpitAnswering: true), "Waiting to send · 0:12")
    XCTAssertEqual(
      WhiteboardLarryClock.state(turn, now: at(12), cockpitAnswering: false, mark: .received),
      "Waiting to send · 0:12", "nothing about him or the Cockpit: it hasn't left the iPad")
    XCTAssertEqual(
      WhiteboardLarryClock.spoken(turn, now: at(12), cockpitAnswering: true), "Waiting to send for 12 seconds")
  }

  func testWhileItWaitsNothingElseGoes() {
    var turn = waiting()
    XCTAssertEqual(turn.paused(version: 2, words: "and label it", now: at(5)), .held, "a pause sends nothing")
    XCTAssertEqual(turn.replied(version: 2, now: at(6)), .held, "an answer to an earlier picture sends nothing")
    XCTAssertEqual(turn.closed(version: 2, now: at(7)), .held)
    XCTAssertNil(turn.tick(version: 2, now: at(600)), "the three minutes don't run while it waits")
    XCTAssertTrue(turn.waitingToSend)
    XCTAssertFalse(turn.interrupted(), "nothing to interrupt: he hasn't got it")
    XCTAssertEqual(
      WhiteboardLarryWait.of(turn, mark: .none, now: at(60)), .none, "never stuck: the outbox keeps trying")
  }

  func testWhenItGoesHisClockStartsAndTheTimeoutCountsFromThere() {
    var turn = waiting()
    XCTAssertTrue(turn.outboxSent(now: at(300)))
    XCTAssertFalse(turn.waitingToSend)
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(300), cockpitAnswering: true), "Larry · 0:00")
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(342), cockpitAnswering: true), "Larry · 0:42")
    XCTAssertNil(turn.tick(version: 1, now: at(400)), "three minutes from when it went, not from the tap")
    XCTAssertEqual(turn.tick(version: 1, now: at(480)), .done)
    XCTAssertFalse(turn.outboxSent(now: at(500)), "once")
  }

  func testAfterItGoesARepeatTapIsAnsweredAsAlways() {
    var turn = waiting()
    _ = turn.outboxSent(now: at(10))
    XCTAssertEqual(turn.tapped(version: 1, now: at(11)), .alreadyHas, "story 765")
    XCTAssertEqual(turn.tapped(version: 2, now: at(12)), .send(words: nil), "a stroke since sends")
  }

  func testRefusedOrDeletedFreesTheTurnAndItsWordsWait() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 1, words: "the arrow", now: at(1))
    _ = turn.interrupted()
    XCTAssertEqual(turn.tapped(version: 2, now: at(2)), .send(words: "the arrow"))
    turn.waitsInOutbox()
    turn.failed(turn.state, words: "the arrow")
    XCTAssertFalse(turn.looking)
    XCTAssertFalse(turn.waitingToSend)
    XCTAssertEqual(turn.tapped(version: 2, now: at(3)), .send(words: "the arrow"), "the words go with the next")
  }

  func testABoardOpenedWhileItsSendWaitsIsWaitingAgain() {
    var turn = WhiteboardLarryTurn()
    turn.reopenedWaiting(version: 4, now: at(0))
    XCTAssertTrue(turn.waitingToSend)
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(3), cockpitAnswering: true), "Waiting to send · 0:03")
    XCTAssertTrue(turn.outboxSent(now: at(5)))
    XCTAssertEqual(turn.state, .awaiting(since: at(5), sent: 4))
  }

  func testWaitingIsOnlyForATurnOut() {
    var turn = WhiteboardLarryTurn()
    turn.waitsInOutbox()
    XCTAssertFalse(turn.waitingToSend, "no turn out: nothing waits")
  }

  // MARK: The strokes file

  func testTheStrokesFileCarriesTheFoldsBesideTheStrokes() throws {
    let strokes: [[String: Any]] = [["id": "s1", "points": [[1, 2]]]]
    let folds: [[String: Any]] = [["header": "h1", "strokes": ["s2"]]]
    let plain = try XCTUnwrap(WhiteboardStrokes.file(try WhiteboardStrokes.file(strokes: strokes, folds: [])))
    XCTAssertEqual(plain.strokes.first?["id"] as? String, "s1")
    XCTAssertTrue(plain.folds.isEmpty)
    let raw = try WhiteboardStrokes.file(strokes: strokes, folds: folds)
    XCTAssertTrue(try JSONSerialization.jsonObject(with: raw) is [String: Any], "with folds, the strokes and folds")
    let both = try XCTUnwrap(WhiteboardStrokes.file(raw))
    XCTAssertEqual(both.strokes.first?["id"] as? String, "s1")
    XCTAssertEqual(both.folds.first?["header"] as? String, "h1")
    XCTAssertNil(WhiteboardStrokes.file(Data("nope".utf8)))
  }
}
