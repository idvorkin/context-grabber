//  Sending a board to the Cockpit, the mirror (spec 2026-11-22-boards-in-the-cockpit-design.md, Sending a board to the
//  Cockpit (the mirror, beta); stories 1361-1363; cockpit-8kh; Larry's pick B, 2026-11-26). The iCloud board stays the
//  iPad's full board and its truth; after each save its ink also goes to the Cockpit's copy, through the same
//  one-save-at-a-time sync as a Cockpit board (`CockpitBoardSync`). Nothing here changes the board or its iCloud copy.

import ContextCore
import CryptoKit
import Foundation
import PencilKit

@MainActor
final class WhiteboardStoreMirror: ObservableObject {
  /// *In the Cockpit · version 12*, *2 saves waiting*, the problem, or nil while the board isn't mirrored.
  @Published private(set) var line: String?
  @Published private(set) var problem: String?

  let board: String
  private let cockpit: String
  private let log: SessionLog
  private let device = CockpitBoardModel.deviceName()
  private let disk: CockpitBoardDisk
  private let bookURL: URL
  private var syncing = false
  private var again: Job?

  /// One save of the board to mirror: its ink, its name and paper, and (story 1368) its meaning with the names the
  /// iPad knows each stroke by.
  struct Job: @unchecked Sendable {
    var drawing: PKDrawing
    var name: String
    var paper: String
    var ruled: Bool
    var meaning: BoardMeaning?
    var names: [[String]]
  }

  init(board: String, cockpit: String, log: SessionLog) {
    self.board = board
    self.cockpit = cockpit
    self.log = log
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    disk = CockpitBoardDisk(folder: support.appendingPathComponent("cockpit-mirror", isDirectory: true))
    bookURL = Self.bookURL
    if mirrored {
      line =
        CockpitBoardMirror.Book.load(bookURL).created.contains(board) ? "In the Cockpit" : "Not in the Cockpit yet"
    }
  }

  private static var all: [String: WhiteboardStoreMirror] = [:]

  /// One per board, kept while the app runs, so a board opened twice shares its sends.
  static func of(board: String, cockpit: String, log: SessionLog) -> WhiteboardStoreMirror {
    if let mirror = all[board] { return mirror }
    let mirror = WhiteboardStoreMirror(board: board, cockpit: cockpit, log: log)
    all[board] = mirror
    return mirror
  }

  static var bookURL: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("cockpit-mirror/mirror.json")
  }

  /// The beta switch (story 1339) is on.
  static var betaOn: Bool { UserDefaults.standard.bool(forKey: WhiteboardCockpitBoards.key) }

  var mirrored: Bool { Self.betaOn && CockpitBoardMirror.Book.load(bookURL).mirrored.contains(board) }

  /// Story 1363: a new board made while the beta switch is on is mirrored from its first save, once the backup allows.
  static func markNew(_ id: String) {
    guard betaOn, CockpitBoardMirror.allowed(name: "") else { return }
    var book = CockpitBoardMirror.Book.load(bookURL)
    book.mirrored.insert(id)
    try? book.save(bookURL)
  }

  /// Story 1361: *Send this board to the Cockpit*. The gate is the menu's; this checks it again. The board counts as
  /// mirrored once the Cockpit has taken its create; until then a failed send leaves the row to try again.
  func send(_ job: Job) {
    let drawing = job.drawing
    let name = job.name
    guard Self.betaOn, CockpitBoardMirror.allowed(name: name) else {
      log.event("board_mirror", ["action": "held", "board": board, "reason": "waiting_for_backup"])
      return
    }
    log.event("board_mirror", ["action": "send", "board": board, "strokes": drawing.strokes.count])
    problem = nil
    line = "Sending to the Cockpit…"
    run(job)
  }

  /// The board was just saved: its ink, as the Cockpit's ops, queued and sent. Nothing while it isn't mirrored.
  func saved(_ job: Job) {
    guard mirrored else { return }
    run(job)
  }

  private func run(_ job: Job) {
    guard !syncing else {
      again = job
      return
    }
    syncing = true
    Task {
      var next: Job? = job
      while let job = next {
        again = nil
        await pass(job)
        next = again
      }
      syncing = false
    }
  }

  private func pass(_ job: Job) async {
    let drawing = job.drawing
    let name = job.name
    let paper = job.paper
    let ruled = job.ruled
    let board = board
    // The create and the original drawing first, once (story 1361); a second create of the same id is a no-op.
    var book = CockpitBoardMirror.Book.load(bookURL)
    if !book.created.contains(board) {
      guard await create(drawing, name: name, paper: paper, ruled: ruled) else { return }
      book = CockpitBoardMirror.Book.load(bookURL)
      book.created.insert(board)
      book.mirrored.insert(board)
      try? book.save(bookURL)
    }
    var cache: BoardStoreCache
    let disk = disk
    if let saved = await Task.detached(priority: .utility) { disk.load(board: board) }.value {
      cache = saved
    } else {
      // A first send, or a copy lost: start from what the Cockpit holds, so strokes it has already land as no change.
      guard let snapshot = await ask(try CockpitBoardStore.snapshotRequest(board: board, cockpit: cockpit), "open")
      else { return }
      cache = BoardStoreCache(snapshot: snapshot)
    }
    // Story 1367 (bead ze0h): the records, the encode, the cut into saves and the copy's write run off the main
    // thread, so a save of a big mirrored board never holds up the pen; each step is timed for a slow save's log line.
    let sent = CockpitBoardMirror.Book.load(bookURL).sent[board] ?? []
    let started = cache
    let work = await Task.detached(priority: .utility) {
      () -> (Result<CockpitBoardMirror.Prepared, CockpitBoardEdit.Failure>, StepLapsReport?, String?) in
      let laps = StepLaps()
      let records = laps.time("records") { Self.records(drawing) }
      // Story 1368: the board's meaning goes in the web board's lists beside the ink.
      let meaning = job.meaning.map { meaning in
        laps.time("meaning") { CockpitBoardMeaning.lists(meaning: meaning, names: job.names, records: records) }
      }
      let prepared = CockpitBoardMirror.prepare(
        records: records, cache: started, sent: sent, name: name, laps: laps, meaning: meaning)
      var writeError: String?
      if case .success(let ready) = prepared {
        do { try laps.time("write") { try disk.save(ready.cache) } } catch {
          writeError = error.localizedDescription
        }
      }
      return (prepared, StepLapsReport(laps, strokes: records.count), writeError)
    }.value
    let (prepared, laps, writeError) = work
    if let laps { logSlow(laps) }
    switch prepared {
    case .failure(let failure):
      fail("this board's ink couldn't be turned into the Cockpit's changes (\(failure))", operation: "encode")
      return
    case .success(let ready):
      cache = ready.cache
      if ready.saves > 0 {
        book = CockpitBoardMirror.Book.load(bookURL)
        book.sent[board, default: []].formUnion(ready.sentIDs)
        try? book.save(bookURL)
        log.event(
          "board_mirror",
          ["action": "queued", "board": board, "saves": ready.saves, "ops": ready.ops, "ms": laps?.totalMs ?? 0])
      }
    }
    if let writeError {
      fail("the board's Cockpit copy couldn't be written (\(writeError))", operation: "save_copy")
      return
    }
    let device = device
    let sync = CockpitBoardSync(
      cockpit: cockpit, device: device, by: "igor",
      send: { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
      },
      newBatchID: { "\(device)-\(UUID().uuidString.prefix(12).lowercased())" },
      now: { ISO8601DateFormatter().string(from: Date()) })
    let synced = cache
    let (after, report) = await Task.detached(priority: .utility) {
      var copy = synced
      let report = await sync.run(&copy) { copy in try disk.save(copy) }
      return (copy, report)
    }.value
    cache = after
    log.event(
      "board_mirror",
      [
        "action": "synced", "board": board, "sent": report.sent, "rev": cache.rev, "waiting": cache.queue.count,
        "notes": cache.notes.count, "problem": report.problem ?? "",
      ])
    if let failure = report.problem {
      fail(failure, operation: "sync")
    } else {
      problem = nil
      line =
        cache.queue.isEmpty
        ? "In the Cockpit · version \(cache.rev)"
        : cache.queue.count == 1
          ? "In the Cockpit · 1 save waiting" : "In the Cockpit · \(cache.queue.count) saves waiting"
    }
  }

  /// Story 1367: a save whose mirror work took a twentieth of a second or more names its steps, as a slow stroke does
  /// (`ink_part_slow`, part `mirror_save`).
  private func logSlow(_ laps: StepLapsReport) {
    guard laps.totalMs >= WhiteboardModel.slowPartMs else { return }
    log.event(
      "whiteboard",
      [
        "action": "ink_part_slow", "part": "mirror_save", "board": board, "total_ms": laps.totalMs, "laps": laps.laps,
        "strokes": laps.strokes,
      ])
  }

  /// `PUT` the original drawing, then `POST /boards` with it named.
  private func create(_ drawing: PKDrawing, name: String, paper: String, ruled: Bool) async -> Bool {
    let blob = drawing.dataRepresentation()
    let sha = SHA256.hash(data: blob).map { String(format: "%02x", $0) }.joined()
    guard await ask(try CockpitBoardMirror.assetRequest(sha: sha, data: blob, cockpit: cockpit), "asset") != nil
    else { return false }
    let body = CockpitBoardMirror.createBody(
      id: board, name: name, paper: paper, ruled: ruled, device: device, originalAsset: sha)
    guard await ask(try CockpitBoardStore.createRequest(body: body, cockpit: cockpit), "create") != nil else {
      return false
    }
    log.event("board_mirror", ["action": "created", "board": board, "asset_bytes": blob.count])
    return true
  }

  /// A request's JSON answer on a 200, else the problem set and nil.
  private func ask(_ make: @autoclosure () throws -> URLRequest, _ operation: String) async -> BoardStoreJSON? {
    do {
      let (data, response) = try await URLSession.shared.data(for: try make())
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200 else {
        fail(
          "the Cockpit answered HTTP \(status) (\(String(data: data.prefix(200), encoding: .utf8) ?? ""))",
          operation: operation)
        return nil
      }
      return CockpitBoardStore.json(data) ?? [:]
    } catch {
      fail("Cockpit not answering (\(error.localizedDescription))", operation: operation)
      return nil
    }
  }

  private func fail(_ what: String, operation: String) {
    if problem != what {
      log.event(
        "error", ["where": "board_mirror", "operation": operation, "board": board, "message": what, "cockpit": cockpit])
    }
    problem = what
    line = "Not in the Cockpit yet: \(what)"
  }

  /// The board's strokes as the store's records, under ids from their creation moments and seeds (stable across sends).
  nonisolated static func records(_ drawing: PKDrawing) -> [BoardStoreJSON] {
    let strokes = drawing.strokes
    let ids = CockpitBoardMirror.strokeIDs(
      strokes.map { (Int64($0.path.creationDate.timeIntervalSince1970 * 1000), $0.randomSeed) })
    return zip(strokes, ids).map { CockpitStrokeRecord.record($0, id: $1) }
  }
}

/// A save's step times, carried back from the background work (story 1367).
struct StepLapsReport: Sendable {
  let totalMs: Int
  let laps: [String: Int]
  let strokes: Int

  init?(_ laps: StepLaps, strokes: Int) {
    guard let report = laps.report(overMs: 0) else { return nil }
    totalMs = report.totalMs
    self.laps = report.laps
    self.strokes = strokes
  }
}
