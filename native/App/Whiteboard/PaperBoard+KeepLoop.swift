//  Bead context-grabber-pbvt: a loop of keeps of three of Larry's circles on the simulator, each looked at by the kept-ink
//  look (story 650) and taken out again, so the rate at which PaperKit draws part of a kept mark black or not at all can
//  be counted, and the ways of putting a mark into the markup compared (`GRABBER_WHITEBOARD_KEEP_LOOP`).

import ContextCore
import PaperKit
import PencilKit
import UIKit

extension PaperBoardController {
  /// How a kept mark's strokes go into the markup: one append each, the board's way (`each`), unless a keep loop or
  /// `GRABBER_WHITEBOARD_KEEP_WAY` asks for `batch`.
  static var keepWay: WhiteboardHooks.KeepLoop.How = .each
  private static var keepLoopStarted = false

  /// `GRABBER_WHITEBOARD_KEEP_LOOP=<count>[,<how>]`: that many keeps of three circles in Larry's purple, a few
  /// milliseconds apart as Keep all makes them, each left 4 s for the look and its heal, then taken out. Each keep logs
  /// `keep_loop` with its number; the verdict is the look's `paper_kept_ink` at attempt 0 .
  func keepLoopForTests() {
    guard let hook = LaunchHooks.current.whiteboard.keepLoop, !Self.keepLoopStarted else { return }
    Self.keepLoopStarted = true
    Self.keepWay = hook.how
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(2))
      for i in 0..<hook.count {
        guard let self else { return }
        let started = Date()
        let strokes = (0..<3).flatMap { j in
          WhiteboardModel.strokes(
            [Self.loopCircle(j)], color: UIColor(rgb: WhiteboardTurn.larryColor), width: WhiteboardTurn.defaultPen,
            spacing: 4, made: started.addingTimeInterval(Double(j) * 0.005))
        }
        self.log.event(
          "whiteboard",
          ["action": "keep_loop", "i": i, "of": hook.count, "how": hook.how.rawValue, "board": self.model.board.id])
        self.keep(strokes, named: WhiteboardModel.keepAllUndoName)
        try? await Task.sleep(for: .seconds(3.5))
        self.takeOut(Set(strokes.map { BoardMoment.nearest($0) }))
        try? await Task.sleep(for: .seconds(0.5))
      }
      self?.log.event("whiteboard", ["action": "keep_loop_done", "count": hook.count, "how": hook.how.rawValue])
    }
  }

  /// One of three circles side by side where the UI tests' ghosts sit, 20 points across.
  private static func loopCircle(_ j: Int) -> [CGPoint] {
    let center = CGPoint(x: 222 + CGFloat(j) * 22, y: 452)
    return (0...24).map { k in
      let a = CGFloat(k) / 24 * 2 * .pi
      return CGPoint(x: center.x + 9 * cos(a), y: center.y + 9 * sin(a))
    }
  }

  /// The strokes made at `moments` out of the markup, as if never kept.
  private func takeOut(_ moments: Set<Int64>) {
    guard var markup = paper.markup else { return }
    for stroke in markup.subelements.strokes where moments.contains(BoardMoment.nearest(stroke)) {
      _ = markup.subelements.removeElement(for: stroke.elementID)
    }
    let held = setMarkup(markup).held
    inkFrames = held.strokeFrames
    model.settled(held.inkDrawing)
  }
}
