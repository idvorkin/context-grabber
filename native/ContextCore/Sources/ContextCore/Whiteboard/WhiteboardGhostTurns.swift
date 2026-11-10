//  The ghosts on an open board and the rules of Claude's turn (spec 2026-11-01-whiteboard-shapes-design.md, stories 344,
//  345, 351, 354, 357, 358, 360, 367, 370, 373, 380–388): which marks show, whose a new set replaces, when Claude's fade,
//  when an answer is stale, what Ghosts off stops, and when spoken words go. The board's model owns the timers, the
//  requests, the picture, the canvas and the log; it hands the time in, so a host test can step it.

import Foundation

/// A ghost as these rules see it: which one, and whose.
public protocol WhiteboardGhost {
  var id: String { get }
  var who: WhiteboardTurn.Who { get }
}

extension WhiteboardTurn {
  /// The board's note while Claude's turns fail.
  public static let ghostsAway = "Ghosts: the Cockpit isn't answering"
}

public struct WhiteboardGhostTurns<Ghost: WhiteboardGhost> {
  /// Faint on the board until a tap keeps one (stories 344, 349).
  public private(set) var ghosts: [Ghost] = []
  /// Story 351's switch.
  public private(set) var on: Bool
  /// Spoken and not yet in a turn that got through.
  public private(set) var unsaid: String?
  /// The last turn in a line: Larry's words or ghosts not answering.
  public var note: String?
  /// When Claude's ghosts go if nothing replaces them (story 358).
  public private(set) var fadeAt: ContinuousClock.Instant?
  public let ghostLife: Duration
  private var pacer = WhiteboardPacer()
  private var failing = false

  public init(on: Bool, ghostLife: Duration) {
    self.on = on
    self.ghostLife = ghostLife
  }

  // MARK: Drawing and the pause

  /// A stroke drawn or pasted. True: start Claude's pause. With Ghosts off nothing is asked.
  public mutating func stroked() -> Bool {
    guard on else { return false }
    pacer.strokeAdded()
    return true
  }

  /// The Pencil touching down: the ghosts stay, and a pause under way starts over when it lifts.
  public mutating func toolWentDown() { pacer.toolWentDown() }

  /// True: start the pause again.
  public mutating func toolLifted() -> Bool { pacer.toolLifted() }

  /// The pause ran out. True: ask now; during a turn, the ask waits for it to land.
  public mutating func pauseEnded() -> Bool { pacer.pauseEnded() }

  // MARK: The switch

  /// Off: Claude's ghosts go, a waiting pause and any owed ask are forgotten, words not yet asked about are dropped, and
  /// an answer on its way lands stale (stories 351, 367). The caller cancels its pause timer.
  public mutating func setOn(_ new: Bool) {
    on = new
    guard !new else { return }
    pacer.dropped()
    unsaid = nil
    ghosts.removeAll { $0.who == .claude }
    if note == WhiteboardTurn.ghostsAway { note = nil }
  }

  // MARK: Speech

  public enum Spoken: String, Sendable {
    /// Ghosts off: nothing asked, and the words aren't kept for later.
    case ghostsOff = "ghosts_off"
    /// Ask now: the caller cancels a waiting pause, since this turn's picture has its strokes.
    case now
    /// A turn is on its way; the words go with the next.
    case held
  }

  /// He stopped talking (stories 345, 367).
  public mutating func spoke(_ words: String) -> Spoken {
    guard on else { return .ghostsOff }
    unsaid = unsaid.map { "\($0) \(words)" } ?? words
    return pacer.pauseEnded() ? .now : .held
  }

  // MARK: A turn

  /// What the turn tells the Cockpit Igor said: Claude's turns carry the words, Larry's none.
  public func said(_ who: WhiteboardTurn.Who) -> String? { who == .claude ? unsaid : nil }

  /// Story 360: a spoken turn on an empty board shows the part on screen; any other turn frames the drawing.
  public static func framesScreen(said: String?, boardEmpty: Bool) -> Bool { said != nil && boardEmpty }

  /// The turn goes: its words are taken. Returns the generation its answer must still match to show.
  public mutating func asked(_ who: WhiteboardTurn.Who) -> Int {
    if who == .claude {
      unsaid = nil
      pacer.turnStarted()
    }
    return pacer.generation
  }

  /// A mark of the turn asked under `generation` still shows: nothing has sent Claude's turn away since.
  public func current(_ generation: Int) -> Bool { pacer.generation == generation }

  /// The turn is over, however it went. True: strokes made meanwhile are owed their pause (story 359).
  public mutating func turnOver(_ who: WhiteboardTurn.Who) -> Bool {
    who == .claude && pacer.turnLanded()
  }

  public struct Answered: Equatable, Sendable {
    /// Asked before a dismissal or Ghosts off: nothing of it shows.
    public var stale = false
    /// Marks to land as the answer's first: a plain answer's, or a stream's empty set, which clears Claude's. A
    /// stream's marks landed as they came.
    public var land: [WhiteboardTurn.Shape]?
    /// What went wrong, for the copyable problem and the log.
    public var failure: String?
    public var status: Int?
    /// The first failure in a run of them: logged once, never a loop of errors.
    public var firstFailure = false
  }

  /// How the turn's answer lands. Words that didn't get through go with the next turn, unless Ghosts went off meanwhile.
  public mutating func answered(
    _ answer: WhiteboardTurn.Answer, who: WhiteboardTurn.Who, asked generation: Int, streamed: Bool, said: String?
  ) -> Answered {
    var result = Answered(stale: who == .claude && !current(generation))
    var undelivered = said
    switch answer {
    case .shapes(let shapes):
      undelivered = nil
      failing = false
      if note == WhiteboardTurn.ghostsAway { note = nil }
      if !result.stale, !streamed || shapes.isEmpty { result.land = shapes }
    case .tooSoon:
      break
    case .refused(let status, let reason):
      result.failure = "The Cockpit refused the turn (\(status)): \(reason)"
      result.status = status
    case .away(let reason):
      result.failure = "Larry couldn't be reached: \(reason)"
    }
    if result.failure != nil { result.firstFailure = failed(who, stale: result.stale) }
    if on, let undelivered { unsaid = unsaid.map { "\(undelivered) \($0)" } ?? undelivered }
    return result
  }

  /// A turn failed. True for the first of a run. Claude's say so in the note, unless stale or something else is there;
  /// Larry's clear it, as his problem shows instead.
  public mutating func failed(_ who: WhiteboardTurn.Who, stale: Bool) -> Bool {
    let first = !failing
    failing = true
    if who == .larry {
      note = nil
    } else if !stale, note == nil {
      note = WhiteboardTurn.ghostsAway
    }
    return first
  }

  /// Larry's picture reached his thread.
  public mutating func larryReached() { failing = false }

  // MARK: Marks on the board

  /// Marks landing: an answer's first replaces its author's earlier ones and only those (story 357), later ones of a
  /// stream join them (story 370). Claude's fade `ghostLife` after his last landed (story 358).
  public mutating func land(_ new: [Ghost], who: WhiteboardTurn.Who, first: Bool, now: ContinuousClock.Instant) {
    if who == .claude, note == WhiteboardTurn.ghostsAway, !new.isEmpty { note = nil }
    ghosts = (first ? ghosts.filter { $0.who != who } : ghosts) + new
    if who == .claude { fadeAt = now + ghostLife }
  }

  /// Claude's go once their time is up; Larry's stay (story 358).
  public mutating func fade(now: ContinuousClock.Instant) {
    guard let fadeAt, now >= fadeAt else { return }
    self.fadeAt = nil
    ghosts.removeAll { $0.who == .claude }
  }

  /// Larry's newest row: its marks replace his unkept ones and leave Claude's (stories 357, 382, 386).
  public mutating func larrysMarks(_ new: [Ghost]) {
    ghosts = ghosts.filter { $0.who != .larry } + new
  }

  /// What Larry's newest row said, in the note; marks with no words clear it.
  public mutating func larrySaid(_ say: String?, marks: Bool) {
    if let say {
      note = "Larry: \(say)"
    } else if marks {
      note = nil
    }
  }

  public enum Tap {
    case nothing
    /// The caller turns it into ink and calls `keep`.
    case keep(Ghost)
    /// The caller calls `dismiss`; `larrys`: his row is settled, so it doesn't come back.
    case dismiss(count: Int, larrys: Bool)
  }

  /// A finger tap (story 354): on a ghost keeps it, anywhere else dismisses them all.
  public func tap(hitting: (Ghost) -> Bool) -> Tap {
    guard !ghosts.isEmpty else { return .nothing }
    if let ghost = ghosts.first(where: hitting) { return .keep(ghost) }
    return .dismiss(count: ghosts.count, larrys: ghosts.contains { $0.who == .larry })
  }

  /// Every ghost goes, and Claude's turn with them: a waiting pause is forgotten (the caller cancels its timer) and an
  /// answer on its way lands stale.
  public mutating func dismiss() {
    pacer.dropped()
    ghosts = []
  }

  /// A ghost kept as ink leaves the ghosts. True when it was Larry's: his row is settled.
  public mutating func keep(_ ghost: Ghost) -> Bool {
    ghosts.removeAll { $0.id == ghost.id }
    return ghost.who == .larry
  }
}

extension WhiteboardStream {
  /// How Claude's answer was read, for the turn and its `whiteboard_turn` line.
  public struct Read: Sendable {
    public var answer: WhiteboardTurn.Answer
    public var streamed: Bool
    public var firstShapeMs: Int?
    /// What cut the reading short; marks that had already arrived stay.
    public var broken: String?
    /// Who the Cockpit said answered (story 659); nil when it didn't say.
    public var responder: WhiteboardResponder?

    public init(
      answer: WhiteboardTurn.Answer = .away(reason: "no answer"), streamed: Bool = false, firstShapeMs: Int? = nil,
      broken: String? = nil, responder: WhiteboardResponder? = nil
    ) {
      self.answer = answer
      self.streamed = streamed
      self.firstShapeMs = firstShapeMs
      self.broken = broken
      self.responder = responder
    }
  }

  /// One reading of Claude's answer, fed by the caller's transport a byte at a time (story 370): which mark is the
  /// answer's first, and when it came. A Cockpit that doesn't stream yields no marks here; its answer comes whole at the
  /// end (story 373).
  public struct Reading: Sendable {
    public private(set) var stream = WhiteboardStream(status: nil, contentType: nil)
    private var firstShapeMs: Int?

    public init() {}

    /// The response arrived: `status` nil for none.
    public mutating func opened(status: Int?, contentType: String?) {
      stream = WhiteboardStream(status: status, contentType: contentType)
    }

    /// The last line came: stop reading.
    public var done: Bool { stream.done }

    /// One byte of the body: the mark it completes and whether it is the answer's first. `elapsedMs` is asked once, at
    /// the first mark.
    public mutating func take(_ byte: UInt8, elapsedMs: () -> Int) -> (shape: WhiteboardTurn.Shape, first: Bool)? {
      stream.take(byte).map { arrived($0, elapsedMs) }
    }

    /// The body ended cleanly.
    public mutating func finish(elapsedMs: () -> Int) -> (shape: WhiteboardTurn.Shape, first: Bool)? {
      stream.finish().map { arrived($0, elapsedMs) }
    }

    private mutating func arrived(_ shape: WhiteboardTurn.Shape, _ elapsedMs: () -> Int) -> (
      shape: WhiteboardTurn.Shape, first: Bool
    ) {
      let first = stream.shapes.count == 1
      if first { firstShapeMs = elapsedMs() }
      return (shape, first)
    }

    /// How it went, given what stopped the reading, if anything.
    public func read(failure: String? = nil) -> Read {
      Read(
        answer: stream.answer(error: failure), streamed: stream.streaming, firstShapeMs: firstShapeMs,
        broken: stream.broken(error: failure), responder: stream.responder)
    }

    /// What a thrown error says; a cancelled reading is the caller's deadline.
    public static func failure(_ error: Error, cancelled: Bool) -> String {
      cancelled ? "no answer in \(Int(WhiteboardTurn.suggestTimeout)) s" : error.localizedDescription
    }
  }
}
