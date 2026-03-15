/**
 * Pure functions extracted from App.tsx for health data processing.
 * These are side-effect-free and testable without HealthKit or device access.
 */

import { extractSleepDetails } from "./sleep";

export type HealthData = {
  steps: number | null;
  heartRate: number | null;
  sleepHours: number | null;
  bedtime: string | null;
  wakeTime: string | null;
  activeEnergy: number | null;
  walkingDistance: number | null;
  weight: number | null;
  weightDaysLast7: number | null;
  meditationMinutes: number | null;
  hrv: number | null;
  restingHeartRate: number | null;
  exerciseMinutes: number | null;
};

export type WeightSample = {
  startDate: string | Date;
  quantity: number;
};

/**
 * Count distinct days with weight measurements from an array of samples.
 * Returns null if samples is empty or undefined.
 */
export function countWeightDays(samples: WeightSample[] | undefined): number | null {
  if (!samples || samples.length === 0) {
    return null;
  }
  const days = new Set(
    samples.map((s) => {
      const d = new Date(s.startDate);
      return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
    }),
  );
  return days.size;
}

export type SleepSample = {
  startDate: string | Date;
  endDate: string | Date;
};

export type MindfulSession = {
  startDate: string | Date;
  endDate: string | Date;
};

/**
 * Calculate total sleep hours from an array of sleep category samples.
 * Merges overlapping intervals (e.g. Watch + Phone both reporting) before summing.
 * Returns null if samples is empty or undefined.
 */
export function calculateSleepHours(samples: SleepSample[] | undefined): number | null {
  if (!samples || samples.length === 0) {
    return null;
  }
  const intervals = samples
    .map((s) => ({
      start: new Date(s.startDate).getTime(),
      end: new Date(s.endDate).getTime(),
    }))
    .filter((i) => i.end > i.start)
    .sort((a, b) => a.start - b.start);

  if (intervals.length === 0) return 0;

  const merged: { start: number; end: number }[] = [intervals[0]];
  for (let i = 1; i < intervals.length; i++) {
    const last = merged[merged.length - 1];
    if (intervals[i].start <= last.end) {
      last.end = Math.max(last.end, intervals[i].end);
    } else {
      merged.push(intervals[i]);
    }
  }

  const totalMs = merged.reduce((acc, i) => acc + (i.end - i.start), 0);
  return Math.round((totalMs / (1000 * 60 * 60)) * 10) / 10;
}

/**
 * Calculate total meditation minutes from an array of mindful session samples.
 * Returns null if sessions is empty or undefined.
 * Clamps negative durations (corrupted data) to zero.
 */
export function calculateMeditationMinutes(
  sessions: MindfulSession[] | undefined,
): number | null {
  if (!sessions || sessions.length === 0) {
    return null;
  }
  const totalMs = sessions.reduce((acc, session) => {
    const start = new Date(session.startDate).getTime();
    const end = new Date(session.endDate).getTime();
    return acc + Math.max(0, end - start);
  }, 0);
  return Math.round((totalMs / (1000 * 60)) * 10) / 10;
}

/**
 * Extract weight value from a weight sample (unit depends on HealthKit configuration).
 * Returns null if sample is null/undefined.
 */
export function extractWeight(
  sample: { quantity: number } | null | undefined,
): number | null {
  if (!sample) {
    return null;
  }
  return Math.round(sample.quantity * 100) / 100;
}

/**
 * Represents the shape of Promise.allSettled results from HealthKit queries.
 * Index 0: steps (sumQuantity), 1: heartRate (quantity), 2: activeEnergy (sumQuantity),
 * 3: walkingDistance (sumQuantity), 4: sleep (category samples array),
 * 5: weight (quantity), 6: meditation (category samples array).
 */
export type HealthQueryResults = [
  PromiseSettledResult<{ sumQuantity?: { quantity: number } | null }>,
  PromiseSettledResult<{ quantity: number } | null>,
  PromiseSettledResult<{ sumQuantity?: { quantity: number } | null }>,
  PromiseSettledResult<{ sumQuantity?: { quantity: number } | null }>,
  PromiseSettledResult<SleepSample[]>,
  PromiseSettledResult<{ quantity: number } | null>,
  PromiseSettledResult<MindfulSession[]>,
  PromiseSettledResult<WeightSample[]>,
  PromiseSettledResult<{ quantity: number } | null>,
  PromiseSettledResult<{ quantity: number } | null>,
  PromiseSettledResult<{ sumQuantity?: { quantity: number } | null }>,
];

/**
 * Build a HealthData object from Promise.allSettled results.
 * Rejected promises produce null for that metric — never throws.
 */
export function buildHealthData(results: HealthQueryResults): HealthData {
  const [steps, heartRate, activeEnergy, walkingDistance, sleep, weight, meditation, weightSamples, hrv, restingHeartRate, exerciseTime] = results;

  const sleepSamples =
    sleep.status === "fulfilled" ? sleep.value : undefined;
  const sleepHours = calculateSleepHours(sleepSamples);
  const sleepDetails = extractSleepDetails(sleepSamples);

  return {
    steps:
      steps.status === "fulfilled" && steps.value.sumQuantity?.quantity != null
        ? Math.round(steps.value.sumQuantity.quantity)
        : null,
    heartRate:
      heartRate.status === "fulfilled" && heartRate.value
        ? Math.round(heartRate.value.quantity)
        : null,
    sleepHours,
    bedtime: sleepDetails.bedtime,
    wakeTime: sleepDetails.wakeTime,
    activeEnergy:
      activeEnergy.status === "fulfilled" && activeEnergy.value.sumQuantity?.quantity != null
        ? Math.round(activeEnergy.value.sumQuantity.quantity)
        : null,
    walkingDistance:
      walkingDistance.status === "fulfilled" && walkingDistance.value.sumQuantity?.quantity != null
        ? Math.round(walkingDistance.value.sumQuantity.quantity * 100) / 100
        : null,
    weight:
      weight.status === "fulfilled"
        ? extractWeight(weight.value)
        : null,
    weightDaysLast7:
      weightSamples.status === "fulfilled"
        ? countWeightDays(weightSamples.value)
        : null,
    meditationMinutes:
      meditation.status === "fulfilled"
        ? calculateMeditationMinutes(meditation.value)
        : null,
    hrv:
      hrv.status === "fulfilled" && hrv.value
        ? Math.round(hrv.value.quantity * 10) / 10
        : null,
    restingHeartRate:
      restingHeartRate.status === "fulfilled" && restingHeartRate.value
        ? Math.round(restingHeartRate.value.quantity)
        : null,
    exerciseMinutes:
      exerciseTime.status === "fulfilled" && exerciseTime.value.sumQuantity?.quantity != null
        ? Math.round(exerciseTime.value.sumQuantity.quantity)
        : null,
  };
}
