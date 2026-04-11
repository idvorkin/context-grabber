# Places Breakdown: Gaps, Transit, and Place Naming

## Summary

Two related improvements to the Location Detail Sheet's per-day places breakdown (`components/PlacesDailyBreakdown.tsx`):

1. **Show transit and untracked gap time alongside stays**, so the day total visibly adds up to elapsed time and the user can distinguish "I was somewhere unnamed" from "my phone wasn't tracking."
2. **Add a "Name this place" button** on unknown `Place N` rows, with automatic detection of nearby known places and an offer to expand the existing place's radius instead of creating a duplicate.

## Motivation

The current breakdown shows `totalTrackedMinutes` per day, computed as the sum of the top-10 stays in `places_summary.ts:60`. Two failure modes are invisible:

- **A stay wasn't in `known_places`** — it's already labeled `Place 1`, `Place 2`, etc., but the user has no way to name it without copying coordinates into the "Add Place" form.
- **Minutes went missing** — transit time (moving between places) and gap time (GPS off / app killed / signal lost) both vanish from the day total, so a day that reads "8h" on an awake-16h day is opaque.

The user needs to know at a glance: *"did I lose data here, or was I just moving / in a place I haven't named yet?"*

## Goals

- Every day's accounting is transparent: stay + transit + gap sums to the day's elapsed minutes.
- Unknown places are one tap away from becoming known places.
- Naming a point close to an existing place offers to expand that place, not create a duplicate.
- No changes to the clustering algorithm or thresholds.

## Non-Goals

- No changes to `clusterLocationsV2` semantics (stay radius, min duration, merge gap, etc.).
- No map view for picking places on a map.
- No bulk rename / merge of multiple `Place N`s at once.
- No changes to the exported JSON shape (`share.ts`).
- No "undo" for place renames (delete + re-add via Known Places is the recovery path).

## Design

### 1. Transit and No-data rows in the daily breakdown

Each day card in `PlacesDailyBreakdown` gains two extra rows below the stays. Three buckets in total: stay / transit / no-data.

```
┌──────────────────────────────────────────┐
│ Sat Apr 11                          24h │  ← day header = elapsed minutes
│ ████████████████  Home           6h 10m │  ← known place
│ ██████            Office         1h 40m │
│ ██                Place 3           52m │  ← unknown — "Name" button
│ ███████           —transit—      1h 53m │  ← cyan dim
│ ███████████████   —no data—     13h 25m │  ← grey dim
└──────────────────────────────────────────┘
   sum of bars = 24h (elapsed)
```

- **Stay** = matched to a known place (or auto-discovered `Place N`) for ≥5 min.
- **Transit** = GPS points exist outside any stay. This includes both inter-stay movement (a real drive) and head/tail wandering (3-min stops, store browsing, GPS noise). The clustering distinction between "between stays" and "head/tail" is an internal implementation detail; from the user's perspective both are "I have GPS but it didn't form a stay."
- **No data** = no GPS points (phone off, signal lost, tracking disabled).
- Day header total = **elapsed minutes for the day** (`24h` for past days, `now − dayStart` for today). This makes the three buckets sum to the header number.
- Transit row color: `#4cc9f0` at reduced opacity.
- No-data row color: `#555`.
- Bar width uses the max of all three bucket values as the scale.
- Any row with zero minutes is omitted.

### 2. Per-day accounting math

**Transit is evidence-gated.** Clustering's `buildTransit` is dumb time arithmetic — it labels every gap between two consecutive stays as `transit` regardless of whether GPS was actually reporting. An overnight Home → Coffee gap with a dead phone would naively read as "8h transit". We do not want that. `buildPlacesDailySummary` re-analyzes every non-stay minute against the raw GPS points: minutes with GPS evidence (per the loose-detection rules below) become `transitMinutes`; minutes without evidence become `noDataMinutes`. We don't trust clustering's transit output for accounting — only its stays.

Inputs: `stays: Stay[]`, `transit: TransitSegment[]` (kept in the API for symmetry but ignored for the bucket math), `rawPoints: LocationPoint[]` (sorted by timestamp), plus each day's `dayStart` / `dayEnd`.

For each local-midnight day bucket:
- `dayStart` = local midnight of that date
- `dayEnd` = `min(dayStart + 24h, now)` — today's day is truncated at "now"
- `elapsedMs` = `dayEnd − dayStart`
- `stayMs` = sum of `overlap(stay, [dayStart, dayEnd])` across all stays
- `nonStay` = `elapsedMs − stayMs` total, computed as the inverse of stay intervals against the day window
- `nonStay` is split into `transitMs` and `noDataMs` by `splitNonStay(nonStayIntervals, rawPoints)`
- Invariant: `stayMs + transitMs + noDataMs = elapsedMs` (±1m rounding)

A stay that straddles midnight gets split proportionally — a Home stay from 10pm to 8am contributes 2h to the earlier day and 8h to the later.

### 2a. Splitting `non-stay` time into `transit` vs `no data`

Walk the raw points in time order. For each non-stay sub-interval `[a, b]` of the day:

1. Collect all raw points whose `timestamp ∈ [a − LOOSE_HALF_WINDOW, b + LOOSE_HALF_WINDOW]`.
2. If there are **no points**, the entire sub-interval is `noDataMs`.
3. If there are points, group them into runs where consecutive points are within `LOOSE_MAX_GAP = 10 min` of each other. Each run becomes a **transit segment** spanning `[firstPoint − LOOSE_HALF_WINDOW, lastPoint + LOOSE_HALF_WINDOW]`.
4. Clamp segments to `[a, b]`, sum their length → `transitMs` for this sub-interval.
5. Remaining minutes → `noDataMs`.

The `5 min` half-window on either side of a point is because a single GPS breadcrumb represents "roughly around here and now" — treating it as a point mass would under-count transit time. The 10-min max gap matches the expectation that normal background tracking reports every 1–5 min; a >10-min silence is a real dropout.

Constants in `lib/clustering_v2.ts` (no algorithm change there, just exports):
- `LOOSE_MAX_GAP = 10 * 60 * 1000` (10 minutes in ms)
- `LOOSE_HALF_WINDOW = 5 * 60 * 1000` (5 minutes in ms, attributed to each point)

The function name `splitUncovered` from the prior revision is renamed to `splitNonStay` to reflect that it now operates on all non-stay time, not just head/tail.

Rounding: all three values rounded to whole minutes. If floating-point drift causes any to go negative, clamp to 0. Overshoot priority: clamp `noData` first, then `transit`, never touch `stay`.

### 3. `PlaceDaySummary` data model

```typescript
export type PlaceDaySummary = {
  dateKey: string;
  places: { placeId: string; totalMinutes: number }[];
  visits: PlaceVisitDetail[];
  elapsedMinutes: number;      // shown in the day header
  totalStayMinutes: number;    // sum of top-10 places
  transitMinutes: number;      // GPS evidence outside stays
  noDataMinutes: number;       // no GPS evidence anywhere
};
```

Invariant: `totalStayMinutes + transitMinutes + noDataMinutes ≈ elapsedMinutes` (±1m).

```typescript
buildPlacesDailySummary(
  stays: Stay[],
  transit: TransitSegment[],   // accepted but unused — kept for API stability
  rawPoints: LocationPoint[],  // sorted by timestamp
  days: number,
  now?: number,                // injectable for tests; defaults to Date.now()
): PlaceDaySummary[]
```

Passing `rawPoints` is necessary because the transit-vs-no-data split requires knowing *where* GPS points landed.

### 4. "Name this place" button

Each `Place N` row gets a trailing `[+]` button (or `Name` text button) rendered only when `placeId` starts with `Place ` (i.e., it's an auto-generated label).

Tap flow:

1. Button handler is called with the stay's `centroid: { latitude, longitude }` and the `placeId` it replaces.
2. Compute `haversineDistance(centroid, knownPlace)` for every known place. Collect any where `distance <= MERGE_SUGGEST_DISTANCE = 500m`. 500m is a deliberately generous bucket: it catches places across a parking lot, noisy known-place centroids that were originally set from a bad GPS fix, and repeat "Place N" clusters sitting just outside a known disc (all of which show up in the real-data fixture check).
3. **Branch A — no known place within 500m:** Show a name-input modal. Default name empty, default radius 100m. On submit → `addKnownPlace(name, lat, lng, radius)`.
4. **Branch B — one or more known places within 500m:** Show a merge-preview modal listing the nearest one. The modal **computes and displays the exact `mergePlaceCircle` result up front** so the user can see what accepting "Expand" would do:
   > "**Place 3** is 168m from **Milstead & Co**.
   >
   > Expanding Milstead & Co would:
   > - grow its radius from 50m → 159m
   > - shift its center by 57m toward this stay
   >
   > Options:
   > - Expand **Milstead & Co** to cover this point
   > - Create a new place here"

   If multiple known places are within 500m, offer the nearest by default and show "(+N more)" — the user can cancel and reopen if they want to merge into a different one. Keep it simple; no multi-select.

   On "Expand": call `updateKnownPlace(id, { latitude, longitude, radiusMeters })` with the precomputed result from step 4.
   On "Create new": fall through to the Branch A name-input modal.

5. After success, the parent `LocationDetailSheet` refetches `knownPlaces` via `getKnownPlaces(db)`, which triggers `placesDailySummary` useMemo to recompute with the new known place. All matching `Place N` stays across all days are automatically re-labeled — the geometry self-heals other instances of the same repeat cluster.

**Why 500m (not `radius + 50m`):** Against real data (`__tests__/fixtures/context-grabber.db` + `__tests__/fixtures/locations.json`), the tight `radius + 50m` gate caught 0 of 10 unmatched stays. The dominant near-miss is "Place 2" — a repeat visit clustered ~160m from "Milstead & Co" (stored radius 50m) across 3 different days. The user's mental model is "that's Milstead, just with a sloppy original centroid," but the tight gate would never offer the fix. 500m is wide enough to catch these without being so wide that unrelated places get offered. Showing the preview numbers up front lets the user reject the wrong suggestion in one tap when the gate is overgenerous.

### 5. Merge geometry

When "Expand" is accepted, compute the new `(latitude, longitude, radiusMeters)` via the minimum-bounding-circle rule defined in the clustering spec: see [**"Merging a new point into a known place"** in `2026-03-26-location-clustering-v2.md`](2026-03-26-location-clustering-v2.md#merging-a-new-point-into-a-known-place). Implementation lives as `mergePlaceCircle` in `lib/places.ts`; this spec only invokes it.

### 6. Modal UX

Two small modals, both rendered inline in `LocationDetailSheet.tsx` (no new component file):

- **Name input modal** (Branch A, and "Create new" from Branch B):
  - Title: "Name this place"
  - Inputs: name (required), radius (default 100m, editable)
  - Buttons: Save / Cancel
  - Coordinates displayed readonly as "47.6062, -122.3321"

- **Merge-preview modal** (Branch B):
  - Title: "Nearby known place"
  - Body lines (computed from `mergePlaceCircle`):
    - `<Place N> is <distance>m from <Known>.`
    - `Expanding would grow radius <r1>m → <r2>m and shift the center by <shift>m.`
  - Buttons: `Expand <Known>` / `Create new place` / `Cancel`
  - If multiple known places within 500m, pick the closest and show `(+N more)` — no multi-select.

### 7. Per-day 24-hour color-coded strip

Each day card gets a thin horizontal strip directly below the date header, spanning the full width of the card. The strip represents elapsed time for that day, with each pixel colored by *what was happening at that minute*. It's a time-ordered, compressed view of the same data the rows below show as totals.

```
┌──────────────────────────────────────────────────────────────┐
│ Thu Apr 9                                              24h   │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │████████│░│██████████│░│████████│ ▒▒▒▒▒▒▒▒ │█│░│█│██████████│ │ ← 24h strip
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│ ████████████████████  Home                            10h    │
│ ...                                                          │
└──────────────────────────────────────────────────────────────┘
```

**Contents.** Each segment represents contiguous time at one "state":
- A **stay** segment → colored by the stay's placeId, reusing the colorMap the row bars already use (known places from the rotating palette, `Place N` in amber).
- A **transit** segment → cyan at reduced opacity (`#4cc9f0` @ 55%), same as the transit row.
- A **no-data** segment → grey (`#555`), same as the no-data row.

No new colors. No new concepts. The strip is a time-ordered repackaging of the same inputs that produce the stay rows + transit row + no-data row below.

**Derivation.** For each day, walk the interval `[dayStart, dayEnd]` in time order:
1. Stays contribute their clamped `[max(startTime, dayStart), min(endTime, dayEnd)]` as `kind: "stay"` segments with their `placeId`.
2. The gaps between stays + the head/tail of the day are the non-stay intervals.
3. Each non-stay interval is split into transit vs no-data sub-segments using the same `splitNonStay` algorithm that already computes bucket totals — but instead of summing, we return the segment boundaries.
4. All segments are sorted by start time.

**Per-day, not a week view.** Every day card gets its own strip. There is no aggregated "last 7 days" consolidated strip.

**Height and styling.** 14px tall, full-width, rounded corners (`borderRadius: 4`), sits between the date row and the first stay row. No tick marks, no axis labels — the day header already conveys elapsed time.

**Today's strip.** The strip always spans the full 24h physical width regardless of which day is being shown. For today, the real segments (stays / transit / no-data) cover `[dayStart, now]`, and a single trailing `kind: "future"` segment covers `[now, dayStart + 24h]`, rendered very dim grey (`#2a2a40` — darker than the no-data grey so the distinction is visible). This keeps every day's strip the same physical width and gives an at-a-glance read of "how much of today has happened."

Note: the strip's 24h coverage is the *only* place in the summary where today's math differs from elapsed-time math. The row bars, day header total, and bucket sums (`stay + transit + noData`) all still use elapsed-minutes (`min(24h, now − dayStart)`). Only the strip is full-width.

**Interaction.** Tap behavior is unchanged — tapping anywhere in the card (including the strip) expands the day card's visit detail. The strip is not separately interactive.

**Data model change.** `PlaceDaySummary` gains a `stripSegments: DayStripSegment[]` field:

```typescript
export type DayStripSegment = {
  startOffsetMs: number;  // offset from dayStart, within [0, DAY_MS]
  endOffsetMs: number;    // offset from dayStart, within [0, DAY_MS]
  kind: "stay" | "transit" | "noData" | "future";
  placeId?: string;       // present when kind === "stay"
};
```

Segments are sorted by `startOffsetMs`, cover `[0, DAY_MS]` contiguously (no gaps, no overlaps), and the sum of `(endOffsetMs − startOffsetMs)` equals `DAY_MS` (24 × 60 × 60 × 1000). For past days there are no `future` segments. For today, a single trailing `future` segment covers `[elapsedMs, DAY_MS]`.

**`splitNonStay` extension.** The existing `splitNonStay` returns totals. Add a sibling `splitNonStayWithSegments` (or extend the existing function to optionally return segment-level output) that returns an array of `{ start, end, kind }` entries. The totals derivation becomes `segments.filter(k === "transit").sum()`.

### 8. UI for known vs unknown distinction

A subtle visual cue so `Place N` rows read as "unnamed" rather than "noise":

- `Place N` rows use a yellow-tinted bar color (`#fca311` from the existing COLORS palette) regardless of COLORS index.
- Known places keep their existing rotating colors.
- This means the user sees yellow → "oh, I should name that."

## Data Model Changes

### `lib/places_summary.ts`

- `PlaceDaySummary`: rename `totalTrackedMinutes` → `totalStayMinutes`, add `transitMinutes`, `looseMinutes`, `noDataMinutes`.
- `buildPlacesDailySummary`: add `transit: TransitSegment[]`, `rawPoints: LocationPoint[]`, `now?: number` arguments.
- Per-day bucket logic now uses millisecond overlap math against `dayStart` / `dayEnd` instead of naively grouping by `formatDateKey(stay.startTime)`. A stay crossing midnight contributes to both days.
- New helper `splitUncovered(uncovered, rawPoints)` to classify minutes as loose vs no-data per section 2a.

### `lib/db.ts`

- Add `updateKnownPlace(db, id, { name?, latitude?, longitude?, radiusMeters? })`. SQL: `UPDATE known_places SET ... WHERE id = ?`.

### `lib/places.ts`

- Add `mergePlaceCircle(existing, newCentroid, buffer=50)` pure function that returns the updated `{ latitude, longitude, radiusMeters }` for merging a new point into an existing known place.

### `lib/clustering_v2.ts`

- Export new constants `LOOSE_MAX_GAP = 10 * 60 * 1000` and `LOOSE_HALF_WINDOW = 5 * 60 * 1000`.
- No algorithm changes.

### `components/PlacesDailyBreakdown.tsx`

- Accept optional `onNamePlace?: (centroid, placeId) => void` prop.
- Render transit / loose / no-data rows.
- Render `[+]` button on rows whose `placeId` matches `/^Place \d+$/`.
- `Place N` rows use yellow bar color.

### `components/LocationDetailSheet.tsx`

- Own the two new modals (name-input, nearby-known).
- Provide `onNamePlace` handler to `PlacesDailyBreakdown`.
- Refresh `knownPlaces` after a successful name/merge.

## Edge Cases

### Stay crosses midnight
A Home stay from 10pm to 8am contributes 2h to day N and 8h to day N+1. The overlap math handles this without special-casing.

### Stay spans multiple days
Unusual but possible (e.g., 3-day camping trip at a single centroid). Contributes `dayMinutes` to each middle day. Transit/loose/no-data math still holds.

### Loose points spanning midnight
A loose segment (contiguous points <10 min apart) that crosses midnight is split at the boundary — each day gets its fraction.

### Day with no GPS data at all
Every minute is `noDataMinutes`. Loose, transit, and stay are all zero. Day header total shows `0m`. Rendered as a single `—no data— 24h` row under the zero stay header. Acceptable.

### Day with uniform background tracking, no stays ≥5 min
User was moving constantly or every stop was <5 min. Every uncovered minute has adjacent points, so all `uncovered` becomes `looseMinutes`, not `noDataMinutes`. Day reads as "mostly loose" — a strong signal that clustering thresholds or their movement pattern is off.

### Single orphan GPS point in a long silence
One breadcrumb at 3am after hours of no tracking. The point creates a 10-minute loose segment (5m before + 5m after). Rest of the silence is `noDataMinutes`. This is intentional — a single point does represent "I was there at some point," even if briefly.

### Negative minute from rounding
If `stayMinutes + transitMinutes + looseMinutes + noDataMinutes` overshoots `dayEnd − dayStart` by ±1m due to rounding, the priority for the clamp is: preserve `stay` and `transit` exact (they come from clustering), then clamp `noDataMinutes` down first (since it's the largest and least "signal-carrying" bucket), then `looseMinutes`. Never allow any value to go negative.

### User names a place 1m from two existing known places
Pick the nearest, show the "+1 more" hint, let the user decide. If they wanted to merge two known places, that's a different flow (out of scope).

### User cancels the name modal
Place N label remains. No state change. Re-tapping the button works.

### Rename creates collision
User names `Place 3` → "Home" but "Home" already exists. `addKnownPlace` will create a second row with the same name. Acceptable — the breakdown will show two separate known places (distinct centroids). User can delete one from the known places list if they care. Not a named feature.

## Acceptance Criteria

1. Each day card shows the day header as **elapsed minutes** (24h for past days, `now − dayStart` for today).
2. Each day card shows transit and no-data rows whenever those minutes are nonzero. Rows with zero minutes are omitted.
3. `stayMinutes + transitMinutes + noDataMinutes` equals `elapsedMinutes` for every day, within ±1 minute for rounding.
4. A day with GPS points throughout but few/no stays reads mostly as `transit`, not `no data`.
5. A day with the phone off / tracking disabled reads as `no data`, not `transit`.
6. An overnight Home → Coffee gap with no GPS pings reads as `no data`, not `transit`.
7. Unknown `Place N` rows have a visually distinct bar color and a tappable naming button.
8. Tapping the naming button on a stay far from all known places opens a name input, and saving adds a new known place at the stay's centroid.
9. Tapping the button on a stay within **500m** of any existing known place shows a merge-preview modal with the precomputed new radius and center shift, and accepting it updates the existing place via `mergePlaceCircle` + `updateKnownPlace`.
10. After any successful name/expand, the breakdown re-renders within one frame and the formerly-`Place N` row is now labeled with the new name.

## Testing

### `__tests__/places_summary.test.ts`

New cases (in addition to updated existing cases for the renamed field):

- `buildPlacesDailySummary([singleStay], [], [], 7)` — zero transit, zero raw points, full-day no-data minus stay minutes.
- Stay crossing midnight — contributes to both days.
- Transit segment contributes to `transitMinutes`.
- Loose classification: day with a 2h stay plus 30 min of scattered points (each <10 min apart) in an uncovered window → those 30 min are `looseMinutes`, not `noDataMinutes`.
- No-data classification: day with a 2h stay and no points outside it → full remaining minutes are `noDataMinutes`.
- Mixed: day with a 2h stay, a loose cluster of 20 min of points, and 4h of silence → split correctly between `loose` and `no data`.
- Single orphan point: a silence of 3h with one point in the middle → 10m loose (±5m window), rest no-data.
- Today's day uses `now` parameter: a day with `now = dayStart + 6h` and a 2h stay plus no other points yields `noDataMinutes = 4h`, not 22h.
- Rounding: four values sum to elapsed minutes ± 1.
- Clamp priority: synthetic overflow clamps `noData` first, then `loose`.

### `__tests__/db.test.ts` (or inline in existing test file)

- `updateKnownPlace` updates radius and/or name.
- `updateKnownPlace` on non-existent id is a no-op (doesn't throw).

### Manual test plan

1. Pick a day with at least one unnamed stay, some transit, some loose, some no-data → observe four non-stay row types in the breakdown.
2. Tap `[+]` on a `Place N` row >500m from all known places → name it "Test A" → row becomes "Test A".
3. Tap `[+]` on a `Place N` row ~160m from "Milstead & Co" (the real fixture case) → offered merge with preview showing `r 50m → 159m, shift 57m` → accept → row becomes "Milstead & Co", other instances of Place 2 also re-label on next render.
4. Tap `[+]` on a `Place N` row ~250m from a known place → still offered merge under the 500m gate, preview shows larger radius growth → user can reject with "Create new".
5. Open Known Places list in the sheet → verify the new/updated entry is visible with the new lat/lng/radius.

## File Changes

- `lib/places_summary.ts` — updated types + `buildPlacesDailySummary` signature + `splitUncovered` helper
- `lib/clustering_v2.ts` — export `LOOSE_MAX_GAP` and `LOOSE_HALF_WINDOW` constants (no algorithm change)
- `lib/places.ts` — add `mergePlaceCircle` pure function
- `lib/db.ts` — add `updateKnownPlace`
- `components/PlacesDailyBreakdown.tsx` — new rows, new button, new prop, `Place N` color override
- `components/LocationDetailSheet.tsx` — new modals, handler, refresh on success; pass `rawPoints` through to `buildPlacesDailySummary`
- `__tests__/places_summary.test.ts` — new test cases, update existing for renamed field
- `__tests__/places.test.ts` — `mergePlaceCircle` tests
- `__tests__/db.test.ts` — `updateKnownPlace` tests
- No `app.json`, no new deps, no permission changes

## Dependency on Other Specs

- Consumes the clustering output defined in `docs/superpowers/specs/2026-03-26-location-clustering-v2.md`.
- No changes to that spec required.
