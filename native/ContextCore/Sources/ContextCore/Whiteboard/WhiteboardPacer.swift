//  When Claude is asked about the board (spec 2026-11-01-whiteboard-shapes-design.md, stories 345, 359): a pause after a
//  stroke or spoken words, one turn at a time, and strokes or words during a turn asking again after the next pause,
//  which waits for the tool to lift. The caller owns the timer and the request; a `true` from a method means start the
//  pause.

public struct WhiteboardPacer: Sendable {
  /// How long the Pencil rests before Claude is asked: half a second since 2026-11-10 (story 660; 1 s before).
  public static let pause: Duration = .milliseconds(500)

  /// Bumped when Igor sends Claude's turn away (a dismissal, Ghosts off): an answer asked under an older one is stale.
  public private(set) var generation = 0
  private var pausing = false
  private var asking = false
  private var askAgain = false
  private var toolDown = false
  private var askOnLift = false

  public init() {}

  public mutating func strokeAdded() {
    pausing = true
  }

  /// A pause under way stops here, and starts over at the lift.
  public mutating func toolWentDown() {
    toolDown = true
    if pausing { askOnLift = true }
    pausing = false
  }

  public mutating func toolLifted() -> Bool {
    toolDown = false
    defer { askOnLift = false }
    if askOnLift { pausing = true }
    return askOnLift
  }

  /// The pause ran out. True: ask now. During a turn, the ask waits for that turn to land.
  public mutating func pauseEnded() -> Bool {
    pausing = false
    if asking { askAgain = true }
    return !asking
  }

  public mutating func turnStarted() {
    asking = true
  }

  public mutating func turnLanded() -> Bool {
    asking = false
    guard askAgain else { return false }
    askAgain = false
    if toolDown {
      askOnLift = true
      return false
    }
    pausing = true
    return true
  }

  /// Igor sent the turn away: a waiting pause and any owed ask are forgotten, and a turn on its way lands stale.
  public mutating func dropped() {
    generation += 1
    pausing = false
    askAgain = false
    askOnLift = false
  }
}
