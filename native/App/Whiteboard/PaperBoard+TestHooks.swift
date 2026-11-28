//  A board on paper: the simulator's launch hooks: presses after ink, a page after ink, copy, and presses after a keep
//  or a batch. Moved from PaperBoard.swift as it was (context-grabber-fz4x).

import ContextCore
import PaperKit
import UIKit
import UniformTypeIdentifiers

extension PaperBoardController {
  func chooseMarkForTests() {
    guard LaunchHooks.current.whiteboard.chooseMark, !choseMarkForTests, model.editable, model.chosen == nil else {
      return
    }
    let visible = paper.contentVisibleFrame
    let hidden = model.turns.hiddenMarks
    let point = model.ghosts.lazy.filter { $0.who == .larry && !hidden.contains($0.id) }
      .flatMap(\.lines).joined().first(where: visible.contains)
    guard let point else { return }
    model.tap(at: point, zoom: screenScale)
    choseMarkForTests = model.chosen != nil
  }

  /// `GRABBER_WHITEBOARD_AFTER_INK=copy,paste` (or `select`, story 920): those, 2 s apart from a second after the first
  /// ink, for the simulator: it can't work the lasso, and keys reach only a run's first test. Copy selects all the ink and copies, as the lasso's does.
  func pressSoonForTests() {
    guard !pressedForTests, let presses = LaunchHooks.current.whiteboard.afterInk else { return }
    pressedForTests = true
    Task { @MainActor [weak self] in
      for press in presses {
        try? await Task.sleep(for: .seconds(1))
        if press == "paste" {
          self?.paste(from: "hook")
        } else if press == "select" {
          self?.selectAllForTests()
        } else {
          await self?.copyAllForTests()
        }
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  /// `GRABBER_WHITEBOARD_PAGE_AFTER_INK=<page>`: a second after the first ink, the view goes to that page's top (as far as
  /// the column lets it), for the simulator: a finger draws there and XCUITest has no two-finger drag (stories 433, 522).
  func goToPageSoonForTests() {
    guard !movedForTests, let page = LaunchHooks.current.whiteboard.pageAfterInk else { return }
    movedForTests = true
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self else { return }
      let size = self.paper.contentVisibleFrame.size
      self.paper.contentVisibleFrame = CGRect(origin: CGPoint(x: 0, y: self.board.frame(ofPage: page).minY), size: size)
      self.showPageNumber()
      self.layRules()
      self.log.event(
        "whiteboard",
        [
          "action": "paper_page_hook", "board": self.model.board.id, "page": page, "pages": self.pages,
          "visible": self.rect(self.paper.contentVisibleFrame),
        ])
    }
  }

  /// What the system's Copy took here: nothing does, on the simulator, with the selection set. So after asking, the selected
  /// ink goes on the clipboard in PaperKit's own format.
  private func copyAllForTests() async {
    guard let markup = paper.markup else { return }
    UIPasteboard.general.items = []
    paper.selection = Set(markup.subelements.strokes.map(\.elementID))
    try? await Task.sleep(for: .seconds(0.5))
    let copy = #selector(UIResponderStandardEditActions.copy(_:))
    let took = UIApplication.shared.sendAction(copy, to: nil, from: nil, for: nil)
    if !took, let data = try? await paper.selectedMarkup.dataRepresentation() {
      UIPasteboard.general.setData(data, forPasteboardType: UTType.paperkit.identifier)
    }
    log.event(
      "whiteboard",
      [
        "action": "paper_copy_hook", "board": model.board.id, "took": took, "selected": paper.selection.count,
        "types": Array(UIPasteboard.general.types.prefix(8)),
      ])
    paper.selection = []
  }

  /// `GRABBER_WHITEBOARD_AFTER_KEEP=<seconds>,undo,redo,...` (after a keep) and `GRABBER_WHITEBOARD_AFTER_OPS=...` (after
  /// a batch of Larry's moved the board, story 814): those presses, 3 s apart, for the simulator: a phone's tool picker
  /// has no Undo, and keys reach only a run's first test.
  func undoSoonForTests(_ hook: WhiteboardHooks.AfterKeep?) {
    guard let hook else { return }
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(hook.delay))
      for press in hook.presses {
        guard let self else { return }
        press == "undo" ? self.paper.undoManager?.undo() : self.paper.undoManager?.redo()
        self.log.event(
          "whiteboard",
          [
            "action": "paper_press_hook", "press": press, "board": self.model.board.id,
            "strokes": self.model.drawing.strokes.count, "pages": self.pages,
            "can_undo": self.paper.undoManager?.canUndo ?? false, "can_redo": self.paper.undoManager?.canRedo ?? false,
          ])
        try? await Task.sleep(for: .seconds(3))
      }
    }
  }
}
