//  The device's copy of a store board and its queue of unsent saves (spec 2026-11-22-boards-in-the-cockpit-design.md,
//  Offline: each device's copy and its unsent changes; plan 2026-11-24-boards-in-the-cockpit-plan.md section 7a;
//  stories 1301, 1330-1334; Larry's store spec, cockpit 2bf00b04, sections 3 and 6).

import XCTest

@testable import ContextCore

final class BoardStoreCacheTests: XCTestCase {
  private let me = BoardStoreClash.Author(device: "ipad-7c2e", by: "igor", at: "2026-11-25T10:00:00Z")
  private let web = BoardStoreClash.Author(device: "web-3f9a", by: "igor", at: "2026-11-25T09:59:00Z")
  private let at = "2026-11-25T10:00:00.000-08:00"

  private func stroke(_ id: String, x: Int = 0) -> BoardStoreJSON {
    ["id": .string(id), "pts": [[.int(Int64(x)), 0, 1]]]
  }

  /// A board at rev 5: s1 and s2 at rev 3, and its name.
  private func board() -> BoardStoreCache {
    BoardStoreCache(
      snapshot: [
        "id": "b-1", "rev": 5, "erased": [],
        "things": [
          [
            "id": "@board", "kind": "board", "body": ["name": "Plan", "paper": "dots"], "rev": 1, "device": "web-3f9a",
            "by": "igor", "at": "t1",
          ],
          [
            "id": "s1", "kind": "stroke", "body": stroke("s1"), "rev": 3, "device": "web-3f9a", "by": "igor",
            "at": "t3",
          ],
          [
            "id": "s2", "kind": "stroke", "body": stroke("s2"), "rev": 3, "device": "web-3f9a", "by": "igor",
            "at": "t3",
          ],
        ],
      ])
  }

  private func answer(rev: Int, applied: [Int], refused: [BoardStoreJSON] = [], ok: Bool = true) -> BoardStoreJSON {
    [
      "ok": .bool(ok), "rev": .int(Int64(rev)), "applied": .array(applied.map { .int(Int64($0)) }),
      "refused": .array(refused), "missing_ids": [],
    ]
  }

  private func webBatch(rev: Int, id: String = "w", ops: [BoardStoreJSON]) -> BoardStoreJSON {
    [
      "rev": .int(Int64(rev)), "batch_id": .string(id), "kind": "ops", "device": .string(web.device), "by": "igor",
      "at": .string(web.at), "ops": .array(ops),
    ]
  }

  // Stories 1330, 1301: unsent saves show at once and go up oldest first, one at a time, each at the base its turn finds.
  func testOfflineSavesShowAndGoUpOneAtATime() throws {
    var cache = board()
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s3")]]])
    cache.enqueue([["op": "set", "ids": ["s1"], "bodies": ["s1": stroke("s1", x: 40)]]])
    XCTAssertEqual(cache.view["s3"]?.body, stroke("s3"))
    XCTAssertEqual(cache.view["s1"]?.body, stroke("s1", x: 40))
    XCTAssertEqual(cache.things["s1"]?.body, stroke("s1"), "the snapshot is the Cockpit's until an answer")

    let first = try XCTUnwrap(cache.freeze(batchID: "b1", deviceAt: at))
    XCTAssertEqual(first.baseRev, 5)
    XCTAssertEqual(first.ops.count, 1)
    XCTAssertEqual(cache.freeze(batchID: "other", deviceAt: at), first, "one batch in flight, the same one")
    XCTAssertNil(cache.queue[1].batchID, "the second save waits unfrozen")

    XCTAssertEqual(cache.receive(status: 200, answer: answer(rev: 6, applied: [0]), me: me, slug: "7c2e"), .done)
    XCTAssertEqual(cache.rev, 6)
    XCTAssertEqual(cache.things["s3"]?.rev, 6)
    XCTAssertEqual(cache.things["s3"]?.author, me)
    let second = try XCTUnwrap(cache.freeze(batchID: "b2", deviceAt: at))
    XCTAssertEqual(second.baseRev, 6, "a later batch's base is set when it is frozen, after the earlier answer")
  }

  // Story 1331: a save sent once is frozen; a retry is the same body, id and base; ok:false and 409 keep it.
  func testLostAnswerResendsTheSameSave() throws {
    var cache = board()
    cache.enqueue([["op": "erase", "ids": ["s2"]]])
    let sent = try XCTUnwrap(cache.freeze(batchID: "b1", deviceAt: at))
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s3")]]])
    let wire = sent.wire(device: me.device, by: me.by)

    // A cache written to disk and read back after a kill mid-send resends the same body.
    let data = try JSONEncoder().encode(cache)
    var reread = try JSONDecoder().decode(BoardStoreCache.self, from: data)
    XCTAssertEqual(reread, cache)
    XCTAssertEqual(reread.freeze(batchID: "fresh", deviceAt: "later")?.wire(device: me.device, by: me.by), wire)

    XCTAssertEqual(
      cache.receive(status: 200, answer: answer(rev: 5, applied: [], ok: false), me: me, slug: "7c2e"),
      .keepQueued)
    XCTAssertEqual(cache.receive(status: 502, answer: [:], me: me, slug: "7c2e"), .keepQueued)
    XCTAssertEqual(cache.queue.count, 2)
    XCTAssertEqual(cache.queue[0].batchID, "b1")

    let reused: BoardStoreJSON = ["ok": false, "error": "batch_id_reused"]
    XCTAssertEqual(cache.receive(status: 409, answer: reused, me: me, slug: "7c2e"), .batchIDReused)
    XCTAssertEqual(cache.queue[0].batchID, "b1", "never quietly re-sent under a new name")
    XCTAssertEqual(cache.problems.last?.error, "batch_id_reused")
  }

  // Story 1332: catching up runs the rule at the OLD base: a queued change over a pulled change is refused locally.
  func testCatchingUpRefusesAQueuedChangeOverAPulledOne() throws {
    var cache = board()
    cache.enqueue([
      ["op": "set", "ids": ["s1"], "bodies": ["s1": stroke("s1", x: 40)]], ["op": "erase", "ids": ["s2"]],
    ])
    cache.pull(
      rev: 6,
      batches: [
        webBatch(rev: 6, ops: [["op": "set", "ids": ["s1"], "bodies": ["s1": stroke("s1", x: -9)]]])
      ])
    XCTAssertEqual(cache.rev, 6)
    XCTAssertFalse(cache.needsPull)
    XCTAssertEqual(cache.notes.count, 1)
    let note = try XCTUnwrap(cache.notes.first)
    XCTAssertEqual(note.id, "s1")
    XCTAssertEqual(note.reason, "changed")
    XCTAssertEqual(note.kind, "set")
    XCTAssertEqual(note.rev, 6)
    XCTAssertEqual(note.author, web)
    XCTAssertTrue(note.local)
    XCTAssertEqual(cache.view["s1"]?.body, stroke("s1", x: -9), "the stroke shows where the web left it")
    XCTAssertEqual(cache.view["s2"]?.erased, true, "everything else still goes up")
    let next = try XCTUnwrap(cache.freeze(batchID: "b1", deviceAt: at))
    XCTAssertEqual(next.baseRev, 6)
    XCTAssertEqual(next.ops, [["op": "erase", "ids": ["s2"]]])
  }

  // Section 6: the device's own late batch comes back in the pull; it is applied once and refuses nothing of its own.
  func testOwnBatchInThePullDoesNotClashWithTheQueue() throws {
    var cache = board()
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s3")]]])
    _ = cache.freeze(batchID: "b1", deviceAt: at)
    cache.enqueue([["op": "set", "ids": ["s3"], "bodies": ["s3": stroke("s3", x: 7)]]])
    // The web landed rev 6 meanwhile, so b1 landed at 7: not caught up.
    XCTAssertEqual(cache.receive(status: 200, answer: answer(rev: 7, applied: [0]), me: me, slug: "7c2e"), .done)
    XCTAssertTrue(cache.needsPull)
    XCTAssertEqual(cache.rev, 5)
    XCTAssertNil(cache.freeze(batchID: "b2", deviceAt: at), "nothing goes up before the pull")
    XCTAssertEqual(cache.view["s3"]?.body, stroke("s3", x: 7), "my landed ink still shows while the pull waits")

    cache.pull(
      rev: 7,
      batches: [
        webBatch(rev: 6, ops: [["op": "add_strokes", "ids": ["s9"], "bodies": ["s9": stroke("s9")]]]),
        [
          "rev": 7, "batch_id": "b1", "kind": "ops", "device": .string(me.device), "by": "igor", "at": .string(me.at),
          "ops": [["op": "add_strokes", "ids": ["s3"], "bodies": ["s3": stroke("s3")]]],
        ],
      ])
    XCTAssertEqual(cache.notes, [])
    XCTAssertEqual(cache.rev, 7)
    XCTAssertEqual(cache.things["s9"]?.author, web)
    XCTAssertEqual(cache.things["s9"]?.kind, "stroke", "a pulled add carries its kind, as the snapshot's do")
    XCTAssertEqual(cache.things["s3"]?.rev, 7)
    XCTAssertEqual(cache.freeze(batchID: "b2", deviceAt: at)?.baseRev, 7)
  }

  // Story 1334: caught up only when applied and rev == base + 1, or nothing applied and rev == base.
  func testCaughtUpNeedsBothArms() {
    func sent() -> BoardStoreCache {
      var cache = board()
      cache.enqueue([["op": "erase", "ids": ["s2"]]])
      _ = cache.freeze(batchID: "b1", deviceAt: at)
      return cache
    }
    let refused: [BoardStoreJSON] = [
      [
        "op": 0, "id": "s2", "reason": "changed", "rev": 6, "device": "web-3f9a",
        "by": "igor", "at": "t6",
      ]
    ]

    var landed = sent()
    _ = landed.receive(status: 200, answer: answer(rev: 6, applied: [0]), me: me, slug: "7c2e")
    XCTAssertFalse(landed.needsPull)
    XCTAssertEqual(landed.rev, 6)

    var nothingAtBase = sent()
    _ = nothingAtBase.receive(status: 200, answer: answer(rev: 5, applied: [], refused: refused), me: me, slug: "7c2e")
    XCTAssertFalse(nothingAtBase.needsPull)
    XCTAssertEqual(nothingAtBase.rev, 5)

    var nothingOnAMovedBoard = sent()
    _ = nothingOnAMovedBoard.receive(
      status: 200, answer: answer(rev: 6, applied: [], refused: refused), me: me, slug: "7c2e")
    XCTAssertTrue(nothingOnAMovedBoard.needsPull, "a fully refused batch on a board one ahead is not caught up")
    XCTAssertEqual(nothingOnAMovedBoard.rev, 5)
    XCTAssertEqual(nothingOnAMovedBoard.notes.first?.local, false)
    XCTAssertEqual(nothingOnAMovedBoard.view["s2"]?.erased, false, "a refused change is undone on the device")
  }

  // Spec section 3: an answer is applied per id from `refused`, never per applied index.
  func testAnAnswerIsAppliedPerIDNotPerAppliedIndex() {
    var cache = BoardStoreCache(snapshot: [
      "id": "b-1", "rev": 5, "erased": [],
      "things": [
        ["id": "s1", "kind": "stroke", "body": stroke("s1"), "rev": 3, "device": "web-3f9a", "by": "igor", "at": "t"],
        [
          "id": "g1", "kind": "group", "body": ["owner": "larry"], "rev": 4, "device": "web-3f9a", "by": "larry",
          "at": "t",
        ],
      ],
    ])
    cache.enqueue([["op": "group", "id": "g1", "ids": ["s1"], "owner": "igor"]])
    _ = cache.freeze(batchID: "b1", deviceAt: at)
    _ = cache.receive(
      status: 200,
      answer: answer(
        rev: 6, applied: [0],
        refused: [
          [
            "op": 0, "id": "g1", "reason": "exists", "rev": 4,
            "device": "web-3f9a", "by": "larry", "at": "t",
          ]
        ]),
      me: me, slug: "7c2e")
    XCTAssertEqual(cache.things["g1"]?.body, ["owner": "larry"], "a group whose id exists inserts no body")
    XCTAssertEqual(cache.things["g1"]?.rev, 4)
    XCTAssertEqual(cache.things["s1"]?.rev, 6, "its members' change landed")
  }

  // Story 1333: ink refused for a deleted board is set aside until Igor keeps it as a new board or lets it go.
  func testDeletedInkWaitsForKeepAsANewBoard() throws {
    var cache = board()
    let add: BoardStoreJSON = ["op": "add_strokes", "strokes": [stroke("s3"), stroke("s4")]]
    cache.enqueue([add, ["op": "rename", "name": "Later"]])
    _ = cache.freeze(batchID: "b1", deviceAt: at)
    let deleted: (Int, String) -> BoardStoreJSON = { op, id in
      [
        "op": .int(Int64(op)), "id": .string(id), "reason": "deleted", "rev": 5, "device": "web-3f9a", "by": "igor",
        "at": "t5",
      ]
    }
    _ = cache.receive(
      status: 200,
      answer: answer(rev: 5, applied: [], refused: [deleted(0, "s3"), deleted(0, "s4"), deleted(1, "@board")]),
      me: me, slug: "7c2e")
    XCTAssertEqual(cache.queue, [])
    XCTAssertEqual(cache.setAside, [add, ["op": "rename", "name": "Later"]])
    XCTAssertEqual(cache.notes.map(\.reason), ["deleted", "deleted", "deleted"])

    let kept = try XCTUnwrap(cache.keptInk(newID: "b-2"))
    XCTAssertEqual(kept.create, ["id": "b-2", "name": "Plan (kept ink)", "paper": "dots"])
    XCTAssertEqual(kept.ops, [add], "the refused ink only, at base 0")
    XCTAssertEqual(cache.setAside, [])

    var dismissed = board()
    dismissed.setAside = [add]
    dismissed.dismissSetAside()
    XCTAssertEqual(dismissed.setAside, [])
  }

  // Section 6: new ink refused `exists` is never dropped: it goes up again under a name with the device's slug.
  func testInkRefusedAsExistingIsAddedBackUnderANewName() {
    var cache = board()
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s2"), stroke("s3")]]])
    _ = cache.freeze(batchID: "b1", deviceAt: at)
    _ = cache.receive(
      status: 200,
      answer: answer(
        rev: 6, applied: [0],
        refused: [
          [
            "op": 0, "id": "s2", "reason": "exists", "rev": 3,
            "device": "web-3f9a", "by": "igor", "at": "t3",
          ]
        ]),
      me: me, slug: "7c2e")
    XCTAssertEqual(cache.things["s2"]?.body, stroke("s2"), "the board's own s2 stays")
    XCTAssertEqual(cache.things["s3"]?.rev, 6)
    var readd = stroke("s2")
    readd["id"] = "s2-7c2e"
    XCTAssertEqual(cache.queue.first?.ops, [["op": "add_strokes", "strokes": [readd]]])
    XCTAssertEqual(cache.notes.first?.readdedAs, "s2-7c2e")
  }

  // An `ahead` answer drops the copy for a fresh download; the save is kept, unfrozen, and goes at the new base.
  func testAheadReloadsAndKeepsTheQueue() throws {
    var cache = board()
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s3")]]])
    _ = cache.freeze(batchID: "b1", deviceAt: at)
    _ = cache.receive(
      status: 200, answer: answer(rev: 2, applied: [], refused: [["op": 0, "id": "s3", "reason": "ahead", "rev": 2]]),
      me: me, slug: "7c2e")
    XCTAssertTrue(cache.needsReload)
    XCTAssertNil(cache.freeze(batchID: "b2", deviceAt: at))
    XCTAssertNil(cache.queue.first?.batchID)

    cache.reload(snapshot: [
      "id": "b-1", "rev": 2, "erased": ["s2"],
      "things": [
        [
          "id": "s1", "kind": "stroke", "body": stroke("s1"), "rev": 1, "device": "web-3f9a", "by": "igor",
          "at": "t",
        ]
      ],
    ])
    XCTAssertFalse(cache.needsReload)
    XCTAssertEqual(cache.rev, 2)
    XCTAssertEqual(cache.things["s2"]?.erased, true)
    let next = try XCTUnwrap(cache.freeze(batchID: "b2", deviceAt: at))
    XCTAssertEqual(next.baseRev, 2)
    XCTAssertEqual(next.batchID, "b2")
  }

  // Remote restore brings the body `ops?since` carries; an admin batch (an undelete) asks for a fresh download.
  func testPulledRestoreUsesItsBodyAndAdminReloads() {
    var cache = BoardStoreCache(snapshot: ["id": "b-1", "rev": 5, "erased": ["s7"], "things": []])
    cache.pull(
      rev: 6,
      batches: [
        webBatch(rev: 6, ops: [["op": "restore", "ids": ["s7"], "bodies": ["s7": stroke("s7", x: 3)]]])
      ])
    XCTAssertEqual(cache.view["s7"]?.body, stroke("s7", x: 3))
    XCTAssertEqual(cache.view["s7"]?.erased, false)
    XCTAssertEqual(cache.order, ["s7"], "a restored thing is drawn")
    cache.pull(
      rev: 7,
      batches: [
        [
          "rev": 7, "batch_id": "a1", "kind": "admin", "device": "cockpit", "by": "larry",
          "at": "t", "ops": [],
        ]
      ])
    XCTAssertTrue(cache.needsReload)
  }

  // Section 6: unsent saves that build on each other don't refuse themselves; a board deleted remotely sets them aside.
  func testRebaseKeepsSavesBuiltOnEachOtherAndSetsAsideOnADelete() {
    var cache = board()
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s3")]]])
    cache.enqueue([
      ["op": "set", "ids": ["s3"], "bodies": ["s3": stroke("s3", x: 5)]], ["op": "erase", "ids": ["s3"]],
    ])
    cache.enqueue([["op": "restore", "ids": ["s3"]]])
    var apart = cache
    apart.pull(
      rev: 6, batches: [webBatch(rev: 6, ops: [["op": "set", "ids": ["s2"], "bodies": ["s2": stroke("s2", x: 1)]]])])
    XCTAssertEqual(apart.notes, [])
    XCTAssertEqual(apart.queue, cache.queue)
    XCTAssertEqual(apart.view["s3"]?.erased, false)

    cache.pull(rev: 6, batches: [webBatch(rev: 6, ops: [["op": "delete_board", "ids": [], "bodies": [:]]])])
    XCTAssertEqual(cache.queue, [])
    XCTAssertEqual(cache.setAside.count, 4)
    XCTAssertEqual(Set(cache.notes.map(\.reason)), ["deleted"])
    XCTAssertEqual(cache.notes.first?.author, web)
  }

  // Section 6: a pull while a save's answer is lost counts that save as mine, and later saves build on it.
  func testPullWithASaveInFlightKeepsTheSavesBuiltOnIt() throws {
    func inFlight() -> BoardStoreCache {
      var cache = board()
      cache.enqueue([["op": "add_strokes", "strokes": [stroke("s3")]]])
      _ = cache.freeze(batchID: "b1", deviceAt: at)
      cache.enqueue([["op": "set", "ids": ["s3"], "bodies": ["s3": stroke("s3", x: 7)]]])
      return cache
    }
    let web6 = webBatch(rev: 6, ops: [["op": "set", "ids": ["s2"], "bodies": ["s2": stroke("s2", x: 1)]]])

    var notLanded = inFlight()
    let queued = notLanded.queue
    notLanded.pull(rev: 6, batches: [web6])
    XCTAssertEqual(notLanded.notes, [], "my unsent set builds on my own add in flight")
    XCTAssertEqual(notLanded.queue, queued)

    var landed = inFlight()
    landed.pull(
      rev: 7,
      batches: [
        web6,
        [
          "rev": 7, "batch_id": "b1", "kind": "ops", "device": .string(me.device), "by": "igor", "at": .string(me.at),
          "ops": [["op": "add_strokes", "ids": ["s3"], "bodies": ["s3": stroke("s3")]]],
        ],
      ])
    XCTAssertEqual(landed.notes, [], "my own add that landed is not someone else's change")
    XCTAssertEqual(landed.queue.count, 2)
    XCTAssertEqual(landed.view["s3"]?.body, stroke("s3", x: 7))

    var late = inFlight()
    late.pull(rev: 8, batches: [web6, webBatch(rev: 8, id: "w8", ops: [])])
    _ = late.receive(status: 200, answer: answer(rev: 6, applied: [0]), me: me, slug: "7c2e")
    XCTAssertEqual(late.rev, 8, "an answer never moves the base back")
  }

  // Story 1333: a delete undone in the same pull sets nothing aside; the fresh download decides.
  func testDeleteUndoneInTheSamePullKeepsTheQueue() throws {
    var cache = board()
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s3")]]])
    let queued = cache.queue
    cache.pull(
      rev: 7,
      batches: [
        webBatch(rev: 6, ops: [["op": "delete_board", "ids": [], "bodies": [:]]]),
        ["rev": 7, "batch_id": "a1", "kind": "admin", "device": "cockpit", "by": "larry", "at": "t", "ops": []],
      ])
    XCTAssertTrue(cache.needsReload)
    XCTAssertEqual(cache.setAside, [])
    XCTAssertEqual(cache.notes, [])
    XCTAssertEqual(cache.queue, queued)

    cache.reload(snapshot: ["id": "b-1", "rev": 7, "erased": [], "things": []])
    XCTAssertNil(cache.deleted)
    XCTAssertEqual(try XCTUnwrap(cache.freeze(batchID: "b1", deviceAt: at)).ops, queued[0].ops)
  }

  // Section 6: a reply refused in part keeps the marks that landed and never sends a landed id again.
  func testReplyRefusedInPartKeepsItsLandedMarks() throws {
    let reply: BoardStoreJSON = ["op": "reply", "id": "r1", "marks": [stroke("m1"), stroke("m2")]]
    func answered(_ refusedID: String) -> BoardStoreCache {
      var cache = board()
      cache.enqueue([reply])
      _ = cache.freeze(batchID: "b1", deviceAt: at)
      let refusal: BoardStoreJSON = [
        "op": 0, "id": .string(refusedID), "reason": "exists", "rev": 3, "device": "web-3f9a", "by": "igor", "at": "t3",
      ]
      _ = cache.receive(status: 200, answer: answer(rev: 6, applied: [0], refused: [refusal]), me: me, slug: "7c2e")
      return cache
    }

    let replyTaken = answered("r1")
    XCTAssertEqual(replyTaken.things["m1"]?.rev, 6, "the marks that landed show")
    XCTAssertEqual(replyTaken.things["m2"]?.rev, 6)
    XCTAssertNil(replyTaken.things["r1"])
    XCTAssertEqual(replyTaken.queue.first?.ops, [["op": "reply", "id": "r1-7c2e", "marks": []]])

    let markTaken = answered("m1")
    XCTAssertEqual(markTaken.things["r1"]?.rev, 6)
    XCTAssertEqual(markTaken.things["m2"]?.rev, 6)
    var readd = stroke("m1")
    readd["id"] = "m1-7c2e"
    XCTAssertEqual(markTaken.queue.first?.ops, [["op": "reply", "marks": [readd]]], "r1 landed: not sent again")
  }

  // Bead context-grabber-2m5r: a resent batch's stored answer, arriving after a pull already brought that batch and a
  // newer change over it, never writes the device's older body back.
  func testAResentAnswerAfterAPullKeepsThePulledBody() {
    var cache = board()
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s3")]]])
    _ = cache.freeze(batchID: "b1", deviceAt: at)
    XCTAssertEqual(cache.receive(status: 502, answer: [:], me: me, slug: "7c2e"), .keepQueued, "the answer is lost")
    cache.pull(rev: 7, batches: [
      ["rev": 6, "batch_id": "b1", "kind": "ops", "device": .string(me.device), "by": "igor", "at": .string(me.at),
       "ops": [["op": "add_strokes", "ids": ["s3"], "bodies": ["s3": stroke("s3")]]]],
      webBatch(rev: 7, ops: [["op": "set", "ids": ["s3"], "bodies": ["s3": stroke("s3", x: 99)]]]),
    ])
    XCTAssertEqual(cache.rev, 7)
    XCTAssertEqual(cache.receive(status: 200, answer: answer(rev: 6, applied: [0]), me: me, slug: "7c2e"), .done)
    XCTAssertEqual(cache.things["s3"]?.body, stroke("s3", x: 99), "the web's newer body stays")
    XCTAssertEqual(cache.things["s3"]?.rev, 7)
    XCTAssertEqual(cache.rev, 7)
    XCTAssertFalse(cache.needsPull, "the pull already brought this batch")
    XCTAssertEqual(cache.queue, [])
  }
}
