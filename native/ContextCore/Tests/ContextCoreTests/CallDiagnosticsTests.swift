import XCTest

@testable import ContextCore

final class CallWatchdogTests: XCTestCase {
  func testMicIsStalledOnlyWhenArmedUnpausedAndQuietForTheWholeWindow() {
    XCTAssertEqual(CallWatchdog.mic(now: 10_000, armed: false, paused: false, armedAt: 0, lastBufferAt: 0), .idle)
    XCTAssertEqual(CallWatchdog.mic(now: 10_000, armed: true, paused: true, armedAt: 0, lastBufferAt: 0), .idle)
    // a fresh tap gets the full grace from arming
    XCTAssertEqual(CallWatchdog.mic(now: 10_000, armed: true, paused: false, armedAt: 9_000, lastBufferAt: 0), .ok)
    XCTAssertEqual(
      CallWatchdog.mic(now: 10_500, armed: true, paused: false, armedAt: 9_000, lastBufferAt: 0), .stalled)
    XCTAssertEqual(
      CallWatchdog.mic(now: 10_500, armed: true, paused: false, armedAt: 1_000, lastBufferAt: 9_100), .ok)
  }

  func testOutputIsStalledWhenAudioIsDueRecentlyScheduledAndTheClockSitsStill() {
    func v(_ now: Double, _ t: Double, _ prev: Double, _ prevAt: Double, _ head: Double, _ sched: Double)
      -> CallWatchdog.Verdict
    {
      CallWatchdog.output(
        now: now, currentTime: t, previousTime: prev, previousCheckAt: prevAt, playhead: head, lastScheduledAt: sched)
    }
    XCTAssertEqual(v(5000, 2, 2, 4500, 2.01, 4900), .idle)  // nothing due
    XCTAssertEqual(v(5000, 2, 2, 3000, 3, 2000), .idle)  // nothing scheduled lately: a silent line
    XCTAssertEqual(v(5000, 2.5, 2, 4900, 3, 4900), .ok)  // the clock moved
    XCTAssertEqual(v(5000, 2, 2, 4500, 3, 4900), .ok)  // still, but not for long
    XCTAssertEqual(v(5000, 2, 2, 4000, 3, 4900), .stalled)
  }

  // #567: the bridge's re-send of a cut-off reply, with or without its "…", and never a short or different text.
  func testACutOffReplysRepeatIsRecognisedAndNothingElseIs() {
    let said = "Let me look. Yes, it's wired in. PR eighty merged."
    XCTAssertTrue(CallWatchdog.repeatsCutOff(said + "…", cutOff: said))
    XCTAssertTrue(CallWatchdog.repeatsCutOff("Let me look. Yes, it's wired…", cutOff: said))
    XCTAssertFalse(CallWatchdog.repeatsCutOff("Not from here, this call is read-only.", cutOff: said))
    XCTAssertFalse(CallWatchdog.repeatsCutOff("Yes…", cutOff: "Yes, it is."))
    XCTAssertFalse(CallWatchdog.repeatsCutOff(said, cutOff: ""))
  }

  func testAudioIsAbsentOnlyWhileTextKeepsComingWithoutAudio() {
    XCTAssertFalse(CallWatchdog.audioAbsent(now: 10_000, lastTextAt: 0, lastAudioAt: 0))
    XCTAssertFalse(CallWatchdog.audioAbsent(now: 10_000, lastTextAt: 9_000, lastAudioAt: 8_000))
    XCTAssertTrue(CallWatchdog.audioAbsent(now: 10_000, lastTextAt: 9_000, lastAudioAt: 4_000))
    XCTAssertFalse(CallWatchdog.audioAbsent(now: 20_000, lastTextAt: 9_000, lastAudioAt: 0))  // Tony went quiet
  }

  func testPlaybackIsDescribedInOneClause() {
    XCTAssertEqual(PlaybackStats.describe(nil), "no playback")
    XCTAssertEqual(
      PlaybackStats.describe(PlaybackStats(scheduledS: 1.5, playedS: 1.2, clockRunning: true, pendingS: 0)),
      "played 1.2s of 1.5s")
    XCTAssertEqual(
      PlaybackStats.describe(PlaybackStats(scheduledS: 0, playedS: 0, clockRunning: false, pendingS: 0.4)),
      "played 0.0s of 0.0s (0.4s held, clock not running)")
    XCTAssertEqual(
      PlaybackStats.describe(PlaybackStats(scheduledS: 0, playedS: 0, clockRunning: false, pendingS: 0)),
      "played 0.0s of 0.0s (nothing to play yet)")
    XCTAssertEqual(
      PlaybackStats.describe(PlaybackStats(scheduledS: 2, playedS: 1, clockRunning: false, pendingS: 0)),
      "played 1.0s of 2.0s (clock not running)")
  }
}

final class CallEventLogTests: XCTestCase {
  func testLinesAreStampedSortedAndSeparatedBetweenCalls() {
    let log = CallEventLog()
    log.add("call_start", t: 1200, fields: ["backend": "eleven", "voice": "tony"])
    log.add("call_ready", t: 3400, fields: ["out_rate": 16000.0, "session": "s 1"])
    log.add("call_ended", t: 9000, fields: ["reason": "stopped", "badly": false])
    log.add("call_start", t: 12000, fields: ["backend": "gemini", "voice": "tony"])
    XCTAssertEqual(
      log.lines,
      [
        "+1.2s call_start backend=eleven voice=tony",
        "+3.4s call_ready out_rate=16000 session=\"s 1\"",
        "+9.0s call_ended badly=false reason=stopped",
        CallEventLog.separator,
        "+12.0s call_start backend=gemini voice=tony",
      ])
    XCTAssertEqual(log.currentCall.count, 1)
    XCTAssertEqual(
      log.render(header: [("build", "abc (main)"), ("problem", "")]).components(separatedBy: "\n").prefix(3),
      ["build: abc (main)", "---", "+1.2s call_start backend=eleven voice=tony"])
  }

  func testKeepsTheNewestWhenFull() {
    let log = CallEventLog(limit: 3)
    for i in 0..<5 { log.add("call_x", t: i, fields: [:]) }
    XCTAssertEqual(log.events.map { $0.t }, [2, 3, 4])
  }

  private func events(_ list: [(String, [String: Any])]) -> [CallEvent] {
    list.map { CallEvent(t: 0, type: $0.0, fields: $0.1) }
  }

  func testTroubleIsWhatTheLogSays() {
    let clean = events([
      ("call_start", [:]), ("call_ready", [:]), ("call_mic", ["action": "open", "ok": true]),
      ("call_problem", ["problem": ""]), ("call_ended", ["reason": "stopped", "badly": false]),
    ])
    XCTAssertFalse(CallEventLog.hadTrouble(clean))
    XCTAssertTrue(CallEventLog.hadTrouble(clean + events([("call_heal", ["action": "rearm_mic"])])))
    XCTAssertTrue(CallEventLog.hadTrouble(events([("call_problem", ["problem": "the microphone stopped delivering"])])))
    // #417: a failed fetch of the voices' recommendation is a fallback, not call trouble.
    XCTAssertFalse(CallEventLog.hadTrouble(clean + events([("call_settings", ["ok": false, "status": 0])])))
    // #442: the log not reaching the archive is not the call's trouble either.
    XCTAssertFalse(CallEventLog.hadTrouble(clean + events([("call_archive", ["ok": false, "reason": "offline"])])))
    // #545: Larry's tool answer failing is his side, not the call's.
    XCTAssertFalse(
      CallEventLog.hadTrouble(
        clean + events([("call_bridge", ["kind": "tool_result", "ok": false, "answer": "no usable answer"])])))
    XCTAssertTrue(
      CallEventLog.hadTrouble(events([("call_bridge", ["kind": "socket", "ok": false])])),
      "the exemption is keyed on kind: a synthetic guard, no such bridge line exists")
    XCTAssertTrue(CallEventLog.hadTrouble(events([("call_ended", ["reason": "connection lost", "badly": true])])))
    XCTAssertTrue(CallEventLog.hadTrouble(events([("call_audio", ["action": "engine_start", "ok": false])])))
    XCTAssertFalse(CallEventLog.hadTrouble(events([("timer_cue", ["ok": false])])))  // not the call's
  }
}
