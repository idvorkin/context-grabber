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
  /// `GRABBER_WHITEBOARD_AFTER_KEEP=<seconds>,undo,redo,...`: those presses after a keep.
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

  /// `GRABBER_WHITEBOARD_SAVE_FAILS`, set to anything: the disk is full (stories 599, 612).
  public var saveFails: Bool
  /// `GRABBER_WHITEBOARD_GHOST_SECONDS=<seconds>`: how long Claude's ghosts stay.
  public var ghostSeconds: Double?
  /// `GRABBER_WHITEBOARD_GRID=on`.
  public var grid: Bool
  /// `GRABBER_WHITEBOARD_SAY=<words>`: what the mic hears.
  public var say: String?
  /// `GRABBER_WHITEBOARD_KEEP=first`: the first ghost keeps itself.
  public var keepFirst: Bool
  /// `GRABBER_WHITEBOARD_PASTE=<text>`.
  public var paste: String?
  /// `GRABBER_WHITEBOARD_AFTER_INK=copy,paste`: those presses after the first ink; nil when unset.
  public var afterInk: [String]?
  /// `GRABBER_WHITEBOARD_PAGE_AFTER_INK=<page>`.
  public var pageAfterInk: Int?
  public var afterKeep: AfterKeep?
  public var larryTimeout: LarryTimeout?

  public init(_ env: [String: String] = [:]) {
    saveFails = env["GRABBER_WHITEBOARD_SAVE_FAILS"] != nil
    ghostSeconds = env["GRABBER_WHITEBOARD_GHOST_SECONDS"].flatMap { Double($0) }
    grid = env["GRABBER_WHITEBOARD_GRID"] == "on"
    say = env["GRABBER_WHITEBOARD_SAY"]
    keepFirst = env["GRABBER_WHITEBOARD_KEEP"] == "first"
    paste = env["GRABBER_WHITEBOARD_PASTE"]
    afterInk = env["GRABBER_WHITEBOARD_AFTER_INK"].map { $0.split(separator: ",").map(String.init) }
    pageAfterInk = env["GRABBER_WHITEBOARD_PAGE_AFTER_INK"].flatMap { Int($0) }
    if let hook = env["GRABBER_WHITEBOARD_AFTER_KEEP"] {
      let parts = hook.split(separator: ",").map(String.init)
      afterKeep = AfterKeep(delay: Double(parts.first ?? "") ?? 3, presses: Array(parts.dropFirst()))
    }
    let timeout = (env["GRABBER_WHITEBOARD_LARRY_TIMEOUT"] ?? "").split(separator: ",").map(String.init)
    if let seconds = timeout.first.flatMap({ Double($0) }) {
      larryTimeout = LarryTimeout(seconds: seconds, dismiss: timeout.dropFirst().contains("dismiss"))
    }
  }
}
