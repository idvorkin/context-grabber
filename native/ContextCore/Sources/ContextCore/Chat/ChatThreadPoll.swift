//  The Cockpit's delta and ETag wire for one thread and the list (Igor, 2026-11-25: "Chats load slow."; cockpit story
//  346, docs/chat-parity.md "The wire: polling a thread and the list"). A poll sends `?after=<cursor>` and the newest
//  ETag; a 304 keeps what is held, a delta merges by id (a held id is replaced in place, the rest appended in order), and
//  `full: true`, or no `full` at all from an older Cockpit, replaces everything. Any failed read drops the cursor and the
//  ETag so the next read is a whole one; the rows on screen stay.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct ChatThreadPoll: Equatable, Sendable {
  /// One message as the Cockpit sent it, kept raw so a later delta can replace it and the device copy is exact.
  public struct Row: Codable, Equatable, Sendable {
    public let id: String
    public let json: Data
  }

  public enum Outcome: Equatable, Sendable {
    /// A 304: nothing changed since the ETag sent.
    case unchanged
    /// The whole thread, replacing what was held.
    case whole(count: Int)
    /// A delta: rows appended and rows replaced in place.
    case changed(new: Int, changed: Int)
    /// Not read; the cursor and ETag are dropped so the next read is whole.
    case failed(String)
  }

  public private(set) var rows: [Row] = []
  public private(set) var cursor: String?
  public private(set) var etag: String?
  /// True once a read (or the device copy) gave this thread its rows.
  public private(set) var held = false

  public init() {}

  /// The next read. Opening a thread always reads it whole (no `after`); the ETag still goes, since it names the
  /// thread's state whatever the cursor, and a 304 then keeps the device copy.
  public func request(_ key: String, cockpit: String, opening: Bool) throws -> URLRequest {
    var path = "/chat/" + ChatWire.encode(key)
    if !opening, held, let cursor, !cursor.isEmpty {
      path += "?after=" + (cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)
    }
    var request = try ChatWire.get(cockpit, path)
    if held, let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
    return request
  }

  /// What one answer did to the thread held.
  public mutating func apply(status: Int, etag: String?, body: Data) -> Outcome {
    if status == 304, held {
      if let etag { self.etag = etag }
      return .unchanged
    }
    guard status == 200 else { return fail("HTTP \(status)") }
    guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any], object["ok"] as? Bool == true,
      let messages = object["messages"] as? [[String: Any]]
    else { return fail("unreadable answer") }
    var incoming: [Row] = []
    for message in messages {
      guard let id = message["id"] as? String, let json = try? JSONSerialization.data(withJSONObject: message) else {
        return fail("unreadable answer")
      }
      incoming.append(Row(id: id, json: json))
    }
    let full = (object["full"] as? Bool) ?? true
    let nextCursor = (object["cursor"] as? String) ?? incoming.last?.id
    let outcome: Outcome
    if full || !held {
      rows = incoming
      outcome = .whole(count: incoming.count)
    } else {
      var index: [String: Int] = [:]
      for (i, row) in rows.enumerated() { index[row.id] = i }
      var added = 0
      var changed = 0
      for row in incoming {
        if let i = index[row.id] {
          if rows[i] != row { changed += 1 }
          rows[i] = row
        } else {
          index[row.id] = rows.count
          rows.append(row)
          added += 1
        }
      }
      outcome = .changed(new: added, changed: changed)
    }
    held = true
    cursor = nextCursor
    self.etag = etag
    return outcome
  }

  /// After an error, or a local guess the Cockpit refused: the next read is a whole one.
  public mutating func forget() {
    cursor = nil
    etag = nil
  }

  private mutating func fail(_ why: String) -> Outcome {
    forget()
    return .failed(why)
  }

  /// The thread as the screen shows it; nil before anything was read.
  public var messages: [ChatMessage]? {
    guard held else { return nil }
    return Self.decode(rows)
  }

  private static func decode(_ rows: [Row]) -> [ChatMessage]? {
    let joined = Data("[".utf8) + rows.map(\.json).joined(separator: Data(",".utf8)) + Data("]".utf8)
    return try? JSONDecoder().decode([ChatMessage].self, from: joined)
  }

  // MARK: The device copy

  private struct Saved: Codable {
    let rows: [Row]
    let cursor: String?
    let etag: String?
  }

  /// What the device keeps, so the thread shows at once when opened again; nil before a read.
  public var saved: Data? {
    guard held else { return nil }
    return try? JSONEncoder().encode(Saved(rows: rows, cursor: cursor, etag: etag))
  }

  public init?(saved: Data) {
    guard let copy = try? JSONDecoder().decode(Saved.self, from: saved), Self.decode(copy.rows) != nil else {
      return nil
    }
    rows = copy.rows
    cursor = copy.cursor
    etag = copy.etag
    held = true
  }
}

/// The list's half: the slim rows and the list's own ETag (a hash of the answer's bytes, kept for this query alone).
public struct ChatListPoll: Equatable, Sendable {
  public private(set) var etag: String?

  public init() {}

  public func request(cockpit: String) throws -> URLRequest {
    var request = try ChatWire.get(cockpit, "/chat?fields=summary")
    if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
    return request
  }

  /// A 200 keeps its ETag, a 304 keeps the one held, anything else drops it so the next read is whole.
  public mutating func answered(status: Int, etag: String?) {
    switch status {
    case 200: self.etag = etag
    case 304: if let etag { self.etag = etag }
    default: self.etag = nil
    }
  }
}
