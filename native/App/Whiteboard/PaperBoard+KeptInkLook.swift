//  context-grabber-ikya: a kept text of Larry's showed in his purple only up to one vertical edge, the rest blank or black,
//  now and then on the iPad simulator; once the other way round, the part left of the edge black. PaperKit held every
//  stroke purple: it drew one tile of the mark wrong or not at all. `paper_ink_look` counts any pixel unlike the paper,
//  so a mark partly drawn passed for drawn. Here the kept strokes' own colour is measured where they are: a mark whose
//  colour spans less of the spot than the same strokes drawn alone would, or that has turned dark where nothing dark was
//  before the keep, is drawn again as a missed one is (story 650).

import ContextCore
import PaperKit
import PencilKit
import UIKit

extension PaperBoardController {
  /// What a picture of a spot holds, sorted against the paper (story 650).
  typealias KeptColours = KeptInkColours

  /// A second after a keep: the kept strokes' inks as made, as held then and now, and the colours drawn where they are.
  /// Part of it missing or dark, in view, redraws and looks again, twice at most. `before`: the spot's dark pixels before
  /// the keep (ink of Igor's already there).
  func lookAtKeptInk(_ made: [PKStroke], why: String, attempt: Int = 0, before: Int? = nil) {
    guard !made.isEmpty else { return }
    let moments = Set(made.map { BoardMoment.nearest($0) })
    let box = PKDrawing(strokes: made).bounds
    let want = Self.inkRGB(made[0].ink.color)
    let darkBefore = before ?? max(drawnColours(in: keptSpot(box), ink: want).dark, 0)
    let madeInks = Self.inkKinds(made)
    let heldNow = Self.inkKinds(heldStrokes(at: moments))
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self else { return }
      let spot = self.keptSpot(box)
      let inView = self.view.bounds.contains(spot)
      let heldLater = self.heldStrokes(at: moments)
      let drawn = self.drawnColours(in: spot, ink: want)
      let expected = heldLater.isEmpty ? KeptColours() : self.expectedColours(made, box: box, ink: want)
      let part = WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: darkBefore, ink: want)
      let whole = WhiteboardKeptInk.wholeSpan(expected)
      let missing = inView && part != nil
      let whose = missing ? self.keptStrokesDrawn(heldLater, ink: want) : [:]
      // context-grabber-z8o: a kept mark the view drew none of, whose strokes drawn alone show none of their colour either,
      // is a pen too thin to draw (#883), which no redraw brings back; said as `none`, where it used to read as whole.
      let none =
        inView && part == nil && !heldLater.isEmpty && WhiteboardKeptInk.drewNothing(drawn: drawn, expected: expected)
      self.log.event(
        "whiteboard",
        [
          "action": "paper_kept_ink", "why": why, "board": self.model.board.id, "strokes": made.count,
          "inks_made": madeInks, "inks_held": heldNow, "inks_held_later": Self.inkKinds(heldLater),
          "ink": self.rect(box), "spot": self.rect(spot), "in_view": inView, "ink_px": drawn.ink,
          "dark_px": drawn.dark, "dark_before": darkBefore, "other_px": drawn.other,
          "ink_span": [drawn.inkWidth, drawn.inkHeight],
          "expected_px": expected.ink, "expected_span": [expected.allWidth, expected.allHeight],
          "expected_ink_span": [expected.inkWidth, expected.inkHeight],
          "whole_span": [whole.width, whole.height],
          "attempt": attempt,
          "missing": part ?? (none ? "none" : ""),
        ].merging(whose) { $1 })
      let how = missing && self.touchesDown == 0 ? WhiteboardKeptInk.heal(afterLook: attempt) : nil
      self.showKeptInkForTests(inView ? (part ?? (none ? "none" : "whole")) : "out", healed: how != nil)
      guard let how else { return }
      // The view's nudge (`redrawSoon`, #906) left such a tile as it was, both tries, on the iPad simulator, and so did
      // setting the same markup again or marking every view to draw again. The view scrolls a screen away and back.
      self.log.event(
        "whiteboard",
        [
          "action": "paper_ink_heal", "why": "kept_\(part ?? "")", "board": self.model.board.id, "attempt": attempt + 1,
          "how": how,
        ])
      let place = self.paper.contentVisibleFrame
      self.paper.contentVisibleFrame = place.offsetBy(dx: 0, dy: place.height)
      try? await Task.sleep(for: .seconds(0.1))
      self.paper.contentVisibleFrame = place
      self.lookAtKeptInk(made, why: why, attempt: attempt + 1, before: darkBefore)
    }
  }

  /// `GRABBER_WHITEBOARD_KEPT_INK_LABEL=1`: every look at kept ink this launch as an element a UI test reads
  /// (`whiteboard-kept-ink`): its label each look's verdict in turn (`whole`, `cut`, `dark`, `none`, `out` of view),
  /// its value how many heals they asked for. A heal on the simulator is seen only as a blink or a jump, too quick to catch.
  private func showKeptInkForTests(_ verdict: String, healed: Bool) {
    guard LaunchHooks.current.whiteboard.keptInkLabel, isViewLoaded else { return }
    let id = "whiteboard-kept-ink"
    let label =
      view.subviews.first { $0.accessibilityIdentifier == id } as? UILabel
      ?? {
        let made = UILabel(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
        made.accessibilityIdentifier = id
        made.isAccessibilityElement = true
        made.alpha = 0.02
        made.accessibilityValue = "0"
        view.addSubview(made)
        return made
      }()
    let looks = label.accessibilityLabel.map { $0.split(separator: ",").map(String.init) } ?? []
    label.accessibilityLabel = (looks + [verdict]).joined(separator: ",")
    label.accessibilityValue = String((Int(label.accessibilityValue ?? "0") ?? 0) + (healed ? 1 : 0))
  }

  /// Where `box` (board points) is in this view's own points.
  private func keptSpot(_ box: CGRect) -> CGRect {
    let corner = lines.convert(lines.spot(of: box.origin), to: view)
    let scale = screenScale
    return CGRect(x: corner.x, y: corner.y, width: box.width * scale, height: box.height * scale)
  }

  /// The strokes PaperKit holds that were made at one of `moments` (a kept mark's strokes share their moment).
  private func heldStrokes(at moments: Set<Int64>) -> [PKStroke] {
    guard let markup = paper.markup else { return [] }
    return markup.inkDrawing.strokes.filter { moments.contains(BoardMoment.nearest($0)) }
  }

  /// Each ink kind and colour among `strokes`, with how many strokes have it: `com.apple.ink.pen #ba39e6 x13`.
  static func inkKinds(_ strokes: [PKStroke]) -> [String] {
    var counts: [String: Int] = [:]
    for stroke in strokes {
      let rgb = inkRGB(stroke.ink.color)
      let hex = String(format: "#%02x%02x%02x", rgb[0], rgb[1], rgb[2])
      counts["\(stroke.ink.inkType.rawValue) \(hex)", default: 0] += 1
    }
    return counts.keys.sorted().map { "\($0) x\(counts[$0] ?? 0)" }
  }

  private static func inkRGB(_ color: UIColor) -> [Int] {
    var (r, g, b): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
    color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&r, green: &g, blue: &b, alpha: nil)
    return [r, g, b].map { Int(($0 * 255).rounded()) }
  }

  /// pbvt: which of a kept mark's strokes the view drew in what, when one looks cut or dark. A kept stroke of Larry's has
  /// drawn black on the iPad simulator, whole, with PaperKit holding it purple, and neither heal brought it back.
  /// `kept_strokes`: each held stroke in the order made, `[place in the markup, ink px, dark px]` at its own spot;
  /// `layers`: each view inside PaperKit's over the spot drawn alone, `<class> ink <px> dark <px> a<alpha %>`;
  /// `style`: light or dark, the view's and PaperKit's; `ink_space`: the first held stroke's colour space and components.
  func keptStrokesDrawn(_ held: [PKStroke], ink want: [Int]) -> [String: Any] {
    guard let markup = paper.markup else { return [:] }
    let all = markup.inkDrawing.strokes
    let places = held.map { stroke in
      let moment = BoardMoment.nearest(stroke)
      return all.firstIndex { BoardMoment.nearest($0) == moment && $0.renderBounds == stroke.renderBounds } ?? -1
    }
    var each: [[Int]] = []
    for (place, stroke) in zip(places, held) {
      let colours = drawnColours(in: keptSpot(stroke.renderBounds), ink: want)
      each.append([place, colours.ink, colours.dark])
    }
    let spot = keptSpot(PKDrawing(strokes: held).bounds)
    // Each view inside PaperKit's that covers the spot, drawn alone (its own subviews with it): which one draws the black.
    // The handwriting reflow view has covered the whole board on the simulator (paper_touch's handwriting_at_start).
    var layers: [String] = []
    for found in Self.subviews(of: paper.view, covering: spot, in: view).prefix(12) {
      let colours = drawnColours(in: spot, ink: want, only: found)
      let shown = found.isHidden ? "hidden" : "a\(Int((found.alpha * 100).rounded()))"
      layers.append("\(type(of: found)) ink \(colours.ink) dark \(colours.dark) \(shown)")
    }
    let style = { (trait: UITraitCollection) in trait.userInterfaceStyle == .dark ? "dark" : "light" }
    var fields: [String: Any] = [
      "kept_strokes": each, "layers": layers,
      "style": [style(traitCollection), style(paper.traitCollection)],
    ]
    if let color = held.first?.ink.color.cgColor {
      fields["ink_space"] = [
        (color.colorSpace?.name as String?) ?? "", (color.components ?? []).map { ($0 * 1000).rounded() / 1000 },
      ]
    }
    return fields
  }

  /// `root`'s subviews, at any depth, outermost first, whose frame in `space` covers `spot`.
  static func subviews(of root: UIView, covering spot: CGRect, in space: UIView) -> [UIView] {
    var out: [UIView] = []
    var queue = root.subviews
    while let next = queue.first {
      queue.removeFirst()
      if next.convert(next.bounds, to: space).intersects(spot) { out.append(next) }
      queue += next.subviews
    }
    return out
  }

  /// The view's own picture at `spot`, sorted; with `only`, that view alone drawn where it sits. Unread when none of it
  /// is in the view.
  private func drawnColours(in spot: CGRect, ink: [Int], only: UIView? = nil) -> KeptColours {
    let box = spot.intersection(view.bounds)
    guard !box.isNull, !box.isEmpty else { return .unread }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let picture = UIGraphicsImageRenderer(size: box.size, format: format).image { _ in
      if let only {
        let frame = only.convert(only.bounds, to: view)
        only.drawHierarchy(in: frame.offsetBy(dx: -box.minX, dy: -box.minY), afterScreenUpdates: false)
      } else {
        let whole = CGRect(origin: CGPoint(x: -box.minX, y: -box.minY), size: view.bounds.size)
        view.drawHierarchy(in: whole, afterScreenUpdates: false)
      }
    }
    return picture.cgImage.flatMap { sortedColours($0, ink: ink) } ?? .unread
  }

  /// The kept strokes alone drawn on the paper at the view's scale, sorted as the view is: what they show when every one
  /// of them is drawn. Empty when it can't be drawn.
  private func expectedColours(_ strokes: [PKStroke], box: CGRect, ink: [Int]) -> KeptColours {
    let scale = screenScale
    let size = CGSize(width: box.width * scale, height: box.height * scale)
    guard size.width >= 1, size.height >= 1 else { return KeptColours() }
    var inkImage: UIImage?
    traitCollection.performAsCurrent { inkImage = PKDrawing(strokes: strokes).image(from: box, scale: scale) }
    guard let inkImage else { return KeptColours() }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let paperFill = paperColor.resolvedColor(with: traitCollection)
    let picture = UIGraphicsImageRenderer(size: size, format: format).image { context in
      paperFill.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      inkImage.draw(in: CGRect(origin: .zero, size: size))
    }
    return picture.cgImage.flatMap { sortedColours($0, ink: ink) } ?? KeptColours()
  }

  /// A picture's pixels unlike the paper, sorted: near `ink`, near black, the rest; and the spans.
  private func sortedColours(_ cg: CGImage, ink: [Int]) -> KeptColours? {
    let paperRGB = Self.inkRGB(paperColor.resolvedColor(with: traitCollection))
    let (w, h) = (cg.width, cg.height)
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
      guard
        let context = CGContext(
          data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
      return true
    }
    guard drawn else { return nil }
    return WhiteboardKeptInk.sort(rgba: bytes, width: w, height: h, paper: paperRGB, ink: ink)
  }
}
