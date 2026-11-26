//  #1527: the board samples each stroke for Larry once and keeps it by what the stroke is (`WhiteboardStrokeCache`).
//  These pin what that rests on: a stroke the same in all that its sampling reads samples the same, one moved, cut or
//  recoloured is sampled again, and a board of a thousand strokes read again costs a small part of sampling it.

import ContextCore
import PencilKit
import UIKit
import XCTest

@testable import GrabberNative

@MainActor
final class StrokeCacheTests: XCTestCase {
  /// A stroke of `points` points from (x, y), drawn at `date`.
  private func stroke(x: CGFloat, y: CGFloat, points: Int = 40, date: Date, seed: UInt32) -> PKStroke {
    let path = PKStrokePath(
      controlPoints: (0..<points).map { i in
        PKStrokePoint(
          location: CGPoint(x: x + CGFloat(i) * 3, y: y + sin(CGFloat(i) / 4) * 6), timeOffset: Double(i) / 120,
          size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
      }, creationDate: date)
    return PKStroke(ink: PKInk(.pen, color: .black), path: path, randomSeed: seed)
  }

  private func sample(_ stroke: PKStroke) -> [WhiteboardStrokes.Stroke] {
    WhiteboardModel.strokesForLarry(PKDrawing(strokes: [stroke]))
  }

  func testTheSameStrokeSamplesOnceAndGivesTheSamePoints() {
    let cache = WhiteboardStrokeCache()
    let one = stroke(x: 10, y: 10, date: Date(timeIntervalSinceReferenceDate: 1000), seed: 7)
    let first = cache.stretches(of: one, sample: sample)
    let again = cache.stretches(of: one, sample: sample)
    XCTAssertEqual(first.map(\.id), again.map(\.id))
    XCTAssertEqual(first.map(\.id), sample(one).map(\.id), "kept points are the ones sampling gives")
    XCTAssertEqual(cache.misses, 1)
    XCTAssertEqual(cache.hits, 1)
  }

  /// The board rebuilds a stroke from PaperKit's element (`PaperBoard.hashes`), a new value each time: it still hits.
  func testARemadeCopyOfAStrokeHits() {
    let cache = WhiteboardStrokeCache()
    let one = stroke(x: 10, y: 10, date: Date(timeIntervalSinceReferenceDate: 1000), seed: 7)
    _ = cache.stretches(of: one, sample: sample)
    let copy = PKStroke(
      ink: one.ink, path: one.path, transform: one.transform, mask: one.mask, randomSeed: one.randomSeed)
    _ = cache.stretches(of: copy, sample: sample)
    XCTAssertEqual(cache.hits, 1)
  }

  func testAMovedCutOrRecolouredStrokeIsSampledAgain() {
    let cache = WhiteboardStrokeCache()
    let one = stroke(x: 10, y: 10, date: Date(timeIntervalSinceReferenceDate: 1000), seed: 7)
    let first = cache.stretches(of: one, sample: sample)
    var moved = one
    moved.transform = CGAffineTransform(translationX: 0, y: 50)
    let movedPoints = cache.stretches(of: moved, sample: sample)
    XCTAssertNotEqual(first.map(\.id), movedPoints.map(\.id))
    var cut = one
    cut.mask = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 40, height: 40))
    _ = cache.stretches(of: cut, sample: sample)
    var red = one
    red.ink = PKInk(.pen, color: .red)
    _ = cache.stretches(of: red, sample: sample)
    XCTAssertEqual(cache.misses, 4)
    XCTAssertEqual(cache.hits, 0)
  }

  /// Igor's board of about a thousand strokes: read again, the kept strokes cost a small part of sampling them.
  func testAThousandStrokeBoardReadAgainIsFarCheaperThanSampled() {
    let base = Date(timeIntervalSinceReferenceDate: 1000)
    var board: [PKStroke] = []
    for i in 0..<1000 {
      let x = CGFloat(i % 20) * 40
      let y = CGFloat(i / 20) * 30
      board.append(stroke(x: x, y: y, date: base.addingTimeInterval(Double(i)), seed: UInt32(i)))
    }
    let cache = WhiteboardStrokeCache()
    let clock = ContinuousClock()
    let sampled = clock.measure { for s in board { _ = cache.stretches(of: s, sample: sample) } }
    let kept = clock.measure { for s in board { _ = cache.stretches(of: s, sample: sample) } }
    let ms = { (d: Duration) in Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15 }
    print("stroke cache, 1000 strokes: sampled \(ms(sampled)) ms, read again \(ms(kept)) ms")
    XCTAssertEqual(cache.hits, 1000)
    XCTAssertLessThan(ms(kept), ms(sampled) / 3, "a board read again must cost far less than sampling it")
  }
}
