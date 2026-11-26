//  Rewording a kept text on paper (spec 2026-11-17-whiteboard-reword-and-live-snap-design.md, stories 940–942; the web
//  board's Edit): a finger tap on a kept text opens its words in a field where it is; done (Return, or a tap off it)
//  draws the new words in its place as the same text, one undo. What the words mean and where the lines go is
//  `BoardReword` in ContextCore. A kept text is its glyph strokes, known by their one creation time (story 817), so each
//  wording is a version of the text under one id, and an undo's glyphs find their own words again.
//  ponytail: the field stays where it opened if the board scrolls under it; done still lands the words on the text.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI

/// The kept text open for rewording, if any, and the words in its field.
@MainActor
final class BoardRewordState: ObservableObject {
  struct Editing: Equatable {
    /// The version of the text whose glyphs are on the board.
    var text: BoardText
    /// Its glyphs' element keys.
    var keys: Set<String>
    /// Where its lines start and how wide they wrap, in board points.
    var topLeft: CGPoint
    var width: CGFloat
    /// Its glyphs' pen and colour, which the new words keep.
    var pen: CGFloat
    var color: UIColor
    /// The field, in the board view's points, and its letters' size there.
    var frame: CGRect
    var fontSize: CGFloat
  }

  @Published var editing: Editing?
  @Published var words = ""
}

extension PaperBoardController {
  /// A finger tap at `at` (board points), with no marks showing: true when it was the reword's, a tap on a kept text
  /// that opened it, or a tap off an open one that is done with it.
  func rewordTapped(at point: CGPoint) -> Bool {
    if reword.editing != nil {
      finishReword(why: "tap_off")
      return true
    }
    guard model.editable, let found = keptTextGlyphs(at: point) else { return false }
    let text = found.text
    let face = text.font.face
    let size = CGFloat(text.size)
    let topLeft = BoardReword.topLeft(
      of: text.text, size: size, face: face, box: found.box, lettering: text.lettering ?? .single)
    let width = BoardReword.width(box: found.box, pageRight: BoardPages.pageWidth)
    let zoom = screenScale
    let origin = lines.convert(lines.spot(of: topLeft), to: view)
    let reach = max(120, min(width * zoom, view.bounds.width - origin.x - 8))
    let frame = CGRect(
      x: origin.x, y: origin.y, width: reach, height: max(found.box.maxY - topLeft.y, size * BoardToText.leading) * zoom
    )
    paper.selection = []
    reword.words = text.text
    reword.editing = BoardRewordState.Editing(
      text: text, keys: found.keys, topLeft: topLeft, width: width, pen: found.pen, color: found.color, frame: frame,
      fontSize: max(12, size * zoom))
    log.event(
      "whiteboard",
      [
        "action": "reword_open", "board": model.board.id, "text_id": text.id, "chars": text.text.count,
        "glyphs": found.keys.count, "box": rect(found.box), "width": round(width),
      ])
    return true
  }

  /// Stories 940–942: the field's words applied to the text. `why`: return, tap_off or focus, for the log.
  func finishReword(why: String) {
    guard let editing = reword.editing else { return }
    reword.editing = nil
    if !paper.isFirstResponder { paper.becomeFirstResponder() }
    var event: [String: Any] = ["action": "reword", "board": model.board.id, "text_id": editing.text.id, "why": why]
    defer { log.event("whiteboard", event) }
    let here = Set(paper.markup?.subelements.strokes.map { Self.key($0.elementID) } ?? [])
    guard editing.keys.isSubset(of: here) else {
      event["outcome"] = "text_gone"
      model.say("The text went while it was being edited")
      return
    }
    switch BoardReword.outcome(old: editing.text.text, edited: reword.words) {
    case .unchanged:
      event["outcome"] = "unchanged"
    case .delete:
      event["outcome"] = "deleted"
      replaceInk(removing: editing.keys, adding: [], named: BoardReword.deleteName)
    case .reword(let words):
      let face = editing.text.font.face
      let size = CGFloat(editing.text.size)
      // #950: redrawn in the lettering it was made in.
      let lettering = editing.text.lettering ?? .single
      let rows = BoardReword.rows(words, width: editing.width, size: size, face: face, lettering: lettering)
      let made = BoardText.time(Date())
      let strokes = BoardReword.lines(
        rows, topLeft: editing.topLeft, size: size, face: face, lettering: lettering
      ).flatMap { shape in
        WhiteboardModel.strokes(
          WhiteboardTurn.lines(shape, frame: .zero, scale: 1), color: editing.color, width: editing.pen, spacing: 4,
          made: made.date)
      }
      guard !strokes.isEmpty else {
        event["outcome"] = "no_letters"
        model.say("Nothing in that text can be drawn")
        return
      }
      var text = editing.text
      text.t = made.t
      text.text = words
      text.glyphs = strokes.count
      model.keep(text: text)
      replaceInk(removing: editing.keys, adding: strokes, named: BoardReword.undoName, reworded: [text.id])
      event.merge(["outcome": "reworded", "chars": words.count, "rows": rows.count, "glyphs": strokes.count]) { $1 }
    }
  }

  /// The strokes (by key) of the kept text a finger tap at `point` would open, or nil off every text (story 1196).
  func keptTextKeys(at point: CGPoint) -> Set<String>? {
    guard model.editable else { return nil }
    return keptTextGlyphs(at: point)?.keys
  }

  /// The whole kept text whose glyphs are at `point` (within a finger's width), the nearest if two are: its version, its
  /// glyphs' keys and box, and their pen and colour. A text missing glyphs is plain ink by now (story 854).
  private func keptTextGlyphs(at point: CGPoint)
    -> (text: BoardText, keys: Set<String>, box: CGRect, pen: CGFloat, color: UIColor)?
  {
    guard !model.texts.isEmpty, let markup = paper.markup else { return nil }
    let byTime = BoardText.byTime(model.texts)
    var found: [Int64: (text: BoardText, keys: Set<String>, box: CGRect, pen: CGFloat, color: UIColor)] = [:]
    for element in markup.subelements.strokes {
      let stroke = PKStroke(
        ink: element.ink, path: element.path, transform: element.transform, mask: element.mask,
        randomSeed: element.randomSeed)
      let t = BoardMoment.of(stroke)
      guard let text = BoardText.owning(t, in: byTime) else { continue }
      let key = Self.key(element.elementID)
      if var entry = found[text.t] {
        entry.keys.insert(key)
        entry.box = entry.box.union(stroke.renderBounds)
        found[text.t] = entry
      } else {
        let pen = stroke.path.first?.size.width ?? WhiteboardTurn.defaultPen
        found[text.t] = (text, [key], stroke.renderBounds, pen, stroke.ink.color)
      }
    }
    let tolerance = WhiteboardTurn.tapReach / screenScale
    let distance = { (box: CGRect) -> CGFloat in
      hypot(max(box.minX - point.x, 0, point.x - box.maxX), max(box.minY - point.y, 0, point.y - box.maxY))
    }
    return found.values
      .filter { entry in
        (entry.text.glyphs.map { $0 == entry.keys.count } ?? true) && distance(entry.box) <= tolerance
      }
      .min { distance($0.box) < distance($1.box) }
  }
}

/// Story 940: the kept text's words in a field where the text is, over the board. Return, or a tap off it, is done.
struct RewordField: View {
  let controller: PaperBoardController
  @ObservedObject var state: BoardRewordState
  @FocusState private var focused: Bool

  var body: some View {
    if let editing = state.editing {
      TextField("Words", text: $state.words, axis: .vertical)
        .accessibilityIdentifier("whiteboard-reword")
        .font(font(editing))
        .foregroundStyle(Color(editing.color))
        .focused($focused)
        .submitLabel(.done)
        .onSubmit { controller.finishReword(why: "return") }
        .onChange(of: state.words) { before, after in
          // Return in a field that wraps is a new line: here it is done, and the line isn't kept, even when it came with
          // other letters in one change (bead context-grabber-4ief).
          if let typed = BoardReword.typedReturn(before: before, after: after) {
            state.words = typed
            controller.finishReword(why: "return")
          }
        }
        .onChange(of: focused) { was, now in
          if was, !now { controller.finishReword(why: "focus") }
        }
        .padding(.horizontal, 4)
        .frame(width: editing.frame.width, alignment: .topLeading)
        .frame(minHeight: editing.frame.height, alignment: .topLeading)
        .background(Color(controller.paperColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 1.5))
        .position(x: editing.frame.minX + editing.frame.width / 2 - 4, y: editing.frame.minY + editing.frame.height / 2)
        .task(id: editing.text.t) { focused = true }
    }
  }

  private func font(_ editing: BoardRewordState.Editing) -> Font {
    editing.text.font == .hand
      ? .custom("Noteworthy-Light", fixedSize: editing.fontSize) : .custom("Helvetica", fixedSize: editing.fontSize)
  }
}
