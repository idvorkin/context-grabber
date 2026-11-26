//  A turn on the whiteboard (spec 2026-11-01-whiteboard-shapes-design.md, story 344): Claude's ghosts come from
//  `POST /whiteboard/suggest` (the contract is the Cockpit's whiteboard.py), in the picture's pixels; Larry's marks come
//  over chat (`WhiteboardMarks`).
//  Here: the request, the answer, and each shape as the ink lines that draw it on the board.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
  import CoreText
#endif

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum WhiteboardTurn {
  /// Whose marks: Claude's ghosts after a pause or spoken words, or Larry's from his chat thread.
  public enum Who: String, Sendable {
    case claude, larry
  }

  /// Larry's colour for a mark that names none (context-grabber-a3w): a purple, half way round the hue circle between
  /// the picker's blue and its red, so his kept ink is never Igor's. It was the system blue, which the picker's own blue
  /// matches to the eye.
  public static let larryColor: UInt32 = 0xBA39E6

  public struct Shape: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case line, arrow, rect, ellipse, path, text, connector }
    public var kind: Kind
    /// In the picture's pixels, origin top-left.
    public var points: [CGPoint]
    public var text: String?
    /// A label's height in the picture's pixels.
    public var size: CGFloat?
    /// The pen's width in the picture's pixels (#698); nil draws at the default (`width`).
    public var pen: CGFloat?
    /// `0xRRGGBB` (#698); nil draws in its author's colour.
    public var color: UInt32?
    /// A label's lettering (#698).
    public var face: Face
    /// A label's letters as single strokes or a real font's outlines (#950); nil takes the board's.
    public var lettering: LetterStyle?
    /// A connector's ends by name (story 917); nil when its ends are its two points.
    public var from: String?
    public var to: String?

    public init(
      kind: Kind, points: [CGPoint], text: String? = nil, size: CGFloat? = nil, pen: CGFloat? = nil,
      color: UInt32? = nil, face: Face = .print, lettering: LetterStyle? = nil, from: String? = nil, to: String? = nil
    ) {
      self.lettering = lettering
      self.from = from
      self.to = to
      self.kind = kind
      self.points = points
      self.text = text
      self.size = size
      self.pen = pen
      self.color = color
      self.face = face
    }
  }

  /// A label's lettering: print, or a handwriting face the system has (not Igor's hand).
  public enum Face: String, Codable, Sendable {
    case print, hand
    var fontName: String { self == .print ? "Helvetica" : "Noteworthy-Light" }
  }

  /// How a label's letters are drawn (#950): single pen strokes (#895, the default), or the outlines of the face's real
  /// font, Helvetica or Noteworthy, which ship with the iPad. Either way they are ink.
  public enum LetterStyle: String, Sendable, Codable, CaseIterable {
    case single, font

    /// As a mark or a text names it; nil for none or one this build doesn't know, which takes the board's.
    public static func named(_ any: Any?) -> LetterStyle? { (any as? String).flatMap(LetterStyle.init(rawValue:)) }
  }

  /// A mark's pen with nothing asked for, in board points: the width of a kept stroke.
  public static let defaultPen: CGFloat = 3.7
  /// The widest pen a mark can ask for, in board points: no wider than a Pencil stroke gets.
  public static let widestPen: CGFloat = 24
  /// The thinnest pen a mark draws with, in board points: PencilKit draws nothing for a stroke much thinner, on the
  /// canvas and in the picture alike (#883). Measured in the pictures Igor's iPad sent: kept marks at 1.2–1.9 points
  /// drew none of their ink, and a kept mark of Larry's at 2.5 points drew all of it, as did every stroke above.
  /// ponytail: small labels come out bolder than #698 wanted (2.5 on 13-point letters); a larger least letter height
  /// is the other way out, and lowering this needs a kept mark between 1.9 and 2.5 seen to draw on the iPad.
  public static let thinnestPen: CGFloat = 2.5

  /// The pen `shape` draws with, in board points. A label with no pen of its own takes `hand`, the width of the pen
  /// Igor last held, in board points (#949: his text and Larry's at one weight); with none known, one in proportion to
  /// its letters, about a ninth of their height, so it reads as writing rather than a marker (#698's bold fix). No pen
  /// is thinner than `thinnestPen`, so a kept mark is ink as its ghost showed it, never ink too thin to draw (#883).
  public static func width(_ shape: Shape, scale: CGFloat, hand: CGFloat? = nil) -> CGFloat {
    let pen: CGFloat
    if let asked = shape.pen {
      pen = asked / scale
    } else if shape.kind == .text {
      pen = hand.flatMap { $0 > 0 ? $0 : nil } ?? textHeight(shape, scale: scale) * 0.11
    } else {
      pen = defaultPen
    }
    return min(widestPen, max(thinnestPen, pen))
  }

  /// A label's letter height on the board, in points; nil for any other mark. For the log.
  public static func letters(_ shape: Shape, scale: CGFloat) -> CGFloat? {
    shape.kind == .text ? textHeight(shape, scale: scale) : nil
  }

  /// `#RRGGBB` as a colour; nil for anything else.
  package static func hexColor(_ any: Any?) -> UInt32? {
    guard let s = any as? String, s.count == 7, s.first == "#", s.dropFirst().allSatisfy(\.isHexDigit) else {
      return nil
    }
    return UInt32(s.dropFirst(), radix: 16)
  }

  public enum Answer: Equatable, Sendable {
    case shapes([Shape])
    /// A 429 on a ghost turn: asked within the Cockpit's 2 s, so this turn is skipped and nothing changes.
    case tooSoon
    /// A 4xx: the Cockpit's reason, shown to Igor.
    case refused(status: Int, reason: String)
    /// No answer, a 5xx, or one that can't be read: no turn this time.
    case away(reason: String)
  }

  /// How long the app waits for Claude's ghosts: the Cockpit's ghost model takes about 3 s.
  public static let suggestTimeout: TimeInterval = 10

  /// Whether a label has letters to draw in a face. The app's is `hasLetters` (CoreText's outlines); a test hands in
  /// its own, so the parse rules run where there are no fonts (`just test-linux`).
  public typealias Lettering = (String, Face) -> Bool

  /// `lettering` decides which labels are kept; only a test passes one.
  public static func answer(
    status: Int?, body: Data?, error: String? = nil, lettering: Lettering = hasLetters
  ) -> Answer {
    guard let status else { return .away(reason: error ?? "no answer") }
    if status == 429 { return .tooSoon }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    if status == 200, let json, json["ok"] as? Bool == true {
      let all = (json["shapes"] as? [Any] ?? []) + (json["strokes"] as? [Any] ?? [])
      return .shapes(all.compactMap { anyShape($0, lettering: lettering) })
    }
    let reason = (json?["error"] as? String) ?? "HTTP \(status)"
    if (400..<500).contains(status) { return .refused(status: status, reason: reason) }
    return .away(reason: reason)
  }

  /// A shape in either format the Cockpit sends: `kind` + `points`, or a stroke from the ghost endpoint. Both have a
  /// `line` and an `arrow`, told apart by their points.
  static func anyShape(_ json: Any, lettering: Lettering = hasLetters) -> Shape? {
    guard let json = json as? [String: Any] else { return nil }
    return shape(json, lettering: lettering) ?? shapeJSON(stroke: json).flatMap { shape($0, lettering: lettering) }
  }

  /// A stroke from the ghost endpoint as a shape's JSON, so `shape` checks it the same way; nil for a kind it doesn't
  /// know or a number that's missing.
  static func shapeJSON(stroke s: [String: Any]) -> [String: Any]? {
    let looks = s.filter { ["pen", "color", "font", "lettering"].contains($0.key) }
    return strokeShape(s).map { $0.merging(looks) { a, _ in a } }
  }

  private static func strokeShape(_ s: [String: Any]) -> [String: Any]? {
    let n = { (key: String) in JSONNumber.double(s[key]) }
    switch s["kind"] as? String {
    case "rect":
      // Top-left, width and height.
      guard let x = n("x"), let y = n("y"), let w = n("w"), let h = n("h") else { return nil }
      return ["kind": "rect", "points": [[x, y], [x + w, y + h]]]
    case let kind? where kind == "line" || kind == "arrow":
      guard let x1 = n("x1"), let y1 = n("y1"), let x2 = n("x2"), let y2 = n("y2") else { return nil }
      return ["kind": kind, "points": [[x1, y1], [x2, y2]]]
    case "polyline":
      return ["kind": "path", "points": s["points"] ?? []]
    case "connector":
      // Story 917, the Cockpit's chat_store `_clean_connector`: two objects by id, or two points on the picture.
      if let from = s["from"] as? String, let to = s["to"] as? String {
        return ["kind": "connector", "from": from, "to": to]
      }
      guard let x1 = n("x1"), let y1 = n("y1"), let x2 = n("x2"), let y2 = n("y2") else { return nil }
      return ["kind": "connector", "points": [[x1, y1], [x2, y2]]]
    case "circle":
      guard let cx = n("cx"), let cy = n("cy"), let r = n("r") else { return nil }
      return ["kind": "ellipse", "points": [[cx - r, cy - r], [cx + r, cy + r]]]
    case "arc":
      guard let cx = n("cx"), let cy = n("cy"), let r = n("r"), let start = n("start"), let end = n("end") else {
        return nil
      }
      // Degrees clockwise from +x on a picture whose y runs down, always the clockwise way from start to end.
      let sweep = (end - start).truncatingRemainder(dividingBy: 360)
      let degrees = sweep < 0 ? sweep + 360 : sweep
      let steps = max(2, Int(degrees / 7.5))
      return [
        "kind": "path",
        "points": (0...steps).map { i -> [Double] in
          let a = (start + degrees * Double(i) / Double(steps)) * .pi / 180
          return [cx + r * cos(a), cy + r * sin(a)]
        },
      ]
    case "label":
      // The Cockpit's x, y is the text's baseline; a shape's text hangs from its top-left.
      guard let x = n("x"), let y = n("y") else { return nil }
      let size = n("size") ?? 18
      let face = (s["font"] as? String).flatMap(Face.init(rawValue:)) ?? .print
      return ["kind": "text", "points": [[x, y - Double(ascent(face)) * size]], "text": s["text"] ?? "", "size": size]
    default:
      return nil
    }
  }

  /// One shape from the answer; nil for a kind it doesn't know, too few points to draw, or a label with no outlines.
  static func shape(_ json: [String: Any], lettering: Lettering = hasLetters) -> Shape? {
    guard let kind = (json["kind"] as? String).flatMap(Shape.Kind.init(rawValue:)) else { return nil }
    let points = (json["points"] as? [[Any]] ?? []).compactMap { pair -> CGPoint? in
      guard pair.count == 2, let x = number(pair[0]), let y = number(pair[1]) else { return nil }
      return CGPoint(x: x, y: y)
    }
    let text = (json["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let face = (json["font"] as? String).flatMap(Face.init(rawValue:)) ?? .print
    let ends = (json["from"] as? String, json["to"] as? String)
    if kind == .text {
      guard !points.isEmpty, let text, lettering(text, face) else { return nil }
    } else if kind == .connector, let from = ends.0, let to = ends.1 {
      guard BoardOps.isName(from), BoardOps.isName(to), from != to else { return nil }
    } else {
      guard points.count >= 2 else { return nil }
    }
    // A pen of zero or less, or one past reach, is no pen: the mark draws as if it hadn't asked.
    let pen = json["pen"].flatMap(number).flatMap { $0 > 0 ? $0 : nil }
    return Shape(
      kind: kind, points: points, text: text, size: json["size"].flatMap(number), pen: pen,
      color: hexColor(json["color"]), face: face, lettering: LetterStyle.named(json["lettering"]),
      from: kind == .connector ? ends.0 : nil,
      to: kind == .connector ? ends.1 : nil)
  }

  /// A number within reach of a picture: no point on the board is further out in pixels than its side at the finest
  /// scale. Past that, a model's coordinate could map to infinity on the board and trap when its ghost is kept.
  static func number(_ any: Any) -> CGFloat? {
    guard let n = JSONNumber(any), abs(n.doubleValue) <= Double(WhiteboardFrame.side * WhiteboardFrame.maxScale) else {
      return nil
    }
    return CGFloat(n.doubleValue)
  }

  /// The ink lines that draw `shape` on the board, given the picture's frame (`WhiteboardFrame.export`). A label that
  /// names no lettering is lettered in `lettering`, the board's (#950).
  public static func lines(_ shape: Shape, frame: CGRect, scale: CGFloat, lettering: LetterStyle = .single)
    -> [[CGPoint]]
  {
    let board = { (p: CGPoint) in CGPoint(x: frame.minX + p.x / scale, y: frame.minY + p.y / scale) }
    let p = shape.points.map(board)
    switch shape.kind {
    case .line: return [[p[0], p[1]]]
    // A connector by name has nothing to draw without the board (story 917): the board draws its ghost.
    case .connector: return p.count >= 2 ? [BoardConnectors.polyline([p[0], p[1]])] : []
    case .path: return [p]
    case .rect:
      let r = CGRect(
        x: min(p[0].x, p[1].x), y: min(p[0].y, p[1].y), width: abs(p[1].x - p[0].x), height: abs(p[1].y - p[0].y))
      return [
        [
          r.origin, CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY),
          r.origin,
        ]
      ]
    case .ellipse:
      let c = CGPoint(x: (p[0].x + p[1].x) / 2, y: (p[0].y + p[1].y) / 2)
      let rx = abs(p[1].x - p[0].x) / 2
      let ry = abs(p[1].y - p[0].y) / 2
      return [
        (0...48).map { i in
          let a = CGFloat(i) / 48 * 2 * .pi
          return CGPoint(x: c.x + rx * cos(a), y: c.y + ry * sin(a))
        }
      ]
    case .arrow:
      let (a, b) = (p[0], p[1])
      let length = hypot(b.x - a.x, b.y - a.y)
      guard length > 0 else { return [[a, b]] }
      let head = min(24, length / 3)
      let angle = atan2(b.y - a.y, b.x - a.x)
      let wing = { (turn: CGFloat) in
        CGPoint(x: b.x - head * cos(angle + turn), y: b.y - head * sin(angle + turn))
      }
      return [[a, b], [wing(.pi / 6), b, wing(-.pi / 6)]]
    case .text:
      // A long label wraps to the picture's right edge (story 1348); one that fits is one row, as before.
      let height = textHeight(shape, scale: scale)
      let style = shape.lettering ?? lettering
      return wrappedRows(shape, frame: frame, scale: scale, lettering: style).flatMap { row in
        glyphLines(row.text, topLeft: CGPoint(x: row.x, y: row.y), height: height, face: shape.face, lettering: style)
      }
    }
  }

  /// Whether `text` has an outline to draw in `face`: an emoji alone has none, so its ghost would be nothing to see.
  public static func hasLetters(_ text: String, _ face: Face) -> Bool {
    !glyphLines(text, topLeft: .zero, height: 28, face: face).isEmpty
  }

  /// A label's letter height on the board: never under 8 points, so it stays readable.
  static func textHeight(_ shape: Shape, scale: CGFloat) -> CGFloat {
    max(8, (shape.size ?? 28) / scale)
  }

  /// How far from a mark a finger tap still reaches it, in screen points (the board's points at a zoom of 1): the
  /// board's one fingertip. Every finger tap and hold on the board divides this by its zoom rather than writing 22
  /// again (context-grabber-egdh item 2).
  public static let tapReach: CGFloat = 22

  /// How far a tap at `point` is from a mark, in board points, or nil when it is out of reach (#941). A label is reached
  /// anywhere in the box its letters fill, at no distance, as a finger aims at words rather than at their outlines;
  /// any other mark by its lines.
  public static func reach(
    _ lines: [[CGPoint]], kind: Shape.Kind, at point: CGPoint, tolerance: CGFloat
  ) -> CGFloat? {
    if kind == .text {
      let box = WhiteboardMarkChoice.bounds(lines)
      guard !box.isNull else { return nil }
      let dx = max(box.minX - point.x, 0, point.x - box.maxX)
      let dy = max(box.minY - point.y, 0, point.y - box.maxY)
      let away = hypot(dx, dy)
      return away <= tolerance ? away : nil
    }
    var nearest = CGFloat.infinity
    for line in lines {
      if line.count == 1 { nearest = min(nearest, hypot(line[0].x - point.x, line[0].y - point.y)) }
      for (a, b) in zip(line, line.dropFirst()) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let span = dx * dx + dy * dy
        let t = span == 0 ? 0 : max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / span))
        nearest = min(nearest, hypot(a.x + t * dx - point.x, a.y + t * dy - point.y))
      }
    }
    return nearest <= tolerance ? nearest : nil
  }

  /// `line` with a point about every `spacing` board points, the most a board-sized edge needs. PencilKit treats a
  /// stroke's points as spline control points, so a corner between far-apart points would be cut short; at 4 points it
  /// misses by under a point.
  public static func inkPoints(_ line: [CGPoint], spacing: CGFloat = 4) -> [CGPoint] {
    var out = Array(line.prefix(1))
    for (a, b) in zip(line, line.dropFirst()) {
      let steps = Int(min(hypot(b.x - a.x, b.y - a.y) / spacing, WhiteboardFrame.side).rounded(.up))
      if steps > 1 {
        for i in 1..<steps {
          let t = CGFloat(i) / CGFloat(steps)
          out.append(CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y)))
        }
      }
      out.append(b)
    }
    return out
  }

  #if canImport(CoreText)
    /// How far a label's baseline sits below its top, as a share of its size.
    static func ascent(_ face: Face) -> CGFloat {
      CTFontGetAscent(CTFontCreateWithName(face.fontName as CFString, 100, nil)) / 100
    }

    /// A label as its letters written in single pen strokes (#895), lines PencilKit can draw. A character the written
    /// letters don't have keeps its outline, so nothing goes missing; an emoji has neither and draws nothing. In the
    /// real font (#950), every letter is its outline.
    static func glyphLines(
      _ text: String, topLeft: CGPoint, height: CGFloat, face: Face = .print, lettering: LetterStyle = .single
    ) -> [[CGPoint]] {
      lettered(text, topLeft: topLeft, height: height, face: face, lettering: lettering).lines
    }

    /// A label's written lines and how far its letters reach along the row, in board points. Its capitals are as tall
    /// as print's and stand on the face's baseline, so a label takes about the room it did as outlines (the script's
    /// capitals at the hand face's own, much taller, height came out a third bigger).
    static func lettered(
      _ text: String, topLeft: CGPoint, height: CGFloat, face: Face, lettering: LetterStyle = .single
    ) -> (lines: [[CGPoint]], width: CGFloat) {
      // The real font (#950): the face's own outlines, on the same baseline at the same size, so a label stands where
      // a written one would and its capitals are as tall.
      if lettering == .font {
        return (
          outlineLines(text, topLeft: topLeft, height: height, face: face),
          outlineWidth(text, height: height, face: face)
        )
      }
      let print = CTFontCreateWithName(Face.print.fontName as CFString, height, nil)
      let baseline = ascent(face) * height
      let unit = CTFontGetCapHeight(print) / BoardLettering.capHeight
      var x: CGFloat = 0
      var out: [[CGPoint]] = []
      for character in BoardLettering.plain(text) {
        if let glyph = BoardLettering.glyph(character, face: face) {
          let origin = CGPoint(x: topLeft.x + x, y: topLeft.y + baseline)
          out += glyph.strokes.map { stroke in
            stroke.map {
              CGPoint(
                x: origin.x + ($0.x - glyph.left) * unit, y: origin.y + ($0.y - BoardLettering.baseline) * unit)
            }
          }
          x += glyph.advance * unit
        } else {
          let one = String(character)
          out += outlineLines(one, topLeft: CGPoint(x: topLeft.x + x, y: topLeft.y), height: height, face: face)
          x += outlineWidth(one, height: height, face: face)
        }
      }
      return (out, x)
    }

    /// How far `text` reaches in `face`'s outlines at `height`.
    static func outlineWidth(_ text: String, height: CGFloat, face: Face) -> CGFloat {
      let font = CTFontCreateWithName(face.fontName as CFString, height, nil)
      let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
      return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    /// Text as the outlines of its letters (the system font), flattened into lines PencilKit can draw: a pasted text's
    /// letters, and a label's character the written letters don't have.
    static func outlineLines(_ text: String, topLeft: CGPoint, height: CGFloat, face: Face = .print) -> [[CGPoint]] {
      let font = CTFontCreateWithName(face.fontName as CFString, height, nil)
      let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
      let baseline = ascent(face) * height
      var out: [[CGPoint]] = []
      for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        // CoreText's fallback for a character Helvetica lacks: the run's glyph ids index the run's own font.
        // swiftlint:disable:next force_cast
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
        for (glyph, at) in zip(glyphs, positions) {
          guard let path = CTFontCreatePathForGlyph(runFont, glyph, nil) else { continue }
          // Glyphs are drawn y-up from the baseline; the board is y-down from the label's top.
          let place = { (q: CGPoint) in CGPoint(x: topLeft.x + at.x + q.x, y: topLeft.y + baseline - q.y) }
          out += flatten(path).map { $0.map(place) }
        }
      }
      return out
    }

    /// A path's subpaths as polylines, curves sampled in eight steps.
    static func flatten(_ path: CGPath) -> [[CGPoint]] {
      var out: [[CGPoint]] = []
      var current: [CGPoint] = []
      var start = CGPoint.zero
      let steps = 8
      path.applyWithBlock { element in
        let e = element.pointee
        // A subpath that goes on after a close starts where the last one started.
        if current.isEmpty, e.type != .moveToPoint { current = [start] }
        let last = current.last ?? start
        switch e.type {
        case .moveToPoint:
          if current.count > 1 { out.append(current) }
          start = e.points[0]
          current = [start]
        case .addLineToPoint:
          current.append(e.points[0])
        case .addQuadCurveToPoint:
          let (c, end) = (e.points[0], e.points[1])
          for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let u = 1 - t
            current.append(
              CGPoint(
                x: u * u * last.x + 2 * u * t * c.x + t * t * end.x, y: u * u * last.y + 2 * u * t * c.y + t * t * end.y
              ))
          }
        case .addCurveToPoint:
          let (c1, c2, end) = (e.points[0], e.points[1], e.points[2])
          for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let u = 1 - t
            let x = u * u * u * last.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * end.x
            let y = u * u * u * last.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * end.y
            current.append(CGPoint(x: x, y: y))
          }
        case .closeSubpath:
          current.append(start)
          if current.count > 1 { out.append(current) }
          current = []
        @unknown default:
          break
        }
      }
      if current.count > 1 { out.append(current) }
      return out
    }
  #else
    // Linux (just test-linux) has no fonts: a label has no outline there, so the app's `hasLetters` drops every text
    // shape. The parse tests hand `answer` their own lettering; the outline tests run on the Mac only.
    static func ascent(_ face: Face) -> CGFloat { 0 }
    static func glyphLines(
      _ text: String, topLeft: CGPoint, height: CGFloat, face: Face = .print, lettering: LetterStyle = .single
    ) -> [[CGPoint]] { [] }
    static func lettered(
      _ text: String, topLeft: CGPoint, height: CGFloat, face: Face, lettering: LetterStyle = .single
    ) -> (lines: [[CGPoint]], width: CGFloat) { ([], 0) }
  #endif
}
