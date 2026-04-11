# Location Clustering v2 — Design Spec

## Problem

Turn ~1,500 sparse GPS breadcrumbs (30 days of background tracking, ~50 points/day) into a token-efficient timeline for AI life coaching:

```
Home Mon 10pm-Tue 8am (10h), Office Tue 9am-5pm (8h), Gym Tue 6pm-7pm (1h)
```

Runs on-device. No network. No heavy libraries. Must handle GPS noise (5m outdoor, 50-100m indoor), irregular sampling, and multi-day data.

## Current Implementation Critique

The existing algorithm (grid + union-find spatial clustering, then RLE timeline) has six structural problems:

1. **Spatial-only clustering conflates distinct visits.** Going to the same coffee shop Monday and Friday produces one cluster. The timeline separates them, but the cluster-level dwell time is meaningless (it sums across days). This is confusing because the cluster object claims to represent "a place" but its dwell time represents "all time ever spent there."

2. **Downsampling destroys short visits.** Global downsampling to 500 points before clustering means a 20-minute coffee stop (1-2 points) may get entirely removed. The downsampling is uniform across time, so 30 days of data starves recent days.

3. **Transit is a black hole.** Any point not in a cluster becomes "transit" with no further detail. A 3-hour road trip and a 30-second walk to the mailbox are indistinguishable. The AI coach has no idea you drove to Portland.

4. **Unknown places have no geographic identity.** The AI sees "Place 1 Tue 9am-5pm" but cannot distinguish a hospital from a restaurant. Without coordinates or any geographic hint, the coaching value is low.

5. **Timeline label matching is fragile.** The `buildTimeline` function matches union-find labels to cluster objects by comparing rounded center coordinates. This indirect mapping can misassign points when two clusters have similar centers (e.g., adjacent buildings).

6. **Dwell time estimation is unreliable.** Summing gaps between consecutive timestamps (capped at 2h) breaks down when sampling is sparse. If you get one GPS point at 9am and another at 11:30am, the 2h cap cuts the real 2.5h visit short. But if you get one point at 9am and another at 3pm (you were stationary so the phone didn't report), the 2h cap is correct. The algorithm can't tell the difference.

## Design

### Core Insight

The right mental model is not "cluster points into places, then build a timeline." It is: **walk through time, and at each moment decide whether you are stationary or moving.** Places emerge from periods of being stationary. The timeline IS the primary data structure, not a derived view.

### Pipeline Overview

```
Raw GPS points (sorted by time)
  |
  v
[1] Known Place Labeling ---- match each point to user-defined places
  |
  v
[2] Stationary Detection ---- identify "stays" where you weren't moving
  |
  v
[3] Stay Merging ------------ merge nearby stays at the same location
  |
  v
[4] Place Assignment -------- assign a place ID to each stay
  |
  v
[5] Transit Annotation ------ characterize gaps between stays
  |
  v
[6] Summary Formatting ------ produce token-efficient text
```

No downsampling. 1,500 points is small enough to process directly. Even 5,000 points is fine — the algorithm is O(n log n) due to sorting, O(n) for everything else.

### Step 1: Known Place Labeling

Unchanged from current implementation. For each point, check if it falls within any user-defined known place (name + center + radius). This is O(n * k) where k is the number of known places (typically < 20).

**One change:** when a point matches a known place, tag it with the place name immediately. Do not use a separate label array — attach the label to the point directly (or use a parallel array indexed identically). This eliminates the fragile label-to-cluster matching in the current implementation.

### Step 2: Stationary Detection (the core algorithm)

Walk through points in time order. Maintain a sliding window of recent points. A "stay" begins when consecutive points remain within a spatial threshold, and ends when a point moves outside it.

```
Algorithm: Sequential Stay Detection

Input: points sorted by timestamp
Parameters:
  STAY_RADIUS = 100m       -- max spread of a stationary period
  MIN_STAY_DURATION = 5min -- minimum time to count as a stay
  MAX_POINT_GAP = 4h       -- if gap between points exceeds this, end current stay

State:
  anchor = null             -- center of current candidate stay
  stayPoints = []           -- points in current candidate stay
  stays = []                -- completed stays

For each point p (in time order):
  if anchor is null:
    Start new candidate: anchor = p, stayPoints = [p]
    continue

  gap = p.timestamp - stayPoints[last].timestamp
  dist = haversine(anchor, p)

  if gap > MAX_POINT_GAP:
    Finalize current stay (if long enough), start new candidate at p
  else if dist <= STAY_RADIUS:
    Add p to stayPoints
    Update anchor to centroid of stayPoints (rolling average)
  else:
    Finalize current stay (if long enough)
    Start new candidate at p

Finalize: if duration(stayPoints) >= MIN_STAY_DURATION → emit stay
```

**Why this instead of grid clustering:**
- Naturally produces temporal segments (stays), not spatial blobs
- Handles the "same coffee shop on different days" case correctly — two separate stays
- No grid boundary artifacts
- No union-find complexity
- Directly answers "where was I and when" without a second pass
- O(n) single pass

**Why 100m STAY_RADIUS (not 50m):**
- Indoor GPS accuracy is 50-100m. A 50m radius means GPS drift alone can break a stay apart.
- 100m covers a typical building footprint (house, office, restaurant).
- Most distinct places people visit are >200m apart. 100m won't merge "office" and "restaurant across the street" unless they're in the same building complex.
- Known places with custom radii handle the case where 100m is wrong for a specific location.

**Why 4h MAX_POINT_GAP:**
- Background significant-change monitoring may not report for hours when you're stationary (the phone has no reason to wake up).
- You sleep 8 hours at home, but the phone might report a point at 11pm and the next at 6am. With a 2h gap cap, you'd split one "Home overnight" stay into fragments.
- 4h is generous but still catches genuine transitions. If there's a 4h gap AND you moved 500m, that's a real place change.
- However, if there's a 4h gap and the next point is still within STAY_RADIUS, assume you stayed put. The gap itself doesn't end a stay — only gap + movement does.

**Revised logic for gaps:**

```
if gap > MAX_POINT_GAP:
  if dist <= STAY_RADIUS:
    // Still at same place after long gap — extend the stay
    Add p to stayPoints
  else:
    // Long gap AND moved — end previous stay, start new one
    Finalize current stay
    Start new candidate at p
```

### Step 3: Stay Merging

After detecting stays, merge consecutive stays that are at the same location (within STAY_RADIUS of each other's centroids) with only short gaps or transit between them.

```
For each pair of consecutive stays (A, B):
  if haversine(A.centroid, B.centroid) <= STAY_RADIUS:
    if gap between A.end and B.start < MERGE_GAP (30 min):
      Merge A and B into one stay
```

This handles the case where GPS drift briefly makes you appear to leave and return. It also handles "walked to the mailbox and came back."

### Step 4: Place Assignment

Each stay needs a place ID. Priority order:

1. **Known place match:** If the stay's centroid is within a known place's radius, use that place's name. If multiple known places match, use the closest.

2. **Cluster repeat visits:** Group stays by spatial proximity. If two stays on different days have centroids within STAY_RADIUS, they get the same anonymous place ID. Use a simple greedy approach:
   - Maintain a list of "discovered places" (centroid + ID).
   - For each stay without a known place label, check if any discovered place is within STAY_RADIUS.
   - If yes, assign that place ID. Update the discovered place's centroid (rolling average).
   - If no, create a new discovered place.

   This means "Place 1" in Monday's timeline and "Place 1" in Friday's timeline refer to the same physical location.

3. **ID format:** Known places use their name ("Home", "Office"). Discovered places use a stable numbering: "Place 1", "Place 2", etc., ordered by first-visit time.

### Step 5: Transit Annotation

Gaps between stays are transit. For each transit gap:

- **Duration:** end of previous stay to start of next stay.
- **Distance:** haversine between previous stay centroid and next stay centroid.
- **Speed estimate:** distance / duration.

Include transit in the timeline only if duration >= 15 minutes (skip micro-transitions).

For the AI summary, transit segments longer than 1 hour get included with distance:

```
Home Mon 10pm-Tue 8am (10h), Transit 45min/15km, Office Tue 9am-5pm (8h)
```

Short transit (< 1h) is omitted from the summary but kept in the structured timeline.

### Step 6: Summary Formatting

**Daily grouping.** The current format produces one flat list across 30 days. For a 30-day window, that's overwhelming. Group by day:

```
Mon Mar 25: Home 10pm-Tue 8am (10h)
Tue Mar 26: Office 9am-5pm (8h), Gym 6pm-7pm (1h)
```

**Week-level rollup.** For the full 30-day export, also produce a weekly summary:

```
This week: Home 62h, Office 38h, Gym 4h, Other 2h
Last week: Home 58h, Office 40h, Gym 6h
```

**Format selection.** Provide two summary levels:
- `summaryRecent` — detailed timeline for last 3 days (the AI cares most about recent behavior)
- `summaryWeekly` — weekly rollup for the full retention window

**Token budget.** A 30-day detailed timeline at ~60 chars per visit, ~5 visits per day = ~9,000 chars = ~2,500 tokens. That's too much. The weekly rollup for 4 weeks is ~200 chars = ~50 tokens. The 3-day detail is ~900 chars = ~250 tokens. Total: ~300 tokens, which is reasonable.

### Output Shape

```typescript
type Stay = {
  placeId: string;          // "Home", "Office", "Place 1"
  centroid: { lat: number; lng: number };
  startTime: number;        // UTC ms
  endTime: number;          // UTC ms
  durationMinutes: number;
  pointCount: number;
};

type TransitSegment = {
  startTime: number;
  endTime: number;
  durationMinutes: number;
  distanceKm: number;
  fromPlaceId: string;
  toPlaceId: string;
};

type ClusterResult = {
  stays: Stay[];
  transit: TransitSegment[];
  summaryRecent: string;    // last 3 days, detailed timeline
  summaryWeekly: string;    // full window, weekly rollup
};
```

## Merging a new point into a known place

When a user manually assigns a stay to an existing known place (e.g., via the "Name this place" flow in the Location Detail Sheet — see [`2026-04-11-places-breakdown-gaps-and-naming-design.md`](2026-04-11-places-breakdown-gaps-and-naming-design.md)), the known place's disc must grow to cover the new stay's centroid. Use the minimum bounding circle of `(existing disc) ∪ (new centroid)` plus a 50m buffer — strictly tighter than naively enlarging the radius by `distance + buffer`.

```
d = haversine(existing.center, newCentroid)  // meters
if d <= existing.radiusMeters:
    // new point already inside (shouldn't occur for an unmatched Place N, but guard anyway)
    return existing unchanged

shift     = (d - existing.radiusMeters) / 2                 // meters to slide center toward new point
t         = shift / d                                       // fraction along the line, always in [0, 0.5)
newCenter = lerp(existing.center, newCentroid, t)           // flat-plane OK at <1km distances
newRadius = (d + existing.radiusMeters) / 2 + 50            // half the span + buffer
```

**Why this rule:**
- Preserves all points in the old radius — the new circle is a superset of the old.
- Self-corrects a sloppy original centroid: if the user's first "Home" coord was off, the first merge pulls it toward reality.
- No visit-count or history weighting — the geometry handles it.
- Pure function; lives in `lib/places.ts` as `mergePlaceCircle(existing, newCentroid, buffer=50)`.

**Examples:**

| existing.r | d (new distance) | shift | newRadius |
|---|---|---|---|
| 100m | 110m | 5m  | 155m |
| 100m | 150m | 25m | 175m |
| 100m | 200m | 50m | 200m |
| 50m  | 120m | 35m | 135m |

## Consecutive same-place merging

### Problem

iOS suppresses background GPS deliveries when the phone is truly stationary (motion-coprocessor confirmed). A phone parked on a nightstand at home from 11 pm to 5 am will report zero breadcrumbs across that window. The clustering pipeline sees the last evening Home point, then nothing, then a fresh morning Home point — and produces **two separate Home stays** with a multi-hour gap between them.

The same effect happens mid-day too: a 4-hour stretch parked at Work with the phone on the desk produces zero new GPS pings, so a single Work stay can fragment into a "Work" + "(no data)" + "Work" sandwich whenever a stray ping later interrupts the silence.

`mergeStays` was supposed to coalesce these, but it caps merges at `MERGE_GAP = 30 min`. Anything longer survives as fragmented stays, and the gap bleeds into the per-day breakdown as `noData` even though the user demonstrably hadn't moved.

We do not want to relax `MERGE_GAP` globally — anonymous mid-day clusters that happen to be close in time should still be allowed to be distinct visits. We want a narrowly-targeted rule that fires only when we have positive evidence the user was at the *same place* before and after the gap.

### Rule

After `assignPlaces` runs, post-process the stay list with a single pass:

> For every pair of stays that are **consecutive in the sorted stay list** and share the same `placeId`, merge them into one stay spanning `[prev.startTime, curr.endTime]`. The merged centroid is the point-count-weighted average of the two; the merged `pointCount` is the sum.

The single gating condition is **same `placeId`**. The "consecutive in the sorted stay list" wording means there is no other stay between them — which is the entire load-bearing claim. If the user had visited a different place in the gap, that visit would itself be a stay in the list, breaking consecutiveness. So:

- **`Home → (gap) → Home`** with no other stay between them → merge. The user was at Home the whole time; iOS just stopped reporting.
- **`Home → Bar → Home`** → no merge. The Bar visit broke consecutiveness.
- **`Work → (gap) → Work`** mid-day → merge. Same logic as overnight Home.
- **`Home → (gap) → Work`** → no merge. Different `placeId`.

Same `placeId` covers both known places (Home, Work, Milstead) and auto-discovered ones (Place 5), since `assignPlaces` deduplicates discovered clusters by centroid before this pass runs.

The pass cascades: if Mon-evening Home merges with Tue-morning Home, and the result then merges with a Wed-morning Home (because the user was home for a multi-day break), all three collapse into a single multi-day stay.

### Why this is safe

- **Strict same-place gating.** The merged stay claims the user was at one specific place across the gap. If they actually went somewhere else, the clustering would have produced a stay for that visit, breaking the consecutiveness check. Our only failure mode is "user went somewhere for less than `MIN_STAY_DURATION` (5 min) and the phone happened to ping enough to record it as a separate stay, just not enough to form a stay" — vanishingly rare and not worth gating against.
- **Geometry already validated upstream.** Both stays already passed `assignPlaces`'s known-place radius check or were assigned the same auto-discovered cluster. The merge does not relax those checks; it only relaxes the time-gap cap.
- **No information loss for the AI export.** A single 9 pm-to-7 am Home stay is more accurate than "9 pm-11 pm Home / 9h gap / 5 am-7 am Home" — the AI gets a better picture.

### Where it sits in the pipeline

```
points → labelPointsWithKnownPlaces → detectStays → mergeStays
       → assignPlaces → mergeConsecutiveSamePlace (NEW) → buildTransit
```

It runs after `assignPlaces` so it has access to `placeId`. It runs before `buildTransit` so the (now-removed) inter-stay gap doesn't appear as a phantom transit segment.

### Edge cases

| Case | Handling |
|---|---|
| 3-day camping at Place 8 | Cascading merge collapses all 3 nights into one stay |
| Home → brief Bar → Home | Bar breaks consecutiveness — no merge |
| Home Wed evening → Work Thu morning | Different `placeId` → no merge |
| Home stay actually ends at 11:30 pm and next stay is Home 5 am | Same `placeId`, consecutive → merge |
| Today's last stay with no successor yet | No `curr` to consider — leave alone |
| Mid-day Work parked stationary 4h → ping → another Work stay | Same `placeId`, consecutive → merge |

### Acceptance criteria

1. Two consecutive stays sharing a `placeId` are merged into one regardless of the gap between them.
2. Two consecutive stays with different `placeId` are never merged by this rule, regardless of gap.
3. Cascading is allowed: three same-place stays separated by intermediate gaps (with no other stays between any pair) collapse into one.
4. The merged stay's `pointCount` equals the sum of the originals.
5. The merged stay's centroid is the point-count-weighted average of the originals.
6. The merged stay's time span is `[firstOriginal.startTime, lastOriginal.endTime]`.
7. After merging, the displayed Thursday in the user's real fixture data shows Home as a single multi-hour stay covering the 5h23m morning gap, not as a tiny 15-minute fragment.

## Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| STAY_RADIUS | 100m | Covers building footprint + indoor GPS noise |
| MIN_STAY_DURATION | 5 min | Filters GPS drift "visits" but keeps real short stops |
| MAX_POINT_GAP | 4h | Accommodates sleep/stationary periods without splitting stays |
| MERGE_GAP | 30 min | Absorbs mailbox walks and GPS drift departures |
| MIN_TRANSIT_DISPLAY | 15 min | Hides micro-transitions in timeline |
| MIN_TRANSIT_SUMMARY | 1h | Only major transit in the text summary |
| RECENT_DAYS | 3 | Detailed timeline window |
| DISCOVERED_PLACE_RADIUS | 100m | Same as STAY_RADIUS for consistency |

## Edge Cases

### GPS drift indoors

**Scenario:** You sit at your desk for 8 hours. GPS reports your position with 50-100m noise. Points wander within a ~80m circle.

**Handling:** STAY_RADIUS of 100m contains the drift. The centroid converges to the true position as points accumulate. No special filtering needed.

**Pathological case:** GPS occasionally reports a wildly wrong position (200m off, then snaps back). This creates a false departure and return. The 30-minute merge gap absorbs it — as long as the bad point doesn't persist for >30 minutes, the stay is preserved.

### Multi-day visits (home overnight)

**Scenario:** You're home from 6pm Monday to 8am Tuesday. Background tracking gives you a point at 6pm, maybe 11pm (phone wakes briefly), and 7am.

**Handling:** The revised gap logic (Step 2) checks distance even across long gaps. 6pm to 11pm is 5h but within STAY_RADIUS, so the stay extends. 11pm to 7am is 8h but still within STAY_RADIUS, so it extends again. One continuous "Home" stay from 6pm to 8am.

**Limitation:** The stay's duration is measured from first to last point. If the first point is at 6pm and the last is at 7am, we report 13h. But you might have arrived at 5:30pm and left at 8am. The sparse sampling means we undercount by up to one sampling interval at each end.

### Short visits (coffee shop)

**Scenario:** You stop at a coffee shop for 20 minutes. You get 1-2 GPS points.

**Handling:** With MIN_STAY_DURATION of 5 minutes, even a single point pair 5 minutes apart registers as a stay. A single isolated point (no second point within 5 minutes) is treated as transit noise.

**Tradeoff:** Setting MIN_STAY_DURATION lower catches more short visits but also catches more GPS artifacts. 5 minutes is the sweet spot — a real "stop" usually involves at least 5 minutes, and GPS drift usually moves on faster.

### Large venues (airport, university campus)

**Scenario:** An airport has a 2km footprint. You spend 3 hours there, walking between gates. Your GPS trail spans 800m.

**Handling:** The 100m STAY_RADIUS will break this into multiple short stays at different parts of the airport. Without a known place defined, the AI sees "Place 7 2pm-2:40pm, Place 8 2:45pm-3:10pm, Place 9 3:15pm-4pm."

**Mitigation:** Users can define the airport as a known place with a 1000m radius. The known place check in Step 1 labels all points, and Step 4 assigns the known name.

**Design choice:** We do NOT auto-detect large venues. The algorithm is designed for the common case (home, office, gym, restaurant) where 100m works well. Large venues are rare enough that explicit known-place configuration is the right answer.

### Commute (regular transit)

**Scenario:** 30-minute drive to work, every weekday. GPS gives a few points en route.

**Handling:** The transit annotation (Step 5) reports duration and distance. The weekly summary does not itemize transit — it only counts time at places. Transit appears in the 3-day detail:

```
Home Tue 7am-8am (1h), [30min/20km], Office Tue 8:30am-5pm (8.5h)
```

### Overlapping known places

**Scenario:** User defines "Home" (100m radius) and "Neighbor's House" (100m radius), with centers 80m apart.

**Handling:** Each point matches the closest known place. Points on the boundary between the two may flip between them. Stay detection aggregates these — if most points in a stay period match "Home", the stay is assigned to "Home."

**Improvement over current:** Current implementation labels each point independently. The v2 approach assigns the place at the stay level (majority vote of point labels within the stay), which is more robust to boundary noise.

### Zero points / single point

**Scenario:** No location data, or only one GPS point.

**Handling:**
- Zero points: return empty result immediately.
- One point: if it matches a known place, report a single stay with 0 duration. Otherwise, nothing to report (cannot determine stationarity from one point).

### Clock changes (DST transitions)

**Scenario:** Clocks spring forward at 2am. A stay that starts at 1:30am and ends at 3:30am (wall clock) is actually 1 hour, not 2.

**Handling:** All internal timestamps are UTC milliseconds. Duration is computed from UTC timestamps, which is correct. Display formatting uses `new Date()` which applies local timezone, so "1:30am-3:30am" appears correctly even though the duration shows 1h.

## What Information Is Lost

1. **Visit purpose.** The algorithm knows WHERE and WHEN but not WHY. "Office 9am-5pm" could mean productive work, a boring meeting, or sitting in the lobby. This is inherent — GPS can't infer purpose.

2. **Mode of transit.** Walking, driving, and taking the bus between the same two points are indistinguishable from GPS breadcrumbs alone. Speed gives a rough hint (walking < 6km/h, driving > 30km/h) but the sparse sampling makes speed unreliable.

3. **Brief outdoor activities.** A 10-minute walk around the block produces 0-1 GPS points. It registers as a brief transit gap and gets absorbed by the merge step. The AI won't know you took a walk.

4. **Vertical dimension.** Going to the 20th floor vs. ground floor of the same building looks identical. GPS altitude is too unreliable to use.

5. **Social context.** Being home alone vs. hosting a party vs. visiting someone else's home (at the same GPS location) are indistinguishable.

6. **Micro-locations within a place.** At the office, you can't tell desk vs. conference room vs. cafeteria.

## What Could Break the Algorithm

1. **Airplane mode / no GPS.** If the user disables location services or enters airplane mode, there are zero points for that period. The algorithm sees a long gap and handles it, but the AI gets no data for flights, camping trips, etc.

2. **GPS spoofing / VPN interference.** Some VPNs or developer tools alter reported location. The algorithm would produce garbage clusters at the spoofed coordinates.

3. **Frequent short stops in a small area.** A delivery driver making 20 stops within a 200m neighborhood would produce a confusing timeline of many short stays that merge into an amorphous blob.

4. **Two distinct places within 100m.** Your office building and the coffee shop across the street (80m apart) merge into one stay. The STAY_RADIUS can't distinguish them. Known places with smaller radii are the escape hatch.

5. **Extreme latitude.** Near the poles, longitude degrees shrink dramatically. The haversine distance handles this correctly, but if anyone runs this app at 85 degrees latitude, the performance characteristics might differ. Not a real concern.

## Implementation Notes

- **No downsampling.** The algorithm is O(n) for the stay detection pass, O(n log n) for the initial sort. For 5,000 points, this is sub-millisecond. Remove the 500-point cap.

- **Centroid update.** Use an incremental centroid: `newCentroid = ((oldCentroid * n) + newPoint) / (n + 1)`. No need to recompute from all points.

- **Haversine calls.** The main loop calls haversine once per point (current point vs. anchor). For 5,000 points, that's 5,000 haversine calls — negligible.

- **Memory.** Each stay is ~6 numbers. 200 stays across 30 days = ~1.6KB. Trivial.

- **Known place matching before stay detection.** Label all points with known place IDs first (O(n*k)), then during stay detection, if a point's known place label differs from the current stay's known place label, that's a place change even if the spatial distance is within STAY_RADIUS. This handles overlapping known place radii correctly.

## Migration from v1

The `ClusterResult` type changes: `clusters` and `timeline` are replaced by `stays` and `transit`. The `summary` string splits into `summaryRecent` and `summaryWeekly`.

Callers (App.tsx share flow) need to update:
- Replace `clusters` with `stays` in the export
- Replace single `summary` with `summaryRecent` + `summaryWeekly`
- Remove the `downsample` call (no longer needed)
- Remove the 500-point progress message (clustering is now instant for any input size)

The `KnownPlace` type and `matchPointToPlace` function are unchanged. The `dbscan`, `UnionFind`, `splitOversized`, and `buildTimeline` functions are replaced entirely by the new `detectStays` function.
