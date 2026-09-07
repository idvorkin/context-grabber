import { CUE_HOLD_MS, DuckWindow, FINISH_HOLD_MS, TICK_HOLD_MS, type DuckSession } from "../lib/gym/duck";

function fakeSession() {
  const log: string[] = [];
  const session: DuckSession = {
    setDucking(on) {
      log.push(on ? "duck" : "base");
    },
    async release() {
      log.push("release");
    },
  };
  return { session, log };
}

// Drain microtasks only — under fake timers a real setTimeout never fires.
const flush = async () => {
  for (let i = 0; i < 4; i++) await Promise.resolve();
};

describe("the duck window", () => {
  beforeEach(() => jest.useFakeTimers());
  afterEach(() => jest.useRealTimers());

  it("opens on the first hold, stays open across the 3-2-1 ticks and the cue, and lets go a beat after the last", async () => {
    const { session, log } = fakeSession();
    const w = new DuckWindow(session);
    expect(w.isOpen).toBe(false);

    w.hold(); // 3
    expect(log).toEqual(["duck"]);
    jest.advanceTimersByTime(1000);
    w.hold(); // 2
    jest.advanceTimersByTime(1000);
    w.hold(); // 1
    jest.advanceTimersByTime(1000);
    w.hold(CUE_HOLD_MS); // the rest cue at 0
    expect(log).toEqual(["duck"]); // opened once, never pumped
    expect(w.isOpen).toBe(true);

    jest.advanceTimersByTime(CUE_HOLD_MS - 1);
    expect(w.isOpen).toBe(true);
    jest.advanceTimersByTime(1);
    await jest.advanceTimersByTimeAsync(0);
    await flush();
    expect(w.isOpen).toBe(false);
    expect(log).toEqual(["duck", "base", "release"]);
  });

  it("a tick's hold outlasts the second to the next tick; the finish holds longest", () => {
    expect(TICK_HOLD_MS).toBeGreaterThan(1000);
    expect(FINISH_HOLD_MS).toBeGreaterThan(CUE_HOLD_MS);
  });

  it("close now: base options and a release, once; closing a closed window does nothing", async () => {
    const { session, log } = fakeSession();
    const w = new DuckWindow(session);
    await w.close();
    expect(log).toEqual([]);
    w.hold();
    await w.close();
    expect(log).toEqual(["duck", "base", "release"]);
    jest.advanceTimersByTime(TICK_HOLD_MS * 2); // the pending timer was cancelled
    await flush();
    expect(log).toEqual(["duck", "base", "release"]);
  });

  it("forget: the timer lets go itself — base options back, no release of our own, no timer left", async () => {
    const { session, log } = fakeSession();
    const w = new DuckWindow(session);
    w.hold();
    w.forget();
    expect(w.isOpen).toBe(false);
    expect(log).toEqual(["duck", "base"]);
    jest.advanceTimersByTime(TICK_HOLD_MS * 2);
    await flush();
    expect(log).toEqual(["duck", "base"]);
    w.forget(); // idempotent
    expect(log).toEqual(["duck", "base"]);
  });
});
