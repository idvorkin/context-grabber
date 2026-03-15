# 7-Day Metric Detail View — Design Spec

## Overview

Add a tap-to-drill-down feature to the Context Grabber dashboard. When a user taps any metric card (steps, heart rate, sleep, etc.), a full-screen sheet slides up showing a 7-day chart and daily breakdown for that metric.

## Goals

- Let users see trailing 7-day trends for every health metric
- Keep the app dependency-light (no navigation library, no charting library)
- Maintain the existing dark aesthetic while creating a "deep dive" feel

## Non-Goals

- No navigation library (single drill-down doesn't justify the dependency)
- No charting library (simple 7-day visualizations are achievable with RN Views)
- No changes to the existing "Grab Context" or share flow
- No persistent storage of weekly data

---

## Data Layer

### MetricKey Type and Configuration

```typescript
type MetricKey = "steps" | "heartRate" | "sleep" | "activeEnergy" | "walkingDistance" | "weight" | "meditation";

type ChartType = "bar" | "line";

type MetricConfig = {
  label: string;
  unit: string;
  color: string;
  chartType: ChartType;
  sublabel: string;
};

const METRIC_CONFIG: Record<MetricKey, MetricConfig> = {
  steps:           { label: "Steps",            unit: "steps",  color: "#4cc9f0", chartType: "bar",  sublabel: "today" },
  heartRate:       { label: "Heart Rate",       unit: "bpm",    color: "#f72585", chartType: "line", sublabel: "latest" },
  sleep:           { label: "Sleep",            unit: "hrs",    color: "#7b2cbf", chartType: "bar",  sublabel: "last night" },
  activeEnergy:    { label: "Active Energy",    unit: "kcal",   color: "#ff9e00", chartType: "bar",  sublabel: "today" },
  walkingDistance:  { label: "Walking Distance", unit: "km",     color: "#06d6a0", chartType: "bar",  sublabel: "today" },
  weight:          { label: "Weight",           unit: "kg",     color: "#4895ef", chartType: "line", sublabel: "latest" },
  meditation:      { label: "Meditation",       unit: "min",    color: "#e0aaff", chartType: "bar",  sublabel: "today" },
};
```

### DailyValue Types

```typescript
// date format: "YYYY-MM-DD" (e.g., "2026-03-15")
type DailyValue = { date: string; value: number | null };

type HeartRateDaily = {
  date: string;
  avg: number | null;
  min: number | null;
  max: number | null;
};
```

Note: The `WeeklyMetricData` aggregate type is not needed since data is fetched per-metric. The cache state is typed as:

```typescript
type WeeklyCache = Partial<Record<MetricKey, DailyValue[] | HeartRateDaily[]>>;
```

### New HealthKit Queries

A new function in `App.tsx`:

```typescript
async function grabWeeklyData(metric: MetricKey): Promise<DailyValue[] | HeartRateDaily[]>
```

This dispatches to the appropriate HealthKit query based on metric key:

| Metric | HealthKit Method | Identifier | Daily Aggregation |
|--------|-----------------|------------|-------------------|
| Steps | `queryStatisticsForQuantity` per day | `HKQuantityTypeIdentifierStepCount` | Sum |
| Heart Rate | `queryQuantitySamples` for 7 days | `HKQuantityTypeIdentifierHeartRate` | Avg / Min / Max per day |
| Sleep | `queryCategorySamples` for 7 nights | `HKCategoryTypeIdentifierSleepAnalysis` | Hours per night (overlap-merged) |
| Active Energy | `queryStatisticsForQuantity` per day | `HKQuantityTypeIdentifierActiveEnergyBurned` | Sum |
| Walking Distance | `queryStatisticsForQuantity` per day | `HKQuantityTypeIdentifierDistanceWalkingRunning` | Sum |
| Weight | `queryQuantitySamples` for 7 days | `HKQuantityTypeIdentifierBodyMass` | Latest value per day |
| Meditation | `queryCategorySamples` for 7 days | `HKCategoryTypeIdentifierMindfulSession` | Sum minutes per day (no overlap merge — matches existing behavior) |

**Error handling**: Wrapped in try/catch. On failure, the sheet shows an error message within the sheet (not a dismiss). HealthKit authorization is assumed already granted from the initial "Grab Context" — no re-request.

### Fetching Strategy

- **Lazy**: Weekly data is fetched only when the user taps a card, not during "Grab Context"
- **Cached**: Results are stored in `weeklyCache` state (`WeeklyCache`) so re-tapping doesn't re-fetch
- **Per-metric**: Only the tapped metric's data is fetched
- **Cache invalidation**: Cache is cleared when a new "Grab Context" is performed (fresh snapshot = stale weekly cache)

### New Pure Module: `lib/weekly.ts`

Functions to bucket raw HealthKit samples into daily arrays:

- `bucketByDay(samples, startDate, days)` — generic day-bucketing helper
- `aggregateHeartRate(samples, startDate)` — buckets HR samples, computes avg/min/max per day → `HeartRateDaily[]`
- `aggregateSleep(samples, startDate)` — applies overlap-merge per night (reuses logic from `lib/health.ts`), returns hours → `DailyValue[]`
- `aggregateMeditation(sessions, startDate)` — sums minutes per day (no overlap merge) → `DailyValue[]`
- `pickLatestPerDay(samples, startDate)` — for weight: picks latest sample per day → `DailyValue[]`
- `computeAverage(dailyValues)` — 7-day average for the summary line

All types (`DailyValue`, `HeartRateDaily`, `MetricKey`, `MetricConfig`, `METRIC_CONFIG`) are exported from `lib/weekly.ts`.

All pure, all testable without HealthKit.

---

## Interaction & Animation

### Making Cards Tappable

- `MetricCard` gets a new `metricKey: MetricKey` prop and `onPress: (key: MetricKey) => void` prop
- Wraps existing content in `TouchableOpacity`
- Only tappable when a snapshot exists (cards aren't shown without one, so this is implicit)

Updated `MetricCardProps`:

```typescript
type MetricCardProps = {
  metricKey: MetricKey;
  label: string;
  value: string;
  sublabel: string;
  fullWidth?: boolean;
  onPress: (key: MetricKey) => void;
};
```

### Detail Sheet Lifecycle

1. User taps card → `selectedMetric` state set to metric key
2. Sheet renders, slide-up animation begins
3. Semi-transparent overlay fades in behind the sheet
4. If `weeklyCache[metricKey]` exists, render immediately; otherwise show loading spinner and fetch
5. Chart + daily breakdown renders
6. Dismiss: tap "X" button or swipe down
7. Sheet slides down, overlay fades out, `selectedMetric` set to null

### Animation Details

- Single `Animated.Value` drives both animations via interpolation:
  - Sheet `translateY`: `screenHeight → 0`
  - Overlay `opacity`: `0 → 0.6` (interpolated from the same animated value)
- `Animated.timing` with `useNativeDriver: true`
- Duration: 300ms, easing: `Easing.out(Easing.cubic)`

### Swipe-to-Dismiss

- The header area (above the daily breakdown) has a `PanResponder`
- The sheet follows the finger during downward swipe (gesture tracking via `translateY`)
- On release: if swipe distance > 100px, animate to dismiss; otherwise snap back
- Upward swipes are no-ops (clamped at 0)
- The daily breakdown list uses a `ScrollView` that is **separate** from the PanResponder zone — the PanResponder is only on the header + chart area, avoiding gesture conflicts with the scrollable breakdown list

---

## Visual Design

### Color Palette Per Metric

Defined in `METRIC_CONFIG` above. Summary:

| Metric | Accent Color | Hex |
|--------|-------------|-----|
| Steps | Cyan | `#4cc9f0` |
| Heart Rate | Warm Pink | `#f72585` |
| Sleep | Deep Purple | `#7b2cbf` |
| Active Energy | Amber | `#ff9e00` |
| Walking Distance | Mint Green | `#06d6a0` |
| Weight | Soft Blue | `#4895ef` |
| Meditation | Lavender | `#e0aaff` |

### Sheet Layout (top to bottom)

1. **Header bar** (inside PanResponder zone)
   - Metric name (16px semibold, accent color) — left aligned
   - Close "X" button — right aligned
   - Current value (36px bold, white) below the name
   - Sublabel below value (e.g., "today", "last night")

2. **Chart area** (~200px tall, inside PanResponder zone)
   - **Bar charts** for: Steps, Active Energy, Walking Distance, Sleep, Meditation
     - 7 vertical bars, rounded tops, evenly spaced
     - Bar height proportional to value vs week max
     - Current day highlighted with accent color; other days use accent at 30% opacity
     - Day labels (Mon, Tue...) below bars
   - **Line charts** for: Heart Rate, Weight
     - 7 dots connected by line, absolute-positioned Views
     - Heart Rate: shaded min/max range band behind avg line
     - Weight: dot-line with gaps for missing days

3. **7-day average line**
   - "Avg: 7,823 steps/day" in accent color
   - Centered below the chart

4. **Daily breakdown list** (inside ScrollView, separate from PanResponder)
   - 7 rows, most recent at top
   - Each row: day name + full date on left (e.g., "Mon, Mar 9"), value on right
   - Subtle `#222` dividers between rows
   - Null days show "—" in muted text
   - Heart rate rows show "72 avg (58–91)" format

### Sheet Background

`#111828` — darker than main app surface (`#1a1a2e`) to create depth.

### Typography

| Element | Size | Weight | Color |
|---------|------|--------|-------|
| Metric name | 16px | Semibold | Accent color |
| Current value | 36px | Bold | `#e0e0e0` |
| Sublabel | 13px | Regular | `#888` |
| Chart day labels | 11px | Regular | `#666` |
| Average line | 14px | Semibold | Accent color |
| Daily breakdown day | 15px | Semibold | `#e0e0e0` |
| Daily breakdown value | 15px | Regular | `#aaa` |

---

## File Structure

### New Files

| File | Purpose |
|------|---------|
| `lib/weekly.ts` | Types (`DailyValue`, `HeartRateDaily`, `MetricKey`, `MetricConfig`, `METRIC_CONFIG`), pure functions (bucketing, aggregation, averages) |
| `__tests__/weekly.test.ts` | Tests for all weekly.ts functions |
| `components/MetricDetailSheet.tsx` | Full-screen slide-up sheet with header, chart, breakdown, animations, PanResponder |
| `components/BarChart.tsx` | Pure RN bar chart (takes `DailyValue[]` + accent color) |
| `components/LineChart.tsx` | Pure RN line chart (takes `DailyValue[]` or `HeartRateDaily[]` + accent color) |

Note: The `components/` directory is new. This is the first extraction of UI components out of `App.tsx`. `MetricCard` stays in `App.tsx` for now since it's small and tightly coupled to the metrics array.

### Modified Files

| File | Changes |
|------|---------|
| `App.tsx` | Add `metricKey` and `onPress` to MetricCard, add `selectedMetric` and `weeklyCache` state, add `grabWeeklyData()` function, render `MetricDetailSheet` conditionally, clear cache on new grab |

### Unchanged

- `lib/health.ts`, `lib/sleep.ts`, `lib/location.ts`, `lib/summary.ts` — no changes
- Existing "Grab Context" flow (except clearing weekly cache)
- Snapshot/share JSON behavior
- All existing tests
- No new npm dependencies

---

## Testing

- `lib/weekly.ts` — fully tested with mock data:
  - `bucketByDay`: normal case, gaps, empty input
  - `aggregateHeartRate`: multiple readings per day, days with no data
  - `aggregateSleep`: overlapping intervals, single source, no data
  - `aggregateMeditation`: multiple sessions per day, zero-duration sessions
  - `pickLatestPerDay`: multiple weights per day, missing days
  - `computeAverage`: with nulls, all nulls, normal case
- Chart components — take plain data arrays, visual testing not required
- HealthKit queries — device-only, not unit tested (matches existing pattern)
- Integration — manual testing on physical iPhone
