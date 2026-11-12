import Foundation
import XCTest

@testable import ContextCore

/// Stories 667–669 and 760: how long Larry has been looking, and his silence said as a copyable problem.
final class WhiteboardLarryClockTests: XCTestCase {
  private let t0 = ContinuousClock.now

  private func at(_ seconds: Int) -> ContinuousClock.Instant { t0 + .seconds(seconds) }

  private func sent(at seconds: Int = 0, version: Int = 1) -> WhiteboardLarryTurn {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: version, now: at(seconds))
    return turn
  }

  func testNoTurnOutShowsNoClock() {
    let turn = WhiteboardLarryTurn()
    XCTAssertNil(WhiteboardLarryClock.state(turn, now: at(5), cockpitAnswering: true))
    XCTAssertNil(WhiteboardLarryClock.spoken(turn, now: at(5), cockpitAnswering: true))
  }

  func testTheClockCountsFromThePicture() {
    let turn = sent()
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(0), cockpitAnswering: true), "Larry · 0:00")
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(7), cockpitAnswering: true), "Larry · 0:07")
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(42), cockpitAnswering: true), "Larry · 0:42")
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(72), cockpitAnswering: true), "Larry · 1:12")
    XCTAssertEqual(
      WhiteboardLarryClock.state(turn, now: at(42) + .milliseconds(900), cockpitAnswering: true), "Larry · 0:42",
      "whole seconds, never rounded up")
  }

  func testAwayAndBackShowsTheTrueTime() {
    // Nothing ticked while the app was away: the reading is the time since the picture, whenever it is asked.
    let turn = sent(at: 10)
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(40), cockpitAnswering: true), "Larry · 0:30")
  }

  func testANewerPictureRestartsTheClock() {
    var turn = sent()
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(20), cockpitAnswering: true), "Larry · 0:20")
    _ = turn.tapped(version: 2, now: at(20))
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(20), cockpitAnswering: true), "Larry · 0:00")
  }

  func testHisAnswerStopsTheClock() {
    var turn = sent()
    _ = turn.replied(version: 1, now: at(30))
    XCTAssertNil(WhiteboardLarryClock.state(turn, now: at(31), cockpitAnswering: true))
  }

  func testTheCockpitNotAnsweringIsSaidAndTheClockKeepsCounting() {
    let turn = sent()
    XCTAssertEqual(
      WhiteboardLarryClock.state(turn, now: at(48), cockpitAnswering: false), "Larry · 0:48 · Cockpit not answering")
    XCTAssertEqual(
      WhiteboardLarryClock.state(turn, now: at(49), cockpitAnswering: false), "Larry · 0:49 · Cockpit not answering")
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(50), cockpitAnswering: true), "Larry · 0:50")
  }

  /// Story 765: a tap that sent nothing is answered in the state for two seconds.
  func testARepeatTapIsAnsweredForTwoSeconds() {
    var turn = sent()
    _ = turn.tapped(version: 1, now: at(12))
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(12), cockpitAnswering: true), "Larry already has this · 0:12")
    XCTAssertEqual(
      WhiteboardLarryClock.state(turn, now: at(13) + .milliseconds(900), cockpitAnswering: true),
      "Larry already has this · 0:13")
    XCTAssertEqual(WhiteboardLarryClock.state(turn, now: at(14), cockpitAnswering: true), "Larry · 0:14")
    XCTAssertEqual(
      WhiteboardLarryClock.spoken(turn, now: at(12), cockpitAnswering: true),
      "Larry already has this, and has been looking for 12 seconds")
    _ = turn.tapped(version: 2, now: at(13))
    XCTAssertEqual(
      WhiteboardLarryClock.state(turn, now: at(13), cockpitAnswering: true), "Larry · 0:00", "a new picture went")
  }

  func testVoiceOverSaysItInWords() {
    let turn = sent()
    XCTAssertEqual(
      WhiteboardLarryClock.spoken(turn, now: at(42), cockpitAnswering: true), "Larry has been looking for 42 seconds")
    XCTAssertEqual(
      WhiteboardLarryClock.spoken(turn, now: at(1), cockpitAnswering: true), "Larry has been looking for 1 second")
    XCTAssertEqual(
      WhiteboardLarryClock.spoken(turn, now: at(60), cockpitAnswering: true), "Larry has been looking for 1 minute")
    XCTAssertEqual(
      WhiteboardLarryClock.spoken(turn, now: at(132), cockpitAnswering: true),
      "Larry has been looking for 2 minutes 12 seconds")
    XCTAssertEqual(
      WhiteboardLarryClock.spoken(turn, now: at(48), cockpitAnswering: false),
      "Larry has been looking for 48 seconds, and the Cockpit isn't answering")
  }

  func testNoProblemWithNoTurnOut() {
    XCTAssertNil(
      WhiteboardLarryClock.didntAnswer(
        WhiteboardLarryTurn(), now: at(400), wallNow: Date(), cockpitAnswering: true), "no turn out")
  }

  func testHisSilenceCarriesTheStateThatExplainsIt() throws {
    let wall = Date(timeIntervalSince1970: 1_800_000_000)
    let problem = try XCTUnwrap(
      WhiteboardLarryClock.didntAnswer(sent(at: 10), now: at(191), wallNow: wall, cockpitAnswering: false))
    XCTAssertEqual(problem.message, "Larry didn't answer")
    XCTAssertEqual(problem.context, "WhiteboardView.larryTimeout")
    XCTAssertEqual(problem.sentAt, wall - 181, "when the picture went, on the wall clock")
    XCTAssertEqual(problem.waitedSeconds, 181)
    XCTAssertFalse(problem.inkWaiting)
    XCTAssertFalse(problem.wordsWaiting)
    XCTAssertFalse(problem.cockpitAnswering)
  }

  func testHisSilenceSaysWhatWasWaiting() throws {
    var turn = sent()
    _ = turn.paused(version: 2, words: nil, now: at(30))
    var problem = try XCTUnwrap(
      WhiteboardLarryClock.didntAnswer(turn, now: at(180), wallNow: Date(), cockpitAnswering: true))
    XCTAssertTrue(problem.inkWaiting)
    XCTAssertFalse(problem.wordsWaiting)
    XCTAssertTrue(problem.cockpitAnswering)

    turn = sent()
    _ = turn.paused(version: 1, words: "circle it", now: at(30))
    problem = try XCTUnwrap(
      WhiteboardLarryClock.didntAnswer(turn, now: at(180), wallNow: Date(), cockpitAnswering: true))
    XCTAssertFalse(problem.inkWaiting)
    XCTAssertTrue(problem.wordsWaiting)
  }
}
