//  Answer cards (#1439, spec 2026-11-16-whiteboard-question-cards-design.md, *Answer cards*; stories 1355–1357): Larry's
//  `answer` shape, `{kind: answer, text, x, y, title?, re?}` in the picture's pixels. It lands as his own card, answered,
//  and, when `re` names the ask of a question card on the board, answers that card and lands under it, as the web
//  board does. Then it is an answered card.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif
#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension WhiteboardQuestions {
  /// One of Larry's answer marks: his words, a title if he gave one, the ask it answers if any, where he put it, and the
  /// mark that remembers it landed.
  public struct AnswerPlacement: Equatable, Sendable {
    public let mark: String
    public let title: String?
    public let text: String
    public let re: String?
    public let at: CGPoint

    public init(mark: String, title: String?, text: String, re: String?, at: CGPoint) {
      self.mark = mark
      self.title = title
      self.text = text
      self.re = re
      self.at = at
    }
  }

  /// Larry's answer marks in `GET /chat/<key>`, placed by the row's own frame as his other marks are. A row with no
  /// frame, or an answer with no words, has nowhere to go.
  public static func answerPlacements(_ data: Data) -> [AnswerPlacement] {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["ok"] as? Bool == true,
      let messages = json["messages"] as? [[String: Any]]
    else { return [] }
    var out: [AnswerPlacement] = []
    for message in messages where message["who"] as? String == "larry" {
      guard let id = message["id"] as? String, let shapes = message["shapes"] as? [Any],
        let place = (message["frame"] as? [String: Any]).flatMap(WhiteboardMarks.frame)
      else { continue }
      for (i, any) in shapes.enumerated() {
        guard let shape = any as? [String: Any], shape["kind"] as? String == "answer",
          let text = shape["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let x = shape["x"].flatMap(WhiteboardTurn.number), let y = shape["y"].flatMap(WhiteboardTurn.number)
        else { continue }
        let title = (shape["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let re = (shape["re"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let at = CGPoint(x: place.rect.minX + x / place.scale, y: place.rect.minY + y / place.scale)
        out.append(AnswerPlacement(mark: WhiteboardMarks.mark(i, of: id), title: title, text: text, re: re, at: at))
      }
    }
    return out
  }

  /// Larry's answer marks not landed before, each as his card. One naming an open question card on the board (`re`,
  /// the card's ask) does as the web board does: the question card answers and collapses to *✓ <answer's title>*, and his
  /// answer card lands under it. How many answer cards landed.
  @discardableResult
  public mutating func landAnswers(_ placements: [AnswerPlacement]) -> Int {
    var landed = 0
    for p in placements where !handled.contains(p.mark) {
      handled.append(p.mark)
      var at = p.at
      if let re = p.re, let i = cards.firstIndex(where: {
        $0.ask == re && !$0.fromLarry && $0.answered == nil && $0.archived == nil
      }) {
        cards[i].answered = WhiteboardQuestion.Answer(title: Self.answerTitle(p), label: p.text)
        cards[i].collapsed = true
        at = CGPoint(x: cards[i].x, y: cards[i].y + Self.height + Self.gap)
      }
      cards.append(
        WhiteboardQuestion(
          id: UUID().uuidString.lowercased(), ask: "answer:\(p.mark)", x: Self.inPage(x: at.x, width: Self.width),
          y: max(0, at.y), answered: WhiteboardQuestion.Answer(title: p.title, label: p.text), fromLarry: true))
      landed += 1
    }
    return landed
  }

  /// An answer's title: Larry's, else the first line of his words.
  static func answerTitle(_ p: AnswerPlacement) -> String {
    p.title ?? firstLine(p.text)
  }

  static func firstLine(_ text: String) -> String {
    text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
  }

  /// What one of Larry's answer cards says: *Larry · <title>* over his words; folded, the title line alone. With no
  /// title, his first line is the title.
  static func answerCardLines(_ a: WhiteboardQuestion.Answer, collapsed: Bool) -> [String] {
    let head = "Larry · \(a.title ?? firstLine(a.label))"
    return collapsed ? [head] : [head, answerText(a)]
  }
}
