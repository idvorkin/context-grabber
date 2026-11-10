//  #802: who gives way to whom over the phone's one audio session, as a table a host test can read. It encodes what
//  the app did on 2026-11-09, gaps included: each rule names the line it was transcribed from, and nothing here
//  touches AVAudioSession. AppModel asks at each moment and carries out the answer. Who records from the microphone
//  is `MicFloor`'s (one holder or nobody, audit finding 4); this table is who plays and who pauses.

/// Something in the app that plays through, or records from, the shared audio session.
public enum AudioUser: String, CaseIterable, Sendable {
  /// The call with Larry. Its raw value is the eulogy song's `play_held` log field.
  case call
  /// The Gym Timer's rounds workout.
  case timer
  case breathe
  /// The eulogy song's player.
  case song
  /// The card screen's spoken ask and reveal.
  case card
  /// Chat's dictation.
  case chatVoice
  /// The report dialog's dictation (BugKit).
  case reportDictation
  /// The whiteboard's microphone.
  case whiteboardMic
  case cockpit
}

/// A moment at which something wants the audio session, or wants to change it.
public enum AudioAsk: String, CaseIterable, Sendable {
  /// The call's screen comes up; a call may already be live, or never start.
  case callScreenOpens
  /// A call is about to configure the session.
  case callStarts
  /// START on the Gym Timer.
  case timerStarts
  case breatheOpens
  /// A breathing session begins.
  case breatheStarts
  /// The eulogy song's tile: its sheet comes up, and a play follows (`songPlays`).
  case songOpens
  /// Any play of the eulogy song: the tile, the sheet's button, the lock screen's.
  case songPlays
  /// The card screen is about to speak, at an ask and again at its reveal.
  case cardSpeaks
  case cockpitOpens
  /// Settings' Reset audio.
  case audioReset
}

/// What the floor says when asked.
public enum AudioDecision: Equatable, Sendable {
  /// The holder pauses or stops. `to` is the asker as the timer's `timer_yield` and the song's `pause` lines log it;
  /// chat's dictation takes no name (it only ever yields to a call, and logs its own `why: call_started`).
  case yield(AudioUser, to: String)
  /// The asker goes without the session while this holder has it: it waits, stays silent or says why.
  case refuse(by: AudioUser)
}

/// One line of the table: at `ask`, while `holder` has the session, `outcome`.
public struct AudioRule: Equatable, Sendable {
  public enum Outcome: Equatable, Sendable {
    case holderYields(to: String)
    case askerRefused
  }
  public let ask: AudioAsk
  public let holder: AudioUser
  public let outcome: Outcome
  /// The line the rule was transcribed from, as of 7e64571e, and the bug behind it.
  public let source: String
}

public enum AudioFloor {
  /// Every rule, in the order its side effects happen. A pair with no rule here coexists: nobody arbitrates it.
  public static let rules: [AudioRule] = [
    rule(.callScreenOpens, .timer, .holderYields(to: "call"), "AppModel.swift:767 openCall (story 191)"),
    rule(.callStarts, .song, .holderYields(to: "call"), "AppModel.swift:184 call.willStart (#197)"),
    // Chat's dictation stopping for the call is the microphone's: `MicFloor`, a call taking it from anyone.
    rule(.breatheOpens, .timer, .holderYields(to: "breathe"), "AppModel.swift:503 openBreathe (story 191)"),
    rule(
      .songOpens, .timer, .holderYields(to: "eulogy_song"), "AppModel.swift:644 playEulogySong (story 191, 34902620)"),
    // The same answer keeps the song from letting go of a call's session when it pauses (EulogySong.swift:122, #371).
    rule(.songPlays, .call, .askerRefused, "AppModel.swift:82 song.heldBy, EulogySong.swift:47 (#197)"),
    rule(.cardSpeaks, .call, .askerRefused, "AppModel.swift:566 mayTheCardSpeak (#219)"),
    rule(.cardSpeaks, .song, .holderYields(to: "card"), "AppModel.swift:567 mayTheCardSpeak (#219)"),
    // The dictations' and the board's mic against a call and each other: `MicFloor.rules`.
    rule(.cockpitOpens, .timer, .holderYields(to: "cockpit"), "AppModel.swift:718 openCockpit (story 191, 34902620)"),
    rule(.audioReset, .call, .askerRefused, "AppModel.swift:694 resetAudio, DiagnosticsView.swift:472 (story 149)"),
  ]

  /// Every holder `decide` can ask `isHolding` about: the ones that refuse an asker in some row. For one ask it asks only about those with a refusal row for that ask. Whoever answers `isHolding` (AppModel's
  /// `holdsAudio`) must answer truthfully for each of these: a new one here needs a case there.
  public static let refusers: Set<AudioUser> = Set(rules.filter { $0.outcome == .askerRefused }.map(\.holder))

  /// The decisions for `ask`, in the order to carry them out. The first holder that refuses is the whole answer:
  /// nothing yields to an asker that goes without. Otherwise every holder with a yield rule is asked to yield,
  /// whether or not it has the session: each knows best whether it is sounding and ignores the ask when it is not.
  /// So `isHolding` is asked only about the refusing holders, in table order, and no further than the first yes.
  public static func decide(_ ask: AudioAsk, isHolding: (AudioUser) -> Bool) -> [AudioDecision] {
    let mine = rules.filter { $0.ask == ask }
    if let refusal = mine.first(where: { $0.outcome == .askerRefused && isHolding($0.holder) }) {
      return [.refuse(by: refusal.holder)]
    }
    return mine.compactMap { rule in
      if case .holderYields(let to) = rule.outcome { return .yield(rule.holder, to: to) }
      return nil
    }
  }

  public static func decide(_ ask: AudioAsk, holding: Set<AudioUser>) -> [AudioDecision] {
    decide(ask) { holding.contains($0) }
  }

  private static func rule(
    _ ask: AudioAsk, _ holder: AudioUser, _ outcome: AudioRule.Outcome, _ source: String
  ) -> AudioRule {
    AudioRule(ask: ask, holder: holder, outcome: outcome, source: source)
  }
}
