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
    XCTAssertTrue(CallEventLog.hadTrouble(events([("call_ended", ["reason": "connection lost", "badly": true])])))
    XCTAssertTrue(CallEventLog.hadTrouble(events([("call_audio", ["action": "engine_start", "ok": false])])))
    XCTAssertFalse(CallEventLog.hadTrouble(events([("timer_cue", ["ok": false])])))  // not the call's
  }
}

final class GistTests: XCTestCase {
  let at = Date(timeIntervalSince1970: 1_790_000_000)  // 2026-09-21 14:13:20 UTC

  func testTheBodyIsSecretOneFileTheNoteFirstThenTheReasonAndTheText() throws {
    let data = Gist.body(at: at, why: "troubled call", text: "build: abc\n---\n+1.0s call_start")
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual(object["public"] as? Bool, false)
    XCTAssertEqual(object["description"] as? String, "Grabber Native call diagnostics · 2026-09-21 14:13 UTC · troubled call")
    let files = try XCTUnwrap(object["files"] as? [String: [String: String]])
    XCTAssertEqual(Array(files.keys), ["call-log.txt"])
    let content = try XCTUnwrap(files["call-log.txt"]?["content"])
    XCTAssertTrue(content.hasPrefix(Gist.readerNote()))
    XCTAssertTrue(content.contains("DELETE THIS GIST ONCE YOU HAVE PROCESSED IT"))
    XCTAssertTrue(content.contains("\n\nupload reason: troubled call\nbuild: abc\n---\n+1.0s call_start\n"))
  }

  func testRequestsCarryTheTokenOnlyInTheHeader() {
    let create = Gist.createRequest(token: "ghp_secret", body: Data("{}".utf8))
    XCTAssertEqual(create.httpMethod, "POST")
    XCTAssertEqual(create.url?.absoluteString, "https://api.github.com/gists")
    XCTAssertEqual(create.value(forHTTPHeaderField: "Authorization"), "Bearer ghp_secret")
    XCTAssertEqual(create.value(forHTTPHeaderField: "X-GitHub-Api-Version"), "2022-11-28")
    let delete = Gist.deleteRequest(token: "ghp_secret", id: "abc123")
    XCTAssertEqual(delete.httpMethod, "DELETE")
    XCTAssertEqual(delete.url?.absoluteString, "https://api.github.com/gists/abc123")
  }

  func testACreateAnswerIsAnUploadOrTheReasonGitHubGave() {
    let ok = Gist.parseCreate(
      status: 201, body: Data(#"{"id":"g1","html_url":"https://gist.github.com/g1"}"#.utf8), at: at)
    XCTAssertEqual(try ok.get(), Gist.Upload(id: "g1", url: "https://gist.github.com/g1", at: "2026-09-21T14:13:20.000Z"))
    let denied = Gist.parseCreate(status: 401, body: Data(#"{"message":"Bad credentials"}"#.utf8), at: at)
    XCTAssertEqual(denied, .failure(GistError("GitHub said 401: Bad credentials")))
    XCTAssertEqual(Gist.parseCreate(status: 500, body: nil, at: at), .failure(GistError("GitHub said 500")))
    XCTAssertEqual(
      Gist.parseCreate(status: 201, body: Data("{}".utf8), at: at),
      .failure(GistError("GitHub answered 201 without a gist id")))
  }

  func testADeleteIsDoneAlreadyGoneOrAnError() {
    XCTAssertEqual(Gist.parseDelete(status: 204), .success(true))
    XCTAssertEqual(Gist.parseDelete(status: 404), .success(false))
    XCTAssertEqual(Gist.parseDelete(status: 401), .failure(GistError("GitHub said 401")))
  }

  private func uploads(_ n: Int) -> [Gist.Upload] {
    (0..<n).map { Gist.Upload(id: "g\($0)", url: "u\($0)", at: String(format: "2026-09-%02dT00:00:00.000Z", $0 + 1)) }
  }

  func testPruneKeepsTheNewestTen() {
    let (keep, drop) = Gist.prune(uploads(12).shuffled())
    XCTAssertEqual(keep.map(\.id), (2..<12).reversed().map { "g\($0)" })
    XCTAssertEqual(drop.map(\.id), ["g1", "g0"])
  }

  func testRetireKeepsAGistWhoseDeleteFailedAndDropsOneAlreadyGone() async {
    let kept = await Gist.retire(uploads(13)) { id in
      if id == "g0" { throw GistError("offline") }
      return id != "g1"  // g1 already gone
    }
    XCTAssertEqual(kept.count, 11)
    XCTAssertEqual(kept.last?.id, "g0")
  }

  func testUploadsRoundTripAndJunkReadsAsNone() {
    let list = uploads(2)
    XCTAssertEqual(Gist.decodeUploads(Gist.encodeUploads(list)), list)
    XCTAssertEqual(Gist.decodeUploads(nil), [])
    XCTAssertEqual(Gist.decodeUploads("not json"), [])
    XCTAssertEqual(Gist.decodeUploads(#"[{"id":"a"},{"id":"b","url":"u","at":"t"}]"#).map(\.id), ["b"])
  }
}
