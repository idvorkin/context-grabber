//  Chat with Larry: what the Cockpit's chat routes answer, as the app reads them (plan 2026-10-25-native-chat-plan.md).
//  `GET /chat` lists every thread with a server-side unread count and the Done fold; `GET /chat/<key>` is one thread's
//  messages, Igor's carrying 👀/🏆 receipts; `POST /chat-seen` marks a thread read on every device.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct ChatSummary: Decodable, Equatable, Sendable, Identifiable {
  public let key: String
  public let title: String
  public let count: Int
  /// ISO 8601 with an offset, as the Cockpit writes it.
  public let lastTs: String
  public let lastWho: String
  public let lastText: String
  public let unread: Int
  public let done: Bool
  /// Archived on the phone or the Cockpit (#589); an archived thread is also `done`.
  public let archived: Bool
  /// Larry judges it finished; a proposal only, shown to Igor, and a new message clears it (#599).
  public let looksDone: Bool
  /// The one always-on thread with Larry (#598): first in the list, and never archived.
  public let pinned: Bool
  /// The skill that answers this thread instead of Larry (#632, cockpit#90); nil on any other, and on an older Cockpit.
  public let skill: String?
  /// The skill's name when it spoke last, otherwise empty.
  public let lastAuthor: String

  public var id: String { key }
  public var larryHasLastWord: Bool { lastWho == "larry" }
  public var lastAt: Date? { ChatWire.date(lastTs) }
  /// Who a message on this thread goes to.
  public var answeredBy: String { skill ?? "Larry" }
  /// Who spoke last, for the row and the notification.
  /// Story 1614: an author of Larry's own name is Larry, *tony* is Tony.
  public var lastSpeaker: String {
    !lastAuthor.isEmpty ? ChatSpeaker.byAuthor(lastAuthor).label : larryHasLastWord ? "Larry" : "You"
  }
  /// The row's second line.
  public var lastLine: String {
    count > 0 ? "\(lastSpeaker): \(lastText)" : skill.map { "Ask \($0)" } ?? "Drop anything here"
  }

  public init(
    key: String, title: String, count: Int = 1, lastTs: String, lastWho: String, lastText: String, unread: Int = 0,
    done: Bool = false, archived: Bool = false, looksDone: Bool = false, pinned: Bool = false, skill: String? = nil,
    lastAuthor: String = ""
  ) {
    self.key = key
    self.title = title
    self.count = count
    self.lastTs = lastTs
    self.lastWho = lastWho
    self.lastText = lastText
    self.unread = unread
    self.done = done
    self.archived = archived
    self.looksDone = looksDone
    self.pinned = pinned
    self.skill = skill
    self.lastAuthor = lastAuthor
  }

  /// The same row archived or brought back, as it shows until the Cockpit's next list.
  public func archiving(_ archive: Bool) -> ChatSummary {
    ChatSummary(
      key: key, title: title, count: count, lastTs: lastTs, lastWho: lastWho, lastText: lastText, unread: unread,
      done: archive, archived: archive, looksDone: looksDone, pinned: pinned, skill: skill, lastAuthor: lastAuthor)
  }

  /// The same row with its replies read, as it shows until the Cockpit's next list.
  public func read() -> ChatSummary {
    ChatSummary(
      key: key, title: title, count: count, lastTs: lastTs, lastWho: lastWho, lastText: lastText, unread: 0,
      done: done, archived: archived, looksDone: looksDone, pinned: pinned, skill: skill, lastAuthor: lastAuthor)
  }

  enum CodingKeys: String, CodingKey {
    case key, title, count, unread, done, archived, pinned, skill
    case looksDone = "looks_done"
    case lastTs = "last_ts"
    case lastWho = "last_who"
    case lastText = "last_text"
    case lastAuthor = "last_author"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    key = try c.decode(String.self, forKey: .key)
    title = (try? c.decode(String.self, forKey: .title)) ?? key
    count = (try? c.decode(Int.self, forKey: .count)) ?? 0
    lastTs = (try? c.decode(String.self, forKey: .lastTs)) ?? ""
    lastWho = (try? c.decode(String.self, forKey: .lastWho)) ?? ""
    lastText = (try? c.decode(String.self, forKey: .lastText)) ?? ""
    unread = (try? c.decode(Int.self, forKey: .unread)) ?? 0
    archived = (try? c.decode(Bool.self, forKey: .archived)) ?? false
    pinned = (try? c.decode(Bool.self, forKey: .pinned)) ?? false
    looksDone = !pinned && ((try? c.decode(Bool.self, forKey: .looksDone)) ?? false)
    done = (try? c.decode(Bool.self, forKey: .done)) ?? false
    skill = (try? c.decode(String.self, forKey: .skill)).flatMap { $0.isEmpty ? nil : $0 }
    lastAuthor = (try? c.decode(String.self, forKey: .lastAuthor)) ?? ""
  }
}

public struct ChatMessage: Decodable, Equatable, Sendable, Identifiable {
  /// The Cockpit's ladder (#630): it has the message, Larry has it, Larry finished it. Only ever moves forward.
  public enum Receipt: String, Sendable {
    case sent, received, seen, done

    public var glyph: String? {
      switch self {
      case .sent: return nil
      case .received: return "👀"
      case .seen: return "🫡"
      case .done: return "🏆"
      }
    }
  }

  public let id: String
  public let ts: String
  public let who: String
  public let text: String
  public let attachments: [String]
  public let receipt: Receipt
  /// Larry's note when he marked it done.
  public let doneNote: String?
  /// The whiteboard its picture was sent from (cockpit#85, #603); nil on a row without one.
  public let board: String?
  /// The skill that wrote it (#632, cockpit#90); nil on anything else. `who` stays "larry" on a skill's row.
  public let author: String?
  /// The skill could not answer and `text` says why: drawn as an error, and not an answer.
  public let isError: Bool
  /// The chat one of Igor's messages was sent on to (Send to new chat, context-grabber-9yo): the Cockpit's one-line
  /// system row left where the message was. Nil on any other row.
  public let movedTo: String?
  /// Larry has seen this message and is holding for more (story 929, context-grabber-4fww): the Cockpit's
  /// `receipt.waiting`, present only while his hold is active, on Igor's newest message. Nil on any other row.
  public let waiting: Waiting?

  /// Larry's hold on a message: his words for it and when it began.
  public struct Waiting: Equatable, Sendable {
    /// What the board says while he holds when the Cockpit gives no words.
    public static let defaultLabel = "Larry: waiting for more"

    public let label: String
    public let ts: String

    public init(label: String? = nil, ts: String = "") {
      let words = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      self.label = words.isEmpty ? Self.defaultLabel : words
      self.ts = ts
    }
  }

  public var fromIgor: Bool { who == "igor" }
  /// A line from the Cockpit itself, neither Igor's nor an answer: drawn as a quiet centred line, with no menu.
  public var isSystem: Bool { who == "system" || movedTo != nil }
  public var at: Date? { ChatWire.date(ts) }
  /// The letter on the author's avatar.
  public var authorInitial: String? { author?.first.map { $0.uppercased() } }

  public init(
    id: String, ts: String, who: String, text: String, attachments: [String] = [], receipt: Receipt = .sent,
    doneNote: String? = nil, board: String? = nil, author: String? = nil, isError: Bool = false, movedTo: String? = nil,
    waiting: Waiting? = nil
  ) {
    self.id = id
    self.ts = ts
    self.who = who
    self.text = text
    self.attachments = attachments
    self.receipt = receipt
    self.doneNote = doneNote
    self.board = board
    self.author = author
    self.isError = isError
    self.movedTo = movedTo
    self.waiting = waiting
  }

  enum CodingKeys: String, CodingKey {
    case id, ts, who, text, attachments, receipt, board, author, error
    // The moved row's new chat, as cockpit-x3s ships it (chat_store._moved_row).
    case movedTo = "moved_to"
  }
  struct ReceiptBody: Decodable {
    let state: String?
    let note: String?
    let waiting: WaitingBody?

    enum CodingKeys: String, CodingKey { case state, note, waiting }

    // Each field on its own: a hold the board can't read never costs the receipt's state (story 929).
    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      state = try? c.decode(String.self, forKey: .state)
      note = try? c.decode(String.self, forKey: .note)
      waiting = try? c.decode(WaitingBody.self, forKey: .waiting)
    }
  }
  /// `receipt.waiting`: `{"label": "Larry: waiting for more", "ts": "…"}`; either may be missing.
  struct WaitingBody: Decodable {
    let label: String?
    let ts: String?

    enum CodingKeys: String, CodingKey { case label, ts }

    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      label = try? c.decode(String.self, forKey: .label)
      ts = try? c.decode(String.self, forKey: .ts)
    }
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    ts = (try? c.decode(String.self, forKey: .ts)) ?? ""
    who = (try? c.decode(String.self, forKey: .who)) ?? ""
    text = (try? c.decode(String.self, forKey: .text)) ?? ""
    attachments = (try? c.decode([String].self, forKey: .attachments)) ?? []
    let body = try? c.decode(ReceiptBody.self, forKey: .receipt)
    receipt = body?.state.map { Receipt(rawValue: $0) ?? .received } ?? .sent
    doneNote = body?.note
    board = (try? c.decode(String.self, forKey: .board)).flatMap { $0.isEmpty ? nil : $0 }
    author = (try? c.decode(String.self, forKey: .author)).flatMap { $0.isEmpty ? nil : $0 }
    isError = (try? c.decode(Bool.self, forKey: .error)) ?? false
    movedTo = (try? c.decode(String.self, forKey: .movedTo)).flatMap { $0.isEmpty ? nil : $0 }
    waiting = body?.waiting.map { Waiting(label: $0.label, ts: $0.ts ?? "") }
  }
}

public enum ChatWire {
  struct List: Decodable {
    let ok: Bool
    let threads: [ChatSummary]
  }

  struct Thread: Decodable {
    let ok: Bool
    let messages: [ChatMessage]
  }

  /// Every thread, the pinned one first and then newest activity first, or nil for an answer that is not a chat list.
  public static func summaries(_ data: Data) -> [ChatSummary]? {
    guard let list = try? JSONDecoder().decode(List.self, from: data), list.ok else { return nil }
    return list.threads.sorted {
      if $0.pinned != $1.pinned { return $0.pinned }
      // Larry's pinned thread above a skill's, whichever is newer (#632).
      if $0.pinned, ($0.skill == nil) != ($1.skill == nil) { return $0.skill == nil }
      return ($0.lastAt ?? .distantPast) > ($1.lastAt ?? .distantPast)
    }
  }

  public static func messages(_ data: Data) -> [ChatMessage]? {
    guard let thread = try? JSONDecoder().decode(Thread.self, from: data), thread.ok else { return nil }
    return thread.messages
  }

  /// Igor's messages with a failure after them and no real reply yet (#632). The Cockpit marks them done either way, so
  /// these are the ones whose 🏆 would be a lie.
  public static func answerFailed(_ messages: [ChatMessage]) -> Set<String> {
    var failed: Set<String> = []
    var sawFailure = false
    // Story 1615: a call's thread rows and openers are news, not a reply.
    for message in messages.reversed() where !message.isSystem && !ChatSpeaker.answersNobody(message) {
      if message.isError {
        sawFailure = true
      } else if !message.fromIgor {
        break
      } else if sawFailure {
        failed.insert(message.id)
      }
    }
    return failed
  }

  /// Nil when the Cockpit took it; otherwise why not.
  public static func archiveFailure(status: Int?, body: Data?, error: String? = nil) -> String? {
    guard let status else { return error ?? "no answer" }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    if status == 200, json?["ok"] as? Bool == true { return nil }
    return (json?["error"] as? String).map { "\($0) (HTTP \(status))" } ?? "HTTP \(status)"
  }

  /// What the list says for the threads an archive or unarchive could not change: each one, and why.
  public static func archiveProblem(_ failed: [(title: String, reason: String)], archive: Bool) -> String {
    let verb = archive ? "archive" : "unarchive"
    let each = failed.map { "\"\($0.title)\": \($0.reason)" }
    return failed.count == 1
      ? "Could not \(verb) \(each[0])" : "Could not \(verb) \(failed.count) chats: \(each.joined(separator: "; "))"
  }

  /// The ticked threads Select can still archive, in list order: a Done or archived thread has left its rows.
  public static func liveKeys(_ picked: Set<String>, in threads: [ChatSummary]) -> [String] {
    threads.filter { !$0.done && picked.contains($0.key) }.map(\.key)
  }

  /// Where an attachment is served; nil for a ref that is not one the Cockpit mints (a picture, or since Cockpit
  /// story 167 a document, #633).
  public static func attachmentURL(_ ref: String, cockpit: String) -> URL? {
    guard attachment(ref) != nil else { return nil }
    return URL(string: cockpit.trimmingSuffix("/") + "/attachments/" + ref)
  }

  /// What a minted ref holds: a picture to draw, or a document to show as a file row (spec "A delivered file in the
  /// thread"). The Cockpit names the type by the bytes, so the ref's extension is the truth.
  public enum Attachment: Equatable, Sendable {
    case image
    case document(ext: String, label: String)
  }

  static let documentLabels: [String: String] = [
    "pdf": "PDF", "txt": "Text", "docx": "Word document", "xlsx": "Excel spreadsheet",
    "pptx": "PowerPoint presentation",
  ]

  public static func attachment(_ ref: String) -> Attachment? {
    guard
      isAttachmentRef(ref), let ext = ref.split(separator: ".").last.map(String.init)
    else { return nil }
    if let label = documentLabels[ext] { return .document(ext: ext, label: label) }
    return .image
  }

  /// A delivered file's ref: `yyyy-mm-dd/` and sixteen lower-case hex digits, then one of the known extensions.
  static func isAttachmentRef(_ ref: String) -> Bool {
    #if FOUNDATION_ESSENTIALS_ONLY
      return LiteText.isAttachmentRef(ref)
    #else
      return ref.range(
        of: #"^\d{4}-\d{2}-\d{2}/[0-9a-f]{16}\.(png|jpg|gif|webp|pdf|txt|docx|xlsx|pptx)$"#, options: .regularExpression
      )
        != nil
    #endif
  }

  /// The name a delivered document shows and opens under: the message's first line when that is a file name of the
  /// same type (the phone sends the name first, `ChatSend.text(for:)`), else the name the Cockpit minted.
  public static func documentName(_ ref: String, text: String) -> String {
    let minted = String(ref.split(separator: "/").last ?? Substring(ref))
    let ext = pathExtension(minted).lowercased()
    let first = text.split(whereSeparator: \.isNewline).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    guard first.count <= 200, pathExtension(first).lowercased() == ext,
      first.count > ext.count + 1, !first.contains("/"), !first.contains(":")
    else { return minted }
    return first
  }

  private static func pathExtension(_ path: String) -> String {
    #if FOUNDATION_ESSENTIALS_ONLY
      return LiteText.pathExtension(path)
    #else
      return (path as NSString).pathExtension
    #endif
  }

  /// Why a delivered document's fetch can't open, or nil when it can: an answer other than 200, or nothing in it.
  public static func documentProblem(name: String, status: Int?, bytes: Int, error: String? = nil) -> String? {
    if let error { return "\(name) could not be fetched from the Cockpit: \(error)" }
    guard let status else { return "\(name) could not be fetched from the Cockpit: no answer" }
    if status == 404 { return "The Cockpit no longer has \(name) (HTTP 404)." }
    if status != 200 { return "\(name) could not be fetched from the Cockpit (HTTP \(status))." }
    if bytes == 0 { return "The Cockpit sent \(name) back empty." }
    return nil
  }

  /// A thread key as one path segment: `auto:note:2026-10-25` and bead ids survive, a slash cannot sneak in.
  public static func encode(_ key: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~:")
    return key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
  }

  public static func date(_ iso: String) -> Date? {
    let f = ISO8601DateFormatter()
    if let d = f.date(from: iso) { return d }
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: iso)
  }

}

/// Which threads get a notification (plan: Hearing back). Larry has the last word, the Cockpit counts it unread, and
/// it is newer than what this phone last notified — or showed on screen — for that thread. A Done thread never
/// notifies, and the first check, with nothing recorded yet, only records: the replies already waiting stay quiet.
public enum ChatNotify {
  public static func due(_ summaries: [ChatSummary], notified: [String: String]) -> [ChatSummary] {
    guard !notified.isEmpty else { return [] }
    return summaries.filter { summary in
      guard !summary.done, summary.larryHasLastWord, summary.unread > 0, let last = summary.lastAt else {
        return false
      }
      guard let before = notified[summary.key].flatMap(ChatWire.date) else { return true }
      return last > before
    }
  }

  /// Every thread's latest stamp, merged over what was recorded: what the app has now shown or notified.
  public static func record(_ summaries: [ChatSummary], into notified: [String: String]) -> [String: String] {
    var out = notified
    for summary in summaries where !summary.lastTs.isEmpty { out[summary.key] = summary.lastTs }
    return out
  }
}

// ContextCore has its own; this module sits below it and cannot see that one.
extension String {
  func trimmingSuffix(_ suffix: String) -> String {
    hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
  }
}
