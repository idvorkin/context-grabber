# Sleep Display Phase 3 — Implementation Plan

Implementation notes for Phase 3 of the sleep display enhancements. The user-facing behavior lives in [`2026-04-11-sleep-display-enhancements-design.md`](../specs/2026-04-11-sleep-display-enhancements-design.md#phase-3--source-filtering-layout-fixes-day-zoom-2026-04-11-revision). This plan is the engineering side only — no behavior decisions here.

## Scope

Four tasks from Phase 3 of the spec: source filtering that actually switches the view, sheet layout rework, day-click zoom card, and enlarged daily rows. All changes live in `components/MetricDetailSheet.tsx`, `components/SleepStageStrip.tsx`, `lib/sleep.ts`, and `App.tsx`. No HealthKit work, no SQLite schema changes.

## 3.1 Source filtering

### Data shape

Replace the single `sleepDetailed: SleepDaily[]` prop passed to `MetricDetailSheet` with a bundle:

```typescript
type SleepDetailedBundle = {
  bySource: Record<string, SleepDaily[]>;  // keyed by source name
  merged: SleepDaily[];                     // all sources deduped (existing behavior)
};
```

### Aggregation

`lib/sleep.ts` already has `aggregateSleepDetailed(samples, endDate, days)`. Two options:

- **(A)** Add an optional `sourceFilter?: (sample: SleepSample) => boolean` arg.
- **(B)** Have callers pre-filter samples and call the existing function once per source.

Lean toward **(B)** — no new parameter, the function stays pure and obvious, and `App.tsx` already walks samples once.

### Wiring in App.tsx

`handleMetricPress("sleep")` currently builds `sleepDetailedCache` as a single `SleepDaily[]`. Replace with a `SleepDetailedBundle`:

1. Collect the unique `sourceName` values from the 7-day sample window.
2. For each source, filter samples to that source and call `aggregateSleepDetailed` → add to `bySource`.
3. Build `merged` the same way the current code does (all samples) → store in `merged`.
4. Prop drill the bundle to `MetricDetailSheet`.

`sleepDetailedCache` is in-memory only, no persistence migration.

### Tab UI

`MetricDetailSheet` sleep branch owns `selectedSource: string` state. Default `"All"`. Tabs list is `["All", ...Object.keys(bundle.bySource).sort()]`. The array currently feeding the chart/stats/consistency/day-list reads `selectedSource === "All" ? bundle.merged : bundle.bySource[selectedSource]`.

Every memo that currently depends on `sleepDetailed` needs to depend on the resolved array instead: `sleepDebt`, `sleepConsistency`, `lastNightStages`, `dailyRows` for sleep, the stacked bar chart data. Audit each `useMemo` in the sleep branch.

Existing `sleepBySource` prop (a flat `Record<string, SourceSleepSummary>` used for the bottom pill row) stays untouched for now — it's a different concept (today-only stage summary) and can be deleted in a follow-up if it's no longer meaningful once the tabs drive everything.

## 3.2 Layout rework

Current structure in `MetricDetailSheet.tsx`:

```
<Animated.View sheet>
  <View panHandlers>           ← drag-to-dismiss zone
    dragHandle
    header
    currentValue
    sourceTabs (sleep)
    timeline (exercise)
    hourlyBoxPlot (whisker)
    chart
    averageText
    movementStats
    sleepStatsBlock            ← debt + stage % + consistency chart
  </View>
  workoutSection (exercise)
  <ScrollView>
    rawSection
    dailyRows
    debugSection
  </ScrollView>
</Animated.View>
```

Target structure:

```
<Animated.View sheet>
  <View panHandlers>           ← drag-to-dismiss zone, minimal
    dragHandle
    header
    currentValue
  </View>
  <ScrollView>
    sourceTabs
    timeline
    hourlyBoxPlot
    chart
    averageText
    movementStats
    sleepStatsBlock
    workoutSection
    zoomedDayCard (sleep only, when selected)
    rawSection
    dailyRows
    debugSection
  </ScrollView>
</Animated.View>
```

The `panResponder` instance stays attached to the top fixed view. The ScrollView already exists; just expand what it wraps. Watch out for layout: the sheet has `maxHeight: "90%"`, and the fixed zone now shrinks, so the ScrollView's `flexShrink: 1` plus `flex: 1` may be needed to let it grow. Verify the `currentValue` doesn't overflow on short content.

Gesture note: `PanResponder` on the top view will no longer get chart-area drags. That's the intended trade-off in the spec.

## 3.3 Zoomed day card

### Component

New stateless component `components/ZoomedSleepDayCard.tsx` (or inlined into `MetricDetailSheet` — prefer extracted for readability). Takes:

```typescript
type Props = {
  night: SleepDaily;  // from the currently-resolved (source-filtered) array
  color: string;      // config.color for the sleep metric
};
```

Renders:
- Row 1: date label (large) + total hours + "bedtime → wake time"
- Row 2: `<SleepStageStrip samples={night.samples} bedtime={night.bedtime} wakeTime={night.wakeTime} height={48} />`
- Row 3: hour tick labels underneath the strip, one per whole hour between bedtime and wake time (grey, small)
- Row 4: stage percentages, colored per stage (reuse the `stagePercentRow` style logic)

Null night (no bedtime/wake): render a centered "No sleep data for this night" with the card border, no strip, no percentages.

### Hour tick labels

Walk from `ceil(bedtime)` to `floor(wakeTime)` in 1-hour steps, compute each tick's `left` as a percentage of the window, render as `<Text>` absolutely positioned under the strip. Format: `11pm`, `12a`, `1a`, `2a`, …. Same `formatTime` helper the strip uses.

If the window is very short (<3 hours), fall back to every 30 min. If very long (>12 hours, shouldn't happen but defensively), fall back to every 2 hours.

### Selection wiring

`selectedDay` is already tracked via `onDayPress` on the stacked bar chart. In the sleep branch, resolve the selected night: `resolvedNights.find(n => n.date === selectedDay)`. Render the card when found. Hide the `stagePercentRow` under the chart while `selectedDay !== null`.

Tapping the same day again should toggle: the existing `setSelectedDay(selectedDay === date ? null : date)` handler already does this — verify it applies.

### Stage strip height prop

`components/SleepStageStrip.tsx` currently hardcodes `height: 10`. Add an optional `height` prop, default 10, and apply it to `styles.strip`. Daily rows in the list pass `18`, zoomed card passes `48`. The styles object becomes a function of `height` or falls back to inline style override — inline override is simpler.

## 3.4 Daily row typography

In `components/MetricDetailSheet.tsx` styles:

- `dayRow.paddingVertical`: 12 → 16
- `dayRowLabel.fontSize`: 15 → 17
- `dayRowValue.fontSize`: 15 → 17
- `SleepStageStrip` height passed from sleep daily rows: 10 → 18
- `SleepStageStrip` `timeLabel.fontSize`: 10 → 12 (apply in the component itself, since it's only used under strips)

Audit that non-sleep metrics still render fine with the bigger row — the dayRow styles are shared. They should be fine; just confirm manually.

## Test plan

### Automated

`__tests__/sleep.test.ts`:
- `aggregateSleepDetailed` called with samples from a single source → returns only that source's nights.
- Two sources over the same window produce independent `SleepDaily[]` arrays; each has its own bedtime/wake.
- A source with zero samples in the 7-day window → empty array.

No new tests for the layout rework (pure UI), zoomed card (UI only), or typography (style only). Manual verification per the spec's manual test plan.

### Manual

Follow the spec's manual test plan section verbatim.

## Rollout

One PR, commits in this order so each stage is independently reviewable:

1. `lib/sleep.ts` + `__tests__/sleep.test.ts`: per-source aggregation tests (no code change if option B).
2. `App.tsx`: build and pass the `SleepDetailedBundle`.
3. `components/MetricDetailSheet.tsx`: source filtering drives all sleep-derived memos.
4. `components/MetricDetailSheet.tsx`: layout rework — move content into ScrollView.
5. `components/SleepStageStrip.tsx`: add `height` prop.
6. `components/ZoomedSleepDayCard.tsx` + wiring in `MetricDetailSheet.tsx`: zoom card.
7. `components/MetricDetailSheet.tsx`: daily row typography bumps.

Run `npx tsc --noEmit` and `npx jest` after each stage.

## Risks

- **Gesture regression.** Moving content out of the PanResponder zone may make the sheet feel harder to dismiss if the drag handle is hard to hit on short phones. Mitigation: make sure the tap target on the handle is generous (already 36×4 visual, 48×24 hit slop worth checking).
- **`sleepBySource` prop becoming dead code.** It still drives the pill row that was the old "source summary". If that row is removed by the tabs-drive-everything change, delete the prop + the computation in `App.tsx`. Don't leave it orphaned.
- **Cache shape change not persisted.** `sleepDetailedCache` is in-memory, so no migration. But any component that reads the old shape from the cache directly needs the update. Grep for `sleepDetailedCache` to catch consumers.
- **ScrollView inside a sheet with its own pan.** React Native Gesture Handler can have conflicts between a `PanResponder` parent and a `ScrollView` child. If touches on the scroll area start triggering dismissal, the fix is a gesture-handler rework — but the current plan keeps the PanResponder only on the fixed top view, so this should be clean.
