//  The session log: one JSON Lines file per launch in Documents/logs (visible in the Files app, pulled with
//  `just pull-logs`). One event per line with `t` in ms since the launch. Events are listed in docs/DEBUGGING.md.

import ContextCore
import Foundation
import UIKit

final class SessionLog: @unchecked Sendable {
  let url: URL
  let startedAt = Date()
  private let queue = DispatchQueue(label: "grabber.log")
  private var handle: FileHandle?
  /// The whiteboard's lines of this launch and the last one the archive took (#883): `WhiteboardModel.shipLog`.
  private var board = WhiteboardLogArchive.Ring()
  private var boardSent = 0
  /// This launch's name in the archive.
  let launch: String

  init() {
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("logs", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    url = dir.appendingPathComponent("grabber-\(formatter.string(from: startedAt)).jsonl")
    launch = WhiteboardLogArchive.launch(
      logFile: url.lastPathComponent, device: UIDevice.current.identifierForVendor?.uuidString ?? "device")
    FileManager.default.createFile(atPath: url.path, contents: nil)
    do {
      handle = try FileHandle(forWritingTo: url)
    } catch {
      // No file, no evidence: say so once where a tethered run can see it; every event after this is dropped.
      print("SessionLog: cannot open \(url.path): \(error)")
    }
    event(
      "session_start",
      [
        "device": UIDevice.current.model, "system": UIDevice.current.systemVersion,
        "app": BuildInfo.version, "sha": BuildInfo.sha, "branch": BuildInfo.branch,
        "started": ISO8601DateFormatter().string(from: startedAt),
      ])
  }

  /// The log as written so far, every queued event included.
  func snapshot() -> String {
    queue.sync { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
  }

  /// Waits for every queued event to be written, so a copy of the file (BugKit's reports) holds them.
  func flush() {
    queue.sync { try? handle?.synchronize() }
  }

  func event(_ type: String, _ fields: [String: Any] = [:]) {
    let t = Int(Date().timeIntervalSince(startedAt) * 1000)
    let boards = WhiteboardLogArchive.Ring.takes(type: type, fields: fields)
    queue.async { [self] in
      let line = SessionLogLine.encode(type: type, t: t, fields: fields)
      if boards { board.add(t: t, line: String(decoding: line, as: UTF8.self)) }
      guard let handle else { return }
      handle.write(line)
      handle.write(Data([0x0A]))
    }
  }

  /// The whiteboard's lines the archive hasn't taken yet, oldest first, one batch's worth.
  func whiteboardUnsent() -> [WhiteboardLogArchive.Line] {
    queue.sync { board.after(boardSent) }
  }

  /// The archive took the whiteboard's lines up to `seq`.
  func whiteboardSent(through seq: Int) {
    queue.async { [self] in boardSent = max(boardSent, seq) }
  }
}
