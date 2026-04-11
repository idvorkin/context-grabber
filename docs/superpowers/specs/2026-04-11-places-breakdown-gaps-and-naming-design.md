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

### 1. Transit, Loose, and No-data rows in the daily breakdown

Each day card in `PlacesDailyBreakdown` gains up to three extra rows below the stays:

```
┌──────────────────────────────────────────┐
│ Sat Apr 11                       8h 42m │  ← day header (total stay time, unchanged)
│ ████████████████  Home           6h 10m │  ← known place (green)
│ ██████            Office         1h 40m │
│ ██                Place 3           52m │  ← unknown — "Name" button on right
│ ░░░░              —transit—      1h 05m │  ← cyan dashed, smaller
│ ▓▓▓▓              —loose—          35m │  ← amber, dimmed (GPS points but no stay formed)
│ ▒▒▒▒▒▒▒▒▒▒▒▒      —no data—      1h 45m │  ← grey, dimmed (GPS was off / phone dead)
└──────────────────────────────────────────┘
```

- Transit, loose, and no-data rows follow the stay rows, visually dimmer than stays.
- Transit row color: `#4cc9f0` at reduced opacity.
- Loose row color: `#fca311` at reduced opacity (same hue as `Place N` so it reads as "unnamed/noise" data).
- No-data row color: `#555` (existing null-value grey).
- Bar width uses the same `maxMinutes` scale as stays.
- Day header total remains **stay minutes only** (current behavior). The three non-stay rows are supplemental accounting, not bundled into the header number.
- Any of the three rows with zero minutes is omitted.

**Why split `loose` from `no data`:** The user needs to tell the difference between "I was somewhere for 3 minutes, it just didn't cluster" (loose) and "my phone was off" (no data). The former is actionable (evidence of a place worth capturing more carefully); the latter is a data-collection failure.

### 2. Per-day accounting math

Inputs: `stays: Stay[]`, `transit: TransitSegment[]`, `rawPoints: LocationPoint[]` (sorted by timestamp), plus each day's `dayStart` / `dayEnd`.

For each local-midnight day bucket:
- `dayStart` = local midnight of that date
- `dayEnd` = `min(dayStart + 24h, now)` — today's day is truncated at "now"
- `stayMinutes` = sum of `overlap(stay, [dayStart, dayEnd])` across all stays
- `transitMinutes` = sum of `overlap(transit, [dayStart, dayEnd])` across all transit segments
- `uncovered` = total minutes in `[dayStart, dayEnd]` not covered by any stay or transit
- `uncovered` is then split into `looseMinutes` and `noDataMinutes` by inspecting raw points (see below)
- Invariant: `stayMinutes + transitMinutes + looseMinutes + noDataMinutes = dayEnd − dayStart` (±1m rounding)

A stay or transit that straddles midnight gets split proportionally — a Home stay from 10pm to 8am contributes 2h to the earlier day and 8h to the later.

### 2a. Splitting `uncovered` into `loose` vs `no data`

Walk the raw points in time order. For each uncovered sub-interval `[a, b]` of the day:

1. Collect all raw points whose `timestamp ∈ [a, b]`.
2. If there are **no points** in `[a, b]`, the entire sub-interval is `noDataMinutes`.
3. If there are points, walk them in order and split the sub-interval at "no-data gaps":
   - Any contiguous run where consecutive points are within `LOOSE_MAX_GAP = 10 min` of each other is a **loose segment**; the segment spans from the first such point minus 5m to the last such point plus 5m (clamped to `[a, b]`).
   - Any part of `[a, b]` not covered by a loose segment is `noDataMinutes`.

The `5 min` half-window on either side of a point is because a single GPS breadcrumb represents "roughly around here and now" — treating it as a point mass would under-count loose time. The 10-min max gap matches the expectation that normal background tracking reports every 1–5 min; a >10-min silence is a real dropout.

Add the constant to `lib/clustering_v2.ts` alongside the other timing constants:
- `LOOSE_MAX_GAP = 10 * 60 * 1000` (10 minutes in ms)
- `LOOSE_HALF_WINDOW = 5 * 60 * 1000` (5 minutes in ms, attributed to each point)

Rounding: all four values rounded to whole minutes. If floating-point drift causes any to go negative, clamp to 0.

### 3. `PlaceDaySummary` data model change

Update `lib/places_summary.ts`:

```typescript
export type PlaceDaySummary = {
  dateKey: string;
  places: { placeId: string; totalMinutes: number }[];
  visits: PlaceVisitDetail[];
  totalStayMinutes: number;    // renamed from totalTrackedMinutes, same value
  transitMinutes: number;      // new
  looseMinutes: number;        // new — GPS points exist but no stay formed
  noDataMinutes: number;       // new — no GPS points (phone off / tracking disabled)
};
```

`buildPlacesDailySummary` gains new arguments:

```typescript
buildPlacesDailySummary(
  stays: Stay[],
  transit: TransitSegment[],
  rawPoints: LocationPoint[],   // sorted by timestamp
  days: number,
  now?: number,                 // injectable for tests; defaults to Date.now()
): PlaceDaySummary[]
```

The `totalStayMinutes` field name makes the semantics explicit (before, it was ambiguous). `totalTrackedMinutes` is removed — rename is intentional, not backwards-compatible, because the old name was misleading.

Passing `rawPoints` is necessary because the loose-vs-no-data split requires knowing *where* GPS points landed, which the stays/transit output alone has already lost.

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

### 7. UI for known vs unknown distinction

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

1. Each day card in the breakdown shows transit, loose, and no-data rows whenever those minutes are nonzero. Rows with zero minutes are omitted.
2. `stayMinutes + transitMinutes + looseMinutes + noDataMinutes` equals `dayEnd − dayStart` for every day, within ±1 minute for rounding.
3. A day with GPS points throughout but few/no stays reads mostly as `loose`, not `no data`.
4. A day with the phone off / tracking disabled reads as `no data`, not `loose`.
5. Unknown `Place N` rows have a visually distinct bar color and a tappable naming button.
6. Tapping the naming button on a stay far from all known places opens a name input, and saving adds a new known place at the stay's centroid.
7. Tapping the button on a stay within **500m** of any existing known place shows a merge-preview modal with the precomputed new radius and center shift, and accepting it updates the existing place via `mergePlaceCircle` + `updateKnownPlace`.
8. After any successful name/expand, the breakdown re-renders within one frame and the formerly-`Place N` row is now labeled with the new name.
9. All existing tests in `__tests__/places_summary.test.ts` and `__tests__/clustering_v2.test.ts` continue to pass (after updating for renamed field and new args).

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
