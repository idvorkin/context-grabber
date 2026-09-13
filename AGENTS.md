# Agent instructions: Context Grabber

iOS app (Expo + React Native + TypeScript; Swift for the widgets and the local audio-route module) that holds up a
humane mirror of Igor's week — health, places, roles, a journal — and feeds it to Larry, his AI coach, as a context
export and over a voice call. Also a gym timer. `lib/` is the platform-free half (pure functions, tested on the
host); `screens/` and `components/` the UI; `modules/audio-route/` and `ios/LiveActivity/` the native capability.
Igor merges the PRs and ships them himself; work lands on a branch as one PR per issue.

## Read these before working

| File | What it settles |
|---|---|
| [docs/TESTING.md](docs/TESTING.md) | the test ladder (host jest → type check → Maestro → phone), which change is verified where, the real-data fixtures, what only the phone can show |
| [docs/DEBUGGING.md](docs/DEBUGGING.md) | the logs (the call log, the timer log, copyable errors, the gist upload), instrument before theorizing, how a bug goes from the phone to a closed issue |
| [docs/stories/README.md](docs/stories/README.md) | the spec: user stories per journey, each with its status and commits |
| [docs/superpowers/specs/](docs/superpowers/specs/) | the design spec behind each feature — functionality, not implementation; updated before the code |
| [docs/jtbd.md](docs/jtbd.md) | why: the two-way mirror, the two dragons, what the app is NOT (a fitness tracker, a habit tracker, a journal app) |

## Rules

- **Test ladder**: host `just test` (~20 s; one file in seconds) and `npx tsc --noEmit` → Maestro on the simulator
  (`.maestro/`, no HealthKit, cannot tap system dialogs) → the phone (`just ota` for JavaScript, `just deploy` for
  anything native). Verify on the cheapest rung that can see the change and **say which rung you used**. Audio
  session behaviour, HealthKit, GPS, widgets, Live Activities, Shortcuts and the voice bridge exist only on the
  phone ([TESTING.md](docs/TESTING.md)).
- **Spec first, story always.** The design spec (`docs/superpowers/specs/`) is updated before the code — the full
  rule is below. And every feature or behaviour change updates the user stories (`docs/stories/`) in the same PR: a
  new capability gets a story in its journey (Cohn + Gherkin, the `user-story` skill) with a `Status:` line naming
  its commit and where it was verified; a changed behaviour edits the story's acceptance criteria and adds its
  commit to the `Status:` line. Status lives only on the stories. **No story, not done.**
- **Instrument before theorizing.** For any phone-only symptom add the log line that would settle it (the call log,
  the timer log, or a `CopyableError` with the state in `extra`), ship it, reproduce, read the evidence, then fix.
  Never ship a second guessed fix ([DEBUGGING.md](docs/DEBUGGING.md)).
- **Bugs**: a report Igor makes — a copied error, a copied or uploaded log, or his voice in the session — becomes a
  GitHub issue with the evidence attached. Before fixing, find or write the story in `docs/stories/` that covers it
  (a bug gets an `Issues:` line, a request becomes a story, no story means the spec has a hole). One PR per issue,
  referencing it; never bundle fixes. Close the issue once the build is on the phone with a comment saying what was
  verified where and what Igor should feel; Igor reopens if it is not fixed. Never leave a fixed bug open.
- **OTA-first**: native code is a capability, what the app does with it is JavaScript. Anything under `ios/`,
  `modules/`, `patches/`, `package.json` or `app.json` is a native build *and* a runtime-version bump; `just ota`
  refuses when the native surface moved. Details under Key Patterns.
- **Every user-visible error is a `CopyableError`** with a `context` and the state in `extra` — never a bare red
  string. Details under Key Patterns.
- **Sanity-check geometry thresholds against the real fixtures** (`__tests__/fixtures/locations.json`,
  `context-grabber.db`) before shipping clustering, place-matching or distance rules; synthetic tests miss what real
  data exposes.
- **Background agents** that investigate are read-only, in a worktree, notes under `~/tmp/agent/notes/`; confirm
  scope before an agent that writes to the repo. Reap background commands when done.
- **Architecture is discussed, not assumed**: propose with a trade-off table or a numeric plan, then one "do it".
  Prefer `just` recipes over raw commands — they carry the version generation and the native-surface checks.

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
- `lib/cockpitClient.ts` — The `?client=context-grabber&v=<build>` tag the Cockpit tab loads the page with (#78)
- `lib/audioBridge.ts` — Cockpit audio-bridge wire format (message parsing, injected JS). Protocol: `docs/cockpit-audio-bridge.md`
- `lib/callProtocol.ts` — Voice-bridge wire format for the native Call tab (frames both ways, ending text, bridge URL). Source of truth: `handle_browser` docstring in the Cockpit repo's `voice_bridge.py`
- `lib/pcm.ts` — Float32 ↔ PCM16 LE, linear resample to the bridge's 16 kHz
- `lib/callVoices.ts` — The voice a call answers in: Tony (bridge default) or Igor (his clone, implies `eleven_v3_conversational`); what rides the start frame per backend
- `lib/gistUpload.ts` — The call log as a private gist: trouble detection, the delete-me note, create/delete, the app's own list (spec `2026-09-05-diagnostics-gist-upload-design.md`)
- `lib/gistToken.ts` — The gist token in the iOS Keychain (`expo-secure-store`; null on a binary without it)
- `lib/callSession.ts` — The call's state machine (socket + mic + playback + captions), platform-free; fake socket/audio in tests
- `lib/callAudio.ts` — Native audio half of a call on `react-native-audio-api` + `modules/audio-route`: `.playAndRecord`/`.voiceChat` session, mic capture, scheduled playback, interruption resume

### Local Native Modules
- `modules/audio-route/` — iOS audio route: list microphones/outputs, steer `AVAudioSession`, push route changes, read the session's state at mic-arm time (`getInputState`, optional on old binaries). Feeds the Cockpit's device pickers and the Call tab's diagnostics.

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
- `expo-secure-store` — Keychain, for the diagnostics-upload token
- `react-native-webview` — hosts the Cockpit tab (tailnet-only web dashboard)
- Jest + ts-jest — testing
- Maestro — iOS simulator UI testing

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
- **OTA-first: native code is a capability, what the app does with it is JavaScript.** Any change under `ios/`, `modules/`, `patches/`, `package.json` or `app.json` is a native build *and* a runtime-version bump (`scripts/bump-runtime-version.sh`, date-based, both files); `just ota` refuses when the native surface moved since the last `just deploy` from this Mac, and `just deploy` refuses when `app.json` and `Expo.plist` disagree. Never import at the top of a file a module some supported binary might lack — `require` it inside a function behind a `try` and degrade (`lib/gistToken.ts`, `lib/gym/useDeviceTurn.ts`). Review and the two proposals (widgets that render what JavaScript wrote; a generic App Group bridge and intent): `docs/superpowers/specs/2026-09-07-ota-first-architecture-design.md`.
- **Adding a native module means `pod install` + a full rebuild, not OTA.** New pods (e.g. `react-native-webview`) can't ship over the air — the JS bundle references a view manager the installed binary doesn't have, and the app red-screens. `just deploy` always runs `pod install` (cheap when nothing changed) and warns if that modified `ios/Podfile.lock` — commit the lockfile; `expo prebuild` is still NOT needed for autolinked pods.
- **WKWebView `getUserMedia` needs `mediaCapturePermissionGrantType`.** `react-native-webview`'s default is to deny silently, so a page's mic button appears to do nothing. Use `grantIfSameHostElsePrompt` (grants the loaded origin, defers to the iOS system alert for anything else) plus `allowsInlineMediaPlayback` and `mediaPlaybackRequiresUserAction={false}`. `NSMicrophoneUsageDescription` is already declared via the `expo-audio` plugin — the OS prompt is the only permission UI.
- **WebKit enumerates one nameless microphone and zero outputs, and has no `setSinkId`.** That is every browser engine on iOS, `WKWebView` included, and it is why a hosted page's device pickers vanish inside the app while working fine on a laptop. There is nothing to fix in the page. The roster only exists in `AVAudioSession` — see `modules/audio-route/` and `docs/cockpit-audio-bridge.md` for the bridge that carries it into the web view. Corollary: the web view's own capture reconfigures the shared audio session when it starts, so a route set *before* a call begins has to be re-asserted on `routeChangeNotification` or it silently reverts.
- **Local Expo modules live in `modules/<name>/` and are autolinked with no `expo prebuild`.** `nativeModulesDir` defaults to `./modules`, so a directory with an `expo-module.config.json` + `ios/<Pod>.podspec` is picked up by `use_expo_modules!`. Verify discovery on any machine — no Mac needed — with `node --no-warnings --eval "require('expo/bin/autolinking')" expo-modules-autolinking resolve --platform apple --json`. But a local module does **not** move `ios/Podfile.lock`, so the Podfile.lock-vs-Manifest.lock check cannot see it; `just deploy` additionally greps `ios/Pods/Manifest.lock` for each local podspec's pod name.
- **`expo-audio` already exposes input selection** — `AudioRecorder.getAvailableInputs / getCurrentInput / setInput` wrap `AVAudioSession.availableInputs` and `setPreferredInput` on the shared session. They need a prepared recorder, expose no outputs, and emit no route-change events, which is why `modules/audio-route/` exists — but check them first before writing native code for anything input-only.
- **Inventory `ios/` before scoping native work.** `ios/LiveActivity/` is a `WidgetBundle` appex — add home-screen widgets as new `Widget` structs inside `LiveActivityWidgetBundle`, NOT a new Xcode target. URL scheme `com.idvorkin.contextgrabber://` is already registered in `ios/ContextGrabber/Info.plist`; `widgetURL()` deep-link plumbing exists in Swift (via `deepLinkUrl`), but JS-side inbound routing (`Linking.addEventListener` / `getInitialURL`) is NOT wired — Live Activity taps currently wake the app without routing.
- **Adding a Swift file to the main app target = edit `project.pbxproj`, and the `xcodeproj` gem is already installed (CocoaPods' Ruby: `/opt/homebrew/opt/ruby/bin/ruby -e 'require "xcodeproj"'`).** `group.new_file(path)` + `target.source_build_phase.add_file_reference(ref)` + `proj.save` is a 4-line diff; never `expo prebuild` for this. App Intents that must foreground the app (`openAppWhenRun = true`, then `UIApplication.shared.open(grabber://…)`) belong in the app target — `ios/ContextGrabber/CallLarryIntent.swift` is the pattern; intents that only touch the App Group (the widget's `+1`) can stay in the `LiveActivity` appex. Shortcuts lists both by name; an `AppShortcutsProvider` (app target only) adds the pre-built shortcut + Siri phrases.
- **The Gym Timer's cues are sound files, never synthesis.** Spoken — *three, two, one, go! / rest / done* — in Igor's own voice (his ElevenLabs clone, `ELEVEN_API_KEY` from the environment or the secretbox; the Mac's `say` when absent) by `scripts/make-timer-words.sh`, padding trimmed and composed into `assets/audio/timer/*.wav` by `scripts/make-timer-cues.mjs`; played by expo-audio's player; the near-silent keepalive loop is one too. react-native-audio-api's Web-Audio engine goes silent as soon as the session mixes with other audio (2026-09-07: music ducked, every cue requested, none heard), so the timer uses that library only to steer the session (`AudioManager.setAudioSessionOptions` / `setAudioSessionActivity`). The Call tab still renders through the engine — its session is exclusive.
- **The Gym Timer's audio session is `playback` mixed with others; a workout never pauses the music.** Around each cue a *duck window* (`lib/gym/duck.ts`, driven from `lib/gym/keepalive.ts`) adds `duckOthers` + `interruptSpokenAudioAndMixWithOthers` to the live session, then lets go with a deactivate-and-reactivate (a paused podcast resumes only on deactivation, and only with `notifyOthersOnDeactivation` — added to the audio library's `setActive:` by the patch) and restarts the keepalive loop. Per-tick ducking makes music pump; the window is the unit. Spec: `docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md`.
- **Echo cancellation on iOS is VoiceProcessingIO, not a session mode.** `AVAudioSession.Mode.voiceChat` alone leaves `AVAudioEngine` on RemoteIO and the speaker feeds straight back into the mic (#80). `patches/react-native-audio-api+0.11.7.patch` adds `AudioEngine.syncVoiceProcessingWithSessionMode` — `inputNode.setVoiceProcessingEnabled(desiredMode == voiceChat)` on a stopped engine, called from `getInputFormat` (VPIO reports a different input format, and the recorder sizes buffers from it before attaching) and from the interruption rebuild. Anything that re-`setCategory`s the session must preserve `.voiceChat` while a call is live (`audio-route`'s `activate()` does). Reinstalling the lib re-applies the patch via `postinstall`.
- **Never put `invalidatableContent()` on a `Button(intent:)` label.** With it, the tap stops running the intent and falls through to `widgetURL` (opens the app) — bisected on the memdeck card, 2026-09-07: removing `isDiscoverable = false` alone changed nothing, removing the modifier fixed it. If a dim-while-changing look is wanted, mark a sibling view, not the button's own label. Keep widget intents discoverable anyway (the +1 precedent; hidden-intent behaviour is unproven). The appex's `Metadata.appintents/extract.actionsdata` lists every intent either way, so it cannot tell you why a tap opens the app. Also: iPhone lock-screen (accessory) widgets run no in-place actions at all — a `Button(intent:)` there rendered blank; they get a `widgetURL`.
- **Ignore recurring `bd doctor` warnings for `Dolt Status / Dolt Locks: config: modified`.** Every `bd` read (including `bd doctor` itself) re-creates that state; `bd vc commit` clears it but the next read brings it back. Cosmetic, not actionable.
- **Sanity-check geometry thresholds against `__tests__/fixtures/context-grabber.db` + `locations.json`** before shipping clustering / place-matching / distance rules. The fixture carries 36K real GPS points + 4 real known places — synthetic tests miss edge cases real data exposes. (Example: the place-merge gate moved from 50m → 500m because the tight gate caught 0/10 unmatched stays in the fixture.)

- **Dependabot PRs here all edit `package-lock.json`, so they conflict with each other and go stale; clear the alerts in bulk instead.** On a branch: `npm update --package-lock-only <the vulnerable packages>` — not `npm audit fix`, which also bumps `expo` / `expo-modules-core` patch versions (pods → a native build, not OTA) — then `npm ci`, `npx tsc --noEmit`, `just test`, and `npx expo export --platform ios` so Metro still bundles. Dependabot closes its own PRs once main is clean. Alerts left in the `@expo/*` / `metro` / `xcode` chain are pinned by the SDK and wait for the SDK upgrade (#46). A scratch `git worktree` needs `git submodule update --init` first, or Metro fails on the empty `vendor/igor-timer`.

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
- **Card tab:** the memdeck card, big (`screens/CardScreen.tsx`) — a fresh card every time the tab opens, tap for another, *Think of a card* deals one five seconds later. `grabber://card` (the lock-screen widgets' tap) lands here. Deals through `WidgetBridge`, syncs the widgets once on leaving.
- **Widgets (`ios/LiveActivity/`):** Today (medium/large; the large one carries the memdeck card) and the lock-screen Memdeck card. The card is a function of the clock (one per five minutes) and one shared tap count in the App Group (a tap on the big widget's card deals a new one, `DealCardIntent.swift`; the lock-screen widgets carry no button — iPhone lock-screen widgets run no in-place actions and a button there rendered blank), so every surface deals the same card with nothing else shared (`PlayingCard.swift`, compiled into both the app and the appex; its promises are checked by `just check-deal`, plain `swiftc`). The lock-screen widgets link to `grabber://card`, the Card tab. Spec: `docs/superpowers/specs/2026-09-07-widget-random-card-design.md`.
- **Cockpit tab:** WKWebView on the tailnet-only Cockpit dashboard (`screens/CockpitScreen.tsx`). Mounted lazily on first visit and kept mounted (hidden) afterwards so the web session survives tab switches. Carries the audio bridge — the page can list and choose real microphones and outputs (`docs/cockpit-audio-bridge.md`).

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:970c3bf2 -->

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

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->
## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at `.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale. Codex 0.129.0+ can load Beads context automatically through native hooks; use `/hooks` to inspect or toggle them.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.
<!-- END BEADS CODEX SETUP -->
