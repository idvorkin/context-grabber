//  A whiteboard (spec 2026-11-01-whiteboard-design.md, stories 340–343, 347, 658): a column of pages on PaperKit with the
//  system tool picker, saved a moment after each stroke, and sent to Larry on the board's chat thread holding its picture
//  (the Inbox's image path, so it waits in the outbox when the network is away). A board another device draws, or one
//  drawn on the old canvas (gone 2026-11-07), opens to look at only. Claude's ghosts after a pause or spoken words and Larry's turn come back
//  as shapes, drawn faint until a tap keeps one (spec 2026-11-01-whiteboard-shapes-design.md, stories 344, 345, 349).
//  This file holds the board's model: its state, init and load. Each feature's methods are in
//  WhiteboardModel+<Feature>.swift; the SwiftUI view is WhiteboardView.swift (context-grabber-jp6z).

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

@MainActor
final class WhiteboardModel: ObservableObject {
  @Published var isEmpty: Bool
  /// What the last Send did, shown in the bar until the next stroke.
  @Published var sent: String?
  @Published var problem: BugProblem?
  /// The ghosts and the rules of Claude's turn: what shows, whose, for how long, and when Claude is asked (stories 344,
  /// 349, 351, 357, 358, 359, 367, 370). The host tests are `WhiteboardGhostTurnsTests`.
  @Published var turns: WhiteboardGhostTurns<Ghost> {
    didSet {
      if turns.ghosts.count != oldValue.ghosts.count {
        log.event(
          "whiteboard",
          [
            "action": "ghosts", "board": board.id, "count": turns.ghosts.count,
            "larry": turns.ghosts.filter { $0.who == .larry }.count,
          ])
      }
    }
  }
  /// Shapes Claude or Larry offered, faint on the board until a tap keeps one (stories 344, 349).
  var ghosts: [Ghost] { turns.ghosts }
  /// The width of the pen Igor last held on this board, in board points; nil until the canvas says. A label with no
  /// pen of its own shows and is kept at it (#949).
  var penInHand: CGFloat?
  /// Story 344's switch, remembered across boards.
  var ghostsOn: Bool { turns.on }
  /// Story 407's switch, remembered per board on this device. Lines on the board, never in the drawing or a picture.
  @Published var gridOn: Bool
  /// On paper only: a board has a grid, ruled lines or neither.
  @Published var ruledOn: Bool
  /// The board's colour (story 378).
  @Published var paper: BoardPaper
  /// How text made on the board from now on is lettered (#950, stories 1056–1058), remembered per board on this device.
  @Published var lettering: WhiteboardTurn.LetterStyle
  /// Who answers a pause: Haiku, Sonnet or Larry, the board's knob on the Cockpit (story 659).
  @Published var responder = WhiteboardResponderKnob()
  /// Larry's turn, one at a time, latest wins (story 662): while one is out the bar says he is looking.
  @Published var larry = WhiteboardLarryTurn()
  /// Larry's changes to the board, whoever sends them (stories 814–819): the board's revision (bumped on every change
  /// of the ink: what a held pause remembers, what a picture to Larry was of, and what his `base_rev` is checked against),
  /// the batches handled and the one held for the Pencil. Kept per board on this device.
  var ops: BoardOpApplier {
    didSet { if ops != oldValue { opLedger.save(ops, board: board.id) } }
  }
  /// The board's meaning (`BoardMeaning`): saved with the drawing here, written at once on a board looked at.
  let opLedger: BoardMeaningLedger
  /// Where his changes come from: today his board replies; later his own rules inside the app (story 819).
  var opSources: [any BoardOpSource] = [WebBoardOpSource()]
  /// The Pencil and taps since the last turn, for Larry (story 818).
  var events = BoardEvents()
  /// The mic, timed for the Cockpit's board debug page: spoken words wait here for the next picture (story 1112).
  var micClock = BoardMicClock()
  /// His texts Igor kept, known by their glyphs' time (story 817).
  var texts: [BoardText]
  /// The names Larry knows moved strokes by: a move never renames a stroke (stories 814, 815); his drawn strokes go by
  /// his names (story 840).
  var strokeIDs: BoardStrokeIDs
  /// Larry's notes on strokes, kept as he wrote them (story 842).
  var strokeMeta: BoardStrokeMeta
  /// Story 855: the board's headers and their folds, kept on this device by their strokes' names.
  var headers: [BoardHeader] {
    didSet { cachedLabelBoxes = nil }
  }
  /// Story 1034: the stroke names of lines he said were not headers, never offered a faint H again.
  var declined: Set<String> = []
  /// `labelBoxes()`'s answer for the ink and headers as they are.
  var cachedLabelBoxes: [CGRect]?
  /// Each element's ink hashes, to tell Larry what Igor added, erased and moved (story 843).
  var ink = BoardInk()
  /// The lasso's selection as last told (story 844).
  var selection: Set<String> = []
  /// Larry's controls on the board (story 845): live only while it is open.
  var overlays = BoardOverlays()
  /// The part of the board on screen as last told (story 850).
  var lastViewport: (rect: CGRect, scale: CGFloat)?
  /// The Pencil (or a drawing finger) is down, and when it last lifted: a change of Larry's waits for it (story 816).
  var penDown = false
  var liftedAt: ContinuousClock.Instant?
  var heldTask: Task<Void, Never>?
  /// The last turn in a line: Larry's words or ghosts not answering.
  var turnNote: String? { turns.note }
  /// The picture is on its way to Larry's thread.
  @Published var larrySending = false
  /// Twenty seconds into his turn, what the board offers: Retry and Dismiss for a picture the Cockpit hasn't taken,
  /// Interrupt for one he has (stories 775–777). Changed by the looks, every few seconds, and by the buttons.
  @Published var larryWait = WhiteboardLarryWait.none
  /// The picture out to Larry: what *Retry* sends again, and the furthest mark the Cockpit has put on its message.
  var larryOut: LarryOut?
  /// Story 1176: the board's *Send* waiting in the outbox, by its id, and whether the Inbox has listed it yet; the watch on
  /// the Inbox that says when it went.
  var sendOut: String?
  var sendListed = false
  var sendWatch: AnyCancellable?
  /// Counts the hand-offs, so one that Retry, Dismiss or Interrupt has replaced never frees the turn or speaks for the
  /// board.
  var larryHandOffs = WhiteboardLarryHandOffs()
  var larryWaitHook = LaunchHooks.current.whiteboard.larryWait
  /// Story 1143: the `whiteboard_turn` lines so far, Claude's and Larry's, so a touch's line says how many came while
  /// it was down.
  var turnsLogged = 0
  /// On paper: ink on the board, none of it on screen, so Send and Larry's turn have nothing to show him (story 522).
  @Published var nothingOnScreen = false
  /// Looking at Larry's thread has failed for a while (story 383).
  @Published var larryAway = false
  /// What the last paste left off or couldn't draw, shown until the board next changes (stories 392, 393).
  @Published var pasteNote: String?
  /// Stories 970–972: a change of Larry's that was refused, as a chip on the board until Retry, × or a change that
  /// applies.
  @Published var blocked = BoardBlockedEdit()
  var blockedFrame: CGRect?
  /// Story 1000: the board's top-right corner (? and Feedback, and the chip), window points, which the chosen mark's
  /// buttons keep clear of.
  @Published var cornerFrame: CGRect = .null
  /// The board's mic (story 345): open, on its way up and finishing its last words.
  @Published var micOn = false
  @Published var micStarting = false
  @Published var micFinishing = false
  /// Story 1103 (#1139): the microphone the open mic hears, by name; nil while it is closed.
  @Published var micHears: String?
  /// Stories 954, 956–958: the board playing back over itself (WhiteboardPlayback.swift); nil while it isn't.
  @Published var playback: WhiteboardPlaybackPlayer?
  /// Story 1103: the mic is on its way to opening (its microphones being listed, or a new pick reopening it); a close
  /// meanwhile clears it, and the opening doesn't happen.
  var micOpening = false
  /// The newest thing said, by Larry or the mic: the middle of the note's line (story 766).
  @Published var lastSaid = WhiteboardSaid()
  /// The note's other messages and when they appeared: they take the line's middle for a few seconds, or for as long
  /// as the Cockpit isn't answering (story 766).
  @Published private(set) var notice: WhiteboardNote.Notice?
  /// The recent end of the board's thread, from the looks that bring Larry's marks: the open note's panel (story 768).
  @Published var thread: [ChatMessage] = []
  /// Larry is holding for more on Igor's newest message, in his words: the note's ear (story 929); nil otherwise.
  @Published var larryListening: String?
  /// The note's panel is open, remembered for the next board (story 768).
  @Published var conversationOpen = UserDefaults.standard.bool(forKey: WhiteboardModel.conversationKey)
  let board: BoardEntry
  /// Drawn on here, or only looked at: a board from another device (story 347) or from the old canvas (story 658).
  let editable: Bool
  /// Drawn on the old canvas: its ink is moved onto pages to be shown, and it can't be sent (story 658).
  let oldCanvas: Bool
  /// Why it's only looked at, for the bar; nil on a board drawn on here.
  let lookOnlyNote: String?
  @Published var drawing: PKDrawing
  /// Larry's open asks as cards on the board (stories 880–886).
  let questions: WhiteboardQuestionsModel
  let store: WhiteboardStore
  let log: SessionLog
  let inbox: InboxModel
  let cockpit: String
  let threads = WhiteboardThreads()
  /// #894 (story 1006): when each picture sent to Larry was taken, so his reply knows what was written after it.
  let pictureTimes = WhiteboardPictureTimes()
  /// #1013: each picture's map through the folds it drew open, for the marks Larry draws on it.
  let pictureFolds = WhiteboardPictureFolds()
  /// The canvas the board is shown on, once it has loaded: where the view is, and the changes to the ink only it can make.
  weak var canvas: (any BoardCanvas)?
  /// Where a paste may land, in board points; a board on paper sets its own.
  var pasteReach = WhiteboardPaste.wholeBoard
  /// #965 (stories 1008, 1009): the bar's Undo and Redo, as the board's undo stack stands; the canvas keeps it current.
  @Published var undoButtons = BoardUndoButtons.none
  let callLive: @MainActor () -> Bool
  lazy var dictation = makeDictation()
  var dictationWatches: Set<AnyCancellable> = []
  private var noticeWatch: AnyCancellable?
  var speech = WhiteboardSpeech()
  var silenceTask: Task<Void, Never>?
  var pauseTask: Task<Void, Never>?
  /// Stories 892, 893: how long the pause waits, learned from his rhythm, and the look for his hand having left.
  var vad = WhiteboardWritingVad()
  var awayTask: Task<Void, Never>?
  /// Claude's answer being read, which the Pencil going down stops (story 894).
  var claudeReading: Task<WhiteboardStream.Read, Never>?
  var fadeTask: Task<Void, Never>?
  var saveTask: Task<Void, Never>?
  /// Ink not saved yet; a board on paper's page number says so (story 673: what a UI test waits on, not a fixed second).
  @Published var dirty = false
  var saveFailing = false
  var marks = WhiteboardMarks()
  /// On paper: each stroke's box, for what's on screen (story 433), and the frame the last Send showed.
  var inkBoxes: [CGRect] = []
  var sentFrame: CGRect?
  /// The part of the board in the picture Larry's turn last took: a tap with another part on screen sends (story 765).
  var larryFrame: CGRect?
  var watchTask: Task<Void, Never>?
  var lookFailures = 0

  static let ghostsKey = "whiteboard_ghosts"
  static let conversationKey = "whiteboard_conversation_open"
  /// A pasted letter's height on screen, in points, at 100% and zoomed out.
  static let pasteLetters: CGFloat = 24
  /// How long Claude's ghosts stay when nothing replaces them.
  static let ghostSeconds = LaunchHooks.current.whiteboard.ghostSeconds ?? 30
  /// How long a turn of Larry's is out before the board stops waiting.
  static let larryTimeout: Duration =
    LaunchHooks.current.whiteboard.larryTimeout.map { .seconds($0.seconds) } ?? WhiteboardLarryTurn.timeout
  /// How often an open board looks at its thread, how long one look waits, and how many failed looks before the bar
  /// says so.
  static let lookEvery: Duration = .seconds(3)
  static let lookTimeout: TimeInterval = 3
  static let awayAfter = 3

  init(
    board: BoardEntry, store: WhiteboardStore, log: SessionLog, inbox: InboxModel, cockpit: String,
    callLive: @escaping @MainActor () -> Bool
  ) {
    self.callLive = callLive
    self.board = board
    paper = board.paper
    self.store = store
    self.log = log
    // #1083 (story 1063): the first stroke of each kind of ink the app has no name for, so the log says what it was.
    WhiteboardInk.onUnknown = { [log] ink, place, points in
      log.event("whiteboard", ["action": "unknown_ink", "ink": ink ?? "none", "where": place, "points": points])
    }
    self.inbox = inbox
    self.cockpit = cockpit
    opLedger = BoardMeaningLedger(board: board.id, meaning: store.meaning(board.id))
    questions = WhiteboardQuestionsModel(board: board.id, log: log, inbox: inbox, cockpit: cockpit, ledger: opLedger)
    turns = WhiteboardGhostTurns(
      on: UserDefaults.standard.object(forKey: Self.ghostsKey) as? Bool ?? true, ghostLife: .seconds(Self.ghostSeconds))
    let lines = BoardLines().choice(board.id)
    lettering = BoardLetteringChoice().choice(board.id)
    gridOn = lines == .grid
    ruledOn = lines == .ruled
    let (loaded, loadProblem, held) = Self.load(board, from: store, log: log)
    // #1042: an unreadable drawing left in place opens look-only, so no stroke saves over it.
    editable = store.drawable(board) && !held
    oldCanvas = BoardIndex.drawnOnTheOldCanvas(board)
    lookOnlyNote = held ? "Couldn't be read: look only" : store.lookOnlyNote(board)
    ops = opLedger.applier(board: board.id)
    texts = opLedger.texts(board: board.id)
    strokeIDs = opLedger.strokeIDs(board: board.id)
    strokeMeta = opLedger.strokeMeta(board: board.id)
    headers = opLedger.headers(board: board.id)
    declined = opLedger.declined(board: board.id)
    problem = loadProblem
    drawing = loaded
    isEmpty = loaded.strokes.isEmpty
    inkBoxes = loaded.strokes.map(\.renderBounds)
    cachedLabelBoxes = nil
    log.event(
      "whiteboard",
      [
        "action": "open", "board": board.id, "strokes": loaded.strokes.count, "editable": editable,
        "old_canvas": oldCanvas, "look_only": lookOnlyNote as Any? ?? NSNull(),
      ])
    if LaunchHooks.current.whiteboard.grid { setGrid(true) }
    watchNotices()
    checkMeaningBehind()
    opLedger.onChange = { [weak self] in self?.meaningChanged() }
    // Story 926: Talk's long press reads the dictation from the first frame; made here, its watches' first values land
    // before any view observes the model, not inside a view update.
    _ = dictation
  }

  /// The meaning was saved with a drawing of another size: a save was cut off between the two files, so a batch of
  /// Larry's in that drawing may come again. The log line settles whether it ever happens (story 1106).
  private func checkMeaningBehind() {
    guard let saved = opLedger.meaning.inkBytes, let read = store.drawingBytes(board.id), saved != read else { return }
    log.event(
      "whiteboard", ["action": "meaning_behind", "board": board.id, "meaning_ink_bytes": saved, "ink_bytes": read])
  }

  /// The board's meaning changed: drawn on here it goes with the next save of the drawing, a second on; looked at, it
  /// is written now, as nothing of the ink is saved.
  private func meaningChanged() {
    guard editable else {
      writeMeaning()
      return
    }
    saveSoon()
  }

  func writeMeaning() {
    do {
      try store.saveMeaning(opLedger.meaning, board: board.id)
      opLedger.wrote(opLedger.meaning)
    } catch {
      log.event(
        "error", ["where": "whiteboard_meaning", "board": board.id, "operation": "save", "message": "\(error)"])
    }
  }

  /// The save a second after the last change, ink or meaning.
  func saveSoon() {
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.save(.debounce)
    }
  }

  /// The board's drawing as it opens, and a copyable problem when it can't be read: moved aside, the board starts
  /// afresh; left in place because the move failed, it is held, look-only, so nothing saves over it (#1042).
  private static func load(
    _ board: BoardEntry, from store: WhiteboardStore, log: SessionLog
  ) -> (PKDrawing, BugProblem?, held: Bool) {
    do {
      return (try store.drawing(board.id), nil, false)
    } catch {
      let unreadable = error as? UnreadableDrawing
      let reason = unreadable?.reason ?? error
      let stuck = unreadable?.stuck
      log.event(
        "error",
        [
          "where": "whiteboard_load", "message": "\(reason)", "board": board.id, "set_aside": stuck == nil,
          "kept_at": unreadable?.keptAt?.lastPathComponent as Any? ?? NSNull(),
          "move_error": stuck.map { "\($0)" } as Any? ?? NSNull(),
        ])
      var extra: [String: JSONValue] = [
        "board": .string(board.id), "operation": .string("open"), "reason": .string("\(reason)"),
      ]
      if let kept = unreadable?.keptAt { extra["kept_at"] = .string(kept.lastPathComponent) }
      if let stuck { extra["move_error"] = .string("\(stuck)") }
      let message =
        stuck == nil
        ? "This board could not be read, so its drawing was set aside and the board starts empty: "
          + reason.localizedDescription
        : "This board could not be read or moved aside, so it is left as it was and opens look-only; nothing is "
          + "saved over it: " + reason.localizedDescription
      return (PKDrawing(), .grabber(message, context: "WhiteboardView.load", extra: extra), stuck != nil)
    }
  }

  /// Story 766: when the note's other messages change, so a new one takes the line's middle for its few seconds.
  private func watchNotices() {
    let lookOnly = lookOnlyNote
    noticeWatch = $pasteNote.combineLatest($sent, $turns.map(\.note), $larryAway.combineLatest($larry.map(\.looking)))
      .map { paste, sent, turnNote, away in
        WhiteboardNote.notice(
          paste: paste, sent: sent, turnNote: turnNote, marksAway: away.0, looking: away.1, lookOnly: lookOnly)
      }
      .removeDuplicates { $0?.text == $1?.text }
      .sink { [weak self] words in
        MainActor.assumeIsolated {
          self?.notice = words.map { WhiteboardNote.Notice(text: $0.text, held: $0.held, since: .now) }
        }
      }
  }
}
