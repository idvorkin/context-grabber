//  Session-log retention: at launch the app deletes Documents/logs/*.jsonl older than 30 days, except any file
//  named by a report in Documents/bugs.jsonl (story 145). The decisions are pure — names, ages and the reports'
//  text in, names to delete out — so the host covers them; the app supplies ages and deletes.

import Foundation

public enum LogRetention {
  public static let retentionSeconds: Double = 30 * 24 * 3600

  /// Names to delete: older than `retention` seconds and not named by a bug report. Boundary stays (strictly older).
  public static func prune(
    files: [(name: String, age: Double)], referenced: Set<String>, retention: Double = retentionSeconds
  ) -> [String] {
    files.filter { $0.age > retention && !referenced.contains($0.name) }.map { $0.name }
  }

  /// The session logs that the reports in a bugs.jsonl name. Malformed lines are skipped.
  public static func referencedLogs(bugsJsonl text: String) -> Set<String> {
    var names = Set<String>()
    for line in text.split(separator: "\n") {
      guard let record = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
        let name = record["log"] as? String
      else { continue }
      names.insert(name)
    }
    return names
  }
}
