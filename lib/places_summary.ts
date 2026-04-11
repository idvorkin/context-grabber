/**
 * Per-day places breakdown from clustering output.
 * Pure functions — no device access, fully testable.
 *
 * Produces a day-by-day accounting that splits every minute of elapsed time
 * into four buckets: stays (matched or unnamed place visits), transit (moving
 * between places), loose (GPS points exist but no stay formed), and no-data
 * (no GPS points — phone off, tracking disabled, signal lost).
 *
 * Invariant for each day:
 *   stayMinutes + transitMinutes + looseMinutes + noDataMinutes = elapsedMinutes ± 1
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
  totalStayMinutes: number; // sum of top-10 places
  transitMinutes: number; // time moving between places
  looseMinutes: number; // GPS points exist but no stay formed
  noDataMinutes: number; // no GPS points at all (phone off / tracking disabled)
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
 * Split `uncovered` time into loose (has GPS points nearby) vs no-data (silence).
 *
 * For each uncovered interval [start, end]:
 *   1. Collect raw points in [start - LOOSE_HALF_WINDOW, end + LOOSE_HALF_WINDOW].
 *   2. Group them into runs where consecutive points are <= LOOSE_MAX_GAP apart.
 *   3. Each run becomes a loose segment spanning [first - HALF, last + HALF].
 *   4. Clamp segments to [start, end], sum their lengths.
 *   5. loose = Σ segments; noData = (end - start) - loose.
 *
 * @internal exported for testing
 */
export function splitUncovered(
  uncovered: Interval[],
  rawPoints: LocationPoint[],
): { looseMs: number; noDataMs: number } {
  let looseMs = 0;
  let totalMs = 0;

  // Pre-sort points once — callers may already have sorted them, but be defensive.
  const sortedPts = [...rawPoints].sort((a, b) => a.timestamp - b.timestamp);

  for (const { start, end } of uncovered) {
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

    // Build loose segments from runs of close-together points.
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
      if (b > a) looseMs += b - a;
    }
  }

  // Safety clamp (floating-point drift).
  if (looseMs > totalMs) looseMs = totalMs;
  return { looseMs, noDataMs: totalMs - looseMs };
}

/**
 * Build a per-day summary of place visits from clustering stays + transit + raw points.
 *
 * Returns the most recent `days` days (including today), sorted most-recent first.
 * Today's elapsed is truncated at `now` rather than full 24h. Days with zero
 * activity of any kind (no stays, no transit, no raw points) are omitted to
 * avoid showing empty history from before tracking was enabled.
 */
export function buildPlacesDailySummary(
  stays: Stay[],
  transit: TransitSegment[],
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
    const covered: Interval[] = [];
    const placeMap = new Map<string, number>(); // placeId → ms
    const visits: PlaceVisitDetail[] = [];
    let stayMsTotal = 0;
    let transitMsTotal = 0;

    // Collect stays overlapping this day.
    for (const stay of stays) {
      const ov = overlapMs(dayStart, dayEnd, stay.startTime, stay.endTime);
      if (ov <= 0) continue;
      stayMsTotal += ov;
      placeMap.set(stay.placeId, (placeMap.get(stay.placeId) ?? 0) + ov);
      const clampedStart = Math.max(stay.startTime, dayStart);
      const clampedEnd = Math.min(stay.endTime, dayEnd);
      covered.push({ start: clampedStart, end: clampedEnd });
      visits.push({
        placeId: stay.placeId,
        startTime: clampedStart,
        endTime: clampedEnd,
        durationMinutes: Math.round(ov / 60000),
      });
    }

    // Collect transit overlapping this day.
    for (const t of transit) {
      const ov = overlapMs(dayStart, dayEnd, t.startTime, t.endTime);
      if (ov <= 0) continue;
      transitMsTotal += ov;
      covered.push({
        start: Math.max(t.startTime, dayStart),
        end: Math.min(t.endTime, dayEnd),
      });
    }

    // Compute uncovered intervals and split into loose vs no-data.
    const uncovered = computeUncovered(covered, dayStart, dayEnd);
    const { looseMs, noDataMs } = splitUncovered(uncovered, rawPoints);

    // Skip days with zero activity of any kind (pre-tracking history).
    const hasRawPoints = rawPoints.some(
      (p) => p.timestamp >= dayStart && p.timestamp < dayEnd,
    );
    if (stayMsTotal === 0 && transitMsTotal === 0 && !hasRawPoints) continue;

    // Round to whole minutes.
    const elapsedMin = Math.round((dayEnd - dayStart) / 60000);
    let stayMin = Math.round(stayMsTotal / 60000);
    let transitMin = Math.round(transitMsTotal / 60000);
    let looseMin = Math.round(looseMs / 60000);
    let noDataMin = Math.round(noDataMs / 60000);

    // Invariant: sum must equal elapsed ±1m. Clamp overshoot in priority
    // order (noData first, then loose) so stay/transit stay truthful.
    let delta = stayMin + transitMin + looseMin + noDataMin - elapsedMin;
    if (delta > 0) {
      const dec = Math.min(delta, noDataMin);
      noDataMin -= dec;
      delta -= dec;
    }
    if (delta > 0) {
      const dec = Math.min(delta, looseMin);
      looseMin -= dec;
      delta -= dec;
    }
    if (delta < 0) {
      // Undershoot — attribute leftover to noData (residual bucket).
      noDataMin += -delta;
    }
    if (noDataMin < 0) noDataMin = 0;
    if (looseMin < 0) looseMin = 0;

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
      totalStayMinutes,
      transitMinutes: transitMin,
      looseMinutes: looseMin,
      noDataMinutes: noDataMin,
    });
  }

  // Already in most-recent-first order due to the loop direction.
  return summaries;
}
