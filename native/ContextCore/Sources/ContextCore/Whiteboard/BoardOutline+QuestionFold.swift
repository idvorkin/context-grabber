//  *To question/answer* (spec 2026-11-01-whiteboard-shapes-design.md, *Larry chooses the buttons beside his reply, and
//  To question/answer*; story 1354, #1525): Igor's question becomes a header and Larry's kept answer folds under it.
//  Pure, on the outline, as every fold is.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension BoardOutline {
  /// The first line of Igor's question made a header named `id`, ending just below `answerBottom` (the kept answer's
  /// lowest point), and folded. The question is his ink made in `made` (unix ms: after the turn before, up to the
  /// picture Larry answered) when the board knows those times, so older lines in the picture stay out; else his ink in
  /// `question`, the picture's place. Nil, with nothing changed, when there is no writing of his to be the question, or
  /// nothing under it to fold.
  @discardableResult
  public mutating func foldQuestion(
    in question: CGRect, made: ClosedRange<Int64>? = nil, answerBottom: CGFloat, id: String
  ) -> String? {
    let us = units()
    let times = strokes.map(\.t)
    let asked = { (u: Unit) -> Bool in
      guard let made else { return u.bounds.intersects(question) }
      return u.members.contains { times[$0].map(made.contains) ?? false }
    }
    guard
      let first = us.filter({ his($0) && $0.header == nil && asked($0) }).min(by: { $0.bounds.minY < $1.bounds.minY }),
      markHeader(at: first.bounds.midY, id: id),
      let at = headers.firstIndex(where: { $0.id == id })
    else { return nil }
    // The fold ends at the first ink below the answer: what he wrote after it stays out.
    let header = box(headers[at]) ?? first.bounds
    if let next = us.filter({ $0.bounds.minY > max(answerBottom, header.maxY) })
      .min(by: { $0.bounds.minY < $1.bounds.minY })
    {
      headers[at].ends = names(next.members)
    }
    guard fold(id) else {
      unmark(id)
      return nil
    }
    return id
  }
}
