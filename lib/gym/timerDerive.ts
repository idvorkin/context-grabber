/**
 * Pure timer-state derivation. Maps an elapsed-second offset (since the timer
 * was started, with paused time already subtracted) onto the corresponding
 * phase / round / timeLeft. Used both by the live tick path and the AppState
 * foreground catch-up path so a single second of code drives both.
 *
 * Kept dependency-free so it can be unit-tested without React Native.
 */

export type Phase = "idle" | "prep" | "work" | "rest" | "done";

export interface TimerProfile {
  name: string;
  workTime: number;
  restTime: number;
  rounds: number;
  cycles: number;
  prepTime: number;
}

export type DerivedState = {
  phase: Phase;
  timeLeft: number;
  currentRound: number;
  totalElapsedSec: number;
  done: boolean;
};

export function deriveTimerState(profile: TimerProfile, elapsedSec: number): DerivedState {
  // Trailing rest after the last round is excluded — done fires the moment
  // the final work round elapses.
  const fullDurationSec =
    profile.prepTime +
    profile.workTime * profile.rounds +
    profile.restTime * Math.max(0, profile.rounds - 1);

  if (elapsedSec >= fullDurationSec) {
    return {
      phase: "done",
      timeLeft: 0,
      currentRound: profile.rounds,
      totalElapsedSec: fullDurationSec,
      done: true,
    };
  }

  let t = elapsedSec;
  if (t < profile.prepTime) {
    return {
      phase: "prep",
      timeLeft: profile.prepTime - t,
      currentRound: 1,
      totalElapsedSec: elapsedSec,
      done: false,
    };
  }
  t -= profile.prepTime;

  for (let r = 1; r <= profile.rounds; r++) {
    if (t < profile.workTime) {
      return {
        phase: "work",
        timeLeft: profile.workTime - t,
        currentRound: r,
        totalElapsedSec: elapsedSec,
        done: false,
      };
    }
    t -= profile.workTime;

    if (r < profile.rounds) {
      if (t < profile.restTime) {
        return {
          phase: "rest",
          timeLeft: profile.restTime - t,
          currentRound: r,
          totalElapsedSec: elapsedSec,
          done: false,
        };
      }
      t -= profile.restTime;
    }
  }

  // Defensive — covered by the early `done` check above.
  return {
    phase: "done",
    timeLeft: 0,
    currentRound: profile.rounds,
    totalElapsedSec: elapsedSec,
    done: true,
  };
}
