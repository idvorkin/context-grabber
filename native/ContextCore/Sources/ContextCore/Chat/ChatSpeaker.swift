//  Stories 1614, 1615 (the Cockpit's stories 321 and 322): who wrote a reply, and when a thread is a group chat.
//  Ported from the Cockpit's cockpit_core.js `chatSpeaker` and `chatIsGroup`, and chat_store.py `answers_nobody`.

/// A reply's speaker: Igor, Larry, Tony (the voice) or a skill.
public struct ChatSpeaker: Equatable, Sendable {
  public enum Tone: String, Sendable { case principal, agent, voice, skill }

  /// The same for every reply of one speaker: what makes a thread a group.
  public let key: String
  public let label: String
  public let tone: Tone
  /// The letter on the avatar.
  public var initial: String { label.first.map { $0.uppercased() } ?? "" }

  public static let agentName = "Larry"
  public static let voiceName = "Tony"

  /// An author equal to Larry's own name is Larry; *tony* is Tony; any other author is a skill.
  public static func of(_ message: ChatMessage) -> ChatSpeaker {
    if message.fromIgor { return ChatSpeaker(key: "principal", label: "You", tone: .principal) }
    return byAuthor(message.author)
  }

  /// The speaker an author names: Larry for none or Larry's own name, Tony for *tony*, otherwise the skill.
  public static func byAuthor(_ author: String?) -> ChatSpeaker {
    let name = author ?? ""
    let lower = name.lowercased()
    if name.isEmpty || lower == agentName.lowercased() {
      return ChatSpeaker(key: "agent", label: agentName, tone: .agent)
    }
    if lower == voiceName.lowercased() { return ChatSpeaker(key: "voice", label: voiceName, tone: .voice) }
    return ChatSpeaker(key: "skill:" + lower, label: name, tone: .skill)
  }

  /// The skill's name when a skill wrote it; nil for Larry, Tony or Igor.
  public static func skillAuthor(_ message: ChatMessage) -> String? {
    let speaker = of(message)
    return speaker.tone == .skill ? speaker.label : nil
  }

  /// A thread's opener (a page's, a call's): the Cockpit introducing the thread, not a speaker in it.
  public static func isOpener(_ message: ChatMessage) -> Bool {
    message.id.hasPrefix("page-opener-") || message.id.hasPrefix("call-thread-open-")
  }

  /// A row that is not a reply to Igor: an opener, or a row a voice call's bridge wrote on the call's thread.
  public static func answersNobody(_ message: ChatMessage) -> Bool {
    isOpener(message) || message.id.hasPrefix("call-thread-")
  }

  /// More than one speaker besides Igor (Larry and Tony, Larry and a skill): only then does every reply wear its
  /// speaker's name and avatar. Openers and the Cockpit's own lines never count.
  public static func isGroup(_ messages: [ChatMessage]) -> Bool {
    var seen: Set<String> = []
    for message in messages where !message.fromIgor && !message.isSystem && !isOpener(message) {
      seen.insert(of(message).key)
      if seen.count > 1 { return true }
    }
    return false
  }
}
