/**
 * Pure functions extracted from App.tsx for health data processing.
 * These are side-effect-free and testable without HealthKit or device access.
 */

import { extractSleepDetails } from "./sleep";

export type SourceSleepSummary = {
  bedtime: string;   // ISO 8601 UTC
  wakeTime: string;  // ISO 8601 UTC
  coreHours: number;
  deepHours: number;
  remHours: number;
  awakeHours: number;
};

export type WorkoutEntry = {
  activityType: string;   // human-readable name like "Running"
  durationMinutes: number;
  energyBurned: number | null;  // kcal
  distanceKm: number | null;
};

export type HealthData = {
  steps: number | null;
  heartRate: number | null;
  sleepHours: number | null;
  bedtime: string | null;
  wakeTime: string | null;
  sleepBySource: Record<string, SourceSleepSummary> | null;
  activeEnergy: number | null;
  walkingDistance: number | null;
  weight: number | null;
  weightDaysLast7: number | null;
  meditationMinutes: number | null;
  hrv: number | null;
  restingHeartRate: number | null;
  exerciseMinutes: number | null;
  workouts: WorkoutEntry[];
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
  value?: number; // 0=InBed, 1=Asleep, 2=Awake, 3=Core, 4=Deep, 5=REM
  source?: string; // e.g. "Apple Watch", "AutoSleep"
};

// Sleep values that count as actual sleep (exclude InBed=0 and Awake=2)
const SLEEP_VALUES = new Set([1, 3, 4, 5]);

// Map HealthKit sleep value to readable category name
const SLEEP_CATEGORY_NAMES: Record<number, string> = {
  0: "InBed",
  1: "Asleep",
  2: "Awake",
  3: "Core",
  4: "Deep",
  5: "REM",
};

/**
 * Map a HealthKit sleep value number to a readable category name.
 * Returns "Unknown" for unrecognized values.
 */
export function sleepCategoryName(value: number | undefined): string {
  if (value === undefined) return "Asleep";
  return SLEEP_CATEGORY_NAMES[value] ?? "Unknown";
}

// Stage value to hours-field mapping
const STAGE_HOURS_KEY: Record<number, keyof Pick<SourceSleepSummary, "coreHours" | "deepHours" | "remHours" | "awakeHours">> = {
  2: "awakeHours",
  3: "coreHours",
  4: "deepHours",
  5: "remHours",
};

/**
 * Build a per-source sleep summary from HealthKit samples.
 * Groups samples by source, computes bedtime/wakeTime and hours per stage.
 * Returns null if samples is empty or undefined.
 */
export function buildSleepBySource(
  samples: SleepSample[] | undefined,
): Record<string, SourceSleepSummary> | null {
  if (!samples || samples.length === 0) return null;

  const bySource = new Map<string, SleepSample[]>();
  for (const s of samples) {
    const src = s.source ?? "Unknown";
    const arr = bySource.get(src);
    if (arr) arr.push(s);
    else bySource.set(src, [s]);
  }

  const result: Record<string, SourceSleepSummary> = {};
  for (const [source, sourceSamples] of bySource) {
    const sorted = [...sourceSamples].sort(
      (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
    );

    const bedtime = new Date(sorted[0].startDate).toISOString();
    const wakeTime = new Date(sorted[sorted.length - 1].endDate).toISOString();

    const summary: SourceSleepSummary = { bedtime, wakeTime, coreHours: 0, deepHours: 0, remHours: 0, awakeHours: 0 };

    for (const s of sorted) {
      const ms = Math.max(0, new Date(s.endDate).getTime() - new Date(s.startDate).getTime());
      const hours = ms / (1000 * 60 * 60);
      const key = s.value !== undefined ? STAGE_HOURS_KEY[s.value] : undefined;
      if (key) {
        summary[key] += hours;
      }
      // InBed (0), Asleep (1), and unknown values don't get their own bucket
    }

    // Round to 1 decimal
    summary.coreHours = Math.round(summary.coreHours * 10) / 10;
    summary.deepHours = Math.round(summary.deepHours * 10) / 10;
    summary.remHours = Math.round(summary.remHours * 10) / 10;
    summary.awakeHours = Math.round(summary.awakeHours * 10) / 10;

    result[source] = summary;
  }

  return result;
}

/**
 * Filter sleep samples to only actual sleep (not InBed or Awake).
 * If no samples have a value field (older data), returns all samples as-is.
 */
export function filterActualSleep(samples: SleepSample[]): SleepSample[] {
  const hasValues = samples.some((s) => s.value !== undefined);
  if (!hasValues) return samples;
  return samples.filter((s) => s.value !== undefined && SLEEP_VALUES.has(s.value));
}

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
  const sleepOnly = filterActualSleep(samples);
  if (sleepOnly.length === 0) return null;
  const intervals = sleepOnly
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
 * 5: weight (quantity), 6: meditation (mindful sessions array),
 * 7: weightSamples (weight samples array), 8: hrv (quantity),
 * 9: restingHeartRate (quantity), 10: exerciseTime (sumQuantity).
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

  const rawSleepSamples =
    sleep.status === "fulfilled" ? sleep.value : undefined;
  const sleepHours = calculateSleepHours(rawSleepSamples);
  const sleepDetails = extractSleepDetails(rawSleepSamples);

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
    sleepBySource: buildSleepBySource(rawSleepSamples),
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
    workouts: [],
  };
}

/** Map WorkoutActivityType enum value to a human-readable name. */
const WORKOUT_NAMES: Record<number, string> = {
  1: "Football", 2: "Archery", 3: "Australian Football", 4: "Badminton",
  5: "Baseball", 6: "Basketball", 7: "Bowling", 8: "Boxing", 9: "Climbing",
  10: "Cricket", 11: "Cross Training", 12: "Curling", 13: "Cycling",
  14: "Dance", 15: "Dance Training", 16: "Elliptical", 17: "Equestrian",
  18: "Fencing", 19: "Fishing", 20: "Functional Strength", 21: "Golf",
  22: "Gymnastics", 23: "Handball", 24: "Hiking", 25: "Hockey",
  26: "Hunting", 27: "Lacrosse", 28: "Martial Arts", 29: "Mind & Body",
  30: "Mixed Cardio", 31: "Paddle Sports", 32: "Play",
  33: "Stretching", 34: "Racquetball", 35: "Rowing", 36: "Rugby",
  37: "Running", 38: "Sailing", 39: "Skating", 40: "Snow Sports",
  41: "Soccer", 42: "Softball", 43: "Squash", 44: "Stair Climbing",
  45: "Surfing", 46: "Swimming", 47: "Table Tennis", 48: "Tennis",
  49: "Track & Field", 50: "Strength Training", 51: "Volleyball",
  52: "Walking", 53: "Water Fitness", 54: "Water Polo", 55: "Water Sports",
  56: "Wrestling", 57: "Yoga", 58: "Barre", 59: "Core Training",
  60: "Cross-Country Skiing", 61: "Downhill Skiing", 62: "Flexibility",
  63: "HIIT", 64: "Jump Rope", 65: "Kickboxing", 66: "Pilates",
  67: "Snowboarding", 68: "Stairs", 69: "Step Training",
  70: "Wheelchair Walk", 71: "Wheelchair Run", 72: "Tai Chi",
  73: "Mixed Cardio", 74: "Hand Cycling", 75: "Disc Sports",
  76: "Fitness Gaming", 77: "Cardio Dance", 78: "Social Dance",
  79: "Pickleball", 80: "Cooldown", 82: "Triathlon", 83: "Transition",
  84: "Underwater Diving", 3000: "Other",
};

export function workoutActivityName(typeValue: number): string {
  return WORKOUT_NAMES[typeValue] ?? `Workout ${typeValue}`;
}
