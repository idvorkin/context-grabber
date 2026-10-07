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
}
