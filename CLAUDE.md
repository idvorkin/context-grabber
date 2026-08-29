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
- `lib/audioBridge.ts` — Cockpit audio-bridge wire format (message parsing, injected JS). Protocol: `docs/cockpit-audio-bridge.md`
- `lib/callProtocol.ts` — Voice-bridge wire format for the native Call tab (frames both ways, ending text, bridge URL). Source of truth: `handle_browser` docstring in the Cockpit repo's `voice_bridge.py`
- `lib/pcm.ts` — Float32 ↔ PCM16 LE, linear resample to the bridge's 16 kHz
- `lib/callSession.ts` — The call's state machine (socket + mic + playback + captions), platform-free; fake socket/audio in tests
- `lib/callAudio.ts` — Native audio half of a call on `react-native-audio-api` + `modules/audio-route`: `.playAndRecord`/`.voiceChat` session, mic capture, scheduled playback, interruption resume

### Local Native Modules
- `modules/audio-route/` — iOS audio route: list microphones/outputs, steer `AVAudioSession`, push route changes. Feeds the Cockpit's device pickers.

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
- `react-native-webview` — hosts the Cockpit tab (tailnet-only web dashboard)
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

**ALWAYS UPDATE THE SPECS BEFORE UPDATING THE CODE.** No exceptions. This applies to new features, bug fixes that change visible behavior, UX tweaks, and refactors that alter contracts. If you catch yourself opening a `.tsx` or `.ts` file before a `.md` spec file, stop and go to the spec first.

**Specs describe FUNCTIONALITY, not implementation.** A spec says what the user sees, what the feature does, and what the acceptance criteria are. It does NOT name files, prop shapes, type definitions, function signatures, cache keys, component hierarchies, or where code goes. Implementation details belong in a plan (`docs/superpowers/plans/`) or in the code itself, not the spec. If a reader could use the spec as a QA checklist without ever opening the codebase, it's at the right level. If it reads like a refactor diff, strip it.

- **In the spec:** user-visible behavior, UX flows, edge cases, acceptance criteria, screenshots/mocks, goals/non-goals, rationale.
- **NOT in the spec:** file paths, prop names, type definitions, component names, function signatures, state shapes, cache key names, "in `foo.tsx`, change X", or any sentence that only makes sense if you've read the code.

Specs live in `docs/superpowers/specs/` as `YYYY-MM-DD-<feature>-design.md`; implementation plans (if needed) live alongside in `docs/superpowers/plans/`. The sequence for ANY change request is:

1. Find or write the spec (summary, goals/non-goals, user-visible behavior, acceptance criteria).
2. Confirm the spec with the user — they can edit it independently of code.
3. Only then touch code. For non-trivial changes, write an implementation plan in `docs/superpowers/plans/` in the same step as the spec update — the spec stays functional, the plan holds types/files/rollout.

**Bug reports and UX tweaks on existing features are spec changes.** "This thing is wonky" / "I don't like how X works" / "what should happen if Y" are all triggers to re-open the feature's spec FIRST, not to triage fixes. If the spec no longer matches reality, update the spec in the same change as the code. Never let implementation drift silently from spec.

## Key Patterns

- **Every user-visible error must use `<CopyableError>`** (`components/CopyableError.tsx`). Never render a raw red `<Text>` for an error message. The component renders the message + a "Copy error" button that puts a multi-line diagnostics payload (error, context label, git sha + branch, any extra fields) on the clipboard. Pass `context="ScreenName.operation"` and any state-shaped `extra` so a copied error is debuggable without a session log. Adding raw-text errors will fail review.
- All HealthKit queries use `Promise.allSettled()` — individual metric failures return `null`, don't crash the grab
- `TaskManager.defineTask()` is at MODULE SCOPE (top of App.tsx, outside component) — expo-task-manager requirement
- Background location tracking is opt-in (defaults to OFF)
- Location history stored in SQLite with configurable retention (default 30 days)
- Pruning happens on app foreground and when retention days are reduced
- All timestamps: UTC unix milliseconds in storage, ISO 8601 UTC in export
- Day bucketing uses **local time** (not UTC) — "your Tuesday" means local Tuesday
- Sleep bucketing is **noon-to-noon** — new code should use `aggregateSleepDetailed` (`lib/sleep.ts`), which attributes pre-noon samples to the PREVIOUS night. The older `aggregateSleep` uses `bucketByDay` with midnight cutoffs and is kept only for the scalar `weeklyCache.sleep` path.
- Sleep merges overlapping intervals before summing (Watch + iPhone both report same period)
- Today's health data is always live; past days are cached in SQLite
- Clustering is computed on-demand (when user opens Location sheet or shares), not on grab
- Pure functions extracted to `lib/` for testability
- **`expo-av` is removed in SDK 55.** Use `expo-audio` for file playback or `react-native-audio-api` (Web Audio API polyfill) for dynamic tones. Reinstalling `expo-av` fails with `EXEventEmitter.h not found`.
- **OTA update `--message` is server-side only** — not in `Updates.manifest` at runtime. For in-app "what's running" display, bake `git log -1 --format=%s` into `lib/generated_version.ts` via `scripts/generate-version.js`.
- **`DEVELOPMENT_TEAM` is committed in `ios/ContextGrabber.xcodeproj/project.pbxproj`** — no need to set it manually each build. Do NOT add `appleTeamId` to `app.json` (causes "No Account for Team" errors). If Xcode loses the Apple ID session after an update, re-add it in Xcode → Settings → Accounts.
- **iOS CoreLocation suppresses GPS updates when the phone is stationary** (motion-coprocessor confirmed). Multi-hour overnight gaps are normal — fix at the clustering layer (`mergeConsecutiveSamePlace` in `lib/clustering_v2.ts`), not by increasing collection frequency. `expo-location` doesn't expose Significant Location Changes API.
- **`runtimeVersion` in `app.json` must be a literal string** (`"1.0.0"`) matching `EXUpdatesRuntimeVersion` in `ios/ContextGrabber/Supporting/Expo.plist`. The `{policy: "appVersion"}` form fails because `ios/` is committed and EAS treats the project as bare workflow — `just ota` will reject it.
- **Never run `expo prebuild` in `just deploy`.** It wipes `DEVELOPMENT_TEAM` from `project.pbxproj` and creates duplicate file refs in LiveActivity's appex (asset catalog conflict). Use `just resync-native` only when native regeneration is intentional, and expect to re-commit `ios/` afterwards.
- **Adding a native module means `pod install` + a full rebuild, not OTA.** New pods (e.g. `react-native-webview`) can't ship over the air — the JS bundle references a view manager the installed binary doesn't have, and the app red-screens. `just deploy` always runs `pod install` (cheap when nothing changed) and warns if that modified `ios/Podfile.lock` — commit the lockfile; `expo prebuild` is still NOT needed for autolinked pods.
- **WKWebView `getUserMedia` needs `mediaCapturePermissionGrantType`.** `react-native-webview`'s default is to deny silently, so a page's mic button appears to do nothing. Use `grantIfSameHostElsePrompt` (grants the loaded origin, defers to the iOS system alert for anything else) plus `allowsInlineMediaPlayback` and `mediaPlaybackRequiresUserAction={false}`. `NSMicrophoneUsageDescription` is already declared via the `expo-audio` plugin — the OS prompt is the only permission UI.
- **WebKit enumerates one nameless microphone and zero outputs, and has no `setSinkId`.** That is every browser engine on iOS, `WKWebView` included, and it is why a hosted page's device pickers vanish inside the app while working fine on a laptop. There is nothing to fix in the page. The roster only exists in `AVAudioSession` — see `modules/audio-route/` and `docs/cockpit-audio-bridge.md` for the bridge that carries it into the web view. Corollary: the web view's own capture reconfigures the shared audio session when it starts, so a route set *before* a call begins has to be re-asserted on `routeChangeNotification` or it silently reverts.
- **Local Expo modules live in `modules/<name>/` and are autolinked with no `expo prebuild`.** `nativeModulesDir` defaults to `./modules`, so a directory with an `expo-module.config.json` + `ios/<Pod>.podspec` is picked up by `use_expo_modules!`. Verify discovery on any machine — no Mac needed — with `node --no-warnings --eval "require('expo/bin/autolinking')" expo-modules-autolinking resolve --platform apple --json`. But a local module does **not** move `ios/Podfile.lock`, so the Podfile.lock-vs-Manifest.lock check cannot see it; `just deploy` additionally greps `ios/Pods/Manifest.lock` for each local podspec's pod name.
- **`expo-audio` already exposes input selection** — `AudioRecorder.getAvailableInputs / getCurrentInput / setInput` wrap `AVAudioSession.availableInputs` and `setPreferredInput` on the shared session. They need a prepared recorder, expose no outputs, and emit no route-change events, which is why `modules/audio-route/` exists — but check them first before writing native code for anything input-only.
- **Inventory `ios/` before scoping native work.** `ios/LiveActivity/` is a `WidgetBundle` appex — add home-screen widgets as new `Widget` structs inside `LiveActivityWidgetBundle`, NOT a new Xcode target. URL scheme `com.idvorkin.contextgrabber://` is already registered in `ios/ContextGrabber/Info.plist`; `widgetURL()` deep-link plumbing exists in Swift (via `deepLinkUrl`), but JS-side inbound routing (`Linking.addEventListener` / `getInitialURL`) is NOT wired — Live Activity taps currently wake the app without routing.
- **Adding a Swift file to the main app target = edit `project.pbxproj`, and the `xcodeproj` gem is already installed (CocoaPods' Ruby: `/opt/homebrew/opt/ruby/bin/ruby -e 'require "xcodeproj"'`).** `group.new_file(path)` + `target.source_build_phase.add_file_reference(ref)` + `proj.save` is a 4-line diff; never `expo prebuild` for this. App Intents that must foreground the app (`openAppWhenRun = true`, then `UIApplication.shared.open(grabber://…)`) belong in the app target — `ios/ContextGrabber/CallLarryIntent.swift` is the pattern; intents that only touch the App Group (the widget's `+1`) can stay in the `LiveActivity` appex. Shortcuts lists both by name; an `AppShortcutsProvider` (app target only) adds the pre-built shortcut + Siri phrases.
- **Echo cancellation on iOS is VoiceProcessingIO, not a session mode.** `AVAudioSession.Mode.voiceChat` alone leaves `AVAudioEngine` on RemoteIO and the speaker feeds straight back into the mic (#80). `patches/react-native-audio-api+0.11.7.patch` adds `AudioEngine.syncVoiceProcessingWithSessionMode` — `inputNode.setVoiceProcessingEnabled(desiredMode == voiceChat)` on a stopped engine, called from `getInputFormat` (VPIO reports a different input format, and the recorder sizes buffers from it before attaching) and from the interruption rebuild. Anything that re-`setCategory`s the session must preserve `.voiceChat` while a call is live (`audio-route`'s `activate()` does). Reinstalling the lib re-applies the patch via `postinstall`.
- **Ignore recurring `bd doctor` warnings for `Dolt Status / Dolt Locks: config: modified`.** Every `bd` read (including `bd doctor` itself) re-creates that state; `bd vc commit` clears it but the next read brings it back. Cosmetic, not actionable.
- **Sanity-check geometry thresholds against `__tests__/fixtures/context-grabber.db` + `locations.json`** before shipping clustering / place-matching / distance rules. The fixture carries 36K real GPS points + 4 real known places — synthetic tests miss edge cases real data exposes. (Example: the place-merge gate moved from 50m → 500m because the tight gate caught 0/10 unmatched stays in the fixture.)

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
- **Call tab:** a Larry call with no web view (`screens/CallScreen.tsx`) — speaks the voice bridge directly, so the call survives screen lock / backgrounding under the `audio` background mode. `grabber://call` lands here. One `CallSession` lives in `App.tsx` and outlives the tab. Spec: `docs/superpowers/specs/2026-08-28-native-call-screen-design.md`.
- **Cockpit tab:** WKWebView on the tailnet-only Cockpit dashboard (`screens/CockpitScreen.tsx`). Mounted lazily on first visit and kept mounted (hidden) afterwards so the web session survives tab switches. Carries the audio bridge — the page can list and choose real microphones and outputs (`docs/cockpit-audio-bridge.md`).


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:970c3bf2 -->
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

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   bd dolt push
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->
