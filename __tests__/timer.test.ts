import { deriveTimerState, type TimerProfile } from "../lib/gym/timerDerive";

const PROFILE: TimerProfile = {
  name: "test",
  prepTime: 5,
  workTime: 30,
  restTime: 10,
  rounds: 3,
  cycles: 1,
};

describe("deriveTimerState", () => {
  test("at t=0: in prep, full prepTime left, round 1", () => {
    const d = deriveTimerState(PROFILE, 0);
    expect(d).toMatchObject({ phase: "prep", timeLeft: 5, currentRound: 1, done: false });
  });

  test("at t=4: still prep, 1s left", () => {
    expect(deriveTimerState(PROFILE, 4)).toMatchObject({
      phase: "prep",
      timeLeft: 1,
      currentRound: 1,
    });
  });

  test("at t=5: phase transitions to work round 1, 30s left", () => {
    expect(deriveTimerState(PROFILE, 5)).toMatchObject({
      phase: "work",
      timeLeft: 30,
      currentRound: 1,
    });
  });

  test("at t=34: still work round 1, 1s left", () => {
    expect(deriveTimerState(PROFILE, 34)).toMatchObject({
      phase: "work",
      timeLeft: 1,
      currentRound: 1,
    });
  });

  test("at t=35: rest round 1 begins", () => {
    expect(deriveTimerState(PROFILE, 35)).toMatchObject({
      phase: "rest",
      timeLeft: 10,
      currentRound: 1,
    });
  });

  test("at t=45: work round 2 begins", () => {
    expect(deriveTimerState(PROFILE, 45)).toMatchObject({
      phase: "work",
      timeLeft: 30,
      currentRound: 2,
    });
  });

  test("at t=85: work round 3 begins", () => {
    expect(deriveTimerState(PROFILE, 85)).toMatchObject({
      phase: "work",
      timeLeft: 30,
      currentRound: 3,
    });
  });

  test("at t=114: last second of final work round", () => {
    expect(deriveTimerState(PROFILE, 114)).toMatchObject({
      phase: "work",
      timeLeft: 1,
      currentRound: 3,
    });
  });

  test("at t=115: done — no trailing rest after the final round", () => {
    expect(deriveTimerState(PROFILE, 115)).toMatchObject({
      phase: "done",
      timeLeft: 0,
      currentRound: 3,
      done: true,
    });
  });

  test("far past end: still done, idempotent", () => {
    expect(deriveTimerState(PROFILE, 600)).toMatchObject({
      phase: "done",
      timeLeft: 0,
      done: true,
    });
  });

  test("background catch-up: skip across an entire phase boundary in one step", () => {
    // Background at t=20 (work r1, 15s left), foreground at t=50 (work r2, 25s left).
    // The hook would call deriveTimerState(profile, 50) once and the consumer
    // sees phase=work, currentRound=2 — no need to replay intermediate phases.
    const d = deriveTimerState(PROFILE, 50);
    expect(d.phase).toBe("work");
    expect(d.currentRound).toBe(2);
    expect(d.timeLeft).toBe(25);
  });
});
