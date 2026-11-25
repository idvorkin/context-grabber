//  Chat with Larry (spec 2026-10-25-native-chat-design.md, plan 2026-10-25-native-chat-plan.md): an Inbox item goes
//  out as a chat message on the Cockpit's threads. An image or file is uploaded first (`POST /attachments`, raw
//  bytes) and named by the ref it gets back; then the message: `POST /chat` starts a new thread, `POST /chat/<key>`
//  adds to one.
//  The item's id is the message id, so a resend after a lost answer lands once (cockpit#64, Cockpit story 129).

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum ChatSend {
  /// What Cockpit's chat calls a message from this app.
  public static let source = "app"
  /// The longest title a new thread gets from its first message.
  public static let maxTitle = 80

  public enum Upload: Equatable, Sendable {
    case ref(String)
    case refused(status: Int, reason: String)
    case retry(reason: String)
  }

  public enum Outcome: Equatable, Sendable {
    /// Taken (or taken before: `duplicate`), on this thread.
    case sent(thread: String, duplicate: Bool)
    case refused(status: Int, reason: String)
    case retry(reason: String)
  }

  /// What the message says: a link is its address then the note, text is the text then the note, an image its note, a file its name then the note.
  public static func text(for item: InboxItem) -> String {
    let parts: [String?]
    switch item.kind {
    case .link: parts = [item.url, item.note]
    case .text: parts = [item.text, item.note]
    case .image: parts = [item.note]
    case .file: parts = [item.fileName, item.note]
    }
    return parts.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
      .joined(separator: "\n\n")
  }

  /// Whether a link item's message holds its link whole (#673), for the log: a yes or no, never the link.
  public static func carriesLink(_ item: InboxItem) -> Bool {
    guard let url = item.url?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else { return false }
    return text(for: item).hasPrefix(url)
  }

  /// A new thread's title: the note's first line, else the text's, else the link's site, else *Photo, <date>*, or the file's name.
  public static func title(for item: InboxItem, timeZone: TimeZone = .current) -> String {
    let firstLine = { (s: String?) -> String? in
      s?.split(whereSeparator: \.isNewline).lazy.map { $0.trimmingCharacters(in: .whitespaces) }
        .first { !$0.isEmpty }
    }
    let picked =
      firstLine(item.note) ?? (item.kind == .text ? firstLine(item.text) : nil) ?? item.site
      ?? (item.kind == .image ? "Photo, \(day(item.sharedAt, timeZone))" : nil) ?? firstLine(item.url) ?? firstLine(
        item.fileName) ?? "Chat"
    guard picked.count > maxTitle else { return picked }
    return String(picked.prefix(maxTitle - 1)).trimmingCharacters(in: .whitespaces) + "…"
  }

  public static func uploadRequest(image: Data, cockpit: String) throws -> URLRequest {
    try uploadRequest(bytes: image, mime: InboxSend.mime(of: image), cockpit: cockpit)
  }

  /// A document, raw like an image (#633). The name goes in the message's words, not here.
  public static func uploadRequest(file: Data, name: String, cockpit: String) throws -> URLRequest {
    try uploadRequest(bytes: file, mime: ChatFile.mime(name: name), cockpit: cockpit)
  }

  private static func uploadRequest(bytes: Data, mime: String, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("attachments"))
    request.httpMethod = "POST"
    request.timeoutInterval = 60
    request.setValue(mime, forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = bytes
    return request
  }

  /// A refused item's problem. A file says it is still here (story 487), or that the phone lost it (story 492).
  public static func refusal(of item: InboxItem, answeredBy: String = "Larry") -> String {
    let reason = item.refused ?? "no reason given"
    guard item.kind == .file else { return "\(answeredBy) refused it: \(reason)" }
    let name = item.fileName ?? "this file"
    guard item.canSendAgain else { return "\(name) could not be read from this phone, so it can't go. Pick it again." }
    return "The Cockpit can't take \(name): \(reason). It is still on this phone: Send again tries it once more."
  }

  /// The bar's line in a new chat whose first message was refused (#536, story 491).
  public static func afterRefusal(of first: InboxItem?) -> String {
    guard first?.canSendAgain == true else {
      return "Larry refused your first message, so the next one starts the chat again."
    }
    return "Your file stays under Not sent yet in the chat list. A new message here starts a separate chat without it."
  }

  public static func upload(status: Int?, body: Data?, error: String? = nil) -> Upload {
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    guard let status else { return .retry(reason: error ?? "no answer") }
    if status == 200, json?["ok"] as? Bool == true, let ref = json?["ref"] as? String, !ref.isEmpty {
      return .ref(ref)
    }
    let reason = (json?["error"] as? String) ?? "HTTP \(status)"
    if refusesForGood(status) { return .refused(status: status, reason: reason) }
    return .retry(reason: reason)
  }

  /// A 4xx says the item itself is wrong, so it isn't sent again; except a 408 (the Cockpit gave up reading the upload,
  /// as a 2.2 MB photo on a slow link made it do, #1452) and a 429 (too many at once), which say try later.
  public static func refusesForGood(_ status: Int) -> Bool {
    (400..<500).contains(status) && status != 408 && status != 429
  }

  /// The message itself; `attachment` is the ref an upload returned. `build` says which build sent it (story 1134).
  public static func messageRequest(
    _ item: InboxItem, attachment: String?, cockpit: String, build: AppBuild = .current
  ) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var body: [String: Any] = ["id": item.id, "text": text(for: item), "source": source]
    if let attachment { body["attachments"] = [attachment] }
    if let whiteboard = item.whiteboard {
      body.merge(whiteboard.wire) { $1 }
      if let report = whiteboard.report { body.merge(report.wire) { $1 } }
    }
    let url: URL?
    if let thread = item.thread {
      url = URL(string: base.absoluteString.trimmingSuffix("/") + "/chat/" + ChatWire.encode(thread))
    } else {
      body["title"] = item.whiteboard?.title ?? title(for: item)
      url = base.appendingPathComponent("chat")
    }
    guard let url else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: build.stamp(body), options: [.sortedKeys])
    return request
  }

  public static func outcome(status: Int?, body: Data?, error: String? = nil) -> Outcome {
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    guard let status else { return .retry(reason: error ?? "no answer") }
    if status == 200, json?["ok"] as? Bool == true, let thread = json?["thread"] as? String, !thread.isEmpty {
      return .sent(thread: thread, duplicate: json?["duplicate"] as? Bool == true)
    }
    let reason = (json?["error"] as? String) ?? (json?["reason"] as? String) ?? "HTTP \(status)"
    // 404 is a thread the Cockpit no longer has: wrong for good, like any other 4xx but a 408 or a 429.
    if refusesForGood(status) { return .refused(status: status, reason: reason) }
    return .retry(reason: reason)
  }

  static func day(_ ms: Int64, _ timeZone: TimeZone) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = timeZone
    f.dateFormat = "MMM d"
    return f.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
  }
}

extension String {
  func trimmingSuffix(_ suffix: String) -> String { hasSuffix(suffix) ? String(dropLast(suffix.count)) : self }
}
