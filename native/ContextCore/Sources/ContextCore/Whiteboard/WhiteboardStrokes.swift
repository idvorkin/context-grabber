//  The board as vectors (spec 2026-11-01-whiteboard-shapes-design.md, story 419, cockpit-f7c). A picture of a tall
//  board shrinks the handwriting to a few pixels; the strokes do not. So every picture for Larry is preceded by the
//  board's strokes, in board points, posted to the Cockpit under that picture's id: `POST /whiteboard/strokes`. Here:
//  a stroke as the Cockpit takes it, its stable id, the request and the answer. PencilKit stays in the app, which
//  turns its strokes into these.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum WhiteboardStrokes {
  /// One stroke in board points, as the Cockpit stores it (`whiteboard_strokes.py`).
  public struct Stroke: Equatable, Sendable {
    /// Stable across sends and devices: `WhiteboardStrokes.id`.
    public var id: String
    /// When it was drawn, unix ms.
    public var t: Int64?
    /// `#rrggbb`, as the ink looks in light mode (black ink, not white).
    public var color: String
    /// In board points.
    public var width: CGFloat
    /// pen, pencil, marker, ... (`WhiteboardStrokes.tool`).
    public var tool: String
    public var points: [CGPoint]
    /// Folded away by Larry (story 847): still on the board, not drawn.
    public var hidden: Bool

    public init(
      id: String, t: Int64? = nil, color: String = "#000000", width: CGFloat = 3, tool: String = "pen",
      points: [CGPoint], hidden: Bool = false
    ) {
      self.hidden = hidden
      self.id = id
      self.t = t
      self.color = color
      self.width = width
      self.tool = tool
      self.points = points
    }
  }

  public enum Answer: Equatable, Sendable {
    case stored(count: Int, new: Int, erased: Int)
    /// A 4xx: the Cockpit's reason. The picture still goes; the log says so.
    case refused(status: Int, reason: String)
    /// No answer, a 5xx, or one that can't be read.
    case away(reason: String)
  }

  /// The Cockpit's caps (`whiteboard_strokes.py`); past them the send is a 400, so the app stays under.
  public static let maxStrokes = 20_000
  public static let maxPoints = 4_000
  /// Board points between the points kept of a stroke: PencilKit's spline sampled this often follows handwriting.
  public static let spacing: CGFloat = 3
  public static let timeout: TimeInterval = 30

  /// A stable id for a stroke: the same ink, colour and moment hash the same on every send and every device (the
  /// drawing moves between them as PencilKit data), so the Cockpit can tell a new stroke from one it has. FNV-1a over
  /// the points to a tenth of a point, 16 hex characters.
  public static func id(points: [CGPoint], color: String, t: Int64?) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    func mix(_ bytes: some Sequence<UInt8>) {
      for b in bytes {
        hash ^= UInt64(b)
        hash = hash &* 0x0000_0100_0000_01b3
      }
    }
    for p in points {
      mix(withUnsafeBytes(of: Int64((p.x * 10).rounded()).littleEndian) { Array($0) })
      mix(withUnsafeBytes(of: Int64((p.y * 10).rounded()).littleEndian) { Array($0) })
    }
    mix(Array(color.lowercased().utf8))
    mix(withUnsafeBytes(of: (t ?? 0).littleEndian) { Array($0) })
    return String(format: "%016llx", hash)
  }

  /// `#rrggbb` from components in 0...1.
  public static func hex(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
    let byte = { (v: CGFloat) in Int((min(max(v, 0), 1) * 255).rounded()) }
    return String(format: "#%02x%02x%02x", byte(red), byte(green), byte(blue))
  }

  /// A stroke's width in board points: the mean of its own point sizes, scaled as its transform scales its points.
  public static func width(sizes: [CGFloat], transform: CGAffineTransform) -> CGFloat {
    let mean = sizes.isEmpty ? 3 : sizes.reduce(0, +) / CGFloat(sizes.count)
    return mean * hypot(transform.a, transform.b)
  }

  /// A PencilKit ink type's raw value (`com.apple.ink.pen`) as the short word the Cockpit takes: lowercase letters
  /// and digits, starting with a letter, at most 16; `pen` when there is nothing usable.
  public static func tool(rawValue: String) -> String {
    let last = rawValue.split(separator: ".").last.map(String.init) ?? ""
    let word = String(last.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(16))
    guard let first = word.first, first.isLetter else { return "pen" }
    return word
  }

  /// `points` with at most `maxPoints`, every nth kept and the last always, rounded to a tenth of a point.
  public static func thin(_ points: [CGPoint], max: Int = maxPoints) -> [CGPoint] {
    let tenth = { (p: CGPoint) in CGPoint(x: (p.x * 10).rounded() / 10, y: (p.y * 10).rounded() / 10) }
    guard points.count > max, max > 1, let last = points.last else { return points.map(tenth) }
    let step = Int((Double(points.count) / Double(max - 1)).rounded(.up))
    var out = stride(from: 0, to: points.count, by: step).map { tenth(points[$0]) }
    if out.last != tenth(last) { out.append(tenth(last)) }
    return out
  }

  /// The strokes as the Cockpit reads them, at most `maxStrokes` of them.
  public static func wire(_ strokes: [Stroke]) -> [[String: Any]] {
    strokes.prefix(maxStrokes).map { s in
      var out: [String: Any] = [
        "id": s.id, "color": s.color, "width": Double(s.width), "tool": s.tool,
        "points": thin(s.points).map { [Double($0.x), Double($0.y)] },
      ]
      if let t = s.t { out["t"] = t }
      if s.hidden { out["hidden"] = true }
      return out
    }
  }

  /// The strokes file a board's picture waits beside in the outbox (story 424): the strokes alone, as a list, or, from a
  /// board drawn here (story 1176), `{"strokes": [...], "folds": [...]}` with its folded sections. Nil when unreadable.
  public static func file(_ raw: Data) -> (strokes: [[String: Any]], folds: [[String: Any]])? {
    let json = try? JSONSerialization.jsonObject(with: raw)
    if let strokes = json as? [[String: Any]] { return (strokes, []) }
    guard let wrapped = json as? [String: Any], let strokes = wrapped["strokes"] as? [[String: Any]] else { return nil }
    return (strokes, wrapped["folds"] as? [[String: Any]] ?? [])
  }

  /// The strokes file for a picture: a list when nothing is folded, as before, else with the folds beside.
  public static func file(strokes: [[String: Any]], folds: [[String: Any]]) throws -> Data {
    try JSONSerialization.data(withJSONObject: folds.isEmpty ? strokes as Any : ["strokes": strokes, "folds": folds])
  }

  /// `POST /whiteboard/strokes`: the board's strokes under this picture's id and frame.
  /// `folds`: the folded sections (`BoardOutline.wire`), whose strokes are not in `strokes` (story 857).
  public static func request(
    picture: WhiteboardPicture, strokes: [[String: Any]], folds: [[String: Any]] = [], cockpit: String
  ) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("whiteboard").appendingPathComponent("strokes"))
    request.httpMethod = "POST"
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    var body = picture.wire
    body["strokes"] = strokes
    if !folds.isEmpty { body["folds"] = folds }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
  }

  public static func answer(status: Int?, body: Data?, error: String? = nil) -> Answer {
    guard let status else { return .away(reason: error ?? "no answer") }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    if status == 200, let json, json["ok"] as? Bool == true {
      return .stored(
        count: json["count"] as? Int ?? 0, new: json["new"] as? Int ?? 0, erased: json["erased"] as? Int ?? 0)
    }
    let reason = (json?["error"] as? String) ?? "HTTP \(status)"
    if (400..<500).contains(status) { return .refused(status: status, reason: reason) }
    return .away(reason: reason)
  }

  /// One line for the session log: what the answer was, never the strokes.
  public static func logFields(_ answer: Answer) -> [String: Any] {
    switch answer {
    case .stored(let count, let new, let erased):
      return ["strokes": count, "strokes_new": new, "strokes_erased": erased, "strokes_ok": true]
    case .refused(let status, let reason):
      return ["strokes_ok": false, "strokes_status": status, "strokes_reason": reason]
    case .away(let reason):
      return ["strokes_ok": false, "strokes_reason": reason]
    }
  }
}
