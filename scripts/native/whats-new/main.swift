//  The I/O half of What's new (story 148): reads the `git log` lines and the stories, hands them to
//  ContextCore's WhatsNew (compiled in beside this file by whats-new.sh) and writes the app's JSON.
//  Usage: whats-new <log file: sha US iso-date US subject per line> <docs/stories dir> <out.json>

import Foundation

let args = CommandLine.arguments
guard args.count == 4 else {
  FileHandle.standardError.write(Data("usage: whats-new <log> <stories dir> <out.json>\n".utf8))
  exit(2)
}
let iso = ISO8601DateFormatter()
let log = (try? String(contentsOfFile: args[1], encoding: .utf8)) ?? ""
let commits = log.split(separator: "\n").compactMap { line -> WhatsNew.Commit? in
  let f = line.split(separator: "\u{1f}", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
  guard f.count == 3, let date = iso.date(from: f[1]) else { return nil }
  return WhatsNew.Commit(sha: f[0], date: date, subject: f[2])
}
var stories: [Int: WhatsNew.Story] = [:]
let dir = URL(fileURLWithPath: args[2])
for file in ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted() where file.hasSuffix(".md") {
  let text = (try? String(contentsOf: dir.appendingPathComponent(file), encoding: .utf8)) ?? ""
  stories.merge(WhatsNew.stories(fromMarkdown: text)) { first, _ in first }
}
let now = Date()
let feed = WhatsNewFeed(generated: iso.string(from: now), days: WhatsNew.build(commits: commits, stories: stories, now: now))
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try encoder.encode(feed).write(to: URL(fileURLWithPath: args[3]))
print("whats-new: \(commits.count) commits, \(stories.count) stories -> \(feed.days.count) days, \(feed.days.reduce(0) { $0 + $1.items.count }) changes")
