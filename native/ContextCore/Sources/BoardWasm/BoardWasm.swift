//  The board's rules behind a small C interface, for the Cockpit's web board (spec
//  2026-11-22-board-rules-on-the-web-design.md, The interface, versions 1 to 3). The board stays loaded: `bw_load`
//  once, `bw_add_strokes` for new ink, `bw_cut_y` with plain numbers. Inputs are the host's buffers, read and never
//  kept; every pointer returned is a new length-prefixed reply the host frees with `bw_free`. The outline's exports
//  (rows and folds) are in BoardWasmOutline.swift, a paste's landing and a drop's room in BoardWasmRoom.swift.

#if os(WASI)
  import BoardCore
  #if FOUNDATION_ESSENTIALS_ONLY
    import FoundationEssentials
  #else
    import Foundation
  #endif

  /// This interface's version: up when an export's arguments, results or JSON change.
  let abi = 23

  /// The loaded board, its boxes as the rules take them (computed when first asked), and why the last call failed.
  var board: BoardSnapshot?
  var boxes: [CGRect]?
  var lastError: String?

  /// What shows and moves whole, as the iPad's own cut takes it (`BoardOps.shownBoxes` over the board's plan input).
  func loadedBoxes(_ board: BoardSnapshot) -> [CGRect] {
    if let boxes { return boxes }
    let input = board.planInput
    let out = BoardOps.shownBoxes(strokes: input.strokes, texts: input.texts, groups: input.metas.groups)
    boxes = out
    return out
  }

  func reply(_ data: Data) -> UnsafeMutableRawPointer {
    let out = UnsafeMutableRawPointer.allocate(byteCount: 4 + data.count, alignment: 4)
    out.storeBytes(of: UInt32(data.count).littleEndian, as: UInt32.self)
    data.withUnsafeBytes { bytes in
      if let base = bytes.baseAddress { out.advanced(by: 4).copyMemory(from: base, byteCount: data.count) }
    }
    return out
  }

  func reply(json object: Any) -> UnsafeMutableRawPointer {
    reply(
      (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
        ?? Data(#"{"error":"no JSON"}"#.utf8))
  }

  func input(_ pointer: UnsafeRawPointer?, _ length: Int32) -> Data {
    guard let pointer, length > 0 else { return Data() }
    return Data(bytes: pointer, count: Int(length))
  }

  func failed(_ why: String) -> Int32 {
    lastError = why
    return -1
  }

  @_expose(wasm, "bw_alloc")
  @_cdecl("bw_alloc")
  public func bwAlloc(_ count: Int32) -> UnsafeMutableRawPointer {
    UnsafeMutableRawPointer.allocate(byteCount: max(Int(count), 0), alignment: 8)
  }

  @_expose(wasm, "bw_free")
  @_cdecl("bw_free")
  public func bwFree(_ pointer: UnsafeMutableRawPointer?) { pointer?.deallocate() }

  @_expose(wasm, "bw_info")
  @_cdecl("bw_info")
  public func bwInfo() -> UnsafeMutableRawPointer {
    reply(json: [
      "abi": abi, "cgfloat_bits": MemoryLayout<CGFloat>.size * 8, "contract": BoardSession.contractVersion,
      "line": Double(BoardRoom.line), "near": Double(BoardRoom.near),
    ])
  }

  /// A board as the iPad posts it, `{"board", "strokes"}`: replaces the loaded one. The number of boxes, or -1 with
  /// nothing loaded.
  @_expose(wasm, "bw_load")
  @_cdecl("bw_load")
  public func bwLoad(_ pointer: UnsafeRawPointer?, _ length: Int32) -> Int32 {
    board = nil
    boxes = nil
    lastError = nil
    do {
      let loaded = try BoardSnapshot(json: JSONSerialization.jsonObject(with: input(pointer, length)))
      board = loaded
      return Int32(loadedBoxes(loaded).count)
    } catch {
      return failed("the board could not be read: \(error)")
    }
  }

  /// `{"strokes": [...]}`, new ink in the board's own form, added to the loaded board. The number of boxes now, or -1
  /// with the board as it was.
  @_expose(wasm, "bw_add_strokes")
  @_cdecl("bw_add_strokes")
  public func bwAddStrokes(_ pointer: UnsafeRawPointer?, _ length: Int32) -> Int32 {
    lastError = nil
    guard var loaded = board else { return failed("no board is loaded") }
    do {
      let json = try JSONSerialization.jsonObject(with: input(pointer, length)) as? [String: Any]
      guard let strokes = json?["strokes"] as? [Any] else {
        return failed("the strokes could not be read: no strokes list")
      }
      let added = try BoardSnapshot(json: ["board": loaded.board, "strokes": strokes])
      loaded.ink += added.ink
      loaded.texts += added.texts
      board = loaded
      boxes = nil
      return Int32(loadedBoxes(loaded).count)
    } catch {
      return failed("the strokes could not be read: \(error)")
    }
  }

  /// The clear line a cut at `y` lands on (`BoardRoom.cut`), or NaN with nothing loaded.
  @_expose(wasm, "bw_cut_y")
  @_cdecl("bw_cut_y")
  public func bwCutY(_ y: Double) -> Double {
    lastError = nil
    guard let loaded = board else {
      lastError = "no board is loaded"
      return .nan
    }
    return Double(BoardRoom.cut(loadedBoxes(loaded), at: CGFloat(y)))
  }

  /// Why the last call failed, as plain text, or 0 when it didn't.
  @_expose(wasm, "bw_error")
  @_cdecl("bw_error")
  public func bwError() -> UnsafeMutableRawPointer? {
    lastError.map { reply(Data($0.utf8)) }
  }

  /// For tests: a recorded session (JSONL) through the board's own replay, as the app's BoardSessionReplayTests read it.
  @_expose(wasm, "bw_replay")
  @_cdecl("bw_replay")
  public func bwReplay(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    do {
      let session = try BoardSession(jsonl: input(pointer, length))
      let report = session.replay()
      return reply(json: [
        "name": session.name, "contract": session.contract, "mismatches": report.mismatches,
        "turns": report.turns.map { turn -> [String: Any] in
          [
            "id": turn.id, "onBoard": turn.onBoard,
            "hint": turn.onBoard ? turn.hint(board: session.board, thread: session.thread) : "",
          ]
        },
        "batches": report.batches.map { batch -> [String: Any] in
          [
            "reply": batch.reply, "arrivedAt": batch.arrivedAt, "matches": batch.matches,
            "replayedOk": batch.replayed.map { $0.ok as Any } ?? NSNull(),
            "recordedOk": batch.recorded.map { $0.ok as Any } ?? NSNull(),
          ]
        },
      ])
    } catch {
      return reply(json: ["error": "the session could not be read: \(error)"])
    }
  }
#endif
