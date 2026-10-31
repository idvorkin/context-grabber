import XCTest

@testable import ContextCore

/// #578: a heal's rebuild plays what the old player had not reached, from where it stopped.
final class PlaybackTailTests: XCTestCase {
  private func ramp(_ n: Int, from first: Float = 0) -> [Float] { (0..<n).map { first + Float($0) } }

  func testTheGreetingThatNeverPlayedComesBackWhole() {
    var tail = PlaybackTail(rate: 10)
    tail.append(ramp(20), at: 0)
    tail.append(ramp(10, from: 20), at: 2)
    XCTAssertEqual(tail.unplayed(at: 0), ramp(30), "a clock that never started heard none of it")
  }

  func testAMidReplyRebuildResumesWhereThePlayerWas() {
    var tail = PlaybackTail(rate: 10)
    tail.append(ramp(20), at: 0)
    tail.append(ramp(20, from: 20), at: 2)
    XCTAssertEqual(tail.unplayed(at: 2.5), ramp(15, from: 25))
  }

  func testAStarvedGapIsNotKept() {
    var tail = PlaybackTail(rate: 10)
    tail.append(ramp(10), at: 0)
    tail.append(ramp(10, from: 10), at: 5)  // the queue ran dry from 1 s to 5 s
    XCTAssertEqual(tail.unplayed(at: 0.5), ramp(15, from: 5))
    XCTAssertEqual(tail.unplayed(at: 3), ramp(10, from: 10))
  }

  func testEverythingHeardLeavesNothing() {
    var tail = PlaybackTail(rate: 10)
    tail.append(ramp(10), at: 0)
    XCTAssertEqual(tail.unplayed(at: 1), [])
    XCTAssertEqual(tail.unplayed(at: 7), [])
  }

  func testPruneDropsOnlyFinishedChunks() {
    var tail = PlaybackTail(rate: 10)
    tail.append(ramp(10), at: 0)
    tail.append(ramp(10, from: 10), at: 1)
    tail.prune(before: 1.5)
    XCTAssertEqual(tail.unplayed(at: 0), ramp(10, from: 10), "the finished chunk is gone, the playing one stays")
  }

  func testARebaseKeepsTheUnheardPartFromZeroAndARetryKeepsIt() {
    var tail = PlaybackTail(rate: 10)
    tail.append(ramp(20), at: 0)
    tail.append(ramp(20, from: 20), at: 2)
    tail.rebase(at: 2.5)
    XCTAssertEqual(tail.durationS, 1.5, accuracy: 1e-9)
    XCTAssertEqual(tail.unplayed(at: 0), ramp(15, from: 25))
    tail.rebase(at: 0)  // a failed rebuild tried again: its new player never ran
    XCTAssertEqual(tail.unplayed(at: 0), ramp(15, from: 25))
  }

  func testARebasePastTheEndHoldsNothing() {
    var tail = PlaybackTail(rate: 10)
    tail.append(ramp(10), at: 0)
    tail.rebase(at: 4)
    XCTAssertEqual(tail.durationS, 0)
    XCTAssertEqual(tail.unplayed(at: 0), [])
  }

  func testABargeInLeavesNothingToFinish() {
    var tail = PlaybackTail(rate: 10)
    tail.append(ramp(10), at: 0)
    tail.reset()
    XCTAssertEqual(tail.unplayed(at: 0), [])
  }
}
