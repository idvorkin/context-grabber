import XCTest

@testable import ContextCore

/// Stories 855–861: headers fold their sections by indent, folds nest, the outline collapses to a level, lines that
/// look like headers are offered, and a held Pencil picks up a word, all as on the web board.
final class BoardOutlineTests: XCTestCase {
  /// A letter-sized stroke: a caret, never an underline.
  private func letter(_ id: String, x: CGFloat, y: CGFloat, w: CGFloat = 20, h: CGFloat = 24) -> BoardOps.Stroke {
    let points = [CGPoint(x: x, y: y + h), CGPoint(x: x + w / 2, y: y), CGPoint(x: x + w, y: y + h)]
    return BoardOps.Stroke(
      ids: [id], t: nil, bounds: CGRect(x: x, y: y, width: w, height: h), points: points, pen: 3)
  }

  /// A word of three letters, 4 points apart: `<id>0`, `<id>1`, `<id>2`.
  private func word(_ id: String, x: CGFloat, y: CGFloat, h: CGFloat = 24) -> [BoardOps.Stroke] {
    (0..<3).map { letter("\(id)\($0)", x: x + CGFloat($0) * 24, y: y, h: h) }
  }

  /// A header at the margin's edge, two indented lines, and a line back at its indent.
  private var outline: [BoardOps.Stroke] {
    word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("b", x: 140, y: 180) + word("c", x: 100, y: 220)
  }

  private func top(_ outline: BoardOutline, _ id: String) -> CGFloat? {
    outline.strokes.first { $0.ids.contains(id) }?.bounds.minY
  }

  private func hidden(_ outline: BoardOutline, _ id: String) -> Bool {
    outline.strokes.first { $0.ids.contains(id) }?.hidden ?? false
  }

  func testAMarginTapMakesARowAHeaderOnlyOnce() {
    var o = BoardOutline(strokes: outline, headers: [])
    XCTAssertFalse(o.markHeader(at: 60, id: "x"), "blank paper is no header")
    XCTAssertTrue(o.markHeader(at: 112, id: "h"))
    XCTAssertEqual(o.headers.first?.ids.sorted(), ["h0", "h1", "h2"])
    XCTAssertFalse(o.markHeader(at: 112, id: "again"), "already one")
    XCTAssertEqual(o.header(at: 112 + 24)?.id, "h", "a tap a little below is on it")
    XCTAssertNil(o.header(at: 160))
  }

  func testAFoldHidesTheIndentedLinesAndClosesUpAndUnfoldPutsThemBack() throws {
    var o = BoardOutline(strokes: outline, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"])])
    XCTAssertTrue(o.fold("h"))
    XCTAssertTrue(hidden(o, "a0") && hidden(o, "b2"), "the indented lines hide")
    XCTAssertFalse(hidden(o, "c0"), "the line back at the header's indent doesn't")
    XCTAssertEqual(top(o, "c0"), 180, "and slides up to a line under the header, whole lines")
    XCTAssertEqual(top(o, "a0"), 140, "hidden ink stays where it was")
    let fold = try XCTUnwrap(o.headers.first?.fold)
    XCTAssertEqual(fold.lines, 2)
    XCTAssertEqual(o.foldedNames, Set(["a0", "a1", "a2", "b0", "b1", "b2"]))
    let wire = try XCTUnwrap(o.wire.first)
    XCTAssertEqual(wire["header"] as? String, "h")
    XCTAssertEqual((wire["header_strokes"] as? [String])?.sorted(), ["h0", "h1", "h2"])
    XCTAssertEqual(wire["lines"] as? Int, 2)
    XCTAssertEqual((wire["strokes"] as? [String])?.count, 6)

    let plan = o.plan(from: outline, pages: 1)
    XCTAssertEqual(plan.hidden.count, 6)
    XCTAssertEqual(plan.offsets.values.map(\.dy), [-40, -40, -40])

    XCTAssertTrue(o.unfold("h"))
    XCTAssertEqual(o.strokes, outline, "everything back where it was")
    XCTAssertTrue(o.wire.isEmpty)
  }

  func testAFoldMovesWithItsHeaderAndAPushNeverSplitsIt() {
    var o = BoardOutline(strokes: outline, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"])])
    o.fold("h")
    // A push at the line just under the header moves the line below, not the hidden body away from its header.
    let plan = BoardOps.plan([.translateBelow(y: 130, dy: 80)], strokes: o.strokes, folds: o.tags, pages: 1)
    let moved = Set(plan.offsets.keys.flatMap { o.strokes[$0].ids })
    XCTAssertEqual(moved, ["c0", "c1", "c2"])
    let push = BoardOps.plan([.translateBelow(y: 90, dy: 80)], strokes: o.strokes, folds: o.tags, pages: 1)
    XCTAssertEqual(push.offsets.count, 12, "a push above the header takes the header and its fold together")
    XCTAssertEqual(
      BoardOps.shownBoxes(strokes: o.strokes, folds: o.tags).count, 4, "the folded header's box is its own row")
  }

  func testUnfoldMakesRoomForWhatWasWrittenUnderTheFoldedHeader() {
    var o = BoardOutline(strokes: outline, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"])])
    o.fold("h")
    o.strokes += word("n", x: 100, y: 140)  // written in the gap the fold closed up
    o.unfold("h")
    XCTAssertEqual(top(o, "a0"), 140, "the body shows where it was")
    let newTop = top(o, "n0") ?? 0
    XCTAssertGreaterThanOrEqual(newTop, 204, "what was written meanwhile lands after the body: \(newTop)")
    XCTAssertGreaterThan(top(o, "c0") ?? 0, newTop)
  }

  func testASectionEndsWhereTheInkReturnsToTheIndentNotAtBlankPaper() {
    let strokes =
      word("h", x: 100, y: 100) + word("a", x: 140, y: 140) + word("b", x: 140, y: 400)
      + word("c", x: 100, y: 440)
    var o = BoardOutline(strokes: strokes, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"])])
    o.fold("h")
    XCTAssertTrue(hidden(o, "b0"), "blank paper never ends a section")
    XCTAssertFalse(hidden(o, "c0"))
    XCTAssertEqual(top(o, "c0"), 200, "a line or two under the header, in whole lines")
  }

  func testAHeaderWhoseNextLineIsNotIndentedRunsToTheNextHeaderAtItsIndent() {
    let strokes = word("h", x: 100, y: 100) + word("a", x: 100, y: 140) + word("g", x: 100, y: 180)
    var o = BoardOutline(
      strokes: strokes,
      headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"]), BoardHeader(id: "g", ids: ["g0", "g1", "g2"])])
    o.fold("h")
    XCTAssertTrue(hidden(o, "a0"))
    XCTAssertFalse(hidden(o, "g0"), "the next header at its indent ends it")
  }

  /// Outer header, an indented inner header with its own deeper lines, a line back under the outer, and the next top
  /// header.
  private var nested: BoardOutline {
    let strokes =
      word("o", x: 100, y: 100) + word("i", x: 140, y: 140) + word("d", x: 180, y: 180) + word("e", x: 140, y: 220)
      + word("p", x: 100, y: 260) + word("q", x: 140, y: 300)
    return BoardOutline(
      strokes: strokes,
      headers: [
        BoardHeader(id: "o", ids: ["o0", "o1", "o2"]), BoardHeader(id: "i", ids: ["i0", "i1", "i2"]),
        BoardHeader(id: "p", ids: ["p0", "p1", "p2"]),
      ])
  }

  func testFoldsNest() {
    var o = nested
    XCTAssertTrue(o.fold("i"))
    XCTAssertTrue(hidden(o, "d0"))
    XCTAssertFalse(hidden(o, "e0"), "the inner section ends back at its indent")
    XCTAssertTrue(o.fold("o"))
    XCTAssertTrue(hidden(o, "i0") && hidden(o, "e0"))
    XCTAssertEqual(top(o, "p0"), 180)
    XCTAssertFalse(o.shows(o.header("i")!), "the inner header is folded away")
    XCTAssertNil(o.header(at: 152), "and a tap there is on the line slid up, not on it")
    XCTAssertTrue(o.unfold("o"))
    XCTAssertTrue(o.isFolded(o.header("i")!), "the inner one is still folded")
    XCTAssertTrue(hidden(o, "d0"))
    XCTAssertFalse(hidden(o, "i0"))
    o.unfoldAll()
    XCTAssertEqual(o.strokes, nested.strokes)
  }

  func testUnfoldAllOpensFoldsInsideFolds() {
    var o = nested
    o.fold("i")
    o.fold("o")
    o.unfoldAll()
    XCTAssertEqual(o.strokes, nested.strokes)
    XCTAssertTrue(o.headers.allSatisfy { $0.fold == nil })
  }

  func testLevelsAndCollapsingToOne() {
    var o = nested
    XCTAssertEqual(o.levels(), ["o": 1, "i": 2, "p": 1])
    o.collapse(to: 1)
    XCTAssertTrue(o.isFolded(o.header("o")!) && o.isFolded(o.header("p")!))
    XCTAssertTrue(hidden(o, "q0") && hidden(o, "i0"))
    o.collapse(to: 2)
    XCTAssertFalse(o.isFolded(o.header("o")!), "a top header with headers under it stays open")
    XCTAssertTrue(o.isFolded(o.header("i")!), "its sub-header folds")
    XCTAssertTrue(o.isFolded(o.header("p")!), "a top header with none under it folds")
    XCTAssertFalse(hidden(o, "e0"), "text between a header and its sub-header stays in view")
    o.foldAll()
    XCTAssertTrue(o.headers.allSatisfy { o.isFolded($0) || !o.shows($0) })
  }

  func testAnUndoThatShowsTheInkAgainOpensTheFold() {
    var o = BoardOutline(strokes: outline, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2"])])
    o.fold("h")
    // The canvas as it was before the fold, with the fold still remembered.
    let back = BoardOutline(strokes: outline, headers: o.headers)
    XCTAssertFalse(back.isFolded(back.headers[0]))
    XCTAssertTrue(back.wire.isEmpty)
  }

  func testABigOrUnderlinedLineIsOffered() {
    var strokes: [BoardOps.Stroke] = []
    for i in 0..<4 { strokes += word("l\(i)", x: 100, y: 100 + CGFloat(i) * 40) }
    strokes += (0..<3).map { letter("big\($0)", x: 100 + CGFloat($0) * 44, y: 300, w: 40, h: 60) }
    strokes += word("u", x: 100, y: 420)
    strokes.append(
      BoardOps.Stroke(
        ids: ["line"], t: nil, bounds: CGRect(x: 98, y: 448, width: 70, height: 4),
        points: [CGPoint(x: 98, y: 450), CGPoint(x: 168, y: 450)], pen: 3))
    let o = BoardOutline(strokes: strokes, headers: [])
    let found = o.candidates()
    XCTAssertEqual(found.map(\.why), [.big, .underline])
    XCTAssertEqual(found.first?.y ?? 0, 330, accuracy: 1)
    let few = BoardOutline(strokes: Array(strokes.suffix(4)), headers: [])
    XCTAssertEqual(few.candidates().map(\.why), [.underline], "big needs four lines of his to judge by")
    var marked = o
    marked.markHeader(at: 330, id: "big")
    XCTAssertEqual(marked.candidates().map(\.why), [.underline], "a header is offered no more")
  }

  func testAHeldPencilPicksUpTheWordUnderIt() {
    // Two words on a line, 24 points apart within each, 40 between.
    let strokes = word("a", x: 100, y: 100) + word("b", x: 212, y: 100)
    let o = BoardOutline(strokes: strokes, headers: [])
    XCTAssertEqual(o.word(at: CGPoint(x: 110, y: 112))?.sorted(), ["a0", "a1", "a2"])
    XCTAssertEqual(o.word(at: CGPoint(x: 230, y: 112))?.sorted(), ["b0", "b1", "b2"])
    XCTAssertNil(o.word(at: CGPoint(x: 400, y: 400)), "off ink")
    let still = (0...5).map { (point: CGPoint(x: 110, y: 112), time: Double($0) * 0.1) }
    let drag = still + [(point: CGPoint(x: 160, y: 300), time: 0.7)]
    let picked = o.pickUp(drag)
    XCTAssertEqual(picked?.names.sorted(), ["a0", "a1", "a2"])
    XCTAssertEqual(picked?.by, CGVector(dx: 50, dy: 188))
    let quick = [(point: CGPoint(x: 110, y: 112), time: 0.0), (point: CGPoint(x: 160, y: 300), time: 0.2)]
    XCTAssertNil(o.pickUp(quick), "a stroke that never held draws")
    XCTAssertNil(o.pickUp(still.map { (point: CGPoint(x: 400, y: 400), time: $0.time) }), "held off ink draws")
  }

  /// Story 947 (#947): a finger tap on any stroke of a group, within a finger's reach of its line, takes the whole group;
  /// inside the group's box but off its strokes, on his own writing nearer, on a bare text or on a header is no group's.
  func testAFingerTapOnAGroupsStrokeTakesTheWholeGroup() {
    // His word at y 100; Larry's group of two words at y 200, one at x 100 and one at x 300; his word between them.
    let mine = word("m", x: 100, y: 100)
    let larry = word("g", x: 100, y: 200) + word("k", x: 300, y: 200)
    let between = word("b", x: 190, y: 200)
    var groups: [String: String] = [:]
    for s in larry { for id in s.ids { groups[id] = "reply-1" } }
    let o = BoardOutline(strokes: mine + larry + between, headers: [], groups: groups)
    let all = ["g0", "g1", "g2", "k0", "k1", "k2"]
    // On g0's left leg: (100, 224) to (110, 200).
    XCTAssertEqual(o.group(at: CGPoint(x: 105, y: 212), slop: 22)?.group, "reply-1")
    XCTAssertEqual(o.group(at: CGPoint(x: 105, y: 212), slop: 22)?.names.sorted(), all)
    XCTAssertEqual(o.group(at: CGPoint(x: 320, y: 230), slop: 22)?.names.sorted(), all, "any stroke of it, near")
    XCTAssertNil(o.group(at: CGPoint(x: 105, y: 260), slop: 22), "out of a finger's reach of every stroke")
    XCTAssertNil(o.group(at: CGPoint(x: 122, y: 201), slop: 5), "inside the group's box, off its strokes")
    XCTAssertNil(o.group(at: CGPoint(x: 200, y: 212), slop: 22), "his own word is nearer")
    XCTAssertNil(o.group(at: CGPoint(x: 105, y: 112), slop: 22), "his writing is no group")
    XCTAssertNil(
      BoardOutline(strokes: mine + larry, headers: []).group(at: CGPoint(x: 105, y: 212), slop: 22), "no groups")
  }

  /// Story 947: a kept text inside a group is the group's; one outside any is not (a tap there rewords it, story 940).
  func testATextInsideAGroupIsTheGroupsAndABareTextIsNot() {
    var glyphs = word("t", x: 100, y: 200)
    for i in glyphs.indices { glyphs[i].t = 1000 }
    var bare = word("u", x: 100, y: 400)
    for i in bare.indices { bare[i].t = 2000 }
    let circle = letter("c", x: 200, y: 200)
    let texts = [
      BoardText(id: "text-1", t: 1000, text: "hi", font: .plain, size: 24, color: "#000000", glyphs: 3),
      BoardText(id: "text-2", t: 2000, text: "ok", font: .plain, size: 24, color: "#000000", glyphs: 3),
    ]
    let groups = ["text-1": "reply-2", "c": "reply-2"]
    let o = BoardOutline(strokes: glyphs + [circle] + bare, headers: [], texts: texts, groups: groups)
    XCTAssertEqual(o.group(at: CGPoint(x: 105, y: 212), slop: 22)?.group, "reply-2", "the text's glyph")
    XCTAssertEqual(o.group(at: CGPoint(x: 105, y: 212), slop: 22)?.names.sorted(), ["c", "t0", "t1", "t2"])
    XCTAssertEqual(o.group(at: CGPoint(x: 205, y: 212), slop: 22)?.names.sorted(), ["c", "t0", "t1", "t2"], "its mark")
    XCTAssertNil(o.group(at: CGPoint(x: 105, y: 412), slop: 22), "a bare text is no group")
  }

  /// Stories 1140–1142 (#1171): a finger tap on one thing of Larry's he kept takes that one thing, every stroke made at
  /// its moment and nothing else: not his ink under it, not Larry's other marks; his ink nearer is his; a group is the
  /// group's.
  func testAFingerTapOnOneThingOfLarrysTakesItAlone() {
    // A box of his (one stroke) round Larry's text of three glyphs; two marks of Larry's, kept apart, of two strokes each.
    let box = BoardOps.Stroke(
      ids: ["box"], t: 1, bounds: CGRect(x: 80, y: 180, width: 200, height: 70),
      points: [
        CGPoint(x: 80, y: 180), CGPoint(x: 280, y: 180), CGPoint(x: 280, y: 250), CGPoint(x: 80, y: 250),
        CGPoint(x: 80, y: 180),
      ], pen: 3)
    var glyphs = word("t", x: 100, y: 200)
    for i in glyphs.indices { glyphs[i].t = 1000 }
    var markA = word("a", x: 100, y: 400)
    var markB = word("b", x: 300, y: 400)
    for i in markA.indices { markA[i].t = 2000 }
    for i in markB.indices { markB[i].t = 3000 }
    var mine = word("m", x: 100, y: 500)
    for i in mine.indices { mine[i].t = 4000 }
    let texts = [BoardText(id: "text-1", t: 1000, text: "hi", font: .plain, size: 24, color: "#000000", glyphs: 3)]
    let o = BoardOutline(strokes: [box] + glyphs + markA + markB + mine, headers: [], texts: texts)
    let theirs: Set<Int64> = [1000, 2000, 3000]
    XCTAssertEqual(
      o.theirs(at: CGPoint(x: 105, y: 212), slop: 22, moments: theirs)?.names.sorted(), ["t0", "t1", "t2"])
    XCTAssertEqual(
      o.theirs(at: CGPoint(x: 105, y: 412), slop: 22, moments: theirs)?.names.sorted(), ["a0", "a1", "a2"])
    XCTAssertEqual(o.theirs(at: CGPoint(x: 320, y: 412), slop: 22, moments: theirs)?.moment, 3000, "the other mark")
    XCTAssertNil(o.theirs(at: CGPoint(x: 180, y: 182), slop: 5, moments: theirs), "on his box, nearer than the text")
    XCTAssertNil(o.theirs(at: CGPoint(x: 105, y: 512), slop: 22, moments: theirs), "his own writing")
    XCTAssertNil(o.theirs(at: CGPoint(x: 600, y: 600), slop: 22, moments: theirs), "off ink")
    XCTAssertNil(o.theirs(at: CGPoint(x: 105, y: 412), slop: 22, moments: []), "nothing of theirs on the board")
    var groups: [String: String] = [:]
    for s in markA { for id in s.ids { groups[id] = "reply-1" } }
    let grouped = BoardOutline(strokes: [box] + glyphs + markA + markB, headers: [], texts: texts, groups: groups)
    XCTAssertNil(grouped.theirs(at: CGPoint(x: 105, y: 412), slop: 22, moments: theirs), "a group's is the group's")
    XCTAssertEqual(grouped.theirs(at: CGPoint(x: 320, y: 412), slop: 22, moments: theirs)?.names.count, 3)
  }

  /// Story 1143 (bead context-grabber-hm7n): pieces of one reply of Larry's kept with plain Keep, each at its own
  /// moment, are picked up together by a tap on any of them; another reply's, a piece with no reply known, and his own
  /// ink stay out. A group Larry made with a change is the group's (story 947).
  func testAFingerTapOnOnePieceOfAReplyTakesTheWholeReply() {
    func at(_ id: String, _ y: CGFloat, _ t: Int64) -> [BoardOps.Stroke] {
      var strokes = word(id, x: 100, y: y)
      for i in strokes.indices { strokes[i].t = t }
      return strokes
    }
    let first = at("p", 200, 1000)
    let second = at("q", 300, 2000)
    let other = at("o", 400, 3000)
    let lone = at("k", 500, 4000)
    let mine = at("m", 600, 5000)
    let steps = at("s", 700, 6000)
    var groups: [String: String] = [:]
    for s in steps { for id in s.ids { groups[id] = "larry-steps" } }
    let o = BoardOutline(strokes: first + second + other + lone + mine + steps, headers: [], groups: groups)
    let theirs: Set<Int64> = [1000, 2000, 3000, 4000, 6000]
    let replies: [Int64: String] = [1000: "r1", 2000: "r1", 3000: "r2"]
    let both = ["p0", "p1", "p2", "q0", "q1", "q2"]
    let tapFirst = o.theirs(at: CGPoint(x: 105, y: 212), slop: 22, moments: theirs, replies: replies)
    XCTAssertEqual(tapFirst?.names.sorted(), both, "both pieces of the reply")
    XCTAssertEqual(tapFirst?.reply, "r1")
    XCTAssertEqual(tapFirst?.moment, 1000, "the piece tapped")
    XCTAssertEqual(
      o.theirs(at: CGPoint(x: 105, y: 312), slop: 22, moments: theirs, replies: replies)?.names.sorted(), both,
      "the other piece takes the same")
    XCTAssertEqual(
      o.theirs(at: CGPoint(x: 105, y: 412), slop: 22, moments: theirs, replies: replies)?.names.sorted(),
      ["o0", "o1", "o2"], "another reply's mark alone")
    let alone = o.theirs(at: CGPoint(x: 105, y: 512), slop: 22, moments: theirs, replies: replies)
    XCTAssertEqual(alone?.names.sorted(), ["k0", "k1", "k2"], "no reply known: that piece alone")
    XCTAssertNil(alone?.reply)
    XCTAssertNil(o.theirs(at: CGPoint(x: 105, y: 612), slop: 22, moments: theirs, replies: replies), "his own ink")
    XCTAssertEqual(
      o.theirs(at: CGPoint(x: 105, y: 212), slop: 22, moments: theirs)?.names.sorted(), ["p0", "p1", "p2"],
      "with no replies known, one piece as before")
    XCTAssertEqual(
      o.theirs(at: CGPoint(x: 105, y: 212), slop: 22, moments: [1000], replies: replies)?.names.sorted(),
      ["p0", "p1", "p2"], "a moment no longer his is never taken")
    // Larry's own group, from a change: the group's tap takes it whole, and the reply's tap leaves it.
    XCTAssertNil(o.theirs(at: CGPoint(x: 105, y: 712), slop: 22, moments: theirs, replies: replies))
    XCTAssertEqual(o.group(at: CGPoint(x: 105, y: 712), slop: 22)?.group, "larry-steps")
    XCTAssertEqual(o.group(at: CGPoint(x: 105, y: 712), slop: 22)?.names.sorted(), ["s0", "s1", "s2"])
  }

  func testFoldsGoBesideTheStrokesToTheCockpit() throws {
    let picture = WhiteboardPicture(board: "b1", title: "t", rect: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 1)
    let fold: [String: Any] = ["header": "h-1", "header_strokes": ["a"], "lines": 2, "strokes": ["b"]]
    let request = try WhiteboardStrokes.request(
      picture: picture, strokes: [], folds: [fold], cockpit: "https://c.example")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual((body["folds"] as? [[String: Any]])?.first?["header"] as? String, "h-1")
    let none = try WhiteboardStrokes.request(picture: picture, strokes: [], cockpit: "https://c.example")
    let plain = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(none.httpBody)) as? [String: Any])
    XCTAssertNil(plain["folds"], "no folds, no field")
  }
}
