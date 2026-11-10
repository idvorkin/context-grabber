//  The boards on this device and in iCloud (spec 2026-11-01-whiteboard-design.md, stories 347, 348). Each board is a
//  PencilKit drawing and a small picture on disk, listed in one index file; this device's own boards go up to the
//  private CloudKit database, every device's boards come down, only the device that made a board draws on it, and any
//  device can delete it (stories 396–398, 401).

import BugKit
import CloudKit
import ContextCore
import PencilKit
import UIKit

@MainActor
final class WhiteboardStore: ObservableObject {
  @Published private(set) var index = BoardIndex()
  /// Why the list is not syncing right now, shown under it; nil while it is.
  @Published private(set) var syncNote: String?
  @Published private(set) var problem: BugProblem?
  /// Bumped when a picture on disk changes, so the rows draw it again.
  @Published private(set) var pictures = 0
  let device: String
  let deviceName = UIDevice.current.model
  /// This device's boards open on screen: a delete from another device waits until their last save.
  private var open: Set<String> = []
  /// Every decision about keeping boards on this device: this store only carries them out (ContextCore, host-tested).
  private var keeping: BoardKeeping
  private let log: SessionLog
  private let cloud = BoardCloud()
  private var running: Task<Void, Never>?
  /// A sync asked for while one ran: it runs again when that one ends, so what changed meanwhile goes up too.
  private var again = false

  init(log: SessionLog, device: String) {
    self.log = log
    self.device = device
    let dir = try? FileManager.default
      .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("whiteboard", isDirectory: true)
    // `GRABBER_WHITEBOARD_SAVE_FAILS=1`: for the simulator, whose disk doesn't fill (stories 599, 612).
    let saveFails = LaunchHooks.current.whiteboard.saveFails
    keeping = BoardKeeping(dir: dir, disk: saveFails ? FullDisk(over: FileBoardDisk()) : FileBoardDisk())
    load()
  }

  func drawingURL(_ id: String) -> URL? { keeping.drawingURL(id) }
  func pictureURL(_ id: String) -> URL? { keeping.pictureURL(id) }
  private var dir: URL? { keeping.dir }
  func editable(_ board: BoardEntry) -> Bool { BoardIndex.editable(board, on: device) }
  /// Story 658: only a board made on paper, here, is drawn on; every other board opens look-only.
  func drawable(_ board: BoardEntry) -> Bool { BoardIndex.drawable(board, on: device, onPhone: onPhone) }
  func lookOnlyNote(_ board: BoardEntry) -> String? { BoardIndex.lookOnlyNote(board, on: device, onPhone: onPhone) }
  /// Story 746: an iPhone only looks at boards, so it starts none.
  let onPhone = UIDevice.current.userInterfaceIdiom == .phone

  /// A board closed with ink that couldn't be saved: the board's screen is gone, so the list says it until that board
  /// next saves (story 612).
  func closedUnsaved(_ problem: BugProblem, board id: String) {
    self.problem = problem
    keeping.closedUnsaved(id)
  }

  // MARK: - The list on disk

  private func load() {
    guard dir != nil else {
      problem = .grabber(
        "This build has nowhere to keep boards, so what is drawn is lost on close.", context: "WhiteboardStore.load")
      return
    }
    let read = keeping.readIndex()
    index = read.index
    if let error = read.unreadable {
      log.event("error", ["where": "whiteboard_index", "message": "\(error)"])
      problem = .grabber(
        "The list of boards could not be read, so it was set aside; iCloud brings the boards back: "
          + error.localizedDescription, context: "WhiteboardStore.load")
    }
    let migrated = migrateSingleBoard()
    log.event(
      "whiteboard",
      [
        "action": "list", "boards": index.boards.count, "own": index.boards.filter(editable).count,
        "migrated": migrated,
      ])
  }

  private func saveIndex() {
    do {
      try keeping.writeIndex(index)
    } catch {
      log.event("error", ["where": "whiteboard_index", "message": "\(error)", "boards": index.boards.count])
      problem = .grabber(
        "The list of boards could not be saved: \(error.localizedDescription)", context: "WhiteboardStore.save")
    }
  }

  /// The one board drawn before the list existed becomes the list's first board (story 348).
  private func migrateSingleBoard() -> Bool {
    guard let dir, let old = Optional(dir.appendingPathComponent("board.drawing")),
      FileManager.default.fileExists(atPath: old.path)
    else { return false }
    let id = UUID().uuidString.lowercased()
    guard let target = drawingURL(id) else { return false }
    do {
      let data = try Data(contentsOf: old)
      let drawing = try PKDrawing(data: data)
      let made = (try? FileManager.default.attributesOfItem(atPath: old.path)[.modificationDate] as? Date) ?? Date()
      try FileManager.default.moveItem(at: old, to: target)
      index.add(id: id, at: made, device: device, deviceName: deviceName)
      index.drew(id, strokes: drawing.strokes.count, at: Int64(made.timeIntervalSince1970 * 1000) + 1)
      writePicture(of: drawing, id: id)
      saveIndex()
      return true
    } catch {
      log.event("error", ["where": "whiteboard_migrate", "message": "\(error)"])
      return false
    }
  }

  // MARK: - Boards

  /// A fresh board on this device, always on paper: in the list at once, gone again if it closes without a stroke.
  func create() -> String {
    let id = UUID().uuidString.lowercased()
    index.add(id: id, at: Date(), device: device, deviceName: deviceName, onPages: true)
    saveIndex()
    log.event("whiteboard", ["action": "new", "board": id, "on_paper": true])
    return id
  }

  /// `GRABBER_BOARD_FIXTURE=<id>`: an empty board on paper with a known id, for the simulator (#603): this device's, or
  /// with `GRABBER_BOARD_FIXTURE_FROM=<device name>` another device's (#613). With `GRABBER_BOARD_FIXTURE_OLD_INK=<n>`
  /// it's a board drawn on the old canvas instead, with n strokes where that canvas put ink (story 658).
  func addFixture(_ id: String, from other: String? = nil, oldInk: Int? = nil) {
    guard index.board(id) == nil else { return }
    index.add(
      id: id, at: Date(), device: other ?? device, deviceName: other ?? deviceName, onPages: oldInk == nil)
    if let oldInk, oldInk > 0 {
      do {
        try save(PKDrawing(strokes: Self.oldCanvasInk(oldInk)), board: id)
      } catch {
        log.event("error", ["where": "whiteboard_fixture", "board": id, "message": "\(error)"])
      }
    }
    saveIndex()
  }

  /// Rows of short strokes where the old canvas put ink, about 10,000 points from its corner, the same on every run.
  private static func oldCanvasInk(_ count: Int) -> [PKStroke] {
    (0..<count).map { (i: Int) -> PKStroke in
      let left: CGFloat = 10_060 + CGFloat(i % 20) * 34
      let top: CGFloat = 10_040 + CGFloat(i / 20) * 40
      let points: [PKStrokePoint] = (0..<8).map { (step: Int) -> PKStrokePoint in
        let wiggle: CGFloat = step % 2 == 0 ? 0 : 14
        return PKStrokePoint(
          location: CGPoint(x: left + CGFloat(step) * 3, y: top + wiggle), timeOffset: Double(step) * 0.01,
          size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: CGFloat.pi / 2)
      }
      let made = Date(timeIntervalSince1970: 1_800_000_000 + Double(i))
      return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: made))
    }
  }

  /// Why a board can't be opened as it is now, once iCloud has been asked; nil when it can (#603). Out of iCloud's
  /// reach, the last drawing this device knew of is as new as can be told. The id is only looked up, never made into a
  /// path: it came from a link or the Cockpit.
  func find(_ id: String, context: String) async -> BugProblem? {
    await sync(reason: "find_board")
    let board = index.board(id)
    if board?.current == true { return nil }
    log.event(
      "whiteboard", ["action": "board_missing", "board": id, "listed": board != nil, "sync": syncNote ?? "ok"])
    return .grabber(
      board == nil
        ? "This board isn't on this device: it was deleted, or iCloud hasn't brought it here."
        : "This board's latest drawing hasn't come down from iCloud, so it can't be opened as it is now.",
      context: context, extra: ["board": .string(id), "sync": .string(syncNote ?? "ok")])
  }

  /// A board's drawing; one that cannot be read is moved aside before the error goes up (`BoardKeeping.drawing`).
  func drawing(_ id: String) throws -> PKDrawing {
    try keeping.drawing(id, decode: PKDrawing.init(data:)) ?? PKDrawing()
  }

  /// A board drawn on: its drawing and picture on disk, the list told, iCloud asked to take it.
  func save(_ drawing: PKDrawing, board id: String) throws {
    if try keeping.save(drawing.dataRepresentation(), board: id), problem?.context == "WhiteboardView.save" {
      problem = nil
    }
    writePicture(of: drawing, id: id)
    index.drew(id, strokes: drawing.strokes.count, at: Int64(Date().timeIntervalSince1970 * 1000))
    saveIndex()
  }

  func opened(_ id: String) { open.insert(id) }

  /// Closing a board, after its last save: a new one left without a stroke is gone; anything else goes up to iCloud.
  func closed(_ id: String, empty: Bool) {
    open.remove(id)
    if BoardKeeping.dropsOnClose(index.board(id), empty: empty, device: device) {
      delete(id, reason: "empty")
      return
    }
    Task { await sync(reason: "board_closed") }
  }

  func rename(_ id: String, to title: String) {
    index.rename(id, to: title, at: Int64(Date().timeIntervalSince1970 * 1000))
    saveIndex()
    log.event("whiteboard", ["action": "rename", "board": id])
    Task { await sync(reason: "rename") }
  }

  func setPaper(_ paper: BoardPaper, board id: String) {
    index.setPaper(id, to: paper, at: Int64(Date().timeIntervalSince1970 * 1000))
    saveIndex()
    Task { await sync(reason: "paper") }
  }

  func delete(_ id: String, reason: String = "asked") {
    let own = index.board(id).map(editable) ?? true
    index.remove(id, device: device)
    saveIndex()
    keeping.removeFiles(id)
    pictures += 1
    log.event("whiteboard", ["action": "delete", "board": id, "why": reason, "own": own])
    if !index.deleted.isEmpty { Task { await sync(reason: "delete") } }
  }

  /// The row's picture: the whole drawing, dark ink on white, at most 480 px across.
  private func writePicture(of drawing: PKDrawing, id: String) {
    guard let url = pictureURL(id) else { return }
    defer { pictures += 1 }
    guard let (rect, _) = WhiteboardFrame.export(drawing.bounds) else {
      try? FileManager.default.removeItem(at: url)
      return
    }
    let scale = min(2, 480 / max(rect.width, rect.height))
    var ink = UIImage()
    UITraitCollection(userInterfaceStyle: .light).performAsCurrent { ink = drawing.image(from: rect, scale: scale) }
    try? ink.pngData()?.write(to: url, options: .atomic)
  }

  // MARK: - iCloud

  /// This device's changes up, everyone's boards down. One at a time; a call while one runs makes it run once more
  /// and waits for that.
  func sync(reason: String) async {
    if let running {
      again = true
      await running.value
      return
    }
    let run = Task {
      var why = reason
      repeat {
        again = false
        await syncOnce(reason: why)
        why = "again"
      } while again
      running = nil
    }
    running = run
    await run.value
  }

  private func syncOnce(reason: String) async {
    do {
      try await cloud.ready()
      for id in index.deleted {
        try await cloud.delete(id, seen: index.deletedVersions[id])
        index.deletedInCloud(id)
      }
      for board in index.pendingUploads(device: device) {
        guard let drawing = drawingURL(board.id), FileManager.default.fileExists(atPath: drawing.path) else { continue }
        let picture = pictureURL(board.id).flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        try await cloud.upload(board, drawing: drawing, picture: picture)
        index.uploaded(board.id, at: board.updated)
      }
      let listed = try await cloud.boards()
      let merged = index.merge(
        cloud: listed.boards, device: device, unread: listed.unread, tombstones: listed.tombstones, open: open)
      if merged.resend { again = true }
      for id in merged.dropped { keeping.removeFiles(id) }
      // Each board on its own: one that fails is asked for again next sync, the rest still arrive.
      var failed: (any Error)?
      for id in merged.fetch {
        guard let drawing = drawingURL(id), let picture = pictureURL(id), let board = index.board(id) else { continue }
        do {
          try await cloud.download(id, drawing: drawing, picture: picture)
          index.fetched(id, at: board.updated)
        } catch {
          failed = failed ?? error
          log.event("whiteboard_sync", ["ok": false, "why": reason, "board": id, "message": "\(error)"])
        }
      }
      saveIndex()
      if let failed { throw failed }
      if !merged.fetch.isEmpty || !merged.dropped.isEmpty { pictures += 1 }
      syncNote = nil
      log.event(
        "whiteboard_sync",
        [
          "ok": true, "why": reason, "boards": index.boards.count, "fetched": merged.fetch.count,
          "dropped": merged.dropped.count, "tombstones": listed.tombstones.count, "resend": merged.resend,
        ])
    } catch let unavailable as BoardCloud.Unavailable {
      saveIndex()
      syncNote = unavailable.note
      log.event("whiteboard_sync", ["ok": false, "why": reason, "skipped": unavailable.reason])
    } catch {
      // What was done before the failure is kept; the rest waits for the next sync.
      saveIndex()
      syncNote = "Boards are not syncing right now: \(error.localizedDescription)"
      log.event("whiteboard_sync", ["ok": false, "why": reason, "message": "\(error)"])
    }
  }
}

/// The boards in the private CloudKit database, in a zone of their own (no query indexes needed to list them), in
/// BugKit's container: the app is already signed for it, so boards need no new entitlement.
struct BoardCloud {
  static let containerID = "iCloud.com.idvorkin.BugKitReports"
  static let recordType = "WhiteboardBoard"
  private let zone = CKRecordZone(zoneName: "Whiteboards")

  struct Unavailable: Error {
    let reason: String
    let note: String
  }

  /// `CKContainer(identifier:)` traps in a build without the container's entitlement (BugKit #87), so it is only
  /// made after the signature says the build has it. Every match of a key is tried: the key's text also sits in this
  /// file's own strings, which a release build puts in the executable ahead of the signature. ponytail: BugKit's
  /// `containers(inExecutable:)`, copied; ask bug-kit to make it public and use that.
  private static let entitled: Bool = {
    guard let url = Bundle.main.executableURL, let data = try? Data(contentsOf: url, options: .alwaysMapped) else {
      return false
    }
    return strings(of: "com.apple.developer.icloud-services", in: data).contains("CloudKit")
      && strings(of: "com.apple.developer.icloud-container-identifiers", in: data).contains(containerID)
  }()

  /// The `<string>`s of a plist array entitlement; only a key followed by an `<array>` counts.
  private static func strings(of entitlement: String, in data: Data) -> Set<String> {
    let key = Data("<key>\(entitlement)</key>".utf8)
    var found: Set<String> = []
    var from = data.startIndex
    while let match = data.range(of: key, in: from..<data.endIndex) {
      from = match.upperBound
      let window = data[match.upperBound..<min(data.endIndex, match.upperBound + 4096)]
      let text = String(decoding: window, as: UTF8.self).drop { $0.isWhitespace }
      guard text.hasPrefix("<array>"), let end = text.range(of: "</array>") else { continue }
      var rest = text[text.index(text.startIndex, offsetBy: 7)..<end.lowerBound]
      while let open = rest.range(of: "<string>"),
        let close = rest.range(of: "</string>", range: open.upperBound..<rest.endIndex)
      {
        found.insert(String(rest[open.upperBound..<close.lowerBound]))
        rest = rest[close.upperBound...]
      }
    }
    return found
  }

  private var database: CKDatabase { CKContainer(identifier: Self.containerID).privateCloudDatabase }

  func ready() async throws {
    guard Self.entitled else {
      throw Unavailable(reason: "not_entitled", note: "This build cannot reach iCloud, so boards stay on this device.")
    }
    let status = try await CKContainer(identifier: Self.containerID).accountStatus()
    guard status == .available else {
      throw Unavailable(
        reason: "account_\(status.rawValue)",
        note: "Not signed into iCloud, so boards stay on this device until it is.")
    }
    _ = try await database.modifyRecordZones(saving: [zone], deleting: [])
  }

  func upload(_ board: BoardEntry, drawing: URL, picture: URL?) async throws {
    let record = CKRecord(recordType: Self.recordType, recordID: id(board.id))
    record["title"] = board.title
    record["created"] = board.created
    record["updated"] = board.updated
    record["strokes"] = board.strokes
    record["device"] = board.device
    record["deviceName"] = board.deviceName
    record["paper"] = board.paperID
    // So a reinstall on the device that draws it reopens it on paper. A board from before has no value here.
    record["onPages"] = board.onPages == true ? 1 : nil
    record["drawing"] = CKAsset(fileURL: drawing)
    record["picture"] = picture.map(CKAsset.init(fileURL:))
    // This device is the board's only writer, so its copy replaces iCloud's whatever iCloud holds. Ink beats a delete
    // from elsewhere (stories 398, 401): any tombstone goes with it.
    try await write(record, deleting: id(BoardIndex.tombstone(of: board.id)))
  }

  /// The board's record goes and its tombstone stays, which tells the device that drew it (story 397), along with the
  /// `updated` this device saw, so ink sent after that outlives it (story 401). Written under the board's own record
  /// type, so it needs no schema of its own and an old build reads it as a record it can't read.
  func delete(_ id: String, seen: Int64?) async throws {
    let tombstone = CKRecord(recordType: Self.recordType, recordID: self.id(BoardIndex.tombstone(of: id)))
    tombstone["updated"] = seen
    try await write(tombstone, deleting: self.id(id))
  }

  /// One record saved and another gone, each on its own: there's seldom a record to delete, and one already gone is
  /// what was asked for, however CloudKit reports it. Anything else throws, a failed save above all, so the caller
  /// tries again next sync.
  private func write(_ record: CKRecord, deleting other: CKRecord.ID) async throws {
    do {
      let result = try await database.modifyRecords(
        saving: [record], deleting: [other], savePolicy: .allKeys, atomically: false)
      _ = try result.saveResults[record.recordID]?.get()
      if case .failure(let error)? = result.deleteResults[other], (error as? CKError)?.code != .unknownItem {
        throw error
      }
    } catch let error as CKError
      where error.code == .partialFailure && error.partialErrorsByItemID?.count == 1
      && (error.partialErrorsByItemID?[other] as? CKError)?.code == .unknownItem
    {
      return
    }
  }

  /// Every board's details, without the drawings, the ids of records that could not be read, and the boards deleted,
  /// each with the `updated` its delete covers: any, for a tombstone that names none. A tombstone that can't be read
  /// is passed over until it can, as it may not cover the ink here.
  func boards() async throws -> (boards: [BoardEntry], unread: Set<String>, tombstones: [String: Int64]) {
    var token: CKServerChangeToken?
    var found: [BoardEntry] = []
    var unread: Set<String> = []
    var tombstones: [String: Int64] = [:]
    var more = true
    while more {
      let changes = try await database.recordZoneChanges(
        inZoneWith: zone.zoneID, since: token,
        desiredKeys: ["title", "created", "updated", "strokes", "device", "deviceName", "paper", "onPages"])
      for (id, result) in changes.modificationResultsByID {
        if let board = BoardIndex.tombstoned(by: id.recordName) {
          if let record = try? result.get().record { tombstones[board] = (record["updated"] as? Int64) ?? .max }
          continue
        }
        guard let record = try? result.get().record, let entry = Self.entry(record) else {
          unread.insert(id.recordName)
          continue
        }
        found.append(entry)
      }
      token = changes.changeToken
      more = changes.moreComing
    }
    return (found, unread, tombstones)
  }

  /// A board's drawing and picture, copied to where this device keeps them.
  func download(_ id: String, drawing: URL, picture: URL) async throws {
    let results = try await database.records(for: [self.id(id)], desiredKeys: ["drawing", "picture"])
    guard let record = try results[self.id(id)]?.get() else { throw CKError(.unknownItem) }
    for (key, target) in [("drawing", drawing), ("picture", picture)] {
      guard let source = (record[key] as? CKAsset)?.fileURL else { continue }
      if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
      try FileManager.default.copyItem(at: source, to: target)
    }
  }

  private func id(_ board: String) -> CKRecord.ID { CKRecord.ID(recordName: board, zoneID: zone.zoneID) }

  private static func entry(_ record: CKRecord) -> BoardEntry? {
    guard let title = record["title"] as? String, let created = record["created"] as? Int64,
      let updated = record["updated"] as? Int64, let device = record["device"] as? String
    else { return nil }
    return BoardEntry(
      id: record.recordID.recordName, title: title, created: created, updated: updated,
      strokes: (record["strokes"] as? Int) ?? 0, device: device,
      deviceName: (record["deviceName"] as? String) ?? "another device", paperID: record["paper"] as? String,
      onPages: (record["onPages"] as? Int) == 1 ? true : nil)
  }
}
