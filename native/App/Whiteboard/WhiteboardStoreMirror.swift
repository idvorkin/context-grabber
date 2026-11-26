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
  private var again: (drawing: PKDrawing, name: String, paper: String, ruled: Bool)?

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
  func send(drawing: PKDrawing, name: String, paper: String, ruled: Bool) {
    guard Self.betaOn, CockpitBoardMirror.allowed(name: name) else {
      log.event("board_mirror", ["action": "held", "board": board, "reason": "waiting_for_backup"])
      return
    }
    log.event("board_mirror", ["action": "send", "board": board, "strokes": drawing.strokes.count])
    problem = nil
    line = "Sending to the Cockpit…"
    run(drawing: drawing, name: name, paper: paper, ruled: ruled)
  }

  /// The board was just saved: its ink, as the Cockpit's ops, queued and sent. Nothing while it isn't mirrored.
  func saved(drawing: PKDrawing, name: String, paper: String, ruled: Bool) {
    guard mirrored else { return }
    run(drawing: drawing, name: name, paper: paper, ruled: ruled)
  }

  private func run(drawing: PKDrawing, name: String, paper: String, ruled: Bool) {
    guard !syncing else {
      again = (drawing, name, paper, ruled)
      return
    }
    syncing = true
    Task {
      var next: (drawing: PKDrawing, name: String, paper: String, ruled: Bool)? = (drawing, name, paper, ruled)
      while let job = next {
        again = nil
        await pass(job.drawing, name: job.name, paper: job.paper, ruled: job.ruled)
        next = again
      }
      syncing = false
    }
  }

  private func pass(_ drawing: PKDrawing, name: String, paper: String, ruled: Bool) async {
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
    if let saved = disk.load(board: board) {
      cache = saved
    } else {
      // A first send, or a copy lost: start from what the Cockpit holds, so strokes it has already land as no change.
      guard let snapshot = await ask(try CockpitBoardStore.snapshotRequest(board: board, cockpit: cockpit), "open")
      else { return }
      cache = BoardStoreCache(snapshot: snapshot)
    }
    let records = await Task.detached(priority: .utility) { Self.records(drawing) }.value
    let after = CockpitBoardMirror.after(records: records, cache: cache, device: device)
    switch CockpitBoardEdit.ops(cache, after: after) {
    case .failure(let failure):
      fail("this board's ink couldn't be turned into the Cockpit's changes (\(failure))", operation: "encode")
      return
    case .success(var ops):
      if let rename = CockpitBoardMirror.rename(cache, name: name) { ops.append(rename) }
      let saves = CockpitBoardMirror.saves(ops)
      for save in saves { cache.enqueue(save) }
      if !saves.isEmpty {
        log.event("board_mirror", ["action": "queued", "board": board, "saves": saves.count, "ops": ops.count])
      }
    }
    do { try disk.save(cache) } catch {
      fail("the board's Cockpit copy couldn't be written (\(error.localizedDescription))", operation: "save_copy")
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
    let disk = disk
    let report = await sync.run(&cache) { copy in try disk.save(copy) }
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
