//  One thread's screen and its bar (#536, #449; stories 262–264, 274, 491): what a Send does, when it can go, what the
//  bar says under a new chat, the screen's title, what waits on the phone, and the moment a new chat becomes its
//  thread. The view draws these and owns only focus, the field and the mic.

import Foundation

extension ChatNewThread {
  /// What a Send does.
  public enum Send: Equatable, Sendable {
    /// Into a thread the Cockpit has.
    case thread(String)
    /// A fresh first message under this id: it starts the chat.
    case start(id: String)
    /// The first message is on its way: nothing goes.
    case hold
  }

  /// A Send at `target`. Starting the chat takes a fresh id, now the one this screen follows.
  public mutating func send(at target: Target, id: String = UUID().uuidString.lowercased()) -> Send {
    switch target {
    case .thread(let key): return .thread(key)
    case .waiting: return .hold
    case .new, .refused: return attempt(at: target, id: id).map { .start(id: $0) } ?? .hold
    }
  }

  /// Send is enabled: something to send, and not while the first message is on its way.
  public static func canSend(_ target: Target, draftReady: Bool) -> Bool { draftReady && target != .waiting }

  /// The bar's line under a new chat's field: the hold-back, or what a refusal means; nil otherwise.
  public static func barLine(_ target: Target, first: InboxItem?) -> String? {
    switch target {
    case .waiting: return waitingLine
    case .refused: return ChatSend.afterRefusal(of: first)
    case .new, .thread: return nil
    }
  }

  public static let waitingLine = "The next message goes once your first one reaches Larry."

  /// A new chat opens with the keyboard up (story 262) unless it opened recording (#637).
  public static func focusesOnOpen(_ target: Target, recording: Bool) -> Bool { target == .new && !recording }

  /// Only a new chat with nothing sent takes the voice button's tap as it opens.
  public static func takesVoiceOnOpen(_ target: Target) -> Bool { target == .new }

  /// The thread this screen shows: its own, or the one its first message landed in.
  public func key(fixedKey: String?) -> String? { fixedKey ?? landed }

  /// The phone's copy of the first message this screen follows, while it is still on the phone.
  public func first(in items: [InboxItem]) -> InboxItem? { sent.flatMap { id in items.first { $0.id == id } } }

  /// The followed first message moved to `thread`: the thread to open, once.
  public mutating func firstMoved(to thread: String?) -> String? {
    guard landed == nil, let thread else { return nil }
    land(in: thread)
    return thread
  }

  /// A new chat takes its first message's first line as the title, as the Cockpit will; once landed, the list's.
  public func title(fixedKey: String?, fixedTitle: String, threads: [ChatSummary], first: InboxItem?) -> String {
    guard fixedKey == nil else { return fixedTitle }
    if let landed, let known = threads.first(where: { $0.key == landed }) { return known.title }
    return first.map { ChatSend.title(for: $0) } ?? fixedTitle
  }

  /// What this screen shows under the thread's messages: the phone's messages for its thread the Cockpit doesn't hold
  /// yet, or before it has one, the first message on its way. `now`: Unix ms.
  public func pending(
    fixedKey: String?, items: [InboxItem], messages: [String: [ChatMessage]],
    now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
  ) -> [InboxItem] {
    if let key = key(fixedKey: fixedKey) {
      return ChatWire.pending(in: key, items: items, messages: messages[key], now: now)
    }
    return first(in: items).map { [$0] } ?? []
  }
}

extension ChatWire {
  /// This phone's messages for a thread that the Cockpit does not list yet: waiting, refused, or sent so lately that
  /// a read may not show it yet. A sent one five minutes old is unconfirmed (#809): the Cockpit has it, so it is no
  /// bubble, and Larry's newest message stays the newest. Oldest first. `now`: Unix ms.
  public static func pending(in key: String, items: [InboxItem], messages: [ChatMessage]?, now: Int64) -> [InboxItem] {
    unheld(in: key, items: items, messages: messages).filter { !$0.isUnconfirmed(now: now) }
  }

  /// Every message of the thread's on the phone that the Cockpit's thread does not list, sent or not. Oldest first.
  static func unheld(in key: String, items: [InboxItem], messages: [ChatMessage]?) -> [InboxItem] {
    let known = Set((messages ?? []).map(\.id))
    return items.filter { ($0.thread == key || $0.chatThread == key) && !known.contains($0.id) }
      .sorted { $0.sharedAt < $1.sharedAt }
  }
}
