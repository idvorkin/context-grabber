//  Larry's clock on a board (spec 2026-11-12-whiteboard-conversation-design.md, *Larry's clock*, story 667; #879: "This
//  seems very slow, are we crashing/hung?"). While a turn is out the bar's note begins with how long he has been looking
//  at the picture, counted from when it went, so the app being away costs nothing; at the timeout his silence is a
//  copyable problem. The board's model hands in the turn, the clock and whether the Cockpit is answering its looks.

import Foundation

public enum WhiteboardLarryClock {
  /// His state at the start of the bar's note, *Larry · 0:42*, with *Cockpit not answering* when the board's looks at
  /// his thread have been failing. For two seconds after a tap that sent nothing it reads *Larry already has this · 0:12*
  /// (story 765). Nil with no turn out.
  public static func state(_ turn: WhiteboardLarryTurn, now: ContinuousClock.Instant, cockpitAnswering: Bool) -> String?
  {
    guard let seconds = seconds(turn, now: now) else { return nil }
    let who = alreadyHas(turn, now: now) ? "Larry already has this" : "Larry"
    let clock = "\(who) · \(seconds / 60):\(String(format: "%02d", seconds % 60))"
    return cockpitAnswering ? clock : "\(clock) · Cockpit not answering"
  }

  /// The same for VoiceOver, in words: *Larry has been looking for 42 seconds*.
  public static func spoken(_ turn: WhiteboardLarryTurn, now: ContinuousClock.Instant, cockpitAnswering: Bool)
    -> String?
  {
    guard let seconds = seconds(turn, now: now) else { return nil }
    let minutes = seconds / 60
    let rest = seconds % 60
    let words = [
      minutes == 0 ? nil : count(minutes, "minute"),
      minutes > 0 && rest == 0 ? nil : count(rest, "second"),
    ].compactMap { $0 }.joined(separator: " ")
    let looking =
      alreadyHas(turn, now: now)
      ? "Larry already has this, and has been looking for \(words)" : "Larry has been looking for \(words)"
    return cockpitAnswering ? looking : "\(looking), and the Cockpit isn't answering"
  }

  /// His silence once `WhiteboardLarryTurn.tick` has stopped the board waiting (story 669): what the bar shows, and
  /// copies. `turn` as it was before that tick, so what was waiting behind the picture is still in it. Nil with no
  /// turn out.
  public static func didntAnswer(
    _ turn: WhiteboardLarryTurn, now: ContinuousClock.Instant, wallNow: Date, cockpitAnswering: Bool
  ) -> DidntAnswer? {
    guard case .awaiting = turn.state, let waited = seconds(turn, now: now) else { return nil }
    return DidntAnswer(
      sentAt: wallNow - TimeInterval(waited), waitedSeconds: waited, inkWaiting: turn.inkWaiting,
      wordsWaiting: turn.wordsWaiting, cockpitAnswering: cockpitAnswering)
  }

  /// His silence: the message and the state that explains it.
  public struct DidntAnswer: Equatable, Sendable {
    public let message = "Larry didn't answer"
    /// The screen and the operation.
    public static let context = "WhiteboardView.larryTimeout"
    public var context: String { Self.context }
    /// When the picture went.
    public let sentAt: Date
    /// How long the board waited.
    public let waitedSeconds: Int
    /// A pause saw the board move on since the picture: a fresh one goes.
    public let inkWaiting: Bool
    /// Words were spoken since the picture: they go with a fresh one.
    public let wordsWaiting: Bool
    /// The board's looks at his thread were working.
    public let cockpitAnswering: Bool
  }

  /// Whole seconds since the picture he is looking at went; nil with no turn out.
  private static func seconds(_ turn: WhiteboardLarryTurn, now: ContinuousClock.Instant) -> Int? {
    guard case .awaiting(let since, _) = turn.state else { return nil }
    return max(0, Int((now - since).components.seconds))
  }

  /// A tap sent nothing within the last two seconds.
  private static func alreadyHas(_ turn: WhiteboardLarryTurn, now: ContinuousClock.Instant) -> Bool {
    guard let at = turn.alreadyHasAt else { return false }
    return now - at < WhiteboardLarryTurn.alreadyHasFor
  }

  private static func count(_ n: Int, _ unit: String) -> String { "\(n) \(unit)\(n == 1 ? "" : "s")" }
}
