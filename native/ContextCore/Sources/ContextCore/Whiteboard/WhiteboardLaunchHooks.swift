//  The whiteboard's launch hooks (docs/TESTING.md): the fixture board, and what a board does by itself on the
//  simulator. Pure; the app's `runBoardFixtureHook` and the whiteboard's views do the work.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

/// `GRABBER_BOARD_FIXTURE=<id>`: an empty board on paper with a known id (#603); `GRABBER_BOARD_FIXTURE_FROM=<device
/// name>` makes it another device's (#613).
public struct BoardFixtureHook: Equatable, Sendable {
  public var board: String
  public var from: String?
  /// `GRABBER_BOARD_FIXTURE_THREAD=<thread>`: the board's thread with Larry, as if it had sent him a picture (bead
  /// context-grabber-dbku: *Open in Chat* on the simulator).
  public var thread: String?

  public init?(_ env: [String: String]) {
    guard let board = env["GRABBER_BOARD_FIXTURE"], !board.isEmpty else { return nil }
    self.board = board
    from = env["GRABBER_BOARD_FIXTURE_FROM"]
    thread = env["GRABBER_BOARD_FIXTURE_THREAD"].flatMap { $0.isEmpty ? nil : $0 }
  }
}

public struct WhiteboardHooks: Equatable, Sendable {
  /// `GRABBER_WHITEBOARD_AFTER_KEEP=<seconds>,undo,redo,...`: those presses after a keep; and
  /// `GRABBER_WHITEBOARD_AFTER_OPS=...` the same after a batch of Larry's changes moved the board (story 814).
  public struct AfterKeep: Equatable, Sendable {
    /// The wait before the first press: 3 unless the first field is a number.
    public var delay: Double
    public var presses: [String]

    public init(delay: Double, presses: [String]) {
      self.delay = delay
      self.presses = presses
    }
  }

  /// `GRABBER_WHITEBOARD_KEEP_LOOP=<count>[,each|batch]`: on the board that opens, that many keeps of three of Larry's
  /// circles, each looked at and taken out again, for the simulator's rate of a kept mark drawn in part black or not at
  /// all (bead context-grabber-pbvt). `how` is the way the strokes go into the markup: one append per stroke, the board's
  /// way (`each`), or all in one append (`batch`), the way that drew wrong.
  public struct KeepLoop: Equatable, Sendable {
    public enum How: String, Equatable, Sendable { case each, batch }
    public var count: Int
    public var how: How

    public init(count: Int, how: How) {
      self.count = count
      self.how = how
    }

    init?(_ spec: String) {
      let parts = spec.split(separator: ",").map(String.init)
      guard let count = parts.first.flatMap({ Int($0) }), count > 0 else { return nil }
      guard let how = parts.count > 1 ? How(rawValue: parts[1]) : .each else { return nil }
      self.init(count: count, how: how)
    }
  }

  /// `GRABBER_WHITEBOARD_LARRY_TIMEOUT=<seconds>[,dismiss]`: how long a turn of Larry's is out before the board stops
  /// waiting, and whether *Larry didn't answer* then dismisses itself (stories 669, 761).
  public struct LarryTimeout: Equatable, Sendable {
    public var seconds: Double
    public var dismiss: Bool

    public init(seconds: Double, dismiss: Bool) {
      self.seconds = seconds
      self.dismiss = dismiss
    }
  }

  /// `GRABBER_WHITEBOARD_LARRY_WAIT=retry` / `dismiss` / `interrupt`: the control that taps itself, once, when the
  /// board first offers it twenty seconds into a turn of Larry's (stories 775–777).
  public enum LarryWaitPress: String, Equatable, Sendable {
    case retry, dismiss, interrupt
  }

  /// `GRABBER_WHITEBOARD_SAVE_FAILS`, set to anything: the disk is full (stories 599, 612).
  public var saveFails: Bool
  /// `GRABBER_WHITEBOARD_UNREADABLE=stuck`: a saved drawing reads as nonsense and can't be moved aside (#1042).
  public var unreadableStuck: Bool
  /// `GRABBER_WHITEBOARD_GHOST_SECONDS=<seconds>`: how long Claude's ghosts stay.
  public var ghostSeconds: Double?
  /// `GRABBER_WHITEBOARD_GRID=on`: the board turns its grid on as it opens.
  public var grid: Bool
  /// `GRABBER_WHITEBOARD_GRID=off`: a new board starts without the grid it has since #915 (story 410), for UI tests that
  /// read the screen's pixels against plain paper.
  public var newBoardsBare: Bool
  /// `GRABBER_WHITEBOARD_SAY=<words>`: what the mic hears.
  public var say: String?
  /// `GRABBER_WHITEBOARD_PASTE=<text>`.
  public var paste: String?
  /// `GRABBER_WHITEBOARD_AFTER_INK=copy,paste`: those presses after the first ink; nil when unset.
  public var afterInk: [String]?
  /// `GRABBER_WHITEBOARD_PAGE_AFTER_INK=<page>`.
  public var pageAfterInk: Int?
  public var afterKeep: AfterKeep?
  public var afterOps: AfterKeep?
  /// `GRABBER_WHITEBOARD_BAR_UNDO=<seconds>,undo,redo,...`: those presses of the bar's own Undo and Redo, that long after a
  /// board drawn on here opens (#965, stories 1008, 1009).
  public var barUndo: AfterKeep?
  public var larryTimeout: LarryTimeout?
  public var larryWait: LarryWaitPress?
  /// `GRABBER_WHITEBOARD_SELECT_NEWEST=<n>`: once the board holds `n` strokes, the newest is selected as the lasso would
  /// leave it, for the simulator, whose UI tests can't draw a lasso (story 910).
  public var selectNewest: Int?
  /// `GRABBER_WHITEBOARD_ZIGZAG=<n>`: the stroke that brings the board to `n` strokes is read as a fast zigzag across its
  /// own frame, for the simulator, whose UI tests can only drag straight (#999, story 890).
  public var zigzagAt: Int?
  /// `GRABBER_WHITEBOARD_FEEDBACK_SECONDS=<seconds>`: how long a pen gesture's feedback (#1000) stays after the finger
  /// or the Pencil lifts, for a UI test's picture: the room band held after the lift, the scratch flash held bright
  /// before it fades, and *Nothing under the scribble* shown at least that long. Nil (none held) when unset.
  public var feedbackSeconds: Double?
  /// `GRABBER_WHITEBOARD_LIST_CHAT=<board>`: on an iPhone, once the boards list is up, that board's chat bubble is
  /// tapped, for the simulator (#1163, story 1097).
  public var listChat: String?
  /// `GRABBER_WHITEBOARD_PENCIL=seen`: the board acts as if the Pencil had touched a board this launch, for the simulator,
  /// which has no Pencil (story 1153).
  public var pencilSeen: Bool
  /// `GRABBER_WHITEBOARD_FINGER_LABEL=1`: whether a finger draws, as an element a UI test reads (stories 1152, 1153).
  public var fingerLabel: Bool
  public var chooseMark: Bool
  /// `GRABBER_WHITEBOARD_KEPT_INK_LABEL=1`: each look at kept ink's verdict and the heals it asked for, as an element a UI
  /// test reads (story 650, bead context-grabber-qko5).
  public var keptInkLabel: Bool
  /// `GRABBER_WHITEBOARD_UNDO_LOOK=label`: each look after an Undo or Redo, its verdict and the heals it asked for, as an
  /// element a UI test reads; `=miss` too, and the first look takes every piece it checks as missing, so the heal runs on
  /// the simulator, which misses only now and then (story 1203, bead context-grabber-9bll).
  public var undoLookLabel: Bool
  public var undoLookMiss: Bool
  /// `GRABBER_WHITEBOARD_PANEL=fresh`: the conversation's kept height, float and card are forgotten as the first board
  /// opens, so a UI test starts from the panel's own place (story 1313, #1416).
  public var panelFresh: Bool
  /// `GRABBER_WHITEBOARD_FAKE_OFFER=1`: a beat after a finger tap selects a group, the board shows a stand-in for the
  /// iPad's handwriting popover at the paper and empties the selection without a callback, as the iPad did, for the
  /// simulator, which never offers it (stories 945, 946).
  public var fakeHandwritingOffer: Bool
  /// `GRABBER_WHITEBOARD_REVIEW_IDLE=<seconds>`: how long the board waits after a step before it reviews the session,
  /// in place of five minutes (story 1237).
  public var reviewIdle: Double?
  /// `GRABBER_WHITEBOARD_REVIEW_FINDING=1`: the first stroke's step is followed by a stand-in Keep that changed the pen,
  /// so the review finds a bug the simulator can show (stories 1243–1245).
  public var reviewFinding: Bool
  public var keepLoop: KeepLoop?
  /// `GRABBER_WHITEBOARD_KEEP_WAY=each|batch`: every keep this launch goes into the markup that way, as the keep
  /// loop's do, so a UI test's own keeps can be counted the same way (bead context-grabber-pbvt).
  public var keepWay: KeepLoop.How?

  public init(_ env: [String: String] = [:]) {
    saveFails = env["GRABBER_WHITEBOARD_SAVE_FAILS"] != nil
    unreadableStuck = env["GRABBER_WHITEBOARD_UNREADABLE"] == "stuck"
    ghostSeconds = env["GRABBER_WHITEBOARD_GHOST_SECONDS"].flatMap { Double($0) }
    grid = env["GRABBER_WHITEBOARD_GRID"] == "on"
    newBoardsBare = env["GRABBER_WHITEBOARD_GRID"] == "off"
    say = env["GRABBER_WHITEBOARD_SAY"]
    paste = env["GRABBER_WHITEBOARD_PASTE"]
    afterInk = env["GRABBER_WHITEBOARD_AFTER_INK"].map { $0.split(separator: ",").map(String.init) }
    pageAfterInk = env["GRABBER_WHITEBOARD_PAGE_AFTER_INK"].flatMap { Int($0) }
    let presses = { (hook: String) -> AfterKeep in
      let parts = hook.split(separator: ",").map(String.init)
      return AfterKeep(delay: Double(parts.first ?? "") ?? 3, presses: Array(parts.dropFirst()))
    }
    afterKeep = env["GRABBER_WHITEBOARD_AFTER_KEEP"].map(presses)
    afterOps = env["GRABBER_WHITEBOARD_AFTER_OPS"].map(presses)
    barUndo = env["GRABBER_WHITEBOARD_BAR_UNDO"].map(presses)
    let timeout = (env["GRABBER_WHITEBOARD_LARRY_TIMEOUT"] ?? "").split(separator: ",").map(String.init)
    if let seconds = timeout.first.flatMap({ Double($0) }) {
      larryTimeout = LarryTimeout(seconds: seconds, dismiss: timeout.dropFirst().contains("dismiss"))
    }
    larryWait = env["GRABBER_WHITEBOARD_LARRY_WAIT"].flatMap(LarryWaitPress.init(rawValue:))
    selectNewest = env["GRABBER_WHITEBOARD_SELECT_NEWEST"].flatMap { Int($0) }
    zigzagAt = env["GRABBER_WHITEBOARD_ZIGZAG"].flatMap { Int($0) }
    feedbackSeconds = env["GRABBER_WHITEBOARD_FEEDBACK_SECONDS"].flatMap { Double($0) }
    listChat = env["GRABBER_WHITEBOARD_LIST_CHAT"].flatMap { $0.isEmpty ? nil : $0 }
    pencilSeen = env["GRABBER_WHITEBOARD_PENCIL"] == "seen"
    fingerLabel = env["GRABBER_WHITEBOARD_FINGER_LABEL"] == "1"
    chooseMark = env["GRABBER_WHITEBOARD_CHOOSE_MARK"] == "1"
    keptInkLabel = env["GRABBER_WHITEBOARD_KEPT_INK_LABEL"] == "1"
    undoLookMiss = env["GRABBER_WHITEBOARD_UNDO_LOOK"] == "miss"
    panelFresh = env["GRABBER_WHITEBOARD_PANEL"] == "fresh"
    undoLookLabel = undoLookMiss || env["GRABBER_WHITEBOARD_UNDO_LOOK"] == "label"
    fakeHandwritingOffer = env["GRABBER_WHITEBOARD_FAKE_OFFER"] == "1"
    reviewIdle = env["GRABBER_WHITEBOARD_REVIEW_IDLE"].flatMap { Double($0) }
    reviewFinding = env["GRABBER_WHITEBOARD_REVIEW_FINDING"] == "1"
    keepLoop = env["GRABBER_WHITEBOARD_KEEP_LOOP"].flatMap(KeepLoop.init)
    keepWay = env["GRABBER_WHITEBOARD_KEEP_WAY"].flatMap(KeepLoop.How.init(rawValue:))
  }
}
