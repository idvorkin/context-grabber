//  The eulogy song's player (SongPlayback) against a fake AVAudioPlayer, session and clock: play, resume, scrub,
//  restart, stop, the finish, a call holding the audio, a song that cannot play, and the #370 rate checks.

import XCTest

@testable import ContextCore

final class FakeSongPlayer: SongPlayer {
  var calls: [String] = []
  var logs: [[String: Any]] = []
  var sessionError: String?
  var sampleRate: Double = 48_000
  var loadResult = SongLoad.loaded
  /// How many plays to refuse, across players.
  var refusals = 0
  var hasPlayer = false
  var isPlaying = false
  var currentTime: Double = 0
  var duration: Double { hasPlayer ? 134 : 0 }
  var nowPlaying: (elapsed: Double, playing: Bool)?
  var now: Double = 1_000_000
  private var look: (() -> Void)?
  var ticking: Bool { look != nil }

  func takeSession() -> String? {
    calls.append("take")
    return sessionError
  }
  func releaseSession() { calls.append("release") }
  func load() -> SongLoad {
    calls.append("load")
    if loadResult == .loaded {
      hasPlayer = true
      currentTime = 0
    }
    return loadResult
  }
  func drop() {
    calls.append("drop")
    hasPlayer = false
    isPlaying = false
  }
  func play() -> Bool {
    calls.append("play")
    if refusals > 0 {
      refusals -= 1
      return false
    }
    guard hasPlayer else { return false }
    isPlaying = true
    return true
  }
  func pause() {
    calls.append("pause")
    isPlaying = false
  }
  func stop() {
    calls.append("stop")
    isPlaying = false
  }
  func prepare() -> Bool { true }
  func audioFields() -> [String: Any] { ["sample_rate_hz": sampleRate] }
  func refusalFields() -> [String: Any] { ["other_audio": false] }
  func showNowPlaying(elapsed: Double, duration: Double, playing: Bool) { nowPlaying = (elapsed, playing) }
  func startTicking(every seconds: Double, _ look: @escaping () -> Void) {
    calls.append("tick_on")
    self.look = look
  }
  func stopTicking() {
    calls.append("tick_off")
    look = nil
  }
  func log(_ type: String, _ fields: [String: Any]) {
    XCTAssertEqual(type, "eulogy_song")
    logs.append(fields)
  }

  /// The song plays on for `seconds` at `rate` times its own speed, the clock looking twice a second.
  func playOn(_ seconds: Double, rate: Double = 1) {
    for _ in 0..<Int(seconds / SongPlayback.lookEvery) {
      now += SongPlayback.lookEvery
      if isPlaying { currentTime += SongPlayback.lookEvery * rate }
      look?()
    }
  }

  func actions() -> [String] { logs.compactMap { $0["action"] as? String } }
  func last(_ action: String) -> [String: Any]? { logs.last { $0["action"] as? String == action } }
}

final class SongPlaybackTests: XCTestCase {
  private let device = FakeSongPlayer()
  private lazy var song = SongPlayback(player: device)
  private var call: String?

  override func setUp() {
    super.setUp()
    song.heldBy = { [unowned self] in self.call }
  }

  func testPlayTakesTheSessionFirstThenLoadsOnceAndPlays() {
    song.play(from: "tile")
    XCTAssertEqual(device.calls, ["take", "load", "play", "tick_on"])
    XCTAssertTrue(song.isPlaying)
    XCTAssertEqual(song.duration, 134)
    XCTAssertNil(song.failure)
    XCTAssertEqual(device.actions(), ["load", "play"])
    XCTAssertEqual(device.last("play")?["how"] as? String, "play")
    XCTAssertEqual(device.last("play")?["ok"] as? Bool, true)
    XCTAssertEqual(device.last("load")?["prepared_hz"] as? Double, 48_000)
    XCTAssertEqual(device.nowPlaying?.playing, true)
  }

  func testTheClockMovesAndPauseKeepsTheSessionAndThePlace() {
    song.play(from: "tile")
    device.playOn(10)
    XCTAssertEqual(song.elapsed, 10, accuracy: 0.01)
    song.pause(from: "sheet")
    XCTAssertFalse(song.isPlaying)
    XCTAssertFalse(device.ticking)
    XCTAssertFalse(device.calls.contains("release"), "a pause keeps the audio")
    XCTAssertEqual(device.last("pause")?["at"] as? Double, 10)
    XCTAssertTrue(song.isStarted, "paused partway: the small player stays")
  }

  func testResumePlaysOnFromWhereItPausedNotTheStart() {
    song.play(from: "tile")
    device.playOn(12)
    song.toggle(from: "sheet")
    device.playOn(30)
    song.toggle(from: "sheet")
    XCTAssertTrue(song.isPlaying)
    XCTAssertEqual(device.calls.filter { $0 == "load" }.count, 1, "the same player")
    XCTAssertEqual(device.last("play")?["at"] as? Double, 12)
    XCTAssertEqual(device.last("play")?["from"] as? String, "sheet")
  }

  func testWhileACallHoldsTheAudioThePlayWaitsAndTouchesNothing() {
    call = "call"
    song.play(from: "lock_screen")
    XCTAssertEqual(song.waiting, SongPlayback.waitingForCall)
    XCTAssertTrue(device.calls.isEmpty, "no session, no player")
    XCTAssertEqual(device.last("play_held")?["by"] as? String, "call")
    call = nil
    song.play(from: "sheet")
    XCTAssertNil(song.waiting, "the first play after the call clears the line")
    XCTAssertTrue(song.isPlaying)
  }

  func testStartingACallPausesThePlayingSongAndOnlyThatSong() {
    song.yield(to: "call")
    XCTAssertTrue(device.logs.isEmpty, "nothing playing: nothing to pause")
    song.play(from: "tile")
    device.playOn(5)
    song.yield(to: "call")
    XCTAssertFalse(song.isPlaying)
    XCTAssertEqual(device.last("pause")?["from"] as? String, "call")
    XCTAssertTrue(song.isStarted, "the small player offers Resume")
  }

  func testWithACallLiveTheSongNeverLetsGoOfTheCallsAudio() {
    song.play(from: "tile")
    call = "call"
    song.stop(from: "mini")
    song.finished(ok: true)
    XCTAssertFalse(device.calls.contains("release"))
  }

  func testARefusedPlayIsReadiedAgainAtTheSamePlace() {
    song.play(from: "tile")
    device.playOn(20)
    song.pause(from: "sheet")
    device.refusals = 1
    song.play(from: "sheet")
    XCTAssertTrue(song.isPlaying)
    XCTAssertEqual(device.last("play")?["how"] as? String, "re_prepared")
    XCTAssertEqual(device.last("play_refused")?["at"] as? Double, 20)
    XCTAssertEqual(device.last("play_refused")?["prepared"] as? Bool, true)
    XCTAssertEqual(device.last("play_refused")?["other_audio"] as? Bool, false)
  }

  func testRefusedTwiceAFreshPlayerTakesOverAtTheSamePlace() {
    song.play(from: "tile")
    device.playOn(20)
    song.pause(from: "sheet")
    device.refusals = 2
    song.play(from: "sheet")
    XCTAssertTrue(song.isPlaying)
    XCTAssertEqual(device.last("play")?["how"] as? String, "fresh_player")
    XCTAssertEqual(device.currentTime, 20, accuracy: 0.01)
    XCTAssertTrue(device.calls.contains("drop"))
    XCTAssertNil(song.failure)
  }

  func testRefusedThreeTimesTheSongSaysSoAndLetsTheAudioGo() {
    device.refusals = 3
    song.play(from: "tile")
    XCTAssertFalse(song.isPlaying)
    XCTAssertEqual(song.failure?.message, "The song would not start.")
    XCTAssertEqual(song.failure?.context, "EulogySong.play")
    XCTAssertEqual(song.failure?.extra, ["from": "tile", "tries": "fresh_player", "session_error": "none"])
    XCTAssertEqual(device.calls.last, "release", "whatever it paused plays again")
    XCTAssertEqual(device.last("play")?["ok"] as? Bool, false)
    XCTAssertEqual(song.failures, 1)
  }

  func testASessionErrorIsLoggedAndCarriedIntoTheFailure() {
    device.sessionError = "!pri"
    device.refusals = 3
    song.play(from: "tile")
    XCTAssertEqual(device.last("session")?["message"] as? String, "!pri")
    XCTAssertEqual(song.failure?.extra["session_error"], "!pri")
  }

  func testASongMissingFromTheBuildSaysSoAndLetsTheAudioGo() {
    device.loadResult = .missing
    song.play(from: "tile")
    XCTAssertEqual(song.failure?.message, "The song is missing from this build.")
    XCTAssertEqual(song.failure?.extra, ["file": "eulogy-song.mp3"])
    XCTAssertEqual(device.calls, ["take", "load", "release"], "never played")
    XCTAssertEqual(device.last("load")?["ok"] as? Bool, false)
    XCTAssertFalse(song.isPlaying)
    device.loadResult = .failed("bad mp3")
    song.play(from: "sheet")
    XCTAssertEqual(song.failure?.message, "The song would not load.")
    XCTAssertEqual(song.failures, 2, "each failure is drawn anew")
  }

  func testAPlayThatWorksClearsAnEarlierFailure() {
    device.refusals = 3
    song.play(from: "tile")
    song.play(from: "sheet")
    XCTAssertNil(song.failure)
  }

  func testTheScrubberMovesTheSongPlayingOrPausedAsItWas() {
    song.play(from: "tile")
    song.seek(to: 100, from: "sheet")
    XCTAssertTrue(song.isPlaying)
    XCTAssertEqual(song.elapsed, 100)
    XCTAssertEqual(device.last("seek")?["was"] as? Double, 0)
    song.pause(from: "sheet")
    song.seek(to: 500, from: "lock_screen")
    XCTAssertFalse(song.isPlaying, "paused stays paused")
    XCTAssertEqual(song.elapsed, 134, "held inside the song")
    song.seek(to: -5, from: "sheet")
    XCTAssertEqual(song.elapsed, 0)
  }

  func testAScrubBeforeAnyPlayLoadsTheSongWithoutPlaying() {
    song.seek(to: 60, from: "sheet")
    XCTAssertEqual(device.calls, ["load"])
    XCTAssertEqual(song.elapsed, 60)
    XCTAssertFalse(song.isPlaying)
  }

  func testRestartGoesBackToTheStartAndPlays() {
    song.play(from: "tile")
    device.playOn(40)
    song.pause(from: "sheet")
    song.restart(from: "sheet")
    XCTAssertTrue(song.isPlaying)
    XCTAssertEqual(device.last("restart")?["was"] as? Double, 40)
    XCTAssertEqual(device.last("play")?["at"] as? Double, 0)
  }

  func testStopGoesBackToTheStartLetsGoAndTheSmallPlayerGoes() {
    song.stop(from: "mini")
    XCTAssertTrue(device.logs.isEmpty, "never loaded: nothing to stop")
    song.play(from: "tile")
    device.playOn(30)
    song.stop(from: "mini")
    XCTAssertFalse(song.isStarted)
    XCTAssertEqual(Array(device.calls.suffix(2)), ["tick_off", "release"])
    XCTAssertEqual(device.last("stop")?["at"] as? Double, 30)
  }

  func testTheFinishGoesBackToTheStartAndLetsTheAudioGo() {
    song.play(from: "tile")
    device.playOn(134)
    device.isPlaying = false
    song.finished(ok: true)
    XCTAssertFalse(song.isStarted, "the small player goes by itself")
    XCTAssertEqual(device.last("finished")?["ok"] as? Bool, true)
    XCTAssertEqual(device.calls.last, "release")
    XCTAssertFalse(device.ticking)
  }

  func testAPlayerThatStoppedByItselfIsNoticedOnTheNextLook() {
    song.play(from: "tile")
    device.isPlaying = false  // a phone call took the audio
    song.interrupted(began: true)
    XCTAssertFalse(song.isPlaying)
    XCTAssertEqual(device.last("interrupted")?["at"] as? Double, 0)
  }

  func testANewOutputRateReloadsThePlayerWhereTheSongWas() {
    song.play(from: "tile")
    device.playOn(14)
    song.pause(from: "sheet")
    device.sampleRate = 16_000  // the car's hands-free line
    song.play(from: "sheet")
    let reload = device.last("reload")
    XCTAssertEqual(reload?["was_hz"] as? Double, 48_000)
    XCTAssertEqual(reload?["now_hz"] as? Double, 16_000)
    XCTAssertEqual(reload?["at"] as? Double, 14)
    XCTAssertEqual(device.calls.filter { $0 == "load" }.count, 2)
    XCTAssertEqual(device.last("play")?["at"] as? Double, 14)
    XCTAssertEqual(device.last("play")?["prepared_hz"] as? Double, 16_000)
  }

  func testAClockRunningAwayIsLoggedOnceAndOnTimeIsNot() {
    song.play(from: "tile")
    device.playOn(10)
    XCTAssertNil(device.last("rate_drift"), "on time")
    song.pause(from: "sheet")
    song.play(from: "sheet")
    device.playOn(14, rate: 3)
    XCTAssertEqual(device.logs.filter { $0["action"] as? String == "rate_drift" }.count, 1)
    XCTAssertEqual(device.last("rate_drift")?["ratio"] as? Double ?? 0, 3, accuracy: 0.01)
  }
}
