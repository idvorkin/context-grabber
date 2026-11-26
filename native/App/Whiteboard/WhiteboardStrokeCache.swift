//  #1527: each stroke as Larry's form, sampled once. The board turned every stroke into points for Larry's names up to
//  four times on each new stroke of a board with marks (the drawing's marks follow, the marks the stroke writes over,
//  the whole board again, the marks follow again), so a stroke's own handling grew with the board: about 8 ms on a new
//  board and 85 on one of 600, with seconds on the slow ones. A stroke's sampling depends only on what it is, so it is
//  kept by what it is and reused until the stroke changes.

import ContextCore
import CoreGraphics
import Foundation
import PencilKit

/// Each stroke's sampled stretches for Larry, by what the stroke is: the same stroke never samples twice.
final class WhiteboardStrokeCache {
  /// What a stroke is, as far as its sampling goes: the same path (its seed, its start and its length), placed and
  /// cut the same way (its transform, the bounds and the stretches its mask leaves), in the same ink.
  struct Key: Hashable {
    let seed: UInt32
    let created: TimeInterval
    let points: Int
    let transform: [CGFloat]
    let bounds: [CGFloat]
    /// The stretches a mask leaves: an erase inside a stroke can keep its bounds and still cut it.
    let ranges: [CGFloat]
    let ink: String

    init(_ stroke: PKStroke) {
      seed = stroke.randomSeed
      created = stroke.path.creationDate.timeIntervalSinceReferenceDate
      points = stroke.path.count
      let t = stroke.transform
      transform = [t.a, t.b, t.c, t.d, t.tx, t.ty]
      let b = stroke.renderBounds
      bounds = [b.minX, b.minY, b.width, b.height]
      ranges = stroke.mask == nil ? [] : stroke.maskedPathRanges.flatMap { [$0.lowerBound, $0.upperBound] }
      ink = "\(stroke.ink.color.description)/\(WhiteboardInk.rawType(stroke.ink) ?? "")"
    }
  }

  private var held: [Key: [WhiteboardStrokes.Stroke]] = [:]
  /// How often a stroke was found and how often sampled, for the log and the tests.
  private(set) var hits = 0
  private(set) var misses = 0

  /// `stroke` as Larry's stretches: kept from before, or sampled by `sample` now and kept.
  func stretches(of stroke: PKStroke, sample: (PKStroke) -> [WhiteboardStrokes.Stroke]) -> [WhiteboardStrokes.Stroke] {
    let key = Key(stroke)
    if let kept = held[key] {
      hits += 1
      return kept
    }
    misses += 1
    let fresh = sample(stroke)
    held[key] = fresh
    return fresh
  }

  /// Forgets what is no longer among `strokes`, once it holds far more than the board does.
  func trim(to strokes: [PKStroke]) {
    guard held.count > max(512, strokes.count * 2) else { return }
    let live = Set(strokes.map(Key.init))
    held = held.filter { live.contains($0.key) }
  }

  var count: Int { held.count }
}
