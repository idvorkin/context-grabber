/**
 * Where Igor is, as the call tells the bridge (#107).
 *
 * Igor, walking to school, 2026-09-02 07:52: "Can you read my location? …
 * If you have the location at the start of the call, you might as well
 * give it to Larry so he knows where you are." One fix rides the start
 * frame; one small frame follows each significant move. Resolved against
 * the known places on the phone so the bridge gets a name, not just a
 * coordinate. Bridge half: the Cockpit repo.
 *
 * Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md,
 * "Where Igor is".
 */

import { haversineDistance } from "./geo";
import { matchPointToPlace, type KnownPlace } from "./places";

export type CallLocation = {
  lat: number;
  lon: number;
  /** Horizontal accuracy in metres, rounded; null when iOS gave none. */
  accuracyM: number | null;
  /** When the fix was taken, ISO 8601 UTC. */
  at: string;
  /** The known place the fix falls inside, or null. */
  place: string | null;
};

/** A move that is worth a frame: a new known place, or this far from the last fix. */
export const SIGNIFICANT_MOVE_M = 200;

export function toCallLocation(
  coords: { latitude: number; longitude: number; accuracy?: number | null },
  timestamp: number,
  knownPlaces: readonly KnownPlace[],
): CallLocation {
  const match = matchPointToPlace(coords.latitude, coords.longitude, knownPlaces as KnownPlace[]);
  return {
    lat: Number(coords.latitude.toFixed(6)),
    lon: Number(coords.longitude.toFixed(6)),
    accuracyM: typeof coords.accuracy === "number" && coords.accuracy >= 0 ? Math.round(coords.accuracy) : null,
    at: new Date(timestamp).toISOString(),
    place: match.placeIndex >= 0 ? knownPlaces[match.placeIndex].name : null,
  };
}

/** True when `next` deserves a frame after `prev`: first fix, a different place, or SIGNIFICANT_MOVE_M away. */
export function significantMove(prev: CallLocation | null, next: CallLocation): boolean {
  if (!prev) return true;
  if (prev.place !== next.place) return true;
  return haversineDistance(prev.lat, prev.lon, next.lat, next.lon) >= SIGNIFICANT_MOVE_M;
}

/** One log line: `Home (±12 m)` or `47.6062, -122.3321 (±65 m)`. */
export function describeLocation(l: CallLocation): string {
  const acc = l.accuracyM === null ? "" : ` (±${l.accuracyM} m)`;
  return `${l.place ?? `${l.lat}, ${l.lon}`}${acc}`;
}

/** What rides the wire — the bridge's snake_case for the accuracy. */
export function locationFields(l: CallLocation): Record<string, unknown> {
  return { lat: l.lat, lon: l.lon, accuracy_m: l.accuracyM, at: l.at, place: l.place };
}
