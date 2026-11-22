//  The whiteboard's launch hooks (docs/TESTING.md): the fixture board, and what a board does by itself on the
//  simulator. Pure; the app's `runBoardFixtureHook` and the whiteboard's views do the work.

import Foundation

/// `GRABBER_BOARD_FIXTURE=<id>`: an empty board on paper with a known id (#603); `GRABBER_BOARD_FIXTURE_FROM=<device
/// name>` makes it another device's (#613), `GRABBER_BOARD_FIXTURE_OLD_INK=<n>` gives it ink.
public struct BoardFixtureHook: Equatable, Sendable {
  public var board: String
  public var from: String?
  public var oldInk: Int?

  public init?(_ env: [String: String]) {
    guard let board = env["GRABBER_BOARD_FIXTURE"], !board.isEmpty else { return nil }
    self.board = board
    from = env["GRABBER_BOARD_FIXTURE_FROM"]
    oldInk = env["GRABBER_BOARD_FIXTURE_OLD_INK"].flatMap { Int($0) }
  }
}

public struct WhiteboardHooks: Equatable, Sendable {
  /// `GRABBER_WHITEBOARD_AFTER_KEEP=<seconds>,undo,redo,...`: those presses after a keep; and
  /// `GRABBER_WHITEBOARD_AFTER_OPS=...` the same after a batch of Larry's changes moved the board (story 814).
  public struct AfterKeep: Equatable, Sendable {
    /// The wait before the first press: 3 unless the first field is a number.
    public var delay: Double
    public var presses: [String]
  }

  /// `GRABBER_WHITEBOARD_LARRY_TIMEOUT=<seconds>[,dismiss]`: how long a turn of Larry's is out before the board stops
  /// waiting, and whether *Larry didn't answer* then dismisses itself (stories 669, 761).
  public struct LarryTimeout: Equatable, Sendable {
    public var seconds: Double
    public var dismiss: Bool
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
  public var replyKeepBoard: String?
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
    replyKeepBoard = env["GRABBER_WHITEBOARD_REPLY_KEEP"]
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
  }
}
