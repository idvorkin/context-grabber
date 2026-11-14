//  Chat's launch hooks with a grammar, and what its screens do by themselves on the simulator (docs/TESTING.md).
//  Pure; the app's `runChatSendHook`, `runChatSendFileHook` and the Chat views do the work.

import Foundation

/// `GRABBER_CHAT_SEND=<thread>|<text>` and `GRABBER_CHAT_SEND_FILE=<thread>|<path>`: written in that thread as the
/// compose bar would; `new` starts one (`thread` nil).
public struct ChatSendHook: Equatable, Sendable {
  public var thread: String?
  /// The text, or the file's path.
  public var body: String

  /// With no `|` the text is empty. Nothing but `|`s is no hook.
  public init?(text spec: String?) {
    guard let spec, !spec.isEmpty else { return nil }
    let parts = spec.split(separator: "|", maxSplits: 1).map(String.init)
    guard let first = parts.first else { return nil }
    thread = first == "new" ? nil : first
    body = parts.count > 1 ? parts[1] : ""
  }

  /// With no `|` the one word is both the thread and the path. Nothing but `|`s is a new thread and no path, which
  /// the send then refuses.
  public init?(file spec: String?) {
    guard let spec, !spec.isEmpty else { return nil }
    let parts = spec.split(separator: "|", maxSplits: 1).map(String.init)
    thread = parts.first.flatMap { $0 == "new" ? nil : $0 }
    body = parts.last ?? ""
  }
}

/// What taps itself once its screen shows.
public struct ChatViewHooks: Equatable, Sendable {
  /// `GRABBER_CHAT_SELECT=archive`: *Review* and *Archive (N)*.
  public var selectArchive: Bool
  /// `GRABBER_CHAT_LINKS=fold` / `all`, as written.
  public var links: String?
  /// `GRABBER_CHAT_HOLD=yes` / `no` / `quote` / `copy`, as written (`ChatHold(hook:)` reads it).
  public var hold: String?
  /// `GRABBER_CHAT_IMAGE=open`: the thread's picture full size.
  public var imageOpen: Bool
  /// `GRABBER_CHAT_REVIEW=open`: a blog-review card's first note.
  public var reviewOpen: Bool
  /// `GRABBER_CHAT_ENTER=<words>`: those words and two new lines, written in the open thread's bar as a keyboard would.
  public var enter: String?

  public init(_ env: [String: String] = [:]) {
    selectArchive = env["GRABBER_CHAT_SELECT"] == "archive"
    links = env["GRABBER_CHAT_LINKS"]
    hold = env["GRABBER_CHAT_HOLD"]
    imageOpen = env["GRABBER_CHAT_IMAGE"] == "open"
    reviewOpen = env["GRABBER_CHAT_REVIEW"] == "open"
    enter = env["GRABBER_CHAT_ENTER"].flatMap { $0.isEmpty ? nil : $0 }
  }
}
