//  Audit finding 4 (spec 2026-11-10-microphone-floor-design.md): the phone has one microphone, so the floor has one
//  holder or nobody. Every pair of the four that record (a call, chat's dictation, the report's dictation, the
//  board's mic) has a row here, and `request` is the only answer: a call takes the mic from anyone, anyone else waits
//  for whoever has it. Pure; AppModel keeps the floor and carries out what a call's taking means for the one it took
//  from. The playback rules (who pauses for whom) stay in `AudioFloor.rules`.

/// What the floor says to a recorder asking for the microphone.
public enum MicAnswer: Equatable, Sendable {
  /// The asker has it now. `took`: who had it and must stop (only a call takes it from someone).
  case granted(took: AudioUser?)
  /// Someone else has it: the asker does not start, and says who.
  case refused(by: AudioUser)
}

/// One row of the mic table: `asker` asks while `holder` has the microphone.
public struct MicRule: Equatable, Sendable {
  public enum Outcome: Equatable, Sendable {
    /// The asker already holds it: nothing changes.
    case keeps
    /// The asker takes it; the holder stops.
    case takes
    /// The asker goes without until the holder lets go.
    case refused
  }
  public enum Enforcer: Equatable, Sendable {
    /// The floor answers it: the asker asks through it and the holder is known to it.
    case floor
    /// The board checks the call for itself, as before the table (its view still reads the call directly).
    case theBoard
    /// Nobody yet: the board does not ask the floor, nor tell it when its mic is on (#821 rewrites that view).
    case nobodyYet
  }

  public let asker: AudioUser
  public let holder: AudioUser
  public let outcome: Outcome
  public let enforcedBy: Enforcer
}

public struct MicFloor: Equatable, Sendable {
  /// The four that record from the microphone, the call first: it beats the other three.
  public static let recorders: [AudioUser] = [.call, .chatVoice, .reportDictation, .whiteboardMic]

  /// Every ordered pair of recorders, a recorder asking again included: 16 rows.
  public static let rules: [MicRule] = recorders.flatMap { asker in
    recorders.map { holder in rule(asker, holder) }
  }

  public static func rule(_ asker: AudioUser, _ holder: AudioUser) -> MicRule {
    let outcome: MicRule.Outcome = asker == holder ? .keeps : asker == .call ? .takes : .refused
    let enforcedBy: MicRule.Enforcer
    switch (asker, holder) {
    case (.whiteboardMic, .call), (.call, .whiteboardMic), (.whiteboardMic, .whiteboardMic): enforcedBy = .theBoard
    case (.whiteboardMic, _), (_, .whiteboardMic): enforcedBy = .nobodyYet
    default: enforcedBy = .floor
    }
    return MicRule(asker: asker, holder: holder, outcome: outcome, enforcedBy: enforcedBy)
  }

  /// Who has the microphone; nil when nobody does.
  public private(set) var holder: AudioUser?

  public init() {}

  /// `user` wants the microphone. `stillHolding` says whether the holder on record is still recording: a recorder
  /// whose end the app can't always see (a dictation that failed to start, a report dialog closed) is let go here
  /// rather than holding the mic for good.
  public mutating func request(_ user: AudioUser, stillHolding: (AudioUser) -> Bool) -> MicAnswer {
    if let held = holder, held != user, !stillHolding(held) { holder = nil }
    guard let held = holder else {
      holder = user
      return .granted(took: nil)
    }
    switch Self.rule(user, held).outcome {
    case .keeps: return .granted(took: nil)
    case .takes:
      holder = user
      return .granted(took: held)
    case .refused: return .refused(by: held)
    }
  }

  /// Whether someone other than `user` has the microphone now, without asking for it: what a recognizer checks
  /// again while it starts, and before it lists the microphones.
  public func heldByAnother(than user: AudioUser, stillHolding: (AudioUser) -> Bool) -> AudioUser? {
    guard let held = holder, held != user, stillHolding(held) else { return nil }
    return held
  }

  /// `user` stopped recording. Only the holder's letting go frees the microphone.
  public mutating func release(_ user: AudioUser) {
    if holder == user { holder = nil }
  }
}
