# Context Grabber

iOS app (Expo + React Native + TypeScript) that exports HealthKit, GPS, and location history data as JSON for AI life coaching.

## Architecture

Main UI in `App.tsx` (~1800 lines) with pure functions extracted into `lib/` modules. Press "Grab Context" to snapshot health + location + location history, then share via iOS share sheet.

### Lib Modules
- `lib/health.ts` — HealthKit data processing (sleep interval merge, weight, meditation, buildHealthData)
- `lib/sleep.ts` — Sleep detail extraction (bedtime/wake time from sleep samples)
- `lib/weekly.ts` — 7-day aggregation per metric (HeartRateDaily, DailyValue, METRIC_CONFIG, bucketByDay)
- `lib/healthCache.ts` — SQLite cache for computed + raw health data (today always live, past days cached)
- `lib/clustering_v2.ts` — **Active** location clustering: temporal stay detection, v1-compatible wrapper
- `lib/clustering.ts` — Legacy v1 grid + union-find clustering (kept for tests, not used in app)
- `lib/places.ts` — Known place matching (matchPointToPlace, labelPointsWithKnownPlaces)
- `lib/geo.ts` — Haversine distance
- `lib/stats.ts` — Box plot statistics (R-7 percentile method)
- `lib/share.ts` — Export JSON formatting (SummaryExport, RawExport, WeeklyStatsExport)
- `lib/summary.ts` — Summary text and number formatting (buildSummary, formatNumber, formatTime)
- `lib/location.ts` — Location pruning logic (pruneThreshold)

### Components
- `components/MetricDetailSheet.tsx` — Bottom sheet with chart + daily breakdown for each metric
- `components/BarChart.tsx` — View-based bar chart (steps, energy, etc.)
- `components/LineChart.tsx` — Line chart with box-and-whisker support (heart rate, HRV, weight)
- `components/BoxPlot.tsx` — Inline horizontal box plot for metric cards

## Tech Stack

- Expo SDK 55, React Native 0.83, React 19, TypeScript 5.9
- `@kingstinct/react-native-healthkit` — HealthKit queries
- `expo-location` — foreground + background GPS
- `expo-task-manager` — background task registration for location tracking
- `expo-sqlite` — local storage for location history, settings, health cache
- `expo-file-system` — database file access for export
- `expo-sharing` — iOS share sheet for database export
- `expo-updates` — OTA update delivery
- Jest + ts-jest — testing
- Maestro — iOS simulator UI testing

## Build & Run

**Prefer `just` commands over running raw commands.** The justfile handles dependencies like version generation automatically.

```bash
just setup        # npm install, prebuild, pod install
just deploy       # build release and install on iPhone (supports OTA updates)
just build        # build debug and install on iPhone (needs Metro, no OTA)
just dev          # start Metro dev server (for debug builds)
just ota "msg"    # deploy OTA update to production channel
just test         # run tests
```

- `just deploy` — standalone release build. App works without Mac, receives OTA updates.
- `just build` — debug build. Requires `just dev` running for Metro. Faster iteration, no OTA.

Requires Xcode, Apple ID for signing, Developer Mode on iPhone. Free Apple ID = 7-day app expiry.

### Maestro UI Testing
```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
maestro test .maestro/check-about.yaml
```
Use `testID` props (not `accessibilityLabel`) for reliable Maestro taps. Maestro cannot interact with native iOS system dialogs (HealthKit permissions).

## Testing

```bash
just test         # or: npm test / npx jest
```

Tests live in `__tests__/` and cover pure functions only (no device/HealthKit mocking needed):
- `health.test.ts` — sleep hours, weight, meditation, buildHealthData
- `sleep.test.ts` — bedtime/wake time extraction
- `location.test.ts` — pruning threshold calculations
- `snapshot.test.ts` — context snapshot shape validation
- `summary.test.ts` — summary builder, formatTime, formatNumber
- `weekly.test.ts` — formatDateKey, bucketByDay, aggregateHeartRate, aggregateSleep
- `clustering.test.ts` — v1 grid clustering, timeline, downsample
- `clustering_v2.test.ts` — v2 stay detection, merging, place assignment, real-data fixture test
- `places.test.ts` — known place matching, cluster building
- `stats.test.ts` — box plot statistics, percentile, extractValues
- `share.test.ts` — dayOfWeek, buildDailyExport, buildWeeklyStats
- `App.test.tsx` — component rendering, interactions, metric cards

Real GPS fixture data: `__tests__/fixtures/locations.json` (36K+ points from real device)

## Spec-First Workflow

**Always update the spec before touching implementation, and check that the spec is still coherent.** Specs live in `docs/superpowers/specs/` as `YYYY-MM-DD-<feature>-design.md`; implementation plans (if needed) live alongside in `docs/superpowers/plans/`. If a user asks for a feature, the sequence is:

1. Find or write the spec (summary, goals/non-goals, design, data model, acceptance criteria).
2. Confirm the spec with the user — they can edit it independently of code.
3. Only then touch code.

When modifying an existing feature, re-read its spec first. If the spec no longer matches reality, update the spec in the same change as the code. Never let implementation drift silently from spec.

## Key Patterns

- All HealthKit queries use `Promise.allSettled()` — individual metric failures return `null`, don't crash the grab
- `TaskManager.defineTask()` is at MODULE SCOPE (top of App.tsx, outside component) — expo-task-manager requirement
- Background location tracking is opt-in (defaults to OFF)
- Location history stored in SQLite with configurable retention (default 30 days)
- Pruning happens on app foreground and when retention days are reduced
- All timestamps: UTC unix milliseconds in storage, ISO 8601 UTC in export
- Day bucketing uses **local time** (not UTC) — "your Tuesday" means local Tuesday
- Sleep window is **noon-to-noon** (not midnight) — captures overnight sessions correctly
- Sleep merges overlapping intervals before summing (Watch + iPhone both report same period)
- Today's health data is always live; past days are cached in SQLite
- Clustering is computed on-demand (when user opens Location sheet or shares), not on grab
- Pure functions extracted to `lib/` for testability
- **`expo-av` is removed in SDK 55.** Use `expo-audio` for file playback or `react-native-audio-api` (Web Audio API polyfill) for dynamic tones. Reinstalling `expo-av` fails with `EXEventEmitter.h not found`.
- **OTA update `--message` is server-side only** — not in `Updates.manifest` at runtime. For in-app "what's running" display, bake `git log -1 --format=%s` into `lib/generated_version.ts` via `scripts/generate-version.js`.
- **Set Apple development team in Xcode's Signing UI**, not `app.json`'s `appleTeamId`. The latter causes "No Account for Team" errors; the former writes `DEVELOPMENT_TEAM` to `project.pbxproj` where xcodebuild finds it.

## Data Collected

- Steps, heart rate, sleep (hours + bedtime + wake time + per-source breakdown), active energy, walking distance
- Weight (most recent, in kg), HRV (ms), resting heart rate
- Meditation minutes (today's total)
- Exercise minutes (today's total, from individual samples)
- Single GPS coordinate (foreground)
- Location history trail (background tracking, stored in SQLite)
- Location clustering summary (temporal stay detection with known places)
- NOT collected: workout sessions, workout routes

## SQLite Tables

- `locations` — GPS breadcrumbs (lat, lng, accuracy, timestamp). Index on timestamp.
- `settings` — key/value (tracking_enabled, retention_days, schema_version)
- `known_places` — user-defined places (name, lat, lng, radius_meters)
- `health_computed_cache` — aggregated daily health values (metric, date_key, data JSON)
- `health_raw_cache` — raw HealthKit samples (metric, date_key, data JSON)
- `health_cache_meta` — cache versioning (cache_version=2; bumping purges caches)

## UI Screens

- **Main:** metric grid (10 cards), location card, summary banner, share buttons
- **Metric Detail Sheet:** chart + 7-day breakdown, sleep source tabs, debug view
- **Location Detail Sheet:** coordinates, clustering summary, Export Database, Known Places CRUD
- **Settings Modal:** location tracking toggle, retention days, debug sleep data
- **About Modal:** build info, OTA updates, repository link


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
