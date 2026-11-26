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
  /// Whether this launch has synced yet: a failed first sync says so (#1002).
  private var syncedThisLaunch = false
  /// Bead context-grabber-irm0: whether iCloud refused a board's thread this launch (a TestFlight build before the
  /// production schema has the field), so the rest of the launch's boards go up without theirs.
  private var threadRefusal = BoardThreadRefusal()
  /// #1137: whether a jump waits on iCloud, and the board just found for one.
  private var finding = BoardFind()
  /// A failed sync tries again by itself, later each time (#1002); the try waiting, if one is.
  private var retry = BoardSyncRetry()
  private var retryTask: Task<Void, Never>?

  init(log: SessionLog, device: String) {
    self.log = log
    self.device = device
    let dir = try? FileManager.default
      .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("whiteboard", isDirectory: true)
    // `GRABBER_WHITEBOARD_SAVE_FAILS=1`: for the simulator, whose disk doesn't fill (stories 599, 612).
    // `GRABBER_WHITEBOARD_UNREADABLE=stuck`: a reopened board can't be read or moved aside (#1042).
    let hooks = LaunchHooks.current.whiteboard
    var disk: any BoardDisk = hooks.saveFails ? FullDisk(over: FileBoardDisk()) : FileBoardDisk()
    if hooks.unreadableStuck { disk = StuckUnreadableDisk(over: disk) }
    keeping = BoardKeeping(dir: dir, disk: disk)
    load()
  }

  func drawingURL(_ id: String) -> URL? { keeping.drawingURL(id) }
  func pictureURL(_ id: String) -> URL? { keeping.pictureURL(id) }
  private var dir: URL? { keeping.dir }
  func editable(_ board: BoardEntry) -> Bool { BoardIndex.editable(board, on: device) }
  /// Only a board made on paper, here, is drawn on; every other board shown opens look-only (story 1204).
  func drawable(_ board: BoardEntry) -> Bool { BoardIndex.drawable(board, on: device, onPhone: onPhone) }
  func lookOnlyNote(_ board: BoardEntry) -> String? { BoardIndex.lookOnlyNote(board, on: device, onPhone: onPhone) }
  /// Story 746: an iPhone only looks at boards, so it starts none. The list's New board and the log's `new_board`.
  var startsBoards: Bool { BoardIndex.startsBoards(onPhone: onPhone) }
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
    migrateMeanings()
    log.event(
      "whiteboard",
      [
        "action": "list", "boards": index.boards.count, "own": index.boards.filter(editable).count,
        "migrated": migrated, "new_board": startsBoards,
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

  /// Once: each board's meaning moves from this device's UserDefaults into the board's own file (bead
  /// context-grabber-cc75), then its kept labels and Larry's ink (bead context-grabber-p1pl). One line says what moved;
  /// a board that failed keeps its keys and is tried next launch.
  private func migrateMeanings() {
    let legacy = BoardOpLedger()
    let inkKeys = BoardInkKeys()
    var moved: [String: [String: Int]] = [:]
    for board in index.boards {
      switch keeping.migrateMeaning(board.id, from: legacy) {
      case .success(let meaning)?: moved[board.id] = meaning.counts
      case .failure(let error)?:
        log.event(
          "error", ["where": "whiteboard_meaning", "board": board.id, "operation": "migrate", "message": "\(error)"])
      case nil: break
      }
      switch keeping.migrateInkIdentity(board.id, from: inkKeys, after: legacy) {
      case .success(let meaning)?: moved[board.id] = meaning.counts
      case .failure(let error)?:
        log.event(
          "error",
          ["where": "whiteboard_meaning", "board": board.id, "operation": "migrate_ink", "message": "\(error)"])
      case nil: break
      }
    }
    if !moved.isEmpty { log.event("whiteboard", ["action": "meaning_migrated", "boards": moved]) }
  }

  // MARK: - Boards

  /// A fresh board on this device, always on paper: in the list at once, gone again if it closes without a stroke.
  func create() -> String {
    let id = UUID().uuidString.lowercased()
    index.add(id: id, at: Date(), device: device, deviceName: deviceName, onPages: true)
    // Story 410 (#915): a new board opens with the grid on.
    BoardLines().startNew(id, bare: LaunchHooks.current.whiteboard.newBoardsBare)
    saveIndex()
    // Story 1363: mirrored from its first save while the beta switch is on, once the Cockpit's backup allows it.
    WhiteboardStoreMirror.markNew(id)
    log.event("whiteboard", ["action": "new", "board": id, "on_paper": true])
    return id
  }

  /// `GRABBER_BOARD_FIXTURE=<id>`: an empty board on paper with a known id, for the simulator (#603): this device's, or
  /// with `GRABBER_BOARD_FIXTURE_FROM=<device name>` another device's (#613).
  func addFixture(_ id: String, from other: String? = nil) {
    guard index.board(id) == nil else { return }
    index.add(id: id, at: Date(), device: other ?? device, deviceName: other ?? deviceName, onPages: true)
    saveIndex()
  }

  /// Why a board can't be opened as it is now, once iCloud has been asked; nil when it can (#603). Out of iCloud's
  /// reach, the last drawing this device knew of is as new as can be told. The id is only looked up, never made into a
  /// path: it came from a link or the Cockpit.
  /// #1137: a board this device draws, here, opens without the wait; a jump asks iCloud at most once.
  /// context-grabber-4qel: iCloud gets `BoardFind.answerSeconds` to answer; past that the sync goes on behind the find.
  func find(_ id: String, context: String) async -> BugProblem? {
    let started = ProcessInfo.processInfo.systemUptime
    var ask = finding.ask(id, index: index, device: device, now: started)
    if ask == .asked {
      let answered = await BoardFind.finishes(within: BoardFind.answerSeconds) { [weak self] in
        await self?.sync(reason: "find_board")
      }
      if !answered { ask = .noAnswer }
    }
    let why = index.whyNotOpen(id, iCloud: BoardCloud.entitled)
    let now = ProcessInfo.processInfo.systemUptime
    log.event(
      "whiteboard",
      [
        "action": "find", "board": id, "context": context, "icloud": ask.rawValue, "found": why == nil,
        "ms": Int((now - started) * 1000),
      ])
    guard let why else {
      finding.opens(id, now: now)
      return nil
    }
    let sync =
      ask == .noAnswer
      ? "iCloud hadn't answered within \(Int(BoardFind.answerSeconds)) seconds, so this is what this device has."
      : syncNote ?? "ok"
    log.event(
      "whiteboard", ["action": "board_missing", "board": id, "listed": index.board(id) != nil, "sync": sync])
    // #1254: with no iCloud in this build (the Mac's own) another device's board can never come; no fix can change it.
    return .grabber(
      why, context: context, extra: ["board": .string(id), "sync": .string(sync)], autoFile: BoardCloud.entitled)
  }

  /// A board's drawing; one that cannot be read is moved aside before the error goes up, or, when it can't be moved,
  /// held so nothing saves over it (`BoardKeeping.drawing`, #1042).
  func drawing(_ id: String) throws -> PKDrawing {
    try keeping.drawing(id, decode: PKDrawing.init(data:)) ?? PKDrawing()
  }

  /// A board's meaning (`BoardMeaning`) as it opens: its file, or before the file's first write the keys it moves from.
  /// Labels and Larry's ink still in their keys are added (`BoardInkKeys.fill`). One that can't be read is set aside
  /// and logged, and the board opens with none.
  func meaning(_ id: String) -> BoardMeaning {
    var meaning: BoardMeaning
    do {
      meaning = try keeping.meaning(id) ?? BoardOpLedger().meaning(board: id) ?? BoardMeaning()
    } catch {
      log.event("error", ["where": "whiteboard_meaning", "board": id, "operation": "open", "message": "\(error)"])
      meaning = BoardMeaning()
    }
    BoardInkKeys().fill(&meaning, board: id)
    return meaning
  }

  /// The size of the board's drawing as it opened, to check against its meaning's.
  func drawingBytes(_ id: String) -> Int? { keeping.drawingBytes(id) }

  /// The fingerprint of the board's drawing as it opened, to check against its meaning's (story 1220).
  func drawingPrint(_ id: String) -> String? { keeping.drawingPrint(id) }

  /// A board's meaning written when its ink didn't change (`BoardKeeping.saveMeaning`).
  func saveMeaning(_ meaning: BoardMeaning, board id: String) throws {
    // A change arriving after the board was deleted (a card from a late read) leaves nothing behind.
    guard index.board(id) != nil else { return }
    try keeping.saveMeaning(meaning, board: id)
  }

  /// A board drawn on: its drawing and picture on disk, the list told, iCloud asked to take it. Each stage's time goes
  /// to the session log (`save_timing`, #1044), with what set it off, never the drawing. With `meaning`, the board's
  /// meaning is written after the drawing (story 1106); what was written comes back, with the drawing's size.
  @discardableResult
  func save(
    _ drawing: PKDrawing, meaning: BoardMeaning? = nil, board id: String, trigger: BoardSaveTiming.Trigger
  ) throws -> BoardMeaning? {
    var timing = BoardSaveTiming(board: id, trigger: trigger, strokes: drawing.strokes.count) {
      ProcessInfo.processInfo.systemUptime
    }
    defer { log.event("whiteboard", timing.fields) }
    // Bead context-grabber-3b02 (story 1092): an ink this build can't read back is saved as the pen, so the board opens.
    let (saving, inks) = WhiteboardInk.savable(drawing)
    if let inks {
      log.event(
        "whiteboard",
        [
          "action": "unknown_ink_saved", "board": id, "kinds": inks.kinds, "unreadable": inks.unreadable,
          "as_pen": inks.asPen,
        ])
    }
    let data = timing.time("encode") { saving.dataRepresentation() }
    var meaning = meaning
    meaning?.inkBytes = data.count
    meaning?.inkPrint = BoardMeaning.fingerprint(data)
    if try timing.time("write", { try keeping.save(data, meaning: meaning, board: id) }),
      problem?.context == "WhiteboardView.save"
    {
      problem = nil
    }
    timing.time("picture") { writePicture(of: drawing, id: id) }
    timing.time("index") {
      index.drew(id, strokes: drawing.strokes.count, at: Int64(Date().timeIntervalSince1970 * 1000))
      saveIndex()
    }
    timing.revision = index.board(id)?.updated
    return meaning
  }

  func opened(_ id: String) { open.insert(id) }

  /// Story 1208: the board is on screen somewhere on this device, so a jump brings that one forward.
  func isOpen(_ id: String) -> Bool { open.contains(id) }

  /// Closing a board, after its last save: a new one left without a stroke is gone; anything else goes up to iCloud.
  func closed(_ id: String, empty: Bool) {
    open.remove(id)
    if BoardKeeping.dropsOnClose(index.board(id), empty: empty, device: device) {
      delete(id, reason: "empty")
      return
    }
    Task { await sync(reason: "board_closed") }
  }

  /// `from`: where the rename was asked, the list's row (`list`) or the board's own title (`title`, story 1160).
  func rename(_ id: String, to title: String, from: String) {
    index.rename(id, to: title, at: Int64(Date().timeIntervalSince1970 * 1000))
    saveIndex()
    log.event("whiteboard", ["action": "rename", "board": id, "from": from])
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
    BoardLines().forget(id)
    BoardLetteringChoice().forget(id)
    BoardReviewDisk.forget(board: id)  // story 1248: its review records go with it
    let keys = BoardDeviceKeys.forget(id)
    pictures += 1
    log.event("whiteboard", ["action": "delete", "board": id, "why": reason, "own": own, "keys": keys])
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
    // Where a failure happened and what was in hand, for its log line (#1002); the sync itself doesn't read them.
    let firstOfLaunch = !syncedThisLaunch
    syncedThisLaunch = true
    // #1161: this device's board threads, which go up on the board's record; none once iCloud refused one this launch.
    let threads = threadRefusal.offered(WhiteboardThreads().all())
    // context-grabber-e3vb: threads the Cockpit said are gone, which come off the board's record.
    let gone = WhiteboardThreads().gone()
    let pending = index.pendingUploads(device: device, threads: threads, gone: gone).count
    var threadsUp = 0
    var threadsDropped = 0
    var threadsCleared = 0
    var step = BoardSyncStep.zone
    var stepBoard: String?
    var stepStrokes: Int?
    var zoneError: (any Error)?
    do {
      zoneError = try await cloud.ready()
      step = .delete
      for id in index.deleted {
        stepBoard = id
        try await cloud.delete(id, seen: index.deletedVersions[id])
        index.deletedInCloud(id)
      }
      step = .upload
      for board in index.pendingUploads(device: device, threads: threads, gone: gone) {
        guard let drawing = drawingURL(board.id), FileManager.default.fileExists(atPath: drawing.path) else { continue }
        let picture = pictureURL(board.id).flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        stepBoard = board.id
        stepStrokes = board.strokes
        // A board waiting only on its thread waits for the next launch once iCloud refused a thread this sync.
        if threadRefusal.refused && board.uploaded == board.updated { continue }
        var thread = threadRefusal.refused ? nil : BoardIndex.thread(sending: board, threads: threads, gone: gone)
        let clear = !threadRefusal.refused && thread == nil && board.thread != nil
        do {
          try await cloud.upload(board, thread: thread, clearThread: clear, drawing: drawing, picture: picture)
        } catch
          where BoardThreadRefusal.retryWithoutThread(
            (error as? BoardCloud.WriteFailed)?.save ?? error, sentThread: thread != nil)
        {
          // Bead context-grabber-irm0: production lacks the thread field, so the ink goes up without it; a second
          // refusal throws as before.
          threadRefusal.dropped()
          thread = nil
          log.event(
            "whiteboard_sync",
            [
              "board": board.id, "thread_dropped": true,
              "error": CloudErrorFields.item((error as? BoardCloud.WriteFailed)?.save ?? error),
            ])
          try await cloud.upload(board, thread: nil, drawing: drawing, picture: picture)
          threadsDropped += 1
        }
        index.uploaded(board.id, at: board.updated, thread: thread)
        if thread != nil { threadsUp += 1 }
        if clear {
          threadsCleared += 1
          log.event("whiteboard_sync", ["board": board.id, "thread_cleared": board.thread ?? ""])
        }
      }
      step = .list
      let listed = try await cloud.boards()
      let merged = index.merge(
        cloud: listed.boards, device: device, unread: listed.unread, tombstones: listed.tombstones, open: open)
      if merged.resend { again = true }
      for id in merged.dropped {
        keeping.removeFiles(id)
        BoardDeviceKeys.forget(id)
      }
      // Each board on its own: one that fails is asked for again next sync, the rest still arrive.
      var failed: (any Error)?
      step = .download
      for id in merged.fetch {
        guard let board = index.board(id) else { continue }
        do {
          // #1043: the assets are checked before they replace this device's copy; only then is the revision fetched.
          let assets = try await cloud.download(id)
          let taken = try keeping.takeReplica(
            id, mine: board.device == device, drawing: assets.drawing?.fileURL, picture: assets.picture?.fileURL,
            decode: PKDrawing.init(data:))
          if let missing = taken.pictureProblem {
            log.event("whiteboard_sync", ["board": id, "picture": "drawn_here", "message": "\(missing)"])
            writePicture(of: taken.drawing, id: id)
          }
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
      var fields: [String: Any] = [
        "ok": true, "why": reason, "boards": index.boards.count, "fetched": merged.fetch.count,
        "dropped": merged.dropped.count, "tombstones": listed.tombstones.count, "resend": merged.resend,
        // #1161: uploads that carried a thread, and other devices' boards that came with one.
        "threads_up": threadsUp, "threads_cleared": threadsCleared,
        "threads_in": listed.boards.filter { $0.device != device && $0.thread != nil }.count,
      ]
      if let zoneError { fields["zone_error"] = CloudErrorFields.item(zoneError) }
      // Bead context-grabber-irm0: boards sent up without the thread iCloud refused.
      if threadsDropped > 0 { fields["thread_dropped"] = threadsDropped }
      if retry.failures > 0 { fields["after_failures"] = retry.failures }
      retry.succeeded()
      retryTask?.cancel()
      retryTask = nil
      log.event("whiteboard_sync", fields)
    } catch let unavailable as BoardCloud.Unavailable {
      saveIndex()
      syncNote = unavailable.note
      log.event("whiteboard_sync", ["ok": false, "why": reason, "skipped": unavailable.reason])
    } catch {
      // What was done before the failure is kept; the rest waits for the next sync.
      saveIndex()
      syncNote = "Boards are not syncing right now: \(error.localizedDescription)"
      let write = error as? BoardCloud.WriteFailed
      // A download's own failure is logged with its board where it happens; this is the step that threw.
      let failure = BoardSyncFailure(
        why: reason, step: step, board: stepBoard, strokes: stepStrokes,
        pending: pending, firstOfLaunch: firstOfLaunch, error: write?.error ?? error, saveError: write?.save,
        deleteError: write?.delete, zoneError: zoneError,
        recordName: { ($0.base as? CKRecord.ID)?.recordName ?? "\($0.base)" })
      let wait = retry.failed(retryAfter: failure.retryAfter)
      var fields = failure.fields
      if let wait { fields["retry_in"] = wait }
      fields["failures"] = retry.failures
      log.event("whiteboard_sync", fields)
      retryTask?.cancel()
      retryTask = nil
      guard let wait else { return }
      retryTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(wait))
        guard !Task.isCancelled else { return }
        await self?.sync(reason: "retry")
      }
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
  static let entitled: Bool = {
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

  /// Throws when iCloud can't be reached; returns the zone's own error, which the sync goes on without (#1002).
  @discardableResult
  func ready() async throws -> (any Error)? {
    guard Self.entitled else {
      throw Unavailable(reason: "not_entitled", note: "This build cannot reach iCloud, so boards stay on this device.")
    }
    let status = try await CKContainer(identifier: Self.containerID).accountStatus()
    guard status == .available else {
      throw Unavailable(
        reason: "account_\(status.rawValue)",
        note: "Not signed into iCloud, so boards stay on this device until it is.")
    }
    let saved = try await database.modifyRecordZones(saving: [zone], deleting: [])
    if case .failure(let error)? = saved.saveResults[zone.zoneID] { return error }
    return nil
  }

  /// A write that failed, with each record's own result: the save's error and the delete's, so the log names the
  /// item CloudKit really refused when the other comes back "Atomic failure" (#1002). It reads as the error thrown.
  struct WriteFailed: Error, LocalizedError, CustomStringConvertible {
    let error: any Error
    let save: (any Error)?
    let delete: (any Error)?
    var description: String { "\(error)" }
    var errorDescription: String? { error.localizedDescription }
  }

  /// `thread`: the board's chat thread with Larry (#1161), so another device opens its conversation. Left off the
  /// record when there is none, so a board that never talked with Larry carries no field production may lack.
  /// `clearThread`: the record carried a thread the Cockpit lost, which is removed from it (context-grabber-e3vb).
  func upload(_ board: BoardEntry, thread: String?, clearThread: Bool = false, drawing: URL, picture: URL?)
    async throws
  {
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
    if let thread {
      record["thread"] = thread
    } else if clearThread {
      record["thread"] = nil
    }
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

  /// One record saved, then another gone, in two calls (#1002): sent as one batch, CloudKit sometimes turned the pair
  /// down as "Atomic failure", blamed on the delete, and the board stayed unsent. There's seldom a record to delete,
  /// and one already gone is what was asked for, however CloudKit reports it. Anything else throws, a failed save above
  /// all, so the caller tries again; the save is idempotent, so a delete that fails after it costs only a resend.
  private func write(_ record: CKRecord, deleting other: CKRecord.ID) async throws {
    let saved = try await database.modifyRecords(
      saving: [record], deleting: [], savePolicy: .allKeys, atomically: false)
    if case .failure(let error)? = saved.saveResults[record.recordID] {
      throw WriteFailed(error: error, save: error, delete: nil)
    }
    do {
      let result = try await database.modifyRecords(
        saving: [], deleting: [other], savePolicy: .allKeys, atomically: false)
      if case .failure(let error)? = result.deleteResults[other], (error as? CKError)?.code != .unknownItem {
        throw WriteFailed(error: error, save: nil, delete: error)
      }
    } catch let error as CKError where error.code == .unknownItem {
      return
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
        desiredKeys: ["title", "created", "updated", "strokes", "device", "deviceName", "paper", "onPages", "thread"])
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

  /// A board's drawing and picture as CloudKit downloaded them; nil for one the record doesn't carry. The assets are
  /// held, so their files stay, while the store checks them before they replace this device's copy
  /// (`BoardKeeping.takeReplica`, #1043).
  func download(_ id: String) async throws -> (drawing: CKAsset?, picture: CKAsset?) {
    let results = try await database.records(for: [self.id(id)], desiredKeys: ["drawing", "picture"])
    guard let record = try results[self.id(id)]?.get() else { throw CKError(.unknownItem) }
    return (record["drawing"] as? CKAsset, record["picture"] as? CKAsset)
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
      onPages: (record["onPages"] as? Int) == 1 ? true : nil, thread: record["thread"] as? String)
  }
}
