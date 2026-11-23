//  Larry's turn on a board, one at a time, latest wins (spec 2026-11-01-whiteboard-shapes-design.md, *Who answers the
//  pause*, story 662; Igor, 2026-11-10: "can we avoid this, think about best design"). Real Larry takes minutes, so a
//  Larry board never piles pictures on his thread: while a turn is out, pauses only remember that the board moved on
//  and words wait; when he answers, or the turn times out, one fresh picture goes if anything changed. A tap on
//  *Larry's turn* or *Send to Larry* goes at once and takes over what was waiting, unless he is looking at this very
//  part of the board with nothing waiting: then it sends nothing and says so (story 765, #879: seven identical pictures
//  in twelve seconds). The board's model owns the clock, the board's version (bumped on every change of its ink), which
//  part of the board is on screen and the sending; it hands them in.

public struct WhiteboardLarryTurn: Equatable, Sendable {
  /// How long a turn is out before the board stops waiting for his answer. His turns took 67 s and 78 s (2026-11).
  public static let timeout: Duration = .seconds(180)

  public enum State: Equatable, Sendable {
    case idle
    /// A picture of the board at version `sent` went (or is going) at `since`, and he hasn't answered yet.
    case awaiting(since: ContinuousClock.Instant, sent: Int)
  }

  /// How long the note says a repeat tap sent nothing (story 765).
  public static let alreadyHasFor: Duration = .seconds(2)

  /// What a tap on *Larry's turn* or *Send to Larry* does.
  public enum Tap: Equatable, Sendable {
    /// A picture goes now, with these words as its message; the turn is out again.
    case send(words: String?)
    /// He is looking at the board as it is, the same part of it, and no words wait: nothing goes (story 765).
    case alreadyHas
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
  /// When a tap last sent nothing because he already has the board; cleared when a picture goes (story 765).
  public private(set) var alreadyHasAt: ContinuousClock.Instant?
  /// He closed the last turn with nothing to say, and no turn has started since (#913): the bar says so.
  public private(set) var nothingToAdd = false
  /// The turn's picture is a *Send* still waiting in the outbox (story 1176): the board says *Waiting to send*, the
  /// timeout doesn't run, and nothing else goes until it has gone.
  public private(set) var waitingToSend = false

  public init() {}

  /// A turn is out: the bar shows how long he has been looking (`WhiteboardLarryClock`, story 667).
  public var looking: Bool { state != .idle }

  /// A pause saw the board move on since the picture he is looking at: a fresh one goes when he answers.
  public var inkWaiting: Bool {
    guard case .awaiting(_, let sent) = state, let latest else { return false }
    return latest > sent
  }

  /// Words wait for the next picture.
  public var wordsWaiting: Bool { queued != nil }

  /// A pause on a Larry board, the board at `version`, `words` spoken with it.
  public mutating func paused(version: Int, words: String?, now: ContinuousClock.Instant) -> Next {
    queue(words)
    guard case .awaiting = state else { return .send(words: go(version: version, now: now)) }
    latest = max(latest ?? version, version)
    return .held
  }

  /// A new row of his on the thread: his answer. One fresh picture of the board as it is now (`version`) if a pause saw
  /// it move on since the last, or words wait.
  public mutating func replied(version: Int, now: ContinuousClock.Instant) -> Next {
    nothingToAdd = false
    // An answer to an earlier picture while the Send waits: the Send is still the one out (story 1176).
    if waitingToSend { return .held }
    guard case .awaiting(_, let sent) = state else { return .done }
    return followUp(sent: sent, version: version, now: now)
  }

  /// He marked the picture of the turn out done and wrote nothing after it (#913, Larry's option (a)): the turn ends as
  /// an answer with no shapes would. With nothing waiting the bar says he had nothing to add, until the next turn.
  public mutating func closed(version: Int, now: ContinuousClock.Instant) -> Next {
    if waitingToSend { return .held }
    guard case .awaiting(_, let sent) = state else { return .done }
    let next = followUp(sent: sent, version: version, now: now)
    if next == .done { nothingToAdd = true }
    return next
  }

  /// The clock: once a turn has been out `timeout`, the board stops waiting, as if he had answered. Nil while it's
  /// still in time, or with no turn out.
  public mutating func tick(version: Int, now: ContinuousClock.Instant, timeout: Duration = Self.timeout) -> Next? {
    guard !waitingToSend, case .awaiting(let since, let sent) = state, now - since >= timeout else { return nil }
    return followUp(sent: sent, version: version, now: now)
  }

  /// Igor tapped *Larry's turn* or *Send to Larry*: the picture goes now, whatever was waiting, with the words that
  /// waited. With his turn out on the board at `version`, no words waiting and the picture's part of the board still
  /// the one on screen (`moved` false), nothing goes (story 765); with no turn out it always goes, since asking him to
  /// look again is a real request.
  public mutating func tapped(version: Int, moved: Bool = false, now: ContinuousClock.Instant) -> Tap {
    if case .awaiting(_, let sent) = state, version == sent, queued == nil, !moved {
      alreadyHasAt = now
      return .alreadyHas
    }
    return .send(words: go(version: version, now: now))
  }

  /// The picture sent as `turn` didn't reach him: its words wait for the next one, and the turn is free unless a newer
  /// one has gone since.
  public mutating func failed(_ turn: State, words: String?) {
    if state == turn {
      state = .idle
      waitingToSend = false
    }
    if let words { queued = queued.map { "\(words) \($0)" } ?? words }
  }

  /// *Retry* on a picture the Cockpit hasn't taken (story 775): the same picture goes again, so the turn stays on the
  /// same version and its clock starts again from `now`. False with no turn out.
  public mutating func resent(now: ContinuousClock.Instant) -> Bool {
    guard case .awaiting(_, let sent) = state else { return false }
    state = .awaiting(since: now, sent: sent)
    alreadyHasAt = nil
    return true
  }

  /// *Interrupt* (story 777): Larry has the picture and the board stops waiting for him, so the next pause or tap is a
  /// fresh ask. What a pause saw is dropped, as the next picture takes the board as it is then; waiting words stay for
  /// it. His answer, when it comes, finds no turn out. False with no turn out.
  public mutating func interrupted() -> Bool {
    guard case .awaiting = state, !waitingToSend else { return false }
    state = .idle
    latest = nil
    alreadyHasAt = nil
    return true
  }

  /// Story 1176: the picture a tap just sent is a *Send* waiting in the outbox. Nothing with no turn out.
  public mutating func waitsInOutbox() {
    guard case .awaiting = state else { return }
    waitingToSend = true
  }

  /// Story 1176: a board opened while its *Send* still waits in the outbox, the board at `version`: the turn is out on
  /// it, waiting. Nothing if a turn is already out.
  public mutating func reopenedWaiting(version: Int, now: ContinuousClock.Instant) {
    guard state == .idle else { return }
    state = .awaiting(since: now, sent: version)
    waitingToSend = true
  }

  /// Story 1176: the outbox sent the waiting *Send*. His clock starts now, and the timeout counts from here. False when
  /// nothing was waiting.
  public mutating func outboxSent(now: ContinuousClock.Instant) -> Bool {
    guard waitingToSend, case .awaiting(_, let sent) = state else { return false }
    waitingToSend = false
    state = .awaiting(since: now, sent: sent)
    return true
  }

  /// Ghosts off: what pauses kept for the next picture is forgotten. A turn already out stays out.
  public mutating func dropped() {
    latest = nil
    queued = nil
  }

  private mutating func followUp(sent: Int, version: Int, now: ContinuousClock.Instant) -> Next {
    if let latest, latest > sent { return .send(words: go(version: max(latest, version), now: now)) }
    if queued != nil { return .send(words: go(version: max(sent, version), now: now)) }
    state = .idle
    latest = nil
    return .done
  }

  /// A picture goes: the turn is out on `version`, and the words that waited go with it.
  private mutating func go(version: Int, now: ContinuousClock.Instant) -> String? {
    state = .awaiting(since: now, sent: version)
    latest = nil
    alreadyHasAt = nil
    nothingToAdd = false
    waitingToSend = false
    defer { queued = nil }
    return queued
  }

  private mutating func queue(_ words: String?) {
    guard let words, !words.isEmpty else { return }
    queued = queued.map { "\($0) \(words)" } ?? words
  }
}
