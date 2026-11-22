//  Playback on the board's own paper (#1169; spec 2026-11-01-whiteboard-design.md, *Playing a board back*; stories 958,
//  956, 948): the paper's colour, its grid or ruled lines and page ends, the whole board faint from the first moment, a
//  tap on that faint ink jumping on to it, and a label when the stroke being drawn is above or below the screen.

import ContextCore
import PencilKit
import SwiftUI
import UIKit

extension WhiteboardPlaybackPlayer {
  /// The faint board's opacity: there to see where the ink goes, never mistaken for ink drawn.
  static let ghostAlpha: CGFloat = 0.2
  /// The faint board's pixels at most, so a long board's ghost stays a few tens of MB.
  static let ghostPixels: CGFloat = 8_000_000

  /// The whole drawing as one picture of the column, light as the board is, at the screen's scale or less for a long
  /// board.
  static func ghost(of drawing: PKDrawing, in column: CGRect) -> UIImage? {
    guard !drawing.strokes.isEmpty, column.width > 0, column.height > 0 else { return nil }
    let scale = min(2, (ghostPixels / (column.width * column.height)).squareRoot())
    var image: UIImage?
    UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
      image = drawing.image(from: CGRect(x: 0, y: 0, width: column.maxX, height: column.maxY), scale: scale)
    }
    return image
  }

  /// For `playback_start`: the paper, the ghost's cost, the page it opened on and the page the first stroke is on (#1169:
  /// opened on page 2 with the first strokes on page 1, the screen stays blank).
  func paperFields(ghostMs: Int) -> [String: Any] {
    var fields: [String: Any] = [
      "rules": "\(rules)", "pages": pageCount, "ghost": ghost != nil, "ghost_ms": ghostMs,
    ]
    if let opening { fields["opened_page"] = column.page(at: CGPoint(x: 0, y: opening.visible.midY)) }
    if let first = timeline.entries.first?.index, strokes.indices.contains(first) {
      let box = strokes[first].renderBounds
      fields["first_page"] = column.page(at: CGPoint(x: box.midX, y: box.midY))
    }
    return fields
  }

  /// What shows, board points.
  var visibleBoardRect: CGRect? {
    guard let canvas, canvas.bounds.height > 0 else { return nil }
    let zoom = max(canvas.zoomScale, 0.01)
    return CGRect(
      x: canvas.contentOffset.x / zoom, y: canvas.contentOffset.y / zoom, width: canvas.bounds.width / zoom,
      height: canvas.bounds.height / zoom)
  }

  /// Story 948: the label follows the stroke being drawn (or drawn last) and the screen; it's logged as it appears or
  /// changes edge, page, or goes.
  func lookOffScreen() {
    guard let visible = visibleBoardRect else { return }
    let latest = timeline.latest(at: clockPosition)
    let next = latest.flatMap { index in
      strokes.indices.contains(index)
        ? BoardPlayback.offScreen(ink: strokes[index].renderBounds, visible: visible, pages: column) : nil
    }
    guard next != offScreen else { return }
    if next != nil { offScreenShown += 1 }
    var fields: [String: Any] = [
      "action": "playback_offscreen", "board": boardID, "at_s": Self.tenths(clockPosition),
      "visible_page": column.page(at: CGPoint(x: 0, y: visible.midY)),
    ]
    switch next {
    case .above(let page): (fields["where"], fields["page"]) = ("above", page)
    case .below(let page): (fields["where"], fields["page"]) = ("below", page)
    case nil: fields["where"] = "on_screen"
    }
    if let latest { fields["stroke"] = latest }
    sessionLog.event("whiteboard", fields)
    setOffScreen(next)
  }

  /// Story 948: the label tapped moves the board to the stroke, its middle in the middle of the screen.
  func goToLatest() {
    guard let canvas, let index = timeline.latest(at: clockPosition), strokes.indices.contains(index) else { return }
    let box = strokes[index].renderBounds
    let zoom = canvas.zoomScale
    let most = max(0, canvas.contentSize.height - canvas.bounds.height)
    let y = min(max(0, box.midY * zoom - canvas.bounds.height / 2), most)
    sessionLog.event(
      "whiteboard",
      ["action": "playback_go", "board": boardID, "stroke": index, "page": offScreen?.page ?? 0])
    canvas.setContentOffset(CGPoint(x: canvas.contentOffset.x, y: y), animated: true)
  }
}

extension PlaybackCanvasView {
  /// The faint board, then the paper's lines over the paper's colour, behind the canvas's own ink.
  func addPaper() {
    paperLines.isUserInteractionEnabled = false
    paperLines.backgroundColor = .clear
    ghostView.image = player.ghost
    ghostView.alpha = WhiteboardPlaybackPlayer.ghostAlpha
    ghostView.isUserInteractionEnabled = false
    ghostView.accessibilityIdentifier = "whiteboard-playback-ghost"
    canvas.insertSubview(ghostView, at: 0)
    canvas.insertSubview(paperLines, at: 0)
    paperLines.show(width: player.column.width, ends: player.column.pageEnds(pages: player.pageCount))
  }

  /// The paper and the ghost sized to the column at this zoom; the lines laid again only when the zoom changes their
  /// spacing.
  func layPaper() {
    let zoom = max(canvas.zoomScale, 0.01)
    let size = CGRect(x: 0, y: 0, width: player.bounds.maxX * zoom, height: player.bounds.maxY * zoom)
    paperLines.frame = CGRect(x: 0, y: 0, width: player.column.width * zoom, height: size.height)
    ghostView.frame = size
    paperLines.hair = 1 / max(traitCollection.displayScale, 1)
    let step = WhiteboardFrame.lineStep(zoom: zoom)
    guard step != laidStep else { return }
    laidStep = step
    let column = player.column.bounds(pages: player.pageCount)
    switch player.rules {
    case .none:
      paperLines.showRules(across: [], span: 0...0, down: [])
    case .ruled:
      paperLines.showRules(
        across: [], span: 0...0,
        down: player.column.ruledLines(visible: column.minY...column.maxY, pages: player.pageCount, zoom: zoom))
    case .grid:
      let grid = player.column.gridLines(visible: column, pages: player.pageCount, zoom: zoom)
      paperLines.showRules(across: grid.across, span: column.minY...column.maxY, down: grid.down)
    }
  }
}

/// Story 948: *Writing above, page 1* at the top edge, *Writing below, page 3* at the bottom; a tap goes there.
struct WhiteboardPlaybackOffScreenLabel: View {
  @ObservedObject var player: WhiteboardPlaybackPlayer
  let edge: VerticalEdge

  var body: some View {
    if let off = player.offScreen, (edge == .top) == (off == .above(page: off.page)) {
      Button {
        player.goToLatest()
      } label: {
        Label(off.text, systemImage: edge == .top ? "arrow.up" : "arrow.down")
          .font(.footnote.weight(.semibold))
          .padding(.vertical, 6).padding(.horizontal, 12)
          .background(.thinMaterial, in: Capsule())
      }
      .buttonStyle(.plain)
      .padding(10)
      .accessibilityIdentifier("whiteboard-playback-offscreen")
      .environment(\.colorScheme, .light)
    }
  }
}
