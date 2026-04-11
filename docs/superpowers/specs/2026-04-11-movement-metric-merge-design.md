# Movement Metric Merge — Design Spec

## Summary

Collapse the three correlated movement-volume metrics — **Steps**, **Walking Distance**, and **Active Energy** — into a single `Movement` card in the dashboard grid, and a single detail sheet that renders all three as overlaid normalized lines on one chart plus a daily breakdown with absolute values.

## Problem

The dashboard currently has three separate cards for Steps, Walking Distance, and Active Energy (`App.tsx` metrics array). On real data these three values are ~90% correlated — more steps means more distance means more energy burned. Showing them as three independent cards:

1. **Wastes grid real estate.** Three cards tell substantially the same story.
2. **Fragments the mental model.** The user thinks "did I move today?" — not three separate questions.
3. **Makes correlation invisible.** With each metric on its own card with its own box plot, you can't see "I walked more distance per step than usual" (= I ran today).

The fix is to merge the three into one card for the grid and one chart for the detail sheet, while keeping all three absolute values accessible.

## Goals

- One `Movement` card in the main grid replaces three cards.
- Tapping the card opens a detail sheet with a chart showing all three as overlaid lines.
- Absolute values for all three remain visible (in the card subtext and in the daily breakdown).
- Correlation between the three is readable at a glance on the chart.
- No changes to HealthKit queries — still fetch all three.
- No changes to the exported JSON shape (`lib/share.ts`).

## Non-Goals

- No new metrics derived from the three (no "move score," no percent-of-goal, no composite).
- No changes to box plot rendering for the *individual* metrics elsewhere (the summary banner still mentions steps etc.).
- No removal of steps/distance/energy from the data pipeline — they're still individually exported and still power the "Grab Context" AI snapshot.

## Design

### 1. Grid card — Option A (stacked primary + subtext)

One card, Steps as the big headline number, Distance and Energy as a single secondary line of subtext. Steps wins as primary because it's the most universally understood number and has the biggest magnitude (so the font-size hierarchy reads correctly).

```
┌──────────────────────────┐
│ Movement                 │
│ 8,241                    │
│ 5.2 km · 423 kcal        │
└──────────────────────────┘
```

- **Card label:** `Movement`
- **Big value:** steps count (e.g., `8,241`). Null → em-dash.
- **Subtext line:** `<distance> km · <energy> kcal` (e.g., `5.2 km · 423 kcal`). If any sub-value is null, display `—` for that part but keep the line: `5.2 km · — kcal`. If steps is null AND both sub-values are null, the whole card shows em-dash and no subtext.
- **Box plot:** none on the grid card (the individual metrics' box plots move to the detail sheet).
- **Tap target:** full card → opens `MetricDetailSheet` with `metricKey = "movement"`.

This replaces three entries in the `metrics` array in `App.tsx` (the steps, walkingDistance, and activeEnergy `MetricCardProps` entries).

### 2. Detail sheet — Option 1 (normalized overlay chart + absolute daily rows)

Tapping the Movement card opens a detail sheet with two sections:

**Top: normalized overlay line chart.**

Three lines, each scaled to `value / max(series, 7day) × 100`, rendered on a shared 0–100% Y axis. All three lines use distinct colors from the existing palette.

```
┌─────────────────────────────────────┐
│ Movement                         ×  │
├─────────────────────────────────────┤
│ Last 7 days                         │
│                                     │
│ 100% ┤      ╭╮                      │
│      │     ╱  ╲    ╭─ Steps ────    │
│  50% ┤   ╱     ╲_╱ ╰─ Distance ━━   │
│      │  ╱           ╰─ Energy  ─ ─  │
│   0% ┴──┴──┴──┴──┴──┴──┴──          │
│      Mon Tue Wed Thu Fri Sat Sun    │
│                                     │
│  ● Steps     max 12,500             │
│  ● Distance  max 9.3 km             │
│  ● Energy    max 620 kcal           │
└─────────────────────────────────────┘
```

- **Y axis:** 0 to 100%, shared by all three series.
- **Colors:** reuse the existing per-metric colors from `METRIC_CONFIG`:
  - Steps → its current color (`#4cc9f0`)
  - Walking Distance → its current color
  - Active Energy → its current color
- **Legend:** beneath the chart, one row per series with `<color dot> <name> max <absolute>`.
- **No box plots in the overlay.** Box plots across three normalized series would be visually unreadable. Absolute box plots for each individual metric live in the daily breakdown rows below.

**Bottom: daily breakdown.**

The existing `MetricDetailSheet` daily breakdown pattern (one row per day, showing the date and the metric value) generalizes to three values per day:

```
Thu Apr 9
  Steps     8,241
  Distance  5.2 km
  Energy    423 kcal

Wed Apr 8
  Steps     7,102
  Distance  4.8 km
  Energy    389 kcal
```

The absolute values the user taps to see live here. Tapping a day in the overlay chart scrolls the daily breakdown to that day.

### 3. Data model

**New `MetricKey`:** `"movement"`. Add to `lib/weekly.ts`:

```typescript
export type MetricKey =
  | "steps"
  | "heartRate"
  // ... existing keys
  | "movement";
```

**New `METRIC_CONFIG` entry:**

```typescript
movement: {
  label: "Movement",
  unit: "",              // composite — no single unit
  color: "#4cc9f0",      // inherits steps's color for card headline styling
  chartType: "line",     // new semantic: "composite-line"? see below
  sublabel: "today",
},
```

The existing `chartType: "bar" | "line"` doesn't cleanly describe "three-series normalized overlay." Two options:

- **(a) Reuse `"line"`** and let the detail sheet branch on `metricKey === "movement"` explicitly. Simplest. Scales to zero additional composite metrics.
- **(b) Add `chartType: "movement"`** as a third value. More honest. But only one metric uses it.

Going with (a) — explicit branch in `MetricDetailSheet` on `metricKey === "movement"`. If we ever add another composite we can revisit.

**New helper in `lib/weekly.ts`:**

```typescript
export type MovementSeriesDay = {
  dateKey: string;
  steps: number | null;
  distanceKm: number | null;
  energyKcal: number | null;
};

export type MovementOverlayData = {
  days: MovementSeriesDay[];        // sorted ascending by date
  stepsMax: number;                 // for normalization + legend
  distanceMax: number;
  energyMax: number;
  stepsNormalized: (number | null)[];   // same order as days, 0-1
  distanceNormalized: (number | null)[];
  energyNormalized: (number | null)[];
};

export function buildMovementOverlay(
  stepsDaily: DailyValue[],
  distanceDaily: DailyValue[],
  energyDaily: DailyValue[],
): MovementOverlayData;
```

Normalization: `value / max` where `max = Math.max(...series.filter(nonNull))`, or 1 if max is 0 / all null. Null values stay null and produce gaps in the line (existing `LineChart` behavior).

### 4. Chart component

`components/LineChart.tsx` currently accepts a single series. Extend it to optionally accept multiple:

```typescript
type LineChartSeries = {
  label: string;
  color: string;
  data: (number | null)[];          // normalized 0-1 or raw, depending on caller
  maxLabel?: string;                // e.g., "12,500 steps" for the legend
};

type LineChartProps = {
  // existing single-series props retained for backwards compat
  series?: LineChartSeries[];       // new: if present, renders multi-series
  // ... other props
};
```

**Backwards compatibility:** existing single-metric callers (heart rate, HRV, weight) keep working via the old props. New `Movement` caller uses `series`.

**Multi-series rendering rules:**
- Y axis 0 to 1 (normalized) or 0 to maxOfAllSeries (raw).
- Each series rendered as its own polyline with its own stroke color.
- Legend rendered inside the chart component or just below, one row per series.
- Box-and-whisker rendering disabled when `series.length > 1` — too visually busy.

### 5. Files to change

| File | Change |
|---|---|
| `lib/weekly.ts` | Add `"movement"` to `MetricKey`, add `METRIC_CONFIG.movement`, add `buildMovementOverlay` and types |
| `components/LineChart.tsx` | Accept optional `series: LineChartSeries[]` prop |
| `components/MetricDetailSheet.tsx` | Branch on `metricKey === "movement"` — render overlay chart + combined daily breakdown |
| `App.tsx` | Remove steps/walkingDistance/activeEnergy cards from `metrics` array, add single movement card; wire movement card tap to `MetricDetailSheet` |
| `__tests__/weekly.test.ts` | New tests for `buildMovementOverlay` normalization |

### 6. Color choices

The three existing metric colors are already in `METRIC_CONFIG`:
- Steps: `#4cc9f0` (cyan)
- Walking Distance: some existing color
- Active Energy: some existing color

Reuse them on the overlay chart so the card colors in the other contexts match the chart lines. This preserves the association the user already has.

## Edge cases

| Case | Handling |
|---|---|
| Steps is null, distance + energy are null | Card shows `—` with no subtext; chart shows empty state |
| All three series have all-null 7 days | Chart empty state, same as any other metric with no data |
| Today's values are live, past days are from cache | Existing `healthCache` behavior — no change needed |
| One series max is 0 (e.g., no energy recorded) | Normalize against 1 to avoid divide-by-zero; line renders as flat at 0 |
| User tapped the old steps/distance/energy cards via Maestro testID | testIDs removed — update `.maestro/*.yaml` references if any |

## Acceptance criteria

1. The grid no longer has separate cards for Steps, Walking Distance, or Active Energy.
2. A single `Movement` card appears in the grid, with steps as the big number and `<distance> · <energy>` as the subtext.
3. Tapping the Movement card opens `MetricDetailSheet` with `metricKey === "movement"`.
4. The detail sheet shows one line chart with three normalized series (steps, distance, energy) and a legend listing each series' absolute 7-day max.
5. The daily breakdown below the chart shows three values per day (steps, distance, energy).
6. Null values render as em-dashes in the card subtext and as gaps in the chart (existing LineChart behavior).
7. `lib/share.ts` exports are unchanged — the JSON still has separate `steps`, `walkingDistance`, `activeEnergy` fields.
8. Existing box-plot rendering for *other* metrics (heart rate, HRV, weight) is unchanged.
9. `npx tsc --noEmit` clean.
10. `npx jest` green.

## Testing

### `__tests__/weekly.test.ts`

New describe block `buildMovementOverlay`:

- Basic normalization: three series of equal length → each day normalized against its own series max → results in range [0, 1]
- All-null series → max = 1, normalized values all null
- Single non-null day → max = that value, that day normalizes to 1.0
- Mixed nulls → gaps preserved

### Manual test plan

1. Open the app, verify Movement card appears in place of the three old cards.
2. Verify steps number dominates visually and `<distance> · <energy>` sub-line is readable.
3. Tap Movement → detail sheet opens with three overlaid lines and a legend.
4. Scroll down → daily breakdown shows three values per day.
5. Share the context JSON → verify steps, walkingDistance, activeEnergy still present as separate fields.

## Dependencies on other specs

- Uses the existing metric detail sheet architecture from `docs/superpowers/specs/2026-03-15-7-day-metric-detail-design.md`.
- No changes to that spec needed; this spec extends one metric key's rendering without touching the infrastructure.
