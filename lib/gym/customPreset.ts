/**
 * The Gym Timer's Custom preset: a work time in ten-second steps, a rest
 * time, a round count — remembered across launches, untouched by RESET.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-custom-preset-design.md
 *
 * Pure; the remembering is customPresetStorage.ts.
 */
import type { TimerProfile } from "./timerDerive";

export const CUSTOM_PRESET_ID = "custom";
export const STEP_SECONDS = 10;

export type CustomPreset = {
  /** Seconds of work per round. */
  work: number;
  /** Seconds of rest between rounds; 0 for none. */
  rest: number;
  rounds: number;
};

export const WORK_RANGE = { min: 10, max: 600 } as const;
export const REST_RANGE = { min: 0, max: 300 } as const;
export const ROUNDS_RANGE = { min: 1, max: 20 } as const;

/** A fresh Custom is the 1 MIN preset's shape: "starting on 60s". */
export const DEFAULT_CUSTOM: CustomPreset = { work: 60, rest: 10, rounds: 5 };

/** The nearest step inside the range. */
export function snap(value: number, step: number, range: { min: number; max: number }): number {
  const clamped = Math.min(range.max, Math.max(range.min, value));
  return Math.round(clamped / step) * step;
}

/** A preset with every value on its grid and in its range. */
export function normalizeCustom(p: Partial<CustomPreset> | null | undefined): CustomPreset {
  return {
    work: snap(p?.work ?? DEFAULT_CUSTOM.work, STEP_SECONDS, WORK_RANGE),
    rest: snap(p?.rest ?? DEFAULT_CUSTOM.rest, STEP_SECONDS, REST_RANGE),
    rounds: snap(p?.rounds ?? DEFAULT_CUSTOM.rounds, 1, ROUNDS_RANGE),
  };
}

/** What the timer runs. The ready count is 5 s up to a minute and a half, 10 s beyond, as the fixed presets do. */
export function customProfile(p: CustomPreset): TimerProfile {
  return {
    name: CUSTOM_PRESET_ID,
    workTime: p.work,
    restTime: p.rest,
    rounds: p.rounds,
    cycles: 1,
    prepTime: p.work > 90 ? 10 : 5,
  };
}

/** `m:ss` for a slider's label. */
export function formatSeconds(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}
