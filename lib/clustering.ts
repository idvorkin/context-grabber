/**
 * Grid-based GPS location clustering with union-find.
 * O(n) complexity — handles 10,000+ points instantly.
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

// ─── Union-Find ──────────────────────────────────────────────────────────────

class UnionFind {
  parent: number[];
  rank: number[];
  constructor(n: number) {
    this.parent = Array.from({ length: n }, (_, i) => i);
    this.rank = new Array(n).fill(0);
  }
  find(x: number): number {
    while (this.parent[x] !== x) {
      this.parent[x] = this.parent[this.parent[x]]; // path compression
      x = this.parent[x];
    }
    return x;
  }
  union(a: number, b: number): void {
    const ra = this.find(a), rb = this.find(b);
    if (ra === rb) return;
    if (this.rank[ra] < this.rank[rb]) { this.parent[ra] = rb; }
    else if (this.rank[ra] > this.rank[rb]) { this.parent[rb] = ra; }
    else { this.parent[rb] = ra; this.rank[ra]++; }
  }
}

// ─── Grid-based Clustering ───────────────────────────────────────────────────

/**
 * Cluster GPS points by assigning to grid cells, then merging adjacent
 * occupied cells via union-find. O(n) total — no pairwise distances needed.
 *
 * Cell size = epsMeters, so all points in the same cell are within eps.
 * Adjacent cells are merged so clusters can span cell boundaries.
 * Cells with fewer than minPts points are treated as noise.
 */
export function dbscan(
  points: LocationPoint[],
  epsMeters: number,
  minPts: number,
): number[] {
  const n = points.length;
  if (n === 0) return [];

  // Compute latitude-aware cell sizes
  const latitudes = points.map((p) => p.latitude).sort((a, b) => a - b);
  const medianLat = latitudes[Math.floor(latitudes.length / 2)];
  const latCellSize = epsMeters / 111000;
  const lngCellSize = epsMeters / (111000 * Math.cos(medianLat * DEG_TO_RAD));

  // Assign each point to a grid cell
  const cellKeys: string[] = new Array(n);
  const cellMap = new Map<string, number[]>(); // cell key → point indices
  for (let i = 0; i < n; i++) {
    const cx = Math.floor(points[i].latitude / latCellSize);
    const cy = Math.floor(points[i].longitude / lngCellSize);
    const key = `${cx},${cy}`;
    cellKeys[i] = key;
    if (!cellMap.has(key)) cellMap.set(key, []);
    cellMap.get(key)!.push(i);
  }

  // Assign a union-find ID to each occupied cell
  const cellList = Array.from(cellMap.keys());
  const cellIdMap = new Map<string, number>();
  for (let i = 0; i < cellList.length; i++) {
    cellIdMap.set(cellList[i], i);
  }
  const uf = new UnionFind(cellList.length);

  // Merge adjacent occupied cells (8-connected neighbors)
  for (const key of cellList) {
    const [cxStr, cyStr] = key.split(",");
    const cx = parseInt(cxStr), cy = parseInt(cyStr);
    const cellId = cellIdMap.get(key)!;
    for (let dx = -1; dx <= 1; dx++) {
      for (let dy = -1; dy <= 1; dy++) {
        if (dx === 0 && dy === 0) continue;
        const neighborKey = `${cx + dx},${cy + dy}`;
        const neighborId = cellIdMap.get(neighborKey);
        if (neighborId !== undefined) {
          uf.union(cellId, neighborId);
        }
      }
    }
  }

  // Group cells by their root, count total points per group
  const groupPoints = new Map<number, number>(); // root → total point count
  for (const key of cellList) {
    const cellId = cellIdMap.get(key)!;
    const root = uf.find(cellId);
    const pts = cellMap.get(key)!.length;
    groupPoints.set(root, (groupPoints.get(root) ?? 0) + pts);
  }

  // Label each point: -1 for noise (group has < minPts), else group root
  const labels = new Array<number>(n);
  for (let i = 0; i < n; i++) {
    const cellId = cellIdMap.get(cellKeys[i])!;
    const root = uf.find(cellId);
    const totalPts = groupPoints.get(root)!;
    labels[i] = totalPts >= minPts ? root : -1;
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

const MAX_CLUSTER_POINTS = 500;

/**
 * Downsample points by keeping every Nth point to stay under limit.
 * Always keeps the first and last point.
 */
export function downsample(points: LocationPoint[], maxPoints = MAX_CLUSTER_POINTS): LocationPoint[] {
  if (points.length <= maxPoints) return points;
  const step = points.length / maxPoints;
  const result: LocationPoint[] = [];
  for (let i = 0; i < maxPoints; i++) {
    result.push(points[Math.floor(i * step)]);
  }
  if (result[result.length - 1] !== points[points.length - 1]) {
    result[result.length - 1] = points[points.length - 1];
  }
  return result;
}

/**
 * Cluster location history into places.
 * Uses grid-based union-find: O(n) complexity.
 * @param points Raw GPS points from SQLite
 * @param epsMeters Distance threshold (default 50m)
 * @param minPts Minimum points per cluster (default 3)
 */
export function clusterLocations(
  points: LocationPoint[],
  epsMeters = 50,
  minPts = 3,
): ClusterResult {
  if (points.length === 0) {
    return { clusters: [], noiseCount: 0, summary: "" };
  }

  const labels = dbscan(points, epsMeters, minPts);

  // Group points by cluster label
  const groups = new Map<number, LocationPoint[]>();
  let noiseCount = 0;

  for (let i = 0; i < labels.length; i++) {
    if (labels[i] === -1) {
      noiseCount++;
      continue;
    }
    if (!groups.has(labels[i])) groups.set(labels[i], []);
    groups.get(labels[i])!.push(points[i]);
  }

  // Build clusters, sorted by dwell time descending
  const clusters: PlaceCluster[] = [];
  let cIdx = 1;
  for (const [, cPoints] of groups) {
    clusters.push(buildCluster(`place_${cIdx++}`, cPoints));
  }
  clusters.sort((a, b) => b.dwellTimeHours - a.dwellTimeHours);

  // Renumber IDs after sorting
  clusters.forEach((c, i) => { c.id = `place_${i + 1}`; });

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
