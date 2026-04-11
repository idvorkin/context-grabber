# Sleep Display Enhancements — Design Spec

## Summary

Expand the Sleep metric detail sheet from "7-day bar chart of total hours" into a richer view that surfaces **stage composition**, **bedtime/wake consistency**, **sleep debt**, and **per-night stage strips**. Ships in two phases that share the same data-layer prerequisite:

- **Phase 1 (text + small charts):** stage percentage breakdown, sleep debt running total, bedtime/wake consistency line chart. All derived from data we already query, just retained further through aggregation.
- **Phase 2 (stage visualization):** stacked-stage 7-day bar chart (replacing the current flat bar chart) and per-night sleep strip in the daily rows.

Both phases depend on one new pure function — `aggregateSleepDetailed` — that replaces today's lossy-to-hours-only weekly aggregation with a per-night object carrying stages + bedtime + wake time. No new HealthKit queries.

## Problem

The current sleep detail sheet (`MetricDetailSheet` sleep branch) shows a bar chart of total hours per night, a 7-day average line, source tabs, and daily row labels. It answers "how many hours did you sleep?" but nothing else:

- **No stage breakdown visible historically.** Stage data (Core/Deep/REM/Awake) is queried and stored for *today only* via `sleepBySource`. The 7-day bar chart discards it.
- **No bedtime consistency.** You can see your bedtime for last night in the grid card subtext, but the sheet doesn't show whether your schedule has been stable or drifting.
- **No quality/efficiency metric.** Classic sleep-tracker concepts (sleep debt, time-in-bed vs asleep, stage percentages) aren't surfaced anywhere.
- **No sense of *when* you slept.** Only the aggregate duration. A rough 2–10am sleep and a smooth 11pm–7am sleep look identical.

The goal is to close these four gaps with minimal new data plumbing.

## Goals

- Stage composition visible at a glance for both last night and the 7-day window
- Bedtime and wake-time consistency readable as a small chart
- Running sleep debt vs a user-adjustable target
- Per-night stage strip showing when you were in each stage
- No new HealthKit queries — reuse the raw samples we already fetch
- No changes to the sleep grid card (keeps its current headline + bedtime/wake subtext)
- Existing sleep source tabs unchanged — they still let you compare Watch vs AutoSleep

## Non-Goals

- No sleep stage goal setting (the only new setting is the sleep duration target for sleep debt)
- No new data exports — `lib/share.ts` JSON shape stays the same
- No correlation with other metrics (cross-metric analytics deferred)
- No sleep clock / circular visualization — rejected in favor of the strip
- No awakenings count, sleep latency, or efficiency ratio in V1/V2 — deferred until we have the core stage + consistency layer landed

## Phase 1 — Text + small chart additions

### 1.1 Stage percentage breakdown (last night)

Below the 7-day bar chart (and above the average line), render a single row of text showing last night's stage composition as percentages. Colors match each stage.

```
 Core 57% · Deep 18% · REM 21% · Awake 4%
```

- **Colors:** Core `#4cc9f0`, Deep `#3a0ca3`, REM `#7209b7`, Awake `#8d99ae`.
- **Null handling:** if any stage has 0 hours, it's omitted. If all stages are 0/null, hide the row entirely.
- **Data source:** `sleepBySource` from the current snapshot — aggregated across all sources (pick the source with the longest total sleep, or sum if overlapping across sources is handled upstream).

### 1.2 Sleep debt running total

One text line near the top of the detail sheet showing cumulative deficit from the sleep target over the last 7 days.

```
Sleep debt: −3h 20m over 7 days (target 8h/night)
```

- **Debt calculation:** for each of the last 7 nights, compute `max(0, target − actualHours)` and sum. A night with more than target doesn't count as "extra credit" — oversleeping doesn't erase prior deficits.
  - Rationale: classic sleep-debt semantics per most consumer apps. It's a debt, not a running balance.
- **Target default:** 8 hours. Configurable via a new setting in `SettingsModal` (see section 3.1).
- **Display:** if total debt is 0, show "Sleep debt: 0m (caught up!)" to reassure. If target isn't set, show "Sleep debt: no target set" with a button or hint to open settings.
- **Color:** debt > 2h → warning amber; debt > 4h → red; else muted grey.

### 1.3 Bedtime / wake-time consistency chart

A small two-line chart between the main bar chart and the sleep debt line. X axis: 7 days. Y axis: time of day (6pm–noon, wrapping around midnight). Two series:

- **Bedtime** — when the user first fell asleep each night (earliest asleep sample)
- **Wake time** — when the user last woke up each morning (last asleep sample)

```
Wake    ──●────●────●──●────●──●────
12a                                    ← wraps
11p   ●───────●────●─●──●────●──    ← bedtime
10p
```

- **Line colors:** bedtime = purple, wake time = lighter purple.
- **Y axis:** from 6pm to noon next day, so overnight sleep lays out sensibly. Labels every 2 hours.
- **Variance readout:** below the chart, a single line summarizing the stdev: "Bedtime ±28 min · Wake ±14 min." Gives an instant read on schedule consistency.
- **Null handling:** nights with no sleep samples show gaps.

## Phase 2 — Stage visualization

### 2.1 Stacked-stage 7-day bar chart

Replace the current single-color bar chart with a stacked bar chart where each day's bar is split vertically into four segments: Core (biggest, bottom), Deep, REM, Awake (smallest, top).

```
              Wed  Thu  Fri  Sat  Sun  Mon  Tue
 8h  ┤                                            ← goal line (optional)
     │      ▓                                     ← Awake
 6h  ┤  █   █   █      █                          ← REM
     │  █   █   █   █  █   █                     ← Deep
 4h  ┤  █   █   █   █  █   █   █                 ← Core
     │  █   █   █   █  █   █   █
 2h  ┤  █   █   █   █  █   █   █
     │  █   █   █   █  █   █   █
 0h  ┼──┴───┴───┴───┴──┴───┴───┴──
      6.2 6.4 5.9 7.1 6.8 6.5 6.0  ← totals below bars
```

- **Data source:** `aggregateSleepDetailed` returning per-night `{ coreHours, deepHours, remHours, awakeHours, totalHours, bedtime, wakeTime }`.
- **Colors:** same as 1.1 (Core/Deep/REM/Awake).
- **Total number below each bar:** like the existing chart.
- **Today's bar:** same "today" highlight the existing chart uses (brighter border, bigger total label).
- **Optional goal line:** if sleep target is set, draw a horizontal line at that value across the chart. Dashed, muted color.
- **Tap-to-select:** tapping a bar highlights it and updates the "selected day" state so the daily rows below scroll to match — matches the existing chart's behavior.

### 2.2 Per-night sleep stage strip

Each daily row in the sleep detail sheet (the list at the bottom, currently `Wed Apr 8 · 6h 10m`) gets a thin horizontal strip below the label showing the sleep stages across the night. Similar in concept to the location day strip, but scoped to the sleep window.

```
Wed Apr 8                              6h 10m
▓▓██████████░░██████░░░░████████▓▓      ← stage strip
11:24 pm                          5:34 am
```

- **Strip spans the sleep window** — `bedtime` on the left to `wakeTime` on the right. NOT a 24h strip.
- **Height:** 10px (thinner than the 14px day-strip elsewhere).
- **Colors per segment:**
  - Core — cyan
  - Deep — dark blue
  - REM — purple
  - Awake — grey
  - InBed (not sleep) — very dim
- **Labels:** bedtime on left, wake time on right, small grey text.
- **Data:** walk the night's `SleepSample[]` in time order, emit a colored segment per stage run.
- **No tap behavior** — the strip is decorative, tapping the row does whatever it does today (nothing currently).

## Data layer

### 3.1 Sleep target setting

Add a new setting `sleep_target_hours` (default 8) stored in the existing `settings` SQLite table via `lib/db.ts`. New getter/setter + `SettingsModal` row with a number input.

- **Why a setting:** lets the sleep-debt calculation be meaningful for users who don't need 8h (some are fine with 7, some want 9).
- **UI:** one numeric row in `SettingsModal` under a new "Sleep" section. Default 8, min 4, max 12.

### 3.2 `SleepDaily` type

New type in `lib/health.ts` (or `lib/sleep.ts`, pick whichever co-locates best):

```typescript
export type SleepDaily = {
  date: string;            // "YYYY-MM-DD" local date of the night
  totalHours: number | null;
  coreHours: number;
  deepHours: number;
  remHours: number;
  awakeHours: number;
  bedtime: string | null;  // ISO local time
  wakeTime: string | null;
  samples: SleepSample[];  // retained for strip rendering
};
```

Keeping raw `samples` per night sounds expensive but the 7-day window is bounded and samples are small (~50–200 per night). Total payload << 100KB typical.

### 3.3 `aggregateSleepDetailed` function

New pure function in `lib/weekly.ts` (or `lib/sleep.ts`). Replaces the lossy path that currently returns `DailyValue[]`:

```typescript
export function aggregateSleepDetailed(
  samples: SleepSample[],
  endDate: Date,
  days = 7,
): SleepDaily[];
```

Internally:
1. Bucket samples by local date of `startDate` (same rule as current `aggregateSleep`).
2. Within each bucket, merge overlapping intervals per stage (handles Watch + iPhone double reporting).
3. Compute `bedtime` = earliest asleep sample, `wakeTime` = latest asleep sample.
4. Compute stage hours by summing non-overlapping intervals per stage.
5. `totalHours` = `core + deep + rem` (excludes Awake and InBed — matches `calculateSleepHours`).
6. Retain raw samples sorted by time.

### 3.4 Wiring in App.tsx

`handleMetricPress("sleep")` currently populates `weeklyCache.sleep` as `DailyValue[]`. Add a parallel cache entry for the detailed version — or change the cache shape for the sleep key specifically to `SleepDaily[]`, with a converter that produces `DailyValue[]` for any consumer that wants the flat shape (e.g., `computeStatsForMetric`).

Cleanest approach: introduce a new cache key pattern `sleepDetailed: SleepDaily[]` separate from the existing scalar cache. `MetricDetailSheet`'s sleep branch consumes the detailed one; the grid card's box plot still uses the scalar one via the existing path.

## UI changes per component

### `components/MetricDetailSheet.tsx` — sleep branch

Current sleep branch flow:

```
Current value → Bar chart → Avg line → Source tabs → Daily rows
```

New flow (after both phases):

```
Current value
→ Sleep debt line                                          (Phase 1.2)
→ Stacked-stage bar chart                                  (Phase 2.1)
→ Stage percentages (last night)                           (Phase 1.1)
→ Bedtime / wake consistency chart                         (Phase 1.3)
→ Source tabs (existing, unchanged)
→ Daily rows with stage strips                             (Phase 2.2)
```

### `components/BarChart.tsx`

Extend the existing bar chart component to support stacked-stage mode. New prop `stackedStages?: boolean` — when true, accept `SleepDaily[]` instead of `DailyValue[]` and render stacked segments. Single-metric callers (steps, active energy, walking distance) are unaffected.

Alternative: new dedicated component `StackedSleepBarChart.tsx`. I lean toward reusing `BarChart` with a branch, since the geometry and axis math are identical — only the per-bar rendering changes.

### `components/SettingsModal.tsx`

New section at the top (or wherever fits) with a single numeric row for sleep target.

### New component: `SleepConsistencyChart.tsx`

Dedicated component for the bedtime/wake consistency chart in Phase 1.3. Small enough to inline, but extracting it keeps `MetricDetailSheet` from getting longer.

### New component: `SleepStageStrip.tsx`

Small stateless component that takes `samples: SleepSample[]` and renders the colored strip. Used by Phase 2.2 (inside each daily row) and optionally reusable later.

## Edge cases

| Case | Handling |
|---|---|
| Night with no sleep data | Bar is absent from chart (same as today); daily row shows "—"; strip is hidden |
| Only "In Bed" samples, no Asleep | `totalHours` = 0, bedtime/wake time null, strip shows a single dim grey segment |
| Overlapping source samples (Watch + AutoSleep) | Merge overlapping intervals per stage before computing hours (same rule as `calculateSleepHours` today) |
| Night crossing two local dates (11pm–7am) | Assigned to the LOCAL date of `startDate` per existing rule |
| Sleep debt with a missing night in the window | That night contributes `target` to the deficit (treated as zero sleep) — conservative |
| Target set to 0 or null | Hide sleep debt line entirely |
| All 7 nights missing | Everything hides; the existing "no data" state shows |

## Acceptance criteria

1. Sleep debt line appears above the chart when a target is set, shows correct cumulative deficit, and color-codes by severity.
2. Sleep target setting persists across app relaunches.
3. Stage percentages row shows non-zero stages only, colored correctly.
4. Bedtime consistency chart renders two lines with stdev readout below.
5. Stacked-stage bar chart replaces the flat bar chart and each day's total equals the sum of its stage segments.
6. Per-night sleep strip appears under each daily row and spans `bedtime` to `wakeTime`.
7. Daily rows with no data show no strip (and em-dash hours).
8. Existing source tabs still switch source-specific views without breaking.
9. `lib/share.ts` JSON export is unchanged.
10. `npx tsc --noEmit` clean.
11. `npx jest` green.

## Testing

### `__tests__/sleep.test.ts`

New describe `aggregateSleepDetailed`:
- Empty input → empty array
- Single night with one source → correct stage hours, bedtime/wake extracted
- Two overlapping sources → intervals merged before stage hours summed
- Stage transitions (core → deep → REM → awake → core) → per-stage sums correct
- Bedtime = min(asleep.startDate), wakeTime = max(asleep.endDate)
- Night crossing midnight → assigned to local date of start
- Missing night → entry with totalHours=null, samples=[]

New describe `sleepDebt`:
- All nights meet target → 0
- Each night 1h short → `7 × 1h = 7h` debt
- Mix of over/under → over nights don't reduce debt
- Missing nights count as full-target deficit
- Target=0 → undefined behavior (not called)

New describe `sleepConsistencyStats`:
- Identical bedtimes → stdev = 0
- Bedtimes across wrap-around midnight → stdev computed modulo 24h (bedtimes span 11pm and 1am should be treated as ~2h apart, not 22h)

### Manual test plan

1. Open sleep detail sheet → verify debt line, stacked bar chart, stage percentages, consistency chart, source tabs, daily rows with strips, all visible and non-overlapping.
2. Tap a day in the bar chart → daily rows highlight the corresponding row.
3. Open Settings → Sleep section → change target from 8 to 7 → return to sleep sheet → debt recomputes.
4. Verify an all-null night shows no strip in the daily rows.
5. Verify a night with only Core (no Deep/REM/Awake) shows only Core in percentages + single-segment strip.

## File changes summary

| File | Change |
|---|---|
| `lib/health.ts` or `lib/sleep.ts` | Add `SleepDaily` type |
| `lib/weekly.ts` | Add `aggregateSleepDetailed`, retain existing `aggregateSleep` for backwards compat if other consumers need it |
| `lib/sleep.ts` | Add `computeSleepDebt`, `computeConsistencyStats` pure helpers |
| `lib/db.ts` | Add `getSleepTarget`, `setSleepTarget` (settings table) |
| `components/BarChart.tsx` | Extend with `stackedStages` mode |
| `components/MetricDetailSheet.tsx` | Sleep branch: debt line, stage percentages, consistency chart, daily row strips |
| `components/SettingsModal.tsx` | New Sleep section with target input |
| `components/SleepConsistencyChart.tsx` | New |
| `components/SleepStageStrip.tsx` | New |
| `App.tsx` | Sleep branch of `handleMetricPress` populates `sleepDetailedCache`; `MetricDetailSheet` prop passes detailed data |
| `__tests__/sleep.test.ts` | New cases |
| `__tests__/weekly.test.ts` | New cases for `aggregateSleepDetailed` |
| `docs/superpowers/specs/2026-04-11-sleep-display-enhancements-design.md` | This spec |
