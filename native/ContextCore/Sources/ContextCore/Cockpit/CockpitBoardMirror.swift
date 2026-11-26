//  Sending a board to the Cockpit, the mirror (spec 2026-11-22-boards-in-the-cockpit-design.md, Sending a board to the
//  Cockpit (the mirror, beta); stories 1361-1363; cockpit-8kh): an iCloud board stays the iPad's full board and its truth,
//  and the Cockpit keeps a copy. This is the part with no PencilKit in it: the stable stroke ids, the store's create, the
//  original drawing as an asset, a save cut under the store's size limit, the gate on the store's backup, and which
//  boards are mirrored.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum CockpitBoardMirror {
  /// What one save may weigh: under the store's 8 MB for a batch, with room for the batch's own fields.
  public static let maxBatchBytes = 7_500_000

  /// The store's nightly backup to igor2 is live (slice 4, cockpit-8kh.1; Larry, 2026-11-26, cockpit cfbb196), so any
  /// board may go (story 1363). Before that only a *Scratch…* board could; set back to false to hold real boards again.
  public static let backupLive = true

  /// Whether this board may be sent: any once the backup is live, before that only a board named *Scratch…*.
  public static func allowed(name: String, backupLive: Bool = backupLive) -> Bool {
    backupLive || name.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("scratch")
  }

  /// The id each stroke is sent under, from the stroke itself, in draw order: `s-<ms>x<seed>`, its creation moment and
  /// its random seed in hex, and only for a second stroke with both the same a letter after it (never `-<n>`, which the
  /// encoder reads as a piece of an erased stroke). The same board gives the same ids every time, so a second send
  /// lands nothing twice (story 1362), and erasing one stroke moves no other stroke's id.
  public static func strokeIDs(_ strokes: [(ms: Int64, seed: UInt32)]) -> [String] {
    var taken = Set<String>()
    var repeats: [String: Int] = [:]
    return strokes.map { stroke in
      let base = "s-\(stroke.ms)x\(String(stroke.seed, radix: 16))"
      var id = base
      while taken.contains(id) {
        let n = repeats[base, default: 0]
        repeats[base] = n + 1
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        id = n < letters.count ? base + String(letters[n]) : base + "z\(n)"
      }
      taken.insert(id)
      return id
    }
  }

  /// The strokes the mirror's save compares the copy against: this device's `records`, and every live stroke on the copy
  /// that another device drew (the web board, Larry) as it is, so a save never erases or overwrites what it didn't send.
  /// A stroke this device sent, or has waiting, is its own: one the drawing no longer has is erased.
  public static func after(records: [BoardStoreJSON], cache: BoardStoreCache, device: String) -> [BoardStoreJSON] {
    let view = cache.view
    let ours = Set(records.compactMap { $0["id"]?.string })
    let theirs = CockpitBoardEdit.strokes(cache).filter { stroke in
      let author = view[stroke.id]?.author.device ?? ""
      return !author.isEmpty && author != device && !ours.contains(stroke.id)
    }
    return records + theirs.map(\.record)
  }

  /// The name the store keeps for a board: its own, or *Untitled* for one without.
  public static func storeName(_ name: String) -> String { name.isEmpty ? "Untitled" : name }

  /// The store's `rename` when the board's name isn't the copy's, so a board renamed after its first send follows.
  public static func rename(_ cache: BoardStoreCache, name: String) -> BoardStoreJSON? {
    let name = storeName(name)
    guard cache.view[BoardStoreClash.boardID]?.body?["name"]?.string != name else { return nil }
    return ["op": "rename", "name": .string(name)]
  }

  /// `POST /boards`'s body: the iCloud board's own id and name, its paper, and the original drawing's asset.
  public static func createBody(
    id: String, name: String, paper: String?, ruled: Bool, device: String, originalAsset: String?
  ) -> BoardStoreJSON {
    var body: BoardStoreJSON = [
      "id": .string(id), "name": .string(storeName(name)), "ruled": .bool(ruled),
      "device": .string(device), "by": "igor",
    ]
    if let paper { body["paper"] = .string(paper) }
    if let originalAsset { body["original_asset"] = .string(originalAsset) }
    return body
  }

  /// `PUT /boards/assets/<sha>`: the board's original drawing, kept beside the store's copy for a lossless way back.
  public static func assetRequest(sha: String, data: Data, cockpit: String) throws -> URLRequest {
    var request = try ChatWire.get(cockpit, "/boards/assets/\(sha)")
    guard request.url?.host != nil else { throw URLError(.badURL) }
    request.httpMethod = "PUT"
    request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
    if let url = request.url { request.setValue(CockpitPage.origin(of: url), forHTTPHeaderField: "Origin") }
    request.httpBody = data
    return request
  }

  /// The encoder's ops as saves each under `maxBytes`, in order: an `add_strokes` too big for one save is cut between
  /// its strokes; every other op goes whole. A stroke bigger than the limit alone still goes, in a save of its own.
  public static func saves(_ ops: [BoardStoreJSON], maxBytes: Int = maxBatchBytes) -> [[BoardStoreJSON]] {
    var out: [[BoardStoreJSON]] = []
    var current: [BoardStoreJSON] = []
    var weight = 0
    func close() {
      if !current.isEmpty { out.append(current) }
      current = []
      weight = 0
    }
    func put(_ op: BoardStoreJSON) {
      let size = CockpitBoardStore.data(op).count
      if weight > 0, weight + size > maxBytes { close() }
      current.append(op)
      weight += size
    }
    for op in ops {
      guard op["op"]?.string == "add_strokes", let strokes = op["strokes"]?.array,
        CockpitBoardStore.data(op).count > maxBytes
      else {
        put(op)
        continue
      }
      var part: [BoardStoreJSON] = []
      var partWeight = 0
      for stroke in strokes {
        let size = CockpitBoardStore.data(stroke).count + 1
        if !part.isEmpty, partWeight + size > maxBytes - 64 {
          put(["op": "add_strokes", "strokes": .array(part)])
          close()
          part = []
          partWeight = 0
        }
        part.append(stroke)
        partWeight += size
      }
      if !part.isEmpty { put(["op": "add_strokes", "strokes": .array(part)]) }
    }
    close()
    return out
  }

  /// Which boards are mirrored, and which have had their create and original drawing taken, on disk.
  public struct Book: Equatable, Codable, Sendable {
    public var mirrored: Set<String> = []
    /// Boards whose `POST /boards` (and asset) the Cockpit answered: their saves can go.
    public var created: Set<String> = []

    public init() {}

    public static func load(_ url: URL) -> Book {
      guard let data = try? Data(contentsOf: url), let book = try? JSONDecoder().decode(Book.self, from: data) else {
        return Book()
      }
      return book
    }

    public func save(_ url: URL) throws {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
  }
}
