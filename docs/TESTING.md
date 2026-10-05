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
| 2 Simulator | the app, driven by launch hooks, judged from its session log | `just native-test-sim` | ~1 min | it installs and launches, the log's first line names the build, a report is stored with its screenshot, no `error` event |
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
| `GRABBER_TURN=left\|right` | with `GRABBER_TIMER`: draw the timer as if the phone were on that side (the simulator has no accelerometer), for a screenshot of the turned face |
| `GRABBER_COCKPIT=open` | open the Cockpit screen, as its row on the home screen would |
| `GRABBER_COCKPIT_URL=<url or page>` | load the Cockpit from elsewhere: a URL (`https://127.0.0.1:65530/` is the unreachable case `just native-test-sim` checks for the error panel), or the name of a page in the app bundle — `cockpit-bridge-test` speaks the audio bridge the way the Cockpit does and reports the round trip as `getRoute("roundtrip:<microphones>:tagged")` |

What the native rungs can and cannot see of the Gym Timer:

| Change | Where it must be verified | How |
|---|---|---|
| Phases, rounds, when each cue and duck hold falls, pause and resume, the catch-up after being away | Host | `TimerEngineTests`, `DeriveTimerStateTests` (the engine takes the clock as an argument) |
| The duck window's opening, holding and letting go | Host | `DuckWindowTests` with a hand-advanced clock |
| Custom preset snapping, the LED glyphs and geometry, the turn's margins, the stopwatch, the accessory log's SQL and grouping | Host | `CustomPresetTests`, `SevenSegmentTests`, `DeviceTurnTests`, `StopwatchTests`, `AccessoryLogTests` (real SQLite, in memory, in a pinned time zone) |
| The timer in the app: cues on their seconds, one window per boundary, the session let go at the end | Simulator | the `timer:` checks in `sim-smoke.sh` |
| The face, upright and turned | Simulator screenshot | `SIMCTL_CHILD_GRABBER_TIMER=10,10,2 SIMCTL_CHILD_GRABBER_TURN=left xcrun simctl launch …`, then `simctl io screenshot` |
| Music dipping and coming back, a podcast pausing and resuming, cues with the phone locked, the real turn, the screen staying lit | Phone only | run a workout with music, lock for a round, `just pull-logs`, read `timer_session` / `timer_duck` / `timer_cue` / `timer_interruption` |
| The Cockpit's bridge wire format (parsing, payloads, the injected scripts run in JavaScriptCore), the output roster and re-assert rules, the client tag, which links stay | Host | `BridgeParseTests`, `BridgePayloadTests`, `BridgeScriptTests`, `AudioRoutingTests`, `CockpitPageTests` |
| The Cockpit in the app: page loaded with the tag, `audio.ready`, a device list delivered and acknowledged by the page, one answer per request, the call's screen hold, the unreachable panel | Simulator | the `cockpit:` checks in `sim-smoke.sh` (the bridge test page); `GRABBER_COCKPIT=open` alone loads the real tailnet page when the Mac is on the tailnet |
| Real microphones and headsets in the pickers, a route put back after the page's capture starts, AirPods arriving mid-call, the microphone prompt, the screen held through a call, Done and back keeping the page | Phone only | open the Cockpit with AirPods paired, pick them, start a page call, `just pull-logs`, read `audio_route` / `cockpit_bridge` / `keep_awake` |

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
