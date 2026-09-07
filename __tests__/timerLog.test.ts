import { TIMER_LOG_LINES, TimerLog } from "../lib/gym/timerLog";

describe("the timer log", () => {
  it("stamps lines with seconds since it began and renders them under a header", () => {
    let t = 1_000_000;
    const log = new TimerLog(() => t);
    expect(log.render()).toBe("(nothing logged yet)");
    log.add("session: playback [mixWithOthers]");
    t += 2_350;
    log.add("window open");
    expect(log.render({ build: "abc123 (main)", mode: "rounds" })).toBe(
      ["build: abc123 (main)", "mode: rounds", "", "+0.0s session: playback [mixWithOthers]", "+2.4s window open"].join("\n"),
    );
  });

  it("keeps only the last few hundred lines", () => {
    const log = new TimerLog(() => 0);
    for (let i = 0; i < TIMER_LOG_LINES + 25; i++) log.add(`line ${i}`);
    expect(log.length).toBe(TIMER_LOG_LINES);
    expect(log.render().split("\n")[0]).toBe("+0.0s line 25");
  });

  it("clear starts the clock again", () => {
    let t = 0;
    const log = new TimerLog(() => t);
    log.add("a");
    t = 5_000;
    log.clear();
    log.add("b");
    expect(log.render()).toBe("+0.0s b");
  });
});
