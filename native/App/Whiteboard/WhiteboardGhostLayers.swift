//  A ghost (a shape Claude or Larry offered, not yet kept), the upload clock, the ghost layers, and the colours
//  they're drawn in.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z).

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

/// A shape Claude or Larry offered, in board points, not yet kept.
struct Ghost: Identifiable, WhiteboardGhost {
  let id: String
  let who: WhiteboardTurn.Who
  /// What it draws; a connector mark's are drawn against the board (story 917).
  var lines: [[CGPoint]]
  /// The colour and pen it asked for, or its author's colour and the default pen (#698); a label with no pen of its own
  /// takes `hand`, the pen in Igor's hand as it showed (#949).
  let color: UIColor
  let width: CGFloat
  /// What it is and, for a label, its letters' height in board points: for the keep's log line (#883).
  let kind: WhiteboardTurn.Shape.Kind
  let letters: CGFloat?
  let offers: [WhiteboardMarkActions.Offer]
  /// A text of Larry's from a batch of his changes (story 817): kept, it becomes one text under its id.
  let text: BoardOps.Text?
  /// A connector mark (story 917): kept, it becomes a connector joining its ends. Moved with the ink it holds to (story
  /// 1180).
  var connector: BoardOps.NewConnector?
  /// When the picture this mark answers was taken, unix ms, when this device knows (#894): what Igor made after it
  /// makes room for the mark when it is kept.
  let seen: Int64?

  init(
    _ shape: WhiteboardTurn.Shape, who: WhiteboardTurn.Who, frame: CGRect, scale: CGFloat,
    id: String = UUID().uuidString, text: BoardOps.Text? = nil, hand: CGFloat? = nil, seen: Int64? = nil,
    folds: BoardFoldMap? = nil, lettering: WhiteboardTurn.LetterStyle = .single,
    offers: [WhiteboardMarkActions.Offer]? = nil
  ) {
    self.id = id
    self.seen = seen
    self.offers = text?.markOffers ?? offers ?? WhiteboardMarkActions.standard
    // #950: a label naming no lettering takes the board's as it shows, and a text of Larry's keeps it when kept.
    self.text = text.map { text in
      var text = text
      text.lettering = text.lettering ?? lettering
      return text
    }
    self.who = who
    // Story 1046: drawn on a picture with folds open, the mark lands on the folded board by the ink it was drawn on.
    var connector = BoardConnectors.mark(shape, frame: frame, scale: scale, id: id)
    var lines = WhiteboardTurn.lines(shape, frame: frame, scale: scale, lettering: lettering)
    if let folds {
      let onBoard = { (end: BoardOps.NewConnector.End) -> BoardOps.NewConnector.End in
        if case .point(let p) = end { return .point(folds.toBoard(p)) }
        return end
      }
      if var mark = connector {
        mark.from = onBoard(mark.from)
        mark.to = onBoard(mark.to)
        connector = mark
      }
      lines = lines.map { $0.map(folds.toBoard) }
    }
    self.connector = connector
    self.lines = lines
    color = shape.color.map { UIColor(rgb: $0) } ?? who.color
    width = WhiteboardTurn.width(shape, scale: scale, hand: hand)
    kind = shape.kind
    letters = WhiteboardTurn.letters(shape, scale: scale)
  }
}

/// How long a ghost turn's request took to go up (story 661): from the send to its body's last byte, the connection's
/// setup included. URLSession tells a task's own delegate as the body goes; the last word is the last byte.
final class UploadClock: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var started: ContinuousClock.Instant?
  private var sent: ContinuousClock.Instant?

  func start() {
    lock.withLock {
      started = .now
      sent = nil
    }
  }

  /// Nil until the body has gone, or when URLSession never said.
  var span: Duration? {
    lock.withLock {
      guard let started, let sent else { return nil }
      return started.duration(to: sent)
    }
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    lock.withLock { sent = .now }
  }
}

/// The ghosts on screen, in board points: one shape layer a ghost, the ink it would become, faint, in its colour. Whoever
/// holds `holder` scales it to sit on the drawing. Never part of the drawing, and in no picture.
@MainActor
final class GhostLayers {
  let holder = CALayer()
  private var shown: [String: CAShapeLayer] = [:]

  init() {
    holder.anchorPoint = .zero
    holder.frame = .zero
  }

  /// True when the ghosts on show changed.
  @discardableResult
  func show(_ ghosts: [Ghost]) -> Bool {
    guard Set(ghosts.map(\.id)) != Set(shown.keys) else { return false }
    let live = Set(ghosts.map(\.id))
    for (id, gone) in shown where !live.contains(id) {
      shown[id] = nil
      CATransaction.begin()
      CATransaction.setCompletionBlock { gone.removeFromSuperlayer() }
      let fade = CABasicAnimation(keyPath: "opacity")
      fade.fromValue = gone.presentation()?.opacity ?? 1
      fade.toValue = 0
      fade.duration = 0.3
      gone.opacity = 0
      gone.add(fade, forKey: "fade")
      CATransaction.commit()
    }
    let arriving = ghosts.filter { shown[$0.id] == nil }
    for (i, ghost) in arriving.enumerated() {
      let path = CGMutablePath()
      for line in ghost.lines { path.addLines(between: line) }
      let shape = CAShapeLayer()
      shape.path = path
      shape.fillColor = nil
      shape.strokeColor = ghost.color.withAlphaComponent(0.5).cgColor
      shape.lineWidth = ghost.width
      shape.lineCap = .round
      shape.lineJoin = .round
      // Drawn in one after another, like someone sketching beside him.
      let drawIn = CABasicAnimation(keyPath: "strokeEnd")
      drawIn.fromValue = 0
      drawIn.toValue = 1
      drawIn.duration = 0.25
      drawIn.beginTime = CACurrentMediaTime() + 0.25 * Double(i)
      drawIn.fillMode = .backwards
      shape.add(drawIn, forKey: "drawIn")
      holder.addSublayer(shape)
      shown[ghost.id] = shape
      drawnLines[ghost.id] = ghost.lines
    }
    return true
  }

  /// Story 1285 (#1383): the dashed outline round each reply of Larry's showing two or more marks, by reply.
  private var outlines: [String: CAShapeLayer] = [:]

  /// Story 1285 (#1383): a faint dashed outline in Larry's colour round each of `groups` (board points), so a reply of
  /// several marks reads as one thing; gone with the reply, or once only one of its marks shows.
  func outline(_ groups: [(reply: String, box: CGRect)]) {
    let live = Set(groups.map(\.reply))
    for (reply, gone) in outlines where !live.contains(reply) {
      gone.removeFromSuperlayer()
      outlines[reply] = nil
    }
    for group in groups {
      let path = CGPath(roundedRect: group.box, cornerWidth: 8, cornerHeight: 8, transform: nil)
      if let layer = outlines[group.reply] {
        guard layer.path != path else { continue }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.path = path
        CATransaction.commit()
        continue
      }
      let layer = CAShapeLayer()
      layer.path = path
      layer.fillColor = nil
      layer.strokeColor = WhiteboardTurn.Who.larry.color.withAlphaComponent(0.25).cgColor
      layer.lineWidth = 1.5
      layer.lineDashPattern = [6, 4]
      holder.addSublayer(layer)
      outlines[group.reply] = layer
    }
  }

  /// The lines each layer draws, to redraw one only when its mark moved.
  private var drawnLines: [String: [[CGPoint]]] = [:]

  /// Stories 1180, 1181, 1269, 1271: each mark where it is now, faded to a third when written over, not shown while the
  /// ink it holds to is folded away or erased.
  func restyle(_ ghosts: [Ghost], look: (String) -> BoardMarkHolds.Place?) {
    drawnLines = drawnLines.filter { shown[$0.key] != nil }
    for ghost in ghosts {
      guard let layer = shown[ghost.id] else { continue }
      if drawnLines[ghost.id] != ghost.lines {
        let path = CGMutablePath()
        for line in ghost.lines { path.addLines(between: line) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.path = path
        CATransaction.commit()
        drawnLines[ghost.id] = ghost.lines
      }
      let place = look(ghost.id)
      let opacity = Float(place?.hidden != nil ? 0 : place?.faded == true ? BoardMarkHolds.fadedStrength : 1)
      guard layer.opacity != opacity, layer.animation(forKey: "fade") == nil else { continue }
      let change = CABasicAnimation(keyPath: "opacity")
      change.fromValue = layer.presentation()?.opacity ?? layer.opacity
      change.toValue = opacity
      change.duration = 0.2
      layer.opacity = opacity
      layer.add(change, forKey: "look")
    }
  }
}

extension WhiteboardTurn.Who {
  /// Claude orange, Larry purple: a colour the picker doesn't offer (spec 2026-11-01-whiteboard-shapes-design.md,
  /// context-grabber-a3w).
  var color: UIColor { self == .claude ? .systemOrange : UIColor(rgb: WhiteboardTurn.larryColor) }
}

extension UIColor {
  convenience init(rgb: UInt32) {
    self.init(
      red: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255,
      alpha: 1)
  }
}

extension BoardPaper {
  /// Follows the view's mode, as the ink does. Plain is the system's own, as every board was before colours.
  var color: UIColor {
    guard self != .plain else { return .systemBackground }
    let light = UIColor(rgb: light)
    let dark = UIColor(rgb: dark)
    return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
  }
}
