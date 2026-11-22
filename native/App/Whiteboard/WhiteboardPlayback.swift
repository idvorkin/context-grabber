//  Playing a board back, as Notability does, the ink alone (spec 2026-11-01-whiteboard-design.md, *Playing a board
//  back, as Notability does*; stories 954, 956–958; bead context-grabber-3tdv). Play, beside ? and Feedback, lays a
//  canvas of its own over the board and draws the board's strokes again in the order and at the pace they were drawn
//  (`BoardPlayback` in ContextCore), with a bar to pause, skip, scrub and change the speed. The real canvas underneath is
//  never touched, so leaving saves nothing, makes no undo step and sends nothing to Larry.

import ContextCore
import PencilKit
import SwiftUI
import UIKit

extension WhiteboardModel {
  /// Story 958: Play. An open mic stops first (its last words go as ever), and the board's tool picker goes away.
  func startPlayback() {
    guard playback == nil, !drawing.strokes.isEmpty else { return }
    stopMic(why: "playback")
    playback = WhiteboardPlaybackPlayer(model: self, controller: canvas as? PaperBoardController)
  }

  /// Story 957: Done. The board shows as it is.
  func endPlayback() {
    playback?.finish()
    playback = nil
  }
}

/// Lays playback over the board while it plays, with the board's own bars hidden so nothing on them can be tapped.
struct WhiteboardPlaybackHost: ViewModifier {
  @ObservedObject var model: WhiteboardModel

  func body(content: Content) -> some View {
    content
      .overlay {
        if let player = model.playback {
          WhiteboardPlaybackView(player: player) { model.endPlayback() }
        }
      }
      .toolbar(model.playback == nil ? .automatic : .hidden, for: .navigationBar, .bottomBar)
  }
}

/// One playback: the drawing as it was when Play was chosen, its timeline and the playhead.
@MainActor
final class WhiteboardPlaybackPlayer: ObservableObject {
  let strokes: [PKStroke]
  let timeline: BoardPlayback
  @Published private(set) var clock: BoardPlaybackClock
  /// How many strokes show, for the bar.
  @Published private(set) var shown = 0
  let paperColor: UIColor
  /// The board's column, board points.
  let bounds: CGRect
  /// Where the board was showing, board points, and its zoom.
  let opening: (visible: CGRect, zoom: CGFloat)?
  /// Story 958 (#1169): the board's paper under playback, its lines as the board has them, its pages.
  let rules: PaperRules
  let column: BoardPages
  let pageCount: Int
  /// The whole board, faint, under the ink drawn again (#1169); nil for a board too big to draw.
  let ghost: UIImage?
  /// Story 948: the stroke being drawn, or drawn last, when it's wholly above or below the screen.
  @Published private(set) var offScreen: BoardPlayback.OffScreen?
  /// Story 948 for the log: how many times the label showed.
  var offScreenShown = 0
  weak var canvas: PKCanvasView? {
    didSet { draw(force: true) }
  }
  private let log: SessionLog
  private let board: String
  private weak var controller: PaperBoardController?
  private var frame = BoardPlayback.Frame(shown: [], partial: nil)
  private var ticker: Task<Void, Never>?
  private var watched: TimeInterval = 0
  private var seeks = 0
  private var reachedEnd = false
  /// Story 958 on a big board: how many new drawings playback set, and the slowest, for the log.
  private var frames = 0
  private var slowestDrawMs = 0.0

  init(model: WhiteboardModel, controller: PaperBoardController?) {
    let started = CACurrentMediaTime()
    var drawing = model.drawing
    if model.oldCanvas {
      // As the board's load moves it (story 658): the old canvas's ink sits about 10,000 points from its corner.
      drawing = drawing.transformed(using: BoardPages.placing(ink: drawing.bounds).transform)
    }
    strokes = drawing.strokes
    timeline = BoardPlayback(
      strokes.map {
        BoardPlayback.Stroke(began: $0.path.creationDate.timeIntervalSince1970, offsets: $0.path.map(\.timeOffset))
      })
    clock = BoardPlaybackClock(length: timeline.length)
    paperColor = model.paper.color
    let pages = BoardPages()
    column = controller?.board ?? pages
    pageCount = controller?.pages ?? pages.pagesNeeded(inkMaxY: drawing.bounds.maxY)
    bounds = column.bounds(pages: pageCount)
    rules = controller?.rules ?? .none
    let ghostStarted = CACurrentMediaTime()
    ghost = Self.ghost(of: drawing, in: bounds)
    let ghostMs = Int((CACurrentMediaTime() - ghostStarted) * 1000)
    opening = model.canvas.map { ($0.visibleRect, $0.zoom) }
    log = model.log
    board = model.board.id
    self.controller = controller
    // The tool picker floats over everything; it goes with the paper's turn as first responder.
    controller?.paper.resignFirstResponder()
    log.event(
      "whiteboard",
      [
        "action": "playback_start", "board": board, "strokes": timeline.count, "timed": timeline.timed,
        "shared": timeline.shared, "real_s": Self.tenths(timeline.realSpan), "plays_s": Self.tenths(timeline.length),
        "ms": Int((CACurrentMediaTime() - started) * 1000),
      ].merging(paperFields(ghostMs: ghostMs)) { first, _ in first })
    clock.play()
    startTicking()
  }

  /// Story 954, the bar's status: which stroke of how many, and whether it plays.
  var status: String {
    "Stroke \(shown) of \(timeline.count), \(clock.playing ? "playing" : "paused")"
  }

  func playPause() {
    if clock.playing { clock.pause() } else { clock.play() }
    draw()
  }

  func skip(_ by: TimeInterval) {
    let from = clock.position
    clock.skip(by)
    seeked(by < 0 ? "back" : "forward", from: from)
  }

  func nextSpeed() {
    clock.nextSpeed()
    log.event("whiteboard", ["action": "playback_speed", "board": board, "speed": clock.speed])
  }

  /// The handle dragged: the board follows; the log hears of it once it's let go.
  func scrub(to t: TimeInterval) {
    scrubFrom = scrubFrom ?? clock.position
    clock.seek(to: t)
    draw()
  }

  func scrubEnded() {
    guard let from = scrubFrom else { return }
    scrubFrom = nil
    seeked("scrub", from: from)
  }
  private var scrubFrom: TimeInterval?

  /// The strokes showing, each with its number in playback order (1 for the first drawn), for VoiceOver and the UI
  /// test: the board's ink isn't in the accessibility tree. The newest few hundred on a big board.
  var showingNumbered: [(number: Int, stroke: PKStroke, index: Int)] {
    frame.shown.suffix(300).map { (number: (numbers[$0] ?? 0) + 1, stroke: stroke($0), index: $0) }
  }
  private lazy var numbers: [Int: Int] = Dictionary(
    timeline.entries.enumerated().map { ($1.index, $0) }, uniquingKeysWith: { first, _ in first })

  /// Story 956 by VoiceOver: a stroke's element activated goes to the moment it began.
  func seek(toStroke index: Int) {
    guard let start = timeline.start(of: index) else { return }
    let from = clock.position
    clock.seek(to: start)
    seeked("voiceover", from: from, stroke: index)
  }

  /// Story 956: a tap on a stroke, drawn again or still faint (#1169), goes back (or on) to the moment it began; bare
  /// paper does nothing.
  func tapped(at point: CGPoint, reach: CGFloat) {
    let showing = strokes.indices.map { index in
      let stroke = stroke(index)
      let points = stroke.path.interpolatedPoints(by: .distance(4)).map { $0.location.applying(stroke.transform) }
      return (
        index: index, points: points.isEmpty ? stroke.path.map { $0.location.applying(stroke.transform) } : points
      )
    }
    guard let index = BoardPlayback.nearest(point, among: showing, within: reach),
      let start = timeline.start(of: index)
    else {
      log.event("whiteboard", ["action": "playback_tap", "board": board, "hit": false, "showing": showing.count])
      return
    }
    let from = clock.position
    clock.seek(to: start)
    seeked("tap", from: from, stroke: index)
  }

  /// Done, or the board closing: the ticking stops and the paper takes the tool picker back.
  func finish() {
    ticker?.cancel()
    ticker = nil
    if let controller, controller.drawsHere { controller.paper.becomeFirstResponder() }
    log.event(
      "whiteboard",
      [
        "action": "playback_end", "board": board, "watched_s": Self.tenths(watched), "reached_end": reachedEnd,
        "seeks": seeks, "at_s": Self.tenths(clock.position), "frames": frames,
        "slowest_draw_ms": Self.tenths(slowestDrawMs), "offscreen_shown": offScreenShown,
      ])
  }

  private func seeked(_ how: String, from: TimeInterval, stroke: Int? = nil) {
    seeks += 1
    var fields: [String: Any] = [
      "action": "playback_seek", "board": board, "how": how, "from_s": Self.tenths(from),
      "to_s": Self.tenths(clock.position),
    ]
    if let stroke { fields["stroke"] = stroke }
    log.event("whiteboard", fields)
    draw()
  }

  private func startTicking() {
    ticker = Task { [weak self] in
      var last = ContinuousClock.now
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(33))
        let now = ContinuousClock.now
        let seconds = (now - last) / .seconds(1)
        last = now
        guard let self else { return }
        guard self.clock.playing else { continue }
        self.watched += seconds
        self.clock.advance(seconds)
        if self.clock.atEnd { self.reachedEnd = true }
        self.draw()
      }
    }
  }

  /// The strokes at the playhead on the canvas, set only when they change: a new drawing every tick is the whole
  /// board drawn again.
  private func draw(force: Bool = false) {
    let next = timeline.frame(at: clock.position)
    guard force || next != frame else { return }
    frame = next
    shown = next.shown.count
    lookOffScreen()
    guard let canvas else { return }
    let started = CACurrentMediaTime()
    canvas.drawing = PKDrawing(strokes: next.shown.map(stroke))
    frames += 1
    slowestDrawMs = max(slowestDrawMs, (CACurrentMediaTime() - started) * 1000)
  }

  /// The stroke at this place in the drawing as it shows now: the one being drawn cut to the points drawn so far.
  private func stroke(_ index: Int) -> PKStroke {
    let whole = strokes[index]
    guard let part = frame.partial, part.index == index, part.points < whole.path.count else { return whole }
    return PKStroke(
      ink: whole.ink,
      path: PKStrokePath(controlPoints: Array(whole.path.prefix(part.points)), creationDate: whole.path.creationDate),
      transform: whole.transform, mask: whole.mask, randomSeed: whole.randomSeed)
  }

  static func tenths(_ t: TimeInterval) -> Double { (t * 10).rounded() / 10 }

  var boardID: String { board }
  var sessionLog: SessionLog { log }
  var clockPosition: TimeInterval { clock.position }

  func setOffScreen(_ next: BoardPlayback.OffScreen?) {
    if next != offScreen { offScreen = next }
  }
}

/// The playback's board and its bar.
struct WhiteboardPlaybackView: View {
  @ObservedObject var player: WhiteboardPlaybackPlayer
  let done: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      WhiteboardPlaybackCanvas(player: player)
        .overlay(alignment: .top) { WhiteboardPlaybackOffScreenLabel(player: player, edge: .top) }
        .overlay(alignment: .bottom) { WhiteboardPlaybackOffScreenLabel(player: player, edge: .bottom) }
      bar
    }
    .background(Color(player.paperColor))
  }

  private var bar: some View {
    VStack(spacing: 8) {
      HStack(spacing: 12) {
        Text(Self.time(player.clock.position)).monospacedDigit()
        Slider(
          value: Binding(get: { player.clock.position }, set: { player.scrub(to: $0) }),
          in: 0...max(player.timeline.length, 0.001),
          onEditingChanged: { editing in if !editing { player.scrubEnded() } }
        )
        .accessibilityLabel("Playback position")
        .accessibilityIdentifier("whiteboard-playback-scrub")
        Text(Self.time(player.timeline.length)).monospacedDigit()
      }
      .font(.footnote)
      HStack(spacing: 8) {
        Button {
          player.skip(-BoardPlayback.skip)
        } label: {
          Label("Back 10 seconds", systemImage: "gobackward.10").labelStyle(.iconOnly).frame(
            minWidth: 36, minHeight: 36)
        }
        .accessibilityIdentifier("whiteboard-playback-back")
        Button {
          player.playPause()
        } label: {
          Label(player.clock.playing ? "Pause" : "Play", systemImage: player.clock.playing ? "pause.fill" : "play.fill")
            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 36)
        }
        .accessibilityIdentifier("whiteboard-playback-play")
        Button {
          player.skip(BoardPlayback.skip)
        } label: {
          Label("On 10 seconds", systemImage: "goforward.10").labelStyle(.iconOnly).frame(minWidth: 36, minHeight: 36)
        }
        .accessibilityIdentifier("whiteboard-playback-forward")
        Button(Self.speed(player.clock.speed)) { player.nextSpeed() }
          .monospacedDigit()
          .frame(minWidth: 52, minHeight: 36)
          .accessibilityLabel("Speed \(Self.speed(player.clock.speed))")
          .accessibilityIdentifier("whiteboard-playback-speed")
        Spacer(minLength: 8)
        Text(player.status)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .accessibilityIdentifier("whiteboard-playback-status")
        Spacer(minLength: 8)
        Button("Done", action: done)
          .fontWeight(.semibold)
          .accessibilityIdentifier("whiteboard-playback-done")
      }
      .buttonStyle(.bordered)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.regularMaterial)
    // The board is light while open (PaperKit's dark mode loses ink), so its playback is too.
    .environment(\.colorScheme, .light)
  }

  /// m:ss.
  static func time(_ t: TimeInterval) -> String {
    let seconds = Int(t.rounded(.down))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  static func speed(_ speed: Double) -> String {
    (speed == speed.rounded() ? String(Int(speed)) : String(format: "%g", speed)) + "×"
  }
}

/// A canvas that only shows: its drawing gesture off (Pencil or finger), a finger still pans and pinches, a tap finds a
/// stroke.
private struct WhiteboardPlaybackCanvas: UIViewRepresentable {
  let player: WhiteboardPlaybackPlayer

  func makeUIView(context: Context) -> PlaybackCanvasView { PlaybackCanvasView(player: player) }

  func updateUIView(_ view: PlaybackCanvasView, context: Context) {}
}

final class PlaybackCanvasView: UIView, PKCanvasViewDelegate {
  let canvas = PKCanvasView()
  let player: WhiteboardPlaybackPlayer
  /// The paper's lines and the faint board, inside the canvas so they pan and zoom with it (#1169; +Paper).
  let paperLines: PaperLines
  let ghostView = UIImageView()
  var laidStep: CGFloat = 0
  private var laidOut = false

  init(player: WhiteboardPlaybackPlayer) {
    self.player = player
    paperLines = PaperLines(paper: player.paperColor)
    super.init(frame: .zero)
    overrideUserInterfaceStyle = .light
    backgroundColor = player.paperColor
    canvas.drawingGestureRecognizer.isEnabled = false
    canvas.backgroundColor = .clear
    canvas.isOpaque = false
    canvas.contentInsetAdjustmentBehavior = .never
    canvas.delegate = self
    canvas.accessibilityIdentifier = "whiteboard-playback-board"
    canvas.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    addSubview(canvas)
    addPaper()
    player.canvas = canvas
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    canvas.frame = bounds
    guard !laidOut, bounds.width > 0 else { return }
    laidOut = true
    // Opened where the board was showing, at its zoom; never narrower than the page across the screen.
    let fit = bounds.width / max(player.bounds.width, 1)
    canvas.minimumZoomScale = fit
    canvas.maximumZoomScale = max(3, fit)
    canvas.zoomScale = min(max(player.opening?.zoom ?? fit, fit), canvas.maximumZoomScale)
    sizeContent()
    if let visible = player.opening?.visible {
      let zoom = canvas.zoomScale
      let most = CGPoint(
        x: max(0, canvas.contentSize.width - bounds.width), y: max(0, canvas.contentSize.height - bounds.height))
      canvas.contentOffset = CGPoint(
        x: min(max(0, (visible.minX - player.bounds.minX) * zoom), most.x),
        y: min(max(0, (visible.minY - player.bounds.minY) * zoom), most.y))
    }
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) { sizeContent() }

  func scrollViewDidScroll(_ scrollView: UIScrollView) { player.lookOffScreen() }

  private func sizeContent() {
    canvas.contentSize = CGSize(
      width: player.bounds.maxX * canvas.zoomScale, height: player.bounds.maxY * canvas.zoomScale)
    layPaper()
  }

  /// Each stroke showing as an element over its ink (story 956 for VoiceOver and the UI test): activated, it seeks there.
  override var accessibilityElements: [Any]? {
    get {
      [canvas]
        + player.showingNumbered.map { shown in
          let element = PlaybackStrokeElement(accessibilityContainer: self)
          element.accessibilityLabel = "Stroke \(shown.number)"
          element.accessibilityIdentifier = "whiteboard-playback-stroke-\(shown.number)"
          element.accessibilityTraits = .button
          let box = shown.stroke.renderBounds
          let zoom = canvas.zoomScale
          let offset = canvas.contentOffset
          element.accessibilityFrameInContainerSpace = CGRect(
            x: box.minX * zoom - offset.x, y: box.minY * zoom - offset.y, width: box.width * zoom,
            height: box.height * zoom)
          let (player, index) = (player, shown.index)
          element.activate = { player.seek(toStroke: index) }
          return element
        }
    }
    // Built each time UIKit asks; nothing sets them.
    // swiftlint:disable:next unused_setter_value
    set {}
  }

  @objc private func tapped(_ tap: UITapGestureRecognizer) {
    let at = tap.location(in: canvas)
    let zoom = max(canvas.zoomScale, 0.01)
    player.tapped(at: CGPoint(x: at.x / zoom, y: at.y / zoom), reach: 44 / zoom)
  }
}

/// A stroke showing in playback, for VoiceOver.
private final class PlaybackStrokeElement: UIAccessibilityElement {
  var activate: (() -> Void)?

  override func accessibilityActivate() -> Bool {
    activate?()
    return activate != nil
  }
}
