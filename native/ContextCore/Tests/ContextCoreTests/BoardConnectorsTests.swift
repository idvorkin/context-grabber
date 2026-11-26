import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Connectors (stories 910–916): the route round things in the way, Larry's connector op, Igor's Connect, and the arrow
/// following its ends through every plan. The cases follow the Cockpit's assets/ink/test_board.mjs.
final class BoardConnectorsTests: XCTestCase {
  /// A box drawn as one stroke.
  private func box(_ id: String, _ x: CGFloat, _ y: CGFloat, w: CGFloat = 60, h: CGFloat = 24, hidden: Bool = false)
    -> BoardOps.Stroke
  {
    let r = CGRect(x: x, y: y, width: w, height: h)
    return BoardOps.Stroke(
      ids: [id], t: nil, bounds: r, hidden: hidden,
      points: [
        CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY),
        CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX, y: r.minY),
      ], pen: 3)
  }

  private func line(_ id: String, _ points: [CGPoint]) -> BoardOps.Stroke {
    let bounds = points.dropFirst().reduce(CGRect(origin: points[0], size: .zero)) {
      $0.union(CGRect(origin: $1, size: .zero))
    }
    return BoardOps.Stroke(ids: [id], t: nil, bounds: bounds, points: points, pen: 3)
  }

  private func grouped(_ pairs: [(String, String)]) -> BoardStrokeMeta {
    var metas = BoardStrokeMeta()
    for (name, group) in pairs { metas.set(BoardMeta(["group": group])!, for: name) }
    return metas
  }

  /// Group gA at (100, 100) and gB at (500, 300), each one box stroke.
  private var two: (strokes: [BoardOps.Stroke], metas: BoardStrokeMeta) {
    ([box("A", 100, 100), box("B", 500, 300)], grouped([("A", "gA"), ("B", "gB")]))
  }

  private func op(_ json: [String: Any]) -> BoardOps.Op? {
    let batch = BoardOps.batch(
      ["board": "b1", "base_rev": 0, "label": "join", "list": [json]], key: "m", source: "web")
    return batch?.ops.first
  }

  /// The canvas once a plan is on it, as the app leaves it: moved, erased, drawn, notes taken in.
  private func applied(_ plan: BoardOps.Plan, _ strokes: [BoardOps.Stroke], _ metas: BoardStrokeMeta)
    -> ([BoardOps.Stroke], BoardStrokeMeta)
  {
    var out: [BoardOps.Stroke] = []
    for (i, s) in strokes.enumerated() where !plan.erase.contains(i) {
      var s = s
      let by = plan.offsets[i] ?? .zero
      s.bounds = s.bounds.offsetBy(dx: by.dx, dy: by.dy)
      s.points = s.points.map { CGPoint(x: $0.x + by.dx, y: $0.y + by.dy) }
      if let hidden = plan.hidden[i] { s.hidden = hidden }
      out.append(s)
    }
    for s in plan.added { out.append(line(s.id, s.points)) }
    var metas = metas
    plan.forgetMetas.forEach { metas.remove($0) }
    metas.merge(plan.metas)
    return (out, metas)
  }

  // MARK: The route

  func testStraightWhenClearOneElbowRoundAThingInTheWayStraightAgainWhenItMoves() {
    let a = CGRect(x: 100, y: 100, width: 60, height: 24)
    let b = CGRect(x: 500, y: 300, width: 60, height: 24)
    let x = CGRect(x: 300, y: 200, width: 60, height: 24)
    let clear = BoardConnectors.route(from: a, to: b, fromSide: .right, toSide: .left, obstacles: [])
    XCTAssertEqual(clear, [CGPoint(x: 160, y: 112), CGPoint(x: 500, y: 312)], "nothing between: straight")
    let bent = BoardConnectors.route(from: a, to: b, fromSide: .right, toSide: .left, obstacles: [x])
    XCTAssertEqual(bent.count, 3, "a thing on the diagonal: one elbow")
    let (p, e, q) = (bent[0], bent[1], bent[2])
    XCTAssertTrue((p.x == e.x || p.y == e.y) && (e.x == q.x || e.y == q.y), "orthogonal: \(bent)")
    XCTAssertFalse(zip(bent, bent.dropFirst()).contains { BoardConnectors.hits($0, $1, x) }, "it crosses nothing")
    let away = BoardConnectors.route(
      from: a, to: b, fromSide: .right, toSide: .left, obstacles: [x.offsetBy(dx: 0, dy: 400)])
    XCTAssertEqual(away.count, 2, "moved out of the way: straight again")
  }

  func testSameRowWithBothElbowsBlockedFallsBackStraight() {
    let a = CGRect(x: 100, y: 100, width: 60, height: 24)
    let b = CGRect(x: 500, y: 100, width: 60, height: 24)
    let x = CGRect(x: 300, y: 100, width: 60, height: 24)
    XCTAssertEqual(BoardConnectors.route(from: a, to: b, fromSide: .right, toSide: .left, obstacles: [x]).count, 2)
  }

  func testTheInkIsTheShaftThenAHead() {
    let ink = BoardConnectors.polyline([CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100)])
    XCTAssertEqual(ink.count, 6, "the shaft through its elbow, then wing, tip, wing")
    XCTAssertEqual(ink[4], CGPoint(x: 100, y: 100), "back to the tip between the wings")
    XCTAssertLessThan(ink[3].y, 100, "the wings sweep back up the last leg")
    XCTAssertLessThan(ink[5].y, 100)
  }

  // MARK: Larry's op

  func testTheWireTakesNamesAndPoints() throws {
    guard case .connector(let byName) = try XCTUnwrap(op(["op": "connector", "id": "k1", "from": "gA", "to": "gB"]))
    else { return XCTFail() }
    XCTAssertEqual(byName.from, .id("gA"))
    XCTAssertEqual(byName.to, .id("gB"))
    guard
      case .connector(let byPoint) = try XCTUnwrap(
        op(["op": "connector", "id": "k2", "from": [130, 120], "to": [430, 320], "color": "#ff0000"]))
    else { return XCTFail() }
    XCTAssertEqual(byPoint.from, .point(CGPoint(x: 130, y: 120)))
    XCTAssertEqual(byPoint.to, .point(CGPoint(x: 430, y: 320)))
    XCTAssertEqual(byPoint.color, 0xFF0000)
    let refused = { (json: [String: Any]) in
      BoardOps.batch(["board": "b1", "base_rev": 0, "list": [json]], key: "m", source: "web")?.refusal
    }
    XCTAssertEqual(refused(["op": "connector", "from": "a", "to": "b"]), BoardOps.Reason.badOp, "no name")
    XCTAssertEqual(refused(["op": "connector", "id": "k", "from": "a"]), BoardOps.Reason.badOp, "one end")
    XCTAssertEqual(
      refused(["op": "connector", "id": "k", "from": ["x": 1, "y": 2], "to": "b"]), BoardOps.Reason.badOp, "{x, y}")
    XCTAssertEqual(
      refused(["op": "connector", "id": "k", "x1": 1, "y1": 2, "x2": 3, "y2": 4]), BoardOps.Reason.badOp, "x1..y2")
  }

  func testLarrysConnectorByNamesLeavesAndLandsOnTheFacingSides() throws {
    let (strokes, metas) = two
    let plan = BoardOps.plan(
      [.connector(.init(id: "k1", from: .id("gA"), to: .id("gB")))], strokes: strokes, metas: metas, pages: 1)
    let drawn = try XCTUnwrap(plan.added.first { $0.id == "k1" })
    let c = try XCTUnwrap(BoardConnector(drawn.meta))
    XCTAssertEqual([c.from, c.to], ["gA", "gB"])
    XCTAssertEqual(c.fromSide, .right)
    XCTAssertEqual(c.toSide, .left)
    XCTAssertEqual(c.route, [CGPoint(x: 160, y: 112), CGPoint(x: 500, y: 312)])
    XCTAssertEqual(drawn.points.first, CGPoint(x: 160, y: 112))
    XCTAssertEqual(plan.connected, ["k1"])
    XCTAssertTrue(plan.changesBoard)
    XCTAssertEqual(BoardConnector(plan.metas["k1"]), c, "its notes are kept, for Larry and for following")
  }

  func testByPointsTheThingUnderEachEndOnBarePaperAPlainArrowAMissingNameNothing() throws {
    let (strokes, metas) = two
    let byPoints = BoardOps.plan(
      [.connector(.init(id: "k1", from: .point(CGPoint(x: 130, y: 120)), to: .point(CGPoint(x: 530, y: 320))))],
      strokes: strokes, metas: metas, pages: 1)
    let c = try XCTUnwrap(BoardConnector(byPoints.added.first?.meta))
    XCTAssertEqual([c.from, c.to], ["gA", "gB"])

    let loose = BoardOps.plan(
      [.connector(.init(id: "k2", from: .point(CGPoint(x: 130, y: 120)), to: .point(CGPoint(x: 700, y: 700))))],
      strokes: strokes, metas: metas, pages: 1)
    let arrow = try XCTUnwrap(loose.added.first)
    XCTAssertNil(arrow.meta, "an end on bare paper: plain ink")
    XCTAssertEqual(arrow.points.first, CGPoint(x: 130, y: 120))
    XCTAssertEqual(arrow.points[1], CGPoint(x: 700, y: 700))
    XCTAssertEqual(loose.connected, [])

    let missing = BoardOps.plan(
      [.connector(.init(id: "k3", from: .id("gA"), to: .id("nope")))], strokes: strokes, metas: metas, pages: 1)
    XCTAssertTrue(missing.added.isEmpty)
    XCTAssertEqual(missing.missingIDs, ["nope"])
  }

  func testAnEndOnAWordOfIgorsMakesTheWordOneThing() throws {
    // "hi" in three strokes at y 100, and Larry's group gB.
    let word = [box("h1", 100, 100, w: 8, h: 20), box("h2", 112, 100, w: 8, h: 20), box("i1", 126, 100, w: 4, h: 20)]
    let strokes = word + [box("B", 500, 300)]
    let plan = BoardOps.plan(
      [.connector(.init(id: "k1", from: .point(CGPoint(x: 118, y: 125)), to: .id("gB")))], strokes: strokes,
      metas: grouped([("B", "gB")]), pages: 1)
    let c = try XCTUnwrap(BoardConnector(plan.added.first?.meta))
    XCTAssertEqual(c.from, "k1-from")
    XCTAssertEqual(["h1", "h2", "i1"].map { plan.metas[$0]?.group }, ["k1-from", "k1-from", "k1-from"])
    XCTAssertEqual(c.route.first, CGPoint(x: 130, y: 110), "it leaves the whole word's right side")
  }

  /// Story 947, bead context-grabber-3iz (Igor, 2026-11-22, card igor2-88g.1620.5: "a connected word is one thing; a
  /// tap takes it whole"): once an arrow joins a word of his, a finger tap on any of its strokes takes the whole word,
  /// as for Larry's groups; his word no arrow joins is still plain ink to a tap.
  func testAFingerTapOnAConnectedWordOfIgorsTakesTheWholeWord() {
    let word = [box("h1", 100, 100, w: 8, h: 20), box("h2", 112, 100, w: 8, h: 20), box("i1", 126, 100, w: 4, h: 20)]
    let other = [box("o1", 100, 200, w: 8, h: 20), box("o2", 112, 200, w: 8, h: 20)]
    let strokes = word + other + [box("B", 500, 300)]
    let plan = BoardOps.plan(
      [.connector(.init(id: "k1", from: .point(CGPoint(x: 118, y: 125)), to: .id("gB")))], strokes: strokes,
      metas: grouped([("B", "gB")]), pages: 1)
    var groups = ["B": "gB"]
    for (name, meta) in plan.metas { if let group = meta.group { groups[name] = group } }
    let outline = BoardOutline(strokes: strokes, headers: [], groups: groups)
    let tapped = outline.group(at: CGPoint(x: 100, y: 110), slop: 22)
    XCTAssertEqual(tapped?.group, "k1-from")
    XCTAssertEqual(tapped?.names.sorted(), ["h1", "h2", "i1"], "the whole word, from a tap on one stroke of it")
    XCTAssertNil(outline.group(at: CGPoint(x: 100, y: 210), slop: 22), "his word no arrow joins stays his ink")
  }

  func testAWordStaysPlainInkWhenNoConnectorIsDrawn() {
    let word = [box("h1", 100, 100, w: 8, h: 20), box("h2", 112, 100, w: 8, h: 20), box("i1", 126, 100, w: 4, h: 20)]
    let onTheWord = CGPoint(x: 118, y: 125)
    for (other, why) in [
      (BoardOps.NewConnector.End.point(CGPoint(x: 700, y: 700)), "the other end on bare paper"),
      (.point(CGPoint(x: 120, y: 120)), "both ends on the same word"),
      (.id("nope"), "the other end names nothing"),
    ] {
      let plan = BoardOps.plan(
        [.connector(.init(id: "k1", from: .point(onTheWord), to: other))], strokes: word, metas: BoardStrokeMeta(),
        pages: 1)
      XCTAssertEqual(plan.connected, [], why)
      XCTAssertEqual(["h1", "h2", "i1"].map { plan.metas[$0]?.group }, [nil, nil, nil], why)
    }
  }

  // MARK: Following

  func testItFollowsAnEndThatMovesAndOnlyItsNotesMoveWhenEverythingMoves() throws {
    var (strokes, metas) = two
    let made = BoardOps.plan(
      [.connector(.init(id: "k1", from: .id("gA"), to: .id("gB")))], strokes: strokes, metas: metas, pages: 1)
    (strokes, metas) = applied(made, strokes, metas)
    let at = try XCTUnwrap(strokes.firstIndex { $0.ids == ["k1"] })

    let moved = BoardOps.plan([.translateIDs(["gB"], dx: 0, dy: 100)], strokes: strokes, metas: metas, pages: 1)
    XCTAssertEqual(moved.rerouted, ["k1"])
    XCTAssertTrue(moved.erase.contains(at), "the old arrow goes")
    let again = try XCTUnwrap(moved.added.first { $0.id == "k1" })
    XCTAssertEqual(BoardConnector(again.meta)?.route.last, CGPoint(x: 500, y: 412), "to where gB is now")

    let pushed = BoardOps.plan([.translateBelow(y: 0, dy: 80)], strokes: strokes, metas: metas, pages: 1)
    XCTAssertEqual(pushed.rerouted, [], "everything moved together: the arrow moved with it")
    XCTAssertEqual(pushed.offsets[at], CGVector(dx: 0, dy: 80))
    XCTAssertEqual(BoardConnector(pushed.metas["k1"])?.route.first, CGPoint(x: 160, y: 192), "its notes follow")

    let half = BoardOps.plan([.translateBelow(y: 200, dy: 80)], strokes: strokes, metas: metas, pages: 1)
    XCTAssertEqual(half.rerouted, ["k1"], "a push that splits its ends draws it again")
    XCTAssertEqual(BoardConnector(half.added.first { $0.id == "k1" }?.meta)?.route.first, CGPoint(x: 160, y: 112))
  }

  func testIgorsOwnMoveIsFollowedByAPlanOfNothing() throws {
    var (strokes, metas) = two
    let made = BoardOps.plan(
      [.connector(.init(id: "k1", from: .id("gA"), to: .id("gB")))], strokes: strokes, metas: metas, pages: 1)
    (strokes, metas) = applied(made, strokes, metas)
    var still = BoardOps.Plan(pagesBefore: 1, pagesAfter: 1)
    BoardConnectors.follow(&still, strokes: strokes, metas: metas)
    XCTAssertFalse(still.changesBoard, "nothing moved: nothing to draw")
    // His lasso moved gA's stroke: the canvas is already moved when the board looks.
    strokes[0] = box("A", 100, 400)
    var after = BoardOps.Plan(pagesBefore: 1, pagesAfter: 1)
    BoardConnectors.follow(&after, strokes: strokes, metas: metas)
    XCTAssertEqual(after.rerouted, ["k1"])
    XCTAssertEqual(BoardConnector(after.metas["k1"])?.route.first?.y, 412)
  }

  func testARouteBendsRoundAGroupPutBetweenAndStraightensWhenItGoes() throws {
    var (strokes, metas) = two
    let made = BoardOps.plan(
      [.connector(.init(id: "k1", from: .id("gA"), to: .id("gB")))], strokes: strokes, metas: metas, pages: 1)
    (strokes, metas) = applied(made, strokes, metas)
    let added = BoardOps.plan(
      [
        .addStrokes([
          .init(id: "X", points: [CGPoint(x: 300, y: 200), CGPoint(x: 360, y: 224)], meta: BoardMeta(["group": "gX"]))
        ])
      ],
      strokes: strokes, metas: metas, pages: 1)
    XCTAssertEqual(BoardConnector(added.metas["k1"])?.route.count, 3, "a group in the way: one elbow")
    (strokes, metas) = applied(added, strokes, metas)
    let away = BoardOps.plan([.translateIDs(["gX"], dx: 0, dy: 400)], strokes: strokes, metas: metas, pages: 1)
    XCTAssertEqual(BoardConnector(away.metas["k1"])?.route.count, 2, "moved away: straight again")
  }

  func testAnEndErasedLeavesTheArrowAsPlainInk() throws {
    var (strokes, metas) = two
    metas.set(BoardMeta(["group": "gB", "note": "kept"])!, for: "B")
    let made = BoardOps.plan(
      [.connector(.init(id: "k1", from: .id("gA"), to: .id("gB")))], strokes: strokes, metas: metas, pages: 1)
    (strokes, metas) = applied(made, strokes, metas)
    let gone = BoardOps.plan([.delete(["gB"])], strokes: strokes, metas: metas, pages: 1)
    XCTAssertEqual(gone.loosened, ["k1"])
    XCTAssertTrue(gone.forgetMetas.contains("k1"), "its connector notes go")
    let at = try XCTUnwrap(strokes.firstIndex { $0.ids == ["k1"] })
    XCTAssertFalse(gone.erase.contains(at), "the ink stays where it was")
  }

  func testAnEndFoldedAwayPointsAtItsHeader() throws {
    // Header H at y 300 holds gB, folded under it.
    let strokes = [box("A", 100, 100), box("H", 400, 300, w: 100), box("B", 420, 340, hidden: true)]
    let metas = grouped([("A", "gA"), ("B", "gB")])
    let plan = BoardOps.plan(
      [.connector(.init(id: "k1", from: .id("gA"), to: .id("gB")))], strokes: strokes, metas: metas,
      folds: ["H": "h:H", "B": "h:H"], pages: 1)
    let c = try XCTUnwrap(BoardConnector(plan.added.first?.meta))
    XCTAssertEqual(c.route.last, CGPoint(x: 400, y: 312), "the header's row")
  }

  // MARK: Igor's Connect

  /// Board.mjs's `boxes()`: gA, gB, and Igor's drawn arrow from A to B (a shaft and a head).
  private var drawn: [BoardOps.Stroke] {
    two.strokes + [
      line("shaft", [CGPoint(x: 165, y: 115), CGPoint(x: 300, y: 200), CGPoint(x: 495, y: 310)]),
      line("head", [CGPoint(x: 480, y: 295), CGPoint(x: 495, y: 310), CGPoint(x: 478, y: 318)]),
    ]
  }

  func testConnectMakesHisArrowACleanConnectorHeadFirst() throws {
    let metas = two.metas
    let ops = try XCTUnwrap(
      BoardConnectors.connect(selected: ["shaft", "head"], id: "k1", strokes: drawn, metas: metas))
    let plan = BoardOps.plan(ops, strokes: drawn, metas: metas, pages: 1)
    XCTAssertEqual(plan.erase, [2, 3], "his drawn ink goes")
    let c = try XCTUnwrap(BoardConnector(plan.added.first?.meta))
    XCTAssertEqual([c.from, c.to, c.by], ["gA", "gB", "igor"])

    var reversed = drawn
    reversed[3] = line("head", [CGPoint(x: 170, y: 120), CGPoint(x: 165, y: 125), CGPoint(x: 180, y: 132)])
    let back = try XCTUnwrap(
      BoardConnectors.connect(selected: ["shaft", "head"], id: "k1", strokes: reversed, metas: metas))
    let r = try XCTUnwrap(
      BoardConnector(BoardOps.plan(back, strokes: reversed, metas: metas, pages: 1).added.first?.meta))
    XCTAssertEqual([r.from, r.to], ["gB", "gA"], "the head decides which way it points")

    var loose = drawn
    loose[2] = line("shaft", [CGPoint(x: 165, y: 115), CGPoint(x: 600, y: 600)])
    loose[3] = line("head", [CGPoint(x: 590, y: 590), CGPoint(x: 600, y: 600)])
    XCTAssertNil(
      BoardConnectors.connect(selected: ["shaft", "head"], id: "k", strokes: loose, metas: metas),
      "an end on bare paper: no Connect")
    XCTAssertNil(BoardConnectors.connect(selected: [], id: "k", strokes: drawn, metas: metas))
  }

  /// #1440, story 1358: on the iPad the lasso took the whole diagram (both boxes and the arrow, 20 strokes); Connect
  /// still finds the arrow inside and joins the two things around it.
  func testConnectFindsTheArrowInsideALassoThatTookTheWholeDiagram() throws {
    let metas = two.metas
    let ops = try XCTUnwrap(
      BoardConnectors.connect(selected: ["A", "B", "shaft", "head"], id: "k1", strokes: drawn, metas: metas))
    let plan = BoardOps.plan(ops, strokes: drawn, metas: metas, pages: 1)
    XCTAssertEqual(plan.erase, [2, 3], "only his arrow's ink goes; the boxes stay")
    let c = try XCTUnwrap(BoardConnector(plan.added.first?.meta))
    XCTAssertEqual([c.from, c.to], ["gA", "gB"])

    // His own boxes, plain ink with no groups, and an elbow arrow, as he drew it.
    let elbow = [
      box("A", 100, 100), box("B", 500, 300),
      line(
        "shaft",
        [CGPoint(x: 165, y: 112), CGPoint(x: 330, y: 112), CGPoint(x: 330, y: 312), CGPoint(x: 495, y: 312)]),
      line("head", [CGPoint(x: 482, y: 302), CGPoint(x: 495, y: 312), CGPoint(x: 482, y: 322)]),
    ]
    XCTAssertNotNil(
      BoardConnectors.connect(selected: ["A", "B", "shaft", "head"], id: "k2", strokes: elbow),
      "an elbow arrow between two of his own boxes")

    XCTAssertNil(
      BoardConnectors.connect(selected: ["A", "B"], id: "k", strokes: drawn, metas: metas),
      "two boxes and no arrow: no Connect")
  }

  func testTheNotesRoundTrip() {
    let c = BoardConnector(
      from: "a", to: "b", fromSide: .bottom, toSide: .top, route: [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)],
      color: 0x00FF00, by: "igor")
    let meta = c.meta(over: BoardMeta(["group": "g", "mine": 1]))
    XCTAssertEqual(BoardConnector(meta), c)
    XCTAssertEqual(meta.group, "g", "his other notes stay")
    XCTAssertEqual(BoardConnector.without(meta)?.group, "g")
    XCTAssertNil(BoardConnector(BoardConnector.without(meta)))
    XCTAssertNil(BoardConnector.without(c.meta(over: nil)))
  }

  // MARK: Larry's connector marks (stories 917–919)

  func testAReplysConnectorMarkIsReadByNamesOrByPoints() throws {
    let byName = try XCTUnwrap(
      WhiteboardTurn.anyShape(["kind": "connector", "from": "gA", "to": "gB", "color": "#ff0000", "pen": 4]))
    XCTAssertEqual(byName.kind, .connector)
    XCTAssertEqual([byName.from, byName.to], ["gA", "gB"])
    XCTAssertEqual(byName.color, 0xFF0000)
    XCTAssertTrue(WhiteboardTurn.lines(byName, frame: .zero, scale: 1).isEmpty, "by name it needs the board to draw")
    let byPoints = try XCTUnwrap(
      WhiteboardTurn.anyShape(["kind": "connector", "x1": 10.0, "y1": 20.0, "x2": 110.0, "y2": 20.0]))
    XCTAssertNil(byPoints.from)
    XCTAssertEqual(byPoints.points, [CGPoint(x: 10, y: 20), CGPoint(x: 110, y: 20)])
    let arrow = WhiteboardTurn.lines(byPoints, frame: CGRect(x: 100, y: 0, width: 1, height: 1), scale: 2)
    XCTAssertEqual(arrow.first?.first, CGPoint(x: 105, y: 10), "an arrow between its points on the board")
    XCTAssertNil(WhiteboardTurn.anyShape(["kind": "connector", "from": "gA", "to": "gA"]), "one thing is no join")
    XCTAssertNil(WhiteboardTurn.anyShape(["kind": "connector", "from": "gA"]), "one end")
    XCTAssertNil(WhiteboardTurn.anyShape(["kind": "connector", "from": "has space", "to": "gB"]))
  }

  func testAMarkBecomesAConnectorOpInBoardPoints() throws {
    let shape = WhiteboardTurn.Shape(
      kind: .connector, points: [CGPoint(x: 60, y: 140), CGPoint(x: 860, y: 540)], pen: 8, color: 0x00FF00)
    let new = try XCTUnwrap(
      BoardConnectors.mark(shape, frame: CGRect(x: 100, y: 50, width: 400, height: 300), scale: 2, id: "row 1#0"))
    XCTAssertEqual(new.id, "m-row-1-0", "a name the strokes endpoint takes")
    XCTAssertEqual(new.from, .point(CGPoint(x: 130, y: 120)))
    XCTAssertEqual(new.to, .point(CGPoint(x: 530, y: 320)))
    XCTAssertEqual(new.width, 4)
    XCTAssertEqual(new.color, 0x00FF00)
    XCTAssertNil(
      BoardConnectors.mark(.init(kind: .arrow, points: shape.points), frame: .zero, scale: 1, id: "r#1"),
      "an arrow mark stays an arrow")
  }

  func testKeepingAMarkJoinsItsEndsOrDrawsAPlainArrowOrNothing() throws {
    let (strokes, metas) = two
    let joined = BoardConnectors.keep(
      .init(id: "m-r-0", from: .id("gA"), to: .id("gB")), strokes: strokes, metas: metas)
    XCTAssertTrue(joined.joins)
    XCTAssertEqual(joined.stroke?.points.first, CGPoint(x: 160, y: 112))
    XCTAssertEqual(Set(joined.metas.keys), ["m-r-0"])

    let byPoints = BoardConnectors.keep(
      .init(id: "m-r-1", from: .point(CGPoint(x: 130, y: 120)), to: .point(CGPoint(x: 530, y: 320))),
      strokes: strokes, metas: metas)
    XCTAssertEqual(BoardConnector(byPoints.stroke?.meta).map { [$0.from, $0.to] }, ["gA", "gB"])

    let loose = BoardConnectors.keep(
      .init(id: "m-r-2", from: .point(CGPoint(x: 130, y: 120)), to: .point(CGPoint(x: 700, y: 700))),
      strokes: strokes, metas: metas)
    XCTAssertFalse(loose.joins, "an end on bare paper: a plain arrow")
    XCTAssertNotNil(loose.stroke)

    let nowhere = BoardConnectors.keep(
      .init(id: "m-r-3", from: .id("gA"), to: .id("gone")), strokes: strokes, metas: metas)
    XCTAssertNil(nowhere.stroke)
    XCTAssertEqual(nowhere.missing, ["gone"])
  }

  func testKeepingBringsOnlyItsOwnNotesAndTheWordItGroups() throws {
    // gA and gB already joined by k1, whose stored route is stale: the keep doesn't touch k1's notes.
    var (strokes, metas) = two
    let stale = BoardConnector(
      from: "gA", to: "gB", fromSide: .right, toSide: .left, route: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)])
    strokes.append(line("k1", [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]))
    metas.set(stale.meta(over: nil), for: "k1")
    let word = [box("h1", 100, 400, w: 8, h: 20), box("h2", 112, 400, w: 8, h: 20)]
    let kept = BoardConnectors.keep(
      .init(id: "m-r-0", from: .point(CGPoint(x: 116, y: 425)), to: .id("gB")), strokes: strokes + word, metas: metas)
    XCTAssertTrue(kept.joins)
    XCTAssertEqual(Set(kept.metas.keys), ["m-r-0", "h1", "h2"])
    XCTAssertEqual(kept.metas["h1"]?.group, "m-r-0-from")
  }
}
