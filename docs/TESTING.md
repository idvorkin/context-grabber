# Test architecture

The rule: every question is answered on the cheapest rung that can answer it, and a change is not "done" until the
rung that can see it has seen it. Say which rung you used. The rungs are ordered by cost, and the split follows the
code: `native/ContextCore` is platform-free and runs on the host; only what genuinely needs the app, HealthKit, GPS,
an audio session, a widget or the voice bridge goes higher. (The React Native app this replaced, and its jest and
Maestro rungs, were removed 2026-10-17; [design spec](superpowers/specs/2026-10-04-swift-native-app-design.md).)

| Rung | What runs | Command | Time | Answers |
|---|---|---|---|---|
| 0 Lint | swift-format's lint over the Swift files the branch touched, then SwiftLint over the tree (no force unwrap, cast or try, no implicitly unwrapped optional, unless a `swiftlint:disable:next` line gives the reason) | `just native-lint-touched` (`just native-format` fixes the layout) | ~2 s | the layout (`native/.swift-format`) of what changed; a new `!` or `try!` |
| 1 Host | `ContextCore` XCTest (`native/ContextCore`, the platform-free package), then the device build's signing path with fakes (`scripts/native/test-signing-guard.sh`), the breathing clips, the asset catalog compiled with actool with every home tile's art present and square (`scripts/native/test-tile-art.sh`), the ladder's own map (`scripts/native/test-ladder-map.sh`), and the UI test timing digest against a real run's log (`scripts/native/test-ui-timings.sh`). `just native-test`, or `just test`, is rungs 0 and 1 with swift-format over the whole tree: what the gate runs | `just native-test-host` | ~25 s once built | everything pure: what a log line can carry, log retention; each ported module's logic |
| 1.5 Mac | the Catalyst build, ad hoc; once open, driven by the same launch hooks (`open --env`), judged from the session log in its sandbox folder; `GRABBER_BUG=<note>` saves a report whose picture is the screen. It reaches Igor's real Cockpit unless named, so a test launch must name the stand-in or nowhere (`https://no-address.invalid`) on every route: `COCKPIT=` sets all three, and a hook-driven `open --env` launch sets `GRABBER_CHAT_URL`, `GRABBER_COCKPIT_URL` and `GRABBER_USAGE_URL` itself. Naming only the chat address leaves the page and the usage strip on the real Cockpit. A launch named anywhere but the real Cockpit has its own outbox (`Inbox-test`, beside `Inbox`), so what it leaves waiting stays among test launches | `just native-build-mac`; `just native-run-mac` opens it, `COCKPIT=<url>` to name a Cockpit | ~5 min | code under `#if targetEnvironment(macCatalyst)`, which the host cannot compile; with `native-run-mac`, it opens and every screen comes up. What a mouse can draw, what iCloud does and the keys (Enter sends, #683) on a Mac still take a person: `MacKeysUITests` presses them but waits for a signed run, as the ad hoc test runner refuses to load it |
| 2 Simulator | the build with its UI tests; the UI test classes the change touches; `just native-test-sim`'s smoke, the app driven by launch hooks and judged from its session log; the areas' whole suites (`scripts/native/test-chat-ui.sh`, `test-whiteboard-ui.sh`) | `just test-ladder` for the build and the touched classes, `--full` for the suites; `just native-test-sim` for the smoke | build ~5 min; a class ~30 s a test; smoke ~1 min; the whiteboard's suite ~18 min on one boot (an estimate from the 7 Nov per-class times, until the Mac times it; ~28 min with two boots before) | a real view, gesture or system service: it installs and launches, the log's first line names the build, a report is stored with its screenshot, no `error` event; the timer's and breathing's cues and Live Activity events, the card's deal and count |
| 3 Phone | Grabber Native on the iPhone | `just native-run-device`, then `just pull-logs` | minutes + a person | the shake, and everything the phone-only rows below list |

## Off the Mac: `just test-linux`

On a Linux box, with no Xcode, `just test-linux` runs `ContextCore`'s XCTests under Linux Swift, then cross-builds the
package and its tests for arm64 macOS, iOS and the iOS simulator with a Darwin Swift SDK (xtool's): compiled, never
run. It is not a rung: it catches a type, concurrency or API slip in `ContextCore` before the Mac does, and the Mac's
rung 1 still decides. At f83889f, 1,064 of the Mac's 1,123 host tests ran on Linux (one of them skipped: the
simulator-exports comparison, which only `sim-smoke.sh` arms) in about 8 s, once built; `just test-linux` prints the
count. It needs a Swift 6 Linux toolchain and SQLite's
header (`libsqlite3-dev`); without a `darwin` Swift SDK the cross-build says it was skipped. The script's header lists
the settings for a toolchain that is not on `PATH`.

A unit that needs an Apple framework is under `#if canImport(<framework>)`, and so are the tests that use it. Where
portable code calls one, Linux gets a stand-in that declines (no image is readable, a label has no outline), and the
tests that need the real one stay on the Mac. Three stand-ins answer instead, so their tests run on both: finding a
message's links (NSDataDetector on Apple, a scan for `http://` and `https://` on Linux), a file's upload type (UTType
on Apple, a table of common types on Linux) and an affine transform (CoreGraphics on Apple, a shim on Linux). The
same tests pass on Linux, but only the Mac's run says the app is right. Left out on Linux:

| What | Why |
|---|---|
| Image reading and shrinking, a picked picture, share-sheet providers | ImageIO, NSItemProvider |
| Label outlines, pasted text | CoreText |
| The audio bridge's script run in a page | JavaScriptCore |
| The mirror fixture written back byte for byte | Linux's JSONSerialization misreads a 17-digit double |

## What kind of change is verified where

| Change | Where it must be verified | How |
|---|---|---|
| Words: documents, comments in Markdown | Nowhere above lint | read the diff |
| Pure logic in `ContextCore`, a rule that needs no screen | Host | an XCTest in `native/ContextCore/Tests` |
| A script check, the ladder's map | Host | `scripts/native/test-*`, run by `just native-test-host` |
| Mac-only code, or anything else that goes into the Mac build | Mac | `just native-build-mac`; a host test can't compile it, and neither can a simulator build |
| A UI test | Simulator | that class: `just test-ladder` |
| Chat or whiteboard on screen | Simulator | `just test-ladder` for the area's classes, `--full` for its suite |
| The timer, breathing, Places, the mirror, the card, the Cockpit, the daily strip, the eulogy or the links on screen | Simulator | `just test-ladder` for the feature's own classes (the map below) |
| Any other screen on screen (a call, an iPad's windows, the home screen itself) | Simulator | the feature's own rows below, or `just test-ladder --all`; the ladder has no map for it and says so |
| HealthKit, GPS, the audio session, widgets, Live Activities, Shortcuts, the voice bridge, the OLED | Phone | the phone-only rows below, then `just pull-logs` |

## Climbing: `just test-ladder`

`just test-ladder` climbs from rung 0 and stops at the first failure, printing the seconds per rung and the rung it
stopped on (story 683). It reads the change from the branch since `origin/main`, committed or not (`--base <ref>` for
another base). A rung with nothing to answer is skipped: the Mac and simulator builds aren't run for words, host tests
or test scripts alone, and a UI test isn't in the Mac build. `--dry-run` prints the rungs and classes and runs nothing;
`--changed <path>` tries the map on a path; `--rung <n>` runs one rung. It never climbs to the phone.

After every run of UI tests, wherever it ran from (the ladder, a suite script, `xcodebuild-log.sh` directly), the run
says where its time went (story 745): the slowest tests, each class's total and how much of it was launching the app,
the steps XCUITest retried, and the kinds of wait of a second or more that cost the most. It also appends one JSON line
per test to `ui-timings.jsonl` beside the run's log (`UI_TIMINGS_JSONL` names another file), so a change meant to
speed the runs up can be measured against the runs before it. `scripts/native/ui-timings.py <log>` reads any saved log.

Which classes a change gets, from an explicit map that `scripts/native/test-ladder-map.sh` checks against the real
script's dry run:

| Changed | UI test classes |
|---|---|
| A test file | the classes it declares, and any that inherit them |
| Chat or the Inbox, in the app or `ContextCore`; the chat suite's script; the fake bridge | chat's |
| The whiteboard, in the app or `ContextCore`; the whiteboard suite's script | the whiteboard's |
| The fake Cockpit | chat's and the whiteboard's |
| The Gym Timer, in the app or `ContextCore` | `GymTimerDialsUITests`, `GymTimerUITests` |
| Breathing, in the app or `ContextCore` | `BreatheMindfulUITests`, `BreathePresetsUITests`, `BreatheStyleUITests` |
| Places, in the app or `ContextCore` | `PlaceIconUITests`, `PlacesProblemUITests`, `PlacesRangeUITests`, `PlacesUnnamedUITests`, in a run of their own: the ladder first installs the build, copies the real export to the app's `Documents/import-fixture.db` and launches the app once to import it, failing the rung if the import's event doesn't come |
| The mirror (Today, a metric's detail), in the app or `ContextCore` | `HomeTodayCardUITests`, `MetricDetailUITests` |
| The card, in the app or `ContextCore` | `CardUITests`, `TodaysHandUITests`; the role of the day's file, `TodaysHandUITests` alone |
| The Cockpit, in the app or `ContextCore` | `CockpitBackUITests`, `CockpitCallUITests` |
| The usage strip's files (`Usage*`, `CockpitUsage.swift`), in the app or `ContextCore` | `UsageTileUITests`, which needs the real Cockpit reachable from this Mac: a Cockpit change off the tailnet doesn't run it |
| The daily strip, in the app or `ContextCore` | `DailyStripUITests` |
| The eulogy; the blog's links in `ContextCore` | `EulogyUITests` |
| The links, in the app or `ContextCore` | `LinksUITests` |
| The supermix link in `ContextCore` | `WorkoutSupermixUITests` |
| A held tile's choices in `ContextCore` | `HoldPopoverUITests` |
| Words, host tests, the home tiles' art, other scripts | none |
| Any other app code (a call, the archive, the Live Activity, an iPad's windows, the files at the app's top level); a helper the UI tests share | none, and the output names the path and `--all`, which runs every UI test class |

A feature's row is its directory under `native/App` and the one of the same name under `ContextCore`'s sources (#795).
A class is in the map only if it runs on the ladder's simulator and opens that feature, and the map's check fails when a
class it names is gone. A file whose feature isn't its directory's has a row of its own. The windows have no row, nor
their ledger in `ContextCore`: `IPadUITests` skips on a phone and `MacKeysUITests` exists only in the Mac build.
`HealthAccessUITests` stays the smoke's.

A whiteboard class list is the suite less its fake-Cockpit report checks, so a change to the whiteboard's app code
costs about the suite's time; a change to one test file costs that file. `--full` runs the whole suite of each area the
change touched, in place of that area's classes.

The Mac and simulator rungs run in the build lane, one job at a time: `lockf -k -t 3600 ~/tmp/agent/locks/build.lock`,
then, inside the lock, the wait for other xcodebuilds (below), then `time-limit` and `caffeinate -i`, so the time limit
counts only the rung's own run. The simulator is shut down after, pass or fail.

**Never run a simulator rung while another xcodebuild is running.** Startup waits fail under contention, and a run
under contention counts as failed and is rerun, not debugged. The lock doesn't cover this, since a device build skips
it. `scripts/native/xcodebuild-idle.sh` waits for every xcodebuild on the Mac before the Mac rung, the simulator rung
and `just native-test-sim` start, says so, and refuses with exit 75 after half an hour (`XCODEBUILD_IDLE_WAIT`). If one
appears during the run, the rung says so at the end: a failure is reported as contention. A pass stands, with a note,
because contention makes a test fail when it shouldn't, not pass.

The host rung has no report suites to skip: nothing in `native/ContextCore/Tests` prints (checked 2026-11-05, 985
tests).

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

**A locked Mac seems to starve the simulator's audio** (#419: inferred from comparing locked and unlocked runs of the
same code, not traced into CoreAudio). Timer cues come late or empty, the keepalive fails, breathing is silent and the
real-audio call can hear only zeros, on code that passes unlocked. The smoke prints a line when the Mac is locked at its
start or end, and still runs and fails those checks, so the evidence stays; judge the timer, breathing, voice and
real-audio call checks only from an unlocked run.

**Only what the branch touched, and quietly** (Igor, 2026-11-01). The smoke runs only the sections for the features
this branch changed since `origin/main`: cockpit, whiteboard, timer, breathe, places, call, mirror, drill or
chat. [`smoke-features.sh`](../scripts/native/smoke-features.sh) maps the changed paths to sections. A change to shared
code, the project or the smoke itself runs everything, and docs or host tests alone run none. The launch and report
checks always run. To run every section, set `SMOKE_ONLY=all just native-test-sim`; to pick sections, set
`SMOKE_ONLY=timer,breathe`. The app under test plays silently, while the Mac's own sound is left alone. The simulator would otherwise play the
timer's counts, the breathing voice and the call through the Mac's speakers. `GRABBER_SILENT=1` goes to every launch,
and it sets the app's players to zero volume, so every cue still plays and still shows in the log. The host rung
(`just test`) plays nothing and stays whole (its time is in the rung table above).

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
| `GRABBER_METRIC=<key>` | with `GRABBER_MIRROR`: open that metric's detail after the grab (`sleep`, `movement`, `heartRate`, …), for a screenshot |
| `GRABBER_TURN=left\|right` | with `GRABBER_TIMER`: draw the timer as if the phone were on that side (the simulator has no accelerometer), for a screenshot of the turned face |
| `GRABBER_COUNT_VOICE=adam\|igor\|aussie` | with `GRABBER_TIMER` or `GRABBER_TIMER_SETTINGS`: count in that voice for this launch, not remembered and with no sample (story 187); `just native-test-sim` runs `aussie` and reads the first `timer_cue`'s `voice` |
| `GRABBER_SILENT=1` | the app's own sound at zero volume: the timer's and breathing's players, the breathing voice, the song and the call's speaker side. Nothing else changes: every cue still plays and logs as played, and the call's silent-mixer check still hears the call. `sim-smoke.sh` sets it on every launch, so a smoke run is quiet without muting the Mac |
| `GRABBER_TIMER_DIAL=drums\|knobs\|arc\|sliders` | which control sets Custom's Work, Rest and Rounds upright (story 184): the drums are what ships; the knobs, the arc and the old sliders are only for trying and screenshots. Alone it opens the timer on CUSTOM, not started (`ui` open_timer with dial); with `GRABBER_TIMER` it draws that control for the run. Not remembered |
| `GRABBER_TIMER_SETTINGS=1` | open the Gym Timer, not started, with *Timer settings* up (logs `ui` action: timer_settings), for a screenshot of the sheet |
| `GRABBER_WHATS_NEW=open` | open What's new (logs `ui` action: open_whats_new with from, days, changes), for a screenshot of the build's own history (story 148) |
| `GRABBER_WINDOW=<screen>[,again][,close]` | on an iPad simulator (a phone has one window): once the home window is up, opens that screen (`chat`, `today`, `cockpit`, `places`, `whiteboard`, `card`) in its own window as *New window* would, then three seconds apart asks again and closes it (story 460, 461). Read `window` from the log: `open`, `appear`, `bring_forward`, `close` and `gone`, with `scenes`, the windows connected; and `title`, what the app just named a window, read back from the scene, and what it was (#661). A hold on a tile, iPadOS's own New Window, what the windows look like beside each other and where iPadOS shows a window's name are checked on the iPad |
| `GRABBER_WINDOW_CHOOSE=<screen>` | on an iPad simulator: once the home window is up, opens a new window as Command+N or iPadOS's New Window would, which shows the chooser since home is taken, and the chooser picks that screen as a tap would (story 731, #782). Read `window` from the log: `extra_home` and `appear` for the chooser, then `choose` with screen and scenes, `open` (or `bring_forward`) with from: new_window, and the chooser's `gone`; `choose_close` with ok: false when iOS refused to close it. The chooser's rows and their order are checked on the iPad or the Mac |
| `GRABBER_WHITEBOARD=open` | open the boards, as the Whiteboard tile on the home screen would (`ui` open_whiteboard, from: hook, then `whiteboard` list with the count, and `whiteboard_sync`: on a simulator with no iCloud account, ok: false with skipped: account_…, never an error). `just native-test-sim` runs it and reads those three. Drawing, the tool picker and a board from another device need a real iPad and iPhone signed into iCloud |
| `GRABBER_HOME=settings` | open the home screen's Settings sheet (logs `ui` action: home_settings), for a screenshot of the launchers and the diagnostics (story 147) |
| `GRABBER_SUPERMIX=workout\|liked\|feel_good` | open that mix as a choice from the music tile's press-and-hold popover would (story 221; the simulator has no YouTube Music, so it opens in Safari); the log's `ui` open_workout_supermix carries the mix, from: hook and how |
| `GRABBER_INBOX_FIXTURE=1` / `GRABBER_INBOX=open` | write three Inbox items as the share extension would (a link with a note and two texts; their ids start `fixture-`, so they are never sent to Larry, since the simulator reaches the tailnet too), and open Chat (#305; `ui` open_chat, from: hook). The share sheet itself is a phone check: simctl cannot drive it |
| `GRABBER_CHAT_NEW=open\|voice` | open Chat with its + tapped: a new, empty thread with the ordinary bar on screen (`ui` open_new_chat, from: hook; #536). `voice` taps the voice button beside the + instead, so the thread opens recording (`voice`: true, then `chat_voice`; #637). Typing, speaking and *Paste image* are phone checks |
| `GRABBER_CHAT_SELECT=archive` | with `GRABBER_INBOX=open` and `GRABBER_CHAT_URL`: once the list is read, *Review* and *Archive (N)* tap themselves (`chat` select, from: hook, with count; archive, from: select; stories 312, 314). `sim-smoke.sh`'s chat section checks it against the fake Cockpit |
| `scripts/native/test-chat-ui.sh <udid>` | the chat UI tests against the fake Cockpit (its POST /chat held 3 s, `FAKE_COCKPIT_NEW_DELAY`): a new chat's typed first Send starts the thread under its first line, the bar holds the next back until it lands, the next goes into that thread and the field empties with the keyboard up (story 274); the voice button beside the + and the + after it opening the ordinary bar with the keyboard up and, against `scripts/native/fake-bridge.py` (port `CHAT_BRIDGE_PORT`, default 8797), a live call keeping the mic from it (#637), the mic's and the full-size picture's way back, and archiving (`ChatArchiveUITests`, stories 307–309, 311, 316, 506: only what the real list shows — the + and the voice button floating over it with the pinned thread on top, a real swipe and its Undo, Select's ticks and *Archive (2)* clear of the buttons with one Undo, the ⋯ menu archiving and going back, and a swipe under Done unarchiving. The chat views decide nothing: which row offers what, Review, Cancel, the counts and lines, a refusal putting a row back, the five seconds, an Undo waiting for its archive's answer and a list read racing a change are `ChatArchiverTests`, and where a Send goes, when it can, the bar's lines, the title and the focus rule are `ChatNewThreadScreenTests`, both on the host), and a skill's thread (`ChatSkillThreadUITests`, stories 512–515: pinned under Larry's with no way to archive it, its reply arriving by itself, a failure as a copyable error with 👀 on Igor's message, and the list row naming it), and holding a message (`ChatReactionUITests`, stories 518–519, 540–541: the menu on Larry's and on Igor's own, *Yes* on the newest, *No* on an older one under its quote, read from what the fake's Larry repeats, and *Quote in reply* filling the bar and sending nothing). Run it in the build lane under `caffeinate -i` (#536) |
| `scripts/native/test-whiteboard-ui.sh <udid>` | the boards list's delete (`WhiteboardRowDeleteUITests`, stories 396, 399); the whiteboard paste UI test: a clipboard set by the test reaches a board on paper through ⌘V and one ⌘Z takes it all back (keys reach the app only in the first test after a boot that presses any, so this is the one test that presses them), and `GRABBER_WHITEBOARD_PASTE` brings a stroke a letter, the pause and the emoji note (stories 390–393, 638, 639); the layout, the caps and which note the bar shows are `WhiteboardPasteTests`, on the host. And the whiteboard turn UI test against the fake Cockpit, Claude's ghosts from `POST /whiteboard/suggest` and Larry's marks over chat (cockpit#85; the fake answers a message with a board's picture with a row of marks, and `POST /fake/larry-draws` has him draw unprompted): a stroke and a pause bring one ghost, *Larry's turn* brings his two beside Claude's one with no further tap, unprompted marks replace his, a reopened board shows his newest set, a dismissed set stays gone on the next look and the next open, and words on an empty board bring a ghost and reach the Cockpit in the turn's text (stories 344, 345, 349, 357, 360, 371, 380, 382, 383, 386, 388), read from the Ghosts button's label (the ghosts showing) and the Send button's label (the strokes drawn). The turn's rules are `WhiteboardGhostTurnsTests`, on the host: Claude's fade and Larry's stay, each author's set replacing only their own, a stream's marks landing one at a time, a Cockpit that doesn't stream, Ghosts off for a stroke and for words, a stale answer, words held for the next turn, a tap keeping or dismissing (stories 351, 357, 358, 367, 370, 373; the fake's `/many` and `/plain` addresses are left for a look by hand). Ghosts staying when the Pencil touches down, a ghost tapped during a Pencil stroke, a second turn after the Pencil lifts (story 359's rules are `WhiteboardPacerTests`, on the host), undo of a kept ghost, a colour reaching another device over iCloud, and Larry's marks landing by eye on what he saw are checked on the iPad; `testAPauseBringsAGhostAndLarryTakesATurn` keeps a screenshot of Claude's and Larry's ghosts in its result (story 371), and how they sit beside real ink on the iPad is for Igor's eye. How faint the grid looks, and how it feels at 120 Hz on a big board, is too. A reading broken part way is `WhiteboardStreamTests`, on the host. Every board is on paper (the old canvas went 2026-11-07), and `WhiteboardPaperGhostsUITests` and `WhiteboardPaperLinesUITests` hold what paper shows: ghosts, a tap off one dismissing and on one keeping, undo on the sheet, ruled lines, the grid and page lines on every colour read from the screen's pixels, a colour and its lines staying with the board, and the first stroke after the Board menu (stories 434, 523, 538, 613–635, 652–657). It boots a fresh simulator once, first, and shuts it down after, because keys reach the app only in the first test after a boot that presses any: the ⌘V test fails on a simulator that has already had one. Run it in the build lane |
| `GRABBER_WHITEBOARD_AFTER_KEEP=<seconds>,undo,redo,...` | on a board on paper, those presses of undo and redo that long after a kept ghost, 3 s apart (`whiteboard` action: paper_press_hook): a phone's tool picker has no Undo, and keys reach only a run's first test. `WhiteboardPaperGhostsUITests`, run by `test-whiteboard-ui.sh`, uses it, and reads where ghosts and ink sit off the screen's pixels: a ghost that can be seen, kept where it was in its colour, a tap off it that leaves no dot, a pinch that takes the ghost with the ink (on an iPhone simulator; skipped on an iPad, where XCUITest's pinch barely moves), one undo for a mark and the pages it brought, a ghost not saved, and the same stroke ids from the fake's `GET /fake/strokes` before and after a reopen. The bar, the note and the turns are `WhiteboardTurnUITests`'. The fake's `/far` address answers with a circle past the last page. The Pencil holding a pause, a finger drag with ghosts showing, a real mic, and how a ghost looks under ink are the iPad's |
| `GRABBER_WHITEBOARD_AFTER_INK=copy,paste` | on a board on paper, a second after the first ink: *copy* selects all the ink and puts it on the clipboard in PaperKit's own format, since nothing takes the system's Copy with a selection set on the simulator; *paste* presses Paste as ⌘V would, since keys reach the app for one test per boot (`whiteboard` actions paper_copy_hook, paper_paste), and that boot's keys are `WhiteboardPasteUITests`' one test of ⌘V and ⌘Z. `WhiteboardPaperPasteUITests`, run by `test-whiteboard-ui.sh`, uses it, and checks a paste in the middle of the paper from the screen's pixels, a tall paste's pages and its one undo, the same stroke ids at the fake Cockpit after a relaunch, and that a picture stays off the board. The text's layout, its caps and the bar's note are `WhiteboardPasteTests`, on the host. The bar's paste button, a real lasso Copy followed by ⌘V, whether ⌘V of something copied in another app shows *Allow Paste?*, whether ink ever goes missing there (`paper_ink_look`), and whether the small redraw of story 650 can be felt are the iPad's |
| `GRABBER_WHITEBOARD_PAGE_AFTER_INK=<page>` | on a board on paper, a second after the first ink, the view goes to that page's top, as far as the column lets it (`whiteboard` action: paper_page_hook, with visible): a finger draws on the simulator and XCUITest has no two-finger drag. `WhiteboardPaperGhostsUITests.testThePictureIsThePageOnScreen` uses it: page 1's ink off screen leaves Send and Larry's turn disabled, and ink on page 2 goes as a picture whose frame, read back from the fake's `GET /chat/<key>`, is page 2's alone (stories 433, 522). Which pages are on screen, which are empty and the frame that covers them are `BoardPicturePagesTests`, on the host; whether the picture reads well to Larry is the iPad's |
| `GRABBER_WHITEBOARD_SAVE_FAILS=1` | every board's save fails as a full disk's would (stories 599, 612): the problem on the board, and on the list after leaving it (`WhiteboardOnPaperUITests`). The save's rules, through a disk that fills (`FullDisk`, what this hook installs), are `BoardKeepingTests`, on the host: the last good drawing kept, the list's problem staying until that board saves, a new board closed without a stroke dropped |
| `GRABBER_WHITEBOARD_GRID=on` | a board turns its grid on as it opens (`whiteboard` action: grid_on with board). The smoke opens a fixture board with it; whether the lines show is `WhiteboardPaperLinesUITests`, from the screenshot's pixels |
| `GRABBER_WHITEBOARD_KEEP=first` | the first ghost of each answer is kept as it lands, with no tap (`whiteboard` action: keep). It needs a stroke, so `WhiteboardPaperGhostsUITests` uses it for a mark kept past the last page, where no tap can reach, not the smoke |
| `GRABBER_WHITEBOARD_SAY=<words>` | a tap on the board's mic hears these words instead of the microphone, so `WhiteboardTurnUITests` can test a spoken turn on the simulator |
| `GRABBER_WHITEBOARD_GHOST_SECONDS=<n>` | Claude's ghosts fade after n seconds instead of 30: `WhiteboardPaperGhostsUITests` holds them for 600 while it looks, and a short value shows them go and Larry's stay by hand; the rule itself is `WhiteboardGhostTurnsTests`, on the host |
| `GRABBER_WHITEBOARD_PASTE=<text>` | a second after a board opens, that text lands as a paste would (`whiteboard` action: paste). XCUITest's taps never reach the system's Paste button (it never fires under them), so `WhiteboardPasteUITests` uses this and ⌘V; the button itself, whether it dims and that no prompt shows are checked on the iPad |
| `GRABBER_CHAT_HOLD=yes` / `no` / `quote` / `copy` | once the open thread is read, that choice of the press-and-hold menu taps itself on Larry's newest message (`chat` reaction, quote or copy; #629, stories 518–519, 540–541); use it with `GRABBER_CHAT_URL` and `GRABBER_LINK=grabbernative://chat?thread=igor2-88g.629`. `sim-smoke.sh`'s chat section checks it against the fake Cockpit; `ChatReactionUITests` holds the message for real. Both (and the ladder's chat step, #812) first run `scripts/native/forget-chat-thread.sh`, which removes the simulator outbox's earlier answers in that thread: the outbox keeps what it sent, a fresh fake Cockpit never heard it, and the thread would show it as newer than Larry's question (#801). A failed check keeps its session log and the fake Cockpit's report under `~/tmp/agent/notes/smoke/` (`SMOKE_EVIDENCE` names another folder) |
| `GRABBER_CHAT_LINKS=fold` / `all` | once an open thread's strip of links shows, *Links* folds it (`chat` links_folded with thread and folded; a second launch with it opens it again, since the fold is remembered) or *All links* opens its list (#736, stories 549–552); use it with `GRABBER_CHAT_URL` and a `GRABBER_LINK` to a thread that holds a link. A chip's tap leaves the app, so the phone checks that |
| `GRABBER_CHAT_IMAGE=open` | a picture in the open thread opens full size by itself (`ui` open_chat_image); use it with `GRABBER_CHAT_URL` and `GRABBER_LINK=grabbernative://chat?thread=igor2-88g.592`, the fake Cockpit's thread holding a white picture (story 306). `ChatImageUITests`, run by `test-chat-ui.sh`, checks Done's badge shows over the white and that Done and a swipe down both close it |
| `GRABBER_BOARD_FIXTURE_OLD_INK=<n>` | makes `GRABBER_BOARD_FIXTURE`'s board one drawn on the old canvas, with n strokes where that canvas put ink, about 10,000 points from its corner (story 658). `WhiteboardOnPaperUITests.testAnOldCanvasBoardOpensLookOnlyOnPaper` opens one by its link: the ink on the first page, the bar's *Drawn on the old canvas: look only*, no tools, no Board menu and no Send. The smoke reads its `paper_open` line. Which boards can be drawn on and what the bar says are `BoardIndexTests`, on the host; where the ink is moved to is `BoardPagesTests` |
| `GRABBER_BOARD_FIXTURE_FROM=<device name>` | makes `GRABBER_BOARD_FIXTURE`'s board another device's, drawn on that name, so `WhiteboardRowDeleteUITests` can delete one (story 396, #613). The delete crossing iCloud needs two real devices: the simulator has no account |
| `GRABBER_BOARD_FIXTURE=<id>` | an empty board on paper, of this device, with that id, so a chat picture's *Jump to board* has somewhere to go (story 317, #603); use it with the fake Cockpit's thread igor2-88g.603 (board-603). Its thread igor2-88g.604 names a board no device has. `ChatImageUITests` checks the jump, no button on a picture with no board, and the problem on a missing one. A board that comes down from iCloud on the jump needs a real device signed in |
| `GRABBER_CHAT_URL=http://localhost:<port>` | Chat (and the Inbox's sending) talks to that Cockpit instead of the tailnet's: `scripts/native/fake-cockpit.py <port> <report>` stands in for the chat routes, with one thread to talk in, one holding a white picture, one Larry marks as looking done, a pinned one with no messages that refuses an archive, and a Larry who answers each message a second later. It has no skill thread until a test asks with `POST /fake/skill-thread` (#632), because an extra row moves the list under the archive tests. Without it a simulator reaches no Cockpit for chat, the Inbox or a board's turn, as with the archive (#525): what waits stays waiting, and the log's `chat` no_address and `inbox` no_address say so. A Mac build named `https://no-address.invalid` behaves the same way. On a Mac build it also names a call's Cockpit. A phone, an iPad or a Mac build with no address uses the real Cockpit, so on a Mac a `GRABBER_CHAT_SEND` with no address reaches Larry. The share card, which gets no hooks, never has an address on a simulator |
| `GRABBER_CHAT_SEND=<thread>\|<text>` | that text written in that thread as the compose bar would (`new\|<text>` starts a thread), then sent; use it only with `GRABBER_CHAT_URL`, or on a simulator to see the message held (#525). That it stays waiting with no address and that a later launch naming one delivers it once are host tests (`InboxOutboxTests`, `ChatCockpitTests`); `sim-smoke.sh`'s chat section checks only the launch's and the list's no-address lines. With `GRABBER_LINK=grabbernative://chat?thread=<key>` the thread is on screen |
| `GRABBER_CHAT_SEND_FILE=<thread>\|<path>` | that file attached and sent as the bar's paperclip would (`new\|<path>` starts a thread; stories 480, 487, the picker itself is a phone check); use it only with `GRABBER_CHAT_URL`. The fake Cockpit refuses a non-picture as the real one does today. The refusal, with no message after it, is a host test (`InboxOutboxTests`, `ChatFileTests`); the smoke no longer runs it |
| `GRABBER_CHAT_SEND_AGAIN=1` | every refused file on the phone sent again, as a tap on its *Send again* would (story 489); use it only with `GRABBER_CHAT_URL`. That the kept file uploads a second time, is refused again and that still no message follows is a host test (`InboxOutboxTests`); the smoke no longer runs it |
| `GRABBER_ARCHIVE=run` / `GRABBER_ARCHIVE_URL=<url>` | run the stats archive now (story 270), as a background refresh would, sending to that URL. On a simulator or Mac build the URL is required and nothing is sent without it (both reach the tailnet, and a simulator's fixture week and imported trail must never land in the real archive); the run itself (an unreachable Cockpit failing the trail's first page and stopping the run, a locked run recording nothing, a cancel keeping cursors, when the next run is due) is `ArchiveTests` on the host, so `just native-test-sim` no longer runs it |
| `GRABBER_LINK=<url>` | route that link as if iOS had opened it (`simctl openurl` stops at an "Open in Grabber Native?" confirmation a script cannot tap): `grabbernative://timer?preset=10,10,2`, `grabbernative://breathe?breath=5&minutes=2`; the log's `open_url` says how it was read. `LinksUITests` opens real links through iOS instead, cold and warm |
| `GRABBER_DRILL=card_to_position\|position_to_card\|mixed` | open the card screen (`ui` open_card, from: hook) and the trainer's drill over it in that direction, as a tap on *Drill the stack* would (story 220); `just native-test-sim` runs `mixed` and reads the library's `drill` how: open |
| `GRABBER_COCKPIT=open` | open the Cockpit screen, as its row on the home screen would |
| `GRABBER_COCKPIT_URL=<url or page>` | load the Cockpit from elsewhere: a URL (`https://127.0.0.1:65530/` is the unreachable case `just native-test-sim` checks for the error panel), or the name of a page in the app bundle — `cockpit-bridge-test` speaks the audio bridge the way the Cockpit does and reports the round trip as `getRoute("roundtrip:<microphones>:tagged")`. A Mac build without it loads the real Cockpit; named `https://no-address.invalid`, it loads nothing and shows the error panel, saying so |

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
| A workout surviving *Done*: the rounds and the stopwatch still running when the timer's link brings it back, the mode kept; a breathing link pausing it (story 188, #791) | Simulator | `GymTimerUITests` (`testAWorkoutSurvivesLeavingTheTimer`), `LinksUITests` (the timer found paused, RESUME) |
| Which voice counts: the default, the remembered choice, every voice having all six files | Host, then simulator | `CountVoiceTests` (the files on disk); the `voice:` checks in `sim-smoke.sh` (`voice: adam` by default, the hook's `aussie`) |
| Timer settings: the gear, the three rows and the checkmark | Simulator screenshot | `SIMCTL_CHILD_GRABBER_TIMER_SETTINGS=1 xcrun simctl launch …`, then `simctl io screenshot` |
| Hearing each voice, the sample on a tap, a change taking effect mid-workout | Phone only | choose each voice in the sheet, start 30 SEC, `just pull-logs`, read `ui` count_voice / `timer_voice_sample` / `timer_cue` voice |
| The face, upright and turned | Simulator screenshot | `SIMCTL_CHILD_GRABBER_TIMER=10,10,2 SIMCTL_CHILD_GRABBER_TURN=left xcrun simctl launch …`, then `simctl io screenshot` |
| Music dipping and coming back, a podcast pausing and resuming, cues with the phone locked or the timer left running (*Done* mid-workout), the real turn, the screen staying lit | Phone only | run a workout with music, lock for a round, `just pull-logs`, read `timer_session` / `timer_duck` / `timer_cue` / `timer_interruption` |
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
| A metric's detail filling a wide window, dragged away on an iPhone, a report opening over it (stories 441, 442) | Simulator, an iPad and an iPhone | `MetricDetailUITests` on each; a narrow Split View, resizing with a detail open (stories 443, 444) and a real shake are the iPad's |
| Igor's own Health: the cards equal the current app's Body tab; sources, preferred units; Health's access sheet | Phone only | grab in both apps, compare; `just pull-logs`, read `mirror_grabbed`, `health_query_failed` |

A new behaviour that only a tap can reach gets a hook and a log event in the same change; a check without an event
to wait on is not a check. `GrabberNative.xcodeproj` is generated from `native/project.yml` by XcodeGen
(`just native-project`, run by the build recipes) and is not committed.

Analysis bugs (a wrong stay, a place that did not match, a sleep total that is off) are reproduced on the host first:
put the data in a fixture or a test, make it fail, fix, then ship. Never tune by reinstalling. The real-data fixtures
are `__tests__/fixtures/locations.json` (36K real points), `context-grabber.db` (a real export with 4 known places;
`sqlite3` opens it on the Mac) and `heart-rate-2d.json`; a geometry threshold is checked against them before it ships
(the place-merge gate moved 50 m → 500 m because the tight gate caught 0/10 unmatched stays).

## A worktree that keeps its build

Every recipe builds into the worktree's own `native/Build` (about 500 MB each), and each new worktree left one
behind: 24 GB across worktrees on 2026-11-09 (#803). The fix is to stop making new worktrees. The win is mainly
bounded disk and the seeded device ids; speed gains are modest. Measured on this Mac with Xcode's machine-wide caches
warm: a first build in a new slot took 39 s, a rebuild 6 s, and a returned slot re-leased for a new branch with one
file touched 7 s. [treehouse](https://github.com/kunchenguid/treehouse)
keeps a pool of four (`treehouse.toml`) under `~/.treehouse/`, and a slot is leased, returned and leased again:

```bash
slot=$(treehouse get --lease -b native/123-my-change)   # prints the slot's path; the branch is cut from origin/main
cd "$slot" && just native-test-sim                      # work, build, commit and push from here
treehouse return "$slot"                                # when the branch is pushed; the branch itself is kept
```

- **The build is reused.** Returning a slot resets tracked files to main and removes untracked ones, but not ignored
  ones (`git clean -fd`, no `-x`), so `native/Build`, its Swift packages and the generated project are still there
  for the next lease, at the same path. Only files that differ between the two commits are rewritten, so Xcode
  recompiles what changed.
- **The device ids come along.** `.worktreeinclude` copies `scripts/native/phone-udid.local` and `ipad-udid.local`
  from the main checkout into the slot on each lease, and a return removes them.
- **A return discards uncommitted work** and stops what is still running in the slot. It asks first; `--force`
  doesn't. Commit and push before returning. A leased slot is never handed to anyone else and never pruned.
- **A full pool is an error, not a fifth worktree.** `treehouse status` shows who holds what; return one.
- **Disk is bounded at four build folders.** For a slot's build alone, delete its `native/Build` (the next build
  there is cold; also the cure for a build that fails only in one slot). `treehouse prune` lists every idle returned
  slot and `--yes` deletes them, warm builds included, so it is for reclaiming disk, not for tidying.
- **Slots share nothing.** Each has its own Swift package checkouts: one shared folder
  (`-clonedSourcePackagesDirPath`) would let a branch that moves a pin switch the checkout under another slot's
  running build, and a device build takes no `build.lock` to keep the two apart. A slot fetches them once.

## The phone

`just native-run-device` builds, installs and launches; `just pull-logs` brings back the session logs, reports and
crashes. What only the phone can show: HealthKit and CoreLocation (and CoreLocation's silence while the phone is
still), the audio session — the Gym Timer's ducking window, a podcast resuming, echo cancellation on a call, the
keepalive with the screen locked — the Live Activity and the widgets, Shortcuts and Siri, the Cockpit page over the
tailnet, and everything visual on an OLED.

**Log before theorizing.** When a phone symptom is unexplained, the first change is a log line, not a fix. Every
session log and report carries the build it came from. [DEBUGGING.md](DEBUGGING.md) says what each holds and how to
get it.
