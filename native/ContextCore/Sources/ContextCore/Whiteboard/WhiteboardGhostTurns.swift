//  The ghosts on an open board and the rules of Claude's turn (spec 2026-11-01-whiteboard-shapes-design.md, stories 344,
//  345, 351, 354, 357, 358, 360, 367, 370, 373, 380–388, 825): which marks show, whose a new set replaces, when Claude's fade,
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
  /// The board's note when the mic would hear words and reach no one (#824).
  public static let micGhostsOff = "Ghosts are off, so the mic would reach no one: turn Ghosts on to talk to Claude"
}

public struct WhiteboardGhostTurns<Ghost: WhiteboardGhost> {
  /// Faint on the board until one is kept or dismissed (stories 344, 349, 825).
  public private(set) var ghosts: [Ghost] = []
  /// The mark whose Keep and Dismiss show (story 825). Gone with its mark, however that goes.
  public var chosen: Ghost? { chosenID.flatMap { id in ghosts.first { $0.id == id } } }
  private var chosenID: String?
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
  /// Claude's marks landed by the turn out, which go if the Pencil cancels it (story 894).
  private var landedThisTurn: Set<String> = []
  /// The generation of a turn the Pencil cancelled: its answer is no failure (story 894).
  private var cancelled: Int?

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

  /// The Pencil touching down: the ghosts stay, and a pause under way starts over when it lifts. Keep and Dismiss go
  /// away (story 810): true when they were showing.
  @discardableResult
  public mutating func toolWentDown() -> Bool {
    pacer.toolWentDown()
    return putAway()
  }

  /// True: start the pause again.
  public mutating func toolLifted() -> Bool { pacer.toolLifted() }

  /// Story 894: the Pencil going down while Claude's turn is out. Writing again makes that picture stale: the turn is
  /// dropped, the marks it had landed go, and its words wait for the next. True when a turn was out, so the caller stops
  /// its request.
  public mutating func penCancelsTurn() -> Bool {
    guard pacer.isAsking else { return false }
    cancelled = pacer.generation
    pacer.dropped()
    ghosts.removeAll { landedThisTurn.contains($0.id) }
    landedThisTurn = []
    return true
  }

  /// The pause ran out. True: ask now; during a turn, the ask waits for it to land.
  public mutating func pauseEnded() -> Bool { pacer.pauseEnded() }

  // MARK: The switch

  /// Off: Claude's ghosts go, a waiting pause and any owed ask are forgotten, words not yet asked about are dropped, and
  /// an answer on its way lands stale (stories 351, 367). The caller cancels its pause timer.
  public mutating func setOn(_ new: Bool) {
    on = new
    guard !new else {
      if note == WhiteboardTurn.micGhostsOff { note = nil }
      return
    }
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

  /// The board's mic may open: with Ghosts off it would hear words and reach no one, so it doesn't, and the note says
  /// why (#824).
  public mutating func micMayOpen() -> Bool {
    if !on { note = WhiteboardTurn.micGhostsOff }
    return on
  }

  /// Ghosts went off with the mic open: it closes, and the note says why (#824).
  public mutating func micClosedByGhostsOff() { note = WhiteboardTurn.micGhostsOff }

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
      landedThisTurn = []
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
    /// The Pencil cancelled it (story 894): stale, and no failure.
    public var cancelled = false
  }

  /// How the turn's answer lands. Words that didn't get through go with the next turn, unless Ghosts went off meanwhile.
  public mutating func answered(
    _ answer: WhiteboardTurn.Answer, who: WhiteboardTurn.Who, asked generation: Int, streamed: Bool, said: String?
  ) -> Answered {
    var result = Answered(stale: who == .claude && !current(generation))
    result.cancelled = who == .claude && cancelled == generation
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
    if result.cancelled {
      cancelled = nil
      result.failure = nil
      result.status = nil
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
    if who == .claude {
      fadeAt = now + ghostLife
      landedThisTurn.formUnion(new.map(\.id))
    }
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

  /// Larry's text from a batch of his changes (story 817): it joins his marks, replacing only a ghost with the same id.
  public mutating func larrysText(_ new: [Ghost]) {
    let ids = Set(new.map(\.id))
    ghosts = ghosts.filter { !ids.contains($0.id) } + new
  }

  /// Larry's change took these ghosts of his text away (#939, story 993): they go, and Keep and Dismiss with one of
  /// them chosen.
  public mutating func larrysTextGone(_ ids: Set<String>) {
    if let chosenID, ids.contains(chosenID) { self.chosenID = nil }
    ghosts.removeAll { $0.who == .larry && ids.contains($0.id) }
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
    /// No buttons showing and none to show, or the tap was on the mark already chosen.
    case nothing
    /// Keep and Dismiss now show beside this mark; nothing on the board has changed.
    case chose(Ghost)
    /// A tap off the marks put the buttons away; nothing is kept or dismissed (#823, #883).
    case putAway
  }

  /// A finger tap (stories 354, 825): on a mark chooses it, so its Keep and Dismiss show; anywhere else only puts them
  /// away. A stray tap never keeps or dismisses a mark.
  public mutating func tap(hitting: (Ghost) -> Bool) -> Tap {
    tapNearest(reach: { hitting($0) ? 0 : nil })
  }

  /// A finger tap, each mark's distance from it given (nil: out of reach): the nearest mark takes it, and between two as
  /// near the one drawn later, on top (#941).
  public mutating func tapNearest(reach: (Ghost) -> CGFloat?) -> Tap {
    if let ghost = WhiteboardMarkChoice.nearest(ghosts, reach: reach) {
      guard ghost.id != chosenID else { return .nothing }
      chosenID = ghost.id
      return .chose(ghost)
    }
    return putAway() ? .putAway : .nothing
  }

  /// Keep and Dismiss go away. True when they were showing.
  @discardableResult
  public mutating func putAway() -> Bool {
    let showing = chosen != nil
    chosenID = nil
    return showing
  }

  /// Keep all of `who`'s marks (story 895): they leave the ghosts, in the order they came, and Keep and Dismiss go with
  /// them if one was chosen. The caller turns them into ink.
  public mutating func keepAll(_ who: WhiteboardTurn.Who) -> [Ghost] {
    let kept = ghosts.filter { $0.who == who }
    if let chosen, chosen.who == who { chosenID = nil }
    ghosts.removeAll { $0.who == who }
    return kept
  }

  /// The marks still showing from the chosen mark's reply of Larry's, the chosen one among them, in the order they came;
  /// empty when nothing of his is chosen (#942, story 995).
  public func chosenReply() -> [Ghost] {
    guard let chosen, chosen.who == .larry, let reply = WhiteboardMarks.reply(of: chosen.id) else { return [] }
    return ghosts.filter { $0.who == .larry && WhiteboardMarks.reply(of: $0.id) == reply }
  }

  /// Keep group: the chosen mark's whole reply leaves the ghosts, in the order it came; the caller makes it ink, one
  /// group. Empty with nothing of his chosen.
  public mutating func keepChosenReply() -> [Ghost] {
    let reply = Set(chosenReply().map(\.id))
    guard !reply.isEmpty else { return [] }
    chosenID = nil
    let kept = ghosts.filter { reply.contains($0.id) }
    ghosts.removeAll { reply.contains($0.id) }
    return kept
  }

  /// Keep: the chosen mark leaves the ghosts; the caller turns it into ink. Nil with nothing chosen.
  public mutating func keepChosen() -> Ghost? { removeChosen() }

  /// Dismiss: the chosen mark goes, and only it. The rest of an answer on its way still lands.
  public mutating func dismissChosen() -> Ghost? { removeChosen() }

  private mutating func removeChosen() -> Ghost? {
    guard let ghost = chosen else { return nil }
    chosenID = nil
    ghosts.removeAll { $0.id == ghost.id }
    return ghost
  }
}

/// Where Keep and Dismiss sit beside a chosen mark (story 825): to its right, else its left, else below, else above,
/// and always wholly inside the view, moved inward at an edge. In the view's own points.
public enum WhiteboardMarkChoice {
  /// Between the mark and the buttons.
  public static let gap: CGFloat = 8
  /// Between the buttons and the view's edge.
  public static let margin: CGFloat = 8

  /// `avoid`: the board's top-right corner (? and Feedback, and the blocked chip), never under the buttons (story 1000).
  /// Placed there, they go below it, or else to its left.
  public static func place(mark: CGRect, buttons: CGSize, in view: CGRect, avoid: CGRect) -> CGRect {
    let placed = place(mark: mark, buttons: buttons, in: view)
    let corner = avoid.insetBy(dx: -gap, dy: -gap)
    guard !avoid.isNull, !avoid.isEmpty, placed.intersects(corner) else { return placed }
    let inside = view.insetBy(dx: margin, dy: margin)
    let below = CGRect(x: placed.minX, y: corner.maxY, width: placed.width, height: placed.height)
    if below.maxY <= inside.maxY { return below }
    return CGRect(
      x: max(inside.minX, corner.minX - placed.width), y: placed.minY, width: placed.width, height: placed.height)
  }

  public static func place(mark: CGRect, buttons: CGSize, in view: CGRect) -> CGRect {
    let inside = view.insetBy(dx: margin, dy: margin)
    let (w, h) = (min(buttons.width, inside.width), buttons.height)
    let beside = mark.midY - h / 2
    let candidates = [
      CGRect(x: mark.maxX + gap, y: beside, width: w, height: h),
      CGRect(x: mark.minX - gap - w, y: beside, width: w, height: h),
      CGRect(x: mark.midX - w / 2, y: mark.maxY + gap, width: w, height: h),
      CGRect(x: mark.midX - w / 2, y: mark.minY - gap - h, width: w, height: h),
    ]
    // The first side with room, judged across that side only; then held inside the view.
    let fits = [
      candidates[0].maxX <= inside.maxX, candidates[1].minX >= inside.minX,
      candidates[2].maxY <= inside.maxY, candidates[3].minY >= inside.minY,
    ]
    let chosen = zip(candidates, fits).first { $0.1 }?.0 ?? candidates[0]
    return CGRect(
      x: min(max(chosen.minX, inside.minX), inside.maxX - w), y: min(max(chosen.minY, inside.minY), inside.maxY - h),
      width: w, height: h)
  }

  /// The mark a tap takes (#941): the nearest within reach, and between two as near the later one, drawn on top. A box
  /// drawn before its label no longer takes every tap near its sides, the label's words included.
  public static func nearest<Mark>(_ marks: [Mark], reach: (Mark) -> CGFloat?) -> Mark? {
    var best: (mark: Mark, away: CGFloat)?
    for mark in marks {
      guard let away = reach(mark) else { continue }
      if let current = best, away > current.away { continue }
      best = (mark, away)
    }
    return best?.mark
  }

  /// Story 966 (#1170): whether a finger tap at `point` is on his own selection rather than for the marks: within
  /// `reach` of the selected ink's box, and reaching no mark. Such a tap keeps the selection, so its menu shows.
  public static func onSelection(_ selection: CGRect, at point: CGPoint, reach: CGFloat, onMark: Bool) -> Bool {
    guard !onMark, !selection.isNull else { return false }
    return selection.insetBy(dx: -reach, dy: -reach).contains(point)
  }

  /// A mark's box from its lines, in their own points; null for none.
  public static func bounds(_ lines: [[CGPoint]]) -> CGRect {
    let points = lines.joined()
    guard let first = points.first else { return .null }
    var box = CGRect(origin: first, size: .zero)
    for point in points.dropFirst() { box = box.union(CGRect(origin: point, size: .zero)) }
    return box
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
