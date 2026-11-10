//  Larry's marks on a board (spec 2026-11-01-whiteboard-shapes-design.md, stories 380–384, cockpit#85). A picture goes
//  to the board's chat thread with where it sits on the board; Larry's rows come back with shapes in that picture's
//  pixels and the same place. Here: what a picture carries, his rows as the app reads them, and which row to show.

import Foundation

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
  /// The thread's title when this picture starts it.
  public let title: String

  public init(
    board: String, title: String, rect: CGRect, scale: CGFloat, pictureID: String = UUID().uuidString.lowercased()
  ) {
    self.board = board
    self.title = title
    self.pictureID = pictureID
    frame = Frame(
      x: Double(rect.minX), y: Double(rect.minY), w: Double(rect.width), h: Double(rect.height), scale: Double(scale))
  }

  enum CodingKeys: String, CodingKey {
    case board, frame, title
    case pictureID = "picture_id"
  }

  var wire: [String: Any] {
    [
      "board": board, "picture_id": pictureID,
      "frame": ["x": frame.x, "y": frame.y, "w": frame.w, "h": frame.h, "scale": frame.scale],
    ]
  }
}

/// Each board's one chat thread on this device, by board id. ponytail: UserDefaults on this device; it moves to the
/// board's index if boards ever change hands.
public struct WhiteboardThreads: @unchecked Sendable {
  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  private func key(_ board: String) -> String { "whiteboard_thread_\(board)" }

  public func thread(board: String) -> String? { defaults.string(forKey: key(board)) }

  public func set(_ thread: String, board: String) { defaults.set(thread, forKey: key(board)) }

  /// The Cockpit no longer has `thread`. A newer thread the board has moved to stays.
  public func forget(_ thread: String, board: String) {
    if self.thread(board: board) == thread { defaults.removeObject(forKey: key(board)) }
  }

  /// The board has no thread yet and a picture waiting in the outbox will start it.
  public func firstSendWaiting(board: String, in items: [InboxItem]) -> Bool {
    thread(board: board) == nil && items.contains { $0.whiteboard?.board == board && $0.status == .waiting }
  }
}

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

    public var drawable: Bool { frame != nil && !shapes.isEmpty }

    public init(
      id: String, text: String = "", shapes: [WhiteboardTurn.Shape] = [], pictureID: String? = nil,
      frame: CGRect? = nil, scale: CGFloat = 1
    ) {
      self.id = id
      self.text = text
      self.shapes = shapes
      self.pictureID = pictureID
      self.frame = frame
      self.scale = scale
    }
  }

  /// What a look at the thread changes.
  public struct Update: Equatable, Sendable {
    /// The row whose marks now show, replacing his unkept ones.
    public var marks: Row?
    /// His newest words.
    public var say: String?
    /// New rows whose shapes have nowhere to go.
    public var unplaced: [String] = []
    /// He answered since the last look: a new row of his, marks or not (story 662). Never on the first look, whose rows
    /// were there before.
    public var replied = false
  }

  private var seen: Set<String>?

  public init() {}

  /// `rows`: Larry's, oldest first. `settled`: the row Igor already kept or dismissed from. The first look shows only
  /// the newest row of marks, unless that one is settled or has nowhere to go; after that, each new one.
  public mutating func take(_ rows: [Row], settled: String?) -> Update {
    var update = Update()
    if let seen {
      let new = rows.filter { !seen.contains($0.id) }
      update.replied = !new.isEmpty
      update.marks = new.last(where: \.drawable)
      update.say = new.last { !$0.text.isEmpty }?.text
      update.unplaced = new.filter { !$0.drawable && !$0.shapes.isEmpty }.map(\.id)
    } else if let newest = rows.last(where: { !$0.shapes.isEmpty }), newest.id != settled {
      if newest.drawable {
        update.marks = newest
        update.say = newest.text.isEmpty ? nil : newest.text
      } else {
        update.unplaced = [newest.id]
      }
    }
    seen = Set(rows.map(\.id))
    return update
  }

  /// Larry's rows from `GET /chat/<key>`, or nil for an answer that is not a thread.
  public static func rows(_ data: Data) -> [Row]? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["ok"] as? Bool == true,
      let messages = json["messages"] as? [[String: Any]]
    else { return nil }
    return messages.compactMap { message in
      guard message["who"] as? String == "larry", let id = message["id"] as? String else { return nil }
      let place = (message["frame"] as? [String: Any]).flatMap(frame)
      return Row(
        id: id, text: (message["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
        shapes: (message["shapes"] as? [Any] ?? []).compactMap { WhiteboardTurn.anyShape($0) },
        pictureID: message["picture_id"] as? String, frame: place?.rect, scale: place?.scale ?? 1)
    }
  }

  /// A row's frame; nil for a number a picture of this board can't have, so a bad one can't send marks to infinity.
  /// `scale` is optional on the Cockpit: without one, a pixel is a point.
  static func frame(_ json: [String: Any]) -> (rect: CGRect, scale: CGFloat)? {
    let field = { (key: String) in json[key].flatMap(WhiteboardTurn.number) }
    guard let x = field("x"), let y = field("y"), let w = field("w"), let h = field("h"), w >= 0, h >= 0 else {
      return nil
    }
    let scale = json["scale"] == nil ? 1 : field("scale") ?? 0
    guard scale >= 0.01 else { return nil }
    return (CGRect(x: x, y: y, width: w, height: h), scale)
  }
}
