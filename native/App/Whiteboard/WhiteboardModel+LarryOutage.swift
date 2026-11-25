//  Story 1302 (#1450): a turn to Larry that can't reach the Cockpit (a 5xx, a timeout, a refused or dropped connection)
//  is a blink, as a chat read's is (story 1136). The board still says Larry couldn't be reached, with Copy error; only
//  an outage that lasts 2 minutes files a report, once. A device offline never files; any other failure files at once.
//  The rule is ContextCore's `CockpitOutage`, host-tested by `CockpitOutageTests`.

import BugKit
import ContextCore
import Foundation

extension WhiteboardModel {
  /// What a turn that failed as `kind` does about a report: whether its problem files, the words that say how long the
  /// Cockpit has been away when an outage files, and the outage's numbers for the report.
  func larryTurnBlinked(_ kind: CockpitOutage.Kind) -> (files: Bool, said: String, extra: [String: JSONValue]) {
    switch larryOutage.failed(kind, now: Self.outageNow) {
    case .file: return (true, "", [:])
    case .quiet: return (false, "", [:])
    case .fileOutage(let ms, let failures):
      log.event(
        "whiteboard",
        [
          "action": "cockpit_outage", "state": "filed", "ms": ms, "failures": failures, "board": board.id,
          "where": "WhiteboardView.larry",
        ])
      return (
        true, " (the Cockpit has been away for \(ms / 60_000) minutes, \(failures) turns failed)",
        ["outage_ms": .int(Int(ms)), "failures": .int(failures)]
      )
    }
  }

  /// A turn reached Larry, so any outage is over.
  func larryOutageEnded() {
    guard let ended = larryOutage.succeeded(now: Self.outageNow) else { return }
    log.event(
      "whiteboard",
      [
        "action": "cockpit_outage", "state": "ended", "ms": ended.ms, "failures": ended.failures, "filed": ended.filed,
        "board": board.id,
      ])
  }

  private static var outageNow: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
