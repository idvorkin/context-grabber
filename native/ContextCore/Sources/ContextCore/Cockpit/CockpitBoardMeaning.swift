//  The mirror's meaning (spec 2026-11-22-boards-in-the-cockpit-design.md, Sending a board to the Cockpit (the mirror,
//  beta), *The board's meaning goes too*; story 1368; cockpit-8kh; the shape Larry agreed on 2026-11-26, msg
//  e837e6cbcbbb). A mirrored board's headers and folds, groups, kept texts, question and answer cards and connectors
//  are given to the Cockpit in the web board's own lists (assets/ink/board.mjs: `objects`, `headers`, `connectors`), so
//  `BoardStoreEncode` turns them into the store's storage ops like any other board. Every stroke name the iPad knows a
//  thing by becomes the mirror's id for that stroke (`s-<ms>x<seed>`); a name no stroke on the board carries is left out.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif
#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum CockpitBoardMeaning {
  /// The board's meaning in the web board's lists, and the strokes that are connectors (their arrow is drawn from the
  /// connector record, so their ink doesn't go up as a stroke: Larry, Q4).
  public struct Lists: Equatable, Sendable {
    public var objects: [BoardStoreJSON] = []
    public var headers: [BoardStoreJSON] = []
    public var connectors: [BoardStoreJSON] = []
    public var connectorStrokes: Set<String> = []

    public init() {}

    /// Every id the lists give the Cockpit: what this iPad owns on the copy.
    public var ids: [String] {
      (objects + headers + connectors).compactMap { $0["id"]?.string }
    }
  }

  /// The id a group of the iPad's goes up as.
  public static func groupID(_ group: String) -> String { "g-" + group }

  /// `names[i]` are the names the iPad knows stroke `i` by, and `records[i]` its record as the mirror sends it.
  public static func lists(meaning: BoardMeaning, names: [[String]], records: [BoardStoreJSON]) -> Lists {
    let strokeIDs = records.map { $0["id"]?.string ?? "" }
    var idOf: [String: String] = [:]
    for (i, stretchNames) in names.enumerated() where i < strokeIDs.count {
      for name in stretchNames where idOf[name] == nil { idOf[name] = strokeIDs[i] }
    }
    func mapped(_ names: [String]?) -> [String] {
      var seen = Set<String>()
      return (names ?? []).compactMap { idOf[$0] }.filter { seen.insert($0).inserted }
    }

    var lists = Lists()
    let groups = meaning.strokeMeta.groups
    let textIDs = Set(meaning.texts.map(\.id))
    let theirs = Set(meaning.theirs)

    // Connectors first, so their strokes are known before groups and Larry's kept ink are counted.
    for (i, stretchNames) in names.enumerated() where i < strokeIDs.count {
      guard let name = stretchNames.first(where: { BoardConnector(meaning.strokeMeta[$0]) != nil }),
        let connector = BoardConnector(meaning.strokeMeta[name])
      else { continue }
      func end(_ ref: String) -> String? {
        if textIDs.contains(ref) { return ref }
        if let group = groups[ref] { return groupID(group) }
        if groups.values.contains(ref) { return groupID(ref) }
        return nil
      }
      // An end that is a bare stroke has no object on the web to follow: the stroke stays ink instead.
      guard let from = end(connector.from), let to = end(connector.to) else { continue }
      // Its own id, not the stroke's: a stroke sent before as ink is erased while the connector is added.
      var record: [String: Any] = [
        "id": "c-" + strokeIDs[i],
        "from": ["obj": from, "side": connector.fromSide.rawValue],
        "to": ["obj": to, "side": connector.toSide.rawValue],
        "by": connector.by,
      ]
      if let color = connector.color { record["color"] = String(format: "#%06x", color) }
      lists.connectors.append(BoardStoreJSON(any: record))
      lists.connectorStrokes.insert(strokeIDs[i])
    }

    // Groups: Igor's, and Larry's (his kept replies, #1537's diagram boxes), by who drew all of their strokes.
    var members: [String: [String]] = [:]
    var groupOrder: [String] = []
    for (i, stretchNames) in names.enumerated() where i < strokeIDs.count {
      let id = strokeIDs[i]
      guard !lists.connectorStrokes.contains(id) else { continue }
      for name in stretchNames {
        guard let group = groups[name] else { continue }
        if members[group] == nil { groupOrder.append(group) }
        if !(members[group] ?? []).contains(id) { members[group, default: []].append(id) }
      }
    }
    var grouped = Set<String>()
    for group in groupOrder {
      let ids = members[group] ?? []
      guard !ids.isEmpty else { continue }
      grouped.formUnion(ids)
      let owner = ids.allSatisfy { ms(of: $0).map(theirs.contains) ?? false } ? "larry" : "igor"
      lists.objects.append(
        BoardStoreJSON(any: ["id": groupID(group), "kind": "group", "ids": ids, "owner": owner] as [String: Any]))
    }

    // Kept texts: the text object names its glyph strokes, which still go up (Larry, Q2).
    var glyphs = Set<String>()
    for text in meaning.texts {
      let ids = strokeIDs.filter { !$0.isEmpty && ms(of: $0) == text.t }
      guard let box = bounds(ids.compactMap { id in records.first { $0["id"]?.string == id } }) else { continue }
      glyphs.formUnion(ids)
      lists.objects.append(
        BoardStoreJSON(
          any: [
            "id": text.id, "kind": "text", "text": text.text, "x": tenth(box.minX), "y": tenth(box.minY),
            "w": tenth(box.maxX - box.minX), "size": text.size, "font": text.font.strokesFont, "color": text.color,
            "ids": ids,
          ] as [String: Any]))
    }

    // Larry's kept ink outside any group: a group of his per moment it was drawn (Larry, Q5).
    var larry: [Int64: [String]] = [:]
    var larryOrder: [Int64] = []
    for id in strokeIDs
    where !id.isEmpty && !grouped.contains(id) && !glyphs.contains(id)
      && !lists.connectorStrokes.contains(id)
    {
      guard let t = ms(of: id), theirs.contains(t) else { continue }
      if larry[t] == nil { larryOrder.append(t) }
      larry[t, default: []].append(id)
    }
    for t in larryOrder {
      lists.objects.append(
        BoardStoreJSON(
          any: [
            "id": groupID("larry-\(t)"), "kind": "group", "ids": larry[t] ?? [], "owner": "larry",
          ] as [String: Any]))
    }

    // Question cards and Larry's answer cards (Larry, Q3: an answer is a card).
    for card in meaning.questions.cards {
      if card.fromLarry, card.ask.hasPrefix("answer:"), let answer = card.answered {
        var body: [String: Any] = [
          "id": card.id, "kind": "answer", "text": answer.label, "x": tenth(card.x), "y": tenth(card.y),
        ]
        if let title = answer.title { body["title"] = title }
        lists.objects.append(BoardStoreJSON(any: body))
        continue
      }
      let show = card.archived != nil ? "archived" : (card.collapsed || card.hidden) ? "collapsed" : "full"
      lists.objects.append(
        BoardStoreJSON(
          any: [
            "id": card.id, "kind": "question", "ask": card.ask, "x": tenth(card.x), "y": tenth(card.y), "show": show,
          ] as [String: Any]))
      if let answer = card.answered {
        var body: [String: Any] = [
          "id": card.id + "-answer", "kind": "answer", "text": answer.label, "re": card.ask, "x": tenth(card.x),
          "y": tenth(card.y + WhiteboardQuestions.height),
        ]
        if let title = answer.title { body["title"] = title }
        lists.objects.append(BoardStoreJSON(any: body))
      }
    }

    // Headers, with a fold riding on the header as board.mjs's `folded` (Larry, Q1).
    for header in meaning.headers {
      let ids = mapped(header.ids)
      guard !ids.isEmpty else { continue }
      var body: [String: Any] = ["id": header.id, "ids": ids]
      if let mark = header.mark { body["mark"] = mapped(mark) }
      if let deeper = header.deeper { body["deeper"] = deeper.map { mapped($0) } }
      if let ends = header.ends { body["ends"] = ends.compactMap { idOf[$0] ?? (textIDs.contains($0) ? $0 : nil) } }
      if let fold = header.fold {
        body["folded"] = ["ids": mapped(fold.ids), "oids": mapped(fold.own), "shift": tenth(fold.shift)]
      }
      lists.headers.append(BoardStoreJSON(any: body))
    }
    return lists
  }

  /// The moment a mirror stroke id was drawn at (`s-<ms>x<seed>`).
  public static func ms(of id: String) -> Int64? {
    guard id.hasPrefix("s-"), let x = id.firstIndex(of: "x") else { return nil }
    return Int64(id[id.index(id.startIndex, offsetBy: 2)..<x])
  }

  /// A tenth of a point, so the same board writes the same numbers every save and nothing goes up for no change.
  static func tenth(_ value: CGFloat) -> Double { (Double(value) * 10).rounded() / 10 }

  /// The box around some stroke records' points (`pts: [[x, y, …]]`).
  static func bounds(_ records: [BoardStoreJSON]) -> CGRect? {
    var minX = Double.infinity
    var minY = Double.infinity
    var maxX = -Double.infinity
    var maxY = -Double.infinity
    for record in records {
      for point in record["pts"]?.array ?? [] {
        guard let p = point.array, p.count >= 2, let x = number(p[0]), let y = number(p[1]) else { continue }
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
      }
    }
    guard minX.isFinite else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  static func number(_ value: BoardStoreJSON) -> Double? {
    switch value {
    case .int(let v): Double(v)
    case .number(let v): v
    default: nil
    }
  }
}
