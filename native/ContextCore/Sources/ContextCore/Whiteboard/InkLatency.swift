//  Ink side by side (story 1209, bead context-grabber-vabk; spec docs/superpowers/specs/2026-11-22-ink-side-by-side-design.md):
//  one half's per-stroke lags, the readout in its corner, its pen-latency line, and the web half's probe script.
//  Story 1324 (bead context-grabber-1zgr): both halves measure the way the web board's live ink does.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

/// One stroke's lags, the web board's definition (its live ink, `liveFrame`): for every frame while the pen is down,
/// the time from the oldest touch not yet drawn to the start of the frame that draws it, in milliseconds on one
/// clock. The first frame counts from the pen-down; each later frame from the first touch since the last frame.
public struct InkStrokeLag: Equatable, Sendable {
  /// A stroke's number: the median of its frames (the web board's `l[l.length >> 1]`), its worst, and how many.
  public struct Summary: Equatable, Sendable {
    public let lag: Double
    public let lagMax: Double
    public let frames: Int

    public init(lag: Double, lagMax: Double, frames: Int) {
      self.lag = lag
      self.lagMax = lagMax
      self.frames = frames
    }
  }

  public private(set) var lags: [Double] = []
  private var undrawn: Double?

  public init(down: Double) { undrawn = down }

  /// A touch at `at` (ms): it starts the next frame's wait unless an older touch is already waiting.
  public mutating func touched(at: Double) {
    if undrawn == nil { undrawn = at }
  }

  /// A frame started at `at` (ms): it draws whatever is waiting. A frame that started before the waiting touch can't
  /// draw it (a display link's timestamp is the frame now on screen), so it neither counts nor ends the wait.
  public mutating func frame(at: Double) {
    guard let start = undrawn, at >= start else { return }
    lags.append(at - start)
    undrawn = nil
  }

  public var summary: Summary? {
    guard !lags.isEmpty else { return nil }
    let sorted = lags.sorted()
    return Summary(
      lag: InkLatency.rounded(sorted[sorted.count >> 1]), lagMax: InkLatency.rounded(sorted[sorted.count - 1]),
      frames: sorted.count)
  }
}

/// One half's strokes: each stroke's median lag and worst frame, in milliseconds.
public struct InkLatency: Equatable, Sendable {
  /// Which half: the app's own PencilKit ink, or the web board in a web view.
  public enum Side: String, Sendable {
    case native
    case web
  }

  /// A stroke outside this range is a fault in the measuring, not a stroke (spec, *What the number means*).
  public static let validRange: ClosedRange<Double> = 0...1000

  /// What `add` did with a stroke, for the log.
  public enum Outcome: Equatable, Sendable {
    case kept
    case dropped
  }

  public let side: Side
  public private(set) var strokes: [InkStrokeLag.Summary] = []
  public private(set) var dropped = 0

  public init(side: Side) { self.side = side }

  public var last: Double? { strokes.last?.lag }
  public var count: Int { strokes.count }

  /// The middle stroke's lag (the mean of the two middle ones for an even count), nil before the first.
  public var median: Double? {
    guard !strokes.isEmpty else { return nil }
    let sorted = strokes.map(\.lag).sorted()
    let mid = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
  }

  @discardableResult
  public mutating func add(_ stroke: InkStrokeLag.Summary) -> Outcome {
    guard stroke.lag.isFinite, stroke.lagMax.isFinite, Self.validRange.contains(stroke.lag),
      Self.validRange.contains(stroke.lagMax)
    else {
      dropped += 1
      return .dropped
    }
    strokes.append(stroke)
    return .kept
  }

  /// The corner's words: "Draw to measure", then "last 18 ms · median 21 ms · 12 strokes".
  public var readout: String {
    guard let last, let median else { return "Draw to measure" }
    let noun = count == 1 ? "stroke" : "strokes"
    return "last \(Self.ms(last)) ms · median \(Self.ms(median)) ms · \(count) \(noun)"
  }

  /// The session log's fields for one stroke (`ink_side_by_side`).
  public func logFields(stroke: InkStrokeLag.Summary, outcome: Outcome) -> [String: Any] {
    var fields: [String: Any] = [
      "side": side.rawValue, "ms": Self.rounded(stroke.lag), "lag_max_ms": Self.rounded(stroke.lagMax),
      "frames": stroke.frames, "kept": outcome == .kept, "n": count, "dropped": dropped,
    ]
    if let median { fields["median"] = Self.rounded(median) }
    return fields
  }

  /// This half's `board_pen_latency` line (the board's own line, story 1311, with `surface`): its strokes' p50 and p90
  /// and its slowest frame. Nil when nobody drew on it.
  public func penLatencyFields() -> [String: Any]? {
    guard let line = PenLatency.summary(strokes.map(\.lag)) else { return nil }
    return [
      "action": "board_pen_latency", "surface": side.rawValue, "measures": "oldest_undrawn_touch_to_frame",
      "count": line.count, "frames": strokes.reduce(0) { $0 + $1.frames }, "p50_ms": line.p50, "p90_ms": line.p90,
      "slowest_ms": Self.rounded(strokes.map(\.lagMax).max() ?? 0),
    ]
  }

  static func ms(_ value: Double) -> String { String(Int(value.rounded())) }
  static func rounded(_ value: Double) -> Double { value.isFinite ? (value * 10).rounded() / 10 : -1 }

  /// The web half's stroke from what the probe posts: the web board's own `lag`, `lagMax` and `frames`.
  public static func webStroke(from body: Any) -> InkStrokeLag.Summary? {
    guard let dict = body as? [String: Any], let lag = number(dict["lag"]), let lagMax = number(dict["lagMax"]) else {
      return nil
    }
    return InkStrokeLag.Summary(lag: lag, lagMax: lagMax, frames: Int(number(dict["frames"]) ?? 0))
  }

  private static func number(_ value: Any?) -> Double? {
    if let double = value as? Double { return double }
    if let int = value as? Int { return Double(int) }
    return nil
  }

  /// The name the web half's probe posts to.
  public static let messageHandler = "inkLatency"

  /// Injected into the web board at document start. It measures nothing itself: the board's live ink already times
  /// every stroke (median and worst frame lag) and logs it as a `ptr` event in `window.__ink.events`. After each
  /// pen-up the probe reads the newest events and posts each drawn stroke's numbers once. A tap that drew nothing has
  /// no `lag` and is not posted.
  public static let webProbeScript = """
    (() => {
      if (window.__inkLatencyProbe) return;
      window.__inkLatencyProbe = true;
      const posted = new WeakSet();
      const pass = () => {
        const events = window.__ink && window.__ink.events;
        if (!events) return;
        const fresh = [];
        for (let i = events.length - 1; i >= 0 && i >= events.length - 50; i--) {
          const e = events[i];
          if (posted.has(e)) break;
          if (e.k === "ptr" && e.kind === "draw" && typeof e.lag === "number") fresh.unshift(e);
        }
        for (const e of fresh) {
          posted.add(e);
          try {
            window.webkit.messageHandlers.\(messageHandler).postMessage({ lag: e.lag, lagMax: e.lagMax, frames: e.frames });
          } catch (_) {}
        }
      };
      for (const type of ["pointerup", "pointercancel"]) addEventListener(type, () => setTimeout(pass), { passive: true });
    })();
    """

  /// The web board's address on its scratch board, from the Cockpit's base address.
  public static func webBoardURL(cockpit: String) -> URL? {
    guard var parts = URLComponents(string: cockpit) else { return nil }
    let base = parts.path.hasSuffix("/") ? String(parts.path.dropLast()) : parts.path
    parts.path = base + "/ink"
    parts.queryItems = [URLQueryItem(name: "b", value: "scratch")]
    return parts.url
  }
}
