import {
  DEFAULT_CUSTOM,
  REST_RANGE,
  ROUNDS_RANGE,
  STEP_SECONDS,
  WORK_RANGE,
  customProfile,
  formatSeconds,
  normalizeCustom,
  snap,
} from "../lib/gym/customPreset";

describe("the Custom preset", () => {
  it("starts on 60 seconds — the 1 MIN preset's shape", () => {
    expect(DEFAULT_CUSTOM).toEqual({ work: 60, rest: 10, rounds: 5 });
    expect(normalizeCustom(null)).toEqual(DEFAULT_CUSTOM);
    expect(normalizeCustom(undefined)).toEqual(DEFAULT_CUSTOM);
  });

  it("moves in tens, inside its ranges", () => {
    expect(STEP_SECONDS).toBe(10);
    expect(snap(64, 10, WORK_RANGE)).toBe(60);
    expect(snap(66, 10, WORK_RANGE)).toBe(70);
    expect(snap(3, 10, WORK_RANGE)).toBe(WORK_RANGE.min);
    expect(snap(9999, 10, WORK_RANGE)).toBe(WORK_RANGE.max);
    expect(snap(-5, 10, REST_RANGE)).toBe(0);
    expect(normalizeCustom({ work: 95, rest: 301, rounds: 0 })).toEqual({ work: 100, rest: 300, rounds: ROUNDS_RANGE.min });
    expect(normalizeCustom({ rounds: 99 }).rounds).toBe(ROUNDS_RANGE.max);
  });

  it("runs what it says, with the ready count the fixed presets use", () => {
    expect(customProfile({ work: 40, rest: 20, rounds: 2 })).toEqual({
      name: "custom",
      workTime: 40,
      restTime: 20,
      rounds: 2,
      cycles: 1,
      prepTime: 5,
    });
    expect(customProfile({ work: 90, rest: 0, rounds: 1 }).prepTime).toBe(5);
    expect(customProfile({ work: 100, rest: 0, rounds: 1 }).prepTime).toBe(10);
  });

  it("reads as m:ss", () => {
    expect(formatSeconds(60)).toBe("1:00");
    expect(formatSeconds(0)).toBe("0:00");
    expect(formatSeconds(610)).toBe("10:10");
  });
});
