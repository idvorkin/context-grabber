//  A board on paper (whiteboard spec's "On paper: the default", stories 590–657, 658; #636): PaperKit's controller, which
//  can't be subclassed, held in `PaperHost` with the page lines, the tool picker and the touch log; and on it
//  `PaperBoardController`, which draws on a board through its model, so it saves and syncs, with its ghosts, Larry's
//  marks, the mic and paste. A look-only board (another device's, or one drawn on the old canvas) shows the same way with
//  drawing off and no tools. Ghosts lie on the sheet under the ink, in
//  PaperKit's content view, so they move with the board whatever it does.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI
import UIKit.UIGestureRecognizerSubclass
import UniformTypeIdentifiers

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

/// PaperKit's controller and what goes with it on any board: a see-through canvas over the paper and its lines, the tool
/// picker, the pinch's floor at the page's width, and what each touch did.
@MainActor
class PaperHost: UIViewController {
  /// One touch, first down to last up, and what came of it.
  struct TouchRun {
    var type: String
    var began: Double
    var start: CGPoint
    var visibleAtStart: CGRect
    var zoomAtStart: CGFloat
    var tool: String
    var facts = PaperProbe.TouchFacts()
    var selected = 0
    var frames = 0
    var maxGap: Double = 0
    var pageAdded = false

    var kind: String { "\(type)_down" }
  }

  let paper: PaperMarkupViewController
  let lines: PaperLines
  /// Held here: the tool picker disappears when nothing keeps it.
  private let picker = PKToolPicker()
  private let watcher = PaperTouchWatcher()
  private(set) var boardPaper: BoardPaper
  var paperColor: UIColor { boardPaper.color }
  /// False on a look-only board: nothing draws, and there's no tool picker; a finger still pans and pinches.
  var drawsHere = true

  private(set) var touchesDown = 0
  private(set) var pencilDown = false
  var run: TouchRun?
  private var runEnding: Task<Void, Never>?
  private var touchStarts: [ObjectIdentifier: (at: CGPoint, began: Double, farthest: CGFloat)] = [:]
  /// Fingers on the glass now, and together since the last time there were none. A Pencil beside one doesn't count.
  private var fingersDown = 0
  private var fingersTogether = 0
  private(set) var lastTouchBoardPoint: CGPoint?

  private static let features: FeatureSet = {
    var set = FeatureSet.empty
    set.contentVersion = .latest
    set.insert(.drawing)
    set.inks = [.pen, .pencil, .marker, .monoline, .fountainPen, .watercolor, .crayon, .reed]
    return set
  }()

  init(boardPaper: BoardPaper) {
    self.boardPaper = boardPaper
    paper = PaperMarkupViewController(markup: nil, supportedFeatureSet: Self.features)
    lines = PaperLines(paper: boardPaper.color)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = paperColor
    addChild(paper)
    paper.view.frame = view.bounds
    paper.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // A see-through canvas, the paper and its lines beneath the ink.
    paper.view.backgroundColor = .clear
    paper.view.isOpaque = false
    view.addSubview(paper.view)
    paper.didMove(toParent: self)
    paper.contentView = lines
    paper.isEditable = drawsHere
    watcher.changed = { [weak self] touch, phase, down in self?.touched(touch, phase, down: down) }
    view.addGestureRecognizer(watcher)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    guard drawsHere else { return }
    picker.addObserver(paper)
    paper.pencilKitResponderState.activeToolPicker = picker
    paper.pencilKitResponderState.toolPickerVisibility = .visible
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    guard drawsHere else { return }
    paper.pencilKitResponderState.toolPickerVisibility = .hidden
    picker.removeObserver(paper)
  }

  func setBoardPaper(_ new: BoardPaper) {
    guard new != boardPaper else { return }
    boardPaper = new
    let color = new.color
    view.backgroundColor = color
    lines.backgroundColor = color
  }

  /// What zoom means is read off the screen, then the pinch's floor is the page's width. The caller puts the view back.
  @discardableResult
  func fit(columnWidth: CGFloat) -> CGFloat {
    let config = paper.scrollConfiguration
    config.bounces = .vertical
    config.visibleScrollIndicators = .vertical
    paper.zoomRange = 0.05...4
    config.zoomScale = 1
    paper.view.layoutIfNeeded()
    let fit =
      BoardPages.fitZoom(visibleWidth: paper.contentVisibleFrame.width, atZoom: config.zoomScale, column: columnWidth)
      ?? 1
    paper.zoomRange = fit...max(3, fit)
    config.zoomScale = fit
    paper.view.layoutIfNeeded()
    return fit
  }

  // MARK: - Touches

  private func touched(_ touch: UITouch, _ phase: PaperTouchWatcher.Phase, down: Int) {
    let at = touch.location(in: view)
    let id = ObjectIdentifier(touch)
    switch phase {
    case .began:
      if touchesDown == 0 {
        // A menu leaves nothing the first responder when it closes, and with that PaperKit drew no stroke and showed no tool
        // picker (3 of 3 on the simulator, iOS 27).
        if !paper.isFirstResponder { paper.becomeFirstResponder() }
        runEnding?.cancel()
        endRun()
        startRun(touch, at: at)
      }
      touchStarts[id] = (at, CACurrentMediaTime(), 0)
      if touch.type == .pencil { pencilDown = true }
      if touch.type == .direct {
        fingersDown += 1
        fingersTogether += 1
      }
      touchWentDown(touch)
    case .moved:
      if let start = touchStarts[id] {
        let went = hypot(at.x - start.at.x, at.y - start.at.y)
        touchStarts[id]?.farthest = max(start.farthest, went)
        if let travel = run?.facts.travel { run?.facts.travel = max(travel, went) }
      }
    case .ended, .cancelled:
      // Short, still and alone, whatever a Pencil is doing beside it. The system calling a touch off, as it does a palm, is
      // no tap.
      if phase == .ended, touch.type == .direct, let start = touchStarts[id],
        PaperProbe.isFingerTap(
          travel: max(start.farthest, hypot(at.x - start.at.x, at.y - start.at.y)),
          seconds: CACurrentMediaTime() - start.began,
          fingers: fingersTogether)
      {
        fingerTapped(at: start.at)
      }
      touchStarts[id] = nil
      if touch.type == .pencil { pencilDown = false }
      if touch.type == .direct {
        fingersDown = max(fingersDown - 1, 0)
        if fingersDown == 0 { fingersTogether = 0 }
      }
    }
    touchesDown = down
    if let fingers = run?.facts.fingers { run?.facts.fingers = max(fingers, down) }
    if phase == .ended || phase == .cancelled { touchLifted(touch, down: down) }
    if phase == .ended || phase == .cancelled, down == 0 {
      if let began = run?.began { run?.facts.seconds = CACurrentMediaTime() - began }
      // A pan's coasting and a selection's arrival come after the lift.
      runEnding = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(0.6))
        guard !Task.isCancelled else { return }
        self?.endRun()
      }
    }
  }

  private func startRun(_ touch: UITouch, at: CGPoint) {
    let visible = paper.contentVisibleFrame
    let scale = visible.width / max(view.bounds.width, 1)
    lastTouchBoardPoint = CGPoint(x: visible.minX + at.x * scale, y: visible.minY + at.y * scale)
    run = TouchRun(
      type: Self.name(touch.type), began: CACurrentMediaTime(), start: at, visibleAtStart: visible,
      zoomAtStart: paper.scrollConfiguration.zoomScale, tool: toolName)
  }

  /// The view closing: a touch still being watched goes in the log now.
  func finishTouches() {
    runEnding?.cancel()
    endRun()
  }

  private func endRun() {
    guard var run else { return }
    self.run = nil
    let visible = paper.contentVisibleFrame
    let zoom = paper.scrollConfiguration.zoomScale
    let (dx, dy) = (visible.minX - run.visibleAtStart.minX, visible.minY - run.visibleAtStart.minY)
    run.facts.scrolled = hypot(dx, dy)
    run.facts.zoomChanged = abs(zoom - run.zoomAtStart) > 0.001
    touchEnded(run, visible: visible, zoom: zoom, dx: dx, dy: dy)
  }

  func touchWentDown(_ touch: UITouch) {}
  func touchLifted(_ touch: UITouch, down: Int) {}
  /// One finger, short and staying put, at this spot in `view`, Pencil or no Pencil. PaperKit may do its own thing with the
  /// same touch.
  func fingerTapped(at spot: CGPoint) {}

  /// What a touch came to, for the log.
  func touchEnded(_ run: TouchRun, visible: CGRect, zoom: CGFloat, dx: CGFloat, dy: CGFloat) {}

  // MARK: - The log's words

  var toolName: String {
    switch paper.drawingTool {
    case let ink as PKInkingTool: return ink.inkType.rawValue
    case is PKEraserTool: return "eraser"
    case is PKLassoTool: return "lasso"
    default: return String(describing: type(of: paper.drawingTool))
    }
  }

  func name(_ mode: PaperMarkupViewController.TouchMode) -> String {
    mode == .selection ? "selection" : "drawing"
  }

  static func name(_ type: UITouch.TouchType) -> String {
    switch type {
    case .direct: return "finger"
    case .pencil: return "pencil"
    case .indirect: return "indirect"
    case .indirectPointer: return "pointer"
    @unknown default: return "other"
    }
  }

  nonisolated static func key(_ id: MarkupOrderedSet.ElementID) -> String {
    if case .stroke(let uuid) = id { return uuid.uuidString }
    return String(describing: id)
  }

  func round(_ value: CGFloat) -> Double { (Double(value) * 10).rounded() / 10 }
  func ms(_ seconds: Double) -> Int { Int((seconds * 1000).rounded()) }
  func seconds(_ value: Double) -> Double { (value * 100).rounded() / 100 }
  func point(_ p: CGPoint) -> [Double] { [round(p.x), round(p.y)] }
  func insets(_ i: UIEdgeInsets) -> [Double] { [round(i.top), round(i.left), round(i.bottom), round(i.right)] }

  func rect(_ r: CGRect) -> [Double] {
    r.isNull || r.isInfinite ? [] : [round(r.minX), round(r.minY), round(r.width), round(r.height)]
  }
}

/// A real board on paper, drawn on this device. The drawing goes through the board's model, as the old canvas's does.
@MainActor
final class PaperBoardController: PaperHost, ObservableObject, PaperMarkupViewController.Delegate {
  @Published private(set) var pageText = BoardPages().pageText(visibleMidY: 0, pages: 1)

  private let model: WhiteboardModel
  private let log: SessionLog
  /// A page wide, or wider for an old-canvas board's wider ink (story 658).
  private var board = BoardPages()
  private var pages = 1
  private var laidWidth: CGFloat = 0
  /// What the column's own changes shouldn't report as a person's.
  private var quiet = false
  private var inkFrames: [String: CGRect] = [:]
  private var saidNotInk = false
  private var remembering: Task<Void, Never>?
  private var redrawing: Task<Void, Never>?
  private var responding: Task<Void, Never>?
  private var rules = PaperRules.none
  private var rulesLaid: (rules: PaperRules, pages: Int, step: CGFloat, y: ClosedRange<CGFloat>)?
  /// The window this board made light, and how it was.
  private var lightWindow: (window: UIWindow, style: UIUserInterfaceStyle)?
  /// A Pencil or a drawing finger is down, as the pacer was told.
  private var toolDown = false
  /// What a finger does when no ghost shows; set while they do, as it taps and doesn't draw.
  private var fingerUsually: (mode: PaperMarkupViewController.TouchMode, autoDraws: Bool)?
  /// A tap's selection comes after the lift: until this time one is put straight back.
  private var noSelectionUntil: Double = 0
  /// How far a ghost's place on the sheet was from where the visible frame says, over this touch, and how many looks
  /// that took. For the iPad: the spec's "A ghost sits on the paper".
  private var seat = (worst: CGFloat(0), checks: 0)
  private var pressedForTests = false
  private var movedForTests = false
  /// The undo stack a kept mark's steps went on. A closing view may no longer be able to say.
  private weak var stepsOn: UndoManager?

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
    model.visibleRect = { [weak self] in self?.paperOnScreen ?? .null }
    model.pasteReach = board.pasteReach
    model.zoom = { [weak self] in self?.screenScale ?? 1 }
    model.draw = { [weak self] _, added in self?.keep(added) }
    model.menuChose = { [weak self] in self?.takeTheResponderBack() }
  }

  /// The part of the column on screen: the visible frame runs past the paper where a phone's one page is shorter than the
  /// screen, and at a side.
  private var paperOnScreen: CGRect {
    let visible = paper.contentVisibleFrame
    let onPaper = visible.intersection(board.bounds(pages: pages))
    return onPaper.isNull || onPaper.isEmpty ? visible : onPaper
  }

  /// Screen points to a board point, whatever PaperKit's zoom scale means.
  private var screenScale: CGFloat {
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
      // #845: whether an opened board's ink is drawn, on every device's geometry.
      if first, let ink = self.paper.markup?.inkDrawing, !ink.strokes.isEmpty {
        self.lookForInk(ink.bounds, why: "open")
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    paper.becomeFirstResponder()
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
    var drawing = model.drawing
    if model.oldCanvas {
      // Story 658: the old canvas put ink about 10,000 points from its corner. Moved, never scaled, to the first page's
      // corner for showing only: a look-only board saves nothing, so its file keeps the ink where it was.
      let placed = BoardPages.placing(ink: drawing.strokes.isEmpty ? nil : drawing.bounds)
      board = placed.board
      drawing = drawing.transformed(using: placed.transform)
    }
    pages = board.pagesNeeded(inkMaxY: drawing.strokes.isEmpty ? nil : drawing.bounds.maxY)
    var markup = PaperMarkup(bounds: board.bounds(pages: pages))
    markup.append(contentsOf: drawing)
    quiet = true
    paper.markup = markup
    quiet = false
    inkFrames = paper.markup?.strokeFrames ?? [:]
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

  private func showLines() {
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
  private func takeTheResponderBack() {
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
    }
  }

  /// The sheet changed under the ink, which must not lose it: `paper_ink_look` says if it did.
  private func lookAfterChange() {
    guard let ink = paper.markup?.inkDrawing, !ink.strokes.isEmpty else { return }
    lookForInk(ink.bounds, why: "sheet")
  }

  /// The grid or ruled lines for a screen above and below the view, so they're laid again only now and then in a scroll, and
  /// when the zoom thins them or a page is added.
  private func layRules() {
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

  private func showPageNumber() {
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
    let frames = markup.strokeFrames
    let change = PaperProbe.inkChange(before: inkFrames, after: frames)
    inkFrames = frames
    run?.facts.inkAdded += change.added.count
    run?.facts.inkMoved += change.moved.count
    run?.facts.inkRemoved += change.removed.count
    if !saidNotInk, markup.subelements.count != frames.count {
      // Only strokes are saved, and the tools offered only make strokes: this says if that ever stops being true.
      saidNotInk = true
      log.event(
        "whiteboard",
        [
          "action": "paper_not_ink", "board": model.board.id, "elements": markup.subelements.count,
          "strokes": frames.count,
        ])
    }
    let drawing = markup.inkDrawing
    model.changed(drawing)
    if change.added.count > 0 {
      pressSoonForTests()
      goToPageSoonForTests()
    }
    // An undo can take back a page added earlier: the count follows what the markup holds.
    pages = board.pages(in: markup.bounds)
    let wanted = board.pages(
      after: pages, inkMaxY: drawing.strokes.isEmpty ? nil : drawing.bounds.maxY,
      redoWaiting: controller.undoManager?.canRedo ?? false)
    log.event(
      "whiteboard",
      [
        "action": "paper_ink", "board": model.board.id, "strokes": frames.count, "pages": pages, "wanted": wanted,
        "added": change.added.count, "moved": change.moved.count, "removed": change.removed.count,
        "can_undo": controller.undoManager?.canUndo ?? false, "can_redo": controller.undoManager?.canRedo ?? false,
        "ms": ms(CACurrentMediaTime() - started),
      ])
    showLines()
    showPageNumber()
    // Not from inside PaperKit's own callback.
    if wanted > pages { Task { @MainActor [weak self] in self?.grow(to: wanted) } }
  }

  /// The markup's bounds are the only way PaperKit's interface has to change the column. On Igor's iPad, 2026-11-03, a
  /// page added like this kept a stroke under way under the Pencil, and the view where it was.
  private func grow(to wanted: Int) {
    guard wanted > pages, var markup = paper.markup else { return }
    markup.bounds = board.bounds(pages: wanted)
    quiet = true
    paper.markup = markup
    quiet = false
    pages = wanted
    run?.pageAdded = true
    showLines()
    showPageNumber()
    redrawSoon()
  }

  func paperMarkupViewControllerDidChangeSelection(_ controller: PaperMarkupViewController) {
    run?.facts.selectionChanges += 1
    run?.selected = controller.selection.count
    if !controller.selection.isEmpty, CACurrentMediaTime() < noSelectionUntil { controller.selection = [] }
  }

  func paperMarkupViewControllerDidBeginDrawing(_ controller: PaperMarkupViewController) {
    run?.facts.beganDrawing = true
    // A finger drawing is only known from here. Late, it's a stroke already over, with no lift to come.
    if touchesDown > 0 { toolWentDown() }
  }

  func paperMarkupViewControllerDidChangeContentVisibleFrame(_ controller: PaperMarkupViewController) {
    showPageNumber()
    layRules()
    checkSeat()
    remembering?.cancel()
    remembering = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.5))
      guard !Task.isCancelled else { return }
      self?.rememberPlace()
    }
  }

  // MARK: - Ghosts

  /// The ghosts on the sheet, and a finger that taps while they show.
  func show(_ ghosts: [Ghost]) {
    guard lines.ghostLayers.show(ghosts) else { return }
    fingerTaps(!ghosts.isEmpty)
    let drawn = ghosts.flatMap(\.lines)
    log.event(
      "whiteboard",
      [
        "action": "paper_ghosts", "board": model.board.id, "count": ghosts.count,
        "past_side": board.reachesPastSide(drawn), "pages": pages, "visible": rect(paper.contentVisibleFrame),
        "sheet": rect(lines.bounds),
        "screen_scale": Double(screenScale),
      ])
    checkSeat()
  }

  /// As the old canvas's `.pencilOnly`, which PaperKit doesn't have: a finger selects rather than draws, and a tap's
  /// selection is put straight back, so a tap leaves nothing.
  private func fingerTaps(_ taps: Bool) {
    if taps, fingerUsually == nil {
      fingerUsually = (paper.directTouchMode, paper.directTouchAutomaticallyDraws)
      paper.directTouchAutomaticallyDraws = false
      paper.directTouchMode = .selection
    } else if !taps, let usual = fingerUsually {
      fingerUsually = nil
      paper.directTouchMode = usual.mode
      paper.directTouchAutomaticallyDraws = usual.autoDraws
    }
  }

  /// Where the sheet has a ghost against where the visible frame says it should be, in screen points.
  private func checkSeat() {
    guard let point = model.ghosts.first?.lines.first?.first else { return }
    let visible = paper.contentVisibleFrame
    let onSheet = lines.convert(lines.spot(of: point), to: view)
    let scale = screenScale
    let framed = CGPoint(x: (point.x - visible.minX) * scale, y: (point.y - visible.minY) * scale)
    seat.worst = max(seat.worst, hypot(onSheet.x - framed.x, onSheet.y - framed.y))
    seat.checks += 1
  }

  override func fingerTapped(at spot: CGPoint) {
    let count = model.ghosts.count
    guard count > 0 else { return }
    let at = lines.columnPoint(of: view.convert(spot, to: lines))
    noSelectionUntil = CACurrentMediaTime() + 0.8
    let selected = paper.selection.count
    if selected > 0 { paper.selection = [] }
    model.tap(at: at, zoom: screenScale)
    log.event(
      "whiteboard",
      [
        "action": "paper_tap", "board": model.board.id, "at": point(at), "ghosts_before": count,
        "ghosts_after": model.ghosts.count, "selected_at_tap": selected, "screen_scale": Double(screenScale),
      ])
  }

  // MARK: - Paste

  /// ⌘V, ahead of whatever PaperKit's own views would do with it.
  override var keyCommands: [UIKeyCommand]? {
    let key = UIKeyCommand(input: "v", modifierFlags: .command, action: #selector(pasteKeyPressed))
    key.wantsPriorityOverSystemBehavior = true
    return (super.keyCommands ?? []) + [key]
  }

  @objc private func pasteKeyPressed() { paste(from: "key") }

  /// Text is ink, in the middle of the view. Copied strokes are PaperKit's to place if it will, and landed here if not: nothing
  /// on the simulator takes them, and whether the iPad's PaperKit does is what this line will say. Only a picture is refused: only
  /// strokes are saved, so one on the sheet would go when he left. Strokes first, as a copy may hold a picture of them too. hasStrings
  /// asks without reading, so no prompt shows for nothing. (The spec's "Paste on paper".)
  private func paste(from how: String) {
    let clipboard = UIPasteboard.general
    var event: [String: Any] = [
      "action": "paper_paste", "board": model.board.id, "how": how, "has_text": clipboard.hasStrings,
      "has_image": clipboard.hasImages, "types": Array(clipboard.types.prefix(8)),
      "strokes_before": model.drawing.strokes.count,
    ]
    defer { log.event("whiteboard", event) }
    if clipboard.hasStrings, let text = clipboard.string {
      event["went"] = "ink"
      model.paste(text)
      return
    }
    let copied = copiedStrokes(clipboard)
    if copied == nil, clipboard.hasImages {
      event["went"] = "refused_picture"
      return
    }
    let paste = #selector(UIResponderStandardEditActions.paste(_:))
    let took = UIApplication.shared.sendAction(paste, to: nil, from: self, for: nil)
    if took {
      event["went"] = "paperkit"
    } else if let copied {
      event["went"] = "landed_here"
      event["strokes"] = copied.count
      model.paste(strokes: moved(copied))
    } else {
      event["went"] = "nobody"
    }
  }

  private func copiedStrokes(_ clipboard: UIPasteboard) -> [PKStroke]? {
    if let data = clipboard.data(forPasteboardType: UTType.paperkit.identifier),
      let markup = try? PaperMarkup(dataRepresentation: data), !markup.subelements.strokes.isEmpty
    {
      return markup.inkDrawing.strokes
    }
    if let data = clipboard.data(forPasteboardType: PKAppleDrawingTypeIdentifier as String),
      let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty
    {
      return drawing.strokes
    }
    return nil
  }

  private func moved(_ strokes: [PKStroke]) -> [PKStroke] {
    let shift = board.pasteShift(ink: PKDrawing(strokes: strokes).bounds, visible: paperOnScreen)
    let by = CGAffineTransform(translationX: shift.dx, y: shift.dy)
    return strokes.map {
      PKStroke(
        ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(by), mask: $0.mask,
        randomSeed: $0.randomSeed)
    }
  }

  /// `GRABBER_WHITEBOARD_AFTER_INK=copy,paste`: those, 2 s apart from a second after the first ink, for the simulator: it
  /// can't work the lasso, and keys reach only a run's first test. Copy selects all the ink and copies, as the lasso's does.
  private func pressSoonForTests() {
    guard !pressedForTests, let presses = LaunchHooks.current.whiteboard.afterInk else { return }
    pressedForTests = true
    Task { @MainActor [weak self] in
      for press in presses {
        try? await Task.sleep(for: .seconds(1))
        if press == "paste" {
          self?.paste(from: "hook")
        } else {
          await self?.copyAllForTests()
        }
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  /// `GRABBER_WHITEBOARD_PAGE_AFTER_INK=<page>`: a second after the first ink, the view goes to that page's top (as far as
  /// the column lets it), for the simulator: a finger draws there and XCUITest has no two-finger drag (stories 433, 522).
  private func goToPageSoonForTests() {
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

  /// A kept mark into the markup, and any page it needs in the same change: one undo takes them both. PaperKit registers no
  /// undo for a markup that's set: left to itself, the next undo took back the stroke before the kept mark, and the mark
  /// stayed (the simulator, iOS 27, 2026-11-03). Its own steps go on working after this, as the elements keep their ids.
  private func keep(_ strokes: [PKStroke]) {
    let started = CACurrentMediaTime()
    guard var markup = paper.markup else {
      // Not laid out yet: the load takes the model's drawing, with this in it.
      log.event("whiteboard", ["action": "paper_keep", "board": model.board.id, "no_markup": true])
      return
    }
    let undo = paper.undoManager
    let (couldUndo, couldRedo) = (undo?.canUndo ?? false, undo?.canRedo ?? false)
    let wanted = board.pages(after: pages, inkMaxY: model.drawing.bounds.maxY, redoWaiting: false)
    let made = PKDrawing(strokes: strokes)
    registerStepBack(to: markup)
    if wanted > pages { markup.bounds = board.bounds(pages: wanted) }
    markup.append(contentsOf: made)
    quiet = true
    paper.markup = markup
    quiet = false
    let pagesBefore = pages
    pages = wanted
    run?.pageAdded = wanted > pagesBefore
    showLines()
    showPageNumber()
    redrawSoon()
    let held = paper.markup ?? markup
    inkFrames = held.strokeFrames
    let whole = held.inkDrawing
    model.settled(whole)
    // The names Larry knows them by, from the mark as made and as PaperKit gives it back: the spec's "Larry knows a kept
    // mark as one stroke".
    let back = PKDrawing(strokes: Array(whole.strokes.suffix(strokes.count)))
    let idsMade = WhiteboardModel.strokesForLarry(made).map(\.id)
    let idsBack = WhiteboardModel.strokesForLarry(back).map(\.id)
    log.event(
      "whiteboard",
      [
        "action": "paper_keep", "board": model.board.id, "strokes": strokes.count, "total": whole.strokes.count,
        "pages_before": pagesBefore, "pages": wanted, "same_ids": idsMade == idsBack, "ids_made": idsMade.count,
        "ids_back": idsBack.count, "ink": rect(made.bounds), "visible": rect(paper.contentVisibleFrame),
        "sheet": rect(lines.bounds), "markup": rect(held.bounds),
        "drift": round(hypot(made.bounds.minX - back.bounds.minX, made.bounds.minY - back.bounds.minY)),
        "could_undo": couldUndo, "could_redo": couldRedo, "can_undo": undo?.canUndo ?? false,
        "can_redo": undo?.canRedo ?? false, "undo_on_window": undo != nil && undo === view.window?.undoManager,
        "ms": ms(CACurrentMediaTime() - started),
      ])
    undoSoonForTests()
    lookForInk(made.bounds, why: "kept")
  }

  /// PaperKit sometimes never draws a markup that's set: the ink is held and counted, and the tile it falls on stays empty,
  /// whatever is set or scrolled after. A change of zoom draws it. On the simulator, iOS 27: 15 of 180 pastes without this, 0 of
  /// 60 with it, and a zoom brought back each of the 7 in the run that tried one. A set that opens a board is followed by a
  /// zoom anyway, the fit. So the zoom moves too little to see and back, with the touches done and the view at rest.
  /// ponytail: works around a miss inside PaperKit, unseen on a real device so far; drop it if `paper_ink_look` shows the iOS
  /// it's built for no longer misses without it.
  private func redrawSoon() {
    redrawing?.cancel()
    redrawing = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.2))
      var seen: CGRect?
      while !Task.isCancelled, let self, self.touchesDown > 0 || self.paper.contentVisibleFrame != seen {
        seen = self.paper.contentVisibleFrame
        try? await Task.sleep(for: .seconds(0.1))
      }
      guard let self, !Task.isCancelled else { return }
      let config = self.paper.scrollConfiguration
      let (zoom, place) = (config.zoomScale, self.paper.contentVisibleFrame)
      let range = self.paper.zoomRange
      let nudged = zoom * (zoom < range.upperBound ? 1.002 : 0.998)
      // #829: with the page narrower than the screen PaperKit centres it (the view starts left of the page), and a zoom
      // set there recursed inside PaperKit until the stack ran out: zoom 1.017 at the bottom of 1.017...3, asked 1.019, on
      // an iPad simulator. Centred, the zoom is left alone and the view moves instead (#833).
      let centred = place.minX < 0
      self.log.event(
        "whiteboard",
        [
          "action": "paper_redraw_nudge", "board": self.model.board.id, "zoom": zoom, "to": nudged,
          "range_lo": range.lowerBound, "range_hi": range.upperBound, "visible": self.rect(place),
          "how": centred ? "frame" : "zoom",
        ])
      if centred {
        // #833: centred, a point down and back instead, which draws the missed tile without setting the zoom.
        self.paper.contentVisibleFrame = place.offsetBy(dx: 0, dy: 1)
        try? await Task.sleep(for: .seconds(0.05))
        if self.touchesDown == 0 { self.paper.contentVisibleFrame = place }
        return
      }
      config.zoomScale = nudged
      try? await Task.sleep(for: .seconds(0.05))
      config.zoomScale = zoom
      if self.touchesDown == 0 { self.paper.contentVisibleFrame = place }
    }
  }

  /// A second after ink is kept or pasted or the sheet changes under it, whether the view's own picture has it. 0 with the
  /// ink in view is the ink missing.
  private func lookForInk(_ ink: CGRect, why: String) {
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self, let markup = self.paper.markup else { return }
      let corner = self.lines.convert(self.lines.spot(of: ink.origin), to: self.view)
      let scale = self.screenScale
      let spot = CGRect(x: corner.x, y: corner.y, width: ink.width * scale, height: ink.height * scale)
      self.log.event(
        "whiteboard",
        [
          "action": "paper_ink_look", "why": why, "board": self.model.board.id, "ink": self.rect(ink),
          "spot": self.rect(spot),
          "in_view": self.view.bounds.contains(spot), "strokes": markup.subelements.strokes.count,
          "visible": self.rect(self.paper.contentVisibleFrame), "shown_px": self.shownPixels(in: spot),
        ])
    }
  }

  /// Pixels unlike the paper in this view's own picture of itself, in a part of it.
  private func shownPixels(in spot: CGRect) -> Int {
    let box = spot.intersection(view.bounds)
    guard !box.isNull, !box.isEmpty else { return -1 }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let picture = UIGraphicsImageRenderer(size: box.size, format: format).image { _ in
      let whole = CGRect(origin: CGPoint(x: -box.minX, y: -box.minY), size: view.bounds.size)
      view.drawHierarchy(in: whole, afterScreenUpdates: false)
    }
    guard let cg = picture.cgImage else { return -1 }
    var (r, g, b): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
    paperColor.resolvedColor(with: traitCollection).getRed(&r, green: &g, blue: &b, alpha: nil)
    let paper = [Int(r * 255), Int(g * 255), Int(b * 255)]
    let (w, h) = (cg.width, cg.height)
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
      guard
        let context = CGContext(
          data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
      return true
    }
    guard drawn else { return -1 }
    return stride(from: 0, to: bytes.count, by: 4).filter { i in
      (0..<3).contains { abs(Int(bytes[i + $0]) - paper[$0]) > 40 }
    }.count
  }

  /// Undo or redo of a kept mark: back to the markup as it was, and the way forward again the same way.
  private func registerStepBack(to markup: PaperMarkup) {
    guard let undo = paper.undoManager else { return }
    stepsOn = undo
    undo.registerUndo(withTarget: self) { controller in
      MainActor.assumeIsolated { controller.step(to: markup) }
    }
  }

  /// The board really closed, which a cancelled swipe back isn't: the stack can be the window's, and the next board's Undo
  /// mustn't reach this one's steps.
  func boardClosed() {
    guard let stepsOn else { return }
    stepsOn.removeAllActions(withTarget: self)
    log.event(
      "whiteboard",
      [
        "action": "paper_undo_closed", "board": model.board.id, "can_undo": stepsOn.canUndo,
        "can_redo": stepsOn.canRedo,
      ])
  }

  private func step(to markup: PaperMarkup) {
    if let now = paper.markup { registerStepBack(to: now) }
    quiet = true
    paper.markup = markup
    quiet = false
    pages = board.pages(in: markup.bounds)
    inkFrames = markup.strokeFrames
    model.stepped(markup.inkDrawing)
    showLines()
    showPageNumber()
    log.event(
      "whiteboard",
      [
        "action": "paper_step", "board": model.board.id, "strokes": inkFrames.count, "pages": pages,
        "can_undo": paper.undoManager?.canUndo ?? false, "can_redo": paper.undoManager?.canRedo ?? false,
      ])
    redrawSoon()
  }

  /// `GRABBER_WHITEBOARD_AFTER_KEEP=<seconds>,undo,redo,...`: those presses after a keep, 3 s apart, for the simulator: a
  /// phone's tool picker has no Undo, and keys reach only a run's first test.
  private func undoSoonForTests() {
    guard let hook = LaunchHooks.current.whiteboard.afterKeep else { return }
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

  /// The word to the pacer: the Pencil touching down, or a finger once it's seen to be drawing.
  private func toolWentDown() {
    guard !toolDown else { return }
    toolDown = true
    model.beganDrawing()
  }

  override func touchWentDown(_ touch: UITouch) {
    if touch.type == .pencil { toolWentDown() }
  }

  /// PaperKit says when drawing begins and not when it ends: this is the touch going. A palm left down doesn't hold it.
  override func touchLifted(_ touch: UITouch, down: Int) {
    guard toolDown, touch.type == .pencil || down == 0 else { return }
    toolDown = false
    model.endedDrawing()
  }

  // MARK: - The log

  /// What a finger does on paper isn't settled (the spec's "On paper"): this line says which it was, Pencil or finger,
  /// and what came of it, so the iPad's next log can settle it. `touch_type`, as `type` is the event's own.
  override func touchEnded(_ run: TouchRun, visible: CGRect, zoom: CGFloat, dx: CGFloat, dy: CGFloat) {
    log.event(
      "whiteboard",
      [
        "action": "paper_touch", "board": model.board.id, "touch_type": run.type,
        "gesture": PaperProbe.gesture(run.facts), "outcome": PaperProbe.outcome(run.facts),
        "travel": round(run.facts.travel), "fingers": run.facts.fingers, "seconds": seconds(run.facts.seconds),
        "scroll_dx": round(dx), "scroll_dy": round(dy), "zoom_from": Double(run.zoomAtStart), "zoom_to": Double(zoom),
        "selected": run.selected, "selection_changes": run.facts.selectionChanges, "ink_added": run.facts.inkAdded,
        "ink_moved": run.facts.inkMoved, "ink_removed": run.facts.inkRemoved, "began_drawing": run.facts.beganDrawing,
        "page_added_during": run.pageAdded, "tool": run.tool, "touch_mode": name(paper.directTouchMode),
        "auto_draws": paper.directTouchAutomaticallyDraws, "pages": pages,
        "page": board.page(at: CGPoint(x: 0, y: visible.midY)), "ghosts": model.ghosts.count,
        "ghost_slip": round(seat.worst), "ghost_checks": seat.checks,
      ])
    seat = (0, 0)
  }
}

/// The board on paper with its page number, which floats over it and isn't in any picture.
struct PaperBoardCanvas: View {
  @ObservedObject var model: WhiteboardModel
  @StateObject private var controller: PaperBoardController

  init(model: WhiteboardModel, log: SessionLog) {
    self.model = model
    _controller = StateObject(wrappedValue: PaperBoardController(model: model, log: log))
  }

  var body: some View {
    PaperBoardHost(
      controller: controller, paper: model.paper, ghosts: model.ghosts,
      rules: model.gridOn ? .grid : model.ruledOn ? .ruled : .none
    )
    .overlay(alignment: .topTrailing) {
      Text(controller.pageText).font(.footnote.monospacedDigit())
        .padding(.vertical, 4).padding(.horizontal, 10)
        .background(.thinMaterial, in: Capsule())
        .padding(10)
        .allowsHitTesting(false)
    }
  }
}

private struct PaperBoardHost: UIViewControllerRepresentable {
  let controller: PaperBoardController
  let paper: BoardPaper
  let ghosts: [Ghost]
  let rules: PaperRules

  func makeUIViewController(context: Context) -> PaperBoardController { controller }

  func updateUIViewController(_ controller: PaperBoardController, context: Context) {
    controller.setBoardPaper(paper)
    controller.setRules(rules)
    controller.show(ghosts)
  }

  static func dismantleUIViewController(_ controller: PaperBoardController, coordinator: ()) {
    controller.boardClosed()
  }
}

/// What a board's paper is ruled with. A board has one or none.
enum PaperRules { case none, grid, ruled }

/// Paper under the ink: its colour, its grid or ruled lines, a faint line where each page ends, and the ghosts. In PaperKit's content view, so it moves with the board and is in nothing else.
final class PaperLines: UIView {
  private let shape = CAShapeLayer()
  /// The grid or ruled lines, under the page lines and the ghosts, as ink lies over all of this.
  private let rules = CAShapeLayer()
  /// A hair on screen, in board points: the lines stay that wide at any zoom.
  var hair: CGFloat = 1 {
    didSet {
      guard hair != oldValue else { return }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      rules.lineWidth = hair
      CATransaction.commit()
    }
  }
  private var rulesAcross: [CGFloat] = []
  private var rulesSpan: ClosedRange<CGFloat> = 0...0
  private var rulesDown: [CGFloat] = []
  private var width: CGFloat = 0
  private var ends: [CGFloat] = []
  let ghostLayers = GhostLayers()

  init(paper: UIColor) {
    super.init(frame: .zero)
    backgroundColor = paper
    isUserInteractionEnabled = false
    shape.fillColor = nil
    shape.strokeColor = UIColor(white: 0.5, alpha: 0.45).cgColor
    shape.lineWidth = 1
    rules.fillColor = nil
    rules.strokeColor = UIColor(white: 0.5, alpha: 0.3).cgColor
    layer.addSublayer(rules)
    layer.addSublayer(shape)
    layer.addSublayer(ghostLayers.holder)
  }

  required init?(coder: NSCoder) { nil }

  /// In board points.
  func show(width: CGFloat, ends: [CGFloat]) {
    self.width = width
    self.ends = ends
    setNeedsLayout()
  }

  /// In board points: lines over `span` at each of `across`, and side to side at each of `down`.
  func showRules(across: [CGFloat], span: ClosedRange<CGFloat>, down: [CGFloat]) {
    (rulesAcross, rulesSpan, rulesDown) = (across, span, down)
    setNeedsLayout()
  }

  /// Column points to this view's own: PaperKit sizes it.
  func spot(of point: CGPoint) -> CGPoint {
    let scale = width > 0 ? bounds.width / width : 1
    return CGPoint(x: point.x * scale, y: point.y * scale)
  }

  /// This view's own point to the column's.
  func columnPoint(of spot: CGPoint) -> CGPoint {
    let scale = width > 0 ? bounds.width / width : 1
    return CGPoint(x: spot.x / scale, y: spot.y / scale)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard width > 0, bounds.width > 0 else { return }
    let path = CGMutablePath()
    for end in ends {
      let edge = spot(of: CGPoint(x: 0, y: end))
      path.move(to: edge)
      path.addLine(to: CGPoint(x: bounds.width, y: edge.y))
    }
    let ruled = CGMutablePath()
    for x in rulesAcross {
      ruled.move(to: spot(of: CGPoint(x: x, y: rulesSpan.lowerBound)))
      ruled.addLine(to: spot(of: CGPoint(x: x, y: rulesSpan.upperBound)))
    }
    for y in rulesDown {
      ruled.move(to: spot(of: CGPoint(x: 0, y: y)))
      ruled.addLine(to: spot(of: CGPoint(x: width, y: y)))
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    shape.frame = bounds
    shape.path = path
    rules.frame = bounds
    rules.path = ruled
    ghostLayers.holder.setAffineTransform(CGAffineTransform(scaleX: bounds.width / width, y: bounds.width / width))
    CATransaction.commit()
  }
}

/// Sees every touch and takes none: it never recognises anything, delays nothing and can't be stopped by what does.
final class PaperTouchWatcher: UIGestureRecognizer {
  enum Phase { case began, moved, ended, cancelled }

  var changed: ((UITouch, Phase, Int) -> Void)?
  private var down: Set<UITouch> = []

  init() {
    super.init(target: nil, action: nil)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
    requiresExclusiveTouchType = false
  }

  override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    for touch in touches {
      down.insert(touch)
      changed?(touch, .began, down.count)
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    for touch in touches { changed?(touch, .moved, down.count) }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches, .ended) }
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches, .cancelled) }

  private func lift(_ touches: Set<UITouch>, _ phase: Phase) {
    for touch in touches {
      down.remove(touch)
      changed?(touch, phase, down.count)
    }
    if down.isEmpty { state = .failed }
  }

  override func reset() { down = [] }
}
