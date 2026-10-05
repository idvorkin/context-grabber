//  One line of the session log: `{"type": "<event>", "t": <ms since launch>, ...fields}` as JSON, no newline.
//  Pure, so the host covers what a line can and cannot carry; the app's SessionLog owns the file.

import Foundation

public enum SessionLogLine {
  public static func encode(type: String, t: Int, fields: [String: Any] = [:]) -> Data {
    var record: [String: Any] = [:]
    for (key, value) in fields { record[key] = sanitize(value) }
    // After the fields: a field named "type" or "t" must not replace the line's own.
    record["type"] = type
    record["t"] = t
    if JSONSerialization.isValidJSONObject(record),
      let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
    {
      return data
    }
    // A value JSON cannot carry (a Date, a CGRect) must not lose the line: keep the type and say what happened.
    let fallback: [String: Any] = [
      "type": "error", "t": t, "where": "log", "event": type, "message": "a field JSON cannot carry",
    ]
    return (try? JSONSerialization.data(withJSONObject: fallback, options: [.sortedKeys])) ?? Data()
  }

  /// JSONSerialization rejects non-finite doubles; round and clamp so a NaN cannot drop a whole line.
  /// Recurses into dictionaries and arrays.
  static func sanitize(_ value: Any) -> Any {
    switch value {
    case let d as Double: return d.isFinite ? (d * 100).rounded() / 100 : -1
    case let f as Float: return sanitize(Double(f))
    case let dict as [String: Any]: return dict.mapValues { sanitize($0) }
    case let array as [Any]: return array.map { sanitize($0) }
    default: return value
    }
  }
}
