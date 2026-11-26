//  Larry's marks on a board (spec 2026-11-01-whiteboard-shapes-design.md, stories 380–384, cockpit#85). A picture goes
//  to the board's chat thread with where it sits on the board; Larry's rows come back with shapes in that picture's
//  pixels and the same place. Here: what a picture carries, his rows as the app reads them, and which row to show.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// A board's picture on its way to Larry: the three fields the Cockpit stores on the row and echoes.
public struct WhiteboardPicture: Codable, Equatable, Sendable {
  public struct Frame: Codable, Equatable, Sendable {
    /// In board points; `scale` is the picture's pixels per point.
    public let x: Double
    public let y: Double
    public let w: Double
    public let h: Double
    public let scale: Double
  }

  public let board: String
  /// A new one for each picture.
  public let pictureID: String
  public let frame: Frame
  /// The board's name when the picture was taken: the thread's title when this picture starts it, and `board_title` on
  /// every picture, so a renamed board renames its chat (story 1101, bead context-grabber-8rei).
  public let title: String
  /// The board's half of the turn (story 818): its revision, what came of Larry's last change, the Pencil and taps. On
  /// the chat message only, never on the strokes.
  public var report: BoardTurnReport?

  public init(
    board: String, title: String, rect: CGRect, scale: CGFloat, pictureID: String = UUID().uuidString.lowercased(),
    report: BoardTurnReport? = nil
  ) {
    self.board = board
    self.report = report
    self.title = title
    self.pictureID = pictureID
    frame = Frame(
      x: Double(rect.minX), y: Double(rect.minY), w: Double(rect.width), h: Double(rect.height), scale: Double(scale))
  }

  /// #1013: the folded sections the picture draws open, and how its places map onto the folded board.
  public var folds: BoardFoldMap?
  /// The app's `<sha> <branch>`, on the chat message for the Cockpit's board debug page (story 1112).
  public var build: String?

  enum CodingKeys: String, CodingKey {
    case board, frame, title, report, folds, build
    case pictureID = "picture_id"
  }

  public var wire: [String: Any] {
    var out: [String: Any] = [
      "board": board, "picture_id": pictureID,
      "frame": ["x": frame.x, "y": frame.y, "w": frame.w, "h": frame.h, "scale": frame.scale],
    ]
    if let folds, !folds.steps.isEmpty { out["picture_folds"] = folds.wire }
    if let build, !build.isEmpty { out["build"] = build }
    if !title.isEmpty { out["board_title"] = title }
    return out
  }
}

#if !FOUNDATION_ESSENTIALS_ONLY
  /// Each board's one chat thread on this device, by board id. ponytail: UserDefaults on this device; the board's iCloud
  /// copy carries the drawing device's (#1161), and `board(_:carried:drawnHere:)` picks between them (story 1158).
  public struct WhiteboardThreads: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
    }

    private func key(_ board: String) -> String { "whiteboard_thread_\(board)" }

    public func thread(board: String) -> String? { defaults.string(forKey: key(board)) }

    /// Story 1158 (bead context-grabber-da1): the board's one conversation, which every picture of it goes to and the note
    /// opens. On the device that drew the board its own thread, which is what its iCloud copy carries, else the carried
    /// one (a reinstall); on any other device the carried one, else its own. A thread the Cockpit said is gone is never
    /// used. `carried`: the thread the board's iCloud copy carries (#1161).
    public func board(_ board: String, carried: String?, drawnHere: Bool) -> String? {
      let carried = carried.flatMap { $0 == defaults.string(forKey: goneKey(board)) ? nil : $0 }
      let own = thread(board: board)
      return drawnHere ? own ?? carried : carried ?? own
    }

    /// A thread the Cockpit said is gone (context-grabber-e3vb): the board's iCloud copy may still carry it, and only the
    /// drawing device's sync clears it there, so it stays gone after a new thread starts; a thread id is never reused.
    /// Its own prefix, so `all()` never reads it as a board.
    private func goneKey(_ board: String) -> String { "whiteboard_gone_thread_\(board)" }

    public func set(_ thread: String, board: String) {
      defaults.set(thread, forKey: key(board))
    }

    /// Every board this device has a thread for, board id to thread (#1091: a thread's *Board* finds its board).
    public func all() -> [String: String] {
      let prefix = key("")
      var out: [String: String] = [:]
      for (name, value) in defaults.dictionaryRepresentation() where name.hasPrefix(prefix) {
        if let thread = value as? String { out[String(name.dropFirst(prefix.count))] = thread }
      }
      return out
    }

    /// The Cockpit no longer has `thread`: it is remembered as gone, so it is never used again and the board's iCloud
    /// copy stops carrying it (context-grabber-e3vb), whether it was this device's own or the one the board carries
    /// (story 1158). A newer thread of this device's own stays. True when this learned something new.
    @discardableResult
    public func forget(_ thread: String, board: String) -> Bool {
      let own = self.thread(board: board) == thread
      let known = defaults.string(forKey: goneKey(board)) == thread
      if own { defaults.removeObject(forKey: key(board)) }
      defaults.set(thread, forKey: goneKey(board))
      return own || !known
    }

    /// Every board with a thread the Cockpit said is gone, board id to that thread.
    public func gone() -> [String: String] {
      let prefix = goneKey("")
      var out: [String: String] = [:]
      for (name, value) in defaults.dictionaryRepresentation() where name.hasPrefix(prefix) {
        if let thread = value as? String { out[String(name.dropFirst(prefix.count))] = thread }
      }
      return out
    }
  }
#endif

#if !FOUNDATION_ESSENTIALS_ONLY
  /// When each picture this device sent Larry was taken, unix ms, per board (#894, story 1006): a reply names its picture,
  /// and the ink made after that moment is what he couldn't have seen. Kept across launches, so a reply that lands with
  /// the board closed knows too. ponytail: UserDefaults on this device, the newest `kept` a board; a picture sent from
  /// another device isn't known, and its reply keeps with nothing moved.
  public struct WhiteboardPictureTimes: @unchecked Sendable {
    public static let kept = 200
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
    }

    private func key(_ board: String) -> String { "whiteboard_picture_times_\(board)" }

    /// "<picture id> <ms>", oldest first.
    private func entries(_ board: String) -> [String] { defaults.stringArray(forKey: key(board)) ?? [] }

    public func record(_ pictureID: String, at ms: Int64, board: String) {
      let others = entries(board).filter { !$0.hasPrefix("\(pictureID) ") }
      defaults.set(Array((others + ["\(pictureID) \(ms)"]).suffix(Self.kept)), forKey: key(board))
    }

    /// When the picture before `pictureID` was taken on this board: what Igor made after it is what that picture's
    /// reply answers (story 1354). Nil for the first, or one this device doesn't remember.
    public func before(_ pictureID: String?, board: String) -> Int64? {
      guard let pictureID, let at = entries(board).lastIndex(where: { $0.hasPrefix("\(pictureID) ") }), at > 0 else {
        return nil
      }
      let entry = entries(board)[at - 1]
      return entry.split(separator: " ").last.flatMap { Int64($0) }
    }

    /// When `pictureID` was taken on this board; nil for one this device doesn't remember.
    public func taken(_ pictureID: String?, board: String) -> Int64? {
      guard let pictureID else { return nil }
      return entries(board).last { $0.hasPrefix("\(pictureID) ") }.flatMap { Int64($0.dropFirst(pictureID.count + 1)) }
    }
  }
#endif

public struct WhiteboardMarks: Sendable {
  /// One of Larry's rows on the thread.
  public struct Row: Equatable, Sendable {
    public let id: String
    public let text: String
    public let shapes: [WhiteboardTurn.Shape]
    public let pictureID: String?
    /// The row's own place on the board (only its origin matters), and pixels per point. Nil when it has none or one
    /// that can't be right: its shapes can't be placed.
    public let frame: CGRect?
    public let scale: CGFloat
    /// Larry's changes to the board on this row (stories 814–817), for `WebBoardOpSource`.
    public let ops: BoardOps.Batch?
    /// The buttons beside this reply's marks, in its order (stories 1352–1354, #1525), and the choices it named that
    /// this build doesn't know.
    public let actions: [WhiteboardMarkActions.Offer]
    public let unknownActions: [String]

    public var drawable: Bool { frame != nil && !shapes.isEmpty }

    public var drawing: Drawing? {
      guard let frame, !shapes.isEmpty else { return nil }
      return Drawing(
        id: id, shapes: shapes, pictureID: pictureID, frame: frame, scale: scale,
        actions: actions == WhiteboardMarkActions.standard ? nil : actions)
    }

    public init(
      id: String, text: String = "", shapes: [WhiteboardTurn.Shape] = [], pictureID: String? = nil,
      frame: CGRect? = nil, scale: CGFloat = 1, ops: BoardOps.Batch? = nil,
      actions: [WhiteboardMarkActions.Offer] = WhiteboardMarkActions.standard, unknownActions: [String] = []
    ) {
      self.id = id
      self.ops = ops
      self.actions = actions
      self.unknownActions = unknownActions
      self.text = text
      self.shapes = shapes
      self.pictureID = pictureID
      self.frame = frame
      self.scale = scale
    }
  }

  public struct Drawing: Codable, Equatable, Sendable {
    public let id: String
    public let shapes: [WhiteboardTurn.Shape]
    public let pictureID: String?
    public let frame: CGRect
    public let scale: CGFloat
    /// The reply's buttons when they aren't Keep and Dismiss (story 1352); nil in a history from before them.
    public var actions: [WhiteboardMarkActions.Offer]? = nil

    /// The buttons beside this reply's marks.
    public var offers: [WhiteboardMarkActions.Offer] { actions ?? WhiteboardMarkActions.standard }
  }

  public struct History: Codable, Sendable {
    public private(set) var showing: [Drawing] = []
    public private(set) var settled: [String]
    public private(set) var done: [String]
    public var newest: String?

    public init(settled: [String] = [], done: [String] = []) {
      self.settled = settled
      self.done = done
    }

    public func restore(excluding present: Set<String>) -> [Drawing] {
      showing.filter { !present.contains($0.id) }
    }

    public mutating func place(_ drawing: Drawing, shown: [String], nowhere: [String] = []) {
      if !shown.isEmpty {
        if let existing = showing.firstIndex(where: { $0.id == drawing.id }) {
          showing[existing] = drawing
        } else {
          showing = Array((showing + [drawing]).suffix(WhiteboardMarks.rowsKept))
          pruneSettled()
        }
      }
      for mark in nowhere { settle(mark, left: shown) }
    }

    public mutating func settle(_ mark: String, left: [String]) {
      guard let row = WhiteboardMarks.reply(of: mark) else { return }
      if left.contains(where: { WhiteboardMarks.reply(of: $0) == row }) {
        if showing.contains(where: { $0.id == row }), !settled.contains(mark) { settled.append(mark) }
      } else {
        showing.removeAll { $0.id == row }
        pruneSettled()
        let recent = done.filter { $0 != row } + [row]
        let pinned = newest.flatMap { recent.contains($0) ? $0 : nil }
        let others = recent.filter { $0 != pinned }
        done = Array(others.suffix(WhiteboardMarks.rowsKept - (pinned == nil ? 0 : 1))) + (pinned.map { [$0] } ?? [])
      }
    }

    private mutating func pruneSettled() {
      let rows = Set(showing.map(\.id))
      settled.removeAll { WhiteboardMarks.reply(of: $0).map(rows.contains) != true }
    }
  }

  /// What a look at the thread changes.
  public struct Update: Equatable, Sendable {
    /// The rows whose marks now show, oldest first, joining his unkept ones (bead context-grabber-n8ab, story 1155).
    public var marks: [Row] = []
    /// His newest words.
    public var say: String?
    /// New rows whose shapes have nowhere to go.
    public var unplaced: [String] = []
    /// He answered since the last look: a new row of his, marks or not (story 662). Never on the first look, whose rows
    /// were there before.
    public var replied = false

    public init(marks: [Row] = [], say: String? = nil, unplaced: [String] = [], replied: Bool = false) {
      self.marks = marks
      self.say = say
      self.unplaced = unplaced
      self.replied = replied
    }
  }

  private var seen: Set<String>?

  public init() {}

  /// The board's own turn opened the thread: nothing was on it before, so every row the first look finds is his answer,
  /// however soon it came.
  public mutating func threadStarted() { seen = [] }

  /// `rows`: Larry's, oldest first. `settled`: the rows Igor kept or dismissed every mark of. `showing`: the rows
  /// still showing on this device when the board last closed. The first look shows those and the
  /// newest row of marks, unless that one is settled or has nowhere to go; after that, every new one (story 1155).
  public mutating func take(_ rows: [Row], settled: Set<String>, showing: [String] = []) -> Update {
    var update = Update()
    if let seen {
      let new = rows.filter { !seen.contains($0.id) }
      update.replied = !new.isEmpty
      update.marks = new.filter { $0.drawable && !settled.contains($0.id) }
      update.say = new.last { !$0.text.isEmpty }?.text
      update.unplaced = new.filter { !$0.drawable && !$0.shapes.isEmpty }.map(\.id)
    } else {
      let newest = rows.last(where: { !$0.shapes.isEmpty }).flatMap { settled.contains($0.id) ? nil : $0 }
      update.marks = rows.filter {
        $0.drawable && !settled.contains($0.id) && $0.id != newest?.id && showing.contains($0.id)
      }
      if let newest, newest.drawable {
        update.marks.append(newest)
        update.say = newest.text.isEmpty ? nil : newest.text
      } else if let newest {
        update.unplaced = [newest.id]
      }
    }
    seen = Set(rows.map(\.id))
    return update
  }

  /// Story 808: one of Larry's marks, by its row and its place in the row. A kept or dismissed one is remembered by it,
  /// so it alone stays gone when the board opens again.
  public static func mark(_ index: Int, of row: String) -> String { "\(row)#\(index)" }

  /// The reply a mark of Larry's came in (`mark`'s row); nil for any other ghost, such as his text from a change.
  public static func reply(of mark: String) -> String? {
    guard let hash = mark.lastIndex(of: "#"), Int(mark[mark.index(after: hash)...]) != nil else { return nil }
    return String(mark[..<hash])
  }

  /// The group a reply kept whole goes under (#942, story 995): Larry moves or erases it by this one name.
  public static func group(reply: String) -> String { "reply-\(reply)" }

  /// A reply's group over the stroke's other notes.
  public static func groupNote(reply: String, over existing: BoardMeta? = nil) -> BoardMeta? {
    var object = existing?.object as? [String: Any] ?? [:]
    object["group"] = group(reply: reply)
    return BoardMeta(object)
  }

  /// Keep all (stories 895, 995, 999; bead context-grabber-yqau): the reply each of `marks` is kept under as one group,
  /// by mark id. A reply with two or more of `marks` is a group; a reply with one, and a mark that belongs to no reply
  /// (his text from a change), is kept alone and not named here.
  public static func keptGroups(_ marks: [String]) -> [String: String] {
    let replies = marks.compactMap { mark in reply(of: mark).map { (mark, $0) } }
    let counts = Dictionary(replies.map { ($0.1, 1) }, uniquingKeysWith: +)
    return Dictionary(replies.filter { counts[$0.1, default: 0] > 1 }, uniquingKeysWith: { a, _ in a })
  }

  /// How many rows a board remembers as showing on this device (story 1155); an older one stays in Chat.
  private static let rowsKept = 20

  /// Larry's rows from `GET /chat/<key>`, or nil for an answer that is not a thread.
  public static func rows(_ data: Data) -> [Row]? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["ok"] as? Bool == true,
      let messages = json["messages"] as? [[String: Any]]
    else { return nil }
    return messages.compactMap { row($0) }
  }

  /// One of Larry's messages on the thread as a row; nil for anyone else's. `lettering` decides which labels have
  /// letters to draw; only a test passes one.
  public static func row(
    _ message: [String: Any], lettering: @escaping WhiteboardTurn.Lettering = WhiteboardTurn.hasLetters
  ) -> Row? {
    guard message["who"] as? String == "larry", let id = message["id"] as? String else { return nil }
    let place = (message["frame"] as? [String: Any]).flatMap(frame)
    let offered = WhiteboardMarkActions.parse(message["actions"])
    return Row(
      id: id, text: (message["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
      shapes: (message["shapes"] as? [Any] ?? []).compactMap { WhiteboardTurn.anyShape($0, lettering: lettering) },
      pictureID: message["picture_id"] as? String, frame: place?.rect, scale: place?.scale ?? 1,
      ops: BoardOps.batch(message["ops"], key: id, source: "web"), actions: offered.offers,
      unknownActions: offered.unknown)
  }

  /// A row's frame; nil for a number a picture of this board can't have, so a bad one can't send marks to infinity.
  /// `scale` is optional on the Cockpit: without one, a pixel is a point.
  public static func frame(_ json: [String: Any]) -> (rect: CGRect, scale: CGFloat)? {
    let field = { (key: String) in json[key].flatMap(WhiteboardTurn.number) }
    guard let x = field("x"), let y = field("y"), let w = field("w"), let h = field("h"), w >= 0, h >= 0 else {
      return nil
    }
    let scale = json["scale"] == nil ? 1 : field("scale") ?? 0
    guard scale >= 0.01 else { return nil }
    return (CGRect(x: x, y: y, width: w, height: h), scale)
  }
}
