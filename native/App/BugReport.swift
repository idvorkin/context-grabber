//  Log pruning (story 145), kept here until BugKit's BugStore.pruneLogs replaces it (bug-kit migration, step 2).
//  The report itself is BugKit's now (step 1): AppModel.reporter.

import ContextCore
import Foundation

@MainActor
final class LogPruner {
  private let log: SessionLog
  private let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

  init(log: SessionLog) { self.log = log }

  /// Deletes session logs older than 30 days, except any named by a report in bugs.jsonl. Runs at launch, after
  /// the new session's log is open, and logs one `logs_pruned` event even when zero. A file whose age cannot be
  /// read is never deleted.
  func pruneOldLogs() {
    let dir = documents.appendingPathComponent("logs", isDirectory: true)
    let bugs = documents.appendingPathComponent("bugs.jsonl")
    var referenced = Set<String>()
    if FileManager.default.fileExists(atPath: bugs.path) {
      // A bugs.jsonl that exists but cannot be read means the reported logs are unknown: prune nothing rather
      // than delete evidence.
      guard let text = try? String(contentsOf: bugs, encoding: .utf8) else {
        log.event("error", ["where": "logs_prune", "message": "bugs.jsonl unreadable; nothing pruned"])
        return
      }
      referenced = LogRetention.referencedLogs(bugsJsonl: text)
    }
    let now = Date()
    let files = ((try? FileManager.default.contentsOfDirectory(
      at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? [])
      .filter { $0.pathExtension == "jsonl" }
      .compactMap { url -> (name: String, age: Double, size: Int)? in
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
          let modified = values.contentModificationDate
        else { return nil }
        return (url.lastPathComponent, now.timeIntervalSince(modified), values.fileSize ?? 0)
      }
    let victims = Set(LogRetention.prune(files: files.map { (name: $0.name, age: $0.age) }, referenced: referenced))
    var count = 0
    var freed = 0
    for file in files where victims.contains(file.name) {
      do {
        try FileManager.default.removeItem(at: dir.appendingPathComponent(file.name))
        count += 1
        freed += file.size
      } catch {
        log.event("error", ["where": "logs_prune", "file": file.name, "message": "\(error)"])
      }
    }
    let kept = files.filter { $0.age > LogRetention.retentionSeconds && referenced.contains($0.name) }.count
    log.event("logs_pruned", ["count": count, "bytes": freed, "kept_for_reports": kept])
  }
}
