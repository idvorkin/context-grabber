//  The eulogy song's player (story 137, #177, #195, #197, #201, #370): what play, pause, a seek, the finish and a
//  failure do, and when the song takes and lets go of the audio session. The audio floor decides who pauses it
//  (AudioFloor); this decides what pausing, playing and failing mean. A SongPlayer wraps AVAudioPlayer, the audio
//  session, the lock screen's now-playing card and the clock, so the rules are host-tested with a fake; the app's
//  EulogySongPlayer is the adapter that publishes the state and draws the copyable problem.

import Foundation

/// What loading the song came to.
public enum SongLoad: Equatable, Sendable {
  case loaded
  /// No song file in this build.
  case missing
  /// The file is there but would not open.
  case failed(String)
}

/// A failure for the sheet's copyable problem; the app adds where the song was and the audio session's state.
public struct SongFailure: Equatable, Sendable {
  public let message: String
  public let context: String
  public let extra: [String: String]
}

/// The song's player and what it plays through. Every call comes on the main thread.
public protocol SongPlayer: AnyObject {
  /// The audio session for playback, not mixed (the song pauses other music) and active. nil, or what went wrong.
  func takeSession() -> String?
  /// Deactivate, telling others they may resume.
  func releaseSession()
  /// The hardware sample rate now.
  var sampleRate: Double { get }

  /// Whether a player is made.
  var hasPlayer: Bool { get }
  /// Make the player (prepared to play) for the song.
  func load() -> SongLoad
  /// Stop and forget the player.
  func drop()
  var isPlaying: Bool { get }
  var currentTime: Double { get set }
  var duration: Double { get }
  func play() -> Bool
  func pause()
  func stop()
  /// Make the player ready again where it is.
  func prepare() -> Bool

  /// What the song goes out through and at what rate, for the log.
  func audioFields() -> [String: Any]
  /// The session's state when a play is refused, for the log.
  func refusalFields() -> [String: Any]
  /// The lock screen and Control Center's card.
  func showNowPlaying(elapsed: Double, duration: Double, playing: Bool)
  /// Look every `seconds` until stopped.
  func startTicking(every seconds: Double, _ look: @escaping () -> Void)
  func stopTicking()
  /// Seconds on the wall clock.
  var now: Double { get }
  func log(_ type: String, _ fields: [String: Any])
}

public final class SongPlayback {
  public private(set) var isPlaying = false
  public private(set) var elapsed: Double = 0
  public private(set) var duration: Double = 0
  /// What went wrong, for the copyable problem (#201).
  public private(set) var failure: SongFailure?
  /// Counts every failure set, so the app draws a new problem even when the words repeat.
  public private(set) var failures = 0
  /// Why the song is not playing although asked to: a live call (#197).
  public private(set) var waiting: String?
  /// Who holds the audio, if anyone: while it answers, the song neither plays nor touches the session.
  public var heldBy: () -> String? = { nil }
  /// Called after any of the published state may have changed.
  public var onChange: (() -> Void)?

  public static let waitingForCall = "The song waits until the call ends."
  /// The clock and the lock screen move twice a second.
  public static let lookEvery = 0.5

  private let player: SongPlayer
  /// The hardware sample rate the player was prepared against: a player prepared on the car's 16 kHz hands-free line
  /// and played on a 48 kHz route ran three times too fast (#370).
  private var preparedRate: Double = 0
  /// Where the song and the wall clock were when it last started or moved, to catch its clock running away (#370).
  private var anchor: (song: Double, wall: Double)?
  private var driftLogged = false
  private var ticking = false

  public init(player: SongPlayer) {
    self.player = player
  }

  /// Started and not back at the start: what the home screen's small player shows for (#195).
  public var isStarted: Bool { isPlaying || elapsed > 0 }

  public func play(from source: String) {
    if let holder = heldBy() {
      waiting = Self.waitingForCall
      player.log("eulogy_song", ["action": "play_held", "from": source, "by": holder])
      onChange?()
      return
    }
    waiting = nil
    // The session first, so the player is prepared against the route the song plays on (#370).
    let sessionError = player.takeSession() ?? ""
    if !sessionError.isEmpty {
      player.log("eulogy_song", ["action": "session", "ok": false, "message": sessionError])
    }
    reloadIfTheRateMoved()
    // No song to play: let the session go, so the music it paused comes back (Codex on #371).
    guard loaded() else {
      release()
      onChange?()
      return
    }
    var ok = player.play()
    var how = "play"
    var at = player.currentTime
    if !ok {
      // A paused player can refuse; re-preparing it at the same place is the retry, and a fresh one the last.
      var fields: [String: Any] = ["action": "play_refused", "at": rounded(at), "prepared": player.prepare()]
      fields.merge(player.refusalFields()) { $1 }
      player.log("eulogy_song", fields)
      ok = player.play()
      how = "re_prepared"
      if !ok {
        player.drop()
        if loaded() {
          player.currentTime = at
          ok = player.play()
          how = "fresh_player"
        }
      }
    }
    // With no fresh player either, where the refused one was.
    if player.hasPlayer { at = player.currentTime }
    var fields = audioFields()
    fields.merge(["action": "play", "from": source, "at": rounded(at), "ok": ok, "how": how]) { $1 }
    player.log("eulogy_song", fields)
    if ok {
      failure = nil
    } else {
      fail(
        "The song would not start.", "EulogySong.play",
        ["from": source, "tries": how, "session_error": sessionError.isEmpty ? "none" : sessionError])
    }
    sync()
    if !ok { release() }
  }

  public func pause(from source: String) {
    guard player.hasPlayer, player.isPlaying else { return }
    player.pause()
    player.log("eulogy_song", ["action": "pause", "from": source, "at": rounded(player.currentTime)])
    sync()
  }

  /// A call or the card is starting: pause where the song is, before it takes the session.
  public func yield(to holder: String) {
    pause(from: holder)
  }

  public func toggle(from source: String) {
    if isPlaying { pause(from: source) } else { play(from: source) }
  }

  /// The scrubber let go: the song carries on from there, playing or paused as it was.
  public func seek(to time: Double, from source: String) {
    guard loaded() else {
      onChange?()
      return
    }
    let was = player.currentTime
    player.currentTime = min(max(time, 0), player.duration)
    player.log(
      "eulogy_song", ["action": "seek", "from": source, "was": rounded(was), "at": rounded(player.currentTime)])
    sync()
  }

  public func restart(from source: String) {
    guard loaded() else {
      onChange?()
      return
    }
    player.log("eulogy_song", ["action": "restart", "from": source, "was": rounded(player.currentTime)])
    player.currentTime = 0
    play(from: source)
  }

  /// The small player's ✕: stopped and back at the start, so it goes away.
  public func stop(from source: String) {
    guard player.hasPlayer else { return }
    player.log("eulogy_song", ["action": "stop", "from": source, "at": rounded(player.currentTime)])
    player.stop()
    player.currentTime = 0
    sync()
    release()
  }

  /// The song reached its end (or the player gave up on it): back to the start, the audio let go.
  public func finished(ok: Bool) {
    player.currentTime = 0
    player.log("eulogy_song", ["action": "finished", "ok": ok])
    sync()
    release()
  }

  /// A phone call or Siri took the audio (`began`), or gave it back.
  public func interrupted(began: Bool) {
    guard player.hasPlayer else { return }
    player.log(
      "eulogy_song", ["action": began ? "interrupted" : "interruption_ended", "at": rounded(player.currentTime)])
    sync()
  }

  // MARK: - private

  /// Lets the session go only when nothing else holds it: a call's session is the call's.
  private func release() {
    guard heldBy() == nil else { return }
    player.releaseSession()
  }

  /// The player, made if it is not yet; false when the song cannot be loaded (the failure says why).
  private func loaded() -> Bool {
    if player.hasPlayer { return true }
    switch player.load() {
    case .loaded:
      preparedRate = player.sampleRate
      duration = player.duration
      failure = nil
      var fields = audioFields()
      fields.merge(["action": "load", "ok": true, "duration_s": rounded(player.duration)]) { $1 }
      player.log("eulogy_song", fields)
      return true
    case .missing:
      fail("The song is missing from this build.", "EulogySong.load", ["file": "eulogy-song.mp3"])
      player.log("eulogy_song", ["action": "load", "ok": false, "message": "eulogy-song.mp3 not in the bundle"])
      return false
    case .failed(let error):
      fail("The song would not load.", "EulogySong.load", ["error": error])
      player.log("eulogy_song", ["action": "load", "ok": false, "message": error])
      return false
    }
  }

  /// A player prepared at another hardware sample rate is replaced by a fresh one at the same place (#370).
  private func reloadIfTheRateMoved() {
    guard player.hasPlayer else { return }
    let now = player.sampleRate
    guard now != preparedRate else { return }
    let at = player.currentTime
    player.drop()
    player.log(
      "eulogy_song",
      ["action": "reload", "reason": "sample_rate", "was_hz": preparedRate, "now_hz": now, "at": rounded(at)])
    if loaded() { player.currentTime = at }
  }

  private func fail(_ message: String, _ context: String, _ extra: [String: String]) {
    failure = SongFailure(message: message, context: context, extra: extra)
    failures += 1
  }

  private func sync() {
    guard player.hasPlayer else {
      onChange?()
      return
    }
    isPlaying = player.isPlaying
    elapsed = player.currentTime
    anchor = player.isPlaying ? (player.currentTime, player.now) : nil
    player.showNowPlaying(elapsed: player.currentTime, duration: player.duration, playing: player.isPlaying)
    if isPlaying, !ticking {
      ticking = true
      player.startTicking(every: Self.lookEvery) { [weak self] in self?.tick() }
    } else if !isPlaying, ticking {
      ticking = false
      player.stopTicking()
    }
    onChange?()
  }

  private func tick() {
    guard player.hasPlayer else { return }
    elapsed = player.currentTime
    if player.isPlaying != isPlaying {
      sync()
    } else {
      onChange?()
    }
    checkDrift()
  }

  /// Once per launch, the song's clock against the wall clock after five seconds of playing: 1.0 is on time (#370).
  private func checkDrift() {
    guard !driftLogged, player.isPlaying, let anchor else { return }
    let wall = player.now - anchor.wall
    guard wall >= 5 else { return }
    let ratio = (player.currentTime - anchor.song) / wall
    guard ratio > 1.2 || ratio < 0.8 else { return }
    driftLogged = true
    var fields = audioFields()
    fields.merge([
      "action": "rate_drift", "ratio": (ratio * 100).rounded() / 100, "wall_s": rounded(wall),
      "at": rounded(player.currentTime),
    ]) { $1 }
    player.log("eulogy_song", fields)
  }

  /// The player's route and rate, and the rate it was prepared at (#370).
  private func audioFields() -> [String: Any] {
    var fields = player.audioFields()
    fields["prepared_hz"] = preparedRate
    return fields
  }

  private func rounded(_ t: Double) -> Double { (t * 10).rounded() / 10 }
}
