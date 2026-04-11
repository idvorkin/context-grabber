/**
 * Pure functions for extracting sleep detail metrics from HealthKit sleep samples.
 */

import type { SleepSample } from "./health";
import { filterActualSleep } from "./health";
import { formatDateKey } from "./weekly";

export type SleepDetails = {
  bedtime: string | null;
  wakeTime: string | null;
};

/** Per-night sleep breakdown with stages + timing. Used by the detailed sleep view. */
export type SleepDaily = {
  date: string; // local YYYY-MM-DD of the night (by startDate of first sample)
  totalHours: number | null; // merged core+deep+rem, matches calculateSleepHours
  coreHours: number;
  deepHours: number;
  remHours: number;
  awakeHours: number;
  bedtime: string | null; // ISO 8601 — first asleep sample start
  wakeTime: string | null; // ISO 8601 — last asleep sample end
  samples: SleepSample[]; // sorted by startTime, used by stage strip rendering
};

export type SleepConsistencyStats = {
  bedtimeStdevMinutes: number;
  wakeStdevMinutes: number;
};

export const SLEEP_STAGE_COLORS = {
  Core: "#4cc9f0",
  Deep: "#3a0ca3",
  REM: "#7209b7",
  Awake: "#8d99ae",
  InBed: "#2a2a40",
} as const;

/**
 * Extract bedtime and wake-up time from sleep category samples.
 * Sorts samples by startDate ascending, then:
 *   - bedtime = startDate of first sample (ISO 8601 UTC)
 *   - wakeTime = endDate of last sample (ISO 8601 UTC)
 * Returns { bedtime: null, wakeTime: null } if samples is empty or undefined.
 */
export function extractSleepDetails(
  samples: SleepSample[] | undefined,
): SleepDetails {
  if (!samples || samples.length === 0) {
    return { bedtime: null, wakeTime: null };
  }

  const sorted = [...samples].sort(
    (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
  );

  const bedtime = new Date(sorted[0].startDate).toISOString();
  const wakeTime = new Date(sorted[sorted.length - 1].endDate).toISOString();

  return { bedtime, wakeTime };
}

// ─── aggregateSleepDetailed ───────────────────────────────────────────────────

/**
 * Bucket raw sleep samples into per-night `SleepDaily` objects. Each bucket
 * represents one "night," defined as the noon-to-noon window starting at
 * 12:00 local on its `date`. A sample that falls anywhere in that window is
 * attributed to that night — so an 11pm-7am sleep session entirely belongs
 * to the night of the starting date, and a 3pm nap on Mar 15 belongs to
 * Mar 15's bucket.
 *
 * The noon-to-noon rule matches the existing project convention (see
 * CLAUDE.md "Sleep window is noon-to-noon — captures overnight sessions
 * correctly") and is stricter than `aggregateSleep`, which used midnight
 * cutoffs and split single sessions across two daily buckets.
 *
 * Stage hours are computed by merging overlapping intervals per stage
 * across sources (handles Watch + iPhone double-reporting). totalHours is
 * the merged duration of actual-sleep samples (Core + Deep + REM + generic
 * Asleep), excluding Awake and InBed.
 */
export function aggregateSleepDetailed(
  samples: SleepSample[] | undefined,
  endDate: Date,
  days = 7,
): SleepDaily[] {
  // Build the `days`-day window ending at endDate, aligned to local midnight.
  const buckets: SleepDaily[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(endDate);
    d.setHours(0, 0, 0, 0);
    d.setDate(d.getDate() - i);
    buckets.push({
      date: formatDateKey(d),
      totalHours: null,
      coreHours: 0,
      deepHours: 0,
      remHours: 0,
      awakeHours: 0,
      bedtime: null,
      wakeTime: null,
      samples: [],
    });
  }

  if (!samples || samples.length === 0) return buckets;

  // Assign each sample to the bucket matching the noon-to-noon window that
  // contains its start time. A sample at 01:00 local belongs to the previous
  // day's bucket; a sample at 13:00 belongs to that day's bucket.
  const bucketByDate = new Map<string, SleepDaily>();
  for (const b of buckets) bucketByDate.set(b.date, b);

  for (const s of samples) {
    const start = new Date(s.startDate);
    const nightDate = new Date(start);
    nightDate.setHours(0, 0, 0, 0);
    if (start.getHours() < 12) {
      // Pre-noon → belongs to PREVIOUS day's night
      nightDate.setDate(nightDate.getDate() - 1);
    }
    const key = formatDateKey(nightDate);
    const bucket = bucketByDate.get(key);
    if (!bucket) continue;
    bucket.samples.push(s);
  }

  // For each bucket, compute stage hours (with overlap merging per stage) and
  // bedtime / wakeTime.
  for (const bucket of buckets) {
    if (bucket.samples.length === 0) continue;

    // Sort by start time
    bucket.samples.sort(
      (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
    );

    // Bedtime/wake — earliest start, latest end across actual-sleep samples
    const actualSleep = filterActualSleep(bucket.samples);
    if (actualSleep.length > 0) {
      const sleepSorted = [...actualSleep].sort(
        (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
      );
      bucket.bedtime = new Date(sleepSorted[0].startDate).toISOString();
      const lastEnd = sleepSorted.reduce(
        (max, s) => Math.max(max, new Date(s.endDate).getTime()),
        0,
      );
      bucket.wakeTime = new Date(lastEnd).toISOString();
    }

    // Stage hours — merge overlapping intervals per-stage
    const stages = [
      { value: 3, key: "coreHours" as const },
      { value: 4, key: "deepHours" as const },
      { value: 5, key: "remHours" as const },
      { value: 2, key: "awakeHours" as const },
    ];
    for (const { value, key } of stages) {
      const stageSamples = bucket.samples.filter((s) => s.value === value);
      const hours = mergedHours(stageSamples);
      bucket[key] = Math.round(hours * 10) / 10;
    }

    // Total hours = merged core+deep+rem (matches calculateSleepHours semantics)
    const actualSleepSamples = bucket.samples.filter(
      (s) => s.value === 1 || s.value === 3 || s.value === 4 || s.value === 5,
    );
    const totalMergedHours = mergedHours(actualSleepSamples);
    bucket.totalHours = totalMergedHours > 0 ? Math.round(totalMergedHours * 10) / 10 : null;
  }

  return buckets;
}

/** Merge overlapping intervals in a sample array and return total hours. */
function mergedHours(samples: SleepSample[]): number {
  if (samples.length === 0) return 0;
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
  return totalMs / (1000 * 60 * 60);
}

// ─── computeSleepDebt ─────────────────────────────────────────────────────────

/**
 * Cumulative sleep deficit over the provided nights. Oversleep does NOT
 * reduce debt — only under-sleep contributes.
 *
 * Returns debt in HOURS. Nights with null totalHours count as zero sleep
 * (contributes full target to deficit) — conservative assumption that a
 * missing night is a tracking gap, not a night off.
 */
export function computeSleepDebt(
  nights: SleepDaily[],
  targetHours: number,
): number {
  if (targetHours <= 0 || nights.length === 0) return 0;
  let debt = 0;
  for (const n of nights) {
    const actual = n.totalHours ?? 0;
    const deficit = targetHours - actual;
    if (deficit > 0) debt += deficit;
  }
  return Math.round(debt * 10) / 10;
}

// ─── computeConsistencyStats ──────────────────────────────────────────────────

/**
 * Stdev of bedtime and wake time across nights. Handles the wrap-around case
 * (bedtimes at 11pm and 1am should be ~2h apart, not 22h) by mapping
 * timestamps to a centered-at-midnight range.
 *
 * Returns stdev in MINUTES. Returns 0 for both fields if < 2 nights with data.
 */
export function computeConsistencyStats(nights: SleepDaily[]): SleepConsistencyStats {
  const bedtimeMins: number[] = [];
  const wakeMins: number[] = [];

  for (const n of nights) {
    if (n.bedtime) {
      const d = new Date(n.bedtime);
      // Minutes from local midnight. For bedtimes, remap values <= noon to
      // +24h so a bedtime at 1am is treated as 25*60=1500, near a bedtime
      // at 11pm (1380), not 60.
      let m = d.getHours() * 60 + d.getMinutes();
      if (m <= 12 * 60) m += 24 * 60;
      bedtimeMins.push(m);
    }
    if (n.wakeTime) {
      const d = new Date(n.wakeTime);
      const m = d.getHours() * 60 + d.getMinutes();
      wakeMins.push(m);
    }
  }

  return {
    bedtimeStdevMinutes: stdev(bedtimeMins),
    wakeStdevMinutes: stdev(wakeMins),
  };
}

function stdev(values: number[]): number {
  if (values.length < 2) return 0;
  const mean = values.reduce((s, v) => s + v, 0) / values.length;
  const variance = values.reduce((s, v) => s + (v - mean) ** 2, 0) / values.length;
  return Math.round(Math.sqrt(variance));
}
