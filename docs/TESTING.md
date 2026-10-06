# Test architecture

The rule: every question is answered on the cheapest rung that can answer it, and a change is not "done" until the
rung that can see it has seen it. Say which rung you used. The rungs are ordered by cost, and the split follows the
code: everything in `lib/` is platform-free and runs on the host; the UI runs under React Native Testing Library on
the host too; only what genuinely needs HealthKit, GPS, an audio session, a widget or the voice bridge goes higher.

| Rung | What runs | Command | Time | Answers |
|---|---|---|---|---|
| 1 Host, unit | ts-jest over `lib/` (jest project `unit`) | `just test` (every rung-1 row), or `npx jest __tests__/<file>` | ~15 s for `just test` warm, ~35 s on a cold cache after `npm ci`, seconds for one file | health math, sleep, weekly bucketing, clustering and places against real GPS data, stats, the export shape, summary text, the call's state machine (fake socket and audio), the bridge and call wire formats, the gist upload, the accessory log, deep links, the LED geometry |
| 1 Host, component | React Native Testing Library over `screens/` and `components/` (jest project `component`, same command) | same | same | rendering, taps, the Gym Timer screen (the turn through the mocked accelerometer, paused, the accessory sheet), metric cards, App interactions |
| 1 Type check | the TypeScript compiler over the whole app | `npx tsc --noEmit` (also run by `just test`) | part of `just test` | every prop and wire shape |
| 1 Swift | the memdeck deal's promises under plain `swiftc` | `just check-deal` (also run by `just test`) | seconds | no repeats, one of each per run, a tap always changes the card |
| 2 Simulator | Maestro flows in `.maestro/` | `maestro test .maestro/<flow>.yaml` | ~1 min each | launch, tapping through by `testID`, screenshots of the About screen, the location sheet, the database export |
| 3 Phone | the app on Igor's iPhone | `just ota` (JavaScript) · `just deploy` (native) · `just build` + `just dev` (debug, Metro) | minutes + a person | HealthKit, GPS and background location, the audio session (ducking, echo cancellation, the keepalive with the screen locked), Live Activities, widgets, Shortcuts, the Cockpit page, the voice bridge, the Keychain |

## The native app's ladder

The Swift-native app (`native/`, [design spec](superpowers/specs/2026-10-04-swift-native-app-design.md)) is built
beside this one and has the same three rungs, after Exercise Analyzer's. As journeys move over, their rows in the
tables below move here.

| Rung | What runs | Command | Time | Answers |
|---|---|---|---|---|
| 1 Host | `ContextCore` XCTest (`native/ContextCore`, the platform-free package) | `just native-test` (also run by `just test`) | seconds | everything pure: what a log line can carry, log retention; each ported `lib/` module's logic |
| 2 Simulator | the app, driven by launch hooks, judged from its session log | `just native-test-sim` | ~1 min | it installs and launches, the log's first line names the build, a report is stored with its screenshot, no `error` event; the timer's and breathing's cues and Live Activity events |
| 2 Simulator | the app, driven by launch hooks, judged from its session log | `just native-test-sim` | ~1 min | it installs and launches, the log's first line names the build, a report is stored with its screenshot, the timer's cues, the card's deal and count, no `error` event |
| 3 Phone | Grabber Native on the iPhone, beside Context Grabber | `just native-run-device`, then `just pull-logs` | minutes + a person | the shake, and everything the phone-only rows below list |

The phone recipes (`native-run-device`, `pull-logs`, `bugs-check`) need the iPhone's hardware UDID: `DEVICE=<udid>`
in the environment, or one line in `scripts/native/phone-udid.local`, which is gitignored because the repo is
public (`xcrun devicectl list devices` shows the id). Without either they stop with a line saying so.

The simulator cannot be shaken or tapped from a script, so the app reads **launch hooks** from the environment
(pass them through `simctl` as `SIMCTL_CHILD_<name>`); checks wait for an event in a *new* launch's log instead of
sleeping, so a slow start cannot reuse the previous result ([`scripts/native/sim-smoke.sh`](../scripts/native/sim-smoke.sh)).

| Hook | Effect |
|---|---|
| `GRABBER_BUG=text` | two seconds after launch, file a problem report with that note, as a shake and *Log it* would |
| `GRABBER_TIMER=<chip>` | open the Gym Timer on that chip (`30sec`, `1min`, `2min`, `5-1`, `custom`) and start it, as a widget tile would. `GRABBER_TIMER=work,rest,rounds` (seconds, seconds, count) runs that shape as Custom without remembering it: `10,10,2` is a whole workout in 35 s, which is what `just native-test-sim` runs and reads `timer_cue`, `timer_duck` and `timer_session` from |
| `GRABBER_BREATHE=breath,cycles[,cue[,pause_at_seconds]]` | open Box breathing and begin exactly that session (seconds a side, whole cycles, `voice` / `tone` / `off`; the cue is used but not remembered): `2,2,voice` is a whole session in 18 s, which `just native-test-sim` runs and reads `breath_phase`, `breath_cue` and `breath_finished` from. A fourth field pauses the session by itself that many seconds into the breathing, as a tap on the circle would (`breath_pause` with reason `hook`): `6,1,off,3` shows the paused circle mid-inhale, for a screenshot. Any other value (`open`) just opens the sliders, for a screenshot |
| `GRABBER_BREATHE_STYLE=line\|glow\|beads\|tide` | with `GRABBER_BREATHE`, draw that session's breath in that ring style (story 240); used but not remembered |
| `GRABBER_IMPORT_DB=<file>[,recent]` | import that database as *Import from Context Grabber* would (a path, absolute or under the app's Documents). `recent` shifts its timestamps by whole weeks so the newest point falls in the last seven days: `just native-test-sim` copies the real fixture `__tests__/fixtures/context-grabber.db` to `Documents/import-fixture.db` and imports it this way, twice, reading `import` and `places_open` |
| `GRABBER_PLACES=open\|map` | open Places (`map`: with the map full screen), for a screenshot and the `places_open` event |
| `GRABBER_TRACKING=on\|off` | flip the Background Tracking switch as a tap would; with `xcrun simctl privacy <udid> grant location-always com.idvorkin.grabbernative` first, `on` starts recording, and `xcrun simctl location <udid> start …` moves the simulator so points arrive (`location_point`) |
| `GRABBER_RETENTION=<days>` | set retention as the stepper would; lowering it prunes at once (`prune` with reason `lowered`) |
| `GRABBER_EXPORT=1` | make the export file as *Export database* does, without the share sheet; `export` names its path, which the smoke opens with `sqlite3` |
| `GRABBER_CALL=<ws url>` | open the call screen and, a second later, call that bridge as a tap on *Call Larry* would; hang up after `GRABBER_CALL_SECONDS` (default 8). `just native-test-sim` points it at `scripts/native/fake-bridge.py` on `ws://localhost:8799` and reads the `call_*` events and the bridge's own report |
| `GRABBER_CALL_AUDIO=synthetic` | with `GRABBER_CALL`: a 220 Hz tone for the mic and counted, unplayed playback instead of the audio engine, so the protocol path is checked whatever the simulator's audio does; the smoke run makes the call once this way and once on the real engine |
| `GRABBER_MIRROR=fixture\|healthkit` | open Today and grab the mirror's fixture week (`mirror-fixture.json`, moved to this week): `fixture` answers from the file, `healthkit` first saves it into the simulator's Health store (never on the phone) and grabs from HealthKit. Either writes `Documents/exports/{fixture,summary,raw}.json` and logs `mirror_fixture_done`; `make-mirror-expected.mjs --fixture` computes what the React Native code makes of the same `fixture.json`, and `sim-smoke.sh` compares bytes. Health's access sheet needs one tap a script cannot make: `just native-sim-health` (a UI test) makes it once per simulator |
| `GRABBER_METRIC=<key>` | with `GRABBER_MIRROR`: open that metric's sheet after the grab (`sleep`, `movement`, `heartRate`, …), for a screenshot |
| `GRABBER_TURN=left\|right` | with `GRABBER_TIMER`: draw the timer as if the phone were on that side (the simulator has no accelerometer), for a screenshot of the turned face |
| `GRABBER_COUNT_VOICE=adam\|igor\|aussie` | with `GRABBER_TIMER` or `GRABBER_TIMER_SETTINGS`: count in that voice for this launch, not remembered and with no sample (story 182); `just native-test-sim` runs `aussie` and reads the first `timer_cue`'s `voice` |
| `GRABBER_TIMER_SETTINGS=1` | open the Gym Timer, not started, with *Timer settings* up (logs `ui` action: timer_settings), for a screenshot of the sheet |
| `GRABBER_WHATS_NEW=open` | open What's new (logs `ui` action: open_whats_new with days, changes, newest), for a screenshot of the build's own history (story 148) |
| `GRABBER_COCKPIT=open` | open the Cockpit screen, as its row on the home screen would |
| `GRABBER_COCKPIT_URL=<url or page>` | load the Cockpit from elsewhere: a URL (`https://127.0.0.1:65530/` is the unreachable case `just native-test-sim` checks for the error panel), or the name of a page in the app bundle — `cockpit-bridge-test` speaks the audio bridge the way the Cockpit does and reports the round trip as `getRoute("roundtrip:<microphones>:tagged")` |

What the native rungs can and cannot see of What's new (story 148, [spec](superpowers/specs/2026-10-06-native-whats-new-design.md)):

| Change | Where it must be verified | How |
|---|---|---|
| Which subjects count (Story NNN first, or stories in brackets), bookkeeping dropped, one line per story per local day, the story's summary and issue from the markdown, the home line, a missing or bad resource | Host | `WhatsNewTests` (one test parses every real file in `docs/stories/`) |
| What a build of this checkout would list | Host | `scripts/native/whats-new.sh <out.json>` prints the counts and writes the same JSON the build phase bundles |
| The row and the screen, with the build's real days | Simulator screenshot | launch plain, and with `SIMCTL_CHILD_GRABBER_WHATS_NEW=open`, then `simctl io screenshot`; the log's `ui` open_whats_new names the days and changes |

What the native rungs can and cannot see of the Gym Timer:

| Change | Where it must be verified | How |
|---|---|---|
| Phases, rounds, when each cue and duck hold falls, pause and resume, the catch-up after being away | Host | `TimerEngineTests`, `DeriveTimerStateTests` (the engine takes the clock as an argument) |
| The duck window's opening, holding and letting go | Host | `DuckWindowTests` with a hand-advanced clock |
| Custom preset snapping, the LED glyphs and geometry, the turn's margins, the stopwatch, the accessory log's SQL and grouping | Host | `CustomPresetTests`, `SevenSegmentTests`, `DeviceTurnTests`, `StopwatchTests`, `AccessoryLogTests` (real SQLite, in memory, in a pinned time zone) |
| The timer in the app: cues on their seconds, one window per boundary, the session let go at the end | Simulator | the `timer:` checks in `sim-smoke.sh` |
| Which voice counts: the default, the remembered choice, every voice having all six files | Host, then simulator | `CountVoiceTests` (the files on disk); the `voice:` checks in `sim-smoke.sh` (`voice: adam` by default, the hook's `aussie`) |
| Timer settings: the gear, the three rows and the checkmark | Simulator screenshot | `SIMCTL_CHILD_GRABBER_TIMER_SETTINGS=1 xcrun simctl launch …`, then `simctl io screenshot` |
| Hearing each voice, the sample on a tap, a change taking effect mid-workout | Phone only | choose each voice in the sheet, start 30 SEC, `just pull-logs`, read `ui` count_voice / `timer_voice_sample` / `timer_cue` voice |
| The face, upright and turned | Simulator screenshot | `SIMCTL_CHILD_GRABBER_TIMER=10,10,2 SIMCTL_CHILD_GRABBER_TURN=left xcrun simctl launch …`, then `simctl io screenshot` |
| Music dipping and coming back, a podcast pausing and resuming, cues with the phone locked, the real turn, the screen staying lit | Phone only | run a workout with music, lock for a round, `just pull-logs`, read `timer_session` / `timer_duck` / `timer_cue` / `timer_interruption` |
| The Cockpit's bridge wire format (parsing, payloads, the injected scripts run in JavaScriptCore), the output roster and re-assert rules, the client tag, which links stay | Host | `BridgeParseTests`, `BridgePayloadTests`, `BridgeScriptTests`, `AudioRoutingTests`, `CockpitPageTests` |
| The Cockpit in the app: page loaded with the tag, `audio.ready`, a device list delivered and acknowledged by the page, one answer per request, the call's screen hold, the unreachable panel | Simulator | the `cockpit:` checks in `sim-smoke.sh` (the bridge test page); `GRABBER_COCKPIT=open` alone loads the real tailnet page when the Mac is on the tailnet |
| Real microphones and headsets in the pickers, a route put back after the page's capture starts, AirPods arriving mid-call, the microphone prompt, the screen held through a call, Done and back keeping the page | Phone only | open the Cockpit with AirPods paired, pick them, start a page call, `just pull-logs`, read `audio_route` / `cockpit_bridge` / `keep_awake` |

What the native rungs can and cannot see of Box breathing:

| Change | Where it must be verified | How |
|---|---|---|
| Cycles from the sliders, the summary and Done lines, each step's length and order, the ring, the circle's eased size, the hold bar, time left | Host | `BreathPlanTests` |
| Steps called on their seconds, 30 cycles without drift, pause and resume mid-step, the lead-in, a late look | Host | `BreathRunTests` (the run takes the clock as an argument) |
| The tones: length, quiet edges, no clipping, a valid WAV | Host | `BreathToneTests` |
| The session in the app: steps on their seconds, every phrase from its file, every tone played, the screen lock given back | Simulator | the `breathe:` checks in `sim-smoke.sh` |
| The look of Setup, the circle (running, on a hold, paused) and Done | Simulator screenshot | `SIMCTL_CHILD_GRABBER_BREATHE=open` for Setup; `6,1,off` and a screenshot at ~3 s (inhale), ~8 s (hold) and ~26 s (Done); `6,1,off,3` for the paused circle; then `simctl io screenshot` |
| The keepalive running for the session and stopping at its end | Simulator | the `breathe: keepalive` check in `sim-smoke.sh` (`breath_keepalive`) |
| How the voice and tones sound, cues over playing music, the screen staying lit, the session and its cues carrying on with the phone locked, Reduce Motion, VoiceOver | Phone only | a session with music on, lock for a cycle, `just pull-logs`, read `breath_session` (other_audio) / `breath_keepalive` / `breath_cue` / `breath_phase` (late_ms while locked) |

What the native rungs can and cannot see of the Live Activity (both screens; [spec](superpowers/specs/2026-10-04-native-live-activity-design.md)):

| Change | Where it must be verified | How |
|---|---|---|
| What the card says for each phase, step, pause and finish; that it is pushed only at steps and pauses, not every second; the exact end of a step through pauses and the lead-in | Host | `GymTimerActivityContentTests`, `BreatheActivityContentTests`, `PhaseEndsAtTests` |
| The card requested, pushed once per step, ended on the finish, each accepted by iOS (or the one `unavailable` line if Live Activities are off) | Simulator | the `live activity` checks in `sim-smoke.sh` (`live_activity` events, timer and breathe runs). The simulator has Live Activities on |
| The compact island: its words, colour and countdown, running and paused | Simulator screenshot | start a session (`SIMCTL_CHILD_GRABBER_TIMER=1min`, `GRABBER_BREATHE=8,3,off`, or `6,1,off,3` for paused), `xcrun simctl launch <udid> com.apple.Preferences` to put another app in front, then `xcrun simctl io <udid> screenshot --mask=black` — without `--mask=black` the island is not in the picture |
| The lock-screen card, the expanded island (long press), the minimal view beside another app's activity, *DONE!* / *Done* and its going a few minutes later, the countdown reaching zero with the cue, a tap landing on the screen, a card left by a killed app gone at the next launch, Live Activities switched off in Settings | Phone only | a 2 MIN workout: lock during round 2, STOP, START, run to DONE!, tap the card; a breathing session locked in cycle 3; then `just pull-logs` and read `live_activity`. The headless simulator here has no Simulator app, so nothing can lock it or long-press |

What the native rungs can and cannot see of Places ([spec](superpowers/specs/2026-10-04-native-places-design.md)):

| Change | Where it must be verified | How |
|---|---|---|
| Stays, the consecutive same-place merge, Place N numbering, known-place matching and growing, the day cards and strips, the daily text, today's route and the map's framing | Host | `StayClusteringTests`, `KnownPlacesTests`, `PlacesDailyTests`, `TodaysRouteTests`, `PlaceStyleTests` (the jest cases, translated, in a pinned time zone) |
| The same answers as the TypeScript on real data | Host | `PlacesFixtureTests`: the 36 601-point fixture against `Fixtures/places-expected.json`, which `TZ=America/Los_Angeles node scripts/native/make-places-expected.mjs` writes from `lib/` itself (rerun it after `npm ci` when the TypeScript changes) |
| The store: insert, range, prune, settings keys, known places, import twice, a file that is not a database, the export snapshot | Host | `LocationStoreTests`, `PlacesFixtureTests.testImportTheRealExportTwice` (real SQLite, in memory or a temp file) |
| Import of the real export (and again, adding nothing), the export file's contents, tracking on with Always and points stored as the simulator moves, recording resumed at launch, retention lowered pruning at once, no `error` | Simulator | the `places:` and `tracking:` checks in `sim-smoke.sh` |
| The screen: map with pins, You and today's path, the day cards, full-screen map | Simulator screenshot | the hooks above, then `simctl io screenshot` (`~/tmp/agent/image/places/`) |
| The permission prompts (While Using, then Always; *Keep Only While Using* turning the switch back off), points with the app in the background and after it was closed (the significant-change relaunch), the blue indicator, an overnight at home read as one stay, the precise fix moving You, Use current at a real place, sharing the export to the Mac and sharing Context Grabber's export into the app, battery with both apps tracking | Phone only | turn tracking on, leave the app closed for a day, `just pull-logs`, read `location_permission`, `tracking`, `location_point` (background: true), `location_fix`, `prune`, `import`, `export` |

What the native rungs can and cannot see of the call:

| Change | Where it must be verified | How |
|---|---|---|
| The call's states, frames both ways, captions, mute, restart, the no-first-frame reset and redial, the zeros re-arm, the probe, the five-second counters, audio not arriving, endings | Host | `CallSession*Tests` (fake socket, fake audio layer, a hand-advanced `FakeScheduler`: the jest cases of `callSession.test.ts` translated) |
| The watchdog's verdicts, the call log's lines and trouble rule, the gist body, requests, GitHub's answers, the ten-gist cap | Host | `CallWatchdogTests`, `CallEventLogTests`, `GistTests` |
| A whole call in the app: start frame with the client tag, mic frames up, PCM down scheduled, captions, the hang-up's dump, `stt_stop` and `stop` | Simulator | the `call (synthetic)` and `call (real audio)` checks in `sim-smoke.sh` against `scripts/native/fake-bridge.py` |
| Echo cancellation, the call with the phone locked, interruptions, AirPods and route changes, a real call to Larry, the Keychain token and a real gist, the Call Larry Shortcut | Phone only | call Larry, lock for two minutes, `just pull-logs`, read `call_audio` / `call_stats` / `call_heal`; Diagnostics → Upload |

What the native rungs can and cannot see of the mirror and Grab Context:

| Change | Where it must be verified | How |
|---|---|---|
| Health math, sleep nights, the week's series, box plots, card and sheet text, the cache | Host | `MirrorHealthTests`, `MirrorWeeklyTests`, `MirrorBasicsTests` (ports of the jest cases, pinned to America/Los_Angeles) |
| The export, byte for byte with the React Native app | Host | `MirrorFixtureTests`: the native grab over `mirror-fixture.json` against `mirror-{summary,raw}-expected.json`, which `TZ=America/Los_Angeles node scripts/native/make-mirror-expected.mjs` writes by running the React Native app's own `lib/` (and a transcript of App.tsx's grab) over the same fixture |
| HealthKit's answers (units, overlap, order) giving the same bytes | Simulator | `just native-sim-health` once (a UI test grants Health's two-page access sheet — topics, then *All Recorded Data* — which simctl cannot tap), then the `mirror:` checks in `sim-smoke.sh` |
| Today and a sheet, drawn | Simulator screenshot | `SIMCTL_CHILD_GRABBER_MIRROR=fixture SIMCTL_CHILD_GRABBER_METRIC=sleep xcrun simctl launch …`, then `simctl io screenshot` |
| Igor's own Health: the cards equal the current app's Body tab; sources, preferred units; Health's access sheet | Phone only | grab in both apps, compare; `just pull-logs`, read `mirror_grabbed`, `health_query_failed` |

A new behaviour that only a tap can reach gets a hook and a log event in the same change; a check without an event
to wait on is not a check. `GrabberNative.xcodeproj` is generated from `native/project.yml` by XcodeGen
(`just native-project`, run by the build recipes) and is not committed.

## What kind of test goes where

| Change | Where it must be verified | How |
|---|---|---|
| Health math: sleep merge, weight, meditation, `buildHealthData` | Host | `__tests__/health.test.ts`, `sleep.test.ts` (noon-to-noon), `weekly.test.ts` (local-day bucketing) |
| Clustering, place matching, distance and merge thresholds | Host, against real data | `clustering_v2.test.ts`, `places.test.ts` with `__tests__/fixtures/locations.json` (36K real points) and `context-grabber.db` (4 real known places); a threshold is checked against the fixture before it ships (the place-merge gate moved 50 m → 500 m because the tight gate caught 0/10 unmatched stays) |
| The export | Host | `share.test.ts`, `snapshot.test.ts`, `summary.test.ts`; the JSON is a contract Larry depends on (`docs/user-needs.md`, Export Contract) |
| The call: state machine, reconnect, captions, ending text | Host | the `callSession` tests with a fake socket and fake audio; `callProtocol` / `audioBridge` / `pcm` tests for the wire formats; `gistUpload` tests for trouble detection and the upload |
| Gym Timer: phases, rounds, cues timing | Host | `timer.test.ts`; the face and the turn `ledTimer.test.ts`, `GymTimerScreen.test.tsx`; the accessory log `accessoryLog.test.ts` |
| Screens and components: rendering, taps, sheets | Host | the `*.test.tsx` component project |
| Deep links, the widget bridge's contract | Host | the `deepLink` tests; the Swift side by `just check-deal` |
| Layout on a real screen, the About / location / export flows | Simulator | Maestro, `.maestro/*.yaml`, screenshots under `/tmp/maestro_*` |
| The audio session: ducking around cues, a podcast pausing and resuming, echo cancellation, the mic after a route change | Phone only | run it, then read the timer log (the *Log* button) or the call log (Diagnostics fold); see [DEBUGGING.md](DEBUGGING.md) |
| HealthKit and GPS data, background tracking, pruning | Phone only | Grab Context, read the cards and the export |
| Widgets, Live Activity, Shortcuts, App Intents, the lock screen | Phone only, native build | `just deploy`; add the widget, tap it, check the App Group state through the Card tab |
| The Cockpit page and the voice bridge | Phone on the tailnet | a real call; the call log says what the bridge said |
| An OTA update | Phone | `just ota`, open the app twice, About shows the running commit message |

Analysis bugs (a wrong stay, a place that did not match, a sleep total that is off) are reproduced on the host first:
put the data in a fixture or a test, make it fail, fix, then ship. Never tune by reinstalling.

## Rung 1: host tests

Two jest projects in `jest.config.js`: `unit` (ts-jest, node, every `*.test.ts`) and `component` (the react-native
preset, every `*.test.tsx`). `jest.setup.js` mocks the native modules — expo-sqlite, the accelerometer (a test holds
the phone with `Accelerometer.__emit`), the clipboard, audio files map to a stub. Patterns worth copying:

- **A stateful fake store** rather than a SQL-shape assertion: `accessoryLog.test.ts` keeps inserted rows and honours
  the `WHERE` clause, so save → read-back is a real round trip.
- **`settle()` / `hold(x, y)`** in `GymTimerScreen.test.tsx`: flush effects, tilt the phone.
- **Real data** for geometry: `__tests__/fixtures/locations.json` and `context-grabber.db` (the `.db` is a real
  export; `sqlite3` can open it on the Mac).
- **Fake socket and audio** for the call: `lib/callSession.ts` is platform-free by design so the whole call can run in
  a test.

A test file per `lib/` module; the list lives in the `__tests__/` directory itself. `npx jest --watch <file>` while
iterating.

## Rung 2: simulator (Maestro)

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
maestro test .maestro/check-about.yaml
```

Flows: `check-about.yaml` (the About screen), `check-location-section.yaml` (Refresh, then the location sheet),
`export-db.yaml` (the database export). Use `testID` props, not `accessibilityLabel`, for taps. Maestro cannot tap
native system dialogs, so a flow that would trigger the HealthKit or location prompt is a phone test; the simulator
has no health data, and the cards must tolerate empty. Screenshots land in `/tmp/maestro_*`.

## Rung 3: the phone

- **`just ota "message"`** publishes the JavaScript bundle to the production channel. Refuses when the native surface
  (`ios/`, `modules/`, `patches/`, `package.json`, `app.json`) moved since the last `just deploy` from this Mac, or
  when `app.json` and `Expo.plist` disagree on the runtime version. The app picks it up on the second open; About
  shows the running commit message (baked at build time by `scripts/generate-version.js`).
- **`just deploy`** is the native build: `pod install` every time, the release build, install over `devicectl`,
  and the `.native-build-sha` marker. Needed for anything native and for a new pod; run
  `scripts/bump-runtime-version.sh` first when the native surface changed. Never `expo prebuild` here.
- **`just build` + `just dev`** is the debug build on Metro: faster iteration, no OTA.

What only the phone can show: HealthKit and CoreLocation (and CoreLocation's silence while the phone is still),
the audio session — the Gym Timer's ducking window, a podcast resuming, VoiceProcessingIO echo cancellation on a
call, the keepalive with the screen locked — the Live Activity and the widgets, Shortcuts and Siri, the Cockpit page
over the tailnet, the Keychain, and everything visual on an OLED.

**Log before theorizing.** When a phone symptom is unexplained, the first change is a log line, not a fix. The call
log, the timer log and every copyable error carry the build they came from. [DEBUGGING.md](DEBUGGING.md) says what
each holds and how to get it.
