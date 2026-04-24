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

## Phase 3 — Source filtering, layout fixes, day zoom (2026-04-11 revision)

After Phases 1 + 2 shipped, four usability issues surfaced in the sleep detail sheet. Phase 3 addresses them.

### 3.1 Source selection must switch the entire view

**Today's behavior.** When the user has multiple sleep sources (e.g. Apple Watch and AutoSleep), tapping a source tab only changes a small summary pill row below the tabs. The chart, sleep debt line, stage percentages, consistency chart, and per-night daily rows all show a merged view regardless of which tab is selected. Switching tabs appears to do nothing.

**New behavior.** Tapping a source tab switches the *entire* sleep sheet to that source's view. Every element that shows per-night data — chart, debt, stage %, consistency chart, day list, per-night strips — re-renders to show only that source's readings.

**Tabs available:**
- **"All"** — shows a merged view (overlaps between sources deduped, same as today's current behavior).
- One tab per sleep source that has at least one sample in the 7-day window, in alphabetical order.

**Default tab.** The source with the most stage detail is selected by default — meaning the source that reports the richest breakdown into Core / Deep / REM / Awake across the 7-day window. Apple Watch typically wins; AutoSleep and phone-only sources typically report coarser data and lose. If no source reports any stages (all nights are just "asleep"), fall back to "All". Rationale: the sheet's whole point is stage visualization; default to the source that actually has stages.

**Out of scope.** Side-by-side comparison of two sources at once.

### 3.2 Sheet layout — more room for the day list

**Today's behavior.** On the sleep sheet, the top half of the sheet fills up with the current value, source tabs, chart, sleep debt line, stage percentage row, and the full consistency chart. The per-night day list at the bottom is squeezed into a small scroll strip that can't comfortably show all 7 nights.

**New behavior.** The day list gets the room it needs. Everything below the current-value header becomes part of one continuous scroll: source tabs, chart, debt line, stage %, consistency chart, and the daily rows all live in the same scrollable area. The user can scroll through everything in one motion.

**Trade-off accepted.** Swipe-to-dismiss by dragging on the chart area is lost. The drag handle at the top and the ✕ button still dismiss the sheet.

This layout change applies to all metric detail sheets, not just sleep — everything benefits from more scroll room on short phones.

### 3.3 Day click → zoomed day detail card

**Today's behavior.** Tapping a day in the stacked sleep bar chart does nothing visible on the sleep sheet.

**New behavior.** Tapping a day in the chart opens a "zoomed day" card that appears just below the chart. The card shows:
- The date
- Total sleep time and bedtime → wake time
- A large, easy-to-read stage strip that visualizes the night — each stage (Core, Deep, REM, Awake) colored, spanning bedtime to wake time, with hour labels beneath
- A stage percentage breakdown for that night

Tapping the same day again closes the card. Tapping a different day switches the card to that night. Nights with no sleep data show a "No sleep data for this night" message inside the card.

While a day is selected, the "last night" stage percentage row that normally sits under the chart hides (the zoomed card already shows the same info for the selected night, so we don't want duplicates).

### 3.4 Per-night daily rows — bigger and easier to read

**Today's behavior.** The daily row list uses small text and a thin stage strip. Rows feel cramped; the strip is hard to read without zooming into the screenshot.

**New behavior.** Rows are taller, text is larger, and the per-night stage strip is thicker — enough to read the stage composition at a glance while scanning the list. This is a typography tune-up; the row structure (date label on the left, total hours on the right, strip beneath) is unchanged.

### Phase 3 acceptance criteria

1. Source tabs include an "All" option plus one tab per distinct sleep source that has samples in the last 7 days, in alphabetical order. The default selection is the source reporting the most stage detail (Core/Deep/REM/Awake coverage) across the 7-day window; "All" is the fallback when no source has stage data.
2. Tapping a source tab re-renders the chart, debt line, stage percentages, consistency chart, and the daily row list to match that source's data. Nothing that shows per-night data ignores the selection.
3. The sheet scrolls as one continuous area from the source tabs down through the daily rows. The day list can be scrolled to show all 7 nights without being squeezed.
4. The sheet can still be dismissed by dragging the handle at the top or tapping ✕.
5. Tapping a day in the chart opens a zoomed card just below the chart showing the date, total, bedtime → wake, a large stage strip with hour labels, and stage percentages for that night. Tapping the same day again closes the card. Tapping a different day switches it.
6. Nights with no sleep data show a "no data" message inside the zoomed card.
7. While a day is selected, the "last night" stage percentage row under the chart is hidden to avoid duplicated info.
8. The per-night daily rows in the breakdown list are visibly larger and easier to read than before Phase 3 — both the text and the stage strip.
9. All automated tests pass.

### Phase 3 manual test plan

1. Open sleep sheet → the source with the richest stage data (typically Apple Watch) is selected by default; chart and stats render from that source.
2. Tap "All" → chart, debt, stage percentages, consistency chart, and daily rows all change to the merged view.
3. Tap "AutoSleep" → everything switches again. Tap the Apple Watch tab → back to the default view.
4. Scroll the sheet — the daily row list can be scrolled to show all 7 nights without being squeezed.
5. Tap a day in the chart → zoomed card appears with that night's details; the "last night" stage row disappears.
6. Tap the same day → card hides, last-night row returns.
7. Tap a different day → card updates to that night.
8. Drag the handle down → sheet dismisses.
9. The per-night rows in the breakdown list feel visibly larger/clearer than before.

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

### Phase 3 implementation

Phase 3 engineering details (data shapes, component layout, file-level changes, rollout order, risks) live in [`docs/superpowers/plans/2026-04-11-sleep-display-phase-3-plan.md`](../plans/2026-04-11-sleep-display-phase-3-plan.md).

## Phase 4 — Attribution + source-aware avg + dropped-tracking flag (2026-04-24 revision)

Trigger: GitHub issue #28 reported three problems visible in the Sleep panel at once. Each resolves a visible lie between two parts of the view that describe the same night.

### 4.1 Sleep card header (summary line) uses local short-time formatting

When the user taps the Sleep card, the detail sheet's header line currently reads `<ISO bedtime> – <ISO wakeTime>` using the raw UTC ISO strings from HealthData. For a sleep session that ran from Thu 10:30 PM PDT to Fri 5:19 AM PDT, both ISO strings stamp the UTC calendar day (2026-04-24 in this case) even though the attribution convention used by the 7-day chart places the night on Thursday (the bed-day in local time). The viewer sees "2026-04-24T05:30:00Z – 2026-04-24T12:19:19Z" and concludes Friday — while the chart attributes it to Thursday — and the two parts of the panel contradict each other.

**Fix:** render the header as local-time, short-form times only, no dates — for example `10:30pm – 5:19am`. The chart's day labeling (Sun / Mon / … / Thu) plus the header's short-time range together convey the same night without either repeating or contradicting the attribution. If one end of the range is unavailable, render just the known end (`10:30pm –` or `– 5:19am`). If both are unavailable, fall back to the existing `"last night"` label.

Formatting helper to reuse: the `formatTime` utility already used by the share summary builder.

### 4.2 Displayed Avg matches the bars (source-filtered + noon-to-noon)

The chart in the sheet bar-stacks the `aggregateSleepDetailed` output (noon-to-noon attribution, per-source filterable). The header Avg text is computed separately from the older `aggregateSleep` output (midnight-attribution, all-sources merged through inBed-inclusive overlap logic). With the `Unknown` tab selected, the bars might sum to ~7.85h/day while the Avg still reads 10.4h/day — a ~30% lie.

**Fix:** when the Sleep sheet is open, compute the Avg directly from the same data the bars render — i.e. from `sleepDetailed.totalHours` for the currently selected source tab. The number the user sees in the Avg line must always equal the mean of the bars they see.

This decouples the Sleep Avg entirely from the legacy `aggregateSleep` path. Other metrics (non-sleep) keep using their existing Avg calculation.

### 4.3 Dropped-tracking indicator + sleep-onset surface (revised 2026-04-24)

Two observations from early use of the initial 4.3 implementation:

- Folding Awake-in-bed time into the "gap" number double-counted it: the chart already shows Awake as gray segments, AND the `⚠ gap` label silently rolled that same time in. A night with 1h of mid-night Awake and zero dropped data read as `⚠ gap 1h` — misleading.
- The pre-sleep Awake period (the "winding down before falling asleep" time) is useful information on its own, and users noticed it being absorbed into the gap value instead of surfaced.

**Revised model:** split "time spent not actually sleeping" into two distinct concepts per night:

1. **`⚠ gap Ym`** — truly untracked time only. `(wakeTime − bedtime) − (Core + Deep + REM + Awake-in-session)`. When this exceeds `max(30 min, 10% × in-bed range)`, flag the row.
2. **`onset Xm`** — sleep-onset latency. Awake time directly preceding the first actual-sleep sample, walking backwards and stopping when the gap to the previous Awake segment (or to sleep) exceeds **1 hour**. The 1-hour rule discards "noise Awake" — e.g. a Watch that briefly detected bed-like activity hours before the real bedtime and went idle before re-engaging at actual bedtime. Only surface when `onset ≥ 10 min` so very short values don't clutter the row.

Both labels can appear on the same row; neither is required. Tapping the row still opens the existing day-zoom card; these markers are passive information, not new interactions.

Mid-night Awake (bathroom breaks, brief stirs) remains visible as gray segments in the stacked bar and is no longer labeled textually — the chart already communicates it.

The `onset` calculation is heuristic, targeting a low false-positive rate. A Watch that both detects bed-activity 3 hours before real bedtime AND briefly re-engages just before real bedtime would correctly show only the true onset; a Watch that stays continuously engaged from early-bed-activity through real sleep would over-report onset — an edge case we accept.

## Phase 4 acceptance

- With the Sleep card's header date-range visible, the rendered text contains no `T00:00:00` / `Z` / `YYYY-MM-DD` substrings. It shows only local short-form times separated by an en-dash.
- With the `Unknown` (or any other) sleep source tab selected, the Avg number equals the arithmetic mean of the non-null bar heights visible in the chart, rounded to 1 decimal.
- The `⚠ gap` label is based on truly untracked time only — Awake samples inside `[bedtime, wakeTime]` are counted as *covered* and not folded into the gap number.
- A night with only Awake time filling the "non-sleep" window (i.e. no truly missing samples) never flags `⚠ gap`.
- A night with ≥ 10 minutes of pre-sleep Awake time directly adjacent to the first sleep moment renders an `onset Xm` label; Awake segments separated from sleep by > 1 hour of untracked time are discarded and do not contribute to the `onset` value.
- Both `onset` and `⚠ gap` labels may appear on the same row independently.
- The two other metrics that share the sheet's Avg path (HRV-style whisker averages and generic DailyValue averages) are unchanged.

