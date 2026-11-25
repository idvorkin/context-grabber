//  Story 1335 (bead context-grabber-lyr4): a real board keeps only its ink, so anything else on the page is named by
//  kind as it appears (`board_markup_added`), and the board's save says what it left behind (`board_markup_unsaved`).
//  The page's elements are walked only when their count no longer matches the strokes', and again only when that count
//  changes: walking the set by element is slow (see `strokeFrames`), and a board of ink alone never walks it.

import ContextCore
import PaperKit
import PencilKit

extension PaperBoardController {
  func takeMarkupCensus(_ markup: PaperMarkup, frames: [String: CGRect]) {
    let elements = markup.subelements.count
    guard elements != censusElements else { return }
    censusElements = elements
    guard elements != frames.count else {
      markupCensus = nil
      model.markupNotKept = ""
      return
    }
    let census = BoardMarkupCensus(
      strokes: markup.subelements.strokes.count, uniqueStrokes: frames.count,
      otherKinds: markup.subelements.ids.compactMap(Self.notInk))
    if markupCensus == nil {
      // Only strokes are saved, and the tools offered only make strokes: this says if that ever stops being true.
      log.event(
        "whiteboard",
        [
          "action": "paper_not_ink", "board": model.board.id, "elements": elements, "strokes": frames.count,
          "kinds": census.text,
        ])
    }
    for kind in census.added(since: markupCensus) {
      log.event(
        "board_markup_added",
        ["board": model.board.id, "kind": kind, "count": census.kinds[kind] ?? 0, "elements": elements])
    }
    markupCensus = census
    model.markupNotKept = census.text
  }

  /// The kind of an element that isn't ink, nil for a stroke.
  nonisolated static func notInk(_ id: MarkupOrderedSet.ElementID) -> String? {
    switch id {
    case .stroke: return nil
    case .shape: return "shape"
    case .image: return "image"
    case .link: return "link"
    case .loupe: return "loupe"
    @unknown default: return "other"
    }
  }
}
