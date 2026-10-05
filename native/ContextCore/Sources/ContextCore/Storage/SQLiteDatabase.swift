//  A thin wrapper over the system's SQLite: open a file (or memory), run statements with bound values, read
//  rows. The app's one database is the file the React Native app wrote (Documents/SQLite/context-grabber.db),
//  with the same tables, so the cutover opens it in place; the host tests run the same code in memory.

import Foundation
import SQLite3

public enum SQLiteValue: Equatable, Sendable {
  case int(Int64)
  case double(Double)
  case text(String)
  case null

  public var intValue: Int64? { if case .int(let v) = self { return v } else { return nil } }
  public var textValue: String? { if case .text(let v) = self { return v } else { return nil } }
  public var doubleValue: Double? {
    switch self {
    case .double(let v): return v
    case .int(let v): return Double(v)
    default: return nil
    }
  }
}

public struct SQLiteError: Error, CustomStringConvertible, Equatable {
  public let code: Int32
  public let message: String
  public let sql: String
  public var description: String { "SQLite \(code): \(message) [\(sql.prefix(80))]" }
}

/// Not thread-safe by itself: one owner, one queue.
public final class SQLiteDatabase {
  private var handle: OpaquePointer?
  private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

  /// `path` nil opens a private in-memory database.
  public init(path: String? = nil) throws {
    let code = sqlite3_open(path ?? ":memory:", &handle)
    guard code == SQLITE_OK else {
      let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open"
      sqlite3_close(handle)
      throw SQLiteError(code: code, message: message, sql: path ?? ":memory:")
    }
  }

  deinit { sqlite3_close(handle) }

  private func fail(_ code: Int32, _ sql: String) -> SQLiteError {
    SQLiteError(code: code, message: String(cString: sqlite3_errmsg(handle)), sql: sql)
  }

  /// One or more statements with no values and no rows (schema).
  public func execute(_ sql: String) throws {
    let code = sqlite3_exec(handle, sql, nil, nil, nil)
    guard code == SQLITE_OK else { throw fail(code, sql) }
  }

  /// One statement with bound values; returns its rows (empty for a write).
  @discardableResult
  public func run(_ sql: String, _ values: [SQLiteValue] = []) throws -> [[String: SQLiteValue]] {
    var statement: OpaquePointer?
    var code = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
    guard code == SQLITE_OK else { throw fail(code, sql) }
    defer { sqlite3_finalize(statement) }
    for (i, value) in values.enumerated() {
      let index = Int32(i + 1)
      switch value {
      case .int(let v): code = sqlite3_bind_int64(statement, index, v)
      case .double(let v): code = sqlite3_bind_double(statement, index, v)
      case .text(let v): code = sqlite3_bind_text(statement, index, v, -1, Self.transient)
      case .null: code = sqlite3_bind_null(statement, index)
      }
      guard code == SQLITE_OK else { throw fail(code, sql) }
    }
    var rows: [[String: SQLiteValue]] = []
    while true {
      code = sqlite3_step(statement)
      if code == SQLITE_DONE { return rows }
      guard code == SQLITE_ROW else { throw fail(code, sql) }
      var row: [String: SQLiteValue] = [:]
      for column in 0..<sqlite3_column_count(statement) {
        let name = String(cString: sqlite3_column_name(statement, column))
        switch sqlite3_column_type(statement, column) {
        case SQLITE_INTEGER: row[name] = .int(sqlite3_column_int64(statement, column))
        case SQLITE_FLOAT: row[name] = .double(sqlite3_column_double(statement, column))
        case SQLITE_TEXT: row[name] = .text(String(cString: sqlite3_column_text(statement, column)))
        default: row[name] = .null
        }
      }
      rows.append(row)
    }
  }
}

/// The key/value `settings` table every journey shares.
public struct SettingsStore {
  private let db: SQLiteDatabase

  public init(db: SQLiteDatabase) throws {
    self.db = db
    try db.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);")
  }

  public func get(_ key: String) throws -> String? {
    try db.run("SELECT value FROM settings WHERE key = ?", [.text(key)]).first?["value"]?.textValue
  }

  public func set(_ key: String, _ value: String) throws {
    try db.run("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", [.text(key), .text(value)])
  }
}
