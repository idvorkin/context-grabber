//  The call's liveness rules, with no platform in them (#95).
//
//  Igor's dumps of 2026-08-30 showed the audio session coming up with one direction dead, either way round: a
//  mic tap that delivered one buffer and then nothing after a route change; a socket that delivered 15 frames of
//  Larry in 63 s; a greeting played into an output whose clock had not started. Each has a plain signal — "no
//  buffer for a while", "the clock is not advancing", "text is arriving but audio is not" — and a plain cure. The
//  rules live here so the host can test them; the app's audio layer and CallSession apply them.

import Foundation

public enum CallWatchdog {
  /// A mic buffer is ~100 ms; fifteen missing in a row is a dead tap, not a hiccup.
  public static let micStallMs = 1500.0
  /// How long the output clock may sit still with audio due before playback is reopened.
  public static let outputStallMs = 1000.0
  /// How long to wait for the output clock to start before reopening playback once.
  public static let clockStartMs = 2000.0
  /// Tony's words arriving as text with no audio behind them for this long: the socket or the vendor.
  public static let audioAbsentMs = 5000.0
  /// Re-arm a stalled tap this many times before saying the microphone is gone.
  public static let micStallsBeforeGivingUp = 3
  /// A stalled output is reopened at most this often.
  public static let reopenMinGapMs = 5000.0

  /// #186: Larry's audio must have been in hand this long before a silent mixer counts. A reply that lands in the
  /// last moment of a five-second window has not had time to play, and rebuilding for it killed a working call.
  public static let silentMixerDueMs = 1500.0
  /// A heal's rebuild that fails (the microphone can read 0 Hz just after the session restarts) is tried again
  /// after each of these waits before the call says its audio is gone.
  public static let rebuildRetryMs: [Double] = [500, 1000, 2000]

  public static let micStopped = "the microphone stopped delivering"
  public static let audioGone = "the phone's audio stopped: hang up and call again"
  public static let audioNotArriving = "Tony's audio is not arriving from the bridge"
  public static let audioNotPlaying = "Tony's audio is arriving but not playing"

  public enum Verdict: Equatable, Sendable { case ok, stalled, idle }

  /// #146's net, without #186's false alarm: audio arrived (loud enough to hear) at least `silentMixerDueMs` before
  /// the window closed, the mixer rendered buffers, and every one of them was silent.
  public static func silentMixer(now: Double, firstLoudRxAt: Double?, mixBuffers: Int, mixPeak: Float) -> Bool {
    guard let firstLoudRxAt, mixBuffers > 0, mixPeak == 0 else { return false }
    return now - firstLoudRxAt >= silentMixerDueMs
  }

  /// "stalled" when an armed, unpaused recorder has gone quiet for `micStallMs`. `lastBufferAt` 0 = none since
  /// arming; a fresh tap gets the full grace from `armedAt`.
  public static func mic(now: Double, armed: Bool, paused: Bool, armedAt: Double, lastBufferAt: Double) -> Verdict {
    guard armed, !paused else { return .idle }
    return now - max(lastBufferAt, armedAt) >= micStallMs ? .stalled : .ok
  }

  /// "stalled" when audio is due (the playhead is ahead of the clock), a frame was scheduled in the last two
  /// seconds, and the clock (seconds) has not moved since the previous check at least `outputStallMs` ago.
  public static func output(
    now: Double, currentTime: Double, previousTime: Double, previousCheckAt: Double, playhead: Double,
    lastScheduledAt: Double
  ) -> Verdict {
    let due = playhead > currentTime + 0.05
    let recent = now - lastScheduledAt < 2000
    guard due, recent else { return .idle }
    if currentTime > previousTime { return .ok }
    return now - previousCheckAt >= outputStallMs ? .stalled : .ok
  }

  /// Tony is talking (text keeps arriving) but nothing has come down the audio channel for `audioAbsentMs`.
  /// 0 = never.
  public static func audioAbsent(now: Double, lastTextAt: Double, lastAudioAt: Double) -> Bool {
    guard lastTextAt > 0, now - lastTextAt <= audioAbsentMs else { return false }
    return now - max(lastAudioAt, 0) > audioAbsentMs
  }
}

/// The output side, for the periodic log line and the ending.
public struct PlaybackStats: Equatable, Sendable {
  /// Seconds of Larry scheduled so far (flushed audio not counted).
  public var scheduledS: Double
  /// Seconds the speaker has rendered of that.
  public var playedS: Double
  public var clockRunning: Bool
  /// Seconds of Larry held back, waiting for a clock.
  public var pendingS: Double

  public init(scheduledS: Double, playedS: Double, clockRunning: Bool, pendingS: Double) {
    self.scheduledS = scheduledS
    self.playedS = playedS
    self.clockRunning = clockRunning
    self.pendingS = pendingS
  }

  /// The output in one clause. "clock not running" only when something is waiting on it.
  public static func describe(_ s: PlaybackStats?) -> String {
    guard let s else { return "no playback" }
    let base = "played \(String(format: "%.1f", s.playedS))s of \(String(format: "%.1f", s.scheduledS))s"
    if s.clockRunning { return base }
    if s.pendingS > 0 { return "\(base) (\(String(format: "%.1f", s.pendingS))s held, clock not running)" }
    if s.scheduledS == 0 { return "\(base) (nothing to play yet)" }
    return "\(base) (clock not running)"
  }
}
