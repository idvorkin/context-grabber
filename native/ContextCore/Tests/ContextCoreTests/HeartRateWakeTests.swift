import XCTest

@testable import ContextCore

/// context-grabber-jimz: heart rate goes to the archive when Health says it arrived, waiting for an unlock if need be.
final class HeartRateWakeTests: XCTestCase {
  func testAnUnlockedWakeRuns() {
    var wakes = HeartRateWake()
    XCTAssertEqual(wakes.wake(nowMs: 1_000, unlocked: true), .run)
    XCTAssertEqual(wakes.lastRunAtMs, 1_000)
  }

  func testWakesWithinAMinuteShareOneRun() {
    var wakes = HeartRateWake()
    XCTAssertEqual(wakes.wake(nowMs: 0, unlocked: true), .run)
    XCTAssertEqual(wakes.wake(nowMs: 59_999, unlocked: true), .tooSoon)  // the next type of the same burst
    XCTAssertEqual(wakes.wake(nowMs: 60_000, unlocked: true), .run)
  }

  func testALockedWakeWaitsForTheUnlockAndRunsOnce() {
    var wakes = HeartRateWake()
    XCTAssertEqual(wakes.wake(nowMs: 0, unlocked: false), .waitForUnlock)
    XCTAssertEqual(wakes.wake(nowMs: 10_000, unlocked: false), .waitForUnlock)
    XCTAssertTrue(wakes.flush(nowMs: 600_000, unlocked: true))
    XCTAssertFalse(wakes.flush(nowMs: 700_000, unlocked: true))  // nothing new waited
    XCTAssertEqual(wakes.wake(nowMs: 610_000, unlocked: true), .tooSoon)  // the unlock's run covers it
  }

  func testAnUnlockWithNoLockedWakeSendsNothing() {
    var wakes = HeartRateWake()
    XCTAssertFalse(wakes.flush(nowMs: 0, unlocked: true))
  }

  func testAFlushWhileStillLockedKeepsWaiting() {
    var wakes = HeartRateWake()
    XCTAssertEqual(wakes.wake(nowMs: 0, unlocked: false), .waitForUnlock)
    XCTAssertFalse(wakes.flush(nowMs: 5_000, unlocked: false))
    XCTAssertTrue(wakes.waitingForUnlock)
    XCTAssertTrue(wakes.flush(nowMs: 9_000, unlocked: true))
    XCTAssertFalse(wakes.waitingForUnlock)
  }

  func testAWaitKeptAcrossARelaunchRunsAtTheNextUnlockedFlush() {
    var before = HeartRateWake()
    XCTAssertEqual(before.wake(nowMs: 0, unlocked: false), .waitForUnlock)
    var relaunched = HeartRateWake(waitingForUnlock: before.waitingForUnlock)
    XCTAssertTrue(relaunched.flush(nowMs: 3_600_000, unlocked: true))
    XCTAssertEqual(relaunched.lastRunAtMs, 3_600_000)
    XCTAssertFalse(HeartRateWake().waitingForUnlock)
  }
}
