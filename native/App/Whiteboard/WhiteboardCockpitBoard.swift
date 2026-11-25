//  Drawing on a Cockpit board (spec 2026-11-22-boards-in-the-cockpit-design.md, Trying it before the rollout: Drawing on
//  a Cockpit board; stories 1344-1346; cockpit-8kh): the store's trial canvas. A plain PencilKit canvas over the board's
//  copy; each change of its strokes goes through the one encoder (`CockpitBoardEdit`) into the copy's queue, and
//  `CockpitBoardSync` takes it from there. After every pass the canvas shows the copy again, so a refused stroke goes back
//  off it, with the copyable note. Ink refused because the board was deleted waits for *Keep my ink as a new board*.

import BugKit
import ContextCore
import PencilKit
import SwiftUI

@MainActor
final class CockpitBoardModel: ObservableObject {
  @Published private(set) var name: String
  @Published private(set) var drawing = PKDrawing()
  @Published private(set) var status = "Opening…"
  @Published private(set) var notes: [BoardStoreCache.Note] = []
  @Published private(set) var problem: BugProblem?
  @Published private(set) var inkSetAside = false
  /// Bumped when the canvas must take `drawing` (a load, or a stroke taken back), never on the canvas's own change.
  @Published private(set) var redraws = 0
  private(set) var boardID: String
  private var cache: BoardStoreCache?
  private var syncing = false
  private var again = false
  /// The device's own changes made while a pass is out, put back on the copy the pass brings home.
  private var madeDuringPass: [(inout BoardStoreCache) -> Void] = []
  private var loggedError: String?
  /// The strokes the canvas was last given or last took, in draw order.
  private var showing: [CockpitBoardEdit.Stroke] = []
  /// The id each stroke on the canvas was drawn under, by its creation moment, and how it looked when last shown.
  private var shown: [Double: (id: String, bounds: CGRect, record: BoardStoreJSON)] = [:]
  private let reads: String
  private let writes: String?
  private let log: SessionLog
  private let disk: CockpitBoardDisk
  let device: String

  init(boardID: String, name: String, reads: String, log: SessionLog) {
    self.boardID = boardID
    self.name = name
    self.reads = reads
    writes = WhiteboardCockpitBoards.writeAddress(reads)
    self.log = log
    let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("cockpit-boards", isDirectory: true)
    disk = CockpitBoardDisk(folder: folder)
    device = Self.deviceName()
  }

  func open() async {
    if let saved = disk.load(board: boardID) {
      cache = saved
      show()
    } else {
      do {
        let request = try CockpitBoardStore.snapshotRequest(board: boardID, cockpit: reads)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let snapshot = CockpitBoardStore.json(data) else {
          fail("the board didn't load (HTTP \(status))", operation: "open")
          return
        }
        cache = BoardStoreCache(snapshot: snapshot)
        persist()
        show()
      } catch {
        fail("the board didn't load (\(error.localizedDescription))", operation: "open")
        return
      }
    }
    await sync()
  }

  /// The canvas's own change: what it now holds, as the store's ops, queued and sent.
  func canvasChanged(_ new: PKDrawing) {
    guard let cache else { return }
    var used = Set<String>()
    var after: [BoardStoreJSON] = []
    for stroke in new.strokes {
      let key = stroke.path.creationDate.timeIntervalSince1970
      if let known = shown[key], !used.contains(known.id) {
        used.insert(known.id)
        after.append(
          known.bounds == stroke.renderBounds ? known.record : CockpitStrokeRecord.record(stroke, id: known.id))
      } else {
        let id = CockpitStrokeRecord.newID(for: stroke, taken: used.union(cache.view.keys))
        used.insert(id)
        let record = CockpitStrokeRecord.record(stroke, id: id)
        shown[key] = (id, stroke.renderBounds, record)
        after.append(record)
      }
    }
    switch CockpitBoardEdit.ops(cache, after: after) {
    case .failure(let failure):
      fail("this change couldn't be saved (\(failure))", operation: "encode")
    case .success(let ops):
      guard !ops.isEmpty else { return }
      edit { $0.enqueue(ops) }
      drawing = new
      if let cache = self.cache { showing = CockpitBoardEdit.strokes(cache) }
      persist()
      log.event(
        "board_store",
        ["action": "queued", "board": boardID, "ops": ops.count, "waiting": self.cache?.queue.count ?? 0])
      status = writes == nil ? "Saves wait: the Cockpit doesn't take them yet" : "Saving…"
      Task { await sync() }
    }
  }

  func sync() async {
    guard !syncing else {
      again = true
      return
    }
    syncing = true
    defer { syncing = false }
    repeat {
      again = false
      await pass()
    } while again
  }

  /// A change of the device's own to the copy, kept through a pass that is out.
  private func edit(_ change: @escaping (inout BoardStoreCache) -> Void) {
    guard var cache else { return }
    change(&cache)
    self.cache = cache
    if syncing { madeDuringPass.append(change) }
  }

  private func pass() async {
    guard var cache else { return }
    let board = boardID
    madeDuringPass = []
    let device = device
    var sync = CockpitBoardSync(
      cockpit: writes ?? reads, device: device, by: "igor",
      send: { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
      },
      newBatchID: { "\(device)-\(UUID().uuidString.prefix(12).lowercased())" },
      now: { ISO8601DateFormatter().string(from: Date()) })
    if writes == nil { sync.limit = 0 }  // reads only until the Cockpit takes the iPad's saves
    let disk = disk
    let report = await sync.run(&cache) { copy in try disk.save(copy) }
    let made = madeDuringPass
    madeDuringPass = []
    guard board == boardID else { return }
    for change in made { change(&cache) }
    self.cache = cache
    if !made.isEmpty { persist() }
    if let failure = report.problem {
      fail(failure, operation: "sync")
    } else {
      problem = nil
      loggedError = nil
    }
    log.event(
      "board_store",
      [
        "action": "synced", "board": boardID, "sent": report.sent, "rev": cache.rev, "waiting": cache.queue.count,
        "notes": cache.notes.count, "set_aside": cache.setAside.count, "problem": report.problem ?? "",
      ])
    show()
  }

  /// *Keep my ink as a new board*: a new Cockpit board named for this one plus *(kept ink)*, with the set-aside ink.
  func keepInk() async {
    guard var cache, let target = writes else { return }
    let board = boardID
    let newID = "b-" + UUID().uuidString.lowercased()
    guard let kept = cache.keptInk(newID: newID) else { return }
    var create = kept.create
    create["device"] = .string(device)
    do {
      let (_, response) = try await URLSession.shared.data(
        for: try CockpitBoardStore.createRequest(body: create, cockpit: target))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200 else {
        fail("the new board wasn't made (HTTP \(status))", operation: "keep_ink")
        return
      }
    } catch {
      fail("the new board wasn't made (\(error.localizedDescription))", operation: "keep_ink")
      return
    }
    guard board == boardID else { return }
    edit { $0.dismissSetAside() }
    persist()
    let newName = create["name"]?.string ?? "Board (kept ink)"
    var fresh = CockpitBoardEdit.emptyBoard(id: newID, name: newName)
    fresh.enqueue(kept.ops)
    log.event("board_store", ["action": "kept_ink", "board": boardID, "new_board": newID, "ops": kept.ops.count])
    boardID = newID
    name = newName
    self.cache = fresh
    shown = [:]
    showing = []
    persist()
    show()
    await sync()
  }

  func letInkGo() {
    edit { $0.dismissSetAside() }
    persist()
    log.event("board_store", ["action": "let_ink_go", "board": boardID])
    show()
  }

  /// The canvas shows the copy as it opens: the Cockpit's ink with this device's waiting saves on top.
  private func show() {
    guard let cache else { return }
    let live = CockpitBoardEdit.strokes(cache)
    let ids = Set(live.map(\.id))
    var taken = Set(shown.filter { ids.contains($0.value.id) }.keys)
    var strokes: [PKStroke] = []
    var next: [Double: (id: String, bounds: CGRect, record: BoardStoreJSON)] = [:]
    for (index, stroke) in live.enumerated() {
      let previous = shown.first { $0.value.id == stroke.id }
      var made = CockpitStrokeRecord.stroke(stroke.record, id: stroke.id, index: index, at: previous?.key)
      while previous == nil, taken.contains(made.path.creationDate.timeIntervalSince1970) {
        let bumped = made.path.creationDate.timeIntervalSince1970 + 1e-4
        made = CockpitStrokeRecord.stroke(stroke.record, id: stroke.id, index: index, at: bumped)
      }
      let key = made.path.creationDate.timeIntervalSince1970
      taken.insert(key)
      strokes.append(made)
      next[key] = (stroke.id, made.renderBounds, stroke.record)
    }
    shown = next
    if live != showing {
      showing = live
      drawing = PKDrawing(strokes: strokes)
      redraws += 1
    }
    notes = cache.notes
    inkSetAside = !cache.setAside.isEmpty
    if let name = cache.view[BoardStoreClash.boardID]?.body?["name"]?.string, !name.isEmpty { self.name = name }
    if problem != nil { return }
    if cache.deleted != nil {
      status = "This board was deleted"
    } else if !cache.queue.isEmpty {
      status =
        writes == nil
        ? "Saves wait: the Cockpit doesn't take them yet"
        : cache.queue.count == 1 ? "1 save waiting" : "\(cache.queue.count) saves waiting"
    } else {
      status = "Saved · version \(cache.rev)"
    }
  }

  private func persist() {
    guard let cache else { return }
    do { try disk.save(cache) } catch {
      fail("the board's copy couldn't be written (\(error.localizedDescription))", operation: "save_copy")
    }
  }

  private func fail(_ what: String, operation: String) {
    if loggedError != what {
      log.event("error", ["where": "CockpitBoardModel.\(operation)", "board": boardID, "error": what])
      loggedError = what
    }
    status = "Cockpit not answering"
    problem = BugProblem(
      message: what.hasPrefix("Cockpit not answering") ? what : "Cockpit not answering: \(what)",
      context: "CockpitBoardView.\(operation)",
      build: "\(BuildInfo.sha) \(BuildInfo.branch)",
      extra: [
        "board": .string(boardID), "reads": .string(reads), "writes": .string(writes ?? "none yet"),
        "waiting": .int(cache?.queue.count ?? 0),
      ],
      autoFile: false)
  }

  static func deviceName() -> String {
    let kind = ProcessInfo.processInfo.isMacCatalystApp ? "mac" : "ipad"
    let vendor = UIDevice.current.identifierForVendor?.uuidString.lowercased() ?? "unknown"
    return kind + "-" + String(vendor.filter { $0.isLetter || $0.isNumber }.prefix(8))
  }
}

/// A PencilKit stroke as the store's stroke record (plan section 5), and back.
enum CockpitStrokeRecord {
  private static let inks: [(PKInk.InkType, String)] = [
    (.pen, "pen"), (.pencil, "pencil"), (.marker, "marker"), (.monoline, "monoline"), (.fountainPen, "fountainPen"),
    (.watercolor, "watercolor"), (.crayon, "crayon"),
  ]

  static func newID(for stroke: PKStroke, taken: Set<String>) -> String {
    let base = "s-\(Int64(stroke.path.creationDate.timeIntervalSince1970 * 1000))"
    guard taken.contains(base) else { return base }
    // A letter, never "-<n>": the encoder reads "<id>-<n>" as a piece of an erased stroke.
    for letter in "abcdefghijklmnopqrstuvwxyz" where !taken.contains(base + String(letter)) {
      return base + String(letter)
    }
    return base + UUID().uuidString.prefix(6).lowercased()
  }

  static func record(_ stroke: PKStroke, id: String) -> BoardStoreJSON {
    let transform = stroke.transform
    let points: [BoardStoreJSON] = stroke.path.map { point in
      let at = point.location.applying(transform)
      return [
        .number(round2(at.x)), .number(round2(at.y)), .number(round2(point.force)),
        .int(Int64(point.timeOffset * 1000)), .number(round2(point.azimuth)), .number(round2(point.altitude)),
        .number(round2(point.size.width)),
      ]
    }
    let ink = inks.first { $0.0 == stroke.ink.inkType }?.1 ?? "pen"
    let width = stroke.path.first?.size.width ?? 2
    var record: BoardStoreJSON = [
      "id": .string(id), "pts": .array(points), "w": .number(round2(width)), "c": .string(hex(stroke.ink.color)),
      "ink": .string(ink),
      "made_at": .string(ISO8601DateFormatter().string(from: stroke.path.creationDate)),
    ]
    record["seed"] = .int(Int64(stroke.randomSeed))
    return record
  }

  /// The record drawn as a stroke. `at` keeps the creation moment it was shown under, so the canvas's later changes
  /// still name it.
  static func stroke(_ record: BoardStoreJSON, id: String, index: Int, at: Double?) -> PKStroke {
    let width = CGFloat(record["w"].flatMap(number) ?? 2)
    let made = at.map { Date(timeIntervalSince1970: $0) } ?? moment(record, id: id, index: index)
    let points = (record["pts"]?.array ?? []).map { point -> PKStrokePoint in
      let values = (point.array ?? []).map { number($0) ?? 0 }
      let value = { (index: Int, fallback: Double) in values.count > index ? values[index] : fallback }
      let size = value(6, Double(width))
      return PKStrokePoint(
        location: CGPoint(x: value(0, 0), y: value(1, 0)), timeOffset: value(3, 0) / 1000,
        size: CGSize(width: size, height: size), opacity: 1, force: value(2, 1), azimuth: value(4, 0),
        altitude: value(5, .pi / 2))
    }
    let type = inks.first { $0.1 == record["ink"]?.string }?.0 ?? .pen
    let ink = PKInk(type, color: color(record["c"]?.string))
    var stroke = PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: made))
    if let seed = record["seed"]?.int { stroke.randomSeed = UInt32(truncatingIfNeeded: seed) }
    return stroke
  }

  private static func moment(_ record: BoardStoreJSON, id: String, index: Int) -> Date {
    if let ms = Double(id.dropFirst(2).prefix { $0.isNumber }), id.hasPrefix("s-") {
      return Date(timeIntervalSince1970: ms / 1000 + Double(index) * 1e-6)
    }
    // A web stroke's id isn't a moment: a fixed one, unique by its place on the board.
    return Date(timeIntervalSince1970: 1_000_000_000 + Double(index) / 1000)
  }

  private static func number(_ json: BoardStoreJSON) -> Double? {
    switch json {
    case .int(let value): Double(value)
    case .number(let value): value
    default: nil
    }
  }

  private static func round2(_ value: CGFloat) -> Double { (Double(value) * 100).rounded() / 100 }

  private static func hex(_ color: UIColor) -> String {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
      .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    let byte = { (part: CGFloat) in Int((min(max(part, 0), 1) * 255).rounded()) }
    return String(format: "#%02x%02x%02x", byte(red), byte(green), byte(blue))
  }

  private static func color(_ hex: String?) -> UIColor {
    guard let hex, hex.hasPrefix("#"), hex.count == 7, let value = Int(hex.dropFirst(), radix: 16) else {
      return .black
    }
    return UIColor(
      red: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255,
      blue: CGFloat(value & 0xff) / 255, alpha: 1)
  }
}

struct CockpitBoardView: View {
  @StateObject private var model: CockpitBoardModel
  @State private var erasing = false
  private let logger: BugLogger

  init(boardID: String, name: String, app: AppModel) {
    _model = StateObject(
      wrappedValue: CockpitBoardModel(boardID: boardID, name: name, reads: app.chat.cockpit, log: app.log))
    logger = app.bugLogger
  }

  var body: some View {
    VStack(spacing: 0) {
      CockpitCanvas(model: model, erasing: erasing)
        .accessibilityIdentifier("cockpit-board-canvas")
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(model.status).font(.footnote).foregroundStyle(.secondary)
            .accessibilityIdentifier("cockpit-board-status")
          Spacer()
          Text(model.drawing.strokes.count == 1 ? "1 stroke" : "\(model.drawing.strokes.count) strokes")
            .font(.footnote).foregroundStyle(.secondary)
            .accessibilityIdentifier("cockpit-board-strokes")
        }
        if let problem = model.problem { BugProblemView(problem: problem, logger: logger) }
        ForEach(Array(model.notes.enumerated()), id: \.offset) { _, note in
          BugProblemView(problem: noteProblem(note), logger: logger)
            .accessibilityIdentifier("cockpit-board-note")
        }
        if model.inkSetAside {
          HStack {
            Button("Keep my ink as a new board") { Task { await model.keepInk() } }
              .accessibilityIdentifier("cockpit-board-keep-ink")
            Button("Let it go", role: .destructive) { model.letInkGo() }
          }
        }
      }
      .padding()
    }
    .navigationTitle(model.name.isEmpty ? "Untitled" : model.name)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Picker("Tool", selection: $erasing) {
          Image(systemName: "pencil.tip").tag(false).accessibilityLabel("Pen")
          Image(systemName: "eraser").tag(true).accessibilityLabel("Eraser")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("cockpit-board-tool")
      }
    }
    .task { await model.open() }
  }

  /// Story 1345: a refused change as a copyable note: what, why, and who changed it when.
  private func noteProblem(_ note: BoardStoreCache.Note) -> BugProblem {
    var who = ""
    if let author = note.author { who = " (changed on \(author.device) by \(author.by) at \(author.at))" }
    let message =
      note.reason == "deleted"
      ? "Your ink wasn't saved: this board was deleted\(who)."
      : "Your \(note.kind) of \(note.id) wasn't saved: \(note.reason)\(who). The board shows the Cockpit's ink."
    return BugProblem(
      message: message, context: "CockpitBoardView.refused", build: "\(BuildInfo.sha) \(BuildInfo.branch)",
      extra: [
        "board": .string(model.boardID), "id": .string(note.id), "reason": .string(note.reason),
        "op": .string(note.kind), "rev": .int(note.rev ?? -1), "local": .bool(note.local),
      ],
      autoFile: false)
  }
}

/// The trial canvas: PencilKit with a pen and a whole-stroke eraser, any input (a finger draws too, as on the Mac and
/// in the simulator).
private struct CockpitCanvas: UIViewRepresentable {
  @ObservedObject var model: CockpitBoardModel
  let erasing: Bool

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> PKCanvasView {
    let canvas = PKCanvasView()
    canvas.drawingPolicy = .anyInput
    canvas.backgroundColor = .systemBackground
    canvas.drawing = model.drawing
    canvas.delegate = context.coordinator
    context.coordinator.redraws = model.redraws
    return canvas
  }

  func updateUIView(_ canvas: PKCanvasView, context: Context) {
    canvas.tool = erasing ? PKEraserTool(.vector) : PKInkingTool(.pen, color: .label, width: 3)
    if context.coordinator.redraws != model.redraws {
      context.coordinator.redraws = model.redraws
      context.coordinator.loading = true
      canvas.drawing = model.drawing
      context.coordinator.loading = false
    }
  }

  @MainActor
  final class Coordinator: NSObject, PKCanvasViewDelegate {
    let model: CockpitBoardModel
    var redraws = 0
    var loading = false

    init(model: CockpitBoardModel) { self.model = model }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      guard !loading else { return }
      model.canvasChanged(canvasView.drawing)
    }
  }
}
