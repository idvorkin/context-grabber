//  The call log as a private gist — created, described and deleted — with the network handed in (#92).
//
//  One gist per upload, never a rolling one: a stable URL would be a permanently live copy of Igor's calls. Each
//  gist opens with a note asking the reader to delete it when processed, and the app keeps the ids so it can
//  delete what it made. Nothing here ever carries the token into a message.
//
//  Spec: docs/superpowers/specs/2026-09-05-diagnostics-gist-upload-design.md. Port of lib/gistUpload.ts.

import Foundation

public struct GistError: Error, LocalizedError, Equatable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}

public enum Gist {
  public static let gistsURL = URL(string: "https://api.github.com/gists")!
  /// How many of the app's gists may exist at once; the oldest beyond this go on the next upload.
  public static let keepUploads = 10
  public static let fileName = "call-log.txt"

  public struct Upload: Codable, Equatable, Sendable {
    public var id: String
    public var url: String
    /// ISO 8601 UTC, so the strings sort in time order.
    public var at: String

    public init(id: String, url: String, at: String) {
      self.id = id
      self.url = url
      self.at = at
    }
  }

  /// The note at the top of every upload — for whoever reads it, human or Larry.
  public static func readerNote() -> String {
    [
      "This is Igor's phone's call log, uploaded by Grabber Native. It contains call",
      "transcripts and device details. DELETE THIS GIST ONCE YOU HAVE PROCESSED IT —",
      "`gh gist delete <this gist's id>`. It is one of several; the app can also delete",
      "everything it uploaded from Diagnostics uploads on its home screen.",
    ].joined(separator: "\n")
  }

  /// `Grabber Native call diagnostics · 2026-10-05 14:03 UTC · troubled call`
  public static func description(at: Date, why: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return "Grabber Native call diagnostics · \(f.string(from: at)) UTC · \(why)"
  }

  /// The POST body: secret, one file — the note, the reason, then the text *Copy diagnostics* gives.
  public static func body(at: Date, why: String, text: String) -> Data {
    let object: [String: Any] = [
      "description": description(at: at, why: why),
      "public": false,
      "files": [fileName: ["content": "\(readerNote())\n\nupload reason: \(why)\n\(text)\n"]],
    ]
    return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
  }

  private static func request(_ url: URL, method: String, token: String) -> URLRequest {
    var r = URLRequest(url: url)
    r.httpMethod = method
    r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
    r.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    r.timeoutInterval = 30
    return r
  }

  public static func createRequest(token: String, body: Data) -> URLRequest {
    var r = request(gistsURL, method: "POST", token: token)
    r.httpBody = body
    return r
  }

  public static func deleteRequest(token: String, id: String) -> URLRequest {
    let safe = id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? id
    return request(gistsURL.appendingPathComponent(safe), method: "DELETE", token: token)
  }

  /// GitHub's answer to a create, or the reason it was not one.
  public static func parseCreate(status: Int, body: Data?, at: Date) -> Result<Upload, GistError> {
    let object = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    if status == 201 || status == 200 {
      if let id = object?["id"] as? String, !id.isEmpty, let url = object?["html_url"] as? String, !url.isEmpty {
        return .success(Upload(id: id, url: url, at: iso(at)))
      }
      return .failure(GistError("GitHub answered \(status) without a gist id"))
    }
    let message = object?["message"] as? String ?? ""
    return .failure(GistError("GitHub said \(status)\(message.isEmpty ? "" : ": \(message)")"))
  }

  /// True when deleted now; false when already gone (404) — the intended outcome. Anything else is an error.
  public static func parseDelete(status: Int) -> Result<Bool, GistError> {
    switch status {
    case 204: return .success(true)
    case 404: return .success(false)
    default: return .failure(GistError("GitHub said \(status)"))
    }
  }

  /// Newest first: what to keep and what to delete once a new upload is on the list.
  public static func prune(_ uploads: [Upload], keep: Int = keepUploads) -> (keep: [Upload], drop: [Upload]) {
    let sorted = uploads.sorted { $0.at > $1.at }
    return (Array(sorted.prefix(keep)), Array(sorted.dropFirst(keep)))
  }

  /// After an upload: the newest `keepUploads` stay, the rest are deleted. A delete that fails (offline, GitHub
  /// down) keeps its gist on the list so the next upload tries again; one already gone is dropped.
  public static func retire(_ uploads: [Upload], delete: (String) async throws -> Bool) async -> [Upload] {
    let (keep, drop) = prune(uploads)
    var stuck: [Upload] = []
    for upload in drop {
      do { _ = try await delete(upload.id) } catch { stuck.append(upload) }
    }
    return keep + stuck
  }

  public static func decodeUploads(_ raw: String?) -> [Upload] {
    guard let raw, let data = raw.data(using: .utf8),
      let array = try? JSONSerialization.jsonObject(with: data) as? [Any]
    else { return [] }
    return array.compactMap { item in
      guard let d = item as? [String: Any], let id = d["id"] as? String, let url = d["url"] as? String,
        let at = d["at"] as? String
      else { return nil }
      return Upload(id: id, url: url, at: at)
    }
  }

  public static func encodeUploads(_ uploads: [Upload]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return (try? encoder.encode(uploads)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
  }

  static func iso(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.string(from: date)
  }
}
