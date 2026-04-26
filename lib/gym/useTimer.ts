/**
 * Wall-clock-anchored gym timer.
 *
 * State derives from `(now - startedAtMs - pausedAccumMs)` so a missed tick
 * (e.g. while the app is suspended in the background) is recovered correctly
 * the next time the app foregrounds. Also feeds an AppState listener that
 * resyncs on `active` so the Live Activity can be re-driven from JS without
 * waiting for the next setInterval tick.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { AppState } from "react-native";
import { useAudio } from "./useAudio";
import { audioService } from "./audioService";
import { startTimerKeepalive, stopTimerKeepalive } from "./keepalive";
import {
  deriveTimerState,
  type DerivedState,
  type Phase,
  type TimerProfile,
} from "./timerDerive";

export type { DerivedState, Phase, TimerProfile } from "./timerDerive";

export interface TimerState {
  isRunning: boolean;
  isPaused: boolean;
  phase: Phase;
  timeLeft: number;
  currentRound: number;
  totalRounds: number;
  totalElapsed: number;
}

const DEFAULT_STATE: TimerState = {
  isRunning: false,
  isPaused: false,
  phase: "idle",
  timeLeft: 0,
  currentRound: 1,
  totalRounds: 6,
  totalElapsed: 0,
};

export function useTimer(profile: TimerProfile) {
  const [state, setState] = useState<TimerState>({
    ...DEFAULT_STATE,
    totalRounds: profile.rounds,
  });

  // Wall-clock anchors. `null` means timer hasn't been started since last reset.
  const startedAtMsRef = useRef<number | null>(null);
  // Total ms accumulated while paused (subtract from wall elapsed).
  const pausedAccumMsRef = useRef<number>(0);
  // When pause began (null while running or before first start).
  const pausedAtMsRef = useRef<number | null>(null);

  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const stateRef = useRef(state);
  const profileRef = useRef(profile);
  const lastPhaseRef = useRef<Phase>("idle");
  const lastTimeLeftRef = useRef<number>(0);

  useEffect(() => { stateRef.current = state; });
  useEffect(() => { profileRef.current = profile; });

  const { playStartBeep, playEndBeep, playCountdownBeep, playFinishBeep } = useAudio();

  const calculateTotalTime = useCallback(() => {
    return ((profile.workTime + profile.restTime) * profile.rounds * profile.cycles) + profile.prepTime;
  }, [profile]);

  const clearInterval_ = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);

  /** Apply derived state at the current wall-clock moment.
   *  Plays cues for phase transitions and the final-3 countdown that
   *  occurred since the previous tick.
   *  Returns the just-derived state.
   */
  const applyDerived = useCallback((opts?: { silent?: boolean }): DerivedState | null => {
    const startedAt = startedAtMsRef.current;
    if (startedAt == null) return null;
    const wallNow = Date.now();
    const wallElapsedMs =
      pausedAtMsRef.current != null
        ? pausedAtMsRef.current - startedAt - pausedAccumMsRef.current
        : wallNow - startedAt - pausedAccumMsRef.current;
    const elapsedSec = Math.max(0, Math.floor(wallElapsedMs / 1000));
    const d = deriveTimerState(profileRef.current, elapsedSec);

    const prevPhase = lastPhaseRef.current;
    const prevTimeLeft = lastTimeLeftRef.current;

    // Audio cues — only when not silent (silent path is for catch-up after
    // background, where we don't want to spam beeps post-hoc).
    if (!opts?.silent) {
      // Final-3 tick cue: when timeLeft just dropped through 3 / 2 / 1.
      if (
        d.phase !== "idle" &&
        d.phase !== "done" &&
        d.timeLeft <= 3 &&
        d.timeLeft > 0 &&
        d.timeLeft !== prevTimeLeft
      ) {
        playCountdownBeep();
      }
      if (d.phase !== prevPhase) {
        if (d.phase === "work") {
          playStartBeep();
        } else if (d.phase === "rest") {
          playEndBeep();
        } else if (d.phase === "done") {
          playEndBeep();
          playFinishBeep();
        }
      }
    }

    lastPhaseRef.current = d.phase;
    lastTimeLeftRef.current = d.timeLeft;

    const next: TimerState = {
      isRunning: !d.done && pausedAtMsRef.current == null,
      isPaused: pausedAtMsRef.current != null,
      phase: d.phase,
      timeLeft: d.timeLeft,
      currentRound: d.currentRound,
      totalRounds: profileRef.current.rounds,
      totalElapsed: d.totalElapsedSec,
    };

    if (d.done) {
      clearInterval_();
      stopTimerKeepalive();
    }

    stateRef.current = next;
    setState(next);
    return d;
  }, [playStartBeep, playEndBeep, playCountdownBeep, playFinishBeep, clearInterval_]);

  const tick = useCallback(() => {
    if (pausedAtMsRef.current != null) return;
    if (startedAtMsRef.current == null) return;
    applyDerived();
  }, [applyDerived]);

  const reset = useCallback(() => {
    clearInterval_();
    stopTimerKeepalive();
    startedAtMsRef.current = null;
    pausedAccumMsRef.current = 0;
    pausedAtMsRef.current = null;
    lastPhaseRef.current = "idle";
    lastTimeLeftRef.current = 0;
    const newState = { ...DEFAULT_STATE, totalRounds: profileRef.current.rounds };
    stateRef.current = newState;
    setState(newState);
  }, [clearInterval_]);

  const start = useCallback(() => {
    audioService.ensureRunning();
    void startTimerKeepalive();

    const wasPaused = pausedAtMsRef.current != null;
    if (wasPaused) {
      // Resume from pause: extend the paused-accum window.
      const pausedMs = Date.now() - pausedAtMsRef.current!;
      pausedAccumMsRef.current += pausedMs;
      pausedAtMsRef.current = null;
    } else {
      // Fresh start.
      startedAtMsRef.current = Date.now();
      pausedAccumMsRef.current = 0;
      pausedAtMsRef.current = null;
      lastPhaseRef.current = "idle";
      lastTimeLeftRef.current = profileRef.current.prepTime;
      playStartBeep();
    }

    clearInterval_();
    intervalRef.current = setInterval(tick, 1000);
    // Apply once immediately so UI / LA reflect the new state without waiting.
    applyDerived({ silent: wasPaused });
  }, [playStartBeep, tick, clearInterval_, applyDerived]);

  const pause = useCallback(() => {
    clearInterval_();
    if (pausedAtMsRef.current == null) {
      pausedAtMsRef.current = Date.now();
    }
    const next = { ...stateRef.current, isRunning: false, isPaused: true };
    stateRef.current = next;
    setState(next);
  }, [clearInterval_]);

  const toggle = useCallback(() => {
    if (stateRef.current.isRunning) pause();
    else start();
  }, [start, pause]);

  // Cleanup on unmount.
  useEffect(() => () => {
    clearInterval_();
    stopTimerKeepalive();
  }, [clearInterval_]);

  // AppState catch-up: when the app comes back to the foreground while the
  // timer is running, recompute state silently from the wall-clock so we
  // don't lag behind missed ticks.
  useEffect(() => {
    const sub = AppState.addEventListener("change", (s) => {
      if (s !== "active") return;
      if (startedAtMsRef.current == null) return;
      if (pausedAtMsRef.current != null) return;
      // Silent catch-up: don't replay beeps for ticks we missed.
      applyDerived({ silent: true });
    });
    return () => sub.remove();
  }, [applyDerived]);

  // Profile rounds change while idle: reflect new rounds in the visible state.
  useEffect(() => {
    if (!state.isRunning && !state.isPaused && state.phase === "idle") {
      setState(prev => ({ ...prev, totalRounds: profile.rounds }));
    }
  }, [profile.rounds, state.isRunning, state.isPaused, state.phase]);

  return { state, profile, start, pause, toggle, reset, calculateTotalTime };
}
