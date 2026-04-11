/**
 * Known-places matching logic.
 * Pure functions — no device access, fully testable.
 */

import type { LocationPoint, PlaceCluster } from "./clustering";
import { haversineDistance } from "./geo";

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
    const dist = haversineDistance(lat, lng, place.latitude, place.longitude);
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

// ─── Merge geometry ──────────────────────────────────────────────────────────

/**
 * Grow an existing known place's disc to cover a new centroid.
 *
 * Computes the minimum bounding circle of (existing disc ∪ new centroid)
 * plus a safety buffer. See docs/superpowers/specs/2026-03-26-location-clustering-v2.md
 * ("Merging a new point into a known place") for the derivation.
 *
 * The new center is linearly interpolated along the flat-plane segment from
 * existing.center toward newCentroid. At the sub-kilometer distances this
 * feature deals with, the great-circle vs straight-line error is <0.01m, so
 * the flat lerp is fine.
 *
 * If the new centroid already lies inside the existing disc, returns the
 * existing disc unchanged (defensive — shouldn't occur in the UI flow).
 */
export function mergePlaceCircle(
  existing: { latitude: number; longitude: number; radiusMeters: number },
  newCentroid: { latitude: number; longitude: number },
  buffer: number = 50,
): { latitude: number; longitude: number; radiusMeters: number } {
  const d = haversineDistance(
    existing.latitude,
    existing.longitude,
    newCentroid.latitude,
    newCentroid.longitude,
  );

  if (d <= existing.radiusMeters) {
    return {
      latitude: existing.latitude,
      longitude: existing.longitude,
      radiusMeters: existing.radiusMeters,
    };
  }

  const shift = (d - existing.radiusMeters) / 2;
  const t = shift / d; // fraction along the line toward newCentroid, in [0, 0.5)
  const newLat =
    existing.latitude + (newCentroid.latitude - existing.latitude) * t;
  const newLng =
    existing.longitude + (newCentroid.longitude - existing.longitude) * t;
  const newRadius = (d + existing.radiusMeters) / 2 + buffer;

  return {
    latitude: newLat,
    longitude: newLng,
    radiusMeters: newRadius,
  };
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
