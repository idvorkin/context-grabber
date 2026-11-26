//  #1527 (story 1168): the two parts of the board's handling of a stroke that grow with the board, the model taking the
//  new drawing and the stroke fading the marks it writes over, name their own steps in the log when one takes a
//  twentieth of a second or more (`ink_part_slow`), so the fix for drawing lag on a full board goes at the step that grows.

import ContextCore

extension WhiteboardModel {
  /// A part slow enough to name its steps.
  static let slowPartMs = 50

  /// `part`'s steps by time, when it took `slowPartMs` or more.
  func logPartLaps(_ laps: StepLaps, part: String) {
    guard let slow = laps.report(overMs: Self.slowPartMs) else { return }
    log.event(
      "whiteboard",
      [
        "action": "ink_part_slow", "part": part, "board": board.id, "total_ms": slow.totalMs, "laps": slow.laps,
        "strokes": drawing.strokes.count, "marks": turns.ghosts.count,
      ])
  }
}
