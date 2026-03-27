/**
 * Grid-based GPS location clustering with union-find.
 * O(n) complexity — handles 10,000+ points instantly.
 * Pure functions — no device access, fully testable.
 */

import { type KnownPlace, labelPointsWithKnownPlaces, buildKnownPlaceClusters } from "./places";

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

export type PlaceVisit = {
  placeId: string; // "place_1", "place_2", or "transit"
  center: { latitude: number; longitude: number };
  startTime: string; // local time e.g. "Mon 10:00pm"
  endTime: string;
  durationHours: number;
};

export type ClusterResult = {
  clusters: PlaceCluster[];
  timeline: PlaceVisit[];
  noiseCount: number;
  summary: string;
};

// ─── Haversine Distance ──────────────────────────────────────────────────────

export { haversineDistance } from "./geo";
import { haversineDistance } from "./geo";

const DEG_TO_RAD = Math.PI / 180;

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
  // Use median for center (robust to outliers)
  const lats = points.map((p) => p.latitude).sort((a, b) => a - b);
  const lngs = points.map((p) => p.longitude).sort((a, b) => a - b);
  const medianLat = lats[Math.floor(lats.length / 2)];
  const medianLng = lngs[Math.floor(lngs.length / 2)];

  // Compute distances from median center, use p90 as radius (trims GPS outliers)
  const distances = points
    .map((p) => haversineDistance(medianLat, medianLng, p.latitude, p.longitude))
    .sort((a, b) => a - b);
  const p90Index = Math.min(Math.floor(distances.length * 0.9), distances.length - 1);
  const radius = distances[p90Index];

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
    center: { latitude: Math.round(medianLat * 10000) / 10000, longitude: Math.round(medianLng * 10000) / 10000 },
    radiusMeters: Math.round(radius),
    pointCount: points.length,
    dwellTimeHours: Math.round((dwellMs / (1000 * 60 * 60)) * 10) / 10,
    firstVisit,
    lastVisit,
  };
}

// ─── Timeline (Run-Length Encoding) ──────────────────────────────────────────

const DAY_NAMES_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

/** Format a UTC timestamp as local time: "Mon 10:00pm" */
export function formatLocalTime(ts: number): string {
  const d = new Date(ts);
  const day = DAY_NAMES_SHORT[d.getDay()];
  let h = d.getHours();
  const m = d.getMinutes();
  const period = h >= 12 ? "pm" : "am";
  h = h % 12 || 12;
  const time = m === 0 ? `${h}${period}` : `${h}:${String(m).padStart(2, "0")}${period}`;
  return `${day} ${time}`;
}

/**
 * Build a timeline of place visits from labeled points.
 * Walk through points in time order. Consecutive points at the same
 * cluster become one visit. Noise points become "transit" visits.
 * Short transit gaps (< gapThresholdMs) between same-place visits are merged.
 */
export function buildTimeline(
  points: LocationPoint[],
  labels: number[],
  clusters: PlaceCluster[],
  gapThresholdMs = 30 * 60 * 1000, // 30 minutes
): PlaceVisit[] {
  if (points.length === 0) return [];

  // Map union-find root labels to sorted cluster objects
  const labelToCluster = new Map<number, PlaceCluster>();
  const uniqueLabels = [...new Set(labels.filter((l) => l !== -1))];
  // Group points by label to match with clusters by point count + center
  const labelPoints = new Map<number, LocationPoint[]>();
  for (let i = 0; i < labels.length; i++) {
    if (labels[i] === -1) continue;
    if (!labelPoints.has(labels[i])) labelPoints.set(labels[i], []);
    labelPoints.get(labels[i])!.push(points[i]);
  }
  // Match labels to clusters by comparing centers
  for (const label of uniqueLabels) {
    const pts = labelPoints.get(label)!;
    const avgLat = pts.reduce((s, p) => s + p.latitude, 0) / pts.length;
    const avgLng = pts.reduce((s, p) => s + p.longitude, 0) / pts.length;
    // Find matching cluster by closest center
    let bestCluster = clusters[0];
    let bestDist = Infinity;
    for (const c of clusters) {
      const d = Math.abs(c.center.latitude - Math.round(avgLat * 10000) / 10000) +
                Math.abs(c.center.longitude - Math.round(avgLng * 10000) / 10000);
      if (d < bestDist) { bestDist = d; bestCluster = c; }
    }
    labelToCluster.set(label, bestCluster);
  }

  // Sort indices by timestamp
  const indices = Array.from({ length: points.length }, (_, i) => i);
  indices.sort((a, b) => points[a].timestamp - points[b].timestamp);

  // Walk through sorted points, building visits
  type RawVisit = { placeId: string; center: { latitude: number; longitude: number }; startTs: number; endTs: number };
  const rawVisits: RawVisit[] = [];

  let currentPlaceId: string | null = null;
  let currentCenter = { latitude: 0, longitude: 0 };
  let visitStart = 0;
  let visitEnd = 0;

  for (const idx of indices) {
    const label = labels[idx];
    const ts = points[idx].timestamp;
    let placeId: string;
    let center: { latitude: number; longitude: number };

    if (label === -1) {
      placeId = "transit";
      center = { latitude: points[idx].latitude, longitude: points[idx].longitude };
    } else {
      const cluster = labelToCluster.get(label)!;
      placeId = cluster.id;
      center = cluster.center;
    }

    if (placeId === currentPlaceId) {
      visitEnd = ts;
    } else {
      if (currentPlaceId !== null) {
        rawVisits.push({ placeId: currentPlaceId, center: currentCenter, startTs: visitStart, endTs: visitEnd });
      }
      currentPlaceId = placeId;
      currentCenter = center;
      visitStart = ts;
      visitEnd = ts;
    }
  }
  if (currentPlaceId !== null) {
    rawVisits.push({ placeId: currentPlaceId, center: currentCenter, startTs: visitStart, endTs: visitEnd });
  }

  // Merge: if same place appears with only short transit gap between, merge them
  const merged: RawVisit[] = [];
  for (const visit of rawVisits) {
    if (
      merged.length > 0 &&
      visit.placeId !== "transit" &&
      merged[merged.length - 1].placeId === visit.placeId &&
      visit.startTs - merged[merged.length - 1].endTs < gapThresholdMs
    ) {
      merged[merged.length - 1].endTs = visit.endTs;
    } else if (
      visit.placeId === "transit" &&
      merged.length > 0 &&
      visit.endTs - visit.startTs < gapThresholdMs
    ) {
      // Skip short transit segments — they'll get absorbed by the merge above
      // Only skip if it's short enough
      continue;
    } else {
      merged.push({ ...visit });
    }
  }

  // Convert to PlaceVisit
  return merged.map((v) => ({
    placeId: v.placeId,
    center: v.center,
    startTime: formatLocalTime(v.startTs),
    endTime: formatLocalTime(v.endTs),
    durationHours: Math.round(((v.endTs - v.startTs) / (1000 * 60 * 60)) * 10) / 10,
  }));
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
 * Split oversized clusters by gridding points into maxRadius-sized cells.
 * Each cell with >= minPts points becomes its own cluster.
 * O(n) — single pass, no recursion, guaranteed to produce sub-maxRadius groups.
 */
function splitOversized(
  points: LocationPoint[],
  maxRadius: number,
  _eps: number,
  minPts: number,
  out: LocationPoint[][],
): void {
  if (points.length < minPts) return;

  // Check if splitting is needed (p90 radius from median center)
  const lats = points.map((p) => p.latitude).sort((a, b) => a - b);
  const lngs = points.map((p) => p.longitude).sort((a, b) => a - b);
  const medLat = lats[Math.floor(lats.length / 2)];
  const medLng = lngs[Math.floor(lngs.length / 2)];
  const dists = points
    .map((p) => haversineDistance(medLat, medLng, p.latitude, p.longitude))
    .sort((a, b) => a - b);
  const p90 = dists[Math.min(Math.floor(dists.length * 0.9), dists.length - 1)];

  if (p90 <= maxRadius) {
    out.push(points);
    return;
  }

  // Grid points into maxRadius-sized cells
  const cellSize = maxRadius; // in meters
  const latCell = cellSize / 111000;
  const lngCell = cellSize / (111000 * Math.cos(medLat * DEG_TO_RAD));

  const cells = new Map<string, LocationPoint[]>();
  for (const p of points) {
    const cx = Math.floor(p.latitude / latCell);
    const cy = Math.floor(p.longitude / lngCell);
    const key = `${cx},${cy}`;
    if (!cells.has(key)) cells.set(key, []);
    cells.get(key)!.push(p);
  }

  for (const [, cellPoints] of cells) {
    if (cellPoints.length >= minPts) {
      out.push(cellPoints);
    }
    // Points in cells with < minPts are dropped as noise
  }
}

/**
 * Cluster location history into places.
 * When knownPlaces are provided, GPS points are matched against them first
 * (by distance within configured radius). Unmatched points fall through to
 * generic grid-based clustering.
 *
 * @param points Raw GPS points from SQLite
 * @param epsMeters Distance threshold for generic clustering (default 50m)
 * @param minPts Minimum points per cluster (default 3)
 * @param knownPlaces Optional array of user-defined known places
 */
export function clusterLocations(
  points: LocationPoint[],
  epsMeters = 50,
  minPts = 3,
  knownPlaces: KnownPlace[] = [],
): ClusterResult {
  if (points.length === 0) {
    return { clusters: [], timeline: [], noiseCount: 0, summary: "" };
  }

  // Step 1: Match points against known places
  const knownLabels = knownPlaces.length > 0
    ? labelPointsWithKnownPlaces(points, knownPlaces)
    : points.map(() => -1);

  // Separate matched and unmatched points
  const unmatchedPoints: LocationPoint[] = [];
  const unmatchedOriginalIndices: number[] = [];
  for (let i = 0; i < points.length; i++) {
    if (knownLabels[i] === -1) {
      unmatchedPoints.push(points[i]);
      unmatchedOriginalIndices.push(i);
    }
  }

  // Step 2: Run generic clustering on unmatched points only
  const genericLabels = unmatchedPoints.length > 0
    ? dbscan(unmatchedPoints, epsMeters, minPts)
    : [];

  // Group unmatched points by cluster label
  const groups = new Map<number, LocationPoint[]>();
  let noiseCount = 0;

  for (let i = 0; i < genericLabels.length; i++) {
    if (genericLabels[i] === -1) {
      noiseCount++;
      continue;
    }
    if (!groups.has(genericLabels[i])) groups.set(genericLabels[i], []);
    groups.get(genericLabels[i])!.push(unmatchedPoints[i]);
  }

  // Split any oversized groups (> maxRadiusMeters) by re-clustering with tighter eps
  const MAX_CLUSTER_RADIUS = 500;
  const finalGroups: LocationPoint[][] = [];
  for (const [, cPoints] of groups) {
    splitOversized(cPoints, MAX_CLUSTER_RADIUS, epsMeters, minPts, finalGroups);
  }

  // Build generic clusters with "place_N" IDs
  const genericClusters: PlaceCluster[] = [];
  let cIdx = 1;
  for (const cPoints of finalGroups) {
    genericClusters.push(buildCluster(`place_${cIdx++}`, cPoints));
  }
  genericClusters.sort((a, b) => b.dwellTimeHours - a.dwellTimeHours);
  genericClusters.forEach((c, i) => { c.id = `place_${i + 1}`; });

  // Step 3: Build known place clusters
  const knownClusters = knownPlaces.length > 0
    ? buildKnownPlaceClusters(points, knownLabels, knownPlaces)
    : [];

  // Combine: known place clusters first, then generic
  const allClusters = [...knownClusters, ...genericClusters];

  // Step 4: Build combined labels for timeline
  // We need a single label array across all points that maps to allClusters
  // Use negative numbers offset for known place clusters to avoid collision with generic labels
  const KNOWN_LABEL_OFFSET = 1000000; // large offset to avoid collision
  const combinedLabels: number[] = new Array(points.length);

  // Build reverse lookup: original index → unmatched index (O(n) instead of O(n^2))
  const originalToUnmatched = new Map<number, number>();
  for (let i = 0; i < unmatchedOriginalIndices.length; i++) {
    originalToUnmatched.set(unmatchedOriginalIndices[i], i);
  }

  for (let i = 0; i < points.length; i++) {
    if (knownLabels[i] !== -1) {
      // Point matched a known place — use offset label
      combinedLabels[i] = KNOWN_LABEL_OFFSET + knownLabels[i];
    } else {
      const unmatchedIdx = originalToUnmatched.get(i) ?? -1;
      if (unmatchedIdx !== -1 && genericLabels[unmatchedIdx] !== -1) {
        combinedLabels[i] = genericLabels[unmatchedIdx];
      } else {
        combinedLabels[i] = -1;
      }
    }
  }

  const timeline = buildTimeline(points, combinedLabels, allClusters);
  const summary = formatTimelineSummary(timeline);

  return { clusters: allClusters, timeline, noiseCount, summary };
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

/**
 * Format timeline as run-length encoded summary.
 * "Place 1 Mon 10pm–Tue 8am (10h), Place 2 Tue 9am–5pm (8h), ..."
 */
export function formatTimelineSummary(timeline: PlaceVisit[]): string {
  if (timeline.length === 0) return "";
  return timeline
    .filter((v) => v.durationHours >= 0.5)
    .map((v) => {
      const label = v.placeId === "transit" ? "Transit" : v.placeId.replace("_", " ").replace(/\b\w/g, (c) => c.toUpperCase());
      return `${label} ${v.startTime}\u2013${v.endTime} (${v.durationHours}h)`;
    })
    .join(", ");
}
