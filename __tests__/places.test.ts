import {
  matchPointToPlace,
  labelPointsWithKnownPlaces,
  buildKnownPlaceClusters,
  type KnownPlace,
} from "../lib/places";
import { haversineDistance, clusterLocations, type LocationPoint } from "../lib/clustering";

// Helper to make a LocationPoint
function pt(
  lat: number,
  lng: number,
  timestamp: number,
  accuracy: number | null = 10,
): LocationPoint {
  return { latitude: lat, longitude: lng, accuracy, timestamp };
}

// ─── matchPointToPlace ──────────────────────────────────────────────────────

describe("matchPointToPlace", () => {
  const places: KnownPlace[] = [
    { id: 1, name: "Home", latitude: 47.6062, longitude: -122.3321, radiusMeters: 100 },
    { id: 2, name: "Work", latitude: 47.6200, longitude: -122.3500, radiusMeters: 200 },
  ];

  it("returns -1 when no places match", () => {
    const result = matchPointToPlace(0, 0, places);
    expect(result.placeIndex).toBe(-1);
    expect(result.distance).toBe(Infinity);
  });

  it("returns -1 for empty places array", () => {
    const result = matchPointToPlace(47.6062, -122.3321, []);
    expect(result.placeIndex).toBe(-1);
  });

  it("matches a point exactly at the place", () => {
    const result = matchPointToPlace(47.6062, -122.3321, places);
    expect(result.placeIndex).toBe(0);
    expect(result.distance).toBe(0);
  });

  it("matches a point within radius", () => {
    // ~10m from Home
    const result = matchPointToPlace(47.6063, -122.3321, places);
    expect(result.placeIndex).toBe(0);
    expect(result.distance).toBeGreaterThan(0);
    expect(result.distance).toBeLessThan(100);
  });

  it("does not match a point outside radius", () => {
    // ~200m from Home, outside 100m radius
    const result = matchPointToPlace(47.608, -122.3321, places);
    expect(result.placeIndex).toBe(-1);
  });

  it("matches the closest place when multiple are within radius", () => {
    // Create overlapping places
    const overlapping: KnownPlace[] = [
      { id: 1, name: "Place A", latitude: 47.6062, longitude: -122.3321, radiusMeters: 500 },
      { id: 2, name: "Place B", latitude: 47.6065, longitude: -122.3321, radiusMeters: 500 },
    ];
    // Point is closer to Place B
    const result = matchPointToPlace(47.6066, -122.3321, overlapping);
    expect(result.placeIndex).toBe(1);
  });
});

// ─── labelPointsWithKnownPlaces ─────────────────────────────────────────────

describe("labelPointsWithKnownPlaces", () => {
  const places: KnownPlace[] = [
    { id: 1, name: "Home", latitude: 47.6062, longitude: -122.3321, radiusMeters: 100 },
    { id: 2, name: "Work", latitude: 47.6200, longitude: -122.3500, radiusMeters: 200 },
  ];

  it("labels all points as -1 when no places defined", () => {
    const points = [pt(47.6062, -122.3321, 1000), pt(47.6200, -122.3500, 2000)];
    const labels = labelPointsWithKnownPlaces(points, []);
    expect(labels).toEqual([-1, -1]);
  });

  it("labels points matching known places", () => {
    const points = [
      pt(47.6062, -122.3321, 1000), // at Home
      pt(47.6200, -122.3500, 2000), // at Work
      pt(0, 0, 3000),               // nowhere
    ];
    const labels = labelPointsWithKnownPlaces(points, places);
    expect(labels[0]).toBe(0); // Home
    expect(labels[1]).toBe(1); // Work
    expect(labels[2]).toBe(-1); // unmatched
  });

  it("labels all points within Home radius as 0", () => {
    const points = [
      pt(47.6062, -122.3321, 1000),
      pt(47.6063, -122.3322, 2000),
      pt(47.6061, -122.3320, 3000),
    ];
    const labels = labelPointsWithKnownPlaces(points, places);
    expect(labels).toEqual([0, 0, 0]);
  });
});

// ─── buildKnownPlaceClusters ────────────────────────────────────────────────

describe("buildKnownPlaceClusters", () => {
  const places: KnownPlace[] = [
    { id: 1, name: "Home", latitude: 47.6062, longitude: -122.3321, radiusMeters: 100 },
    { id: 2, name: "Work", latitude: 47.6200, longitude: -122.3500, radiusMeters: 200 },
  ];

  it("returns empty array when no points match", () => {
    const points = [pt(0, 0, 1000)];
    const labels = [-1];
    const clusters = buildKnownPlaceClusters(points, labels, places);
    expect(clusters).toEqual([]);
  });

  it("builds cluster for matched points", () => {
    const hourMs = 60 * 60 * 1000;
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const points = [
      pt(47.6062, -122.3321, ts),
      pt(47.6063, -122.3322, ts + hourMs),
      pt(47.6061, -122.3320, ts + 2 * hourMs),
    ];
    const labels = [0, 0, 0]; // all Home
    const clusters = buildKnownPlaceClusters(points, labels, places);

    expect(clusters).toHaveLength(1);
    expect(clusters[0].id).toBe("Home");
    expect(clusters[0].center.latitude).toBe(47.6062);
    expect(clusters[0].center.longitude).toBe(-122.3321);
    expect(clusters[0].pointCount).toBe(3);
    expect(clusters[0].dwellTimeHours).toBe(2);
  });

  it("builds separate clusters for different known places", () => {
    const hourMs = 60 * 60 * 1000;
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const points = [
      pt(47.6062, -122.3321, ts),
      pt(47.6063, -122.3322, ts + hourMs),
      pt(47.6200, -122.3500, ts + 3 * hourMs),
      pt(47.6201, -122.3501, ts + 4 * hourMs),
    ];
    const labels = [0, 0, 1, 1];
    const clusters = buildKnownPlaceClusters(points, labels, places);

    expect(clusters).toHaveLength(2);
    const homeCluster = clusters.find((c) => c.id === "Home");
    const workCluster = clusters.find((c) => c.id === "Work");
    expect(homeCluster).toBeDefined();
    expect(workCluster).toBeDefined();
    expect(homeCluster!.pointCount).toBe(2);
    expect(workCluster!.pointCount).toBe(2);
  });

  it("caps dwell time gaps at 2 hours", () => {
    const hourMs = 60 * 60 * 1000;
    const ts = Date.UTC(2026, 2, 15, 0, 0, 0);
    const points = [
      pt(47.6062, -122.3321, ts),
      pt(47.6063, -122.3322, ts + 5 * hourMs), // 5h gap, capped to 2h
      pt(47.6061, -122.3320, ts + 6 * hourMs), // 1h gap
    ];
    const labels = [0, 0, 0];
    const clusters = buildKnownPlaceClusters(points, labels, places);

    expect(clusters).toHaveLength(1);
    expect(clusters[0].dwellTimeHours).toBe(3); // 2h (capped) + 1h
  });
});

// ─── clusterLocations with known places ─────────────────────────────────────

describe("clusterLocations with known places", () => {
  const places: KnownPlace[] = [
    { id: 1, name: "Home", latitude: 47.6062, longitude: -122.3321, radiusMeters: 100 },
    { id: 2, name: "Work", latitude: 47.6200, longitude: -122.3500, radiusMeters: 200 },
  ];

  it("uses known place names in clusters", () => {
    const hourMs = 60 * 60 * 1000;
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const points: LocationPoint[] = [];

    // 5 points at Home
    for (let i = 0; i < 5; i++) {
      points.push(pt(
        47.6062 + (Math.random() - 0.5) * 0.0002,
        -122.3321 + (Math.random() - 0.5) * 0.0002,
        ts + i * hourMs,
      ));
    }

    const result = clusterLocations(points, 50, 3, places);
    expect(result.clusters.length).toBeGreaterThanOrEqual(1);
    const homeCluster = result.clusters.find((c) => c.id === "Home");
    expect(homeCluster).toBeDefined();
    expect(homeCluster!.pointCount).toBe(5);
  });

  it("falls back to generic clustering for unmatched points", () => {
    const hourMs = 60 * 60 * 1000;
    const ts = Date.UTC(2026, 2, 15, 0, 0, 0);
    const points: LocationPoint[] = [];

    // 3 points at Home (known place)
    for (let i = 0; i < 3; i++) {
      points.push(pt(47.6062, -122.3321, ts + i * hourMs));
    }

    // 5 points at unknown location (far from known places)
    for (let i = 0; i < 5; i++) {
      points.push(pt(
        48.0000 + i * 0.0001,
        -121.0000,
        ts + (3 + i) * hourMs,
      ));
    }

    const result = clusterLocations(points, 500, 3, places);

    // Should have Home + a generic cluster
    const homeCluster = result.clusters.find((c) => c.id === "Home");
    expect(homeCluster).toBeDefined();
    expect(homeCluster!.pointCount).toBe(3);

    const genericClusters = result.clusters.filter((c) => c.id.startsWith("place_"));
    expect(genericClusters.length).toBeGreaterThanOrEqual(1);
  });

  it("uses known place names in timeline", () => {
    const hourMs = 60 * 60 * 1000;
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const points: LocationPoint[] = [];

    // 4 points at Home
    for (let i = 0; i < 4; i++) {
      points.push(pt(47.6062, -122.3321, ts + i * hourMs));
    }
    // 4 points at Work
    for (let i = 0; i < 4; i++) {
      points.push(pt(47.6200, -122.3500, ts + (5 + i) * hourMs));
    }

    const result = clusterLocations(points, 50, 3, places);

    // Timeline should reference Home and Work
    const homeVisit = result.timeline.find((v) => v.placeId === "Home");
    const workVisit = result.timeline.find((v) => v.placeId === "Work");
    expect(homeVisit).toBeDefined();
    expect(workVisit).toBeDefined();
  });

  it("uses known place names in summary", () => {
    const hourMs = 60 * 60 * 1000;
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const points: LocationPoint[] = [];

    for (let i = 0; i < 4; i++) {
      points.push(pt(47.6062, -122.3321, ts + i * hourMs));
    }
    for (let i = 0; i < 4; i++) {
      points.push(pt(47.6200, -122.3500, ts + (5 + i) * hourMs));
    }

    const result = clusterLocations(points, 50, 3, places);
    expect(result.summary).toContain("Home");
    expect(result.summary).toContain("Work");
  });

  it("works without known places (backward compatible)", () => {
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const hourMs = 60 * 60 * 1000;
    const points = Array.from({ length: 5 }, (_, i) =>
      pt(47.6, -122.3, ts + i * hourMs),
    );
    const result = clusterLocations(points, 150, 3);
    expect(result.clusters).toHaveLength(1);
    expect(result.clusters[0].id).toBe("place_1");
  });

  it("returns empty result for empty input with known places", () => {
    const result = clusterLocations([], 50, 3, places);
    expect(result.clusters).toEqual([]);
    expect(result.timeline).toEqual([]);
    expect(result.summary).toBe("");
  });
});

// ─── Distance calculation verification ──────────────────────────────────────

describe("haversine distance for known places matching", () => {
  it("correctly identifies points within 100m radius", () => {
    // Home at (47.6062, -122.3321)
    // A point ~50m away
    const dist = haversineDistance(47.6062, -122.3321, 47.60665, -122.3321);
    expect(dist).toBeLessThan(100);
    expect(dist).toBeGreaterThan(30);
  });

  it("correctly identifies points outside 100m radius", () => {
    // Home at (47.6062, -122.3321)
    // A point ~200m away
    const dist = haversineDistance(47.6062, -122.3321, 47.608, -122.3321);
    expect(dist).toBeGreaterThan(100);
  });
});
