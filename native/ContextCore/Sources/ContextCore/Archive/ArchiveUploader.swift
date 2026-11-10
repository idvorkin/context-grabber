//  Story 270: one stream's pages to the Cockpit, oldest first, the cursor moved only after each 2xx. The first run
//  of a stream is its whole history; later runs are what came since. A run reads at most `maxPages`, so a
//  background task's minute is never spent on one stream, and stops at the first answer that is not a 2xx: a
//  refusal is a bug to read in the log, an unreachable Cockpit would fail the next page the same way.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A page of a stream, as its source read it.
public struct ArchivePage {
  public var records: [[String: Any]]
  /// The cursor to keep once this page is in the archive; nil when the source has nothing to remember.
  public var cursor: String?
  /// Whether the source has more after this page.
  public var more: Bool
  /// Whether the source could not read the cursor it was given and started the stream over from the beginning.
  public var restarted: Bool

  public init(records: [[String: Any]], cursor: String?, more: Bool, restarted: Bool = false) {
    self.records = records
    self.cursor = cursor
    self.more = more
    self.restarted = restarted
  }
}

public protocol ArchiveSource {
  var stream: String { get }
  /// The next page after `cursor` (nil: from the beginning), at most `limit` records.
  @MainActor
  func page(after cursor: String?, limit: Int) async throws -> ArchivePage
}

public struct ArchiveUploader {
  public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  let cursors: ArchiveCursorStore
  let cockpit: String
  let deviceId: String
  let transport: Transport
  public var pageSize = ArchiveSend.pageSize
  /// Pages per stream per run (a backfill takes as many runs as it needs).
  public var maxPages = 20

  public init(cursors: ArchiveCursorStore, cockpit: String, deviceId: String, transport: @escaping Transport) {
    self.cursors = cursors
    self.cockpit = cockpit
    self.deviceId = deviceId
    self.transport = transport
  }

  public struct Report: Equatable, Sendable {
    public var pages = 0
    public var records = 0
    public var inserted = 0
    public var duplicate = 0
    /// Why the run ended before the stream was caught up; nil when it is caught up.
    public var stopped: ArchiveStop?
    /// The HTTP status when the stream was `refused` (story 304's Settings line).
    public var refusedStatus: Int?
    public init() {}
  }

  /// `log` gets one `archive` line per page and per stop: counts and reasons, never a record.
  /// Database reads and cursor writes share the location writers' actor; the transport remains nonisolated.
  @MainActor
  public func upload(
    _ source: ArchiveSource, now: @Sendable () -> Date = { Date() }, isCancelled: () -> Bool = { false },
    log: (String, [String: Any]) -> Void
  ) async -> Report {
    var report = Report()
    var cursor: String?
    do {
      cursor = try cursors.cursor(source.stream)
    } catch {
      log("error", ["where": "archive_cursor", "stream": source.stream, "message": "\(error)"])
      report.stopped = .unreadable
      return report
    }
    var first = cursor == nil
    while report.pages < maxPages {
      // The task iOS is taking back (ArchiveModel.cancel), or the caller's own say.
      if Task.isCancelled || isCancelled() {
        report.stopped = .cancelled
        break
      }
      let page: ArchivePage
      do {
        page = try await source.page(after: cursor, limit: pageSize)
      } catch {
        log("error", ["where": "archive_read", "stream": source.stream, "message": "\(error)"])
        report.stopped = .unreadable
        break
      }
      if page.restarted {
        log("archive", ["action": "restarted", "stream": source.stream])
        first = true
      }
      if page.records.isEmpty {
        // Nothing to send, but the source may still have moved (Health answers an anchor for an empty page).
        if let next = page.cursor, next != cursor { keep(next, for: source.stream, now: now, log: log) }
        break
      }
      let batch = ArchiveBatch(stream: source.stream, deviceId: deviceId, records: page.records)
      var fields: [String: Any] = [
        "action": "page", "stream": source.stream, "batch": batch.batchId, "records": page.records.count,
        "backfill": first,
      ]
      let outcome: ArchiveSend.Outcome
      do {
        let request = try ArchiveSend.request(batch, cockpit: cockpit)
        let (data, response) = try await transport(request)
        outcome = ArchiveSend.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: data)
      } catch {
        outcome = ArchiveSend.outcome(status: nil, body: nil, error: error.localizedDescription)
      }
      report.pages += 1
      report.records += page.records.count
      switch outcome {
      case .taken(let inserted, let duplicate):
        report.inserted += inserted
        report.duplicate += duplicate
        fields.merge(["ok": true, "inserted": inserted, "duplicate": duplicate]) { $1 }
        log("archive", fields)
        // The one place the cursor moves: the archive has this page.
        if let next = page.cursor { keep(next, for: source.stream, now: now, log: log) }
        cursor = page.cursor ?? cursor
        if !page.more { return report }
      case .refused(let status, let reason):
        fields.merge(["ok": false, "action": "refused", "status": status, "reason": reason]) { $1 }
        log("archive", fields)
        report.stopped = .refused
        report.refusedStatus = status
        return report
      case .retry(let reason):
        fields.merge(["ok": false, "action": "failed", "reason": reason]) { $1 }
        log("archive", fields)
        report.stopped = .cockpitAway
        return report
      }
    }
    if report.stopped == nil && report.pages >= maxPages { report.stopped = .pages }
    return report
  }

  @MainActor
  private func keep(_ cursor: String, for stream: String, now: () -> Date, log: (String, [String: Any]) -> Void) {
    do {
      try cursors.set(stream, cursor: cursor, at: Int64(now().timeIntervalSince1970 * 1000))
    } catch {
      // The page is in the archive; without the stamp it goes again next run and the archive takes nothing twice.
      log("error", ["where": "archive_cursor", "stream": stream, "message": "\(error)"])
    }
  }
}

/// The trail, paged by row id: a point's guid is its content, so a re-import (new ids, same points) sends records
/// the archive already has and nothing doubles.
public struct LocationArchiveSource: ArchiveSource {
  let store: LocationStore
  public let stream = ArchiveStream.points

  public init(store: LocationStore) { self.store = store }

  @MainActor
  public func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
    let after = cursor.flatMap { Int64($0) } ?? 0
    let rows = try store.points(afterId: after, limit: limit)
    let records = rows.map { row -> [String: Any] in
      var record: [String: Any] = [
        "guid": ArchiveGUID.point(row.point), "t": row.point.timestamp, "lat": row.point.latitude,
        "lng": row.point.longitude,
      ]
      if let accuracy = row.point.accuracy { record["acc"] = accuracy }
      return record
    }
    return ArchivePage(records: records, cursor: rows.last.map { String($0.id) }, more: rows.count == limit)
  }
}
