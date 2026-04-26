/**
 * Data layer for the 7-day metric detail feature.
 * Pure functions — no device/HealthKit access, fully testable.
 */

import { calculateSleepHours, type SleepSample, type MindfulSession } from "./health";

// ─── Types & Config ───────────────────────────────────────────────────────────

export type MetricKey =
  | "steps"
  | "heartRate"
  | "sleep"
  | "activeEnergy"
  | "walkingDistance"
  | "weight"
  | "meditation"
  | "hrv"
  | "restingHeartRate"
  | "exerciseMinutes"
  | "movement";

export type ChartType = "bar" | "line";

export type MetricConfig = {
  label: string;
  unit: string;
  color: string;
  chartType: ChartType;
  sublabel: string;
};

export const METRIC_CONFIG: Record<MetricKey, MetricConfig> = {
  steps: { label: "Steps", unit: "steps", color: "#4cc9f0", chartType: "bar", sublabel: "today" },
  heartRate: { label: "Heart Rate", unit: "bpm", color: "#f72585", chartType: "line", sublabel: "latest" },
  sleep: { label: "Sleep", unit: "hrs", color: "#7b2cbf", chartType: "bar", sublabel: "last night" },
  activeEnergy: { label: "Active Energy", unit: "kcal", color: "#ff9e00", chartType: "bar", sublabel: "today" },
  walkingDistance: { label: "Walking Distance", unit: "km", color: "#06d6a0", chartType: "bar", sublabel: "today" },
  weight: { label: "Weight", unit: "lbs", color: "#4895ef", chartType: "line", sublabel: "latest" },
  meditation: { label: "Meditation", unit: "min", color: "#e0aaff", chartType: "bar", sublabel: "today" },
  hrv: { label: "HRV", unit: "ms", color: "#48bfe3", chartType: "line", sublabel: "latest" },
  restingHeartRate: { label: "Resting HR", unit: "bpm", color: "#f4845f", chartType: "line", sublabel: "latest" },
  exerciseMinutes: { label: "Exercise", unit: "min", color: "#57cc99", chartType: "bar", sublabel: "today" },
  // Composite metric: merges steps + walkingDistance + activeEnergy. The card
  // shows steps as the big number with a "<distance> · <energy>" subtext; the
  // detail sheet renders a normalized 3-series overlay line chart.
  movement: { label: "Movement", unit: "", color: "#4cc9f0", chartType: "line", sublabel: "today" },
};

/** A single-value day bucket (used by most metrics). */
export type DailyValue = {
  date: string; // "YYYY-MM-DD"
  value: number | null;
};

/** Single timestamped reading. */
export type TimedReading = { value: number; time: string };

/** Heart-rate day bucket with box-and-whisker stats. */
export type HeartRateDaily = {
  date: string;
  avg: number | null;
  min: number | null;
  max: number | null;
  q1: number | null;
  median: number | null;
  q3: number | null;
  count: number;
  /** All individual readings for the day (sorted by value ascending). */
  raw: TimedReading[];
};

// ─── formatDateKey ────────────────────────────────────────────────────────────

/**
 * Format a Date as "YYYY-MM-DD" using LOCAL time (not UTC).
 * Uses getFullYear / getMonth / getDate — NOT toISOString().
 */
export function formatDateKey(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

// ─── bucketByDay ──────────────────────────────────────────────────────────────

type HasStartDate = { startDate: Date | string };

/**
 * Generic day-bucketing: distributes samples into `days` buckets ending at
 * `endDate` (inclusive). Buckets are keyed by local-time date ("YYYY-MM-DD").
 * Days with no samples get `value: null`.
 *
 * @param samples   Array of objects with a `startDate` field.
 * @param endDate   The last (most recent) day to include.
 * @param days      Number of days in the window (7 means today + 6 prior days).
 * @param aggregate Called with all samples for a bucket; return the aggregated
 *                  value, or null if the bucket should be empty.
 */
export function bucketByDay<T extends HasStartDate>(
  samples: T[],
  endDate: Date,
  days: number,
  aggregate: (samples: T[]) => number | null,
): DailyValue[] {
  // Build the ordered list of date keys for the window.
  const buckets: DailyValue[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(endDate);
    d.setDate(d.getDate() - i);
    buckets.push({ date: formatDateKey(d), value: null });
  }

  // Build a set of valid keys for fast lookup.
  const keySet = new Set(buckets.map((b) => b.date));

  // Group samples by their local-time date key.
  const grouped = new Map<string, T[]>();
  for (const sample of samples) {
    const key = formatDateKey(new Date(sample.startDate));
    if (!keySet.has(key)) continue;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key)!.push(sample);
  }

  // Aggregate each bucket.
  for (const bucket of buckets) {
    const daySamples = grouped.get(bucket.date);
    if (daySamples && daySamples.length > 0) {
      bucket.value = aggregate(daySamples);
    }
  }

  return buckets;
}

// ─── computeAverage ───────────────────────────────────────────────────────────

/**
 * Days between today (local) and the most recent DailyValue with a positive
 * value. Returns 0 if today is the latest, 1 if yesterday, etc. Returns null
 * when the array is empty / undefined or contains no positive entries — the
 * caller decides what "no data in the window" should display.
 */
export function daysSinceLastDailyValue(
  values: DailyValue[] | undefined | null,
  now: Date = new Date(),
): number | null {
  if (!values || values.length === 0) return null;
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  // Walk newest-first so the first hit wins.
  for (let i = values.length - 1; i >= 0; i--) {
    const v = values[i].value;
    if (v == null || v <= 0) continue;
    const [y, m, d] = values[i].date.split("-").map(Number);
    const that = new Date(y, m - 1, d).getTime();
    return Math.round((today - that) / 86400000);
  }
  return null;
}

/**
 * Average non-null values in a DailyValue array, rounded to 1 decimal.
 * Returns null when there are no non-null values.
 */
export function computeAverage(values: DailyValue[]): number | null {
  const nonNull = values.filter((v) => v.value !== null) as Array<DailyValue & { value: number }>;
  if (nonNull.length === 0) return null;
  const sum = nonNull.reduce((acc, v) => acc + v.value, 0);
  return Math.round((sum / nonNull.length) * 10) / 10;
}

// ─── aggregateHeartRate ───────────────────────────────────────────────────────

type HRSample = { startDate: Date | string; quantity: number };

/**
 * Compute daily box-and-whisker stats over a `days`-day window ending at `endDate`.
 */
export function aggregateHeartRate(
  samples: HRSample[],
  endDate: Date,
  days = 7,
): HeartRateDaily[] {
  // Build ordered bucket list.
  const results: HeartRateDaily[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(endDate);
    d.setDate(d.getDate() - i);
    results.push({ date: formatDateKey(d), avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] });
  }

  const keySet = new Set(results.map((r) => r.date));

  // Group samples by day.
  const grouped = new Map<string, TimedReading[]>();
  for (const sample of samples) {
    const dt = new Date(sample.startDate);
    const key = formatDateKey(dt);
    if (!keySet.has(key)) continue;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key)!.push({ value: sample.quantity, time: dt.toISOString() });
  }

  // Fill in stats.
  for (const bucket of results) {
    const readings = grouped.get(bucket.date);
    if (!readings || readings.length === 0) continue;
    const sorted = [...readings].sort((a, b) => a.value - b.value);
    const vals = sorted.map((r) => r.value);
    const sum = vals.reduce((a, v) => a + v, 0);
    bucket.count = vals.length;
    bucket.avg = Math.round((sum / vals.length) * 10) / 10;
    bucket.min = vals[0];
    bucket.max = vals[vals.length - 1];
    bucket.median = quantile(vals, 0.5);
    bucket.q1 = quantile(vals, 0.25);
    bucket.q3 = quantile(vals, 0.75);
    bucket.raw = sorted;
  }

  return results;
}

/** Linear interpolation percentile (R-7 method). */
function quantile(sorted: number[], p: number): number {
  if (sorted.length === 1) return sorted[0];
  const idx = p * (sorted.length - 1);
  const lo = Math.floor(idx);
  const hi = Math.ceil(idx);
  if (lo === hi) return sorted[lo];
  return Math.round((sorted[lo] + (idx - lo) * (sorted[hi] - sorted[lo])) * 10) / 10;
}

// ─── aggregateSleep ───────────────────────────────────────────────────────────

/**
 * Aggregate per-night sleep hours over a `days`-day window ending at `endDate`.
 *
 * Sleep is assigned to the LOCAL date of its `startDate`. All samples sharing
 * the same start-date bucket are merged with `calculateSleepHours` to handle
 * overlapping sources (Watch + iPhone).
 */
export function aggregateSleep(
  samples: SleepSample[],
  endDate: Date,
  days = 7,
): DailyValue[] {
  return bucketByDay<SleepSample>(
    samples,
    endDate,
    days,
    (daySamples) => calculateSleepHours(daySamples),
  );
}

// ─── aggregateMeditation ─────────────────────────────────────────────────────

/**
 * Aggregate meditation minutes per day over a `days`-day window ending at `endDate`.
 *
 * Multiple sessions on the same day are summed. Negative durations are clamped to 0.
 * Does NOT merge overlapping sessions (meditation sessions don't typically overlap).
 */
export function aggregateMeditation(
  sessions: MindfulSession[],
  endDate: Date,
  days = 7,
): DailyValue[] {
  return bucketByDay<MindfulSession>(
    sessions,
    endDate,
    days,
    (daySessions) => {
      const totalMs = daySessions.reduce((acc, s) => {
        const start = new Date(s.startDate).getTime();
        const end = new Date(s.endDate).getTime();
        return acc + Math.max(0, end - start);
      }, 0);
      return Math.round((totalMs / (1000 * 60)) * 10) / 10;
    },
  );
}

// ─── pickLatestPerDay ─────────────────────────────────────────────────────────

type QuantitySample = { startDate: Date | string; quantity: number };

/**
 * For weight: pick the latest reading per day in a `days`-day window ending
 * at `endDate`. Values are rounded to 2 decimal places.
 */
export function pickLatestPerDay(
  samples: QuantitySample[],
  endDate: Date,
  days = 7,
): DailyValue[] {
  // Build ordered bucket list.
  const results: DailyValue[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(endDate);
    d.setDate(d.getDate() - i);
    results.push({ date: formatDateKey(d), value: null });
  }

  const keySet = new Set(results.map((r) => r.date));

  // Group samples by day, keeping track of latest timestamp.
  const latestByDay = new Map<string, { ts: number; quantity: number }>();
  for (const sample of samples) {
    const d = new Date(sample.startDate);
    const key = formatDateKey(d);
    if (!keySet.has(key)) continue;
    const ts = d.getTime();
    const existing = latestByDay.get(key);
    if (!existing || ts > existing.ts) {
      latestByDay.set(key, { ts, quantity: sample.quantity });
    }
  }

  for (const bucket of results) {
    const entry = latestByDay.get(bucket.date);
    if (entry != null) {
      bucket.value = Math.round(entry.quantity * 100) / 100;
    }
  }

  return results;
}

// ─── Movement (composite) ─────────────────────────────────────────────────────

/** Per-day absolute values for the three movement metrics. */
export type MovementSeriesDay = {
  dateKey: string; // "YYYY-MM-DD"
  steps: number | null;
  distanceKm: number | null;
  energyKcal: number | null;
};

/**
 * Normalized overlay data for the Movement metric's detail chart. Each series
 * is scaled to its own 7-day max so all three fit on a shared 0–1 Y axis.
 */
export type MovementOverlayData = {
  days: MovementSeriesDay[]; // sorted ascending by date (oldest first)
  stepsMax: number;
  distanceMax: number;
  energyMax: number;
  /** Same order as `days`. Values in [0, 1] or null. */
  stepsNormalized: (number | null)[];
  distanceNormalized: (number | null)[];
  energyNormalized: (number | null)[];
};

function seriesMax(values: (number | null)[]): number {
  let max = 0;
  for (const v of values) {
    if (v !== null && v > max) max = v;
  }
  return max;
}

function normalizeSeries(values: (number | null)[], max: number): (number | null)[] {
  const denom = max > 0 ? max : 1;
  return values.map((v) => (v === null ? null : v / denom));
}

/**
 * Build a normalized 3-series overlay from the three underlying daily arrays.
 *
 * All three inputs are expected to cover the same date range in the same
 * order (the existing `bucketByDay` pipeline produces them in aligned order).
 * Missing days in any series stay null and render as gaps in the line.
 */
export function buildMovementOverlay(
  stepsDaily: DailyValue[],
  distanceDaily: DailyValue[],
  energyDaily: DailyValue[],
): MovementOverlayData {
  // Align by date key. Use steps as the source of truth for the date list
  // (all three should be same length from bucketByDay, but be defensive).
  const dateKeys = stepsDaily.map((d) => d.date);
  const byDate = <T extends DailyValue>(series: T[]): Map<string, number | null> => {
    const m = new Map<string, number | null>();
    for (const d of series) m.set(d.date, d.value);
    return m;
  };
  const distMap = byDate(distanceDaily);
  const energyMap = byDate(energyDaily);

  const days: MovementSeriesDay[] = dateKeys.map((dateKey, i) => ({
    dateKey,
    steps: stepsDaily[i].value,
    distanceKm: distMap.get(dateKey) ?? null,
    energyKcal: energyMap.get(dateKey) ?? null,
  }));

  const stepsValues = days.map((d) => d.steps);
  const distanceValues = days.map((d) => d.distanceKm);
  const energyValues = days.map((d) => d.energyKcal);

  const stepsMax = seriesMax(stepsValues);
  const distanceMax = seriesMax(distanceValues);
  const energyMax = seriesMax(energyValues);

  return {
    days,
    stepsMax,
    distanceMax,
    energyMax,
    stepsNormalized: normalizeSeries(stepsValues, stepsMax),
    distanceNormalized: normalizeSeries(distanceValues, distanceMax),
    energyNormalized: normalizeSeries(energyValues, energyMax),
  };
}
