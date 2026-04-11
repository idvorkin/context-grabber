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

### 1. Transit + Gap rows in the daily breakdown

Each day card in `PlacesDailyBreakdown` gains two extra rows below the stays:

```
┌──────────────────────────────────────────┐
│ Sat Apr 11                       8h 42m │  ← day header (total stay time, unchanged)
│ ████████████████  Home           6h 10m │  ← known place (green)
│ ██████            Office         1h 40m │
│ ██                Place 3           52m │  ← unknown — "Name" button on right
│ ░░░░              —transit—      1h 05m │  ← cyan dashed, smaller
│ ▒▒▒▒▒▒▒▒▒▒▒▒      —untracked—    2h 20m │  ← grey, dimmed
└──────────────────────────────────────────┘
```

- Transit and gap rows follow the stay rows, visually dimmer than stays.
- Transit row color: `#4cc9f0` at reduced opacity.
- Gap row color: `#555` (same as existing null-value grey).
- Bar width uses the same `maxMinutes` scale as stays (whichever is largest on the row drives the scale).
- Day header total remains **stay minutes only** (current behavior). Transit/gap are additional rows, not bundled into the header number.
- If transit or gap is zero, the row is omitted.

### 2. Per-day accounting math

Inputs: `stays: Stay[]`, `transit: TransitSegment[]`, plus each day's `dayStart` / `dayEnd`.

For each local-midnight day bucket:
- `dayStart` = local midnight of that date
- `dayEnd` = `min(dayStart + 24h, now)` — today's day is truncated at "now"
- `stayMinutes` = sum of `overlap(stay, [dayStart, dayEnd])` across all stays
- `transitMinutes` = sum of `overlap(transit, [dayStart, dayEnd])` across all transit segments
- `gapMinutes` = `(dayEnd − dayStart) − stayMinutes − transitMinutes`

A stay that straddles midnight (e.g., Home from 10pm to 8am) gets split proportionally: 2h into the earlier day, 8h into the later. Same rule for transit.

Rounding: all three values rounded to whole minutes. If floating-point drift causes `gapMinutes` to go negative (e.g., −1m), clamp to 0.

### 3. `PlaceDaySummary` data model change

Update `lib/places_summary.ts`:

```typescript
export type PlaceDaySummary = {
  dateKey: string;
  places: { placeId: string; totalMinutes: number }[];
  visits: PlaceVisitDetail[];
  totalStayMinutes: number;    // renamed from totalTrackedMinutes, same value
  transitMinutes: number;      // new
  gapMinutes: number;          // new
};
```

`buildPlacesDailySummary` gains a second argument:

```typescript
buildPlacesDailySummary(
  stays: Stay[],
  transit: TransitSegment[],
  days: number,
  now?: number,  // injectable for tests; defaults to Date.now()
): PlaceDaySummary[]
```

The `totalStayMinutes` field name makes the semantics explicit (before, it was ambiguous). `totalTrackedMinutes` is removed — rename is intentional, not backwards-compatible, because the old name was misleading.

### 4. "Name this place" button

Each `Place N` row gets a trailing `[+]` button (or `Name` text button) rendered only when `placeId` starts with `Place ` (i.e., it's an auto-generated label).

Tap flow:

1. Button handler is called with the stay's `centroid: { latitude, longitude }` and the `placeId` it replaces.
2. Compute proximity to all `knownPlaces`: for each, compute `haversineDistance(centroid, place)`. Collect any where `distance <= place.radiusMeters + 50`.
3. **Branch A — no nearby known place:** Show a name-input modal. Default name empty, default radius 100m (reusing the existing `addPlaceForm` styling). On submit → `addKnownPlace(name, lat, lng, radius)`.
4. **Branch B — one or more nearby known places:** Show a confirmation modal listing the nearest one:
   > "This is 45m from **Home** (radius 100m). Options:
   > - Expand **Home** to cover this point (new radius 145m)
   > - Create a new place here"

   On "Expand": update the existing known place's radius to `max(existing.radiusMeters, distance + 50)`. Requires new `updateKnownPlace(id, { radiusMeters })` in `lib/db.ts`.
   On "Create new": fall through to the Branch A name-input modal.

5. After success, the parent `LocationDetailSheet` refetches `knownPlaces` via `getKnownPlaces(db)`, which triggers `placesDailySummary` useMemo to recompute with the new known place. All matching `Place N` stays across all days are automatically re-labeled with the new name — no extra work needed.

### 5. Modal UX

Two small modals, both rendered inline in `LocationDetailSheet.tsx` (no new component file):

- **Name input modal** (Branch A, and "Create new" from Branch B):
  - Title: "Name this place"
  - Inputs: name (required), radius (default 100m, editable)
  - Buttons: Save / Cancel
  - Coordinates displayed readonly as "47.6062, -122.3321"

- **Nearby known place modal** (Branch B):
  - Title: "Nearby known place found"
  - Body: "This is **45m from Home** (current radius 100m)."
  - Buttons: "Expand Home to 145m" / "Create new place" / "Cancel"
  - If multiple known places within buffer, pick the closest and mention the count ("(+2 more)") — no multi-select.

### 6. UI for known vs unknown distinction

A subtle visual cue so `Place N` rows read as "unnamed" rather than "noise":

- `Place N` rows use a yellow-tinted bar color (`#fca311` from the existing COLORS palette) regardless of COLORS index.
- Known places keep their existing rotating colors.
- This means the user sees yellow → "oh, I should name that."

## Data Model Changes

### `lib/places_summary.ts`

- `PlaceDaySummary`: rename `totalTrackedMinutes` → `totalStayMinutes`, add `transitMinutes`, add `gapMinutes`.
- `buildPlacesDailySummary`: add `transit: TransitSegment[]` second argument, add `now?: number` last argument.
- Per-day bucket logic now uses millisecond overlap math against `dayStart` / `dayEnd` instead of naively grouping by `formatDateKey(stay.startTime)`. A stay crossing midnight contributes to both days.

### `lib/db.ts`

- Add `updateKnownPlace(db, id, { name?, radiusMeters? })`. SQL: `UPDATE known_places SET ... WHERE id = ?`.

### `components/PlacesDailyBreakdown.tsx`

- Accept optional `onNamePlace?: (centroid, placeId) => void` prop.
- Render transit / gap rows.
- Render `[+]` button on rows whose `placeId` matches `/^Place \d+$/`.
- `Place N` rows use yellow bar color.

### `components/LocationDetailSheet.tsx`

- Own the two new modals (name-input, nearby-known).
- Provide `onNamePlace` handler to `PlacesDailyBreakdown`.
- Refresh `knownPlaces` after a successful name/merge.

### `lib/clustering_v2.ts`

No changes.

## Edge Cases

### Stay crosses midnight
A Home stay from 10pm to 8am contributes 2h to day N and 8h to day N+1. The overlap math handles this without special-casing.

### Stay spans multiple days
Unusual but possible (e.g., 3-day camping trip at a single centroid). Contributes `dayMinutes` to each middle day. Transit/gap math still holds.

### Gap bigger than 24h
Day bucket gap = `dayEnd − dayStart − stays − transit`. If no stays or transit for a day, gap = full 24h (or less for today). This is correct — user wasn't tracked that day.

### Negative gap from rounding
If `stayMinutes + transitMinutes > (dayEnd − dayStart)` due to rounding, clamp gap to 0. Should not happen in practice unless transit segments overlap stays, which `clusterLocationsV2` currently prevents.

### User names a place 1m from two existing known places
Pick the nearest, show the "+1 more" hint, let the user decide. If they wanted to merge two known places, that's a different flow (out of scope).

### User cancels the name modal
Place N label remains. No state change. Re-tapping the button works.

### Rename creates collision
User names `Place 3` → "Home" but "Home" already exists. `addKnownPlace` will create a second row with the same name. Acceptable — the breakdown will show two separate known places (distinct centroids). User can delete one from the known places list if they care. Not a named feature.

## Acceptance Criteria

1. Each day card in the breakdown shows transit and untracked rows whenever those minutes are nonzero.
2. `stayMinutes + transitMinutes + gapMinutes` equals `dayEnd − dayStart` for every day, within ±1 minute for rounding.
3. Unknown `Place N` rows have a visually distinct bar color and a tappable naming button.
4. Tapping the naming button on a stay far from all known places opens a name input, and saving adds a new known place at the stay's centroid.
5. Tapping the button on a stay within `radius + 50m` of an existing known place offers an "Expand" option, and accepting it updates the existing place's radius.
6. After any successful name/expand, the breakdown re-renders within one frame and the formerly-`Place N` row is now labeled with the new name.
7. All existing tests in `__tests__/places_summary.test.ts` and `__tests__/clustering_v2.test.ts` continue to pass (after updating for the renamed field and new args).

## Testing

### `__tests__/places_summary.test.ts`

New cases (in addition to updated existing cases for the renamed field):

- `buildPlacesDailySummary([singleStay], [], 7)` — zero transit, full-day gap minus stay minutes.
- Stay crossing midnight — contributes to both days.
- Transit segment contributes to `transitMinutes`.
- Today's day uses `now` parameter instead of 24h: a day with `now = dayStart + 6h` and a 2h stay yields `gapMinutes = 4h`, not 22h.
- Rounding: stays + transit + gap sum to elapsed minutes ± 1.
- Negative-gap clamp: synthetic case where overlaps exceed the day.

### `__tests__/db.test.ts` (or inline in existing test file)

- `updateKnownPlace` updates radius and/or name.
- `updateKnownPlace` on non-existent id is a no-op (doesn't throw).

### Manual test plan

1. Pick a day with at least one unnamed stay and some transit → observe three row types in breakdown.
2. Tap `[+]` on a `Place N` row far from known places → name it "Test A" → row becomes "Test A".
3. Tap `[+]` on a `Place N` row ~30m from "Home" → offered expand → accept → "Home"'s radius grows, row becomes "Home".
4. Open Known Places list in the sheet → verify the new/updated entry is visible.

## File Changes

- `lib/places_summary.ts` — updated types + `buildPlacesDailySummary` signature
- `lib/db.ts` — add `updateKnownPlace`
- `components/PlacesDailyBreakdown.tsx` — new rows, new button, new prop, `Place N` color override
- `components/LocationDetailSheet.tsx` — new modals, handler, refresh on success
- `__tests__/places_summary.test.ts` — new test cases, update existing for renamed field
- `__tests__/db.test.ts` — new (or extend existing)
- No `lib/clustering_v2.ts` changes
- No `app.json`, no new deps, no permission changes

## Dependency on Other Specs

- Consumes the clustering output defined in `docs/superpowers/specs/2026-03-26-location-clustering-v2.md`.
- No changes to that spec required.
