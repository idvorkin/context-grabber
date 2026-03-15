# At-a-Glance Dashboard UI

## Summary

Replace the current raw data display with a polished dashboard — a natural language summary at top for quick scanning, and visual metric cards below for detail.

## Goals

- Glanceable one-liner summary of current state
- Visual metric cards with icons for each health data point
- Location tracking status visible at a glance
- Maintain existing dark theme aesthetic

## Non-Goals

- Charts or graphs
- Historical trends (just current snapshot)
- Map view of location trail
- Animations

## Design

### 1. Summary Banner

A single natural-language line at the top of the snapshot, auto-generated from the data:

> "8,241 steps | Slept 7.2hrs (11pm–6:15am) | 73 bpm | 142 locations"

- Adapts to available data — omits metrics that are null
- Uses short readable formats: "11pm" not "2026-03-15T23:00:00Z", "7.2hrs" not "7.2 hours"
- Subtle background, smaller font — designed for scanning not reading

### 2. Metric Cards

Grid of compact cards (2 columns), each showing:

```
┌─────────────────┐
│ 🚶  Steps       │
│ 8,241           │
│ today            │
└─────────────────┘
```

**Cards** (in order):
- Steps (today)
- Heart Rate (latest bpm)
- Sleep (hours + bedtime → wake range)
- Active Energy (kcal)
- Walking Distance (km)
- Weight (kg, most recent)
- Meditation (minutes today)

Each card:
- Icon/emoji left-aligned with label
- Large number as the primary visual
- Subtle sublabel ("today", "latest", "last 24h")
- Null values show "—" with dimmed styling
- Consistent card size in a 2-column grid

### 3. Location Section

Below the health cards:

```
┌──────────────────────────────────────┐
│ 📍  Location                         │
│ Current: 47.6062, -122.3321          │
│ Tracking: ON · 142 points · 30d     │
└──────────────────────────────────────┘
```

- Current GPS coordinate
- Tracking status, point count, retention window
- Full-width card (not in grid)

### 4. Layout Structure

```
┌──────────────────────────────────────┐
│ Context Grabber                      │
│ Grab your iPhone context...          │
├──────────────────────────────────────┤
│ "8,241 steps | Slept 7.2hrs..."      │  ← Summary banner
├──────────┬───────────────────────────┤
│ Steps    │ Heart Rate               │  ← Metric cards (2-col grid)
│ 8,241    │ 73 bpm                   │
├──────────┼───────────────────────────┤
│ Sleep    │ Energy                   │
│ 7.2 hrs  │ 423 kcal                │
├──────────┼───────────────────────────┤
│ Distance │ Weight                   │
│ 5.2 km   │ 78.3 kg                 │
├──────────┴───────────────────────────┤
│ Meditation: 15 min                   │  ← Odd card spans full width
├──────────────────────────────────────┤
│ 📍 Location                         │  ← Location card
│ Current: 47.6062, -122.3321          │
│ Tracking: ON · 142 points · 30d     │
├──────────────────────────────────────┤
│       [ Grab Context ]               │
│       [ Share JSON   ]               │
└──────────────────────────────────────┘
```

### 5. Styling

Follows existing dark theme:
- Background: `#1a1a2e` (existing)
- Cards: `#16213e` (existing card color)
- Card accent/icon color: `#4cc9f0` (existing cardTitle color)
- Values: `#e0e0e0` (large, bold)
- Labels: `#888` (small, subdued)
- Summary banner: `#0f3460` background, `#ccc` text
- Null/unavailable: `#555` text, "—"

## Implementation Notes

- Summary string is a pure function: `buildSummary(health, locationCount) → string` — testable
- Card grid uses `flexWrap: 'wrap'` with 2 items per row, each `width: '48%'`
- No new dependencies — just React Native StyleSheet + View/Text
- This is a visual restructure of the existing snapshot display, not new data

## Testing

Test infra (Jest + ts-jest) is already in place. Add tests for the summary builder.

### `__tests__/summary.test.ts`

- `buildSummary(health, locationCount)` → string
- All data present: includes steps, sleep, heart rate, location count
- Null steps: omits steps from summary
- Null sleep: omits sleep section
- All null health: returns minimal summary (just location count or empty)
- Zero location count: omits location from summary
- Formats numbers with commas (e.g., "8,241 steps" not "8241 steps")
- Formats sleep times as short form ("11pm" not "23:00:00")
- Rounds sleep hours to 1 decimal

### Extractable Pure Functions

Add to `lib/summary.ts`:
- `buildSummary(health: HealthData, locationCount: number): string`
- `formatTime(isoString: string): string` — "2026-03-15T23:00:00Z" → "11pm"
- `formatNumber(n: number): string` — 8241 → "8,241"

## File Changes

- `App.tsx` — replace the current `{snapshot && ...}` card section with dashboard layout
- `lib/summary.ts` — summary builder pure functions
- `__tests__/summary.test.ts` — new
- No dependency changes
- No permission changes

## Dependency on Other Specs

- Renders data from spec 1 (sleep details, weight, meditation, location history count)
- Should be implemented AFTER spec 1, or at least designed to handle null values for fields that spec 1 adds
