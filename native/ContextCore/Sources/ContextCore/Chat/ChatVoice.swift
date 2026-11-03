//  Speaking a message in Chat (#448, chat spec "Speaking a message"): the platform-free half of the thread's mic.
//  The words come from BugKit's dictation (Apple's recognizer, the problem report's); this is its limit and its clock.

import Foundation

public enum ChatVoice {
  /// The longest recording (Igor, 2026-10-26): at this it stops on its own, as if he had tapped stop.
  public static let limit: TimeInterval = 5 * 60

  /// The quiet line under the bar after the limit stopped a recording.
  public static var cappedLine: String { "Stopped at \(Int(limit) / 60) minutes." }

  /// The recording button's clock: `0:07`, `1:12`.
  public static func elapsed(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    return "\(s / 60):" + String(format: "%02d", s % 60)
  }
}

/// The chat mic's clock: each recording's start and stop, and whether the five-minute timer that fired is still
/// this recording's. A stop, or a newer recording, makes an older timer's firing a no-op.
public struct ChatVoiceClock: Equatable, Sendable {
  public enum Decision: Equatable, Sendable {
    /// Nothing to do: the same state again.
    case none
    /// A recording began: arm a timer for `recording`, due at `capAt`.
    case started(recording: Int, capAt: Date)
    case stopped(seconds: Double)
  }

  /// Counts recordings, so a timer names the one it was armed for.
  public private(set) var recording = 0
  public private(set) var since: Date?

  public init() {}

  /// The dictation started or stopped listening.
  public mutating func listening(_ on: Bool, at now: Date) -> Decision {
    switch (on, since) {
    case (true, nil):
      recording += 1
      since = now
      return .started(recording: recording, capAt: now.addingTimeInterval(ChatVoice.limit))
    case (false, let started?):
      since = nil
      return .stopped(seconds: (now.timeIntervalSince(started) * 10).rounded() / 10)
    default:
      return .none
    }
  }

  /// A timer armed for `recording` fired at `now`: stop for the limit only if that recording is still the one
  /// going and has run the full limit (half a second of timer slack).
  public func shouldCap(recording armed: Int, at now: Date) -> Bool {
    guard let since, armed == recording else { return false }
    return now.timeIntervalSince(since) >= ChatVoice.limit - 0.5
  }
}

/// The words for one thread's bar, handed over once: a bar takes only its own thread's, so another thread never
/// shows words spoken in this one.
public struct ChatVoiceWords: Equatable, Sendable {
  public struct Words: Equatable, Sendable {
    /// Tells a repeat of the same text apart, so the bar takes each one.
    public let id: Int
    public let thread: String
    public let text: String
  }

  public private(set) var latest: Words?
  private var count = 0

  public init() {}

  /// The dictation's whole draft so far for `thread` (what was typed, then the words).
  public mutating func heard(_ text: String, thread: String) {
    count += 1
    latest = Words(id: count, thread: thread, text: text)
  }

  /// The words for `thread`, once; nil when there are none or they are another thread's (which stay for it).
  public mutating func take(thread: String) -> String? {
    guard let words = latest, words.thread == thread else { return nil }
    latest = nil
    return words.text
  }
}

/// The voice button beside the + (#637, stories 470 and 473): a new chat that opens recording, once. The ask rides from
/// the tap to the new chat's bar, which takes it as it appears, so a bar coming back on screen never records again and
/// a + after it never records at all.
public struct ChatNewChatVoice: Equatable, Sendable {
  /// What the new chat's bar does with the ask.
  public enum Start: Equatable, Sendable {
    case record
    /// A live call holds the microphone: it opens recording nothing and says so.
    case callHasMic
    /// An earlier recording is still ending. It is never stopped from here: this is not the mic's toggle.
    case stillRecording
  }

  private var asked = false

  public init() {}

  /// A tap on the + (`voice` false) or on the voice button (`voice` true).
  public mutating func open(voice: Bool) { asked = voice }

  /// Whether this new chat should record: true once per tap on the voice button.
  public mutating func take() -> Bool {
    defer { asked = false }
    return asked
  }

  public static func start(callLive: Bool, recording: Bool) -> Start {
    if callLive { return .callHasMic }
    return recording ? .stillRecording : .record
  }
}
