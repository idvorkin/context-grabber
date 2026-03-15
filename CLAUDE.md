# Context Grabber

iOS app (Expo + React Native + TypeScript) that exports HealthKit, GPS, and location history data as JSON for AI life coaching.

## Architecture

Main UI in `App.tsx` with pure functions extracted into `lib/` modules. Press "Grab Context" to snapshot health + location + location history, then share via iOS share sheet.

- `lib/health.ts` — HealthKit data processing (sleep hours, weight, meditation, buildHealthData)
- `lib/sleep.ts` — Sleep detail extraction (bedtime/wake time from sleep samples)
- `lib/location.ts` — Location pruning logic (pruneThreshold)
- `lib/summary.ts` — Summary text and number formatting (buildSummary, formatNumber, formatTime)

## Tech Stack

- Expo SDK 55, React Native 0.83, React 19, TypeScript 5.9
- `@kingstinct/react-native-healthkit` — HealthKit queries
- `expo-location` — foreground + background GPS
- `expo-task-manager` — background task registration for location tracking
- `expo-sqlite` — local storage for location history and settings
- Jest + ts-jest — testing

## Build & Run

```bash
npm install
npx expo prebuild --platform ios
cd ios && pod install && cd ..
npx expo run:ios --device   # physical iPhone required (HealthKit needs real device)
```

Requires Xcode, Apple ID for signing, Developer Mode on iPhone. Free Apple ID = 7-day app expiry.

## Testing

```bash
npm test          # or: npx jest
```

Tests live in `__tests__/` and cover pure functions only (no device/HealthKit mocking needed):
- `health.test.ts` — sleep hours, weight, meditation, buildHealthData
- `sleep.test.ts` — bedtime/wake time extraction
- `location.test.ts` — pruning threshold calculations
- `snapshot.test.ts` — context snapshot shape validation
- `summary.test.ts` — summary builder, formatTime, formatNumber
- `App.test.tsx` — component rendering, interactions, metric cards

## Key Patterns

- All HealthKit queries use `Promise.allSettled()` — individual metric failures return `null`, don't crash the grab
- `TaskManager.defineTask()` is at MODULE SCOPE (top of App.tsx, outside component) — this is an expo-task-manager requirement
- Background location tracking is opt-in (defaults to OFF)
- Location history stored in SQLite with configurable retention (default 30 days)
- Pruning happens on app foreground and when retention days are reduced
- All timestamps: UTC unix milliseconds in storage, ISO 8601 UTC in export
- Pure functions extracted to `lib/` for testability

## Data Collected

- Steps, heart rate, sleep (hours + bedtime + wake time), active energy, walking distance (from HealthKit)
- Weight (most recent, in kg, from HealthKit)
- Meditation minutes (today's total, from HealthKit)
- Single GPS coordinate (from expo-location foreground)
- Location history trail (from background location tracking with balanced accuracy, stored in SQLite)
- NOT collected: workout sessions, workout routes

## Settings (SQLite)

- `tracking_enabled`: "true"/"false" (default "false")
- `retention_days`: number as string (default "30")
- `schema_version`: "1"
