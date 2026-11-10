import Foundation
import XCTest

@testable import ContextCore

/// Story 662: Larry's turn on a board, one at a time, latest wins.
final class WhiteboardLarryTurnTests: XCTestCase {
  private let t0 = ContinuousClock.now

  private func at(_ seconds: Int) -> ContinuousClock.Instant { t0 + .seconds(seconds) }

  func testAPauseWhileIdleSends() {
    var turn = WhiteboardLarryTurn()
    XCTAssertFalse(turn.looking)
    XCTAssertEqual(turn.paused(version: 1, words: nil, now: at(0)), .send(words: nil))
    XCTAssertTrue(turn.looking)
    XCTAssertEqual(turn.state, .awaiting(since: at(0), sent: 1))
  }

  func testAPauseWhileATurnIsOutSendsNothing() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    XCTAssertEqual(turn.paused(version: 2, words: nil, now: at(5)), .held)
    XCTAssertEqual(turn.paused(version: 4, words: nil, now: at(9)), .held)
    XCTAssertEqual(turn.latest, 4, "the newest version is remembered")
    XCTAssertEqual(turn.state, .awaiting(since: at(0), sent: 1), "still the first turn")
  }

  func testHisAnswerWithTheBoardMovedOnSendsOnce() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 2, words: nil, now: at(5))
    _ = turn.paused(version: 3, words: nil, now: at(8))
    XCTAssertEqual(turn.replied(version: 3, now: at(70)), .send(words: nil))
    XCTAssertEqual(turn.state, .awaiting(since: at(70), sent: 3))
    XCTAssertNil(turn.latest)
    XCTAssertEqual(turn.replied(version: 3, now: at(140)), .done, "nothing moved since: no second picture")
    XCTAssertFalse(turn.looking)
  }

  func testHisAnswerWithNothingNewSendsNothing() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    XCTAssertEqual(turn.replied(version: 1, now: at(60)), .done)
    XCTAssertEqual(turn.state, .idle)
    XCTAssertEqual(turn.paused(version: 2, words: nil, now: at(61)), .send(words: nil), "the next pause goes at once")
  }

  func testAnAnswerWithNoTurnOutIsNothing() {
    var turn = WhiteboardLarryTurn()
    XCTAssertEqual(turn.replied(version: 1, now: at(0)), .done)
    XCTAssertFalse(turn.looking)
  }

  func testTheTurnTimesOut() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    XCTAssertNil(turn.tick(version: 1, now: at(179)), "still in time")
    XCTAssertEqual(turn.tick(version: 1, now: at(180)), .done)
    XCTAssertFalse(turn.looking)
    XCTAssertNil(turn.tick(version: 1, now: at(400)), "no turn out")
  }

  func testATimeoutWithTheBoardMovedOnSendsTheLatest() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 2, words: nil, now: at(30))
    XCTAssertEqual(turn.tick(version: 3, now: at(181)), .send(words: nil))
    XCTAssertEqual(turn.state, .awaiting(since: at(181), sent: 3), "the picture is of the board as it is now")
  }

  func testATapSupersedesWhatWasWaiting() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 2, words: "circle the middle", now: at(5))
    XCTAssertEqual(turn.tapped(version: 3, now: at(10)), "circle the middle", "the waiting words go with it")
    XCTAssertEqual(turn.state, .awaiting(since: at(10), sent: 3))
    XCTAssertNil(turn.latest)
    XCTAssertEqual(turn.replied(version: 3, now: at(70)), .done, "what waited went with the tap")
  }

  func testATapWhileIdleSendsAtOnce() {
    var turn = WhiteboardLarryTurn()
    XCTAssertNil(turn.tapped(version: 1, now: at(0)))
    XCTAssertTrue(turn.looking)
  }

  func testWordsWaitForTheNextPicture() {
    var turn = WhiteboardLarryTurn()
    XCTAssertEqual(turn.paused(version: 1, words: "draw a box", now: at(0)), .send(words: "draw a box"))
    XCTAssertEqual(turn.paused(version: 1, words: "and an arrow", now: at(3)), .held)
    XCTAssertEqual(turn.paused(version: 1, words: "to the left", now: at(6)), .held)
    XCTAssertEqual(turn.queued, "and an arrow to the left")
    XCTAssertEqual(
      turn.replied(version: 1, now: at(60)), .send(words: "and an arrow to the left"),
      "words alone are reason enough for a picture")
    XCTAssertNil(turn.queued)
  }

  func testAFailedPictureFreesTheTurnAndKeepsItsWords() {
    var turn = WhiteboardLarryTurn()
    guard case .send(let words) = turn.paused(version: 1, words: "draw a box", now: at(0)) else {
      return XCTFail("the first pause sends")
    }
    _ = turn.paused(version: 1, words: "now", now: at(1))
    turn.failed(words: words)
    XCTAssertFalse(turn.looking)
    XCTAssertEqual(turn.paused(version: 2, words: nil, now: at(5)), .send(words: "draw a box now"))
  }

  func testGhostsOffForgetsWhatWasWaiting() {
    var turn = WhiteboardLarryTurn()
    _ = turn.paused(version: 1, words: nil, now: at(0))
    _ = turn.paused(version: 2, words: "more", now: at(5))
    turn.dropped()
    XCTAssertTrue(turn.looking, "the turn already out stays out")
    XCTAssertEqual(turn.replied(version: 2, now: at(60)), .done)
  }

  func testOnlyNewRowsAreAnAnswer() {
    var marks = WhiteboardMarks()
    let old = WhiteboardMarks.Row(id: "a", text: "earlier")
    XCTAssertFalse(marks.take([old], settled: nil).replied, "the first look's rows were there before")
    XCTAssertFalse(marks.take([old], settled: nil).replied)
    XCTAssertTrue(marks.take([old, .init(id: "b", text: "ok")], settled: nil).replied)
  }
}
