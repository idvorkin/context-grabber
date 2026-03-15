/**
 * DBSCAN-based GPS location clustering.
 * Pure functions — no device access, fully testable.
 */

// ─── Types ───────────────────────────────────────────────────────────────────

export type LocationPoint = {
  latitude: number;
  longitude: number;
  accuracy: number | null;
  timestamp: number;
};

export type PlaceCluster = {
  id: string;
  center: { latitude: number; longitude: number };
  radiusMeters: number;
  pointCount: number;
  dwellTimeHours: number;
  firstVisit: number; // UTC unix ms
  lastVisit: number; // UTC unix ms
};

export type ClusterResult = {
  clusters: PlaceCluster[];
  noiseCount: number;
  summary: string;
};

// ─── Haversine Distance ──────────────────────────────────────────────────────

const DEG_TO_RAD = Math.PI / 180;
const EARTH_RADIUS_M = 6371000;

/** Haversine distance between two lat/lng points in meters. */
export function haversineDistance(
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

// ─── DBSCAN ──────────────────────────────────────────────────────────────────

const UNVISITED = 0;
const NOISE = -1;

/**
 * DBSCAN clustering on GPS points.
 * Returns cluster labels for each point: -1 = noise, 0+ = cluster ID.
 */
export function dbscan(
  points: LocationPoint[],
  epsMeters: number,
  minPts: number,
): number[] {
  const n = points.length;
  const labels = new Array<number>(n).fill(UNVISITED);
  let clusterId = 0;

  // Grid-based spatial index for fast neighbor lookups
  // Cell size ~epsMeters in degrees (rough: 1 degree lat ≈ 111km)
  const cellSize = epsMeters / 111000;
  const grid = new Map<string, number[]>();
  for (let i = 0; i < n; i++) {
    const cx = Math.floor(points[i].latitude / cellSize);
    const cy = Math.floor(points[i].longitude / cellSize);
    const key = `${cx},${cy}`;
    if (!grid.has(key)) grid.set(key, []);
    grid.get(key)!.push(i);
  }

  // Only compare points in same or adjacent grid cells
  const neighbors: number[][] = new Array(n);
  for (let i = 0; i < n; i++) {
    neighbors[i] = [];
    const cx = Math.floor(points[i].latitude / cellSize);
    const cy = Math.floor(points[i].longitude / cellSize);
    for (let dx = -1; dx <= 1; dx++) {
      for (let dy = -1; dy <= 1; dy++) {
        const cell = grid.get(`${cx + dx},${cy + dy}`);
        if (!cell) continue;
        for (const j of cell) {
          if (i === j) continue;
          const d = haversineDistance(
            points[i].latitude, points[i].longitude,
            points[j].latitude, points[j].longitude,
          );
          if (d <= epsMeters) {
            neighbors[i].push(j);
          }
        }
      }
    }
  }

  for (let i = 0; i < n; i++) {
    if (labels[i] !== UNVISITED) continue;

    const nbrs = neighbors[i];
    if (nbrs.length + 1 < minPts) {
      // +1 includes the point itself
      labels[i] = NOISE;
      continue;
    }

    // Start a new cluster
    labels[i] = clusterId;
    const queue = [...nbrs];
    const visited = new Set<number>([i]);

    while (queue.length > 0) {
      const j = queue.shift()!;
      if (visited.has(j)) continue;
      visited.add(j);

      if (labels[j] === NOISE) {
        // Border point — add to cluster
        labels[j] = clusterId;
      }

      if (labels[j] !== UNVISITED) continue;
      labels[j] = clusterId;

      const jNbrs = neighbors[j];
      if (jNbrs.length + 1 >= minPts) {
        // Core point — expand
        for (const k of jNbrs) {
          if (!visited.has(k)) queue.push(k);
        }
      }
    }

    clusterId++;
  }

  return labels;
}

// ─── Cluster Statistics ──────────────────────────────────────────────────────

function buildCluster(id: string, points: LocationPoint[]): PlaceCluster {
  const avgLat = points.reduce((s, p) => s + p.latitude, 0) / points.length;
  const avgLng = points.reduce((s, p) => s + p.longitude, 0) / points.length;

  let maxDist = 0;
  for (const p of points) {
    const d = haversineDistance(avgLat, avgLng, p.latitude, p.longitude);
    if (d > maxDist) maxDist = d;
  }

  const timestamps = points.map((p) => p.timestamp).sort((a, b) => a - b);
  const firstVisit = timestamps[0];
  const lastVisit = timestamps[timestamps.length - 1];

  // Estimate dwell time: sum gaps between consecutive points (capped at 2hrs per gap)
  const MAX_GAP_MS = 2 * 60 * 60 * 1000;
  let dwellMs = 0;
  for (let i = 1; i < timestamps.length; i++) {
    const gap = timestamps[i] - timestamps[i - 1];
    dwellMs += Math.min(gap, MAX_GAP_MS);
  }

  return {
    id,
    center: { latitude: Math.round(avgLat * 10000) / 10000, longitude: Math.round(avgLng * 10000) / 10000 },
    radiusMeters: Math.round(maxDist),
    pointCount: points.length,
    dwellTimeHours: Math.round((dwellMs / (1000 * 60 * 60)) * 10) / 10,
    firstVisit,
    lastVisit,
  };
}

// ─── Main Entry Point ────────────────────────────────────────────────────────

/**
 * Cluster location history into places.
 * @param points Raw GPS points from SQLite
 * @param epsMeters Distance threshold (default 150m)
 * @param minPts Minimum points per cluster (default 3)
 */
export function clusterLocations(
  points: LocationPoint[],
  epsMeters = 150,
  minPts = 3,
): ClusterResult {
  if (points.length === 0) {
    return { clusters: [], noiseCount: 0, summary: "" };
  }

  const labels = dbscan(points, epsMeters, minPts);

  // Group points by cluster
  const groups = new Map<number, LocationPoint[]>();
  let noiseCount = 0;

  for (let i = 0; i < labels.length; i++) {
    if (labels[i] === NOISE) {
      noiseCount++;
      continue;
    }
    if (!groups.has(labels[i])) groups.set(labels[i], []);
    groups.get(labels[i])!.push(points[i]);
  }

  // Build clusters, sorted by dwell time descending
  const clusters: PlaceCluster[] = [];
  for (const [cid, cPoints] of groups) {
    clusters.push(buildCluster(`place_${cid + 1}`, cPoints));
  }
  clusters.sort((a, b) => b.dwellTimeHours - a.dwellTimeHours);

  const summary = formatClusterSummary(clusters);

  return { clusters, noiseCount, summary };
}

// ─── Summary Formatting ──────────────────────────────────────────────────────

/**
 * Format clusters as a human-readable summary.
 * Labels top clusters as Place 1, Place 2, etc.
 */
export function formatClusterSummary(clusters: PlaceCluster[]): string {
  if (clusters.length === 0) return "";
  return clusters
    .map((c, i) => `Place ${i + 1}: ${c.dwellTimeHours}h`)
    .join(", ");
}
