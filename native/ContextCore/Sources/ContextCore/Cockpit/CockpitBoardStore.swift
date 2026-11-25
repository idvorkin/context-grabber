//  The beta switch's talk with the Cockpit board store (spec 2026-11-22-boards-in-the-cockpit-design.md, Trying it
//  before the rollout: Boards from the Cockpit (beta); stories 1339-1341; plan 2026-11-24-boards-in-the-cockpit-plan.md
//  sections 6 and 7a). The requests and the list rows, a board's copy on disk, and one sync pass that drives
//  `BoardStoreCache`: fetch what was missed, then send the oldest waiting save, wait for its answer, and only then the
//  next. Kept out of BoardCore (whose Foundation, on WebAssembly, has no URLRequest).

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum CockpitBoardStore {
  /// One board in `GET /boards`.
  public struct Row: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var rev: Int
    public var lastDrawnOn: String?

    public init(id: String, name: String, rev: Int, lastDrawnOn: String? = nil) {
      self.id = id
      self.name = name
      self.rev = rev
      self.lastDrawnOn = lastDrawnOn
    }
  }

  public static func listRequest(cockpit: String) throws -> URLRequest {
    try get(cockpit, "/boards")
  }

  public static func snapshotRequest(board: String, cockpit: String) throws -> URLRequest {
    try get(cockpit, "/boards/" + escaped(board))
  }

  public static func opsRequest(board: String, since: Int, cockpit: String) throws -> URLRequest {
    try get(cockpit, "/boards/" + escaped(board) + "/ops?since=\(since)")
  }

  /// `POST /boards/<id>/ops` with one frozen batch's wire body.
  public static func postRequest(board: String, body: BoardStoreJSON, cockpit: String) throws -> URLRequest {
    var request = try get(cockpit, "/boards/" + escaped(board) + "/ops")
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let url = request.url { request.setValue(CockpitPage.origin(of: url), forHTTPHeaderField: "Origin") }
    request.httpBody = data(body)
    return request
  }

  /// The live boards, most versions first; nil when the answer isn't the store's.
  public static func rows(_ data: Data) -> [Row]? {
    guard let boards = json(data)?["boards"]?.array else { return nil }
    return
      boards
      .filter { $0["deleted"]?.bool != true }
      .compactMap { board -> Row? in
        guard let id = board["id"]?.string else { return nil }
        return Row(
          id: id, name: board["name"]?.string ?? "", rev: board["rev"]?.int ?? 0,
          lastDrawnOn: board["last_drawn_on"]?.string)
      }
      .sorted { $0.rev > $1.rev }
  }

  public static func json(_ data: Data) -> BoardStoreJSON? {
    try? JSONDecoder().decode(BoardStoreJSON.self, from: data)
  }

  public static func data(_ json: BoardStoreJSON) -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return (try? encoder.encode(json)) ?? Data("null".utf8)
  }

  private static func get(_ cockpit: String, _ path: String) throws -> URLRequest {
    guard URL(string: cockpit)?.host != nil else { throw URLError(.badURL) }
    return try ChatWire.get(cockpit, path)
  }

  private static func escaped(_ id: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/?#")
    return id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
  }
}

/// Each Cockpit board's copy and its waiting saves, one JSON file per board, written whole and atomically.
public struct CockpitBoardDisk: Sendable {
  public let folder: URL

  public init(folder: URL) { self.folder = folder }

  public func load(board: String) -> BoardStoreCache? {
    guard let data = try? Data(contentsOf: file(board)) else { return nil }
    return try? JSONDecoder().decode(BoardStoreCache.self, from: data)
  }

  public func save(_ cache: BoardStoreCache) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try JSONEncoder().encode(cache).write(to: file(cache.boardID), options: .atomic)
  }

  private func file(_ board: String) -> URL {
    let safe = board.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? String($0) : "_" }.joined()
    return folder.appendingPathComponent("board-\(safe).json")
  }
}

/// One pass with the Cockpit for one board: what was missed comes first, then the waiting saves one at a time.
public struct CockpitBoardSync: Sendable {
  public typealias Send = @Sendable (URLRequest) async throws -> (Int, Data)

  public struct Report: Equatable, Sendable {
    /// Saves answered this pass.
    public var sent = 0
    /// Whether the pass fetched changes or a fresh copy.
    public var pulled = false
    /// What stopped the pass early, copyable: the address, the request, what failed.
    public var problem: String?
  }

  public let cockpit: String
  public let device: String
  public let by: String
  public let send: Send
  public let newBatchID: @Sendable () -> String
  public let now: @Sendable () -> String
  /// The most saves one pass sends; the rest wait for the next pass.
  public var limit = 20

  public init(
    cockpit: String, device: String, by: String, send: @escaping Send, newBatchID: @escaping @Sendable () -> String,
    now: @escaping @Sendable () -> String
  ) {
    self.cockpit = cockpit
    self.device = device
    self.by = by
    self.send = send
    self.newBatchID = newBatchID
    self.now = now
  }

  /// `save` writes the copy to disk: before each save leaves (so a kill sends it again as it was) and after each
  /// answer or fetch.
  public func run(_ cache: inout BoardStoreCache, save: (BoardStoreCache) throws -> Void) async -> Report {
    var report = Report()
    let board = cache.boardID
    let me = BoardStoreClash.Author(device: device, by: by, at: now())
    var fetched = false
    var rounds = 0
    while rounds < limit * 3 {
      rounds += 1
      if cache.needsReload {
        guard let snapshot = await ask(try CockpitBoardStore.snapshotRequest(board: board, cockpit: cockpit), &report)
        else { return report }
        cache.reload(snapshot: snapshot, slug: device)
        report.pulled = true
        fetched = true
        try? save(cache)
        continue
      }
      if cache.needsPull || !fetched {
        guard
          let answer = await ask(
            try CockpitBoardStore.opsRequest(board: board, since: cache.rev, cockpit: cockpit), &report),
          let rev = answer["rev"]?.int
        else { return report }
        cache.pull(rev: rev, batches: answer["batches"]?.array ?? [], slug: device)
        report.pulled = true
        fetched = true
        try? save(cache)
        continue
      }
      // The save in flight keeps its name; only a fresh one gets a new one.
      guard report.sent < limit, let first = cache.queue.first,
        let batch = cache.freeze(batchID: first.batchID ?? newBatchID(), deviceAt: now())
      else { break }
      try? save(cache)
      let request: URLRequest
      do {
        request = try CockpitBoardStore.postRequest(
          board: board, body: batch.wire(device: device, by: by), cockpit: cockpit)
      } catch {
        report.problem = problem("POST /boards/\(board)/ops", error: "\(error)")
        return report
      }
      let status: Int
      let data: Data
      do {
        (status, data) = try await send(request)
      } catch {
        report.problem = problem("POST /boards/\(board)/ops", error: "\(error)")
        return report
      }
      let outcome = cache.receive(
        status: status, answer: CockpitBoardStore.json(data) ?? [:], me: me, slug: device)
      try? save(cache)
      switch outcome {
      case .done:
        report.sent += 1
      case .keepQueued:
        report.problem = problem("POST /boards/\(board)/ops", error: "HTTP \(status), the save waits to go again")
        return report
      case .batchIDReused:
        report.problem = problem("POST /boards/\(board)/ops", error: "HTTP \(status), batch_id_reused")
        return report
      }
    }
    return report
  }

  private func ask(_ make: @autoclosure () throws -> URLRequest, _ report: inout Report) async -> BoardStoreJSON? {
    let request: URLRequest
    do { request = try make() } catch {
      report.problem = problem("GET", error: "\(error)")
      return nil
    }
    let what = "GET " + (request.url.map { $0.path + ($0.query.map { "?" + $0 } ?? "") } ?? "")
    do {
      let (status, data) = try await send(request)
      guard status == 200, let json = CockpitBoardStore.json(data) else {
        report.problem = problem(what, error: "HTTP \(status)")
        return nil
      }
      return json
    } catch {
      report.problem = problem(what, error: "\(error)")
      return nil
    }
  }

  private func problem(_ what: String, error: String) -> String {
    "Cockpit not answering: \(what) at \(cockpit) failed: \(error)"
  }
}
