import {
  haversineDistance,
  dbscan,
  clusterLocations,
  formatClusterSummary,
  type LocationPoint,
  type PlaceCluster,
} from "../lib/clustering";

// Helper to make a LocationPoint
function pt(
  lat: number,
  lng: number,
  timestamp: number,
  accuracy: number | null = 10,
): LocationPoint {
  return { latitude: lat, longitude: lng, accuracy, timestamp };
}

// ─── haversineDistance ────────────────────────────────────────────────────────

describe("haversineDistance", () => {
  it("returns 0 for same point", () => {
    expect(haversineDistance(47.6, -122.3, 47.6, -122.3)).toBe(0);
  });

  it("returns ~111km for 1 degree latitude difference at equator", () => {
    const d = haversineDistance(0, 0, 1, 0);
    // 1 degree of latitude is ~111,195 meters
    expect(d).toBeGreaterThan(110000);
    expect(d).toBeLessThan(112000);
  });

  it("returns ~111km for 1 degree latitude at non-equator", () => {
    const d = haversineDistance(47, 0, 48, 0);
    // Latitude degrees are roughly constant (~111km)
    expect(d).toBeGreaterThan(110000);
    expect(d).toBeLessThan(112000);
  });

  it("returns shorter distance for 1 degree longitude at high latitude", () => {
    const atEquator = haversineDistance(0, 0, 0, 1);
    const at60 = haversineDistance(60, 0, 60, 1);
    // At 60 degrees, 1 lng degree is about half
    expect(at60).toBeLessThan(atEquator * 0.6);
    expect(at60).toBeGreaterThan(atEquator * 0.4);
  });

  it("is symmetric", () => {
    const d1 = haversineDistance(47.6, -122.3, 48.0, -121.0);
    const d2 = haversineDistance(48.0, -121.0, 47.6, -122.3);
    expect(d1).toBeCloseTo(d2, 6);
  });
});

// ─── dbscan ──────────────────────────────────────────────────────────────────

describe("dbscan", () => {
  it("returns empty array for empty input", () => {
    expect(dbscan([], 150, 3)).toEqual([]);
  });

  it("labels single point as noise when minPts > 1", () => {
    const labels = dbscan([pt(47.6, -122.3, 1000)], 150, 2);
    expect(labels).toEqual([-1]);
  });

  it("forms single cluster for nearby points", () => {
    // Points within a few meters of each other
    const points = [
      pt(47.6000, -122.3000, 1000),
      pt(47.6001, -122.3001, 2000),
      pt(47.6001, -122.3000, 3000),
      pt(47.6000, -122.3001, 4000),
    ];
    const labels = dbscan(points, 150, 3);
    // All should be in the same cluster (not noise)
    expect(labels[0]).toBeGreaterThanOrEqual(0);
    expect(new Set(labels).size).toBe(1);
  });

  it("forms two separate clusters for distant groups", () => {
    // Cluster A: near (47.6, -122.3)
    const a1 = pt(47.6000, -122.3000, 1000);
    const a2 = pt(47.6001, -122.3001, 2000);
    const a3 = pt(47.6001, -122.3000, 3000);
    // Cluster B: near (48.0, -121.0) — far away
    const b1 = pt(48.0000, -121.0000, 4000);
    const b2 = pt(48.0001, -121.0001, 5000);
    const b3 = pt(48.0001, -121.0000, 6000);

    const labels = dbscan([a1, a2, a3, b1, b2, b3], 150, 3);
    // First three form one cluster, last three form another
    expect(labels[0]).toBe(labels[1]);
    expect(labels[1]).toBe(labels[2]);
    expect(labels[3]).toBe(labels[4]);
    expect(labels[4]).toBe(labels[5]);
    // The two clusters have different IDs
    expect(labels[0]).not.toBe(labels[3]);
    // Neither is noise
    expect(labels[0]).toBeGreaterThanOrEqual(0);
    expect(labels[3]).toBeGreaterThanOrEqual(0);
  });

  it("filters noise points between clusters", () => {
    const a1 = pt(47.6000, -122.3000, 1000);
    const a2 = pt(47.6001, -122.3001, 2000);
    const a3 = pt(47.6001, -122.3000, 3000);
    // Noise: isolated point far from both clusters
    const noise = pt(47.8, -122.0, 3500);
    const b1 = pt(48.0000, -121.0000, 4000);
    const b2 = pt(48.0001, -121.0001, 5000);
    const b3 = pt(48.0001, -121.0000, 6000);

    const labels = dbscan([a1, a2, a3, noise, b1, b2, b3], 150, 3);
    expect(labels[3]).toBe(-1); // noise
  });

  it("all points noise when minPts is very high", () => {
    const points = [
      pt(47.6, -122.3, 1000),
      pt(47.6001, -122.3001, 2000),
    ];
    const labels = dbscan(points, 150, 100);
    expect(labels).toEqual([-1, -1]);
  });
});

// ─── clusterLocations ────────────────────────────────────────────────────────

describe("clusterLocations", () => {
  it("returns empty result for empty input", () => {
    const result = clusterLocations([]);
    expect(result.clusters).toEqual([]);
    expect(result.noiseCount).toBe(0);
    expect(result.summary).toBe("");
  });

  it("single point returns noise, no clusters", () => {
    const result = clusterLocations([pt(47.6, -122.3, 1000)]);
    expect(result.clusters).toHaveLength(0);
    expect(result.noiseCount).toBe(1);
    expect(result.summary).toBe("");
  });

  it("all same location forms one cluster", () => {
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const points = Array.from({ length: 5 }, (_, i) =>
      pt(47.6, -122.3, ts + i * 60 * 60 * 1000), // 1 hour apart
    );
    const result = clusterLocations(points, 150, 3);
    expect(result.clusters).toHaveLength(1);
    expect(result.noiseCount).toBe(0);
    expect(result.clusters[0].pointCount).toBe(5);
    // ID is based on internal cluster numbering
    expect(result.clusters[0].id).toMatch(/^place_\d+$/);
  });

  it("computes dwell time from timestamps", () => {
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const hourMs = 60 * 60 * 1000;
    const points = [
      pt(47.6000, -122.3000, ts),
      pt(47.6001, -122.3001, ts + 1 * hourMs),
      pt(47.6001, -122.3000, ts + 2 * hourMs),
      pt(47.6000, -122.3001, ts + 3 * hourMs),
    ];
    const result = clusterLocations(points, 150, 3);
    expect(result.clusters).toHaveLength(1);
    expect(result.clusters[0].dwellTimeHours).toBe(3);
  });

  it("caps dwell time gaps at 2 hours", () => {
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const hourMs = 60 * 60 * 1000;
    // 3 points: 0h, 5h, 6h — gap 0->5 is 5h (capped to 2h), gap 5->6 is 1h
    const points = [
      pt(47.6000, -122.3000, ts),
      pt(47.6001, -122.3001, ts + 5 * hourMs),
      pt(47.6001, -122.3000, ts + 6 * hourMs),
    ];
    const result = clusterLocations(points, 150, 3);
    expect(result.clusters).toHaveLength(1);
    // Dwell = min(5h, 2h) + 1h = 3h
    expect(result.clusters[0].dwellTimeHours).toBe(3);
  });

  it("returns clusters sorted by dwell time descending", () => {
    const ts = Date.UTC(2026, 2, 15, 0, 0, 0);
    const hourMs = 60 * 60 * 1000;
    // Cluster A: 2 hours dwell (3 points, 1h apart)
    const a = [
      pt(47.6000, -122.3000, ts),
      pt(47.6001, -122.3001, ts + 1 * hourMs),
      pt(47.6001, -122.3000, ts + 2 * hourMs),
    ];
    // Cluster B: 4 hours dwell (5 points, 1h apart)
    const b = [
      pt(48.0000, -121.0000, ts),
      pt(48.0001, -121.0001, ts + 1 * hourMs),
      pt(48.0001, -121.0000, ts + 2 * hourMs),
      pt(48.0000, -121.0001, ts + 3 * hourMs),
      pt(48.0000, -121.0000, ts + 4 * hourMs),
    ];
    const result = clusterLocations([...a, ...b], 150, 3);
    expect(result.clusters).toHaveLength(2);
    expect(result.clusters[0].dwellTimeHours).toBeGreaterThanOrEqual(
      result.clusters[1].dwellTimeHours,
    );
  });

  it("center is average of cluster points (rounded to 4 decimal places)", () => {
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const points = [
      pt(47.6000, -122.3000, ts),
      pt(47.6010, -122.3010, ts + 1000),
      pt(47.6020, -122.3020, ts + 2000),
    ];
    const result = clusterLocations(points, 500, 3);
    expect(result.clusters).toHaveLength(1);
    expect(result.clusters[0].center.latitude).toBe(47.601);
    expect(result.clusters[0].center.longitude).toBe(-122.301);
  });

  it("all noise when points are far apart", () => {
    const result = clusterLocations(
      [
        pt(0, 0, 1000),
        pt(10, 10, 2000),
        pt(20, 20, 3000),
      ],
      150,
      3,
    );
    expect(result.clusters).toHaveLength(0);
    expect(result.noiseCount).toBe(3);
    expect(result.summary).toBe("");
  });

  it("summary formats cluster dwell times", () => {
    const ts = Date.UTC(2026, 2, 15, 8, 0, 0);
    const hourMs = 60 * 60 * 1000;
    const points = Array.from({ length: 5 }, (_, i) =>
      pt(47.6000 + i * 0.0001, -122.3000, ts + i * hourMs),
    );
    const result = clusterLocations(points, 500, 3);
    expect(result.summary).toContain("Place 1:");
    expect(result.summary).toContain("h");
  });
});

// ─── formatClusterSummary ────────────────────────────────────────────────────

describe("formatClusterSummary", () => {
  it("returns empty string for no clusters", () => {
    expect(formatClusterSummary([])).toBe("");
  });

  it("formats single cluster", () => {
    const cluster: PlaceCluster = {
      id: "place_1",
      center: { latitude: 47.6, longitude: -122.3 },
      radiusMeters: 50,
      pointCount: 5,
      dwellTimeHours: 3.5,
      firstVisit: 1000,
      lastVisit: 5000,
    };
    expect(formatClusterSummary([cluster])).toBe("Place 1: 3.5h");
  });

  it("formats multiple clusters separated by comma", () => {
    const clusters: PlaceCluster[] = [
      {
        id: "place_1",
        center: { latitude: 47.6, longitude: -122.3 },
        radiusMeters: 50,
        pointCount: 5,
        dwellTimeHours: 5,
        firstVisit: 1000,
        lastVisit: 5000,
      },
      {
        id: "place_2",
        center: { latitude: 48.0, longitude: -121.0 },
        radiusMeters: 30,
        pointCount: 3,
        dwellTimeHours: 1.2,
        firstVisit: 6000,
        lastVisit: 7000,
      },
    ];
    expect(formatClusterSummary(clusters)).toBe("Place 1: 5h, Place 2: 1.2h");
  });
});
