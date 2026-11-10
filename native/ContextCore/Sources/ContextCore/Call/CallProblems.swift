//  The call's problem line: every writer owns its own slot, and the line is computed from them — the first one
//  still standing, in the spec's "who wins" order — never stored. Clearing one slot reveals the next.
//
//  Spec: "The problem line" in docs/superpowers/specs/2026-08-28-native-call-screen-design.md (state-machine audit
//  of 2026-11-10, finding 1: before this, five writers shared one string and a clear by one wiped the others).

public struct CallProblems: Equatable, Sendable {
  /// The audio layer's own verdict (`CallWatchdog.micStopped`, `audioNotPlaying`, `audioGone`); nil when fine.
  public var audio: String?
  /// The mic failed to open; lifts at its first buffer.
  public var micOpenFailed: String?
  /// A mic restart failed; lifts at the mic's first sound.
  public var micRestartFailed: String?
  /// Exact zeros after the call's one restart (or no buffer after the redial); lifts at the first sound.
  public var micSilent = false
  /// The bridge did not acknowledge the mic after the call's one restart; lifts with the ack.
  public var micNotReaching = false
  /// Tony's words arriving as text with no audio behind them; lifts with audio, or when his text goes quiet.
  public var audioNotArriving = false
  /// The bridge's error. Nothing withdraws it, so it ranks last and stands until the call ends.
  public var bridge: String?

  public init() {}

  /// The line on screen: the first standing problem, phone's audio → mic → Tony's audio → bridge.
  public var line: String? {
    if let audio { return audio }
    if let micOpenFailed { return micOpenFailed }
    if let micRestartFailed { return micRestartFailed }
    if micSilent { return CallSession.micSilent }
    if micNotReaching { return CallSession.micNotReaching }
    if audioNotArriving { return CallWatchdog.audioNotArriving }
    return bridge
  }
}
