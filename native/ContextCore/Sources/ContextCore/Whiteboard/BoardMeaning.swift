//  What a board means beyond its ink, kept in one file beside its drawing (bead context-grabber-cc75, plan
//  2026-11-21-whiteboard-board-meaning-plan.md): the revision Larry's changes are checked against and the batches
//  already handled, his kept texts, the names moved strokes keep, his notes and groups, the headers and their folds,
//  the question cards, the kept labels and which ink is Larry's. On the device that draws the board it is written with the drawing, in the same save, so a
//  batch of Larry's is remembered as handled only once its ink is on disk (story 1106). It used to be six UserDefaults
//  keys per board (`BoardOpLedger`), moved here once (`BoardKeeping.migrateMeaning`).

import Foundation

public struct BoardMeaning: Codable, Equatable, Sendable {
  /// The file's own version, for a later build that changes it.
  public static let currentVersion = 1

  public var version = BoardMeaning.currentVersion
  /// `BoardOpApplier`'s revision, handled batches and last result.
  public var rev = 0
  public var handled: [String] = []
  public var lastResult: BoardOps.Result?
  /// Larry's texts Igor kept, known by their glyphs' time (story 817).
  public var texts: [BoardText] = []
  /// The names moved strokes keep (stories 814, 815, 840).
  public var strokeIDs = BoardStrokeIDs()
  /// Larry's notes on strokes (story 842).
  public var strokeMeta = BoardStrokeMeta()
  /// The board's headers and their folds (story 855).
  public var headers: [BoardHeader] = []
  /// The question cards (stories 880–886).
  public var questions = WhiteboardQuestions()
  /// The creation moments (ms) of kept labels and pastes, the ink *Tidy overlaps* lays out (story 896).
  public var labels: [Int64] = []
  /// The creation moments (ms) of ink Larry or Claude made (a mark kept, his ink or text), so it never makes room as
  /// Igor's (#894).
  public var theirs: [Int64] = []
  /// Story 1143: the reply of Larry's each piece kept with plain Keep came in, by its moment (ms, as text), so a tap
  /// on one picks up every piece of that reply. Only moments still in `theirs` are kept.
  public var replies: [String: String] = [:]
  /// The most label and Larry's-ink moments remembered per board; the oldest go first.
  public static let mostLabels = 2000
  public static let mostTheirs = 4000
  /// The size in bytes of the drawing file this was last written with; nil before the first save with ink. Read on
  /// open against the drawing on disk: a difference means a save was cut off between the two files.
  public var inkBytes: Int?

  public init() {}

  enum CodingKeys: String, CodingKey {
    case version, rev, handled, lastResult, texts, strokeIDs, strokeMeta, headers, questions, labels, theirs, replies
    case inkBytes
  }

  /// Every part optional, so a file from an older or newer build still reads.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
    rev = try c.decodeIfPresent(Int.self, forKey: .rev) ?? 0
    handled = try c.decodeIfPresent([String].self, forKey: .handled) ?? []
    lastResult = try c.decodeIfPresent(BoardOps.Result.self, forKey: .lastResult)
    texts = try c.decodeIfPresent([BoardText].self, forKey: .texts) ?? []
    strokeIDs = try c.decodeIfPresent(BoardStrokeIDs.self, forKey: .strokeIDs) ?? BoardStrokeIDs()
    strokeMeta = try c.decodeIfPresent(BoardStrokeMeta.self, forKey: .strokeMeta) ?? BoardStrokeMeta()
    headers = try c.decodeIfPresent([BoardHeader].self, forKey: .headers) ?? []
    questions = try c.decodeIfPresent(WhiteboardQuestions.self, forKey: .questions) ?? WhiteboardQuestions()
    labels = try c.decodeIfPresent([Int64].self, forKey: .labels) ?? []
    theirs = try c.decodeIfPresent([Int64].self, forKey: .theirs) ?? []
    replies = try c.decodeIfPresent([String: String].self, forKey: .replies) ?? [:]
    inkBytes = try c.decodeIfPresent(Int.self, forKey: .inkBytes)
  }

  /// The applier as this was saved: a relaunch starts remembering touches afresh (story 961).
  public var applier: BoardOpApplier { BoardOpApplier(rev: rev, handled: handled, lastResult: lastResult) }

  /// The applier as it is to be saved. A batch held for the Pencil or still on its way to the canvas isn't saved as
  /// handled yet: its ink isn't on the board, so a relaunch offers it again (story 1106). Once the canvas has answered,
  /// it is.
  public mutating func take(_ applier: BoardOpApplier) {
    rev = applier.rev
    let pending = Set([applier.held?.key, applier.applying].compactMap { $0 })
    handled = applier.handled.filter { !pending.contains($0) }
    lastResult = applier.lastResult
  }

  /// What the migration's log line says it moved.
  public var counts: [String: Int] {
    [
      "rev": rev, "handled": handled.count, "texts": texts.count, "headers": headers.count,
      "cards": questions.cards.count, "labels": labels.count, "theirs": theirs.count, "replies": replies.count,
    ]
  }
}

/// One open board's meaning, as its model changes it: each change is told (`onChange`), so the model saves it with
/// the drawing, and what was last written is remembered, so a save with nothing new writes nothing. The methods are
/// `BoardOpLedger`'s, which this replaced; `board` must be the ledger's own.
public final class BoardMeaningLedger: @unchecked Sendable {
  public let board: String
  public private(set) var meaning: BoardMeaning
  /// What the board's file holds.
  public private(set) var written: BoardMeaning
  /// Called after every change that leaves the meaning different.
  public var onChange: (() -> Void)?

  public init(board: String, meaning: BoardMeaning) {
    self.board = board
    self.meaning = meaning
    written = meaning
  }

  /// Changed since the file was last written.
  public var unsaved: Bool { meaning != written }

  /// The file now holds `saved`: the meaning as it was handed to the save, with the drawing's size it went with.
  public func wrote(_ saved: BoardMeaning) {
    meaning.inkBytes = saved.inkBytes
    written = saved
  }

  private func change(_ board: String, _ edit: (inout BoardMeaning) -> Void) {
    guard board == self.board else {
      assertionFailure("ledger for \(self.board) asked about \(board)")
      return
    }
    let before = meaning
    edit(&meaning)
    if meaning != before { onChange?() }
  }

  public func applier(board: String) -> BoardOpApplier { meaning.applier }
  public func save(_ applier: BoardOpApplier, board: String) { change(board) { $0.take(applier) } }

  public func headers(board: String) -> [BoardHeader] { meaning.headers }
  public func setHeaders(_ headers: [BoardHeader], board: String) { change(board) { $0.headers = headers } }

  public func strokeMeta(board: String) -> BoardStrokeMeta { meaning.strokeMeta }
  public func setStrokeMeta(_ meta: BoardStrokeMeta, board: String) { change(board) { $0.strokeMeta = meta } }

  public func strokeIDs(board: String) -> BoardStrokeIDs { meaning.strokeIDs }
  public func setStrokeIDs(_ ids: BoardStrokeIDs, board: String) { change(board) { $0.strokeIDs = ids } }

  public func texts(board: String) -> [BoardText] { meaning.texts }
  public func setTexts(_ texts: [BoardText], board: String) {
    change(board) { $0.texts = Array(texts.suffix(BoardOpLedger.mostTexts)) }
  }

  public func labels(board: String) -> Set<Int64> { Set(meaning.labels) }
  public func rememberLabels(_ moments: [Int64], board: String) {
    guard !moments.isEmpty else { return }
    change(board) { $0.labels = Array(($0.labels + moments).suffix(BoardMeaning.mostLabels)) }
  }

  public func theirs(board: String) -> Set<Int64> { Set(meaning.theirs) }
  public func rememberTheirs(_ moments: [Int64], board: String) {
    guard !moments.isEmpty else { return }
    change(board) {
      $0.theirs = Array(($0.theirs + moments).suffix(BoardMeaning.mostTheirs))
      Self.prune(&$0)
    }
  }

  /// Story 1143: the reply of Larry's each of these moments' pieces came in, by moment.
  public func replies(board: String) -> [Int64: String] {
    Dictionary(meaning.replies.compactMap { key, reply in Int64(key).map { ($0, reply) } }) { a, _ in a }
  }

  /// Story 1143: `moments`, pieces of Larry's kept with plain Keep, came in `reply`. Remembered once the moments are
  /// his (`rememberTheirs`), and forgotten with them.
  public func rememberReply(_ moments: [Int64], reply: String, board: String) {
    guard !moments.isEmpty else { return }
    change(board) {
      for moment in moments { $0.replies[String(moment)] = reply }
      Self.prune(&$0)
    }
  }

  /// The replies of moments no longer remembered as theirs go with them.
  private static func prune(_ meaning: inout BoardMeaning) {
    guard !meaning.replies.isEmpty else { return }
    let theirs = Set(meaning.theirs.map(String.init))
    meaning.replies = meaning.replies.filter { theirs.contains($0.key) }
  }

  public func questions(board: String) -> WhiteboardQuestions { meaning.questions }
  public func setQuestions(_ questions: WhiteboardQuestions, board: String) {
    change(board) { $0.questions = questions }
  }
}

/// Where a board's kept labels and Larry's ink were remembered before they joined its meaning file (bead
/// context-grabber-p1pl): two UserDefaults keys per board on this device, each a list of creation moments. Read now
/// only to move them into the file (`BoardKeeping.migrateInkIdentity`), and to fill the board as it opens until then.
public struct BoardInkKeys: @unchecked Sendable {
  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public static func labelsKey(_ board: String) -> String { "whiteboard_labels_\(board)" }
  public static func theirsKey(_ board: String) -> String { "whiteboard_theirs_\(board)" }

  /// The moments a key holds; nil when the board has no such key.
  public func labels(board: String) -> [Int64]? { moments(Self.labelsKey(board)) }
  public func theirs(board: String) -> [Int64]? { moments(Self.theirsKey(board)) }

  private func moments(_ key: String) -> [Int64]? {
    guard let list = defaults.array(forKey: key) else { return nil }
    return list.compactMap { ($0 as? NSNumber)?.int64Value }
  }

  /// Whether the board still has either key.
  public func any(board: String) -> Bool { labels(board: board) != nil || theirs(board: board) != nil }

  /// The keys' moments added to the meaning's, never in place of them: what the meaning already holds stays, in its
  /// order, after the keys' older moments it lacks.
  public func fill(_ meaning: inout BoardMeaning, board: String) {
    if let labels = labels(board: board) {
      meaning.labels = Array(Self.adding(labels, to: meaning.labels).suffix(BoardMeaning.mostLabels))
    }
    if let theirs = theirs(board: board) {
      meaning.theirs = Array(Self.adding(theirs, to: meaning.theirs).suffix(BoardMeaning.mostTheirs))
    }
  }

  private static func adding(_ old: [Int64], to held: [Int64]) -> [Int64] {
    let have = Set(held)
    return old.filter { !have.contains($0) } + held
  }

  /// The board's two keys, gone once its file holds what they did.
  public func forget(board: String) {
    defaults.removeObject(forKey: Self.labelsKey(board))
    defaults.removeObject(forKey: Self.theirsKey(board))
  }
}

/// Every UserDefaults key this device keeps for one board, its meaning's old keys and its own view of it alike: the
/// board's thread, its pictures' times and folds, the marks settled, where the paper was, its lines and lettering (and
/// labels and Larry's ink, until they move into the board's file). A delete forgets them all.
public enum BoardDeviceKeys {
  public static func keys(of board: String, in defaults: UserDefaults) -> [String] {
    let suffix = "_\(board)"
    return defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("whiteboard_") && $0.hasSuffix(suffix) }
      .sorted()
  }

  /// Removes them, and says how many there were.
  @discardableResult
  public static func forget(_ board: String, in defaults: UserDefaults = .standard) -> Int {
    let keys = keys(of: board, in: defaults)
    for key in keys { defaults.removeObject(forKey: key) }
    return keys.count
  }
}
