# Location Clustering Algorithm

## Summary

Turn raw GPS breadcrumbs (stored in SQLite from background tracking) into a compact human-readable timeline: "Home Mon 10pm–Tue 8am (10h), Office Tue 9am–5pm (8h)". The output is optimized for pasting into an AI chat as context.

## Goals

- Summarize "where was I and for how long" from noisy GPS data
- Produce a token-efficient text summary for AI consumption
- Support user-defined known places (Home, Office, Gym, etc.)
- Handle 10,000+ points without noticeable delay on-device

## Non-Goals

- Route/path reconstruction between places
- Reverse geocoding (no network calls)
- Map visualization of clusters
- Real-time / streaming clustering

## Pipeline

### Step 1: Known Place Matching

If the user has defined named places (center + radius), each GPS point is checked against them first. Points within a place's radius are labeled with that place. Unmatched points proceed to Step 2.

This runs before generic clustering so that known places always take priority — a GPS point near "Home" won't get absorbed into an anonymous "place_3".

### Step 2: Grid-Based Clustering (O(n))

The function is called `dbscan` but is actually a grid-based union-find approach (not iterative DBSCAN):

1. **Grid assignment** — Divide the map into cells of `epsMeters` (default 50m). Cell width is latitude-aware: longitude cells are wider near the equator, narrower near the poles. Each point lands in exactly one cell.

2. **Union-find merge** — Adjacent occupied cells (8-connected: up/down/left/right/diagonals) are merged via union-find with path compression and rank balancing.

3. **Noise filter** — Merged groups with fewer than `minPts` (default 3) total points are labeled noise (-1). These become transit segments in the timeline.

**Why grid + union-find instead of real DBSCAN?** Real DBSCAN is O(n²) without a spatial index. Grid assignment is O(n) and union-find merges are effectively O(n). For 500 downsampled points this doesn't matter, but it's simpler to implement correctly and scales if we increase the cap.

### Step 3: Split Oversized Clusters

Any cluster whose p90 radius exceeds 500m gets re-gridded into 500m cells. This catches cases like highway driving that happen to form one large connected cluster. Each sub-cell with >= minPts points becomes its own cluster; smaller cells are dropped as noise.

### Step 4: Build Timeline (Run-Length Encoding)

Walk all points in time order. Consecutive points at the same cluster become one "visit". Then two cleanup passes:

- **Short transit absorption**: Transit segments shorter than 30 minutes are dropped (you walked to the mailbox and back — that's not a meaningful place change).
- **Same-place merge**: If the same place appears on both sides of a dropped transit gap, merge into one continuous visit.

### Step 5: Format Summary

Convert the timeline to a compact text string:

```
Home Mon 10pm–Tue 8am (10h), Office Tue 9am–5pm (8h), Gym Tue 6pm–7pm (1h)
```

Visits shorter than 30 minutes are filtered from the summary (as of 2026-03-26).

## Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `epsMeters` | 50 | Grid cell size — points within ~50m cluster together |
| `minPts` | 3 | Minimum points to form a cluster (fewer = noise) |
| `MAX_CLUSTER_RADIUS` | 500m | Clusters larger than this get split |
| `gapThresholdMs` | 30 min | Transit gaps shorter than this get absorbed |
| `MAX_CLUSTER_POINTS` | 500 | Downsample input before clustering |
| Summary min duration | 0.5h | Visits shorter than 30min excluded from summary text |

## Output Shape

`ClusterResult` contains three representations:

```typescript
{
  clusters: PlaceCluster[];  // Structured: center, radius, dwell time, point count
  timeline: PlaceVisit[];    // Ordered visits: place ID, start/end times, duration
  summary: string;           // Compact text (most token-efficient for AI)
  noiseCount: number;        // Points that didn't cluster
}
```

For AI export, only `summary` matters. The structured `clusters` and `timeline` are used by the in-app UI.

## Critique & Known Issues

### 1. Downsampling loses temporal resolution

We downsample to 500 points before clustering. With 30 days × ~50 points/day = 1,500 points, we keep 1 in 3. This means:

- **Short visits get erased**: A 20-minute coffee shop stop might have only 1-2 points, which after downsampling may have 0 — the visit vanishes entirely.
- **Fix**: Downsample per-day (keep N points per day) instead of globally, so recent days aren't starved by older data.

### 2. No time-awareness in clustering

The algorithm clusters purely by space. If you go to the same coffee shop Monday morning and Friday evening, those points merge into one cluster with one combined dwell time. The timeline handles this (separate visits), but the cluster's `dwellTimeHours` sums gaps between consecutive points regardless of multi-day spread.

- **Impact**: Cluster dwell time is misleading for places visited on multiple non-consecutive days.
- **Fix**: Cap the gap between consecutive points when computing dwell time (currently capped at 2h, which helps but doesn't fully solve multi-day).

### 3. Grid boundary artifacts

Points exactly on a grid cell boundary may split into different cells. Two points 1 meter apart could land in non-adjacent cells if they straddle a corner. The 8-connected merge mitigates this but doesn't fully eliminate it.

- **Impact**: Rare in practice. GPS noise (~5-20m) makes exact boundary hits unlikely with 50m cells.

### 4. Transit detection is primitive

"Transit" is just "noise points in time order." There's no distinction between:
- Walking to the mailbox (30 seconds)
- A 2-hour road trip
- GPS drift while stationary indoors

The 30-minute filter helps, but long transit (road trips) appears as a single "Transit" block with no detail about where you went.

- **Fix**: Could detect sustained movement (speed estimation from consecutive points) vs. GPS drift.

### 5. Known place radius is fixed

Each known place has a single radius. A large campus (university, airport) needs a big radius, but then nearby distinct places get swallowed.

- **Impact**: User has to choose between precision and coverage for large venues.

### 6. Summary text has no coordinates

The AI sees "Place 1 Tue 9am–5pm (8h)" but has no idea where Place 1 is geographically. For coaching ("you spent 8 hours somewhere new"), the AI can't distinguish "office" from "hospital" from "friend's house."

- **Fix**: Include lat/lng or reverse-geocoded name for unknown places in the summary text.

### 7. The structured export is bloated

The full `clusters` + `timeline` arrays are included in the JSON export even though only `summary` is useful for AI. This wastes tokens when the user pastes the full JSON.

- **Fix**: Export only `summary` string in the AI-facing export. Keep structured data for in-app UI only.
