import XCTest

@testable import ContextCore

/// Story 1368: a mirrored board's meaning goes to the Cockpit in the web board's own lists.
final class CockpitBoardMeaningTests: XCTestCase {
  private func stroke(_ id: String, at x: Double = 10, _ y: Double = 20) -> BoardStoreJSON {
    ["id": .string(id), "pts": [[.number(x), .number(y), 0.5], [.number(x + 30), .number(y + 12), 0.5]]]
  }

  private func fold(_ ids: [String], own: [String], shift: Double) -> BoardHeader.Fold {
    let json = #"{"ids":\#(ids),"own":\#(own),"shift":\#(shift),"lines":1,"bottom":500}"#
    // swiftlint:disable:next force_try
    return try! JSONDecoder().decode(BoardHeader.Fold.self, from: Data(json.utf8))
  }

  private func meta(_ object: [String: Any]) -> BoardMeta {
    // swiftlint:disable:next force_unwrapping
    BoardMeta(object)!
  }

  /// Three strokes of Igor's grouped, two of Larry's grouped, a kept text's glyph, and one plain stroke.
  private func sample() -> (BoardMeaning, [[String]], [BoardStoreJSON]) {
    var meaning = BoardMeaning()
    meaning.strokeMeta.set(meta(["group": "mine"]), for: "a")
    meaning.strokeMeta.set(meta(["group": "mine"]), for: "b")
    meaning.strokeMeta.set(meta(["group": "his"]), for: "c")
    meaning.theirs = [300]
    meaning.texts = [BoardText(id: "t1", t: 400, text: "hello", font: .plain, size: 20, color: "#5b3fa8")]
    meaning.headers = [BoardHeader(id: "h1", ids: ["a", "z"])]
    let names = [["a"], ["b"], ["c"], ["g1"], ["p"]]
    let records = [
      stroke("s-100x1"), stroke("s-200x2"), stroke("s-300x3"), stroke("s-400x4", at: 5, 7), stroke("s-500x5"),
    ]
    return (meaning, names, records)
  }

  func testGroupsGoAsTheWebBoardsGroupsWithTheirOwner() {
    let (meaning, names, records) = sample()
    let lists = CockpitBoardMeaning.lists(meaning: meaning, names: names, records: records)
    let groups = lists.objects.filter { $0["kind"]?.string == "group" }
    let mine = groups.first { $0["id"]?.string == "g-mine" }
    XCTAssertEqual(mine?["ids"]?.strings, ["s-100x1", "s-200x2"])
    XCTAssertEqual(mine?["owner"]?.string, "igor")
    XCTAssertEqual(groups.first { $0["id"]?.string == "g-his" }?["owner"]?.string, "larry", "drawn by Larry: his")
  }

  func testAKeptTextNamesItsGlyphsAndSitsWhereTheyAre() {
    let (meaning, names, records) = sample()
    let lists = CockpitBoardMeaning.lists(meaning: meaning, names: names, records: records)
    let text = lists.objects.first { $0["kind"]?.string == "text" }
    XCTAssertEqual(text?["id"]?.string, "t1")
    XCTAssertEqual(text?["ids"]?.strings, ["s-400x4"], "the glyph strokes, which still go up as ink")
    XCTAssertEqual(text?["text"]?.string, "hello")
    XCTAssertEqual(text?["x"], .number(5))
    XCTAssertEqual(text?["y"], .number(7))
    XCTAssertEqual(text?["w"], .number(30))
  }

  func testAHeaderNamesItsStrokesByTheMirrorsIDsAndDropsUnknownNames() {
    var (meaning, names, records) = sample()
    meaning.headers[0].fold = fold(["b", "p"], own: ["b"], shift: 120.04)
    let lists = CockpitBoardMeaning.lists(meaning: meaning, names: names, records: records)
    let header = lists.headers.first
    XCTAssertEqual(header?["ids"]?.strings, ["s-100x1"], "z is no stroke on the board")
    XCTAssertEqual(header?["folded"]?["ids"]?.strings, ["s-200x2", "s-500x5"])
    XCTAssertEqual(header?["folded"]?["oids"]?.strings, ["s-200x2"])
    XCTAssertEqual(header?["folded"]?["shift"], .number(120), "to a tenth of a point")
    XCTAssertNil(header?["folded"]?["lines"], "the iPad's own fold bookkeeping stays on the iPad")
  }

  func testQuestionAndAnswerCardsAreCards() {
    var meaning = BoardMeaning()
    meaning.questions = WhiteboardQuestions(cards: [
      WhiteboardQuestion(id: "q1", ask: "igor2-1", x: 80, y: 100, collapsed: true),
      WhiteboardQuestion(
        id: "q2", ask: "igor2-2", x: 80, y: 200, answered: .init(title: "Pick", label: "A")),
      WhiteboardQuestion(
        id: "l1", ask: "answer:m1", x: 90, y: 300, answered: .init(title: "Plan", label: "Do B"), fromLarry: true),
    ])
    let objects = CockpitBoardMeaning.lists(meaning: meaning, names: [], records: []).objects
    let q1 = objects.first { $0["id"]?.string == "q1" }
    XCTAssertEqual(q1?["kind"]?.string, "question")
    XCTAssertEqual(q1?["show"]?.string, "collapsed")
    let answer = objects.first { $0["id"]?.string == "q2-answer" }
    XCTAssertEqual(answer?["kind"]?.string, "answer")
    XCTAssertEqual(answer?["re"]?.string, "igor2-2", "an answered card's answer names the ask it answers")
    let larry = objects.first { $0["id"]?.string == "l1" }
    XCTAssertEqual(larry?["kind"]?.string, "answer")
    XCTAssertEqual(larry?["text"]?.string, "Do B")
    XCTAssertNil(larry?["re"])
  }

  func testAConnectorGoesAsARecordAndItsInkStaysHome() {
    var (meaning, names, records) = sample()
    meaning.strokeMeta.set(
      meta(["connector": ["from": "mine", "to": "t1", "from_side": "right", "to_side": "left", "by": "igor"]]),
      for: "p")
    let lists = CockpitBoardMeaning.lists(meaning: meaning, names: names, records: records)
    XCTAssertEqual(lists.connectorStrokes, ["s-500x5"])
    let connector = lists.connectors.first
    XCTAssertEqual(connector?["id"]?.string, "c-s-500x5")
    XCTAssertEqual(connector?["from"]?["obj"]?.string, "g-mine")
    XCTAssertEqual(connector?["to"]?["obj"]?.string, "t1")
    XCTAssertEqual(connector?["from"]?["side"]?.string, "right")
  }

  func testAConnectorToABareStrokeStaysInk() {
    var (meaning, names, records) = sample()
    meaning.strokeMeta.set(meta(["connector": ["from": "z9", "to": "t1"]]), for: "p")
    let lists = CockpitBoardMeaning.lists(meaning: meaning, names: names, records: records)
    XCTAssertTrue(lists.connectors.isEmpty, "no object on the web to follow")
    XCTAssertTrue(lists.connectorStrokes.isEmpty)
  }

  // The mirror's save with the meaning (story 1368).

  private func copy(_ things: [BoardStoreJSON]) -> BoardStoreCache {
    BoardStoreCache(snapshot: [
      "id": "b1", "rev": 3, "erased": [],
      "things": .array(
        [["id": "@board", "kind": "board", "body": ["name": "Main"], "rev": 1, "device": "ipad-1", "by": "igor"]]
          + things),
    ])
  }

  func testAFirstSendAddsTheMeaningAfterTheInk() throws {
    let (meaning, names, records) = sample()
    let lists = CockpitBoardMeaning.lists(meaning: meaning, names: names, records: records)
    let prepared = try CockpitBoardMirror.prepare(
      records: records, cache: copy([]), sent: [], name: "Main", laps: StepLaps(), meaning: lists
    ).get()
    let ops = prepared.cache.queue.flatMap { $0.ops }
    let kinds = ops.compactMap { $0["op"]?.string }
    XCTAssertEqual(kinds.first, "add_strokes")
    XCTAssertTrue(kinds.contains("group"))
    XCTAssertTrue(kinds.contains("add_text"))
    XCTAssertTrue(kinds.contains("header"))
    XCTAssertTrue(Set(prepared.sentIDs).isSuperset(of: ["g-mine", "t1", "h1"]), "the meaning is the iPad's too")
  }

  func testAFoldIsASetOfItsHeader() throws {
    var (meaning, names, records) = sample()
    let first = CockpitBoardMeaning.lists(meaning: meaning, names: names, records: records)
    let things: [BoardStoreJSON] =
      records.map {
        ["id": $0["id"] ?? .null, "kind": "stroke", "body": $0, "rev": 1, "device": "ipad-1", "by": "igor"]
      }
      + first.objects.map {
        ["id": $0["id"] ?? .null, "kind": "object", "body": $0, "rev": 1, "device": "ipad-1", "by": "igor"]
      }
      + first.headers.map {
        ["id": $0["id"] ?? .null, "kind": "header", "body": $0, "rev": 1, "device": "ipad-1", "by": "igor"]
      }
    let cache = copy(things)
    let sent = Set(records.compactMap { $0["id"]?.string } + first.ids)
    meaning.headers[0].fold = fold(["b"], own: ["b"], shift: 40)
    let lists = CockpitBoardMeaning.lists(meaning: meaning, names: names, records: records)
    let ops = try CockpitBoardMirror.prepare(
      records: records, cache: cache, sent: sent, name: "Main", laps: StepLaps(), meaning: lists
    ).get().cache.queue.flatMap { $0.ops }
    XCTAssertEqual(ops.compactMap { $0["op"]?.string }, ["set"], "only the header changed: \(ops)")
    XCTAssertEqual(ops.first?["ids"]?.strings, ["h1"])
  }

  func testAThingTheWebAddedIsNeverErasedByTheMirror() throws {
    let (meaning, names, records) = sample()
    let web: BoardStoreJSON = [
      "id": "w-card", "kind": "object", "body": ["id": "w-card", "kind": "question", "ask": "igor2-9", "x": 1, "y": 2],
      "rev": 2, "device": "web-1", "by": "igor",
    ]
    let lists = CockpitBoardMeaning.lists(meaning: meaning, names: names, records: records)
    let ops = try CockpitBoardMirror.prepare(
      records: records, cache: copy([web]), sent: [], name: "Main", laps: StepLaps(), meaning: lists
    ).get().cache.queue.flatMap { $0.ops }
    let erased = ops.filter { $0["op"]?.string == "erase" }.flatMap { $0["ids"]?.strings ?? [] }
    XCTAssertFalse(erased.contains("w-card"), "the web's card stays: \(ops)")
  }

  func testAnAnswerObjectEncodesAsACard() {
    let answer = BoardStoreEncode.encode(
      before: [:], after: ["objects": [["id": "a1", "kind": "answer", "text": "x", "x": 1, "y": 2]]])
    let ops = answer["ops"] as? [[String: Any]] ?? []
    XCTAssertEqual(ops.first?["op"] as? String, "add_card")
  }
}
