//  Story 270: the delta stamp per stream, in the app's database. A Health stream's cursor is its query anchor
//  (what Health has already answered, deletions included); the trail's is the last row id sent. Set only after
//  the Cockpit answered 2xx for the page it covers (ArchiveUploader), so a lost answer sends the page again and
//  the archive, keyed by guid, takes nothing twice.

import Foundation

public struct ArchiveCursorStore {
  private let db: SQLiteDatabase

  public init(db: SQLiteDatabase) throws {
    self.db = db
    try db.execute(
      """
      CREATE TABLE IF NOT EXISTS archive_cursor (
        stream TEXT PRIMARY KEY,
        cursor TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
      """)
  }

  /// Where the stream's last taken page ended; nil before its first.
  public func cursor(_ stream: String) throws -> String? {
    try db.run("SELECT cursor FROM archive_cursor WHERE stream = ?", [.text(stream)]).first?["cursor"]?.textValue
  }

  /// The trail's last row id the archive has taken (the points stream pages by row id), 0 before its first page.
  public func pointsArchivedThroughId() throws -> Int64 {
    try cursor(ArchiveStream.points).flatMap { Int64($0) } ?? 0
  }

  public func set(_ stream: String, cursor: String, at ms: Int64) throws {
    try db.run(
      "INSERT OR REPLACE INTO archive_cursor (stream, cursor, updated_at) VALUES (?, ?, ?)",
      [.text(stream), .text(cursor), .int(ms)])
  }
}
