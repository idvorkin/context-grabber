//  The board's log for Larry (#883, bead context-grabber-z8o): Igor, 2026-11-14, "make sure you have the logging to
//  debug, and be able to request [logs]". A whiteboard bug lived in the session log on the iPad, out of Larry's reach
//  until Igor pulled it to the Mac. So each picture the board hands Larry is followed by the whiteboard's log lines
//  since the last that went, to the Cockpit's archive (`POST /archive`, the `whiteboard.log` stream), as a call's log
//  goes at its hang-up (story 212). On the box: cockpit-data's archive.sqlite3, one record per line.

import Foundation

public enum WhiteboardLogArchive {
  public static let stream = "whiteboard.log"
  /// Lines kept between sends: a board's busiest minute of touches and turns is a few hundred.
  public static let keep = 2000
  /// Lines in one batch, oldest first, the rest with the next send: well inside the archive's 8 MB body.
  public static let perBatch = 500

  /// One log line that went into the ring: its place in this launch, `t` from the line, and the line as written.
  public struct Line: Equatable, Sendable {
    public var seq: Int
    public var t: Int
    public var line: String
  }

  /// The whiteboard's lines of this launch, newest last, at most `keep`: what the next send takes from.
  public struct Ring: Sendable {
    public private(set) var lines: [Line] = []
    private var next = 1

    public init() {}

    /// A line of the board's: any `whiteboard…` event, and an `error` whose `where` is the board's. Others are not
    /// taken.
    public static func takes(type: String, fields: [String: Any]) -> Bool {
      if type.hasPrefix("whiteboard") { return true }
      return type == "error" && (fields["where"] as? String)?.hasPrefix("whiteboard") == true
    }

    public mutating func add(t: Int, line: String) {
      lines.append(Line(seq: next, t: t, line: line))
      next += 1
      if lines.count > WhiteboardLogArchive.keep { lines.removeFirst(lines.count - WhiteboardLogArchive.keep) }
    }

    /// The oldest `perBatch` lines after `seq`, the last one sent.
    public func after(_ seq: Int) -> [Line] {
      Array(lines.filter { $0.seq > seq }.prefix(WhiteboardLogArchive.perBatch))
    }
  }

  /// The batch's records: one a line, `guid` `<launch>:<seq>` so a line sent twice is one record, with the launch
  /// and its place in it beside the line, cut to the archive's 8 KB.
  public static func records(_ lines: [Line], launch: String) -> [[String: Any]] {
    lines.map { line in
      CallLogArchive.fitted(
        ["guid": "\(launch):" + String(format: "%06d", line.seq), "launch": launch, "seq": line.seq, "t": line.t],
        field: "line", text: line.line)
    }
  }

  /// A launch's name in the archive: the session log's own stamp and the device, in the archive's guid characters.
  public static func launch(logFile: String, device: String) -> String {
    let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.+-")
    let stem = (logFile as NSString).deletingPathExtension
    return String((String(device.prefix(8)) + "." + stem).filter { allowed.contains($0) }.prefix(100))
  }
}
