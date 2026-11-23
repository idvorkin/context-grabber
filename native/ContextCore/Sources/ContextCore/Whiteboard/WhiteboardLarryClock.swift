//  Larry's clock on a board (spec 2026-11-12-whiteboard-conversation-design.md, *Larry's clock*, story 667; #879: "This
//  seems very slow, are we crashing/hung?"). While a turn is out the bar's note begins with how long he has been looking
//  at the picture, counted from when it went, so the app being away costs nothing; at the timeout his silence is a
//  copyable problem. The board's model hands in the turn, the clock and whether the Cockpit is answering its looks. While the
//  Cockpit has the picture and Larry hasn't picked it up the state says *Sent* (story 773), from where the picture is
//  (`WhiteboardLarryWait.Mark`, the same reading the 20-second controls use).

import Foundation

public enum WhiteboardLarryClock {
  /// What the bar says once he closed a turn with nothing to say, until the next one starts (#913).
  public static let nothingToAdd = "Larry: nothing to add yet"
  /// What the bar's state says while the board's *Send* waits in the outbox (story 1176).
  public static let waitingToSend = "Waiting to send"

  /// His state at the start of the bar's note, *Larry · 0:42*, or *Sent · 0:03* while the Cockpit has the picture and
  /// he hasn't picked it up (*Sent · 0:21 · not picked up yet* from `WhiteboardLarryWait.after`, twenty seconds), with
  /// *Cockpit not answering* when the board's looks at his thread have been failing. For two seconds after a tap that sent nothing it reads *Larry already has this · 0:12*
  /// (story 765). With no turn out, *Larry: nothing to add yet* after he closed the last with nothing to say (#913),
  /// else nil.
  public static func state(
    _ turn: WhiteboardLarryTurn, now: ContinuousClock.Instant, cockpitAnswering: Bool,
    mark: WhiteboardLarryWait.Mark = .unknown
  ) -> String? {
    guard let seconds = seconds(turn, now: now) else { return turn.nothingToAdd ? nothingToAdd : nil }
    // Story 1176: a Send still in the outbox has not reached the Cockpit, so nothing is said about him or it.
    if turn.waitingToSend { return "\(waitingToSend) · \(seconds / 60):\(String(format: "%02d", seconds % 60))" }
    let already = alreadyHas(turn, now: now)
    let sent = !already && mark == .received
    let who = already ? "Larry already has this" : sent ? "Sent" : "Larry"
    var clock = "\(who) · \(seconds / 60):\(String(format: "%02d", seconds % 60))"
    if sent, seconds >= Int(WhiteboardLarryWait.after.components.seconds) { clock += " · not picked up yet" }
    return cockpitAnswering ? clock : "\(clock) · Cockpit not answering"
  }

  /// The same for VoiceOver, in words: *Larry has been looking for 42 seconds*, or *Sent 3 seconds ago, not picked up
  /// yet*.
  public static func spoken(
    _ turn: WhiteboardLarryTurn, now: ContinuousClock.Instant, cockpitAnswering: Bool,
    mark: WhiteboardLarryWait.Mark = .unknown
  ) -> String? {
    guard let seconds = seconds(turn, now: now) else { return turn.nothingToAdd ? nothingToAdd : nil }
    let minutes = seconds / 60
    let rest = seconds % 60
    let words = [
      minutes == 0 ? nil : count(minutes, "minute"),
      minutes > 0 && rest == 0 ? nil : count(rest, "second"),
    ].compactMap { $0 }.joined(separator: " ")
    if turn.waitingToSend { return "\(waitingToSend) for \(words)" }
    let already = alreadyHas(turn, now: now)
    let looking =
      already
      ? "Larry already has this, and has been looking for \(words)"
      : mark == .received ? "Sent \(words) ago, not picked up yet" : "Larry has been looking for \(words)"
    return cockpitAnswering ? looking : "\(looking), and the Cockpit isn't answering"
  }

  /// His silence once `WhiteboardLarryTurn.tick` has stopped the board waiting (story 669): what the bar shows, and
  /// copies. `turn` as it was before that tick, so what was waiting behind the picture is still in it. Nil with no
  /// turn out.
  public static func didntAnswer(
    _ turn: WhiteboardLarryTurn, now: ContinuousClock.Instant, wallNow: Date, cockpitAnswering: Bool,
    mark: WhiteboardLarryWait.Mark = .unknown
  ) -> DidntAnswer? {
    guard case .awaiting = turn.state, let waited = seconds(turn, now: now) else { return nil }
    return DidntAnswer(
      sentAt: wallNow - TimeInterval(waited), waitedSeconds: waited, inkWaiting: turn.inkWaiting,
      wordsWaiting: turn.wordsWaiting, cockpitAnswering: cockpitAnswering, mark: mark)
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
    /// Where the picture was (story 773): whether the Cockpit ever took it, and whether he picked it up.
    public let mark: WhiteboardLarryWait.Mark
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
