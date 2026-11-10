//  Larry's turn on a board, one at a time, latest wins (spec 2026-11-01-whiteboard-shapes-design.md, *Who answers the
//  pause*, story 662; Igor, 2026-11-10: "can we avoid this, think about best design"). Real Larry takes minutes, so a
//  Larry board never piles pictures on his thread: while a turn is out, pauses only remember that the board moved on
//  and words wait; when he answers, or the turn times out, one fresh picture goes if anything changed. A tap on
//  *Larry's turn* or *Send to Larry* always goes at once and takes over what was waiting. The board's model owns the
//  clock, the board's version (bumped on every change of its ink) and the sending; it hands them in.

public struct WhiteboardLarryTurn: Equatable, Sendable {
  /// How long a turn is out before the board stops waiting for his answer. His turns took 67 s and 78 s (2026-11).
  public static let timeout: Duration = .seconds(180)
  /// The bar's words while a turn is out.
  public static let lookingNote = "Larry is looking…"

  public enum State: Equatable, Sendable {
    case idle
    /// A picture of the board at version `sent` went (or is going) at `since`, and he hasn't answered yet.
    case awaiting(since: ContinuousClock.Instant, sent: Int)
  }

  public enum Next: Equatable, Sendable {
    /// A picture goes now, with these words as its message; the turn is out again.
    case send(words: String?)
    /// A turn is out: the board's newest version and any words are kept for the next picture.
    case held
    /// Nothing to send.
    case done
  }

  public private(set) var state: State = .idle
  /// The newest version a pause saw while a turn was out.
  public private(set) var latest: Int?
  /// Words spoken while a turn was out, for the next picture.
  public private(set) var queued: String?

  public init() {}

  /// A turn is out: the bar says he is looking.
  public var looking: Bool { state != .idle }

  /// A pause on a Larry board, the board at `version`, `words` spoken with it.
  public mutating func paused(version: Int, words: String?, now: ContinuousClock.Instant) -> Next {
    queue(words)
    guard case .awaiting = state else { return go(version: version, now: now) }
    latest = max(latest ?? version, version)
    return .held
  }

  /// A new row of his on the thread: his answer. One fresh picture of the board as it is now (`version`) if a pause saw
  /// it move on since the last, or words wait.
  public mutating func replied(version: Int, now: ContinuousClock.Instant) -> Next {
    guard case .awaiting(_, let sent) = state else { return .done }
    return followUp(sent: sent, version: version, now: now)
  }

  /// The clock: once a turn has been out `timeout`, the board stops waiting, as if he had answered. Nil while it's
  /// still in time, or with no turn out.
  public mutating func tick(version: Int, now: ContinuousClock.Instant) -> Next? {
    guard case .awaiting(let since, let sent) = state, now - since >= Self.timeout else { return nil }
    return followUp(sent: sent, version: version, now: now)
  }

  /// Igor tapped *Larry's turn* or *Send to Larry*: the picture goes now, whatever was waiting. Returns the words
  /// waiting, which go with it.
  public mutating func tapped(version: Int, now: ContinuousClock.Instant) -> String? {
    guard case .send(let words) = go(version: version, now: now) else { return nil }
    return words
  }

  /// The picture didn't reach him: no turn is out, and its words wait for the next one.
  public mutating func failed(words: String?) {
    state = .idle
    if let words { queued = queued.map { "\(words) \($0)" } ?? words }
  }

  /// Ghosts off: what pauses kept for the next picture is forgotten. A turn already out stays out.
  public mutating func dropped() {
    latest = nil
    queued = nil
  }

  private mutating func followUp(sent: Int, version: Int, now: ContinuousClock.Instant) -> Next {
    if let latest, latest > sent { return go(version: max(latest, version), now: now) }
    if queued != nil { return go(version: max(sent, version), now: now) }
    state = .idle
    latest = nil
    return .done
  }

  private mutating func go(version: Int, now: ContinuousClock.Instant) -> Next {
    state = .awaiting(since: now, sent: version)
    latest = nil
    defer { queued = nil }
    return .send(words: queued)
  }

  private mutating func queue(_ words: String?) {
    guard let words, !words.isEmpty else { return }
    queued = queued.map { "\($0) \(words)" } ?? words
  }
}
