//  #186 (story 080): the silent-mixer heal fires for audio that should have played, not for a reply still landing.

import ContextCore
import XCTest

final class CallSilentMixerTests: XCTestCase {
  /// The phone's log, 2026-10-06 08:30: Larry's reply arrived about 0.1 s before the window closed, the mixer had
  /// not played it yet, and the rebuild that followed killed the call.
  func testAReplyLandingAtTheWindowsEndIsNotSilence() {
    XCTAssertFalse(CallWatchdog.silentMixer(now: 789_194, firstLoudRxAt: 789_100, mixBuffers: 50, mixPeak: 0))
  }

  /// #146 as it was: audio in hand for seconds and the mixer rendering nothing.
  func testAudioInHandForSecondsWithASilentMixerIsSilence() {
    XCTAssertTrue(CallWatchdog.silentMixer(now: 10_000, firstLoudRxAt: 5_200, mixBuffers: 50, mixPeak: 0))
  }

  func testNoAudioOrAnAudibleMixerIsNotSilence() {
    XCTAssertFalse(CallWatchdog.silentMixer(now: 10_000, firstLoudRxAt: nil, mixBuffers: 50, mixPeak: 0))
    XCTAssertFalse(CallWatchdog.silentMixer(now: 10_000, firstLoudRxAt: 5_000, mixBuffers: 50, mixPeak: 0.4))
    XCTAssertFalse(CallWatchdog.silentMixer(now: 10_000, firstLoudRxAt: 5_000, mixBuffers: 0, mixPeak: 0))
  }

  /// #199: a short reply arrives 0.1 s before the window closes and the mixer, clock still running, renders only
  /// silence. The first window puts the verdict off; the second, with no new audio from Larry, still heals.
  func testAShortReplyAtTheBoundaryIsJudgedInTheNextWindow() {
    var loud: Double? = 4_900
    XCTAssertFalse(CallWatchdog.silentMixer(now: 5_000, firstLoudRxAt: loud, mixBuffers: 50, mixPeak: 0))
    loud = CallWatchdog.carriedLoudRx(firstLoudRxAt: loud, mixPeak: 0, healed: false)
    XCTAssertEqual(loud, 4_900)
    XCTAssertTrue(CallWatchdog.silentMixer(now: 10_000, firstLoudRxAt: loud, mixBuffers: 50, mixPeak: 0))
  }

  /// The same reply on a working mixer: it renders in the next window, which confirms delivery and drops it.
  func testAReplyThatPlaysIsDroppedAndAHealStartsOver() {
    XCTAssertNil(CallWatchdog.carriedLoudRx(firstLoudRxAt: 4_900, mixPeak: 0.3, healed: false))
    XCTAssertNil(CallWatchdog.carriedLoudRx(firstLoudRxAt: 4_900, mixPeak: 0, healed: true))
    XCTAssertNil(CallWatchdog.carriedLoudRx(firstLoudRxAt: nil, mixPeak: 0, healed: false))
  }

  /// #198: a heal's rebuild fails and queues a retry; Igor restarts the call before it runs. The old retry finds its
  /// ticket stale and leaves the new call alone. A newer heal supersedes an older one's retries the same way.
  func testARetryFromBeforeARestartOrANewerHealIsStale() {
    var gate = HealGate()
    let failed = gate.begin()
    XCTAssertTrue(gate.isCurrent(failed), "the retry runs while nothing has changed")
    gate.invalidate()  // stop
    gate.invalidate()  // the new call prepares
    XCTAssertFalse(gate.isCurrent(failed))
    let first = gate.begin()
    let second = gate.begin()
    XCTAssertFalse(gate.isCurrent(first))
    XCTAssertTrue(gate.isCurrent(second))
  }
}
