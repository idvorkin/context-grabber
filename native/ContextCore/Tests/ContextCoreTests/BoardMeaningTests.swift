import Foundation
import XCTest

@testable import ContextCore

/// A board's meaning in its own file beside the drawing (bead context-grabber-cc75, story 1106): written after the
/// drawing in one save, moved once from UserDefaults, gone with the board.
final class BoardMeaningTests: XCTestCase {
  private var dir: URL!
  private var defaults: UserDefaults!

  override func setUpWithError() throws {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("board-meaning-\(UUID().uuidString)")
    defaults = try XCTUnwrap(UserDefaults(suiteName: "BoardMeaningTests-\(UUID().uuidString)"))
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: dir)
  }

  /// A real disk that notes every write and can refuse one kind of file.
  private final class TestDisk: BoardDisk {
    let disk = FileBoardDisk()
    var refuse: String?
    var garbleNext: String?
    var changes: [String] = []
    func exists(_ url: URL) -> Bool { disk.exists(url) }
    func read(_ url: URL) throws -> Data { try disk.read(url) }
    func write(_ data: Data, to url: URL) throws {
      changes.append("write \(url.lastPathComponent)")
      if let refuse, url.lastPathComponent.hasSuffix(refuse) { throw CocoaError(.fileWriteOutOfSpace) }
      if let garble = garbleNext, url.lastPathComponent.hasSuffix(garble) {
        garbleNext = nil
        return try disk.write(Data("not the meaning".utf8), to: url)
      }
      try disk.write(data, to: url)
    }
    func remove(_ url: URL) throws {
      changes.append("remove \(url.lastPathComponent)")
      try disk.remove(url)
    }
    func move(_ url: URL, to target: URL) throws {
      changes.append("move \(url.lastPathComponent)")
      try disk.move(url, to: target)
    }
    func makeDirectory(_ url: URL) throws { try disk.makeDirectory(url) }
  }

  private func keeping(_ disk: TestDisk = TestDisk()) -> BoardKeeping {
    let keeping = BoardKeeping(dir: dir, disk: disk)
    _ = keeping.readIndex()
    return keeping
  }

  private func sample() throws -> BoardMeaning {
    var meaning = BoardMeaning()
    var applier = BoardOpApplier(rev: 7)
    applier.changed()
    meaning.take(applier)
    meaning.handled = ["m1", "m2"]
    meaning.texts = [BoardText(id: "t1", t: 99, text: "Plan", font: .plain, size: 18, color: "#ba39e6")]
    meaning.strokeIDs.moved(from: ["old"], to: ["new"])
    meaning.strokeMeta.set(try XCTUnwrap(BoardMeta(["group": "g"])), for: "a")
    meaning.headers = [BoardHeader(id: "h1", ids: ["s1"])]
    meaning.questions = WhiteboardQuestions(cards: [WhiteboardQuestion(id: "c1", ask: "a1", x: 80.5, y: 120)])
    return meaning
  }

  // MARK: The file

  func testTheMeaningReadsBackAsItWasWritten() throws {
    let meaning = try sample()
    let back = try JSONDecoder().decode(BoardMeaning.self, from: JSONEncoder().encode(meaning))
    XCTAssertEqual(back, meaning)
    XCTAssertEqual(back.applier.rev, 8)
    XCTAssertEqual(back.applier.handled, ["m1", "m2"])
  }

  func testAFileMissingPartsOrCarryingNewOnesStillReads() throws {
    let back = try JSONDecoder().decode(BoardMeaning.self, from: Data(#"{"rev": 3, "later": true}"#.utf8))
    XCTAssertEqual(back.rev, 3)
    XCTAssertEqual(back.texts, [])
    XCTAssertEqual(back.questions, WhiteboardQuestions())
    XCTAssertNil(back.inkBytes)
  }

  func testTheDrawingIsWrittenFirstThenItsMeaning() throws {
    let disk = TestDisk()
    var keeping = keeping(disk)
    var meaning = try sample()
    meaning.inkBytes = 3
    _ = try keeping.save(Data("ink".utf8), meaning: meaning, board: "b1")
    XCTAssertEqual(disk.changes, ["write b1.drawing", "write b1.meaning.json"])
    XCTAssertEqual(try keeping.meaning("b1"), meaning)
  }

  func testADrawingThatFailsToSaveWritesNoMeaning() throws {
    let disk = TestDisk()
    disk.refuse = ".drawing"
    var keeping = keeping(disk)
    XCTAssertThrowsError(try keeping.save(Data("ink".utf8), meaning: try sample(), board: "b1"))
    XCTAssertNil(try keeping.meaning("b1"), "the meaning never runs ahead of the ink")
  }

  func testAMeaningThatFailsToSaveFailsTheSave() throws {
    let disk = TestDisk()
    disk.refuse = ".meaning.json"
    var keeping = keeping(disk)
    XCTAssertThrowsError(try keeping.save(Data("ink".utf8), meaning: try sample(), board: "b1"))
  }

  func testTheDrawingsSizeAsReadIsKnown() throws {
    var keeping = keeping()
    _ = try keeping.save(Data("ink12".utf8), board: "b1")
    XCTAssertNil(keeping.drawingBytes("b1"))
    _ = try keeping.drawing("b1") { $0 }
    XCTAssertEqual(keeping.drawingBytes("b1"), 5)
  }

  func testAnUnreadableMeaningIsSetAside() throws {
    let keeping = keeping()
    let url = try XCTUnwrap(keeping.meaningURL("b1"))
    try Data("not json".utf8).write(to: url)
    XCTAssertThrowsError(try keeping.meaning("b1"))
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.appendingPathExtension("unreadable").path))
    XCTAssertNil(try keeping.meaning("b1"))
  }

  func testADeleteTakesTheMeaningToo() throws {
    var keeping = keeping()
    _ = try keeping.save(Data("ink".utf8), meaning: try sample(), board: "b1")
    keeping.removeFiles("b1")
    XCTAssertNil(try keeping.meaning("b1"))
  }

  // MARK: The move from UserDefaults

  private func legacy() throws -> BoardOpLedger {
    let ledger = BoardOpLedger(defaults: defaults)
    let meaning = try sample()
    ledger.save(meaning.applier, board: "b1")
    ledger.setTexts(meaning.texts, board: "b1")
    ledger.setStrokeIDs(meaning.strokeIDs, board: "b1")
    ledger.setStrokeMeta(meaning.strokeMeta, board: "b1")
    ledger.setHeaders(meaning.headers, board: "b1")
    defaults.set(try JSONEncoder().encode(meaning.questions), forKey: "whiteboard_questions_b1")
    return ledger
  }

  func testTheOldKeysMoveIntoTheFileOnceAndGo() throws {
    let ledger = try legacy()
    let keeping = keeping()
    let moved = try XCTUnwrap(keeping.migrateMeaning("b1", from: ledger)).get()
    XCTAssertEqual(moved, try sample())
    XCTAssertEqual(try keeping.meaning("b1"), try sample())
    XCTAssertNil(ledger.meaning(board: "b1"), "every old key is gone")
    XCTAssertTrue(BoardDeviceKeys.keys(of: "b1", in: defaults).isEmpty)
    XCTAssertNil(keeping.migrateMeaning("b1", from: ledger), "once")
  }

  func testABoardWithNoOldKeysHasNothingToMove() {
    XCTAssertNil(keeping().migrateMeaning("b1", from: BoardOpLedger(defaults: defaults)))
  }

  func testAFileAlreadyThereIsNeverOverwritten() throws {
    let ledger = try legacy()
    let keeping = keeping()
    var newer = BoardMeaning()
    newer.rev = 42
    try keeping.saveMeaning(newer, board: "b1")
    XCTAssertNil(keeping.migrateMeaning("b1", from: ledger))
    XCTAssertEqual(try keeping.meaning("b1")?.rev, 42)
    XCTAssertNil(ledger.meaning(board: "b1"), "the stale keys go")
  }

  func testAMoveThatFailsKeepsTheKeys() throws {
    let ledger = try legacy()
    let disk = TestDisk()
    disk.refuse = ".meaning.json"
    guard case .failure? = keeping(disk).migrateMeaning("b1", from: ledger) else { return XCTFail("should fail") }
    XCTAssertEqual(ledger.meaning(board: "b1"), try sample(), "tried again next launch")
  }

  // MARK: The open board's ledger

  func testEachChangeIsToldAndTheSaveRemembered() throws {
    let ledger = BoardMeaningLedger(board: "b1", meaning: BoardMeaning())
    var told = 0
    ledger.onChange = { told += 1 }
    XCTAssertFalse(ledger.unsaved)
    ledger.setHeaders([], board: "b1")
    XCTAssertEqual(told, 0, "no change, nothing told")
    var applier = ledger.applier(board: "b1")
    applier.changed()
    ledger.save(applier, board: "b1")
    ledger.setTexts(try sample().texts, board: "b1")
    ledger.setQuestions(try sample().questions, board: "b1")
    XCTAssertEqual(told, 3)
    XCTAssertTrue(ledger.unsaved)
    var written = ledger.meaning
    written.inkBytes = 12
    ledger.wrote(written)
    XCTAssertFalse(ledger.unsaved)
    XCTAssertEqual(ledger.meaning.inkBytes, 12)
    XCTAssertEqual(ledger.applier(board: "b1").rev, 1)
  }

  func testOnlyTheMeaningParkedOnTheApplierIsKept() {
    let ledger = BoardMeaningLedger(board: "b1", meaning: BoardMeaning())
    var told = 0
    ledger.onChange = { told += 1 }
    var applier = ledger.applier(board: "b1")
    applier.touched(["a"])
    applier.closed()
    ledger.save(applier, board: "b1")
    XCTAssertEqual(told, 0, "touches and the batch in flight live only on this run")
  }

  func testABatchNotYetOnTheBoardIsntSavedAsHandled() {
    let batch = BoardOps.Batch(
      key: "m1", source: "web", board: "b1", label: "push", baseRev: 0, ops: [])
    var applier = BoardOpApplier()
    _ = applier.receive(batch, board: "b1", editable: true, ready: false)
    var meaning = BoardMeaning()
    meaning.take(applier)
    XCTAssertEqual(applier.handled, ["m1"], "the board itself won't take it twice")
    XCTAssertEqual(meaning.handled, [], "held for the Pencil: offered again after a relaunch")
    let released = applier.release(ready: true)
    XCTAssertNotNil(released)
    meaning.take(applier)
    XCTAssertEqual(meaning.handled, [], "on its way to the canvas")
    _ = applier.report(batch, .applied(BoardOps.Plan(pagesBefore: 1, pagesAfter: 1)))
    meaning.take(applier)
    XCTAssertEqual(meaning.handled, ["m1"], "once the canvas took it")
  }

  // MARK: Labels and Larry's ink join the file (bead context-grabber-p1pl)

  private func inkKeys(labels: [Int64]? = [1, 2], theirs: [Int64]? = [7]) -> BoardInkKeys {
    if let labels { defaults.set(labels, forKey: "whiteboard_labels_b1") }
    if let theirs { defaults.set(theirs, forKey: "whiteboard_theirs_b1") }
    return BoardInkKeys(defaults: defaults)
  }

  func testAFileFromBeforeLabelsStillReads() throws {
    let old = Data(#"{"version":1,"rev":3,"handled":["m1"],"inkBytes":9}"#.utf8)
    let meaning = try JSONDecoder().decode(BoardMeaning.self, from: old)
    XCTAssertEqual(meaning.rev, 3)
    XCTAssertEqual(meaning.labels, [])
    XCTAssertEqual(meaning.theirs, [])
  }

  func testTheKeysJoinAFileAlreadyThereAndGo() throws {
    let keys = inkKeys()
    let keeping = keeping()
    var held = try sample()
    held.inkBytes = 12
    try keeping.saveMeaning(held, board: "b1")
    let moved = try XCTUnwrap(keeping.migrateInkIdentity("b1", from: keys, after: BoardOpLedger(defaults: defaults)))
      .get()
    var expected = held
    expected.labels = [1, 2]
    expected.theirs = [7]
    XCTAssertEqual(moved, expected, "every other part, and the drawing's size, as it was")
    XCTAssertEqual(try keeping.meaning("b1"), expected)
    XCTAssertFalse(keys.any(board: "b1"), "the keys go")
    XCTAssertNil(keeping.migrateInkIdentity("b1", from: keys, after: BoardOpLedger(defaults: defaults)), "once")
  }

  func testWithNoFileTheKeysMakeOne() throws {
    let keys = inkKeys(labels: nil)
    let keeping = keeping()
    let moved = try XCTUnwrap(keeping.migrateInkIdentity("b1", from: keys, after: BoardOpLedger(defaults: defaults)))
      .get()
    XCTAssertEqual(moved.theirs, [7])
    XCTAssertEqual(try keeping.meaning("b1")?.theirs, [7])
    XCTAssertFalse(keys.any(board: "b1"))
  }

  func testWhatTheFileHoldsIsNeverReplacedOnlyAddedTo() throws {
    let keys = inkKeys(labels: [1, 2], theirs: [7])
    let keeping = keeping()
    var held = BoardMeaning()
    held.labels = [2, 5]
    held.theirs = [7]
    try keeping.saveMeaning(held, board: "b1")
    let moved = try XCTUnwrap(keeping.migrateInkIdentity("b1", from: keys, after: BoardOpLedger(defaults: defaults)))
      .get()
    XCTAssertEqual(moved.labels, [1, 2, 5], "the key's older moment first, nothing doubled")
    XCTAssertEqual(moved.theirs, [7])
  }

  func testKeysTheFileAlreadyHoldsGoWithNoWrite() throws {
    let keys = inkKeys(labels: [1], theirs: nil)
    let disk = TestDisk()
    let keeping = keeping(disk)
    var held = BoardMeaning()
    held.labels = [1]
    try keeping.saveMeaning(held, board: "b1")
    disk.changes = []
    XCTAssertNil(keeping.migrateInkIdentity("b1", from: keys, after: BoardOpLedger(defaults: defaults)))
    XCTAssertEqual(disk.changes, [])
    XCTAssertFalse(keys.any(board: "b1"))
  }

  func testAMoveThatFailsLeavesTheFileAndTheKeys() throws {
    let keys = inkKeys()
    let disk = TestDisk()
    let keeping = keeping(disk)
    try keeping.saveMeaning(try sample(), board: "b1")
    disk.refuse = ".meaning.json"
    guard case .failure? = keeping.migrateInkIdentity("b1", from: keys, after: BoardOpLedger(defaults: defaults))
    else { return XCTFail("should fail") }
    XCTAssertEqual(try keeping.meaning("b1"), try sample(), "never removed: it holds the rest of the meaning")
    XCTAssertEqual(keys.labels(board: "b1"), [1, 2], "tried again next launch")
    XCTAssertEqual(keys.theirs(board: "b1"), [7])
  }

  func testAMoveThatDoesntReadBackPutsTheFileBackAsItWas() throws {
    let keys = inkKeys()
    let disk = TestDisk()
    let keeping = keeping(disk)
    try keeping.saveMeaning(try sample(), board: "b1")
    let url = try XCTUnwrap(keeping.meaningURL("b1"))
    let before = try disk.read(url)
    disk.garbleNext = ".meaning.json"
    guard case .failure? = keeping.migrateInkIdentity("b1", from: keys, after: BoardOpLedger(defaults: defaults))
    else { return XCTFail("should fail") }
    XCTAssertEqual(try disk.read(url), before, "the file's original bytes, not removed")
    XCTAssertEqual(try keeping.meaning("b1"), try sample())
    XCTAssertEqual(keys.labels(board: "b1"), [1, 2], "tried again next launch")
    XCTAssertEqual(keys.theirs(board: "b1"), [7])
  }

  func testABoardWhoseOldKeysHaventMovedWaits() throws {
    let ledger = try legacy()
    let keys = inkKeys()
    let keeping = keeping()
    XCTAssertNil(keeping.migrateInkIdentity("b1", from: keys, after: ledger))
    XCTAssertNil(try keeping.meaning("b1"), "no file to make the six keys' move take them for stale")
    XCTAssertTrue(keys.any(board: "b1"))
    _ = try XCTUnwrap(keeping.migrateMeaning("b1", from: ledger)).get()
    let moved = try XCTUnwrap(keeping.migrateInkIdentity("b1", from: keys, after: ledger)).get()
    XCTAssertEqual(moved.headers, try sample().headers)
    XCTAssertEqual(moved.labels, [1, 2])
    XCTAssertTrue(BoardDeviceKeys.keys(of: "b1", in: defaults).isEmpty)
  }

  func testUntilTheyMoveTheKeysFillTheBoardAsItOpens() {
    let keys = inkKeys()
    var meaning = BoardMeaning()
    meaning.labels = [9]
    keys.fill(&meaning, board: "b1")
    XCTAssertEqual(meaning.labels, [1, 2, 9])
    XCTAssertEqual(meaning.theirs, [7])
  }

  func testTheLedgerRemembersLabelsAndTheirsCappedAndTellsEachChange() {
    let ledger = BoardMeaningLedger(board: "b1", meaning: BoardMeaning())
    var told = 0
    ledger.onChange = { told += 1 }
    ledger.rememberLabels([], board: "b1")
    ledger.rememberTheirs([], board: "b1")
    XCTAssertEqual(told, 0)
    ledger.rememberLabels([5], board: "b1")
    ledger.rememberTheirs(Array(1...Int64(BoardMeaning.mostTheirs + 3)), board: "b1")
    XCTAssertEqual(told, 2)
    XCTAssertEqual(ledger.labels(board: "b1"), [5])
    XCTAssertEqual(ledger.meaning.theirs.count, BoardMeaning.mostTheirs)
    XCTAssertFalse(ledger.theirs(board: "b1").contains(1), "the oldest go first")
    XCTAssertTrue(ledger.unsaved)
  }

  // MARK: A delete forgets the device's keys

  func testADeleteForgetsEveryKeyOfThatBoardOnly() {
    for key in ["whiteboard_thread_b1", "whiteboard_paper_y_b1", "whiteboard_labels_b1", "whiteboard_thread_b2"] {
      defaults.set("x", forKey: key)
    }
    defaults.set("x", forKey: "other_b1")
    XCTAssertEqual(BoardDeviceKeys.forget("b1", in: defaults), 3)
    XCTAssertNil(defaults.object(forKey: "whiteboard_thread_b1"))
    XCTAssertNotNil(defaults.object(forKey: "whiteboard_thread_b2"))
    XCTAssertNotNil(defaults.object(forKey: "other_b1"))
  }

  /// Story 1148: the reply each piece kept with plain Keep came in is remembered by its moment, read back by moment,
  /// forgotten once the moment is no longer remembered as theirs, and absent from a file written before it.
  func testTheReplyOfEachKeptPieceIsRememberedWithItsMoment() throws {
    let ledger = BoardMeaningLedger(board: "b", meaning: BoardMeaning())
    var changes = 0
    ledger.onChange = { changes += 1 }
    ledger.rememberReply([1000: [1], 2000: [2]], reply: "r1", board: "b")
    ledger.rememberReply([1000: [3]], reply: "r2", board: "b")
    XCTAssertEqual(ledger.replies(board: "b"), [1000: [1: "r1", 3: "r2"], 2000: [2: "r1"]])
    XCTAssertEqual(changes, 2)
    XCTAssertEqual(ledger.meaning.theirs, [1000, 2000])
    ledger.rememberReply([3000: [4]], reply: "r1", board: "b")
    XCTAssertEqual(ledger.reply(at: 3000, seed: 4, board: "b"), "r1", "the revised wording")
    XCTAssertEqual(ledger.reply(at: 2000, seed: 2, board: "b"), "r1", "the old wording is still known for Undo")
    XCTAssertNil(ledger.reply(at: 1000, seed: 5, board: "b"), "someone else's stroke at the same millisecond")
    let saved = try JSONEncoder().encode(ledger.meaning)
    let restored = BoardMeaningLedger(board: "b", meaning: try JSONDecoder().decode(BoardMeaning.self, from: saved))
    XCTAssertEqual(restored.replies(board: "b"), [1000: [1: "r1", 3: "r2"], 2000: [2: "r1"], 3000: [4: "r1"]])
    let old = try JSONDecoder().decode(BoardMeaning.self, from: Data(#"{"version": 1, "theirs": [1000]}"#.utf8))
    XCTAssertEqual(old.replies, [:], "a file from before has none")
    XCTAssertEqual(old.theirs, [1000])
  }

  /// Story 1148: when the oldest of Larry's moments go, their replies go with them.
  func testARepliesMomentGoesWithTheOldestOfTheirs() {
    var meaning = BoardMeaning()
    meaning.theirs = Array(1...Int64(BoardMeaning.mostTheirs))
    let ledger = BoardMeaningLedger(board: "b", meaning: meaning)
    ledger.rememberReply([1: [1, 3], 2: [2]], reply: "r1", board: "b")
    ledger.rememberTheirs([999_999], board: "b")
    XCTAssertEqual(ledger.replies(board: "b"), [2: [2: "r1"]], "1 fell off the end, 2 is still his")
    XCTAssertNil(ledger.reply(at: 1, seed: 3, board: "b"))
  }
}
