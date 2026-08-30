import { CALL_LOG_LINES, CALL_SEPARATOR, CallLog } from "../lib/callLog";

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
