//  #809, chat spec "What the phone keeps": where a message on the phone is, one state at a time, and how long a sent
//  one stays. Sent and refused at once can't be written; a file an older build wrote with both reads as sent.

import Foundation

extension InboxItem {
  public enum Delivery: Equatable, Sendable {
    /// Not yet taken by the Cockpit.
    case waiting
    /// The Cockpit took it at `at` (Unix ms) into `thread`; nil is an *Earlier share*, sent to Larry's inbox before
    /// chat.
    case sent(at: Int64, thread: String?)
    /// The Cockpit's reason it said the item itself is wrong. Only *Send again* makes it waiting again.
    case refused(String)
  }

  /// Five minutes after its send, a sent message its thread doesn't list is unconfirmed: no longer a pending bubble.
  public static let unconfirmedAfterMs: Int64 = 5 * 60_000
  /// Seven days after its send, a sent chat message leaves the phone, its thread opened or not.
  public static let droppedAfterMs: Int64 = 7 * 24 * 3_600_000

  /// Ms since the Cockpit took it, nil unless sent; a clock set back reads 0, never a negative age.
  public func sentAge(now: Int64) -> Int64? { sentAt.map { max(0, now - $0) } }

  /// Sent long enough ago that a thread not listing it is not a read racing the send. A thread that lists it has
  /// delivered it instead, whatever its age.
  public func isUnconfirmed(now: Int64) -> Bool { (sentAge(now: now) ?? 0) >= Self.unconfirmedAfterMs }

  /// A sent chat message old enough to drop. An *Earlier share* stays until it is swiped away.
  public func isDueToDrop(now: Int64) -> Bool {
    chatThread != nil && (sentAge(now: now) ?? 0) >= Self.droppedAfterMs
  }
}

extension InboxItem.Delivery: Codable {
  private enum Keys: String, CodingKey { case state, at, thread, reason }
  private enum State: String, Codable { case waiting, sent, refused }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    switch try c.decode(State.self, forKey: .state) {
    case .waiting: self = .waiting
    case .sent:
      self = .sent(
        at: try c.decode(Int64.self, forKey: .at), thread: try c.decodeIfPresent(String.self, forKey: .thread))
    case .refused: self = .refused(try c.decode(String.self, forKey: .reason))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    switch self {
    case .waiting: try c.encode(State.waiting, forKey: .state)
    case .sent(let at, let thread):
      try c.encode(State.sent, forKey: .state)
      try c.encode(at, forKey: .at)
      try c.encodeIfPresent(thread, forKey: .thread)
    case .refused(let reason):
      try c.encode(State.refused, forKey: .state)
      try c.encode(reason, forKey: .reason)
    }
  }

  /// The shape before #809: `sent_at` and `chat_thread` set on a send, `refused` on a refusal, each optional, so a
  /// file could hold both. The Cockpit's *taken* wins: it has the message.
  static func legacy(sentAt: Int64?, chatThread: String?, refused: String?) -> Self {
    if let sentAt { return .sent(at: sentAt, thread: chatThread) }
    if let refused { return .refused(refused) }
    return .waiting
  }
}
