# Test architecture

The rule: every question is answered on the cheapest rung that can answer it, and a change is not "done" until the
rung that can see it has seen it. Say which rung you used. The rungs are ordered by cost, and the split follows the
code: `native/ContextCore` is platform-free and runs on the host; only what genuinely needs the app, HealthKit, GPS,
an audio session, a widget or the voice bridge goes higher. (The React Native app this replaced, and its jest and
Maestro rungs, were removed 2026-10-17; [design spec](superpowers/specs/2026-10-04-swift-native-app-design.md).)

| Rung | What runs | Command | Time | Answers |
|---|---|---|---|---|
| 1 Host | swift-format's lint over every native Swift file and SwiftLint's (no force unwrap, cast or try, no implicitly unwrapped optional, unless a `swiftlint:disable:next` line gives the reason), then `ContextCore` XCTest (`native/ContextCore`, the platform-free package), then the device build's signing path with fakes (`scripts/native/test-signing-guard.sh`), then the asset catalog compiled with actool, every home tile's art present and square (`scripts/native/test-tile-art.sh`) | `just native-test` (or `just test`; `just native-format` fixes the layout) | seconds | the layout (`native/.swift-format`); everything pure: what a log line can carry, log retention; each ported `lib/` module's logic |
| 2 Simulator | the app, driven by launch hooks, judged from its session log | `just native-test-sim` | ~1 min | it installs and launches, the log's first line names the build, a report is stored with its screenshot, no `error` event; the timer's and breathing's cues and Live Activity events, the card's deal and count |
| 3 Phone | Grabber Native on the iPhone | `just native-run-device`, then `just pull-logs` | minutes + a person | the shake, and everything the phone-only rows below list |

The phone recipes (`native-run-device`, `pull-logs`) need the iPhone's hardware UDID: `DEVICE=<udid>`
in the environment, or one line in `scripts/native/phone-udid.local`, which is gitignored because the repo is
public (`xcrun devicectl list devices` shows the id). Without either they stop with a line saying so. (`bugs-check`
is BugKit's and finds every plugged-in iPhone and iPad itself, no ids.) `pull-logs` covers the iPad too: its id is `IPAD=<udid>` or one line in the gitignored
`scripts/native/ipad-udid.local`. Each device's logs, reports and screenshots land in
`~/tmp/agent/grabber-logs/<phone|ipad>/`. A device
that is not plugged in or reachable is named and skipped. `native-run-device` builds under the Mac's one signing lock
(`~/tmp/agent/locks/xcode-signing.lock`, shared with every app and agent), so it waits while another signing build
runs; run it bare, not inside another `lockf` on that lock. Its xcodebuild runs through BugKit's `signing-guard.sh`
(bug-kit#53, from the pinned SwiftPM checkout): it waits while the Mac is locked rather than start a provisioning
build, and Xcode's "No Accounts" fails it with exit 78, so nothing installs.

The simulator cannot be shaken or tapped from a script, so the app reads **launch hooks** from the environment
(pass them through `simctl` as `SIMCTL_CHILD_<name>`); checks wait for an event in a *new* launch's log instead of
sleeping, so a slow start cannot reuse the previous result ([`scripts/native/sim-smoke.sh`](../scripts/native/sim-smoke.sh)).

| Hook | Effect |
|---|---|
| `GRABBER_BUG=text` | two seconds after launch, file a problem report with that note, as a shake and *Log it* would |
| `GRABBER_TIMER=<chip>` | open the Gym Timer on that chip (`30sec`, `1min`, `2min`, `5-1`, `custom`) and start it, as a widget tile would. `GRABBER_TIMER=work,rest,rounds` (seconds, seconds, count) runs that shape as Custom without remembering it: `10,10,2` is a whole workout in 35 s, which is what `just native-test-sim` runs and reads `timer_cue`, `timer_duck` and `timer_session` from |
| `GRABBER_BREATHE=breath,cycles[,cue[,pause_at_seconds]]` | open Box breathing and begin exactly that session (seconds a side, whole cycles, `voice` / `tone` / `off`; the cue is used but not remembered): `2,2,voice` is a whole session in 18 s, which `just native-test-sim` runs and reads `breath_phase`, `breath_cue` and `breath_finished` from. A fourth field pauses the session by itself that many seconds into the breathing, as a tap on the circle would (`breath_pause` with reason `hook`): `6,1,off,3` shows the paused circle mid-inhale, for a screenshot. Any other value (`open`) just opens the sliders, for a screenshot |
| `GRABBER_BREATHE_STYLE=line\|glow\|beads\|tide` | with `GRABBER_BREATHE`, draw that session's breath in that ring style (story 240); used but not remembered |
| `GRABBER_IMPORT_DB=<file>[,recent]` | import that database as *Import from Context Grabber* would (a path, absolute or under the app's Documents). `recent` shifts its timestamps by whole days so the newest point falls in the last 24 hours, at its own time of day, and the fixture's last week fills the last seven days (#217; whole weeks left it up to six days back): `just native-test-sim` copies the real fixture `__tests__/fixtures/context-grabber.db` to `Documents/import-fixture.db` and imports it this way, twice, reading `import` and `places_open` |
| `GRABBER_PLACES=open\|map[,unnamed[,name]][,edit:<name>]` | open Places (`map`: with the map full screen), for a screenshot and the `places_open` event; `map,unnamed` then opens the card of the longest unnamed place once the trail is read (`ui` unnamed_place, from: hook), and `map,unnamed,name` its naming card (story 056); `open,edit:Home` opens that known place's screen with its icon picker (story 057) |
| `GRABBER_TRACKING=on\|off` | flip the Background Tracking switch as a tap would; with `xcrun simctl privacy <udid> grant location-always com.idvorkin.grabbernative` first, `on` starts recording, and `xcrun simctl location <udid> start …` moves the simulator so points arrive (`location_point`) |
| `GRABBER_RETENTION=<days>` | set retention as the stepper would; lowering it prunes at once (`prune` with reason `lowered`) |
| `GRABBER_EXPORT=1` | make the export file as *Export database* does, without the share sheet; `export` names its path, which the smoke opens with `sqlite3` |
| `GRABBER_CALL=<ws url>` | open the call screen and, a second later, call that bridge as a tap on *Call Larry* would; hang up after `GRABBER_CALL_SECONDS` (default 8). `just native-test-sim` points it at `scripts/native/fake-bridge.py` on `ws://localhost:8799` and reads the `call_*` events and the bridge's own report |
| `GRABBER_CALL_AUDIO=synthetic` | with `GRABBER_CALL`: a 220 Hz tone for the mic and counted, unplayed playback instead of the audio engine, so the protocol path is checked whatever the simulator's audio does; the smoke run makes the call once this way and once on the real engine |
| `GRABBER_MIRROR=fixture\|healthkit` | open Today and grab the mirror's fixture week (`mirror-fixture.json`, moved to this week): `fixture` answers from the file, `healthkit` first saves it into the simulator's Health store (never on the phone) and grabs from HealthKit. Either writes `Documents/exports/{fixture,summary,raw}.json` and logs `mirror_fixture_done`; `sim-smoke.sh` checks each run's summary and raw are byte-identical to the fixture code path over that run's own `fixture.json` (a host test, `MirrorFixtureTests` with `MIRROR_COMPARE_DIR` naming the run's copy), and that the ten series came back with nothing failed. Health's access sheet needs one tap a script cannot make: `just native-sim-health` (a UI test) makes it once per simulator |
| `GRABBER_METRIC=<key>` | with `GRABBER_MIRROR`: open that metric's sheet after the grab (`sleep`, `movement`, `heartRate`, …), for a screenshot |
| `GRABBER_TURN=left\|right` | with `GRABBER_TIMER`: draw the timer as if the phone were on that side (the simulator has no accelerometer), for a screenshot of the turned face |
| `GRABBER_COUNT_VOICE=adam\|igor\|aussie` | with `GRABBER_TIMER` or `GRABBER_TIMER_SETTINGS`: count in that voice for this launch, not remembered and with no sample (story 187); `just native-test-sim` runs `aussie` and reads the first `timer_cue`'s `voice` |
| `GRABBER_TIMER_DIAL=drums\|knobs\|arc\|sliders` | which control sets Custom's Work, Rest and Rounds upright (story 184): the drums are what ships; the knobs, the arc and the old sliders are only for trying and screenshots. Alone it opens the timer on CUSTOM, not started (`ui` open_timer with dial); with `GRABBER_TIMER` it draws that control for the run. Not remembered |
| `GRABBER_TIMER_SETTINGS=1` | open the Gym Timer, not started, with *Timer settings* up (logs `ui` action: timer_settings), for a screenshot of the sheet |
| `GRABBER_WHATS_NEW=open` | open What's new (logs `ui` action: open_whats_new with from, days, changes), for a screenshot of the build's own history (story 148) |
| `GRABBER_HOME=settings` | open the home screen's Settings sheet (logs `ui` action: home_settings), for a screenshot of the launchers and the diagnostics (story 147) |
| `GRABBER_SUPERMIX=workout\|liked\|feel_good` | open that mix as a choice from the music tile's press-and-hold popover would (story 221; the simulator has no YouTube Music, so it opens in Safari); the log's `ui` open_workout_supermix carries the mix, from: hook and how |
| `GRABBER_INBOX_FIXTURE=1` / `GRABBER_INBOX=open` | write three Inbox items as the share extension would (a link with a note and two texts; their ids start `fixture-`, so they are never sent to Larry, since the simulator reaches the tailnet too), and open Chat (#305; `ui` open_chat, from: hook). The share sheet itself is a phone check: simctl cannot drive it |
| `GRABBER_CHAT_NEW=open` | open Chat with its + tapped: a new, empty thread with the ordinary bar on screen (`ui` open_new_chat, from: hook; #536). Typing, dictation and *Paste image* are phone checks |
| `scripts/native/test-chat-ui.sh <udid>` | the chat UI tests against the fake Cockpit (its POST /chat held 3 s, `FAKE_COCKPIT_NEW_DELAY`): a new chat's first Send starts the thread under its first line, the bar holds the next back until it lands, the next goes into that thread; plus the + and `GRABBER_CHAT_NEW` checks and the mic's. Run it in the build lane under `caffeinate -i` (#536) |
| `GRABBER_CHAT_URL=http://localhost:<port>` | Chat (and the Inbox's sending) talks to that Cockpit instead of the tailnet's: `scripts/native/fake-cockpit.py <port> <report>` stands in for the chat routes, with one thread and a Larry who answers each message a second later. Without it the simulator reads your real chats |
| `GRABBER_CHAT_SEND=<thread>\|<text>` | that text written in that thread as the compose bar would (`new\|<text>` starts a thread), then sent; use it only with `GRABBER_CHAT_URL`. With `GRABBER_LINK=grabbernative://chat?thread=<key>` the thread is on screen |
| `GRABBER_ARCHIVE=run` / `GRABBER_ARCHIVE_URL=<url>` | run the stats archive now (story 270), as a background refresh would, sending to that URL. On the simulator the URL is required and nothing is sent without it (the simulator reaches the tailnet, and its fixture week and imported trail must never land in the real archive); `just native-test-sim` points it at the unreachable `https://127.0.0.1:65530/` after the trail is imported and reads `archive` failed and `archive_run` stopped: retry |
| `GRABBER_LINK=<url>` | route that link as if iOS had opened it (`simctl openurl` stops at an "Open in Grabber Native?" confirmation a script cannot tap): `grabbernative://timer?preset=10,10,2`, `grabbernative://breathe?breath=5&minutes=2`; the log's `open_url` says how it was read. `LinksUITests` opens real links through iOS instead, cold and warm |
| `GRABBER_DRILL=card_to_position\|position_to_card\|mixed` | open the card screen (`ui` open_card, from: hook) and the trainer's drill over it in that direction, as a tap on *Drill the stack* would (story 220); `just native-test-sim` runs `mixed` and reads the library's `drill` how: open |
| `GRABBER_COCKPIT=open` | open the Cockpit screen, as its row on the home screen would |
| `GRABBER_COCKPIT_URL=<url or page>` | load the Cockpit from elsewhere: a URL (`https://127.0.0.1:65530/` is the unreachable case `just native-test-sim` checks for the error panel), or the name of a page in the app bundle — `cockpit-bridge-test` speaks the audio bridge the way the Cockpit does and reports the round trip as `getRoute("roundtrip:<microphones>:tagged")` |

What the native rungs can and cannot see of What's new (story 148, [spec](superpowers/specs/2026-10-06-native-whats-new-design.md)):

| Change | Where it must be verified | How |
|---|---|---|
| Which subjects count (Story NNN first, or stories in brackets), bookkeeping dropped, one line per story per local day, the story's summary and issue from the markdown, the home line, a missing or bad resource | BugKit's host tests | `WhatsNewTests` in idvorkin/bug-kit |
| What a build of this checkout would list | Host | BugKit's `scripts/whats-new.sh <out.json> --repo . --path native --fixed-reports` (from the SwiftPM checkout) prints the counts and writes the same JSON the build phase bundles (`--fixed-reports` reads the repo's issues with `gh`; without `gh`, auth or network the feed has no fixed reports) |
| The row and the screen, with the build's real days | Simulator screenshot | launch plain, and with `SIMCTL_CHILD_GRABBER_WHATS_NEW=open`, then `simctl io screenshot`; the log's `ui` open_whats_new names the days and changes |

What the native rungs can and cannot see of the home screen (story 147, [spec](superpowers/specs/2026-10-06-native-home-screen-design.md)):

| Change | Where it must be verified | How |
|---|---|---|
| The remembered order and hidden rows read against this build's rows: a new row at the end, a gone one dropped, moves, store and read back | Host | `HomeLayoutTests` |
| Hiding and moving a row on Settings → Launchers, both holding after a relaunch; Reset | Simulator | `HomeSettingsUITests` (`xcodebuild … -only-testing:GrabberNativeUITests/HomeSettingsUITests test`), then the `ui` home_rows lines in the log |
| Three tiles to a line, Recent beside Random, Settings the last tile (#284–#286) | Simulator | `HomeGridUITests` |
| The home screen and the sheet, drawn | Simulator screenshot | launch plain, and with `SIMCTL_CHILD_GRABBER_HOME=settings`, then `simctl io screenshot` |

What the native rungs can and cannot see of the Gym Timer:

| Change | Where it must be verified | How |
|---|---|---|
| Phases, rounds, when each cue and duck hold falls, pause and resume, the catch-up after being away | Host | `TimerEngineTests`, `DeriveTimerStateTests` (the engine takes the clock as an argument) |
| The duck window's opening, holding and letting go | Host | `DuckWindowTests` with a hand-advanced clock |
| The Custom dials' arithmetic: drag and turn into whole steps, the flick multiplier, the ranges held, the arc's angles | Host | `TimerDialsTests` |
| The drums (and the knobs and arc to try): their look, a swipe and a tap moving Work | Simulator | `GRABBER_TIMER_DIAL=<style>` screenshots; `GymTimerDialsUITests` (taps and a swipe on the Work drum). The haptic ticks are the phone's |
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

What the native rungs can and cannot see of links and Shortcuts ([spec](superpowers/specs/2026-10-06-native-links-design.md)):

| Change | Where it must be verified | How |
|---|---|---|
| What every link asks for, its parameters, ranges, bad input, the link each route is written as, the Links screen's list | Host | `AppLinkTests` |
| A link through iOS opening the app cold and warm, starting the timer or the breathing, an unknown link landing on home, Copy on the Links screen | Simulator | `xcodebuild … -only-testing:GrabberNativeUITests/LinksUITests test` (the warm case taps SpringBoard's *Open*), then the log's `open_url` |
| The Shortcuts actions and Siri phrases, the Action Button, a link from another app or a widget | Phone only | build a shortcut of *Start Gym Timer* (1 MIN), run it with the app closed, `just pull-logs`, read `open_url` from: shortcut |

What the native rungs can and cannot see of the live tile ([spec](superpowers/specs/2026-10-06-native-live-tile-design.md)):

| Change | Where it must be verified | How |
|---|---|---|
| The reading written and read back, the countdown and *to spend* worked out at drawing time, the age and when it turns orange, nothing written being the placeholder | Host | `UsageSnapshotTests` |
| Today's strip and Health under the usage: marks, counts, steps/HRV/exercise, short forms, the dash, independent local-day expiry and round trips | Host | `TodayGlanceTests` |
| The tile drawing the app's last reading (small and medium), being added to the home screen, its Gym Timer button starting the timer | Simulator | `xcodebuild … -only-testing:GrabberNativeUITests/UsageTileUITests test` (needs the Cockpit reachable from the Mac; it adds the tile through SpringBoard's gallery and keeps screenshots of the gallery and the home screen), then the log's `usage` load with tile: true |
| The tile on the phone over hours: redrawing every quarter hour, the orange age, today's numbers drawn and gone at midnight, Breathe and Call Larry from it, the App Group on a device-signed build | Phone only | add the medium tile, leave the app closed for two hours, look; tap each button; `just pull-logs`, read `usage` tile and `open_url` |

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
| The same answers as the TypeScript on real data | Host | `PlacesFixtureTests`: the 36 601-point fixture against `Fixtures/places-expected.json`, written from the TypeScript `lib/` before the React Native code was removed (2026-10-17): the file is now the record, changed only by a deliberate behaviour change |
| The store: insert, range, prune, settings keys, known places, import twice, a file that is not a database, the export snapshot | Host | `LocationStoreTests`, `PlacesFixtureTests.testImportTheRealExportTwice` (real SQLite, in memory or a temp file) |
| Import of the real export (and again, adding nothing), the export file's contents, tracking on with Always and points stored as the simulator moves, recording resumed at launch, retention lowered pruning at once, no `error` | Simulator | the `places:` and `tracking:` checks in `sim-smoke.sh` |
| The screen: map with pins, You and today's path, the day cards, full-screen map | Simulator screenshot | the hooks above, then `simctl io screenshot` (`~/tmp/agent/image/places/`) |
| The unnamed places: which, where, hours, visits, the suggested radius (against the real fixture), the dot's size and the card's lines | Host | `UnnamedPlacesTests` |
| Place icons: the name's guess, the Apple Maps rules (by name, then the nearest), what is remembered, chosen over everything, the twenty symbols existing | Host | `PlaceIconsTests` (the real fixture's Apple Maps answers, as the simulator got them, in the cases) |
| Apple Maps' answers for real places, the icons on the pins, the picker changing a pin at once | Simulator, online | `place_icon` lookup lines in the session log; `GRABBER_PLACES=map` and `open,edit:Home` screenshots; `PlaceIconUITests` |
| A grey dot's card, *Name this place*, the dot becoming a named pin | Simulator | `GRABBER_PLACES=map,unnamed` (and `,name`) screenshots; `PlacesUnnamedUITests` names the place and deletes it again (the fixture copied to `Documents/import-fixture.db` first, as `sim-smoke.sh` does) |
| The permission prompts (While Using, then Always; *Keep Only While Using* turning the switch back off), points with the app in the background and after it was closed (the significant-change relaunch), the blue indicator, an overnight at home read as one stay, the precise fix moving You, Use current at a real place, sharing the export to the Mac and sharing Context Grabber's export into the app, battery with both apps tracking | Phone only | turn tracking on, leave the app closed for a day, `just pull-logs`, read `location_permission`, `tracking`, `location_point` (background: true), `location_fix`, `prune`, `import`, `export` |

What the native rungs can and cannot see of the call:

| Change | Where it must be verified | How |
|---|---|---|
| The call's states, frames both ways, captions, mute, restart, the no-first-frame reset and redial, the zeros re-arm, the probe, the five-second counters, audio not arriving, endings | Host | `CallSession*Tests` (fake socket, fake audio layer, a hand-advanced `FakeScheduler`: the jest cases of `callSession.test.ts` translated) |
| The watchdog's verdicts, the call log's lines and trouble rule | Host | `CallWatchdogTests`, `CallEventLogTests`; the automatic report's window, cap and format are BugKit's own tests |
| A whole call in the app: start frame with the client tag, mic frames up, PCM down scheduled, captions, the hang-up's dump, `stt_stop` and `stop` | Simulator | the `call (synthetic)` and `call (real audio)` checks in `sim-smoke.sh` against `scripts/native/fake-bridge.py` |
| Echo cancellation, the call with the phone locked, interruptions, AirPods and route changes, a real call to Larry, a real troubled call reaching an issue, the Call Larry Shortcut | Phone only | call Larry, lock for two minutes, `just pull-logs`, read `call_audio` / `call_stats` / `call_heal`; after a troubled call, `bug_report_auto` in the log and the always-on listener files *Automatic report: call_trouble* within five minutes — watch it land in `~/tmp/agent/bugs/inbox.jsonl` |

What the native rungs can and cannot see of the mirror and Grab Context:

| Change | Where it must be verified | How |
|---|---|---|
| Health math, sleep nights, the week's series, box plots, card and sheet text, the cache | Host | `MirrorHealthTests`, `MirrorWeeklyTests`, `MirrorBasicsTests` (ports of the jest cases, pinned to America/Los_Angeles) |
| The export, byte for byte with the React Native app | Host | `MirrorFixtureTests`: the native grab over `mirror-fixture.json` against `mirror-{summary,raw}-expected.json`, written by running the React Native app's own `lib/` (and a transcript of App.tsx's grab) over the same fixture before that code was removed (2026-10-17): the files are now the record |
| HealthKit's answers (units, overlap, order) giving the same bytes | Simulator | `just native-sim-health` once (a UI test grants Health's two-page access sheet — topics, then *All Recorded Data* — which simctl cannot tap), then the `mirror:` checks in `sim-smoke.sh` |
| Today and a sheet, drawn | Simulator screenshot | `SIMCTL_CHILD_GRABBER_MIRROR=fixture SIMCTL_CHILD_GRABBER_METRIC=sleep xcrun simctl launch …`, then `simctl io screenshot` |
| Igor's own Health: the cards equal the current app's Body tab; sources, preferred units; Health's access sheet | Phone only | grab in both apps, compare; `just pull-logs`, read `mirror_grabbed`, `health_query_failed` |

A new behaviour that only a tap can reach gets a hook and a log event in the same change; a check without an event
to wait on is not a check. `GrabberNative.xcodeproj` is generated from `native/project.yml` by XcodeGen
(`just native-project`, run by the build recipes) and is not committed.

Analysis bugs (a wrong stay, a place that did not match, a sleep total that is off) are reproduced on the host first:
put the data in a fixture or a test, make it fail, fix, then ship. Never tune by reinstalling. The real-data fixtures
are `__tests__/fixtures/locations.json` (36K real points), `context-grabber.db` (a real export with 4 known places;
`sqlite3` opens it on the Mac) and `heart-rate-2d.json`; a geometry threshold is checked against them before it ships
(the place-merge gate moved 50 m → 500 m because the tight gate caught 0/10 unmatched stays).

## The phone

`just native-run-device` builds, installs and launches; `just pull-logs` brings back the session logs, reports and
crashes. What only the phone can show: HealthKit and CoreLocation (and CoreLocation's silence while the phone is
still), the audio session — the Gym Timer's ducking window, a podcast resuming, echo cancellation on a call, the
keepalive with the screen locked — the Live Activity and the widgets, Shortcuts and Siri, the Cockpit page over the
tailnet, and everything visual on an OLED.

**Log before theorizing.** When a phone symptom is unexplained, the first change is a log line, not a fix. Every
session log and report carries the build it came from. [DEBUGGING.md](DEBUGGING.md) says what each holds and how to
get it.
