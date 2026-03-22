/**
 * Known-places matching logic.
 * Pure functions — no device access, fully testable.
 */

import type { LocationPoint, PlaceCluster } from "./clustering";

// ─── Haversine Distance (local copy to avoid circular dependency) ────────────

const DEG_TO_RAD = Math.PI / 180;
const EARTH_RADIUS_M = 6371000;

/** Haversine distance between two lat/lng points in meters. */
export function haversineDistancePlaces(
  lat1: number, lng1: number,
  lat2: number, lng2: number,
): number {
  const dLat = (lat2 - lat1) * DEG_TO_RAD;
  const dLng = (lng2 - lng1) * DEG_TO_RAD;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * DEG_TO_RAD) * Math.cos(lat2 * DEG_TO_RAD) *
    Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a));
}

// ─── Types ───────────────────────────────────────────────────────────────────

export type KnownPlace = {
  id: number;
  name: string;
  latitude: number;
  longitude: number;
  radiusMeters: number;
};

export type MatchResult = {
  placeIndex: number; // index into KnownPlace[], or -1 if no match
  distance: number; // distance in meters to the matched place (Infinity if no match)
};

// ─── Matching ────────────────────────────────────────────────────────────────

/**
 * Find the closest known place within radius for a single GPS point.
 * Returns the index into the knownPlaces array and the distance.
 * If no place is within radius, returns { placeIndex: -1, distance: Infinity }.
 */
export function matchPointToPlace(
  lat: number,
  lng: number,
  knownPlaces: KnownPlace[],
): MatchResult {
  let bestIndex = -1;
  let bestDistance = Infinity;

  for (let i = 0; i < knownPlaces.length; i++) {
    const place = knownPlaces[i];
    const dist = haversineDistancePlaces(lat, lng, place.latitude, place.longitude);
    if (dist <= place.radiusMeters && dist < bestDistance) {
      bestIndex = i;
      bestDistance = dist;
    }
  }

  return { placeIndex: bestIndex, distance: bestDistance };
}

/**
 * Label each GPS point: match against known places first.
 * Returns an array of KnownPlace indices (-1 for unmatched points).
 */
export function labelPointsWithKnownPlaces(
  points: LocationPoint[],
  knownPlaces: KnownPlace[],
): number[] {
  return points.map((p) =>
    matchPointToPlace(p.latitude, p.longitude, knownPlaces).placeIndex,
  );
}

/**
 * Build PlaceCluster objects from points matched to known places.
 * Groups points by their known place match, computes dwell time.
 */
export function buildKnownPlaceClusters(
  points: LocationPoint[],
  knownPlaceLabels: number[],
  knownPlaces: KnownPlace[],
): PlaceCluster[] {
  const groups = new Map<number, LocationPoint[]>();

  for (let i = 0; i < points.length; i++) {
    const label = knownPlaceLabels[i];
    if (label === -1) continue;
    if (!groups.has(label)) groups.set(label, []);
    groups.get(label)!.push(points[i]);
  }

  const clusters: PlaceCluster[] = [];
  for (const [placeIdx, pts] of groups) {
    const place = knownPlaces[placeIdx];
    const timestamps = pts.map((p) => p.timestamp).sort((a, b) => a - b);
    const firstVisit = timestamps[0];
    const lastVisit = timestamps[timestamps.length - 1];

    // Estimate dwell time: sum gaps between consecutive points (capped at 2hrs per gap)
    const MAX_GAP_MS = 2 * 60 * 60 * 1000;
    let dwellMs = 0;
    for (let i = 1; i < timestamps.length; i++) {
      const gap = timestamps[i] - timestamps[i - 1];
      dwellMs += Math.min(gap, MAX_GAP_MS);
    }

    clusters.push({
      id: place.name,
      center: { latitude: place.latitude, longitude: place.longitude },
      radiusMeters: place.radiusMeters,
      pointCount: pts.length,
      dwellTimeHours: Math.round((dwellMs / (1000 * 60 * 60)) * 10) / 10,
      firstVisit,
      lastVisit,
    });
  }

  return clusters;
}
