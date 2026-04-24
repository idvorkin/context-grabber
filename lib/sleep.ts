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
  /**
   * Sleep-onset latency: Awake time directly preceding the first actual-sleep
   * sample, walking backwards and stopping when the gap between one Awake
   * segment and the next exceeds `ONSET_NOISE_GAP_MS`. Awake segments that
   * are separated from sleep by a > 1h untracked gap are discarded as noise
   * (typical when a device detects bed-like activity much earlier and later
   * re-engages). `null` when there's no pre-sleep Awake at all.
   */
  onsetMinutes: number | null;
  samples: SleepSample[]; // sorted by startTime, used by stage strip rendering
};

/** Max tolerable gap between an Awake segment and the next sample still counted
 *  as part of sleep-onset latency. Beyond this, earlier Awake is "noise." */
export const ONSET_NOISE_GAP_MS = 60 * 60 * 1000; // 1 hour

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
      onsetMinutes: null,
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
    const mainSession = pickMainSleepSession(actualSleep);
    if (mainSession) {
      bucket.bedtime = new Date(mainSession.startMs).toISOString();
      bucket.wakeTime = new Date(mainSession.endMs).toISOString();
      bucket.onsetMinutes = computeOnsetMinutes(bucket.samples, mainSession.startMs);
    }

    // Stage hours — merge overlapping intervals per-stage, restricted to the
    // main session window when one exists (so noise naps / phantom afternoon
    // samples don't inflate totals or chart bar heights).
    const stages = [
      { value: 3, key: "coreHours" as const },
      { value: 4, key: "deepHours" as const },
      { value: 5, key: "remHours" as const },
      { value: 2, key: "awakeHours" as const },
    ];
    for (const { value, key } of stages) {
      const stageSamples = bucket.samples.filter((s) => s.value === value);
      const hours = mainSession
        ? mergedHoursInRange(stageSamples, mainSession.startMs, mainSession.endMs)
        : mergedHours(stageSamples);
      bucket[key] = Math.round(hours * 10) / 10;
    }

    // Total hours = merged core+deep+rem inside the main session only.
    const actualSleepSamples = bucket.samples.filter(
      (s) => s.value === 1 || s.value === 3 || s.value === 4 || s.value === 5,
    );
    const totalMergedHours = mainSession
      ? mergedHoursInRange(actualSleepSamples, mainSession.startMs, mainSession.endMs)
      : mergedHours(actualSleepSamples);
    bucket.totalHours = totalMergedHours > 0 ? Math.round(totalMergedHours * 10) / 10 : null;
  }

  return buckets;
}

/**
 * Pick the "main" overnight sleep session out of a night's actual-sleep samples
 * by clustering with the same 1-hour-gap rule used for onset-noise detection.
 * Returns `{startMs, endMs}` of the cluster with the most Core+Deep+REM merged
 * minutes (ties broken by the latest-ending cluster). Returns null when there
 * are no actual-sleep samples at all.
 *
 * This prevents noise samples — afternoon naps, early-evening bed-like Watch
 * activity that later re-engages, or mid-morning in-bed readings — from
 * inflating the night's bedtime/wakeTime range and producing phantom gap
 * warnings and oversized chart strips.
 */
export function pickMainSleepSession(
  actualSleep: SleepSample[],
): { startMs: number; endMs: number } | null {
  if (actualSleep.length === 0) return null;

  const sorted = [...actualSleep]
    .map((s) => ({
      start: new Date(s.startDate).getTime(),
      end: new Date(s.endDate).getTime(),
      value: s.value,
    }))
    .filter((s) => s.end > s.start)
    .sort((a, b) => a.start - b.start);
  if (sorted.length === 0) return null;

  // Group into clusters: consecutive samples with ≤ ONSET_NOISE_GAP_MS between
  // previous cluster end and next sample start are merged.
  type Cluster = { startMs: number; endMs: number; samples: typeof sorted };
  const clusters: Cluster[] = [];
  for (const s of sorted) {
    const last = clusters[clusters.length - 1];
    if (last && s.start - last.endMs <= ONSET_NOISE_GAP_MS) {
      last.endMs = Math.max(last.endMs, s.end);
      last.samples.push(s);
    } else {
      clusters.push({ startMs: s.start, endMs: s.end, samples: [s] });
    }
  }

  // Score a cluster by merged minutes of a given sample-value set.
  function mergedMsByValues(c: Cluster, values: Set<number>): number {
    const pool = c.samples.filter((s) => s.value !== undefined && values.has(s.value));
    if (pool.length === 0) return 0;
    const sortedPool = [...pool].sort((a, b) => a.start - b.start);
    const merged: { start: number; end: number }[] = [];
    for (const s of sortedPool) {
      const last = merged[merged.length - 1];
      if (last && s.start <= last.end) {
        last.end = Math.max(last.end, s.end);
      } else {
        merged.push({ start: s.start, end: s.end });
      }
    }
    return merged.reduce((acc, i) => acc + (i.end - i.start), 0);
  }

  // Prefer stage-typed scoring when ANY cluster has stage data — this prevents
  // a long "generic asleep" (value=1) noise blob from beating a real 2h typed
  // overnight session. Fall back to value=1 only when no cluster has stages.
  const STAGED = new Set([3, 4, 5]);
  const ANY_SLEEP = new Set([1, 3, 4, 5]);
  const anyClusterHasTyped = clusters.some((c) => mergedMsByValues(c, STAGED) > 0);
  const scoreOf = (c: Cluster): number =>
    anyClusterHasTyped ? mergedMsByValues(c, STAGED) : mergedMsByValues(c, ANY_SLEEP);

  let best = clusters[0];
  let bestMs = scoreOf(best);
  for (let i = 1; i < clusters.length; i++) {
    const c = clusters[i];
    const cMs = scoreOf(c);
    // Tie-break: prefer the most recent cluster (typical case: a user naps
    // in the afternoon then sleeps overnight — we want the overnight session).
    if (cMs > bestMs || (cMs === bestMs && c.endMs > best.endMs)) {
      best = c;
      bestMs = cMs;
    }
  }

  return { startMs: best.startMs, endMs: best.endMs };
}

/** Merge overlapping intervals clipped to [rangeStart, rangeEnd] and return total hours. */
function mergedHoursInRange(
  samples: SleepSample[],
  rangeStart: number,
  rangeEnd: number,
): number {
  if (samples.length === 0 || rangeEnd <= rangeStart) return 0;
  const clipped = samples
    .map((s) => ({
      start: Math.max(rangeStart, new Date(s.startDate).getTime()),
      end: Math.min(rangeEnd, new Date(s.endDate).getTime()),
    }))
    .filter((i) => i.end > i.start)
    .sort((a, b) => a.start - b.start);
  if (clipped.length === 0) return 0;
  const merged: { start: number; end: number }[] = [clipped[0]];
  for (let i = 1; i < clipped.length; i++) {
    const last = merged[merged.length - 1];
    if (clipped[i].start <= last.end) {
      last.end = Math.max(last.end, clipped[i].end);
    } else {
      merged.push(clipped[i]);
    }
  }
  const totalMs = merged.reduce((acc, i) => acc + (i.end - i.start), 0);
  return totalMs / (1000 * 60 * 60);
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

// ─── Multi-source bundle ──────────────────────────────────────────────────────

export const SLEEP_ALL_SOURCES = "All";

export type SleepDetailedBundle = {
  /** Per-source SleepDaily arrays, keyed by SleepSample.source. */
  bySource: Record<string, SleepDaily[]>;
  /** All sources merged (overlaps deduped). Used for the "All" tab. */
  merged: SleepDaily[];
};

/**
 * Build a `SleepDetailedBundle` from raw sleep samples: one `SleepDaily[]` per
 * distinct source plus one "merged" array with all sources combined.
 *
 * Sources that contribute zero samples in the window are omitted from
 * `bySource` (their empty result is uninteresting as a tab).
 */
export function buildSleepDetailedBundle(
  samples: SleepSample[] | undefined,
  endDate: Date,
  days = 7,
): SleepDetailedBundle {
  const merged = aggregateSleepDetailed(samples, endDate, days);
  const bySource: Record<string, SleepDaily[]> = {};
  if (!samples || samples.length === 0) return { bySource, merged };

  const sourceGroups = new Map<string, SleepSample[]>();
  for (const s of samples) {
    const src = s.source ?? "Unknown";
    const arr = sourceGroups.get(src);
    if (arr) arr.push(s);
    else sourceGroups.set(src, [s]);
  }

  for (const [source, sourceSamples] of sourceGroups) {
    bySource[source] = aggregateSleepDetailed(sourceSamples, endDate, days);
  }

  return { bySource, merged };
}

/**
 * Pick the default source tab for a bundle. Chooses the source with the most
 * stage-detailed sleep (sum of core + deep + REM hours across all nights) on
 * the theory that the sheet's purpose is stage visualization, so the default
 * should be the source that actually reports stages. Falls back to
 * `SLEEP_ALL_SOURCES` if no source reports any stage data.
 *
 * Ties break alphabetically by source name for stability.
 */
export function pickDefaultSleepSource(bundle: SleepDetailedBundle): string {
  let best: { name: string; score: number } | null = null;
  const names = Object.keys(bundle.bySource).sort();
  for (const name of names) {
    const nights = bundle.bySource[name];
    const score = nights.reduce(
      (acc, n) => acc + n.coreHours + n.deepHours + n.remHours,
      0,
    );
    if (score <= 0) continue;
    if (!best || score > best.score) {
      best = { name, score };
    }
  }
  return best ? best.name : SLEEP_ALL_SOURCES;
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

// ─── computeOnsetMinutes ──────────────────────────────────────────────────────

/**
 * Walking backwards from `firstSleepMs` through the night's samples, sum Awake
 * durations that are directly contiguous with the sleep-onset moment. A gap
 * (time with no samples) of more than `ONSET_NOISE_GAP_MS` between one Awake
 * segment and the next causes anything earlier to be dropped as noise — e.g.
 * a Watch that detected bed-like activity 3h before the real bedtime and then
 * went idle before re-engaging at actual bedtime.
 *
 * Returns total pre-sleep Awake minutes (rounded), or null when there's no
 * pre-sleep Awake at all.
 */
export function computeOnsetMinutes(
  samples: SleepSample[],
  firstSleepMs: number,
): number | null {
  if (samples.length === 0) return null;

  // Collect all Awake segments ending at or before the first sleep sample,
  // merge any overlapping ones per-segment (by start), then walk backwards.
  const awakeRanges: { start: number; end: number }[] = samples
    .filter((s) => s.value === 2)
    .map((s) => ({
      start: new Date(s.startDate).getTime(),
      end: new Date(s.endDate).getTime(),
    }))
    .filter((r) => r.end <= firstSleepMs && r.end > r.start)
    .sort((a, b) => a.start - b.start);

  if (awakeRanges.length === 0) return null;

  // Merge overlapping Awake intervals so we count time covered, not samples.
  const merged: { start: number; end: number }[] = [awakeRanges[0]];
  for (let i = 1; i < awakeRanges.length; i++) {
    const last = merged[merged.length - 1];
    if (awakeRanges[i].start <= last.end) {
      last.end = Math.max(last.end, awakeRanges[i].end);
    } else {
      merged.push(awakeRanges[i]);
    }
  }

  // Walk backwards from the first sleep moment, accepting Awake segments while
  // the gap to the next-later known time (firstSleepMs, then each accepted
  // segment's start) stays ≤ ONSET_NOISE_GAP_MS.
  let totalMs = 0;
  let cursor = firstSleepMs;
  for (let i = merged.length - 1; i >= 0; i--) {
    const seg = merged[i];
    const gapToCursor = cursor - seg.end;
    if (gapToCursor > ONSET_NOISE_GAP_MS) break; // earlier segments are noise
    totalMs += seg.end - seg.start;
    cursor = seg.start;
  }

  if (totalMs <= 0) return null;
  return Math.round(totalMs / 60000);
}

// ─── computeTrackingGap ───────────────────────────────────────────────────────

/**
 * Gap between time-in-bed (bedtime → wakeTime range) and total *covered* time
 * — i.e. time HealthKit had a sample for (actual sleep OR Awake in session).
 * Surfaces nights where the tracker genuinely dropped coverage (phone died,
 * Watch removed mid-night, Eight Sleep session aborted).
 *
 * Awake-in-bed is NOT counted as gap — it's visible as the gray segment in the
 * chart and surfaced separately via `onsetMinutes` when it's pre-sleep. That
 * way "⚠ gap" only flags missing data, not awake time that was recorded.
 *
 * Returns the gap in MINUTES (positive only) when all of these hold:
 *   - Both bedtime and wakeTime are present.
 *   - totalHours is a positive number.
 *   - The gap exceeds max(30 min, 10% of the in-bed range).
 *
 * Returns null otherwise. Heuristic — low false-positive rate at the cost of
 * occasionally missing thin gaps.
 */
export function computeTrackingGap(night: SleepDaily): number | null {
  if (!night.bedtime || !night.wakeTime) return null;
  if (night.totalHours == null || night.totalHours <= 0) return null;
  const bedMs = new Date(night.bedtime).getTime();
  const wakeMs = new Date(night.wakeTime).getTime();
  const inBedMinutes = (wakeMs - bedMs) / 60000;
  if (inBedMinutes <= 0) return null;

  // Covered time = actual sleep (Core+Deep+REM merged, i.e. totalHours)
  // + Awake time inside [bedtime, wakeTime] (the gray in-chart segments).
  const awakeInSessionMs = mergedAwakeMsInRange(night.samples, bedMs, wakeMs);
  const coveredMinutes = night.totalHours * 60 + awakeInSessionMs / 60000;

  const gapMinutes = inBedMinutes - coveredMinutes;
  const threshold = Math.max(30, inBedMinutes * 0.1);
  if (gapMinutes <= threshold) return null;
  return Math.round(gapMinutes);
}

/** Sum Awake sample time (merged overlaps) clipped to [rangeStart, rangeEnd]. */
function mergedAwakeMsInRange(
  samples: SleepSample[],
  rangeStart: number,
  rangeEnd: number,
): number {
  const clipped = samples
    .filter((s) => s.value === 2)
    .map((s) => ({
      start: Math.max(new Date(s.startDate).getTime(), rangeStart),
      end: Math.min(new Date(s.endDate).getTime(), rangeEnd),
    }))
    .filter((r) => r.end > r.start)
    .sort((a, b) => a.start - b.start);
  if (clipped.length === 0) return 0;
  const merged: { start: number; end: number }[] = [clipped[0]];
  for (let i = 1; i < clipped.length; i++) {
    const last = merged[merged.length - 1];
    if (clipped[i].start <= last.end) {
      last.end = Math.max(last.end, clipped[i].end);
    } else {
      merged.push(clipped[i]);
    }
  }
  return merged.reduce((acc, r) => acc + (r.end - r.start), 0);
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
