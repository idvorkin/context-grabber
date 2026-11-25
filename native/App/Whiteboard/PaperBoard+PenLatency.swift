//  Story 1311 (context-grabber-7xv6): the board's Pencil-to-frame latency goes in the session log as `board_pen_latency`,
//  about every 200 measured moments and on a Pencil lift after at least 20. `scripts/native/pen-latency.sh` prints the
//  lines from the pulled logs.

import ContextCore
import UIKit

extension PaperBoardController {
  func logPenLatency(_ line: PenLatency.Summary, hz: Int) {
    log.event(
      "whiteboard",
      [
        "action": "board_pen_latency", "surface": "board", "board": model.board.id, "measures": "input_to_frame",
        "count": line.count, "p50_ms": line.p50, "p90_ms": line.p90, "slowest_ms": line.slowest, "hz": hz,
      ])
  }
}
