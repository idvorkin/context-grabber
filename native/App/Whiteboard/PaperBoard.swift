//  A board on paper (whiteboard spec's "On paper: the default", stories 590–657; #636): PaperKit's controller, which
//  can't be subclassed, held in `PaperHost` with the page lines, the tool picker and the touch log; and on it
//  `PaperBoardController`, which draws on a board through its model, so it saves and syncs, with its ghosts, Larry's
//  marks, the mic and paste. A look-only board (another device's, or any on an iPhone) shows the same way with
//  drawing off and no tools. Ghosts lie on the sheet under the ink, in
//  PaperKit's content view, so they move with the board whatever it does.
//  Its features are in PaperBoard+<Feature>.swift beside it; PaperKit's host is PaperHost.swift, the SwiftUI canvas
//  PaperBoardCanvas.swift, the paper PaperLines.swift.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI
import UIKit

extension PaperMarkup {
  /// The ink as a drawing, in today's file format. The strokes are remade: PKDrawing(strokes:) on what
  /// `subelements.strokes` gives throws an Objective-C exception, nil into PencilKit's set of UUIDs, seen on the simulator
  /// on iOS 27 with ink appended from a drawing.
  var inkDrawing: PKDrawing {
    PKDrawing(
      strokes: subelements.strokes.map {
        PKStroke(ink: $0.ink, path: $0.path, transform: $0.transform, mask: $0.mask, randomSeed: $0.randomSeed)
      })
  }

  /// `subelements.strokes`, not the set itself: walking the set by element took 4.3 s at 1,000 strokes on the simulator
  /// and over 40 s at 5,000.
  var strokeFrames: [String: CGRect] {
    Dictionary(
      subelements.strokes.map { (PaperHost.key($0.elementID), $0.renderFrame) }, uniquingKeysWith: { _, new in new })
  }
}

/// A real board on paper, drawn on this device. The drawing goes through the board's model.
@MainActor
final class PaperBoardController: PaperHost, ObservableObject, PaperMarkupViewController.Delegate {
  @Published private(set) var pageText = BoardPages().pageText(visibleMidY: 0, pages: 1)
  /// The chosen mark's box in this view's points, where Keep and Dismiss sit beside it (story 825); nil with none.
  @Published var choiceFrame: CGRect?
  /// Where the board is on screen, for its question cards (stories 880–886).
  let place = WhiteboardBoardPlace()
  /// Story 852: the paste just landed, selected, in this view's points, where its Delete sits; nil once anything else
  /// is selected or the ink changes.
  @Published var pastedFrame: CGRect?
  /// The landed paste's elements, by key.
  var pasted: Set<String> = []
  /// Story 910: the lassoed arrow Connect would join, in this view's points, and its elements by key; nil with none.
  @Published var connectFrame: CGRect?
  var connectKeys: Set<String> = []
  /// Story 1168: when the ink last changed, for a slow change's `since_ink_ms`.
  var lastInkAt: CFTimeInterval?
  var following: Task<Void, Never>?
  var selectedNewestForTests = false
  var marking: Task<Void, Never>?
  /// Headers made by ink whose mark is away, as last logged (#967).
  var marksGone: Set<String> = []
  /// Each header's ▾ in the margin, over the ink (stories 1040, 1041), and a new header's tint.
  @Published var headerMarks: [BoardOutline.HeaderMark] = []
  @Published var headerTint: HeaderTint?
  var tinting: Task<Void, Never>?
  /// Stories 902, 903: an eraser touch on a board with a fold, from where it went down (PaperBoard+FoldErase.swift).
  var foldErasing: FoldErasing?
  /// Story 858: the menu a held finger brought up, in this view's points; nil with none.
  @Published var holdMenu: HoldMenu?
  /// About when the finger that brought the menu went down, so the dot a drawing finger leaves is told as its own.
  var holdBegan: Date?
  /// A finger held in the margin: where it went down, board `y`, and in this view.
  var grip: (y: CGFloat, spot: CGPoint)?
  /// Story 933: the touch that went down in the margin, for its log line when it lifts, and whether the finger's hold
  /// recogniser fired for it.
  var marginTry: (touch: ObjectIdentifier, tool: BoardMarginHold.Tool, y: CGFloat, held: Bool)?
  /// What the last touch to go down was: a stroke the Pencil drew is the one the margin's Pencil hold judges.
  var lastDown: UITouch.TouchType?
  private lazy var holding: UILongPressGestureRecognizer = {
    let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
    hold.minimumPressDuration = BoardMargin.holdAfter
    hold.allowableMovement = BoardMargin.dragAfter
    hold.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    hold.cancelsTouchesInView = false
    hold.delegate = self
    return hold
  }()

  let model: WhiteboardModel
  let log: SessionLog
  /// Stories 920–922: To text beside the lasso's ink (BoardToTextFlow.swift).
  let toText = BoardToTextState()
  /// Story 1095: the label on the selection.
  let selectionLabel = BoardSelectionLabelState()
  /// Stories 923–925: a stroke held still at its end snaps to its shape (BoardShapeSnapping.swift).
  let snaps = BoardSnapWatch()
  /// Story 1104: each drawing touch's path, for the log.
  let paths = BoardTouchPaths()
  /// Stories 1044, 1038, 1039, 1042 (#1000): the band the room handle shows while held (PaperBoard+RoomBand.swift).
  let roomBand = BoardRoomBandState()
  /// Story 1051 (#1000): *Nothing under the scribble to erase*, while it shows (PaperBoard+ScratchFeedback.swift).
  let scratchNote = BoardScratchNote()
  /// Stories 940–942: a kept text's words open in place (BoardRewordFlow.swift).
  let reword = BoardRewordState()
  /// Story 1188: PaperKit's handwriting reflow, for the log (PaperBoard+ReflowWatch.swift).
  let reflowWatch = BoardReflowWatch()
  let selectionDrag = SelectionDragWatch()
  /// A page wide.
  let board = BoardPages()
  var pages = 1
  private var laidWidth: CGFloat = 0
  /// What the column's own changes shouldn't report as a person's. Set only by the edit lane (PaperBoard+EditLane.swift).
  var quiet = false
  var inkFrames: [String: CGRect] = [:]
  /// Story 1335: what's on the page the board won't keep, and the element count it was last taken at.
  var markupCensus: BoardMarkupCensus?
  var censusElements = 0
  private var remembering: Task<Void, Never>?
  var redrawing: Task<Void, Never>?
  private var responding: Task<Void, Never>?
  private(set) var rules = PaperRules.none
  private var rulesLaid: (rules: PaperRules, pages: Int, step: CGFloat, y: ClosedRange<CGFloat>)?
  /// The window this board made light, and how it was.
  private var lightWindow: (window: UIWindow, style: UIUserInterfaceStyle)?
  /// A Pencil or a drawing finger is down, as the pacer was told.
  var toolDown = false
  /// What a finger does when no ghost shows; set while the board has it tapping instead (PaperBoard+FingerDraws.swift).
  var fingerUsually: (mode: PaperMarkupViewController.TouchMode, autoDraws: Bool)?
  /// Stories 354, 1152, 1153: whether a finger draws, by the marks showing, a tap off them and the Pencil.
  var finger = WhiteboardFinger(pencil: PaperBoardController.pencilThisLaunch)
  /// A tap's selection comes after the lift: until this time one is put straight back.
  private var noSelectionUntil: Double = 0
  /// The last finger tap while marks showed, in board points, and when: the dot PaperKit draws there is taken back.
  var ghostTap: TapDot?
  /// Story 947: the group a finger tap selected, by its strokes' names, and until when a selection PaperKit makes of the
  /// same tap is put back to it. Gone at the next touch.
  var groupTap: (names: Set<String>, until: Double)?
  /// How far a ghost's place on the sheet was from where the visible frame says, over this touch, and how many looks
  /// that took. For the iPad: the spec's "A ghost sits on the paper".
  var seat = (worst: CGFloat(0), checks: 0)
  var pressedForTests = false
  /// #999: the strokes the last scratch-out took, so a later change that brings them back without an Undo says so.
  var scratched: Set<String> = []
  /// The element keys of the markup `put` last set: what a fold's scratch-out wanted on the sheet (#1015).
  var putKeys: Set<String> = []
  var movedForTests = false
  /// The undo stack a kept mark's steps went on. A closing view may no longer be able to say.
  weak var stepsOn: UndoManager?
  /// #966: the board's take-back of PaperKit's own step, which leaves one of the board's own on the stack.
  let probe = BoardUndoProbe()
  /// #965: the bar's Undo and Redo are about to be brought up to date.
  var undoShowing = false
  /// #966: what the stack said just before an Undo or Redo ran, for the log's line once it has.
  var stepping: (name: String, strokes: Int, frames: [String: CGRect])?
  /// Undos and Redos run on the board's stack so far: strokes taken out to be drawn again go back only if none ran meanwhile.
  var undoSteps = 0

  private var placeKey: String { "whiteboard_paper_y_\(model.board.id)" }

  init(model: WhiteboardModel, log: SessionLog) {
    self.model = model
    self.log = log
    super.init(boardPaper: model.paper)
    drawsHere = model.editable
  }

  required init?(coder: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    paper.delegate = self
    model.canvas = self
    model.questions.visibleRect = { [weak self] in self?.paperOnScreen ?? .null }
    model.pasteReach = board.pasteReach
    if model.editable { view.addGestureRecognizer(holding) }
    if drawsHere { view.addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(hovering(_:)))) }
    NotificationCenter.default.addObserver(
      self, selector: #selector(keyboardShown(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    watchUndo()
    watchCovers()
    watchHandwritingOffers()
    watchReflow()
    settleFinger()
  }

  /// Stories 892, 893: the Pencil hovering over the paper, in board points. A pointer's hover has no height above the
  /// glass and isn't the Pencil.
  @objc private func hovering(_ hover: UIHoverGestureRecognizer) {
    guard hover.state == .began || hover.state == .changed, hover.zOffset > 0 else { return }
    model.hovered(at: lines.columnPoint(of: hover.location(in: lines)))
  }

  /// #850: whether a board raises the on-screen keyboard. On the iPad simulator one rose over an open Board menu and its
  /// tap didn't take; this says whether a real iPad does it too.
  @objc private func keyboardShown(_ note: Notification) {
    let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
    log.event(
      "whiteboard",
      [
        "action": "keyboard_shown", "height": Int(frame.height), "paper_has_it": paper.isFirstResponder,
        "taking_back": responding != nil,
      ])
  }

  /// The part of the column on screen: the visible frame runs past the paper where a phone's one page is shorter than the
  /// screen, and at a side.
  var paperOnScreen: CGRect {
    let visible = paper.contentVisibleFrame
    let onPaper = visible.intersection(board.bounds(pages: pages))
    return onPaper.isNull || onPaper.isEmpty ? visible : onPaper
  }

  /// Screen points to a board point, whatever PaperKit's zoom scale means.
  var screenScale: CGFloat {
    view.bounds.width / max(paper.contentVisibleFrame.width, 1)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let width = view.bounds.width
    guard width > 0, width != laidWidth else { return }
    let first = laidWidth == 0
    laidWidth = width
    // On the next turn: PaperKit lays itself out first, and this publishes, which SwiftUI's update may not.
    Task { @MainActor [weak self] in
      guard let self else { return }
      if first { self.load() }
      self.fitToPage(first: first)
      self.placeCards()
      // #845: whether an opened board's ink is drawn, on every device's geometry.
      if first, let ink = self.paper.markup?.inkDrawing, !ink.strokes.isEmpty {
        self.lookForInk(ink.bounds, why: "open")
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    paper.becomeFirstResponder()
    showUndoSoon()
    // Story 1153: PaperKit may set its own touch as it first appears; the board's rule goes back over it.
    settleFinger()
  }

  /// The whole window in light mode while a board on paper is up, whatever the device's. In dark mode PaperKit draws new
  /// ink so it can't be seen: black on Plain's black; and with only this controller's views set light, white on white on
  /// a new board, as PaperKit's canvas doesn't reliably take the override (the simulator, iOS 27, 2026-11-03). Saved ink
  /// is the same either way. ponytail: light only; a board in dark mode needs PaperKit's ink to follow the mode as
  /// PencilKit's canvas does, and a look on the iPad.
  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    guard lightWindow == nil, let window = view.window else { return }
    lightWindow = (window, window.overrideUserInterfaceStyle)
    window.overrideUserInterfaceStyle = .light
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    finishTouches()
    rememberPlace()
    lightWindow?.window.overrideUserInterfaceStyle = lightWindow?.style ?? .unspecified
    lightWindow = nil
  }

  private func load() {
    let started = CACurrentMediaTime()
    let drawing = model.drawing
    pages = board.pagesNeeded(inkMaxY: drawing.strokes.isEmpty ? nil : drawing.bounds.maxY)
    var markup = PaperMarkup(bounds: board.bounds(pages: pages))
    markup.append(contentsOf: drawing)
    setMarkup(markup)
    inkFrames = paper.markup?.strokeFrames ?? [:]
    model.inkReset(paper.markup.map(Self.allHashes) ?? [:])
    showMarks()
    showLines()
    log.event(
      "whiteboard",
      [
        "action": "paper_open", "board": model.board.id, "strokes": inkFrames.count, "pages": pages,
        "width": Double(board.width), "ink": rect(drawing.strokes.isEmpty ? .zero : drawing.bounds),
        "editable": drawsHere, "ms": ms(CACurrentMediaTime() - started),
      ])
  }

  /// The page fits the screen's width, at the place he left it or, when only the width changed, the place it's at.
  private func fitToPage(first: Bool) {
    let y =
      first
      ? board.openingY(remembered: UserDefaults.standard.object(forKey: placeKey) as? Double, pages: pages)
      : paper.contentVisibleFrame.minY
    fit(columnWidth: board.width)
    let size = paper.contentVisibleFrame.size
    paper.contentVisibleFrame = CGRect(origin: CGPoint(x: 0, y: y), size: size)
    showPageNumber()
    layRules()
  }

  func showLines() {
    lines.show(width: board.width, ends: board.pageEnds(pages: pages))
    layRules()
  }

  func setRules(_ wanted: PaperRules) {
    guard wanted != rules else { return }
    rules = wanted
    layRules()
    lookAfterChange()
  }

  override func setBoardPaper(_ new: BoardPaper) {
    guard new != boardPaper else { return }
    super.setBoardPaper(new)
    lookAfterChange()
  }

  /// A choice in the menu, which leaves nothing the first responder as it closes: PaperKit then draws no stroke, and shows no
  /// tool picker (3 of 3 on the simulator, iOS 27), and giving it back as the touch lands is too late for that touch (5 of 5).
  /// So it goes back as the menu goes, for as long as that takes.
  func takeTheResponderBack() {
    responding?.cancel()
    responding = Task { @MainActor [weak self] in
      var lost = 0
      for _ in 0..<30 {
        try? await Task.sleep(for: .seconds(0.1))
        guard let self, !Task.isCancelled else { return }
        if !self.paper.isFirstResponder {
          lost += 1
          self.paper.becomeFirstResponder()
        }
      }
      self?.log.event(
        "whiteboard",
        ["action": "paper_responder", "times_lost": lost, "has_it": self?.paper.isFirstResponder ?? false])
      self?.responding = nil
    }
  }

  /// The sheet changed under the ink, which must not lose it: `paper_ink_look` says if it did.
  private func lookAfterChange() {
    guard let ink = paper.markup?.inkDrawing, !ink.strokes.isEmpty else { return }
    lookForInk(ink.bounds, why: "sheet")
  }

  /// The grid or ruled lines for a screen above and below the view, so they're laid again only now and then in a scroll, and
  /// when the zoom thins them or a page is added.
  func layRules() {
    let zoom = screenScale
    let visible = paper.contentVisibleFrame
    let step = WhiteboardFrame.lineStep(zoom: zoom)
    lines.hair = 1 / (traitCollection.displayScale * max(zoom, 0.01))
    if let laid = rulesLaid, laid.rules == rules, laid.pages == pages, laid.step == step,
      laid.y.contains(visible.minY), laid.y.contains(visible.maxY)
    {
      return
    }
    let y = (visible.minY - visible.height)...(visible.maxY + visible.height)
    rulesLaid = (rules, pages, step, y)
    switch rules {
    case .none:
      lines.showRules(across: [], span: 0...0, down: [])
    case .ruled:
      lines.showRules(across: [], span: 0...0, down: board.ruledLines(visible: y, pages: pages, zoom: zoom))
    case .grid:
      let area = CGRect(x: 0, y: y.lowerBound, width: board.width, height: y.upperBound - y.lowerBound)
      let grid = board.gridLines(visible: area, pages: pages, zoom: zoom)
      let column = board.bounds(pages: pages)
      let span = min(max(y.lowerBound, 0), column.maxY)...max(min(y.upperBound, column.maxY), 0)
      lines.showRules(across: grid.across, span: span, down: grid.down)
    }
  }

  func showPageNumber() {
    let text = board.pageText(visibleMidY: paper.contentVisibleFrame.midY, pages: pages)
    if text != pageText { pageText = text }
    model.screenMoved()
  }

  private func rememberPlace() {
    remembering?.cancel()
    UserDefaults.standard.set(Double(paper.contentVisibleFrame.minY), forKey: placeKey)
  }

  // MARK: - PaperKit's delegate

  func paperMarkupViewControllerDidChangeMarkup(_ controller: PaperMarkupViewController) {
    guard !quiet, let markup = controller.markup else { return }
    let started = CACurrentMediaTime()
    // Story 1168: a slow change names its slow parts, once all below has run, the deferred step too.
    let laps = StepLaps()
    let frames = markup.strokeFrames
    let previous = inkFrames
    let change = PaperProbe.inkChange(before: inkFrames, after: frames)
    inkFrames = frames
    laps.lap("frames")
    defer { logSlowInk(laps, change: change) }
    var consumed =
      laps.time("tap_dot") { takesBackTapDot(change, markup: markup, frames: frames) }
      || laps.time("margin_hold") { marginHeld(change, markup: markup) }
      || laps.time("pick_up") { pickedUp(change, markup: markup, before: previous) }
    // Story 1269: a stroke of his fades a mark it writes over; a scratch-out's zigzag goes and leaves it as it was.
    if !consumed { laps.time("marks") { marksWritten(change, markup: markup, undo: controller.undoManager) } }
    consumed = consumed || laps.time("scratch") { scratchesOut(change, markup) }
    snapNoticed(change, consumed: consumed)
    laps.lap("snap")
    if consumed { return }
    inkHeaderSoon(change)
    if !change.isEmpty {
      forgetPaste()
      showMarksSoon()
      followSoon()
    }
    laps.lap("soon")
    defer {
      // Story 843: after the model's revision has moved on.
      if !change.isEmpty {
        model.inkElements(
          updated: Self.hashes(of: Set(change.added + change.moved.map(\.id)), in: markup), removed: change.removed,
          report: true)
        laps.lap("elements")
      }
    }
    run?.facts.inkAdded += change.added.count
    run?.facts.inkMoved += change.moved.count
    run?.facts.inkRemoved += change.removed.count
    takeMarkupCensus(markup, frames: frames)
    let drawing = markup.inkDrawing
    model.changed(drawing)
    laps.lap("model")
    if change.added.count > 0 {
      pressSoonForTests()
      goToPageSoonForTests()
    }
    // An undo can take back a page added earlier: the count follows what the markup holds.
    pages = board.pages(in: markup.bounds)
    let wanted = board.pages(
      after: pages, inkMaxY: drawing.strokes.isEmpty ? nil : drawing.bounds.maxY,
      redoWaiting: controller.undoManager?.canRedo ?? false)
    laps.lap("pages")
    var event: [String: Any] = [
      "action": "paper_ink", "board": model.board.id, "strokes": frames.count, "pages": pages, "wanted": wanted,
      "added": change.added.count, "moved": change.moved.count, "removed": change.removed.count,
      "added_box": rect(change.added.compactMap { frames[$0] }.reduce(CGRect.null) { $0.union($1) }),
      "can_undo": controller.undoManager?.canUndo ?? false, "can_redo": controller.undoManager?.canRedo ?? false,
      "ms": ms(CACurrentMediaTime() - started),
    ]
    event.merge(unheard(change, frames: frames, undo: controller.undoManager)) { $1 }
    event.merge(moveAudit(change, markup: markup, frames: frames)) { $1 }
    let apart = keepOwnersApart(change, markup: markup, previous: previous, undo: controller.undoManager)
    event.merge(apart) { $1 }
    // #999: scratched-out ink back without an Undo or Redo.
    if !scratched.isEmpty, controller.undoManager?.isUndoing != true, controller.undoManager?.isRedoing != true {
      let back = change.added.filter(scratched.contains).count
      if back > 0 { event["came_back"] = back }
    }
    log.event("whiteboard", event)
    laps.lap("audits")
    showLines()
    showPageNumber()
    showToText()
    laps.lap("show")
    // Not from inside PaperKit's own callback.
    if wanted > pages { Task { @MainActor [weak self] in self?.grow(to: wanted) } }
    pushesOnMove(change, markup: markup, undo: controller.undoManager, split: apart["apart"] as? String == "split")
    laps.lap("push")
  }

  /// Every stroke where it was, to half a point.
  static func close(_ a: [String: CGRect], _ b: [String: CGRect]) -> Bool {
    a.count == b.count
      && a.allSatisfy { key, box in b[key].map { abs($0.minX - box.minX) + abs($0.minY - box.minY) < 0.5 } ?? false }
  }

  /// The markup's bounds are the only way PaperKit's interface has to change the column. On Igor's iPad, 2026-11-03, a
  /// page added like this kept a stroke under way under the Pencil, and the view where it was.
  private func grow(to wanted: Int) {
    guard wanted > pages, var markup = paper.markup else { return }
    markup.bounds = board.bounds(pages: wanted)
    setMarkup(markup)
    pages = wanted
    run?.pageAdded = true
    showLines()
    showPageNumber()
    redrawSoon()
  }

  func paperMarkupViewControllerDidChangeSelection(_ controller: PaperMarkupViewController) {
    run?.facts.selectionChanges += 1
    run?.selected = controller.selection.count
    // Story 947: PaperKit's own selection for a tap on a group goes back to the whole group.
    if let tap = groupTap { reselectGroupTap(until: tap.until, why: "selection") }
    let putBack = !controller.selection.isEmpty && CACurrentMediaTime() < noSelectionUntil
    logSelection(controller.selection, putBack: putBack)
    if putBack { controller.selection = [] }
    // Story 844: what the lasso holds, for Larry.
    let keys = Set(controller.selection.map(Self.key))
    if !pasted.isEmpty, keys != pasted { forgetPaste() }
    model.selectionChanged(keys)
    showToText()
    offerConnect(keys)
  }

  /// #945: every selection PaperKit reports, with what it holds and whether a touch was heard making it.
  private func logSelection(_ selection: Set<MarkupOrderedSet.ElementID>, putBack: Bool) {
    let keys = selection.map(Self.key)
    let box = keys.compactMap { inkFrames[$0] }.reduce(CGRect.null) { $0.union($1) }
    var event: [String: Any] = [
      "action": "paper_selection", "board": model.board.id, "selected": selection.count,
      "strokes": keys.filter { inkFrames[$0] != nil }.count, "box": rect(box), "put_back": putBack,
      "in_touch": run != nil, "touch_mode": name(paper.directTouchMode),
    ]
    if run == nil { event.merge(watchState(at: box.isNull ? nil : viewSpot(box))) { $1 } }
    log.event("whiteboard", event)
  }

  /// #945: the ink's change, said with whether a touch was heard making it and what was selected; with none heard (and
  /// no Undo or Redo), what the watcher holds and what is on top where the ink changed.
  private func unheard(_ change: PaperProbe.InkChange, frames: [String: CGRect], undo: UndoManager?) -> [String: Any] {
    let undoing = undo?.isUndoing == true || undo?.isRedoing == true
    var fields: [String: Any] = [
      "in_touch": run != nil, "selected": paper.selection.count, "undoing": undoing,
      "redoing": undo?.isRedoing == true,
    ]
    guard run == nil, !undoing, !change.isEmpty else { return fields }
    let box = (change.added + change.moved.map(\.id)).compactMap { frames[$0] }.reduce(CGRect.null) { $0.union($1) }
    fields.merge(watchState(at: box.isNull ? nil : viewSpot(box))) { $1 }
    return fields
  }

  /// A box on the board, its centre in this view's points.
  private func viewSpot(_ box: CGRect) -> CGPoint {
    lines.convert(lines.spot(of: CGPoint(x: box.midX, y: box.midY)), to: view)
  }

  func paperMarkupViewControllerDidBeginDrawing(_ controller: PaperMarkupViewController) {
    run?.facts.beganDrawing = true
    // A finger drawing is only known from here. Late, it's a stroke already over, with no lift to come.
    if touchesDown > 0 { toolWentDown() }
  }

  func paperMarkupViewControllerDidChangeContentVisibleFrame(_ controller: PaperMarkupViewController) {
    showPageNumber()
    showChoice()
    placeCards()
    showPasted()
    showToText()
    showConnect()
    layRules()
    checkSeat()
    remembering?.cancel()
    remembering = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.5))
      guard !Task.isCancelled, let self else { return }
      self.rememberPlace()
      // Story 850: where the view came to rest, for Larry.
      self.model.viewRested(self.paper.contentVisibleFrame, scale: self.screenScale)
    }
  }

  // MARK: - Touches the host hands on (overrides stay in the class: PaperBoard+GhostsTaps.swift, PaperBoard+Touches.swift)

  override func fingerLifted(from start: CGPoint, to end: CGPoint, seconds: Double) {
    let column = { (spot: CGPoint) in self.lines.columnPoint(of: self.view.convert(spot, to: self.lines)) }
    model.fingerLifted(from: column(start), to: column(end), seconds: seconds)
  }

  override func fingerTapped(at spot: CGPoint, beganAt: Date) {
    // Story 968: a tap on PaperKit's menu beside a selection (Delete) is the menu's: no mark, no letting the selection go.
    if let start = run?.startView, PaperProbe.isSelectionMenu(start) {
      log.event(
        "whiteboard",
        [
          "action": "menu_tap", "board": model.board.id, "view": start, "selected": paper.selection.count,
          "ghosts": model.ghosts.count,
        ])
      return
    }
    let at = lines.columnPoint(of: view.convert(spot, to: lines))
    // Story 818: Larry hears every tap, marks showing or not.
    model.tapped(at: at, zoom: screenScale)
    let count = model.ghosts.count
    // Story 855: a margin tap is the outline's; a dot a drawing finger leaves there is taken back.
    if at.x < BoardMargin.width {
      ghostTap = TapDot(at: at, beganAt: beganAt)
      noSelectionUntil = CACurrentMediaTime() + 0.8
      return
    }
    // Story 947: with no marks showing, a tap on a group's stroke selects all of it; with it selected, a tap on its text
    // opens the words (story 940). Story 1141: one thing of Larry's outside a group, the same way. His controls showing
    // change nothing (bead context-grabber-9d1), but a tap on one is the control's (story 846): no selection, no words.
    let onControl = model.overlays.hit(at, tolerance: 4 / max(screenScale, 0.01)) != nil
    // Story 1196: inside his own selection a tap on a group, a thing of Larry's or a text is the selection's, unless the
    // selection is that one thing (then a second tap rewords, as below).
    if count == 0, !onControl, reword.editing == nil, selectionKeptTap(at: at, beganAt: beganAt) { return }
    if count == 0, !onControl, reword.editing == nil,
      let group = tappedGroup(at: at) ?? tappedTheirs(at: at)
    {
      if group.selected, rewordTapped(at: at) {
        noSelectionUntil = CACurrentMediaTime() + 0.8
        ghostTap = TapDot(at: at, beganAt: beganAt, within: PaperProbe.rewordDotSeconds)
      } else {
        select(group, tappedAt: at, beganAt: beganAt)
      }
      return
    }
    // Story 1197: the first tap on a kept text selects it, ready to drag; the second (below) opens its words.
    if count == 0, !onControl, reword.editing == nil, let text = tappedText(at: at), !text.selected {
      select(text, tappedAt: at, beganAt: beganAt)
      return
    }
    // Story 940: with no marks to choose, a tap on a selected kept text opens its words (or, with them open, is done).
    if count == 0, !onControl || reword.editing != nil, rewordTapped(at: at) {
      noSelectionUntil = CACurrentMediaTime() + 0.8
      ghostTap = TapDot(at: at, beganAt: beganAt, within: PaperProbe.rewordDotSeconds)
      return
    }
    // With his controls showing a finger taps too (story 846): no dot, no selection.
    guard count > 0 || !model.overlays.list.isEmpty else { return }
    ghostTap = TapDot(at: at, beganAt: beganAt)
    let selected = paper.selection.count
    // Story 967 (#1170): a tap on his selection that reaches no mark is his, so PaperKit's menu (Delete) shows.
    let box = selectionBox
    let onMark = model.reachesMark(at: at, zoom: screenScale)
    let onSelection = WhiteboardMarkChoice.onSelection(
      box, at: at, reach: WhiteboardTurn.tapReach / max(screenScale, 0.01), onMark: onMark)
    if !onSelection {
      noSelectionUntil = CACurrentMediaTime() + 0.8
      if selected > 0 { paper.selection = [] }
    }
    guard count > 0 else { return }
    model.tap(at: at, zoom: screenScale)
    log.event(
      "whiteboard",
      [
        "action": "paper_tap", "board": model.board.id, "at": point(at), "ghosts_before": count,
        "ghosts_after": model.ghosts.count, "chosen": model.chosen != nil, "selected_at_tap": selected,
        "selection_box": rect(box), "on_selection": onSelection,
        "touch_mode": name(paper.directTouchMode), "auto_draws": paper.directTouchAutomaticallyDraws,
        "screen_scale": Double(screenScale),
      ])
    // Story 1152: a tap off the marks and his selection gives a finger with no Pencil in use its pen back.
    fingerTappedWithMarks(onMark: onMark, onSelection: onSelection)
  }

  override func touchWentDown(_ touch: UITouch) {
    if ghostTap?.selection?.isGroup == true { ghostTap = nil }
    groupTap = nil
    reflowTouched(touch)
    selectionTouchDown(touch)
    // Story 1143: the turns logged as the touch began, so its line says how many came while it was down.
    if touchesDown == 0 { run?.turnsAtStart = model.turnsLogged }
    if touch.type == .pencil {
      toolWentDown()
      pencilTouched()
    }
    lastDown = pencilDown ? .pencil : touch.type
    toolInHand(touchTool)
    snapTouch(touch, .down, draws: touch.type == .pencil || fingersDraw)
    pathTouch(touch, .down, draws: touch.type == .pencil || fingersDraw)
    foldEraserDown(touch)
    // Story 858: any touch but the hold's own puts the menu away.
    if holdMenu != nil, grip == nil { holdMenu = nil }
    // Story 933: every try at a hold in the margin is in the log, from here to its verdict.
    let at = lines.columnPoint(of: touch.location(in: lines))
    guard model.editable, marginTry == nil || touchesDown == 0, at.x >= 0, at.x < BoardMargin.width,
      touch.type == .pencil || touch.type == .direct
    else {
      return
    }
    let tool: BoardMarginHold.Tool = touch.type == .pencil ? .pencil : .finger
    marginTry = (ObjectIdentifier(touch), tool, at.y, false)
    if tool == .pencil { roomBandPencilDown(touch, at: at) }
    log.event(
      "board_margin",
      [
        "action": "hold_began", "board": model.board.id, "tool": tool.rawValue, "x": Double(at.x), "y": Double(at.y),
        "drawing_tool": toolName,
      ])
  }

  override func touchEnded(_ touch: UITouch, cancelled: Bool, seconds: Double, travel: CGFloat) {
    roomBandPencilLifted(touch)
    guard let attempt = marginTry, attempt.touch == ObjectIdentifier(touch) else { return }
    marginTry = nil
    var event: [String: Any] = [
      "action": "hold_ended", "board": model.board.id, "tool": attempt.tool.rawValue, "y": Double(attempt.y),
      "ms": Int(seconds * 1000), "travel": Double(travel.rounded()), "cancelled": cancelled,
    ]
    switch attempt.tool {
    case .finger:
      event["verdict"] = BoardMarginHold.finger(seconds: seconds, travel: travel, recognized: attempt.held)
    case .pencil:
      // The Pencil's verdict comes from its stroke, as `hold_stroke`; none means PaperKit drew nothing for it.
      event["verdict"] = "stroke"
    }
    log.event("board_margin", event)
  }

  /// Story 886: the eraser over an answered question card takes it, from a touch that would erase ink: the Pencil, or a
  /// finger only while fingers draw. A finger that pans the board takes nothing.
  override func touchMoved(_ touch: UITouch) {
    snapTouch(touch, .moved, draws: touch.type == .pencil || fingersDraw)
    pathTouch(touch, .moved, draws: touch.type == .pencil || fingersDraw)
    foldEraserMoved(touch)
    selectionTouchMoved(touch)
    roomBandPencilMoved(touch, at: lines.columnPoint(of: touch.location(in: lines)))
    guard touchTool.erases, touch.type == .pencil || fingersDraw,
      model.questions.board.cards.contains(where: { $0.answered != nil })
    else { return }
    model.questions.erase(crossing: [lines.columnPoint(of: touch.location(in: lines))])
  }

  override func toolChanged() {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.toolInHand(self.decidingTool)
      // #1078 (story 1064): what the picker shows beside what the board holds, as each pick lands.
      self.log.event(
        "whiteboard",
        [
          "action": "tool_changed", "board": self.model.board.id, "picker_tool": self.pickerText,
          "tool": self.toolName, "tool_ink": self.toolText(self.paper.drawingTool),
        ])
    }
  }

  /// PaperKit says when drawing begins and not when it ends: this is the touch going. A palm left down doesn't hold it.
  override func touchLifted(_ touch: UITouch, down: Int) {
    snapTouch(touch, .lifted, draws: touch.type == .pencil || fingersDraw)
    pathTouch(touch, .lifted, draws: touch.type == .pencil || fingersDraw)
    foldEraserLifted(touch)
    guard toolDown, touch.type == .pencil || down == 0 else { return }
    toolDown = false
    model.endedDrawing()
  }

  // MARK: - The log

  /// Story 1311: how fast the board answers the Pencil (`PaperBoard+PenLatency.swift`).
  override func penLatencyLine(_ line: PenLatency.Summary, hz: Int) { logPenLatency(line, hz: hz) }

  /// What a finger does on paper isn't settled (the spec's "On paper"): this line says which it was, Pencil or finger,
  /// and what came of it, so the iPad's next log can settle it. `touch_type`, as `type` is the event's own.
  override func touchEnded(_ run: TouchRun, visible: CGRect, zoom: CGFloat, dx: CGFloat, dy: CGFloat) {
    log.event(
      "whiteboard",
      [
        "action": "paper_touch", "board": model.board.id, "touch_type": run.tally.type ?? run.type,
        "touch_types": run.tally.types, "finger_radius": round(run.tally.fingerRadius),
        "gesture": PaperProbe.gesture(run.facts), "outcome": PaperProbe.outcome(run.facts),
        "travel": round(run.facts.travel), "fingers": run.facts.fingers, "seconds": seconds(run.facts.seconds),
        "scroll_dx": round(dx), "scroll_dy": round(dy), "zoom_from": Double(run.zoomAtStart), "zoom_to": Double(zoom),
        "selected": run.selected, "selection_changes": run.facts.selectionChanges, "ink_added": run.facts.inkAdded,
        "ink_moved": run.facts.inkMoved, "ink_removed": run.facts.inkRemoved, "began_drawing": run.facts.beganDrawing,
        "page_added_during": run.pageAdded, "tool": run.tool, "tool_ink": run.ink, "picker_tool": run.picker,
        "touch_mode": name(paper.directTouchMode),
        "auto_draws": paper.directTouchAutomaticallyDraws, "pages": pages,
        "page": board.page(at: CGPoint(x: 0, y: visible.midY)), "ghosts": model.ghosts.count,
        "ghost_slip": round(seat.worst), "ghost_checks": seat.checks, "pinch_held": run.pinchHeld ?? "",
        "pinches_held": run.pinchesHeld,
      ].merging(touchAudit(run)) { $1 })
    seat = (0, 0)
  }
}

extension PaperBoardController: UIGestureRecognizerDelegate {
  /// The hold watches beside PaperKit's own gestures, never instead of them.
  nonisolated func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
  ) -> Bool { true }
}

/// What a board's paper is ruled with. A board has one or none.
enum PaperRules { case none, grid, ruled }

/// The canvas the model asks for its changes to the ink: each one the controller's own, as it was.
extension PaperBoardController: BoardCanvas {
  var visibleRect: CGRect { paperOnScreen }
  var zoom: CGFloat { screenScale }

  func draw(_ strokes: [PKStroke], named name: String) -> Bool {
    let laidOut = paper.markup != nil
    keep(strokes, named: name)
    return laidOut
  }

  func apply(_ batch: BoardOps.Batch) -> BoardCanvasOutcome { applyOps(batch) }
  func landPaste(_ strokes: [PKStroke]) -> Bool { land(paste: strokes) }

  func keepMakingRoom(_ strokes: [PKStroke], push: BoardRoom.Push, why: String) -> Bool {
    keep(strokes, making: push, why: why)
  }

  func changeOutline(named label: @autoclosure () -> String, _ change: (inout BoardOutline) -> Bool) -> Bool {
    changeOutline(label(), on: nil, undoTo: nil, change)
  }

  func moveStrokes(_ moves: [Int: CGFloat]) -> Bool {
    let laidOut = paper.markup != nil
    move(moves)
    return laidOut
  }

  func showOverlays(_ list: [BoardOverlay]) {
    lines.showOverlays(list)
    // Story 846: with his controls showing, a finger taps them, as it taps ghosts, rather than drawing.
    fingerTaps(marks: !model.ghosts.isEmpty, controls: !list.isEmpty)
  }

  func menuChose() { takeTheResponderBack() }
  func pressedUndo(redo: Bool) { pressUndo(redo: redo) }
}
