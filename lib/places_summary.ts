/**
 * Per-day places breakdown from clustering output.
 * Pure functions — no device access, fully testable.
 *
 * Produces a day-by-day accounting that splits every minute of elapsed time
 * into three buckets:
 *   stay     — matched (or auto-discovered Place N) for ≥5 min
 *   transit  — GPS evidence exists, no stay formed (movement, brief stops, noise)
 *   noData   — no GPS evidence (phone off / tracking disabled / signal lost)
 *
 * Invariant for each day:
 *   stayMinutes + transitMinutes + noDataMinutes = elapsedMinutes ± 1
 *
 * Notes on the "transit" bucket:
 * - We do NOT trust clustering's TransitSegment output for accounting. That
 *   function labels every gap between stays as transit regardless of whether
 *   GPS was reporting (so an overnight "Home → Coffee" with a dead phone
 *   would naively read as 8h transit).
 * - Instead, we re-analyze every non-stay minute against the raw points and
 *   call it transit only if there's actual GPS evidence (per the loose-gap
 *   detection rules in `splitNonStay`).
 */

import type { Stay, TransitSegment } from "./clustering_v2";
import { LOOSE_MAX_GAP, LOOSE_HALF_WINDOW } from "./clustering_v2";
import type { LocationPoint } from "./clustering";
import { formatDateKey } from "./weekly";

export type PlaceVisitDetail = {
  placeId: string;
  startTime: number; // unix ms
  endTime: number; // unix ms
  durationMinutes: number;
};

export type PlaceDaySummary = {
  dateKey: string; // "YYYY-MM-DD"
  places: {
    placeId: string; // "Home", "Cafe Turko", "Place 3", etc.
    totalMinutes: number;
  }[]; // sorted by totalMinutes descending, top 10 only
  visits: PlaceVisitDetail[]; // individual visits sorted by startTime
  elapsedMinutes: number; // shown in the day header (24h or now - dayStart)
  totalStayMinutes: number; // sum of top-10 places
  transitMinutes: number; // GPS evidence outside stays
  noDataMinutes: number; // no GPS evidence anywhere
};

const DAY_MS = 24 * 60 * 60 * 1000;

function localMidnight(ts: number): number {
  const d = new Date(ts);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

function overlapMs(aStart: number, aEnd: number, bStart: number, bEnd: number): number {
  return Math.max(0, Math.min(aEnd, bEnd) - Math.max(aStart, bStart));
}

type Interval = { start: number; end: number };

/**
 * Invert a list of covered intervals against a day window, returning the
 * uncovered gaps. Assumes `covered` may overlap or be out of order; normalizes
 * via sort + merge first.
 */
function computeUncovered(covered: Interval[], dayStart: number, dayEnd: number): Interval[] {
  if (dayEnd <= dayStart) return [];
  if (covered.length === 0) return [{ start: dayStart, end: dayEnd }];

  // Clamp + sort + merge
  const clamped = covered
    .map((c) => ({ start: Math.max(c.start, dayStart), end: Math.min(c.end, dayEnd) }))
    .filter((c) => c.end > c.start)
    .sort((a, b) => a.start - b.start);

  const merged: Interval[] = [];
  for (const iv of clamped) {
    if (merged.length === 0 || iv.start > merged[merged.length - 1].end) {
      merged.push({ ...iv });
    } else {
      merged[merged.length - 1].end = Math.max(merged[merged.length - 1].end, iv.end);
    }
  }

  const uncovered: Interval[] = [];
  let cursor = dayStart;
  for (const iv of merged) {
    if (iv.start > cursor) uncovered.push({ start: cursor, end: iv.start });
    cursor = Math.max(cursor, iv.end);
  }
  if (cursor < dayEnd) uncovered.push({ start: cursor, end: dayEnd });
  return uncovered;
}

/**
 * Split non-stay time into transit (has GPS evidence) vs no-data (silence).
 *
 * For each non-stay interval [start, end]:
 *   1. Collect raw points in [start - LOOSE_HALF_WINDOW, end + LOOSE_HALF_WINDOW].
 *   2. Group into runs where consecutive points are <= LOOSE_MAX_GAP apart.
 *   3. Each run becomes a transit segment spanning [first - HALF, last + HALF].
 *   4. Clamp segments to [start, end], sum their lengths.
 *   5. transit = Σ segments; noData = (end - start) - transit.
 *
 * @internal exported for testing
 */
export function splitNonStay(
  nonStay: Interval[],
  rawPoints: LocationPoint[],
): { transitMs: number; noDataMs: number } {
  let transitMs = 0;
  let totalMs = 0;

  // Pre-sort points once — callers may already have sorted them, but be defensive.
  const sortedPts = [...rawPoints].sort((a, b) => a.timestamp - b.timestamp);

  for (const { start, end } of nonStay) {
    const ivMs = end - start;
    if (ivMs <= 0) continue;
    totalMs += ivMs;

    // Collect candidate points — those whose ±HALF_WINDOW could touch [start, end].
    const candidates: number[] = [];
    for (const p of sortedPts) {
      const t = p.timestamp;
      if (t < start - LOOSE_HALF_WINDOW) continue;
      if (t > end + LOOSE_HALF_WINDOW) break;
      candidates.push(t);
    }
    if (candidates.length === 0) continue;

    // Build transit segments from runs of close-together points.
    const segments: Interval[] = [];
    let runStart = candidates[0];
    let runEnd = candidates[0];
    for (let i = 1; i < candidates.length; i++) {
      if (candidates[i] - runEnd <= LOOSE_MAX_GAP) {
        runEnd = candidates[i];
      } else {
        segments.push({ start: runStart - LOOSE_HALF_WINDOW, end: runEnd + LOOSE_HALF_WINDOW });
        runStart = candidates[i];
        runEnd = candidates[i];
      }
    }
    segments.push({ start: runStart - LOOSE_HALF_WINDOW, end: runEnd + LOOSE_HALF_WINDOW });

    // Clamp each segment to [start, end] and sum. Segments are disjoint by construction.
    for (const seg of segments) {
      const a = Math.max(seg.start, start);
      const b = Math.min(seg.end, end);
      if (b > a) transitMs += b - a;
    }
  }

  // Safety clamp (floating-point drift).
  if (transitMs > totalMs) transitMs = totalMs;
  return { transitMs, noDataMs: totalMs - transitMs };
}

/**
 * Build a per-day summary of place visits from clustering stays + raw points.
 *
 * Returns the most recent `days` days (including today), sorted most-recent first.
 * Today's elapsed is truncated at `now` rather than full 24h. Days with zero
 * activity (no stays AND no raw points) are omitted to avoid showing empty
 * history from before tracking was enabled.
 *
 * The `transit` argument is accepted for API compatibility but unused — we
 * derive transit minutes from raw points, not from clustering's
 * `TransitSegment` output. See file header for rationale.
 */
export function buildPlacesDailySummary(
  stays: Stay[],
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  _transit: TransitSegment[],
  rawPoints: LocationPoint[],
  days: number,
  now: number = Date.now(),
): PlaceDaySummary[] {
  if (days <= 0) return [];

  const todayStart = localMidnight(now);
  const summaries: PlaceDaySummary[] = [];

  for (let i = 0; i < days; i++) {
    const dayStart = todayStart - i * DAY_MS;
    const dayEnd = Math.min(dayStart + DAY_MS, now);
    if (dayEnd <= dayStart) continue;

    const dateKey = formatDateKey(new Date(dayStart));
    const stayCovered: Interval[] = [];
    const placeMap = new Map<string, number>(); // placeId → ms
    const visits: PlaceVisitDetail[] = [];
    let stayMsTotal = 0;

    // Collect stays overlapping this day.
    for (const stay of stays) {
      const ov = overlapMs(dayStart, dayEnd, stay.startTime, stay.endTime);
      if (ov <= 0) continue;
      stayMsTotal += ov;
      placeMap.set(stay.placeId, (placeMap.get(stay.placeId) ?? 0) + ov);
      const clampedStart = Math.max(stay.startTime, dayStart);
      const clampedEnd = Math.min(stay.endTime, dayEnd);
      stayCovered.push({ start: clampedStart, end: clampedEnd });
      visits.push({
        placeId: stay.placeId,
        startTime: clampedStart,
        endTime: clampedEnd,
        durationMinutes: Math.round(ov / 60000),
      });
    }

    // All non-stay time = day window minus stay intervals.
    const nonStay = computeUncovered(stayCovered, dayStart, dayEnd);
    const { transitMs, noDataMs } = splitNonStay(nonStay, rawPoints);

    // Skip days with zero activity (pre-tracking history).
    const hasRawPoints = rawPoints.some(
      (p) => p.timestamp >= dayStart && p.timestamp < dayEnd,
    );
    if (stayMsTotal === 0 && !hasRawPoints) continue;

    // Round to whole minutes.
    const elapsedMin = Math.round((dayEnd - dayStart) / 60000);
    let stayMin = Math.round(stayMsTotal / 60000);
    let transitMin = Math.round(transitMs / 60000);
    let noDataMin = Math.round(noDataMs / 60000);

    // Invariant: stay + transit + noData = elapsed (±1m). Clamp overshoot
    // in priority order (noData first, then transit) so stay stays truthful.
    let delta = stayMin + transitMin + noDataMin - elapsedMin;
    if (delta > 0) {
      const dec = Math.min(delta, noDataMin);
      noDataMin -= dec;
      delta -= dec;
    }
    if (delta > 0) {
      const dec = Math.min(delta, transitMin);
      transitMin -= dec;
      delta -= dec;
    }
    if (delta < 0) {
      // Undershoot — attribute leftover to noData (residual bucket).
      noDataMin += -delta;
    }
    if (noDataMin < 0) noDataMin = 0;
    if (transitMin < 0) transitMin = 0;

    // Build top-10 places by minutes.
    const places = [...placeMap.entries()]
      .map(([placeId, ms]) => ({ placeId, totalMinutes: Math.round(ms / 60000) }))
      .sort((a, b) => b.totalMinutes - a.totalMinutes)
      .slice(0, 10);

    const totalStayMinutes = places.reduce((sum, p) => sum + p.totalMinutes, 0);

    visits.sort((a, b) => a.startTime - b.startTime);

    summaries.push({
      dateKey,
      places,
      visits,
      elapsedMinutes: elapsedMin,
      totalStayMinutes,
      transitMinutes: transitMin,
      noDataMinutes: noDataMin,
    });
  }

  // Already in most-recent-first order due to the loop direction.
  return summaries;
}
