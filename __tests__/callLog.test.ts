import { CALL_LOG_LINES, CALL_SEPARATOR, CallLog, RECOVERED_HEADER } from "../lib/callLog";

describe("CallLog", () => {
  it("stamps lines relative to its start and keeps them in order", () => {
    let now = 1000;
    const log = new CallLog(() => now);
    log.add("start");
    now += 2340;
    log.add("ready");
    expect(log.all).toEqual(["+0.0s start", "+2.3s ready"]);
  });

  it("is a ring: the oldest lines fall off", () => {
    const log = new CallLog(() => 0);
    for (let i = 0; i < CALL_LOG_LINES + 5; i++) log.add(`l${i}`);
    expect(log.all).toHaveLength(CALL_LOG_LINES);
    expect(log.all[0]).toBe("+0.0s l5");
  });

  it("reset keeps every call so far, each behind a separator, and restarts the clock", () => {
    let now = 0;
    const log = new CallLog(() => now);
    log.add("a");
    now = 5000;
    log.reset();
    log.add("b");
    expect(log.all).toEqual(["+0.0s a", CALL_SEPARATOR, "+0.0s b"]);
    expect(log.current).toEqual(["+0.0s b"]);
    log.reset();
    log.add("c");
    expect(log.all).toEqual(["+0.0s a", CALL_SEPARATOR, "+0.0s b", CALL_SEPARATOR, "+0.0s c"]);
  });

  it("an empty log resets to empty, no dangling separator", () => {
    const log = new CallLog(() => 0);
    log.reset();
    expect(log.all).toEqual([]);
  });

  it("renders a header then the lines, skipping empty header values", () => {
    const log = new CallLog(() => 0);
    log.add("x");
    expect(log.render({ build: "abc", state: "live", nothing: null, blank: "" })).toBe(
      "build: abc\nstate: live\n---\n+0.0s x",
    );
  });
});

describe("the log on disk (#106)", () => {
  it("mirrors the whole text to the sink shortly after each change, debounced", () => {
    jest.useFakeTimers();
    try {
      const log = new CallLog(() => 0);
      const sink = jest.fn();
      log.attachSink(sink, 500);
      log.add("a");
      log.add("b");
      expect(sink).not.toHaveBeenCalled();
      jest.advanceTimersByTime(499);
      expect(sink).not.toHaveBeenCalled();
      jest.advanceTimersByTime(1);
      expect(sink).toHaveBeenCalledTimes(1);
      expect(sink).toHaveBeenLastCalledWith("+0.0s a\n+0.0s b");
      log.reset();
      jest.advanceTimersByTime(500);
      expect(sink).toHaveBeenLastCalledWith(`+0.0s a\n+0.0s b\n${CALL_SEPARATOR}`);
    } finally {
      jest.useRealTimers();
    }
  });

  it("a sink that throws does not take the log down", () => {
    jest.useFakeTimers();
    try {
      const log = new CallLog(() => 0);
      log.attachSink(() => {
        throw new Error("disk full");
      }, 10);
      log.add("a");
      expect(() => jest.advanceTimersByTime(10)).not.toThrow();
      expect(log.all).toEqual(["+0.0s a"]);
    } finally {
      jest.useRealTimers();
    }
  });

  it("preload puts the previous run first, under its own header, and keeps the cap", () => {
    const log = new CallLog(() => 0);
    log.add("now");
    log.preload(["+1.0s old start", "", "+2.0s old ended"]);
    expect(log.all).toEqual([RECOVERED_HEADER, "+1.0s old start", "+2.0s old ended", CALL_SEPARATOR, "+0.0s now"]);
    expect(log.current).toEqual(["+0.0s now"]);
    log.preload([]);
    expect(log.all).toHaveLength(5);
    const many = Array.from({ length: CALL_LOG_LINES + 50 }, (_, i) => `l${i}`);
    log.preload(many);
    expect(log.all.length).toBe(CALL_LOG_LINES);
    expect(log.all.at(-1)).toBe("+0.0s now");
  });
});
