# Background Location Tracking + Health Enhancements

## Summary

Add background geolocation tracking over time to context-grabber, stored locally in SQLite, and include the location trail in the JSON export. Also extract bedtime/wake-up time from existing sleep data, and add weight and meditation metrics.

## Goals

- Track user location over time via iOS significant-change monitoring
- Store location history locally with configurable retention (default 30 days)
- Include location trail in the "Grab Context" JSON export
- Extract bedtime and wake-up time from HealthKit sleep samples
- Add weight (most recent) and meditation minutes (today) to health export
- All timestamps stored in UTC (unix milliseconds)

## Non-Goals

- High-frequency GPS tracking (routes/paths)
- Remote/cloud storage
- Sleep score computation
- Reverse geocoding (address lookup)
- Map visualization

## Architecture

Single-file app (App.tsx) remains the primary structure. It will grow from ~330 to ~500-600 lines — acceptable for a single-screen app with no routing. If it exceeds ~700 lines, extract SQLite and HealthKit helpers into separate modules.

### 1. Background Location Tracking

**Mechanism**: `expo-location` significant-change monitoring via `expo-task-manager`.

- iOS wakes the app on ~200-500m movement
- Typically 20-50 points/day
- Battery-friendly — uses cell/wifi triangulation, not continuous GPS
- Requires "Always" location permission

**Critical constraint**: `TaskManager.defineTask()` MUST be called at module scope (top level of the file), outside any React component. This is an expo-task-manager requirement — placing it inside `App()` will silently fail.

**Flow**:
1. User enables tracking via toggle in the UI (opt-in, defaults to off)
2. App requests background location permission
3. Background task (defined at module scope) handles location events
4. On each location event: insert into SQLite, prune old entries
5. Toggle state persisted in SQLite settings table

### 2. Sleep Detail Extraction

Derive bedtime and wake-up time from existing `HKCategoryTypeIdentifierSleepAnalysis` query:
- Sort sleep samples by `startDate` ascending before extracting times
- **Bedtime**: `startDate` of first sample in the sleep window
- **Wake time**: `endDate` of last sample in the sleep window
- No new HealthKit queries needed — uses same data we already fetch

### 3. New Health Metrics

- **Weight**: `getMostRecentQuantitySample(HKQuantityTypeIdentifierBodyMass)` — most recent reading in kg
- **Meditation**: `queryCategorySamples(HKCategoryTypeIdentifierMindfulSession)` — today's sessions, sum duration to minutes

## Storage

**Database**: expo-sqlite (included in Expo SDK 55)

```sql
CREATE TABLE IF NOT EXISTS locations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  accuracy REAL,                        -- meters, from coords.accuracy
  timestamp INTEGER NOT NULL            -- UTC unix milliseconds
);

CREATE INDEX IF NOT EXISTS idx_locations_timestamp ON locations(timestamp);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Schema versioning
INSERT OR IGNORE INTO settings (key, value) VALUES ('schema_version', '1');
```

**Settings keys**:
- `schema_version`: current schema version (for future migrations)
- `tracking_enabled`: "true" / "false" (default "false" — opt-in)
- `retention_days`: number as string (default "30")

**Pruning**: On app foreground (not every insert), delete rows where `timestamp < now - (retention_days * 86400000)`. Also prune immediately when user reduces retention days.

**Data volume**: ~50 points/day x 30 days = ~1,500 rows. Trivial for SQLite.

## Updated Export Shape

```typescript
type ContextSnapshot = {
  timestamp: string;                    // ISO 8601, UTC
  health: {
    steps: number | null;
    heartRate: number | null;
    sleepHours: number | null;
    bedtime: string | null;             // NEW — ISO 8601 UTC
    wakeTime: string | null;            // NEW — ISO 8601 UTC
    activeEnergy: number | null;
    walkingDistance: number | null;
    weight: number | null;              // NEW — kg, most recent
    meditationMinutes: number | null;   // NEW — today's total
  };
  location: {
    latitude: number;
    longitude: number;
    timestamp: number;                  // UTC unix ms
  } | null;
  locationHistory: Array<{             // NEW — full retention window
    latitude: number;
    longitude: number;
    accuracy: number | null;            // meters
    timestamp: number;                  // UTC unix ms
  }>;
};
```

Note: `settings` removed from export — it's app metadata, not user context. The AI coach doesn't need to know retention config.

**Export window**: Full retention period (all stored locations). At ~1,500 points max, the JSON is ~100KB — fine for share sheet. The AI receiving it can filter/cluster as needed.

## New Dependencies

- `expo-task-manager` — background task registration (npm install required, add to plugins array in app.json)
- `expo-sqlite` — already included in Expo SDK 55 (no install needed)

## Permissions Changes

**app.json additions** (merged with existing infoPlist, not replacing):
```json
{
  "plugins": [
    "expo-task-manager"
  ],
  "infoPlist": {
    "UIBackgroundModes": ["location"],
    "NSLocationAlwaysAndWhenInUseUsageDescription": "Context Grabber tracks your location in the background to build a location history for your AI life coach."
  }
}
```

Existing `NSLocationWhenInUseUsageDescription` and `NSHealthShareUsageDescription` entries remain unchanged.

**Runtime**: Request `Location.requestBackgroundPermissionsAsync()` when user enables tracking.

**HealthKit authorization** updated to include new read types:
- `HKQuantityTypeIdentifierBodyMass`
- `HKCategoryTypeIdentifierMindfulSession`

## UI Changes

- **Tracking toggle**: start/stop background location tracking
- **Retention setting**: input for number of days (default 30)
- **History indicator**: show count of stored locations (e.g., "142 locations tracked")
- **Location history section**: in the snapshot card, show summary of trail
- All new UI follows existing dark theme and component patterns

## Error Handling

- Background permission denied: show message, keep toggle off
- SQLite errors: log, don't crash — location tracking is best-effort
- Sleep sample edge cases (no data, single sample): return null for bedtime/wakeTime
- Missing settings rows: default to tracking_enabled=false, retention_days=30

## Testing

Test infra (Jest + ts-jest) is already in place. Add tests in `__tests__/` for new pure logic.

### `__tests__/sleep.test.ts`

- `extractSleepDetails(samples)` → `{ bedtime, wakeTime }`
- Samples sorted by startDate before extraction
- Single sample: bedtime = startDate, wakeTime = endDate
- Multiple samples: bedtime = first startDate, wakeTime = last endDate
- Empty samples: returns `{ bedtime: null, wakeTime: null }`
- Unsorted input: still returns correct min/max

### `__tests__/location.test.ts`

- Pruning logic: `pruneThreshold(retentionDays, now)` returns correct UTC cutoff timestamp
- Retention 30 days: threshold is exactly 30 * 86400000 ms before now
- Retention 0 days: prunes everything
- Retention change downward: immediate prune applies

### `__tests__/health.test.ts` (extend existing)

- Weight: null when no sample, returns kg value when present
- Meditation: null when no sessions, sums multiple sessions to minutes

### Extractable Pure Functions

Add to `lib/health.ts` (or new `lib/location.ts`, `lib/sleep.ts`):
- `extractSleepDetails(samples: SleepSample[]): { bedtime: string | null; wakeTime: string | null }`
- `pruneThreshold(retentionDays: number, now: number): number`
- Extend `buildHealthData` to handle weight + meditation results

## File Changes

- `App.tsx` — all changes (background task at module scope, SQLite setup, sleep extraction, UI additions)
- `app.json` — permission descriptions, UIBackgroundModes, expo-task-manager plugin
- `package.json` — add expo-task-manager dependency
- `lib/health.ts` or `lib/sleep.ts` — extracted pure functions
- `lib/location.ts` — pruning logic
- `__tests__/sleep.test.ts` — new
- `__tests__/location.test.ts` — new
- `__tests__/health.test.ts` — extend with weight/meditation tests
- `CLAUDE.md` — update to reflect new capabilities

## Platform Note

This app is iOS-only. All `expo-location` timestamps are milliseconds since epoch on iOS. No Android considerations needed.
