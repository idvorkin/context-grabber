//  Drawing on a Cockpit board (spec 2026-11-22-boards-in-the-cockpit-design.md, Trying it before the rollout: Drawing on
//  a Cockpit board; stories 1344-1346; cockpit-8kh): the board's strokes as the trial canvas shows them, and a change of
//  its strokes turned into the store's ops through the one encoder (`BoardStoreEncode`, #1507). Only strokes: the trial
//  canvas leaves every other thing on the board as it is, so they are in neither side of the encode.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension BoardStoreJSON {
  /// From the values `JSONSerialization` and the encoder give (Swift's own types, or `NSNumber` and `NSNull`).
  public init(any value: Any?) {
    guard let value, !(value is NSNull) else {
      self = .null
      return
    }
    if type(of: value) == Bool.self, let bool = value as? Bool {
      self = .bool(bool)
    } else if let string = value as? String {
      self = .string(string)
    } else if let array = value as? [Any] {
      self = .array(array.map { BoardStoreJSON(any: $0) })
    } else if let object = value as? [String: Any] {
      self = .object(object.mapValues { BoardStoreJSON(any: $0) })
    } else if let int = value as? Int64, type(of: value) != Double.self {
      self = .int(int)
    } else if let int = value as? Int, type(of: value) != Double.self {
      self = .int(Int64(int))
    } else if let number = value as? Double {
      self = .number(number)
    } else {
      self = .null
    }
  }
}

public enum CockpitBoardEdit {
  public struct Stroke: Equatable, Sendable {
    public var id: String
    public var record: BoardStoreJSON
  }

  public enum Failure: Error, Equatable {
    /// The encoder refused the after board (a record without an id, or an id used twice).
    case malformed(String)
  }

  /// The board's live strokes as it opens (the copy with this device's waiting saves on top), in draw order.
  public static func strokes(_ cache: BoardStoreCache) -> [Stroke] {
    let view = cache.view
    return cache.viewOrder.compactMap { id in
      guard let thing = view[id], !thing.erased, isStroke(thing), let body = thing.body else { return nil }
      return Stroke(id: id, record: body)
    }
  }

  /// The ops that take the board as it opens to `after`'s strokes, in an order the store takes in one batch; none when
  /// nothing changed.
  public static func ops(_ cache: BoardStoreCache, after: [BoardStoreJSON]) -> Result<[BoardStoreJSON], Failure> {
    let before = strokes(cache).map(\.record.any)
    var erased: [String: Any] = [:]
    for (id, thing) in cache.view where thing.erased && isStroke(thing) {
      if let body = thing.body { erased[id] = body.any }
    }
    let answer = BoardStoreEncode.encode(
      before: ["strokes": before], after: ["strokes": after.map(\.any)], erased: erased)
    if let error = answer["error"] as? String { return .failure(.malformed(error)) }
    return .success((answer["ops"] as? [Any] ?? []).map { BoardStoreJSON(any: $0) })
  }

  /// A new empty board's copy: what *Keep my ink as a new board* starts from before its first save.
  public static func emptyBoard(id: String, name: String) -> BoardStoreCache {
    BoardStoreCache(snapshot: [
      "id": .string(id), "rev": 0, "erased": [],
      "things": [["id": "@board", "kind": "board", "body": ["name": .string(name)], "rev": 0, "device": "", "by": ""]],
    ])
  }

  private static func isStroke(_ thing: BoardStoreCache.Thing) -> Bool {
    thing.kind == "stroke" || (thing.kind == nil && thing.body?["pts"] != nil)
  }
}

extension CockpitBoardStore {
  /// `POST /boards`: a new board, `{id, name, paper?}`, made on the device so it can be made offline.
  public static func createRequest(body: BoardStoreJSON, cockpit: String) throws -> URLRequest {
    var request = try ChatWire.get(cockpit, "/boards")
    guard request.url?.host != nil else { throw URLError(.badURL) }
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let url = request.url { request.setValue(CockpitPage.origin(of: url), forHTTPHeaderField: "Origin") }
    request.httpBody = data(body)
    return request
  }
}
