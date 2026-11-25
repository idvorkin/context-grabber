//  Story 1324 (bead context-grabber-1zgr): Ink side by side measures both halves the way the web board's live ink
//  does: per frame, the oldest undrawn touch to the frame that draws it; per stroke, the median and worst.

import XCTest

@testable import ContextCore

#if canImport(JavaScriptCore)
  import JavaScriptCore
#endif

final class InkStrokeLagTests: XCTestCase {
  func testTheFirstFrameCountsFromThePenDownAndLaterFramesFromTheFirstMoveSince() {
    var stroke = InkStrokeLag(down: 100)
    stroke.touched(at: 104)  // a move before the first frame doesn't move the start
    stroke.frame(at: 116)  // 16 from the pen-down
    stroke.frame(at: 132)  // nothing undrawn: no sample
    stroke.touched(at: 140)
    stroke.touched(at: 145)  // only the oldest undrawn touch counts
    stroke.frame(at: 149)  // 9
    XCTAssertEqual(stroke.lags, [16, 9])
  }

  func testAStrokesNumberIsTheMedianLikeTheWebBoardsAndItsWorstFrame() throws {
    var stroke = InkStrokeLag(down: 0)
    for (touch, frame) in [(0.0, 10.04), (20, 41), (50, 58), (70, 100)] {
      stroke.touched(at: touch)
      stroke.frame(at: frame)
    }
    // sorted 8, 10.04, 21, 30: the web board takes l[n >> 1], so 21, not the mean of the middle two
    let summary = try XCTUnwrap(stroke.summary)
    XCTAssertEqual(summary, InkStrokeLag.Summary(lag: 21, lagMax: 30, frames: 4))
  }

  /// A display link's timestamp is the start of the frame now on screen, which can be earlier than a touch that
  /// arrived just after it: that frame can't draw the touch, so it neither counts nor clears the wait.
  func testAFrameThatStartedBeforeTheWaitingTouchDoesNotDrawIt() {
    var stroke = InkStrokeLag(down: 100)
    stroke.frame(at: 92)
    stroke.frame(at: 108.3)
    XCTAssertEqual(stroke.lags.map { ($0 * 10).rounded() / 10 }, [8.3])
  }

  func testAStrokeThatNeverReachedAFrameHasNoNumber() {
    XCTAssertNil(InkStrokeLag(down: 5).summary)
  }

  func testLagsRoundToATenthAsTheWebBoardsToFixedDoes() throws {
    var stroke = InkStrokeLag(down: 0)
    stroke.frame(at: 16.66)
    XCTAssertEqual(try XCTUnwrap(stroke.summary).lag, 16.7)
  }

  func testTheWebBoardsStrokeNumbersAreReadFromWhatItsProbePosts() {
    XCTAssertEqual(
      InkLatency.webStroke(from: ["lag": 18.5, "lagMax": 33.1, "frames": 12, "pointer": "pen"]),
      InkStrokeLag.Summary(lag: 18.5, lagMax: 33.1, frames: 12))
    XCTAssertEqual(
      InkLatency.webStroke(from: ["lag": 17, "lagMax": 17, "frames": 1]),
      InkStrokeLag.Summary(lag: 17, lagMax: 17, frames: 1), "a whole number comes as an Int")
    XCTAssertNil(InkLatency.webStroke(from: ["lag": "fast"]))
    XCTAssertNil(InkLatency.webStroke(from: ["frames": 3]))
    XCTAssertNil(InkLatency.webStroke(from: "not a dictionary"))
  }

  func testEachStrokeUpdatesTheCornerWithItsMedianLag() {
    var latency = InkLatency(side: .web)
    XCTAssertEqual(latency.add(InkStrokeLag.Summary(lag: 18.4, lagMax: 40, frames: 9)), .kept)
    latency.add(InkStrokeLag.Summary(lag: 30, lagMax: 31, frames: 3))
    latency.add(InkStrokeLag.Summary(lag: 21, lagMax: 25, frames: 5))
    XCTAssertEqual(latency.readout, "last 21 ms · median 21 ms · 3 strokes")
  }

  func testAStrokeLogNamesItsMedianWorstAndFrames() {
    var latency = InkLatency(side: .native)
    let stroke = InkStrokeLag.Summary(lag: 12.3, lagMax: 20.1, frames: 7)
    let outcome = latency.add(stroke)
    let fields = latency.logFields(stroke: stroke, outcome: outcome)
    XCTAssertEqual(fields["side"] as? String, "native")
    XCTAssertEqual(fields["ms"] as? Double, 12.3)
    XCTAssertEqual(fields["lag_max_ms"] as? Double, 20.1)
    XCTAssertEqual(fields["frames"] as? Int, 7)
    XCTAssertEqual(fields["n"] as? Int, 1)
    XCTAssertEqual(fields["kept"] as? Bool, true)
  }

  func testAStrokeOverASecondIsDropped() {
    var latency = InkLatency(side: .native)
    XCTAssertEqual(latency.add(InkStrokeLag.Summary(lag: 1500, lagMax: 1500, frames: 1)), .dropped)
    XCTAssertEqual(latency.count, 0)
    XCTAssertEqual(latency.dropped, 1)
  }

  func testEachHalfWritesOneBoardPenLatencyLineNamingItsSurface() throws {
    var native = InkLatency(side: .native)
    for (lag, worst, frames) in [(10.0, 15.0, 4), (20, 40, 6), (12, 13, 2)] {
      native.add(InkStrokeLag.Summary(lag: lag, lagMax: worst, frames: frames))
    }
    let line = try XCTUnwrap(native.penLatencyFields())
    XCTAssertEqual(line["action"] as? String, "board_pen_latency")
    XCTAssertEqual(line["surface"] as? String, "native")
    XCTAssertEqual(line["measures"] as? String, "oldest_undrawn_touch_to_frame")
    XCTAssertEqual(line["count"] as? Int, 3)
    XCTAssertEqual(line["frames"] as? Int, 12)
    XCTAssertEqual(line["p50_ms"] as? Double, 12)
    XCTAssertEqual(line["p90_ms"] as? Double, 20)
    XCTAssertEqual(line["slowest_ms"] as? Double, 40)
    XCTAssertNil(InkLatency(side: .web).penLatencyFields(), "a half nobody drew on writes no line")
  }

  #if canImport(JavaScriptCore)
    /// The web half passes along the web board's own per-stroke numbers: after each pen-up it reads the board's
    /// newest `ptr` events and posts each drawn stroke's lag once, and nothing for a tap that drew nothing.
    func testTheProbePostsEachDrawnStrokeTheWebBoardLoggedOnce() throws {
      let js = try XCTUnwrap(JSContext())
      var thrown: [String] = []
      js.exceptionHandler = { _, error in thrown.append(error?.toString() ?? "?") }
      js.evaluateScript(
        """
        var window = this;
        var listeners = [];
        function addEventListener(type, fn, opts) { listeners.push({ type: type, fn: fn, opts: opts }); }
        var later = [];
        function setTimeout(fn) { later.push(fn); }
        var posts = [];
        window.webkit = { messageHandlers: { "\(InkLatency.messageHandler)": { postMessage: function (m) { posts.push(m); } } } };
        window.__ink = { events: [] };
        function up(type) {
          listeners.forEach(function (l) { if (l.type === type) l.fn({ type: type, pointerType: "pen" }); });
          var due = later; later = []; due.forEach(function (f) { f(); });
        }
        function sent() { return JSON.stringify(posts.map(function (p) { return [p.lag, p.lagMax, p.frames]; })); }
        """)
      js.evaluateScript(InkLatency.webProbeScript)
      js.evaluateScript(InkLatency.webProbeScript)
      XCTAssertEqual(
        js.evaluateScript("listeners.filter(function (l) { return l.type === 'pointerup'; }).length")?.toInt32(), 1,
        "a second injection adds no second listener")

      js.evaluateScript(
        "window.__ink.events.push({ k: 'ptr', kind: 'draw', lag: 16.7, lagMax: 33.4, frames: 9 }); up('pointerup')")
      XCTAssertEqual(js.evaluateScript("sent()")?.toString(), "[[16.7,33.4,9]]")

      js.evaluateScript("window.__ink.events.push({ k: 'ptr', kind: 'tap' }); up('pointerup')")
      js.evaluateScript("up('pointerup')")
      XCTAssertEqual(
        js.evaluateScript("sent()")?.toString(), "[[16.7,33.4,9]]", "a tap, or the same stroke twice, posts nothing")

      js.evaluateScript(
        "window.__ink.events.push({ k: 'ptr', kind: 'draw', lag: 8, lagMax: 9, frames: 2 }); up('pointercancel')")
      XCTAssertEqual(js.evaluateScript("sent()")?.toString(), "[[16.7,33.4,9],[8,9,2]]")
      XCTAssertEqual(thrown, [])
    }
  #endif
}
