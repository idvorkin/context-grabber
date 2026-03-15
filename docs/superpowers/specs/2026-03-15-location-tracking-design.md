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

Single-file app (App.tsx) remains the primary structure. Two additions:

### 1. Background Location Tracking

**Mechanism**: `expo-location` significant-change monitoring via `expo-task-manager`.

- iOS wakes the app on ~200-500m movement
- Typically 20-50 points/day
- Battery-friendly — uses cell/wifi triangulation, not continuous GPS
- Requires "Always" location permission

**Flow**:
1. User enables tracking via toggle in the UI
2. App requests background location permission
3. Registers `TaskManager.defineTask()` for location updates
4. On each location event: insert into SQLite, prune old entries
5. Toggle state persisted in SQLite settings table

### 2. Sleep Detail Extraction

Derive bedtime and wake-up time from existing `HKCategoryTypeIdentifierSleepAnalysis` query:
- **Bedtime**: `startDate` of first `inBed` or `asleep` sample in the sleep window
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
  timestamp INTEGER NOT NULL  -- UTC unix milliseconds
);

CREATE INDEX idx_locations_timestamp ON locations(timestamp);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

**Settings keys**:
- `tracking_enabled`: "true" / "false"
- `retention_days`: number as string (default "30")

**Pruning**: On each insert, delete rows where `timestamp < now - (retention_days * 86400000)`.

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
  locationHistory: Array<{             // NEW
    latitude: number;
    longitude: number;
    timestamp: number;                  // UTC unix ms
  }>;
  settings: {                          // NEW
    retentionDays: number;
    trackingEnabled: boolean;
  };
};
```

## New Dependencies

- `expo-task-manager` — background task registration (npm install required)
- `expo-sqlite` — already included in Expo SDK 55 (no install needed)

## Permissions Changes

**app.json additions**:
```json
{
  "infoPlist": {
    "UIBackgroundModes": ["location"],
    "NSLocationAlwaysAndWhenInUseUsageDescription": "Context Grabber tracks your location in the background to build a location history for your AI life coach."
  }
}
```

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

## File Changes

- `App.tsx` — all changes (background task definition, SQLite setup, sleep extraction, UI additions)
- `app.json` — permission descriptions and UIBackgroundModes
- `package.json` — add expo-task-manager dependency
- `CLAUDE.md` — update to reflect new capabilities
