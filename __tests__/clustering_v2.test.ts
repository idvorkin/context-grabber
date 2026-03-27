import {
  clusterLocationsV2,
  type Stay,
  type TransitSegment,
  type ClusterResultV2,
  STAY_RADIUS,
  MIN_STAY_DURATION,
} from "../lib/clustering_v2";
import type { LocationPoint } from "../lib/clustering";
import type { KnownPlace } from "../lib/places";

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Create a LocationPoint at (lat, lng) with given timestamp (UTC ms). */
function pt(lat: number, lng: number, timestamp: number, accuracy: number | null = 10): LocationPoint {
  return { latitude: lat, longitude: lng, accuracy, timestamp };
}

/** Generate N points at the same location, spaced `intervalMs` apart, starting at `startTs`. */
function stationaryPoints(
  lat: number, lng: number, startTs: number, count: number, intervalMs = 5 * 60 * 1000,
): LocationPoint[] {
  return Array.from({ length: count }, (_, i) =>
    pt(lat, lng, startTs + i * intervalMs),
  );
}

/** Offset latitude by ~meters (rough approximation: 1 degree ~ 111km). */
function offsetLat(lat: number, meters: number): number {
  return lat + meters / 111000;
}

// Base coordinates (Seattle area)
const HOME_LAT = 47.6419;
const HOME_LNG = -122.3045;
const WORK_LAT = 47.6289;
const WORK_LNG = -122.3434;

// Known places fixture
const KNOWN_PLACES: KnownPlace[] = [
  { id: 17, name: "Home", latitude: HOME_LAT, longitude: HOME_LNG, radiusMeters: 100 },
  { id: 18, name: "Work", latitude: WORK_LAT, longitude: WORK_LNG, radiusMeters: 200 },
  { id: 13, name: "Kettlebility", latitude: 47.6762, longitude: -122.3187, radiusMeters: 100 },
];

// ─── Tests ───────────────────────────────────────────────────────────────────

describe("clusterLocationsV2", () => {
  // 1. Empty input
  it("returns empty result for empty input", () => {
    const result = clusterLocationsV2([], []);
    expect(result.stays).toEqual([]);
    expect(result.transit).toEqual([]);
    expect(result.summaryRecent).toBe("");
    expect(result.summaryWeekly).toBe("");
  });

  // 2. Single point at known place
  it("single point at known place creates no stay (below min duration)", () => {
    const points = [pt(HOME_LAT, HOME_LNG, Date.now())];
    const result = clusterLocationsV2(points, KNOWN_PLACES);
    // Single point has 0 duration, below MIN_STAY_DURATION
    expect(result.stays).toHaveLength(0);
  });

  it("two points at known place within min duration creates one stay", () => {
    const now = Date.now();
    const points = [
      pt(HOME_LAT, HOME_LNG, now),
      pt(HOME_LAT + 0.0001, HOME_LNG, now + 6 * 60 * 1000), // 6 min later, slight drift
    ];
    const result = clusterLocationsV2(points, KNOWN_PLACES);
    expect(result.stays).toHaveLength(1);
    expect(result.stays[0].placeId).toBe("Home");
    expect(result.stays[0].pointCount).toBe(2);
  });

  // 3. Stationary points → one stay
  it("stationary points at same location produce one stay", () => {
    const now = Date.now();
    const points = stationaryPoints(HOME_LAT, HOME_LNG, now, 10, 10 * 60 * 1000); // 10 pts, 10min apart = 90min
    const result = clusterLocationsV2(points, KNOWN_PLACES);
    expect(result.stays).toHaveLength(1);
    expect(result.stays[0].placeId).toBe("Home");
    expect(result.stays[0].durationMinutes).toBe(90);
    expect(result.stays[0].pointCount).toBe(10);
  });

  // 4. Moving points → multiple stays with transit
  it("moving between two places produces two stays and transit", () => {
    const now = Date.now();
    // Home for 1 hour
    const homePoints = stationaryPoints(HOME_LAT, HOME_LNG, now, 7, 10 * 60 * 1000); // 60min
    // Work for 1 hour (starts 90min after home start — 30min transit)
    const workStart = now + 90 * 60 * 1000;
    const workPoints = stationaryPoints(WORK_LAT, WORK_LNG, workStart, 7, 10 * 60 * 1000); // 60min

    const result = clusterLocationsV2([...homePoints, ...workPoints], KNOWN_PLACES);

    expect(result.stays).toHaveLength(2);
    expect(result.stays[0].placeId).toBe("Home");
    expect(result.stays[1].placeId).toBe("Work");

    expect(result.transit).toHaveLength(1);
    expect(result.transit[0].fromPlaceId).toBe("Home");
    expect(result.transit[0].toPlaceId).toBe("Work");
    expect(result.transit[0].durationMinutes).toBe(30);
    expect(result.transit[0].distanceKm).toBeGreaterThan(0);
  });

  // 5. Long gap at same location → stay continues
  it("long gap at same location continues the stay", () => {
    const now = Date.now();
    // Evening points at home
    const evening = stationaryPoints(HOME_LAT, HOME_LNG, now, 3, 10 * 60 * 1000); // 20min
    // Morning points at home, 8 hours later
    const morning = stationaryPoints(HOME_LAT, HOME_LNG, now + 8 * 60 * 60 * 1000, 3, 10 * 60 * 1000); // 20min

    const result = clusterLocationsV2([...evening, ...morning], KNOWN_PLACES);

    // Should be ONE stay spanning the full overnight period
    expect(result.stays).toHaveLength(1);
    expect(result.stays[0].placeId).toBe("Home");
    expect(result.stays[0].pointCount).toBe(6);
    // Duration should span from first to last point (~8h 20min)
    expect(result.stays[0].durationMinutes).toBeGreaterThan(480);
  });

  // 6. Long gap with movement → stay ends
  it("long gap with movement splits into two stays", () => {
    const now = Date.now();
    const homePoints = stationaryPoints(HOME_LAT, HOME_LNG, now, 3, 10 * 60 * 1000);
    // 5 hours later, at a different location (>100m away)
    const otherLat = offsetLat(HOME_LAT, 500); // 500m away
    const otherPoints = stationaryPoints(otherLat, HOME_LNG, now + 5 * 60 * 60 * 1000, 3, 10 * 60 * 1000);

    const result = clusterLocationsV2([...homePoints, ...otherPoints], KNOWN_PLACES);

    expect(result.stays).toHaveLength(2);
    expect(result.stays[0].placeId).toBe("Home");
    expect(result.stays[1].placeId).not.toBe("Home");
  });

  // 7. Short visit filtering (< 5 min)
  it("filters out stays shorter than MIN_STAY_DURATION", () => {
    const now = Date.now();
    // Quick drive-by: 2 points 2 minutes apart
    const shortVisit = [
      pt(HOME_LAT, HOME_LNG, now),
      pt(HOME_LAT, HOME_LNG, now + 2 * 60 * 1000),
    ];
    // Real stay: 10 minutes at work
    const realStay = stationaryPoints(WORK_LAT, WORK_LNG, now + 30 * 60 * 1000, 3, 5 * 60 * 1000);

    const result = clusterLocationsV2([...shortVisit, ...realStay], KNOWN_PLACES);

    // The short visit should be filtered out
    expect(result.stays).toHaveLength(1);
    expect(result.stays[0].placeId).toBe("Work");
  });

  // 8. Stay merging (brief departure and return)
  it("merges stays at same location with brief gap", () => {
    const now = Date.now();
    // Home for 30 min
    const home1 = stationaryPoints(HOME_LAT, HOME_LNG, now, 4, 10 * 60 * 1000); // 30min
    // Brief departure (15 min gap — within MERGE_GAP)
    // Home again for 30 min
    const home2 = stationaryPoints(HOME_LAT, HOME_LNG, now + 45 * 60 * 1000, 4, 10 * 60 * 1000); // 30min

    const result = clusterLocationsV2([...home1, ...home2], KNOWN_PLACES);

    // Should merge into one stay
    expect(result.stays).toHaveLength(1);
    expect(result.stays[0].placeId).toBe("Home");
    expect(result.stays[0].pointCount).toBe(8);
  });

  // 9. Same place on different days gets same place ID
  it("same unknown place on different days gets same place ID", () => {
    const day1 = new Date(2026, 2, 25, 10, 0).getTime(); // Mar 25
    const day2 = new Date(2026, 2, 26, 10, 0).getTime(); // Mar 26

    // Unknown location (not matching any known place)
    const unknownLat = 47.70;
    const unknownLng = -122.35;

    // A different location in between (far away) to break the stay
    const otherLat = 47.75;
    const otherLng = -122.40;
    const betweenStart = day1 + 2 * 60 * 60 * 1000; // 2h after day1 start

    const day1Points = stationaryPoints(unknownLat, unknownLng, day1, 5, 10 * 60 * 1000);
    const betweenPoints = stationaryPoints(otherLat, otherLng, betweenStart, 5, 10 * 60 * 1000);
    const day2Points = stationaryPoints(unknownLat, unknownLng, day2, 5, 10 * 60 * 1000);

    const result = clusterLocationsV2([...day1Points, ...betweenPoints, ...day2Points], KNOWN_PLACES);

    // Find stays at the unknown location
    const unknownStays = result.stays.filter((s) => s.placeId.startsWith("Place"));
    const targetStays = unknownStays.filter((s) => {
      const d = Math.abs(s.centroid.latitude - unknownLat) + Math.abs(s.centroid.longitude - unknownLng);
      return d < 0.01;
    });

    // Both visits to the unknown place should have the same place ID
    expect(targetStays.length).toBeGreaterThanOrEqual(2);
    expect(targetStays[0].placeId).toBe(targetStays[1].placeId);
    expect(targetStays[0].placeId).toMatch(/^Place \d+$/);
  });

  // 10. Summary formatting
  describe("summary formatting", () => {
    it("produces recent summary with day headers", () => {
      const now = Date.now();
      // Stay at home for 2 hours
      const homePoints = stationaryPoints(HOME_LAT, HOME_LNG, now - 2 * 60 * 60 * 1000, 13, 10 * 60 * 1000);

      const result = clusterLocationsV2(homePoints, KNOWN_PLACES);

      expect(result.summaryRecent).toContain("Home");
      expect(result.summaryRecent.length).toBeGreaterThan(0);
      // Should have a day header format like "Thu Mar 26:"
      expect(result.summaryRecent).toMatch(/\w{3} \w{3} \d+:/);
    });

    it("produces weekly summary with place totals", () => {
      const now = Date.now();
      // Multiple days of data
      const points: LocationPoint[] = [];
      for (let day = 0; day < 5; day++) {
        const dayStart = now - (5 - day) * 24 * 60 * 60 * 1000;
        // 8 hours at home
        points.push(...stationaryPoints(HOME_LAT, HOME_LNG, dayStart, 5, 10 * 60 * 1000));
      }

      const result = clusterLocationsV2(points, KNOWN_PLACES);

      expect(result.summaryWeekly).toContain("Home");
      expect(result.summaryWeekly).toMatch(/\d+(\.\d)?h/);
    });

    it("does not include zero-duration stays in summary", () => {
      const now = Date.now();
      const points = stationaryPoints(HOME_LAT, HOME_LNG, now, 5, 10 * 60 * 1000);
      const result = clusterLocationsV2(points, KNOWN_PLACES);

      // Check that no stay with "(0min)" appears
      expect(result.summaryRecent).not.toContain("(0min)");
      expect(result.summaryRecent).not.toContain("(0h)");
    });
  });
});

// ─── Real Data Test ──────────────────────────────────────────────────────────

describe("clusterLocationsV2 with real data", () => {
  let points: LocationPoint[];
  let result: ClusterResultV2;

  beforeAll(() => {
    // Load real location data from JSON fixture
    const rawData = require("./fixtures/locations.json") as Array<{
      latitude: number;
      longitude: number;
      accuracy: number;
      timestamp: number;
    }>;

    points = rawData.map((r) => ({
      latitude: r.latitude,
      longitude: r.longitude,
      accuracy: r.accuracy,
      timestamp: r.timestamp,
    }));

    const knownPlaces: KnownPlace[] = [
      { id: 13, name: "Kettlebility", latitude: 47.6762, longitude: -122.3187, radiusMeters: 100 },
      { id: 15, name: "Milstead & Co", latitude: 47.6508, longitude: -122.3503, radiusMeters: 50 },
      { id: 17, name: "Home", latitude: 47.641901, longitude: -122.304481, radiusMeters: 100 },
      { id: 18, name: "Work", latitude: 47.628937, longitude: -122.343437, radiusMeters: 200 },
    ];

    result = clusterLocationsV2(points, knownPlaces);
  });

  it("produces a reasonable number of stays", () => {
    expect(result.stays.length).toBeGreaterThan(0);
    expect(result.stays.length).toBeLessThan(50);
  });

  it("identifies known places (Home, Work, Kettlebility)", () => {
    const placeIds = result.stays.map((s) => s.placeId);
    expect(placeIds).toContain("Home");
    // Work or Kettlebility may or may not appear depending on data range
    const hasWorkOrKettlebility = placeIds.includes("Work") || placeIds.includes("Kettlebility");
    expect(hasWorkOrKettlebility).toBe(true);
  });

  it("summaryRecent is reasonable length", () => {
    expect(result.summaryRecent.length).toBeLessThan(2000);
  });

  it("summaryWeekly is reasonable length", () => {
    expect(result.summaryWeekly.length).toBeLessThan(2000);
  });

  it("no stays with 0 dwell time in summary", () => {
    // Filter stays that appear in summaryRecent
    for (const stay of result.stays) {
      if (stay.durationMinutes === 0) {
        // Zero-duration stays should not appear in the summary
        expect(result.summaryRecent).not.toContain(`${stay.placeId} `);
      }
    }
  });

  it("all stays have positive duration", () => {
    for (const stay of result.stays) {
      expect(stay.durationMinutes).toBeGreaterThanOrEqual(5);
      expect(stay.endTime).toBeGreaterThan(stay.startTime);
    }
  });

  it("transit segments have valid references", () => {
    const placeIds = new Set(result.stays.map((s) => s.placeId));
    for (const t of result.transit) {
      expect(placeIds.has(t.fromPlaceId)).toBe(true);
      expect(placeIds.has(t.toPlaceId)).toBe(true);
      expect(t.durationMinutes).toBeGreaterThan(0);
      expect(t.distanceKm).toBeGreaterThanOrEqual(0);
    }
  });
});
