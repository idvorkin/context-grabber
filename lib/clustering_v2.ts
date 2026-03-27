/**
 * Temporal stay-detection location clustering (v2).
 * Walks through GPS points in time order, detecting stationary periods ("stays")
 * rather than spatially clustering points. O(n log n) due to sort, O(n) for everything else.
 *
 * Pure functions — no device access, fully testable.
 */

import type { LocationPoint } from "./clustering";
import { formatLocalTime } from "./clustering";
import type { KnownPlace } from "./places";
import { labelPointsWithKnownPlaces } from "./places";
import { haversineDistance } from "./geo";

// ─── Parameters ──────────────────────────────────────────────────────────────

const STAY_RADIUS = 100; // meters
const MIN_STAY_DURATION = 5 * 60 * 1000; // 5 minutes in ms
const MAX_POINT_GAP = 4 * 60 * 60 * 1000; // 4 hours in ms
const MERGE_GAP = 30 * 60 * 1000; // 30 minutes in ms
const MIN_TRANSIT_SUMMARY = 60 * 60 * 1000; // 1 hour in ms
const RECENT_DAYS = 3;

// ─── Types ───────────────────────────────────────────────────────────────────

export type Stay = {
  placeId: string;
  centroid: { latitude: number; longitude: number };
  startTime: number; // UTC ms
  endTime: number; // UTC ms
  durationMinutes: number;
  pointCount: number;
};

export type TransitSegment = {
  startTime: number;
  endTime: number;
  durationMinutes: number;
  distanceKm: number;
  fromPlaceId: string;
  toPlaceId: string;
};

export type ClusterResultV2 = {
  stays: Stay[];
  transit: TransitSegment[];
  summaryRecent: string;
  summaryWeekly: string;
};

// ─── Internal Types ──────────────────────────────────────────────────────────

type RawStay = {
  centroidLat: number;
  centroidLng: number;
  startTime: number;
  endTime: number;
  pointCount: number;
  knownPlaceLabel: number; // index into knownPlaces, or -1
};

type DiscoveredPlace = {
  id: string;
  centroidLat: number;
  centroidLng: number;
  stayCount: number; // for rolling centroid average
};

// ─── Step 2: Stationary Detection ────────────────────────────────────────────

function detectStays(
  points: LocationPoint[],
  knownLabels: number[],
): RawStay[] {
  if (points.length === 0) return [];

  const stays: RawStay[] = [];

  // Current candidate stay state
  let anchorLat = points[0].latitude;
  let anchorLng = points[0].longitude;
  let stayStart = points[0].timestamp;
  let stayEnd = points[0].timestamp;
  let pointCount = 1;
  let currentKnownLabel = knownLabels[0];

  function finalizeCurrent() {
    const duration = stayEnd - stayStart;
    if (duration >= MIN_STAY_DURATION) {
      stays.push({
        centroidLat: anchorLat,
        centroidLng: anchorLng,
        startTime: stayStart,
        endTime: stayEnd,
        pointCount,
        knownPlaceLabel: currentKnownLabel,
      });
    }
  }

  function startNew(idx: number) {
    anchorLat = points[idx].latitude;
    anchorLng = points[idx].longitude;
    stayStart = points[idx].timestamp;
    stayEnd = points[idx].timestamp;
    pointCount = 1;
    currentKnownLabel = knownLabels[idx];
  }

  for (let i = 1; i < points.length; i++) {
    const p = points[i];
    const gap = p.timestamp - stayEnd;
    const dist = haversineDistance(anchorLat, anchorLng, p.latitude, p.longitude);
    const labelChanged = knownLabels[i] !== -1 && currentKnownLabel !== -1 && knownLabels[i] !== currentKnownLabel;

    // Known place label change forces a boundary even within STAY_RADIUS
    if (labelChanged) {
      finalizeCurrent();
      startNew(i);
      continue;
    }

    if (gap > MAX_POINT_GAP) {
      if (dist <= STAY_RADIUS && !labelChanged) {
        // Still at same place after long gap — extend the stay
        pointCount++;
        stayEnd = p.timestamp;
        // Update centroid incrementally
        anchorLat = (anchorLat * (pointCount - 1) + p.latitude) / pointCount;
        anchorLng = (anchorLng * (pointCount - 1) + p.longitude) / pointCount;
        // Update known label if current is unresolved
        if (currentKnownLabel === -1 && knownLabels[i] !== -1) {
          currentKnownLabel = knownLabels[i];
        }
      } else {
        // Long gap AND moved — end previous stay, start new one
        finalizeCurrent();
        startNew(i);
      }
    } else if (dist <= STAY_RADIUS) {
      // Within radius — extend the stay
      pointCount++;
      stayEnd = p.timestamp;
      // Update centroid incrementally
      anchorLat = (anchorLat * (pointCount - 1) + p.latitude) / pointCount;
      anchorLng = (anchorLng * (pointCount - 1) + p.longitude) / pointCount;
      // Update known label if current is unresolved
      if (currentKnownLabel === -1 && knownLabels[i] !== -1) {
        currentKnownLabel = knownLabels[i];
      }
    } else {
      // Moved outside radius — end current stay, start new one
      finalizeCurrent();
      startNew(i);
    }
  }

  // Finalize the last candidate
  finalizeCurrent();

  return stays;
}

// ─── Step 3: Stay Merging ────────────────────────────────────────────────────

function mergeStays(stays: RawStay[]): RawStay[] {
  if (stays.length === 0) return [];

  const merged: RawStay[] = [{ ...stays[0] }];

  for (let i = 1; i < stays.length; i++) {
    const prev = merged[merged.length - 1];
    const curr = stays[i];

    const dist = haversineDistance(
      prev.centroidLat, prev.centroidLng,
      curr.centroidLat, curr.centroidLng,
    );
    const gap = curr.startTime - prev.endTime;

    // Same location (or same known place) and short gap → merge
    const sameKnownPlace = prev.knownPlaceLabel !== -1 && prev.knownPlaceLabel === curr.knownPlaceLabel;
    if ((dist <= STAY_RADIUS || sameKnownPlace) && gap <= MERGE_GAP) {
      // Merge: update centroid, extend time, sum points
      const totalPoints = prev.pointCount + curr.pointCount;
      prev.centroidLat = (prev.centroidLat * prev.pointCount + curr.centroidLat * curr.pointCount) / totalPoints;
      prev.centroidLng = (prev.centroidLng * prev.pointCount + curr.centroidLng * curr.pointCount) / totalPoints;
      prev.endTime = curr.endTime;
      prev.pointCount = totalPoints;
      // Keep known place label if either has one
      if (prev.knownPlaceLabel === -1) prev.knownPlaceLabel = curr.knownPlaceLabel;
    } else {
      merged.push({ ...curr });
    }
  }

  return merged;
}

// ─── Step 4: Place Assignment ────────────────────────────────────────────────

function assignPlaces(
  stays: RawStay[],
  knownPlaces: KnownPlace[],
): Stay[] {
  const discoveredPlaces: DiscoveredPlace[] = [];
  let nextPlaceNum = 1;

  return stays.map((raw) => {
    let placeId = "";

    if (raw.knownPlaceLabel !== -1) {
      // Known place — use its name
      placeId = knownPlaces[raw.knownPlaceLabel].name;
    } else {
      // Check if centroid matches any known place directly
      let matchedKnown = false;
      let bestDist = Infinity;
      let bestKnown = -1;
      for (let k = 0; k < knownPlaces.length; k++) {
        const d = haversineDistance(
          raw.centroidLat, raw.centroidLng,
          knownPlaces[k].latitude, knownPlaces[k].longitude,
        );
        if (d <= knownPlaces[k].radiusMeters && d < bestDist) {
          bestDist = d;
          bestKnown = k;
          matchedKnown = true;
        }
      }

      if (matchedKnown) {
        placeId = knownPlaces[bestKnown].name;
      } else {
        // Check discovered places
        let found = false;
        for (const dp of discoveredPlaces) {
          const d = haversineDistance(
            raw.centroidLat, raw.centroidLng,
            dp.centroidLat, dp.centroidLng,
          );
          if (d <= STAY_RADIUS) {
            placeId = dp.id;
            // Update discovered place centroid (rolling average)
            dp.stayCount++;
            dp.centroidLat = (dp.centroidLat * (dp.stayCount - 1) + raw.centroidLat) / dp.stayCount;
            dp.centroidLng = (dp.centroidLng * (dp.stayCount - 1) + raw.centroidLng) / dp.stayCount;
            found = true;
            break;
          }
        }

        if (!found) {
          placeId = `Place ${nextPlaceNum}`;
          discoveredPlaces.push({
            id: placeId,
            centroidLat: raw.centroidLat,
            centroidLng: raw.centroidLng,
            stayCount: 1,
          });
          nextPlaceNum++;
        }
      }
    }

    return {
      placeId,
      centroid: { latitude: raw.centroidLat, longitude: raw.centroidLng },
      startTime: raw.startTime,
      endTime: raw.endTime,
      durationMinutes: Math.round((raw.endTime - raw.startTime) / (1000 * 60)),
      pointCount: raw.pointCount,
    };
  });
}

// ─── Step 5: Transit Annotation ──────────────────────────────────────────────

function buildTransit(stays: Stay[]): TransitSegment[] {
  const transit: TransitSegment[] = [];

  for (let i = 1; i < stays.length; i++) {
    const prev = stays[i - 1];
    const curr = stays[i];
    const gapMs = curr.startTime - prev.endTime;

    if (gapMs <= 0) continue;

    const distKm = haversineDistance(
      prev.centroid.latitude, prev.centroid.longitude,
      curr.centroid.latitude, curr.centroid.longitude,
    ) / 1000;

    transit.push({
      startTime: prev.endTime,
      endTime: curr.startTime,
      durationMinutes: Math.round(gapMs / (1000 * 60)),
      distanceKm: Math.round(distKm * 10) / 10,
      fromPlaceId: prev.placeId,
      toPlaceId: curr.placeId,
    });
  }

  return transit;
}

// ─── Step 6: Summary Formatting ──────────────────────────────────────────────

const DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function formatDateHeader(ts: number): string {
  const d = new Date(ts);
  return `${DAY_NAMES[d.getDay()]} ${MONTH_NAMES[d.getMonth()]} ${d.getDate()}`;
}

function formatDuration(minutes: number): string {
  if (minutes < 60) return `${minutes}min`;
  const h = Math.round(minutes / 6) / 10; // round to 1 decimal
  return `${h}h`;
}

function buildSummaryRecent(stays: Stay[], transit: TransitSegment[], now: number): string {
  const cutoff = now - RECENT_DAYS * 24 * 60 * 60 * 1000;
  const recentStays = stays.filter((s) => s.endTime >= cutoff);

  if (recentStays.length === 0) return "";

  // Group stays by local date
  const dayGroups = new Map<string, { stays: Stay[]; transit: TransitSegment[] }>();

  for (const stay of recentStays) {
    const header = formatDateHeader(stay.startTime);
    if (!dayGroups.has(header)) dayGroups.set(header, { stays: [], transit: [] });
    dayGroups.get(header)!.stays.push(stay);
  }

  // Add transit to day groups
  const recentTransit = transit.filter((t) => t.endTime >= cutoff && t.durationMinutes * 60 * 1000 >= MIN_TRANSIT_SUMMARY);
  for (const t of recentTransit) {
    const header = formatDateHeader(t.startTime);
    if (dayGroups.has(header)) {
      dayGroups.get(header)!.transit.push(t);
    }
  }

  const lines: string[] = [];
  for (const [header, group] of dayGroups) {
    const parts: string[] = [];
    // Interleave stays and transit in time order
    const events: { time: number; text: string }[] = [];

    for (const s of group.stays) {
      if (s.durationMinutes === 0) continue;
      const start = formatLocalTime(s.startTime);
      const end = formatLocalTime(s.endTime);
      events.push({
        time: s.startTime,
        text: `${s.placeId} ${start}\u2013${end} (${formatDuration(s.durationMinutes)})`,
      });
    }

    for (const t of group.transit) {
      events.push({
        time: t.startTime,
        text: `[${formatDuration(t.durationMinutes)}/${t.distanceKm}km]`,
      });
    }

    events.sort((a, b) => a.time - b.time);
    for (const e of events) parts.push(e.text);

    if (parts.length > 0) {
      lines.push(`${header}: ${parts.join(", ")}`);
    }
  }

  return lines.join("\n");
}

function buildSummaryWeekly(stays: Stay[], now: number): string {
  if (stays.length === 0) return "";

  // Determine week boundaries (Sunday-based)
  const nowDate = new Date(now);
  // Start of current week (Sunday)
  const currentSunday = new Date(nowDate);
  currentSunday.setHours(0, 0, 0, 0);
  currentSunday.setDate(currentSunday.getDate() - currentSunday.getDay());
  const currentWeekStart = currentSunday.getTime();

  // Group stays by week
  const weekMs = 7 * 24 * 60 * 60 * 1000;
  const weekGroups = new Map<number, Map<string, number>>(); // weekStart → placeId → totalMinutes

  for (const stay of stays) {
    // Determine which week this stay belongs to (by start time)
    const weeksAgo = Math.floor((currentWeekStart - stay.startTime) / weekMs);
    const weekStart = currentWeekStart - weeksAgo * weekMs;

    if (!weekGroups.has(weekStart)) weekGroups.set(weekStart, new Map());
    const placeMap = weekGroups.get(weekStart)!;
    placeMap.set(stay.placeId, (placeMap.get(stay.placeId) ?? 0) + stay.durationMinutes);
  }

  // Sort weeks by date (most recent first)
  const sortedWeeks = [...weekGroups.entries()].sort((a, b) => b[0] - a[0]);

  const lines: string[] = [];
  for (let i = 0; i < sortedWeeks.length; i++) {
    const [weekStart, placeMap] = sortedWeeks[i];
    const label = i === 0 ? "This week" : i === 1 ? "Last week" : `${i} weeks ago`;

    // Sort places by total time descending
    const sorted = [...placeMap.entries()].sort((a, b) => b[1] - a[1]);
    const parts = sorted.map(([place, minutes]) => {
      const hours = Math.round(minutes / 6) / 10;
      return `${place} ${hours}h`;
    });

    lines.push(`${label}: ${parts.join(", ")}`);
  }

  return lines.join("\n");
}

// ─── Main Entry Point ────────────────────────────────────────────────────────

export function clusterLocationsV2(
  points: LocationPoint[],
  knownPlaces: KnownPlace[] = [],
): ClusterResultV2 {
  if (points.length === 0) {
    return { stays: [], transit: [], summaryRecent: "", summaryWeekly: "" };
  }

  // Sort by timestamp
  const sorted = [...points].sort((a, b) => a.timestamp - b.timestamp);

  // Step 1: Known place labeling
  const knownLabels = knownPlaces.length > 0
    ? labelPointsWithKnownPlaces(sorted, knownPlaces)
    : sorted.map(() => -1);

  // Step 2: Stationary detection
  const rawStays = detectStays(sorted, knownLabels);

  // Step 3: Stay merging
  const mergedStays = mergeStays(rawStays);

  // Step 4: Place assignment
  const stays = assignPlaces(mergedStays, knownPlaces);

  // Step 5: Transit annotation
  const transit = buildTransit(stays);

  // Step 6: Summary formatting
  const now = sorted[sorted.length - 1].timestamp;
  const summaryRecent = buildSummaryRecent(stays, transit, now);
  const summaryWeekly = buildSummaryWeekly(stays, now);

  return { stays, transit, summaryRecent, summaryWeekly };
}

// Export internals for testing
export { detectStays, mergeStays, assignPlaces, buildTransit, buildSummaryRecent, buildSummaryWeekly };
export { STAY_RADIUS, MIN_STAY_DURATION, MAX_POINT_GAP, MERGE_GAP, MIN_TRANSIT_SUMMARY, RECENT_DAYS };
