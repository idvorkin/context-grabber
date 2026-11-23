//  Where the picture Larry is looking at is, and what the board offers twenty seconds into his turn (spec
//  2026-11-12-whiteboard-conversation-design.md, *Where the picture is* and *After 20 seconds*, stories 773, 775–777;
//  Igor on his board, 2026-11-14: "I think Larry got stuck. I need interrupt/retry button after 20s!"). One reading of
//  the Cockpit's mark on the picture's message (#630, #879) names the state (*Sent* or *Larry*, `WhiteboardLarryClock`)
//  and picks the control: a picture the Cockpit never took is stuck, with Retry and Dismiss; one it has, or one on a
//  Cockpit that marks nothing, is Larry's to answer, with a quiet Interrupt. The board's model hands in the turn, the
//  thread it last read, what it knows of the sending and the clock.

import Foundation

public enum WhiteboardLarryWait: String, Equatable, Sendable {
  /// No turn out, or Larry marked the picture done.
  case none
  /// A turn is out and twenty seconds haven't passed.
  case waiting
  /// Twenty seconds and the Cockpit hasn't taken the picture: Retry or Dismiss.
  case stuck
  /// Twenty seconds and the Cockpit has it (received or seen, not done), or can't say: Interrupt.
  case working

  /// How long a picture goes unanswered before the board offers anything, and before *Sent* adds *not picked up yet*:
  /// the one threshold (Igor's twenty seconds).
  public static let after: Duration = .seconds(20)

  /// Where the picture is (story 773): the one reading of the Cockpit's mark.
  public enum Mark: String, Equatable, Sendable {
    /// The Cockpit never took it: no mark on its message, or no such message, on a thread whose other messages of
    /// Igor's carry marks, and its sending hasn't been answered.
    case none
    /// Can't be told: the Cockpit marks nothing (an older one), the board hasn't read the thread, the picture has no
    /// id the board knows (*Send to Larry*), or no turn is out. Reads as before, *Larry*, and is never stuck.
    case unknown
    /// The Cockpit has it; Larry hasn't picked it up: *Sent*.
    case received
    /// Larry has picked it up.
    case seen
    /// Larry has answered it.
    case done
  }

  /// Where the picture of the turn out is, from the board's thread as last read (oldest first). `picture`: its message's
  /// id, when the board handed it over itself; without one, Igor's newest message since the picture went stands for it.
  /// `delivered`: its sending was answered, so the Cockpit has it. `earlier`: the furthest mark the board has already
  /// seen on it, as the ladder only moves forward.
  public static func mark(
    _ turn: WhiteboardLarryTurn, thread: [ChatMessage], now: ContinuousClock.Instant, wallNow: Date,
    picture: String? = nil, delivered: Bool = false, earlier: ChatMessage.Receipt = .sent
  ) -> Mark {
    guard case .awaiting(let since, _) = turn.state else { return .unknown }
    let message: ChatMessage?
    if let picture {
      message = thread.last { $0.id == picture }
    } else {
      // The Cockpit's timestamps may be whole seconds, and its message lands after the picture went: a second's grace.
      let went = wallNow - TimeInterval(max(0, Int((now - since).components.seconds))) - 1
      message = thread.last { $0.fromIgor && ($0.at.map { $0 >= went } ?? false) }
    }
    switch (message?.receipt ?? .sent).atLeast(earlier) {
    case .done: return .done
    case .seen: return .seen
    case .received: return .received
    case .sent:
      // A missing mark says something only on a Cockpit that marks Igor's messages, and only of a picture the board
      // can name: else an older Cockpit would look stuck on every turn.
      guard picture != nil, thread.contains(where: { $0.fromIgor && $0.receipt != .sent }) else { return .unknown }
      return delivered ? .received : .none
    }
  }

  public static func of(_ turn: WhiteboardLarryTurn, mark: Mark, now: ContinuousClock.Instant) -> Self {
    // Story 1176: a Send waiting in the outbox is the outbox's to retry, never stuck.
    guard case .awaiting(let since, _) = turn.state, mark != .done, !turn.waitingToSend else { return .none }
    if now - since < after { return .waiting }
    return mark == .none ? .stuck : .working
  }

  /// The stuck picture's copyable problem: the message and its context. Its state (when it went, how long it waited,
  /// whether it is still going up, whether the Cockpit is answering) is the board's to add.
  public static let stuckMessage = "Larry hasn't got the picture"
  public static let stuckContext = "WhiteboardView.larryStuck"

  /// Larry closed the turn with nothing to say (#913): the message `id` is marked done and no message of his comes after
  /// it in the thread (oldest first). False when the thread doesn't hold it.
  public static func doneWithoutReply(_ id: String, in messages: [ChatMessage]) -> Bool {
    guard let index = messages.lastIndex(where: { $0.id == id }), messages[index].receipt == .done else { return false }
    return !messages[(index + 1)...].contains { !$0.fromIgor && !$0.isSystem }
  }

  /// The mark of the message `id` in a thread's messages, nil when the thread doesn't hold it.
  public static func receipt(of id: String, in messages: [ChatMessage]) -> ChatMessage.Receipt? {
    messages.last { $0.id == id }?.receipt
  }
}

extension ChatMessage.Receipt {
  private var rank: Int {
    switch self {
    case .sent: return 0
    case .received: return 1
    case .seen: return 2
    case .done: return 3
    }
  }

  /// The further along of the two: the Cockpit's ladder only moves forward, so a look that brings back less is ignored.
  public func atLeast(_ other: Self) -> Self { other.rank > rank ? other : self }
}

/// The board's hand-offs of pictures to Larry, counted (stories 775–777): one that *Retry*, *Dismiss* or *Interrupt*
/// replaced no longer speaks for the board (its words went with the retry, or back in the queue), while one a newer picture replaced
/// still frees its own turn if that is still out, keeps its words and says it failed. Only the latest says whether a
/// picture is on its way.
public struct WhiteboardLarryHandOffs: Equatable, Sendable {
  public private(set) var latest = 0
  private var replaced: Set<Int> = []

  public init() {}

  /// A picture is handed over: its number.
  public mutating func begin() -> Int {
    latest += 1
    return latest
  }

  /// *Retry*, *Dismiss* or *Interrupt* took over hand-off `attempt`.
  public mutating func replace(_ attempt: Int) { replaced.insert(attempt) }

  /// Its ending frees the turn, keeps its words and shows its failure.
  public func speaks(_ attempt: Int) -> Bool { !replaced.contains(attempt) }

  public func isLatest(_ attempt: Int) -> Bool { attempt == latest }
}
