# Test architecture

The rule: every question is answered on the cheapest rung that can answer it, and a change is not "done" until the
rung that can see it has seen it. Say which rung you used. The rungs are ordered by cost, and the split follows the
code: `native/ContextCore` is platform-free and runs on the host; only what genuinely needs the app, HealthKit, GPS,
an audio session, a widget or the voice bridge goes higher. (The React Native app this replaced, and its jest and
Maestro rungs, were removed 2026-10-17; [design spec](superpowers/specs/2026-10-04-swift-native-app-design.md).)

| Rung | What runs | Command | Time | Answers |
|---|---|---|---|---|
| 0 Lint | swift-format's lint over the Swift files the branch touched, then SwiftLint over the tree (no force unwrap, cast or try, no implicitly unwrapped optional, unless a `swiftlint:disable:next` line gives the reason) | `just native-lint-touched` (`just native-format` fixes the layout) | ~2 s | the layout (`native/.swift-format`) of what changed; a new `!` or `try!` |
| 1L Linux | off the Mac, the first rung: `ContextCore`'s XCTest under Linux Swift; the package and its tests cross-built for macOS, iOS and the simulator; the app's own sources (App and Shared, the widgets, the share extension, the UI tests) compiled for iOS against the real BugKit and ThinkACard pins; the [portable script checks](#off-the-mac-just-test-linux) | `just test-linux` | tests ~10 s once built; ~4 min with the cross-builds | the package's portable logic and script checks, plus type, concurrency and API errors in the app code it compiles. No app is linked, signed or launched, and Catalyst-only code isn't compiled |
| 1 Host | `ContextCore` XCTest (`native/ContextCore`, the platform-free package), then the script checks, one line each in [The host rung's script checks](#the-host-rungs-script-checks). `just board-test [Class]` builds and runs the board's bundle alone, a few seconds an edit (Mac only). `just native-test`, or `just test`, is rungs 0 and 1 with swift-format over the whole tree: what the gate runs | `just native-test-host` | ~25 s once built | everything pure: what a log line can carry, log retention; each ported module's logic |
| 1.5 Mac | the Catalyst build, ad hoc; once open, driven by the same launch hooks (`open --env`), judged from the session log in its sandbox folder; `GRABBER_BUG=<note>` saves a report whose picture is the screen. It reaches Igor's real Cockpit unless named, so a test launch must name the stand-in or nowhere (`https://no-address.invalid`) on every route: `COCKPIT=` sets all three, and a hook-driven `open --env` launch sets `GRABBER_CHAT_URL`, `GRABBER_COCKPIT_URL` and `GRABBER_USAGE_URL` itself. Naming only the chat address leaves the page and the usage strip on the real Cockpit. A launch named anywhere but the real Cockpit has its own outbox (`Inbox-test`, beside `Inbox`), so what it leaves waiting stays among test launches | `just native-build-mac`; `just native-run-mac` opens it, `COCKPIT=<url>` to name a Cockpit | ~5 min | code under `#if targetEnvironment(macCatalyst)`, which the host cannot compile; with `native-run-mac`, it opens and every screen comes up. What a mouse can draw, what iCloud does and the keys (Enter sends, #683) on a Mac still take a person: `MacKeysUITests` presses them but waits for a signed run, as the ad hoc test runner refuses to load it |
| 2 Simulator | the build with its UI tests; the UI test classes the change touches; `just native-test-sim`'s smoke, the app driven by launch hooks and judged from its session log; the areas' whole suites (`scripts/native/test-chat-ui.sh`, `test-whiteboard-ui.sh`) | `just test-ladder` for the build, the touched classes and then the smoke's touched sections on the same build and boot (story 755; `LADDER_SMOKE=0` leaves the smoke out), `--full` for the suites; `just native-test-sim` for the smoke alone | build ~5 min; a class ~30 s a test; smoke ~1 min; the whiteboard's suite ~18 min on one boot (an estimate from the 7 Nov per-class times, until the Mac times it; ~28 min with two boots before) | a real view, gesture or system service: it installs and launches, the log's first line names the build, a report is stored with its screenshot, no `error` event; the timer's and breathing's cues and Live Activity events, the card's deal and count |
| 3 Phone | Grabber Native on the iPhone | `just native-run-device`, then `just pull-logs` | minutes + a person | the shake, and everything the phone-only rows below list |

## The host rung's script checks

What the host rung runs after `ContextCore`'s XCTest, in the order `just native-test-host` runs them. A new check is a
line of its own here and in the recipe; `scripts/native/test-testing-lists.sh` fails when the two disagree (story 1502).

- `scripts/native/test-signing-guard.sh`: the device build's signing path with fakes (BugKit's screen-lock guard and "No Accounts", bug-kit#53)
- `scripts/native/test-breath-clips.py`: the breathing clips, each ending in silence, not on a click (#279)
- `scripts/native/test-tile-art.sh`: the asset catalog compiled with actool with every home tile's art present and square (#304, #299)
- `scripts/native/test-ladder-map.sh`: the ladder's own map, which rungs and UI test classes a change gets, from the real script's dry run (story 683)
- `scripts/native/test-build-lane.sh`: the build lanes, their locks and simulators, sim-boot and the xcodebuild wait per lane (story 785, #954)
- `scripts/native/test-time-limit.sh`: the repo's own rung time limit, a hang and everything it started stopped (exit 124), a finished command's status kept, the lane count past it unchanged (stories 1505, 1506)
- `scripts/native/test-sim-lane.sh` checks simulator lane selection and refusals, including UUID case and the default lane for Health access and smoke (stories 1516, 1517 and 1518, bead context-grabber-w7nl).
- `scripts/native/test-host-lane.sh`: the host slots, six jobs on four, the wait, a killed holder (stories 795, 797, 798)
- `scripts/native/test-lane-env.sh`: the build, simulator and host lane self-tests pass with a caller's `SIM` and lane settings set (story 785, context-grabber-2l07)
- `scripts/native/test-release-check.sh`: `just pre-merge`'s Release build of ContextCore runs when the branch as pushed changes it, skips otherwise, a failing build ends in a FAIL line and exit 1, and a checkout behind the pushed branch fails without building (story 1519, context-grabber-6ocd). The Release build itself only runs in pre-merge: about 25 s to a minute in a slot, two minutes cold
- `scripts/native/test-wasm-essentials-check.sh` (testing `wasm-essentials-check.sh`, which `just test` also runs): the board wasm's own sources use no Foundation-only types such as `NSNumber`, which FoundationEssentials lacks; read JSON numbers with BoardCore's `JSONNumber`. Such a type builds on the Mac and only breaks the wasm build on Larry's VM, where the wasm is built and tested (2026-11-24, `bw_store_clash`)
- `scripts/native/test-ui-timings.sh`: the UI test timing digest against a real run's log
- `scripts/native/test-device-build-check.sh`: the build each device last reported against the last install in the deploys ledger (match, mismatch, no session yet, over the air, unknown), and `just deploy` recording each installed device and checking its next session, with fakes (story 1511)
- `scripts/native/test-pen-latency.sh`: the board's Pencil-to-frame latency lines read off fake pulled logs, oldest session first (story 1311)
- `scripts/native/test-render-preview.sh`: `render-preview.sh` names a file as Xcode's project does, asks for the iPad, and refuses a missing file, from its dry run (story 1625)
- `scripts/native/test-ladder-report.sh`: the ladder report keeping a retry, a wrong-device skip and a missing deploy apart, on a fixture (#1038, story 1016)
- `scripts/native/test-xcodebuild-log.sh`: the UI test run wrapper's time limit, retry, flake gate and quarantine (story 1017, after a hang too), hang stop (which waits for the result bundle to be written, story 790) start watchdog, a failure after the screen locked (story 1018), and on a locked screen the skip of the tests that open the mic and the mid-run stop while one is still to run (stories 1022, 1023, bead context-grabber-wm8y) against a fake xcodebuild
- `scripts/native/test-own-child.sh`: the wrapper stops a watchdog at the end of a run only while it is still the wrapper's own child, so a number a watchdog left long ago, since given to another process on a busy Mac, isn't killed (bead context-grabber-tne1)
- `scripts/native/test-smoke-lock.sh`: the smoke's audio checks skipped, and said to be, on a locked Mac (story 827, #419)
- `scripts/native/test-mic-tests.sh`: every UI test that touches a mic control or a call is listed in `scripts/native/mic-tests.txt`, as one that opens the mic (skipped on a locked Mac) or one reviewed as not, and a listed test still exists (bead context-grabber-wm8y)
- `scripts/native/test-fake-cockpit-ops.py`: the fake Cockpit's board ops, which the whiteboard UI tests rely on (stories 814–818)
- `scripts/native/test-board-sessions.py`: the Cockpit's recorded board sessions, vendored scrubbed (stories 1173, 1174)
- `scripts/native/test-fake-cockpit-session.py`: the fake Cockpit playing those sessions back (stories 1173, 1174)
- `scripts/native/test-testflight.sh`: what `just testflight` refuses before it builds, from its dry run (stories 1012, 1013)
- `scripts/native/test-ota.sh`: `just ota`'s arguments and dry run; ota-watch's batch rule and post (stories 1027–1029)
- `scripts/native/test-linux-imports.sh`: Apple-only imports checked against Linux branches, including `#if canImport` and `#if os` (#943, bead context-grabber-cmk)
- `scripts/native/test-story-ids.sh`: that every user story's ID is used once and sits in its journey's ranges (story 789), with the reserve command against a fake gh and main and a bare repository as the shared ledger's remote, two checkouts standing in for two machines, the pre-merge check on a throwaway repository (stories 791–794), and the pipeline's claim check, which fails a branch adding a story ID another open PR adds unless that PR is the branch's own (story 1515; the gate's lint step runs it as `just pipeline-lint`)
- `scripts/native/test-story-commits.sh`: checks links to Context Grabber commits in the stories against the checkout's history and reports each missing hash with its file and line (beads context-grabber-t309, context-grabber-lldg). If a shallow checkout can't verify a link, it fails and asks you to run `git fetch --unshallow` and rerun the check.
- `scripts/native/test-story-tests.sh`: checks that every test a story's Status line names (a test class, `Class.testMethod` or a bare `testMethod`) still exists under native/, and names each one that is gone with its file and line (story 1624). A test in another repo is written with the repo first, `bug-kit:WhatsNewTests`, and is not looked for.
- `scripts/native/test-board-tests-listed.sh`: that every board test file is in the board's own bundle or listed as staying in ContextCore's
- `scripts/native/test-testing-lists.sh`: that this list, the chat suite's and the whiteboard suite's below each name, one line apiece, exactly what their scripts run, the UI classes in name order (story 1502)


## Off the Mac: `just test-linux`

Rung 1L. On a Linux box, with no Xcode, `just test-linux` is the first rung to climb, and an agent with no Mac climbs
it before every push. In order, it:

1. runs `ContextCore`'s XCTests under Linux Swift (all but the few that need an Apple framework, below), then builds
   the board-ops harness and replays the Judge batch to an SVG (#943);
2. cross-builds the package and its tests for arm64 macOS, iOS and the iOS simulator with a Darwin Swift SDK (xtool's):
   compiled, never run;
3. compiles the app's own sources for iOS with that SDK: App and Shared, the widgets, the share extension and the UI
   tests, each Xcode target as a SwiftPM target in a generated package that takes the BugKit and ThinkACard pins from
   `native/project.yml`. Fetching those packages needs the network; without it, or without the SDK, the step says it
   was skipped. Nothing is linked into an app, signed or launched, and code under
   `#if targetEnvironment(macCatalyst)` isn't compiled (the Mac rung does);
4. runs the host rung's portable script checks (each described in the host list above): the ladder's map
   (`test-ladder-map.sh`), the breath clips and the UI timing digest, the ladder report (`test-ladder-report.sh`), the
   smoke on a locked Mac (`test-smoke-lock.sh`), the Linux import check (`test-linux-imports.sh`), the build lanes
   (`test-build-lane.sh`), the story IDs (`test-story-ids.sh`), the stories' commit links (`test-story-commits.sh`), the tests
   their Status lines cite (`test-story-tests.sh`), the vendored board sessions (`test-board-sessions.py`), and this guide's one-a-line lists (`test-testing-lists.sh`). The asset
   catalog check needs `actool` and the signing guard needs BugKit's script, so they stay the Mac's.

The Mac host rung also runs `test-linux-imports.sh`, so it can catch an import problem before a Linux build. The check
requires files using URL loading to import `FoundationNetworking` on Linux (#943). It also flags Apple-only framework
imports in the package's sources and tests unless their branches exclude Linux, such as with `#if canImport(CoreGraphics)`
or `#if os(macOS)` (bead `context-grabber-cmk`).

It prints each step's count or result. It needs a Swift 6 Linux toolchain and SQLite (`libsqlite3-dev`, found through
`pkg-config sqlite3`); the
script's header lists the settings for a toolchain that is not on `PATH`. The Mac's rung 1 still decides: Linux runs
the same tests on another Foundation, and only the Mac's `just native-test` (with SwiftLint, which isn't on Linux, and
the Mac's own swift-format) and its build say the app is right.

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
| Any Swift change, from a box with no Mac | Linux (1L) first, then the Mac's rungs | `just test-linux`; the PR says what still needs the Mac (SwiftLint, the Xcode build, the simulator) |
| Pure logic in `ContextCore`, a rule that needs no screen | Host | an XCTest in `native/ContextCore/Tests`; a new `Board*`, `Whiteboard*` or `Paper*` file is listed in `Package.swift`'s `boardTests` (or `boardTestsInContextCore` if it needs the rest of ContextCore) |
| A script check, the ladder's map | Host | `scripts/native/test-*`, run by `just native-test-host` |
| Mac-only code, or anything else that goes into the Mac build | Mac | `just native-build-mac`; a host test can't compile it, and neither can a simulator build |
| A batch of Larry's board changes: what it will do to a board | Host, on the Mac | `just board-ops` (below); the rules are `BoardOpsTests` and `BoardReplayTests` |
| A UI test | Simulator | that class: `just test-ladder` |
| What PaperKit or PencilKit does that the whiteboard relies on, an Xcode or iOS update | Simulator | `just native-test-contracts` (below) |
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

A run of UI tests keeps its result bundle beside its log, named for the run (`native/Build/logs/<name>.xcresult`, the
last run of that name replacing it), and a failed run names it: the screenshots and view trees its failed tests kept
are there, `xcrun xcresulttool get test-results summary --path <bundle>` for the results, and `xcrun xcresulttool
export attachments --path <bundle> --output-path <dir>` for the pictures. When xcodebuild sits quiet after the last
suite closes, the run waits for it to finish writing the bundle (up to 120 s, `XCODEBUILD_BUNDLE_SECONDS`) before it
stops xcodebuild; stopped sooner, the bundle can't be opened (story 790). A simulator run in which any try failed
also keeps the session logs the app wrote during the run, in `native/Build/logs/<name>.session-logs/`, and names the
folder: the next run's install clears the app's container, and with it the board's own account of what went wrong
(story 1514).

Which classes a change gets, from an explicit map that `scripts/native/test-ladder-map.sh` checks against the real
script's dry run:

| Changed | UI test classes |
|---|---|
| A test file | the classes it declares, and any that inherit them; `IPadUITests` (story 150), which skips on a phone, runs on the iPad's simulator (the whiteboard's), here and under `--all`, in a run of its own after the whiteboard's classes; a test of it that skips there fails the step, as a skip on the iPad can only be the wrong destination, and the step prints how many passed and skipped (#1037, story 1015) |
| Chat or the Inbox, in the app or `ContextCore`; the chat suite's script; the fake bridge | chat's |
| The whiteboard, in the app or `ContextCore`; the whiteboard suite's script | a rule in `ContextCore` runs only the classes that show it (paste, lines and pages, the board list, the turn and ghosts — the picture's frame, Larry's clock and the note among them; stories 753, 756), Larry's question cards, in the app or `ContextCore`, run `WhiteboardQuestionUITests`; the app's board fixture hook runs `WhiteboardRowDeleteUITests` and chat's `ChatImageUITests`, the two that launch with a fixture board (story 784); the board's views, its hooks in `ContextCore` and the suite's script run every class: the whiteboard's, on an iPad simulator (`WHITEBOARD_SIM`, default *iPad Pro 11-inch (M5)*; the iPhone's is shut first, and the iPad's stays up for the next climb). An iPhone only looks at boards (story 746): that is the smoke's whiteboard section on the iPhone, from the session log (no New board, its own board look-only with the bar's reason), so no class runs on the iPhone and there's no second test session (story 770) |
| The fake Cockpit | chat's and the whiteboard's |
| A file that drives PaperKit (one that imports it: the board's canvas and whatever it is split into, the reword and to-text flows, the scratch-out, the shape snapping), the tool the board reads, its ink kinds and its board files; the contract tests themselves, their stage and its hook | the contract tests (`GrabberNativeContractTests` and `PaperKitTouchContractUITests`, story 1021) on the iPad's simulator, in a step of their own after the whiteboard's and the iPad's classes, with no retry; beside the classes the file has of its own. The contracts' own files run them alone, with no whiteboard class and no smoke |
| The replay of Larry's board changes on a copy of a board (`BoardReplay.swift`), and the board-ops harness | none, and no smoke section and no simulator build (#1036, story 1014): the app never runs the replay, so no screen can show it. The host rung's replay fixtures (`BoardReplayTests`, `BoardMarksReplayTests`, `WhiteboardWordsOnlyTests`) hold it, and the Mac build still compiles the replay, as the app links the package. The planner and applier it calls (`BoardOps*.swift`, `BoardOpApplier.swift`) are the canvas's too and run every whiteboard class; a change to both the replay and the canvas gets the union. The route holds while the app never calls the replay: once it does, the replay goes back to the whiteboard's every-class row |
| The Gym Timer, in the app or `ContextCore` | `GymTimerDialsUITests`, `GymTimerUITests` |
| Breathing, in the app or `ContextCore` | `BreathePresetsUITests`, `BreatheStyleUITests`; when a session is saved to Health is `BreathSessionTests`, on the host |
| Places, in the app or `ContextCore` | `PlaceIconUITests`, `PlacesUnnamedUITests`, in a run of their own: the ladder first installs the build, copies the real export to the app's `Documents/import-fixture.db` and launches the app once to import it, failing the rung if the import's event doesn't come |
| The mirror (Today, a metric's detail), in the app or `ContextCore` | `HomeTodayCardUITests`, `MetricDetailUITests`; the Health source's file, `BreatheMindfulUITests` too: its 60 s session is the one check that a sample reaches Health (story 770). `AppModel.swift`'s save stays unmapped, as that file is in a fifth of changes |
| The card, in the app or `ContextCore` | `CardUITests`, `TodaysHandUITests`; the role of the day's file, `TodaysHandUITests` alone |
| The Cockpit, in the app or `ContextCore` | `CockpitBackUITests`: Back, Cockpit and Done, then the page's ☎ in the same launch (#905) |
| The usage strip's files (`Usage*`, `CockpitUsage.swift`), in the app or `ContextCore` | `UsageTileUITests`, which needs the real Cockpit reachable from this Mac: a Cockpit change off the tailnet doesn't run it |
| The daily strip, in the app or `ContextCore` | `DailyStripUITests` |
| The eulogy, or the song's player or the blog's links in `ContextCore` | `EulogyUITests` |
| The links, in the app or `ContextCore` | `LinksUITests` |
| The supermix link in `ContextCore` | `WorkoutSupermixUITests` |
| A held tile's choices in `ContextCore` | `HoldPopoverUITests` |
| Words, host tests, the home tiles' art, other scripts | none |
| Any other app code (a call, the archive, the Live Activity, an iPad's windows, the files at the app's top level); a helper the UI tests share | none, and the output names the path and `--all`, which runs every UI test class |

A feature's row is its directory under `native/App` and the one of the same name under `ContextCore`'s sources (#795).
A class is in the map only if it runs on the ladder's simulator and opens that feature, and the map's check fails when a
class it names is gone. A file whose feature isn't its directory's has a row of its own. The windows have no row, nor
their ledger in `ContextCore`: `IPadUITests` opens the home screen's launchers, not a second window, and `MacKeysUITests`
exists only in the Mac build.
`HealthAccessUITests` stays the smoke's.

**One running app per class** (story 672). A launch costs 5-9 s a test. A class whose tests start on the same screen
gets its app from `SharedApp.open(environment, for: self) { app in … }`: the first test launches, and each later one
gets the running app back through the closure, the class's own way back to where its launch hook lands (a Back tap).
Not a link home: XCTest then waits for the app to idle, 33 s on the chat list. A failed test, another class or another
environment launches fresh. `ChatArchiveUITests` went from 56-70 s to 26 s.

A whiteboard class list is the suite less its fake-Cockpit report checks, so a change to the whiteboard's app code
costs about the suite's time; a change to one test file costs that file. `--full` runs the whole suite of each area the
change touched, in place of that area's classes.

The Mac and simulator rungs run in build lanes, one job per lane (story 785, #954). The lane count is `BUILD_LANES`,
else one per 12 GB of memory (`sysctl -n hw.memsize`), at most four and at least one: four on the 48 GB M5 Pro, one on a
16 GB Mac. `scripts/native/build-lane.sh run <command…>` takes the first free lane's lock, waiting only while every lane
is busy (up to an hour, then exit 75), and exports `BUILD_LANE` (its number) and `BUILD_LANES` to the job. Lane 1's lock
is `~/tmp/agent/locks/build.lock`, the one every older checkout takes, so those still exclude lane 1; lane N's is
`build-N.lock`. With one lane it is exactly `lockf -k -t 3600 ~/tmp/agent/locks/build.lock`, as before lanes. Inside
the lock come the wait for other xcodebuilds (below), then the time limit and `caffeinate -i` (the simulator rung
`caffeinate -d -i`, story 782), so the time limit counts only the rung's own run. The time limit is the repo's own
`scripts/native/time-limit.sh <minutes> <command…>` (stories 1505–1507, bead context-grabber-xmwp): past its minutes it stops
the command and everything it started (TERM, then KILL 5 s later) and exits 124, so a hang frees the lane; it needs no
`~/gits/mac-driver`. `LADDER_TIME_LIMIT` names another (mac-driver's `bin/time-limit` takes the same arguments). One that
can't be found stops the rung with exit 2 and says so, rather than running with no limit. mac-driver's is a zsh script
and zsh reads `~/.zshenv`, so the ladder passes the lane's `BUILD_LANES` past the time limit again rather than trust
what arrives.

**Simulator lane ownership.** `sim-boot.sh` checks its boot target, and `xcodebuild-log.sh` checks the iOS Simulator
destination named for a `test` or `test-without-building` run. Both accept a name or a case-insensitive UUID. The guard
refuses with exit 64 and explains how to proceed when a command targets a lane's simulator from outside its owning
lane. Builds and targets with no owner pass the guard. Device names of the form `<model> lane N` belong to lane N.
Lane 1 owns the configured and default model names listed below.

`sim-smoke.sh`, `test-chat-ui.sh` and `test-whiteboard-ui.sh` take the first free lane when started directly.
Pass the model name or a lane simulator's UUID to select that model in the acquired lane. To apply a time limit
and prevent idle sleep during the run itself, take the lane first, as in
`scripts/native/build-lane.sh run scripts/native/time-limit.sh 30 caffeinate -i scripts/native/test-chat-ui.sh "iPhone 17"`.

**Health access for the simulator smoke.** From outside a lane, `just native-sim-health` and `just native-test-sim`
both take lane 1 before starting work. From inside a lane, both use the current lane. Use the same `SIM` model
for the grant and the smoke. The smoke reports a HealthKit skip if the fixture-completion event never arrives.
The copy and refresh commands below explain how to carry lane 1's grant to other lanes.

**Host builds and tests take a host slot** (stories 795, 797, 798; bead context-grabber-mkd0). Twenty agents' `just
test` at once loaded the 18-core Mac to 281 (2026-11-22), and lanes only cover Xcode. So swift-format and SwiftLint
(`just native-lint-format`, `just native-lint`, rung 0), ContextCore's `swift test` (`just native-test-host`, so
`just test`, `just native-test` and the no-mistakes test step) and the Mac Catalyst build (`just native-build-mac`)
each run in `scripts/native/host-lane.sh run <command…>`: one of `HOST_LANES` slots machine-wide, else a quarter of the
cores, at most four and at least one (four on the M5 Pro). Slot N's lock is `~/tmp/agent/locks/host-N.lock`. While
every slot is busy it says once that it is waiting for a host slot, polls, and after `HOST_LANE_WAIT` seconds (an hour)
exits 75 having run nothing; the job gets `HOST_LANE` and `HOST_LANES`. The locks are lockf's, so a holder that dies,
even by `kill -9`, frees its slot at once and a lock file left behind holds nothing (a killed `lockf` leaves its
command running unseen by the slots, as a killed build lane's does). The slot is taken around one command at a time,
never inside another slot, since a holder waiting for a second slot can deadlock; a build lane may take one inside
it (the Mac rung's build does), never the reverse, and a slot wait inside the Mac rung counts in its time limit. The
`swift` binary itself is not wrapped: a raw `swift test` takes no slot, so run a host test by hand as
`../../scripts/native/host-lane.sh run swift test --filter <Tests>` from `native/ContextCore`. `test-linux` takes no slot
(Linux has no `lockf`, and it runs only there). `scripts/native/test-host-lane.sh` checks it with real locks in a
temporary folder: six jobs on four slots, never more than four at once, the waiting line, the hour's exit 75, and a
killed holder.

**Each lane has its own simulators.** Lane 1's are the named ones (`SIM`, default *iPhone 17*, and `WHITEBOARD_SIM`,
default *iPad Pro 11-inch (M5)*), as on a one-lane Mac. Lane N's are *iPhone 17 lane N* and *iPad Pro 11-inch (M5) lane
N*: `scripts/native/sim-udid.sh` resolves a name to the job's lane's device, and the first time a lane needs one it is
cloned (`simctl clone`) from lane 1's while holding lane 1's lock, lane 1's shut down for it, so the copy keeps the
Health grant and the seeded data. If lane 1 stays busy for ten minutes (`BUILD_LANE_CLONE_WAIT`), the lane gets a fresh
simulator of the same model and runtime instead, and says it needs `BUILD_LANE=<n> just native-sim-health` once.
`just native-sim-lanes` makes every lane's copies ahead of time, waiting for lane 1 up to an hour. It never replaces a copy that exists, so after lane 1 gains something (`just native-sim-health`, seeded data) run `just native-sim-lanes refresh` (stories 786, 787): lane by lane, holding that lane's lock and then lane 1's, it deletes the lane's copies and copies lane 1's again; a busy lane, or a busy lane 1, is skipped and named, never given a blank simulator, and the exit is 75 (`BUILD_LANE_REFRESH_WAIT` seconds to wait for a lock, none by default); a lane whose copy fails is named, the rest are still tried, and the exit is that failure's. `just native-sim-lanes list` (story 788) prints each lane's copies with their ids and states, or *missing*, and changes nothing. The fake Cockpit's
and bridge's default ports move up by ten per lane (`BUILD_LANE_PORT_OFFSET`), so lanes never collide on a port.

**One booted simulator per lane, left booted between runs; switched only when the device changes** (stories 980–983,
985). Every script that needs a simulator goes through `scripts/native/sim-boot.sh <name|udid>`. On a one-lane Mac it
shuts down any *other* booted simulator (one takes about 10 GB of a 16 GB Mac), as before. With more lanes it shuts
down the lane's other device and any simulator that belongs to no lane (counted as lane 1's), never one whose lane's
lock another job holds, and an idle lane's only to keep the booted count at or under the lane count. It boots its own only if it isn't up
(`simctl bootstatus -b`). Nothing shuts it down when it ends, pass or fail: each iOS 27 boot writes about 300 MB of wallpaper snapshots
(`PRBPosterExtensionDataStore`) that are never evicted, and spikes the CPU. On 2026-11-14 that was 31 boots, and on
2026-11-17 the snapshots filled the disk. The rung's iPhone steps (chat, places, the other classes, the smoke, the chat
suite) and its iPad steps (the whiteboard's classes and suite, then the iPad's own classes) run as two groups, the device already booted first, so a
climb switches device at most once. Until story 982 finds why keys reach the app only in the first test after a boot,
the iPad is still fresh-booted when `WhiteboardPasteUITests` runs, and only then. The one exception is a hot Mac: when macOS records a thermal or performance warning
(`pmset -g therm`; not the load, which here counts hung processes), the rung shuts its simulator down at the end and says so (story
983). The wallpaper snapshots of every shut-down simulator are deleted before a boot and again when the rung, the
whiteboard suite or the smoke ends (`scripts/native/sim-poster-prune.sh`, stories 984 and 987), whatever the free disk: a booted
simulator's are never touched (each device's state is read again just before its delete; story 988), PosterBoard rebuilds about
300 MB on the next boot, one line names the simulators and the MB freed, and a failed prune never fails the run (story 989). Don't `xcrun simctl shutdown all` after a run; that is a heat stop's, not a habit.

**UI tests need the Mac's display on; on a locked screen only the tests that open the mic are skipped** (stories 782,
1022, 1023, 1509; bead context-grabber-wm8y). With the display off they don't start, and running ones stall: on
2026-11-16 the whiteboard step sat 17 minutes before its first test on a dark Mac, against about 30 s once the display
came on, and a run that morning spent two hours in tests that pass in ten minutes. So the simulator rung holds the
display on (`caffeinate -d`), lights it first (`caffeinate -u`), and story 783's watchdog stops a run that still doesn't
start within 3 minutes. A locked screen with the display on is a different thing: every UI test runs on it as on an
unlocked one, except a test that opens the mic, which crashes the app in Apple's audio toolbox because a locked Mac
starves the simulator's audio server (beads 2v63, 208e). Evidence: on 2026-11-21 the screen was locked from 19:00:19 to
19:02:34, and the PaperKit touch contract UI tests, the contract tests, ChatReaction and ChatSkillThread all passed in
that window, the voice-button test the only failure; on 2026-11-22 at 22:42, locked throughout,
`WhiteboardTitleRenameUITests` started within seconds on the iPad simulator and passed 2 of 2 in 25 s. So on a locked
screen a simulator test run skips the tests `scripts/native/mic-tests.txt` lists as opening the mic (`-skip-testing`),
names each one on screen and in the ladder's ledger (`locked_skip`) to rerun unlocked, and runs the rest; a run that
named only such tests doesn't start (exit 75), and one that ran nothing else isn't a pass (exit 75). A screen that
locks during a simulator test run stops it only while one of its tests that open the mic is still to run (story 1023);
a test that fails after a lock on a run off the simulator sends the run back with exit 75 (story 1018, below).
`scripts/native/mic-tests.py check` (in `just test`) fails when a UI test touches a mic control or a call and is on
neither the list's `mic` lines nor its `reviewed` ones, so a new test that opens the mic can't run on a locked Mac
unnoticed.

**Never run a simulator rung while more xcodebuilds run than the Mac has lanes.** Startup waits fail under contention,
and a run under contention counts as failed and is rerun, not debugged. The lock doesn't cover this, since a device
build skips it. `scripts/native/xcodebuild-idle.sh` waits while as many other xcodebuilds run as there are lanes (on a
one-lane Mac: any other) before the Mac rung, the simulator rung and `just native-test-sim` start, says so, and refuses
with exit 75 after half an hour (`XCODEBUILD_IDLE_WAIT`). If more than the lane count run together during the rung, it
says so at the end: a failure is reported as contention. A pass stands, with a note,
because contention makes a test fail when it shouldn't, not pass.

**Every UI test run has a time limit, one retry and a short hang wait** (story 689). The wrapper all test runs go
through gives each case two minutes, runs a failed case once more on its own rather than the whole list again
(`UI_TEST_RETRY=0` turns that off), and stops an xcodebuild that prints nothing for 10 s once the run's last suite has closed
(`XCODEBUILD_IDLE_SECONDS`) and its result bundle is written (story 790), taking the result from the log's last closing suite line. A run of built tests
(`test-without-building`) whose first suite hasn't started within 180 s (`XCODEBUILD_START_SECONDS`; a healthy start,
the simulator's boot included, is under a minute) is stopped and fails with exit 75, naming the dark or locked screen
as the likely cause and saying whether the screen is locked now (story 783). A plain `test` compiles first, so it isn't
watched for its start. The timing summary counts a
retried case once and names every case that passed only on its retry: that is a flake to fix, not a pass to forget, so
the run fails for it with exit 65 even though xcodebuild called it a success (story 1017). If the flake check can't
complete, a run with a failed try exits 65 and says the flakes weren't checked, even after a hang or screen lock.
A run with no failed try keeps its ordinary result. A timing ledger write error leaves a completed flake verdict in
effect (bead `context-grabber-z8p7`). A known flake someone is chasing goes in `scripts/native/ui-quarantine.txt`,
one `Class[.test] <bead or #issue> <why>` per line (a line with no
tracker is ignored): it still runs, retries and is named as quarantined, but doesn't fail the run. Take its line out
when the bead closes. A run asked to repeat a passing case (`-test-iterations N`) repeats it; repeats are not retries.

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

**A locked Mac seems to starve the simulator's audio** (and with the display off, the UI tests don't start at all:
story 782 above) (#419: first inferred from comparing locked and unlocked runs of the
same code; on 2026-11-21 one case was traced, below). Timer cues come late or empty, the keepalive fails, breathing is silent and the
real-audio call can hear only zeros, on code that passes unlocked. Zeros for the whole call make the app re-arm the
mic, find no sound after it and file an automatic report, which is right for a real call (#364: unlocked on
2026-11-19 the same call heard the mic from its first buffer and filed none). The eulogy song failed the same way (#692; whether the Mac was locked then isn't known): on 2026-11-05 the song took 15 s to load and the system's player would not start it, nor a fresh one, and on 2026-11-19, unlocked, the same tests passed with a 0.2 s load. So `EulogyUITests` names the problem the sheet shows when the song doesn't play, and that is the sign to unlock and rerun. Since story 827 the smoke skips those checks while the
Mac's screen is locked (the timer and its voice, breathing, the real-audio call): each prints *skipped: Mac screen
locked*, the run's last lines count them as skipped, not passed, and a rerun unlocked is what checks them. A screen
that locks during one of them can still fail it; the line at the end says so. `scripts/native/test-smoke-lock.sh`
checks the skip with the lock probe faked (`SMOKE_LOCK_PROBE`), in `just native-test`.

**A closed lid deafens the real-audio call** (story 1025, bead `context-grabber-qj5y`). The simulator's microphone
is the Mac's default input, and with the lid closed (an external display, clamshell) the MacBook's built-in
microphone delivers exact zeros. The call re-arms the mic, still hears zeros and files an automatic report, which is
right for a real call. On 2026-11-22 all three real-audio calls run with the lid closed (10:03, 10:06 and 12:09 PST,
the lid shut since 09:28) heard only zeros, and every real-audio call run with the lid open since 2026-11-19 heard
the mic. So the smoke skips the real-audio call while the lid is closed and the default input is the built-in
microphone: it prints *skipped: Mac lid closed, the built-in mic hears nothing*, the run's last lines count it as
skipped, not passed, and a run with the lid open (or another input chosen as the default) is what checks it. The
timer and breathing only play sound, so they still run. A clean call is judged on its own log (story 1026), and a report the
ten-minute window held back counts as filed: the 10:06 rerun "passed" only because the window skipped its report.
`scripts/native/test-smoke-lock.sh` checks the skip with the lid and input probes faked (`SMOKE_LID_PROBE`,
`SMOKE_MIC_PROBE`).

A locked Mac can crash the app, too (bead `context-grabber-2v63`). Opening the mic asks the simulator's audio server
for the input, and on a locked Mac that call can go unanswered: after about ten seconds Apple's audio toolbox aborts
the app (the crash report's top frames are `_ReportRPCTimeout` under `AVAudioEngine.inputNode`). That is how
`ChatNewThreadUITests.testTheVoiceButtonOpensANewChatWithItsMicTapped` failed on two runs of 2026-11-21, its retry
crashing too, each while the screen was locked, and how it failed again when rerun on purpose locked; that morning,
unlocked, it passed twice. So **a test that fails after the screen has locked is not read as broken** (story 1018): the
wrapper every test run goes through looks at the lock every two seconds, and when every case that failed (or passed
only on its retry) failed after the screen was first seen locked, the run stops with exit 75, saying when it was first
seen locked and to unlock and rerun. A case that failed before the lock, or a failure that wasn't a test's (a build),
fails the run as before, naming the lock; a pass stands, with a line that the screen locked. If a try failed and the
flake check couldn't complete, the run exits 65 with the unchecked-flakes message.
`scripts/native/test-xcodebuild-log.sh` checks it with the lock probe faked. Since BugKit 0.3.16 (bug-kit #131, story
144) a simulator crash ends at BugKit's own file in the app's container,
`$(xcrun simctl get_app_container <udid> com.idvorkin.grabbernative data)/Documents/crashes/signal-<epoch>.txt`
(renamed `.reported.txt` once the next launch has announced it as `crash_report`; `exception-<epoch>.txt` for an
Objective-C exception); the Mac's ReportCrash no longer writes a `GrabberNative-*.ips` for it, so the older crashes
are the only ones under `~/Library/Logs/DiagnosticReports/`. The screen's lock and unlock times are in the system
log (`/usr/bin/log show --predicate 'process == "loginwindow" AND eventMessage CONTAINS "setScreenIsLocked"'`).

Each of those crashes also put a *GrabberNative quit unexpectedly* dialog on the Mac's screen until BugKit 0.3.16 (seven
on the evening of 2026-11-21, bead `context-grabber-208e`; since then a simulator crash ends quietly at its file), and the
run is lost either way, so **no test that opens the mic runs on a locked Mac, and a run is stopped when the
screen locks under it with one still to run** (stories 1022, 1023). The wrapper every test run goes through looks at the
lock the way BugKit's signing guard does (`ioreg`'s `CGSSessionScreenIsLocked`) before it starts: locked, it skips the
tests that open the mic, as above. During a simulator test run whose tests that open the mic haven't all passed,
skipped or failed, the wrapper's two-second look at the lock stops the run the moment it sees the screen locked: it ends xcodebuild and
the app and its test runner on that simulator (`simctl terminate`), and exits 75 saying when, or 65 if a case had
already failed before the lock or a failed try went unchecked. A run of several test targets (`just native-test-contracts`
is two) closes a suite after each, so the stop stays on to the last. A lock seen between two targets stops the run once the next one starts, if the
screen is still locked then. Once the last target's suite has closed, a lock no longer stops it. Builds, the Mac build
and test runs that aren't on a simulator are not held. An unreadable lock state counts as unlocked (Linux has no
`ioreg`). So never run `xcodebuild test` on a simulator by hand: every `xcodebuild … test` in this file means through
`scripts/native/xcodebuild-log.sh <name> "TEST SUCCEEDED" xcodebuild …`. `scripts/native/test-xcodebuild-log.sh`
and `scripts/native/test-build-lane.sh` check it with the lock probe faked.

**Only what the branch touched, and quietly** (Igor, 2026-11-01). The smoke runs only the sections for the features
this branch changed since `origin/main`: cockpit, whiteboard, timer, breathe, places, call, mirror, drill or
chat. [`smoke-features.sh`](../scripts/native/smoke-features.sh) maps the changed paths to sections. A change to shared
code, the project or the smoke itself runs everything, and docs, host tests or UI test files alone run none (the ladder runs a UI test file as its own class). The launch and report
checks always run. To run every section, set `SMOKE_ONLY=all just native-test-sim`; to pick sections, set
`SMOKE_ONLY=timer,breathe`. The app under test plays silently, while the Mac's own sound is left alone. The simulator would otherwise play the
timer's counts, the breathing voice and the call through the Mac's speakers. `GRABBER_SILENT=1` goes to every launch,
and it sets the app's players to zero volume, so every cue still plays and still shows in the log. The host rung
(`just test`) plays nothing and stays whole (its time is in the rung table above).

| Hook | Effect |
|---|---|
| `GRABBER_BUG=text` | two seconds after launch, file a problem report with that note, as a shake and *Log it* would |
| `GRABBER_TIMER=<chip>` | open the Gym Timer on that chip (`30sec`, `1min`, `2min`, `5-1`, `custom`) and start it, as a widget tile would. `GRABBER_TIMER=work,rest,rounds` (seconds, seconds, count) runs that shape as Custom without remembering it: `10,10,2` is a whole workout in 35 s; `just native-test-sim` runs `10,0,1` (15 s) and reads `timer_cue` and `live_activity` from |
| `GRABBER_BREATHE=breath,cycles[,cue[,pause_at_seconds]]` | open Box breathing and begin exactly that session (seconds a side, whole cycles, `voice` / `tone` / `off`; the cue is used but not remembered): `2,1,voice` is a whole session in 10 s, which `just native-test-sim` runs and reads `breath_cue` and `live_activity` from. A fourth field pauses the session by itself that many seconds into the breathing, as a tap on the circle would (`breath_pause` with reason `hook`): `6,1,off,3` shows the paused circle mid-inhale, for a screenshot. Any other value (`open`) just opens the sliders, for a screenshot |
| `GRABBER_BREATHE_STYLE=line\|glow\|beads\|tide` | with `GRABBER_BREATHE`, draw that session's breath in that ring style (story 240); used but not remembered |
| `GRABBER_IMPORT_DB=<file>[,recent]` | import that database as *Import from Context Grabber* would (a path, absolute or under the app's Documents). `recent` shifts its timestamps by whole days so the newest point falls in the last 24 hours, at its own time of day, and the fixture's last week fills the last seven days (#217; whole weeks left it up to six days back): `just native-test-sim` copies the real fixture `__tests__/fixtures/context-grabber.db` to `Documents/import-fixture.db` and imports it this way, twice, reading `import` and `places_open` |
| `GRABBER_PLACES=open\|map[,unnamed[,name]][,edit:<name>]` | open Places (`map`: with the map full screen), for a screenshot and the `places_open` event; `map,unnamed` then opens the card of the longest unnamed place once the trail is read (`ui` unnamed_place, from: hook), and `map,unnamed,name` its naming card (story 056); `open,edit:Home` opens that known place's screen with its icon picker (story 057) |
| `GRABBER_TRACKING=on\|off` | flip the Background Tracking switch as a tap would; with `xcrun simctl privacy <udid> grant location-always com.idvorkin.grabbernative` first, `on` starts recording, and `xcrun simctl location <udid> start …` moves the simulator so points arrive (`location_point`) |
| `GRABBER_RETENTION=<days>` | set retention as the stepper would; lowering it prunes at once (`prune` with reason `lowered`) |
| `GRABBER_EXPORT=1` | make the export file as *Export database* does, without the share sheet; `export` names its path, which the smoke opens with `sqlite3` |
| `GRABBER_CALL=<ws url>` | open the call screen and, a second later, call that bridge as a tap on *Call Larry* would; hang up after `GRABBER_CALL_SECONDS` (default 8). `just native-test-sim` points it at `scripts/native/fake-bridge.py` on `ws://localhost:8799` and reads the `call_*` events and the bridge's own report |
| `GRABBER_CALL_BRIDGE=<ws url>` | the bridge a call dials, placing none (`GRABBER_CALL` wins over it). Every UI test sets it through `XCUIApplication.forTests()` to `ws://192.0.2.1:8780`, an address routed nowhere, so a test that taps *Call* never reaches Igor's bridge (context-grabber-0mn: the Cockpit's ☎ check, now in `CockpitBackUITests`, placed a real drill call on every run) |
| `GRABBER_CALL_AUDIO=synthetic` | with `GRABBER_CALL`: a 220 Hz tone for the mic and counted, unplayed playback instead of the audio engine, so the protocol path is checked whatever the simulator's audio does; the smoke run makes the call once this way and once on the real engine |
| `GRABBER_MIRROR=fixture\|healthkit` | open Today and grab the mirror's fixture week (`mirror-fixture.json`, moved to this week): `fixture` answers from the file, `healthkit` first saves it into the simulator's Health store (never on the phone) and grabs from HealthKit. Either writes `Documents/exports/{fixture,summary,raw}.json` and logs `mirror_fixture_done`; `sim-smoke.sh` checks each run's summary and raw are byte-identical to the fixture code path over that run's own `fixture.json` (a host test, `MirrorFixtureTests` with `MIRROR_COMPARE_DIR` naming the run's copy), and that the ten series came back with nothing failed. See [Health access for the simulator smoke](#climbing-just-test-ladder). |
| `GRABBER_METRIC=<key>` | with `GRABBER_MIRROR`: open that metric's detail after the grab (`sleep`, `movement`, `heartRate`, …), for a screenshot |
| `GRABBER_TURN=left\|right` | with `GRABBER_TIMER`: draw the timer as if the phone were on that side (the simulator has no accelerometer), for a screenshot of the turned face |
| `GRABBER_COUNT_VOICE=adam\|igor\|aussie` | with `GRABBER_TIMER` or `GRABBER_TIMER_SETTINGS`: count in that voice for this launch, not remembered and with no sample (story 187); `just native-test-sim` runs `aussie` and reads the first `timer_cue`'s `voice` |
| `GRABBER_SILENT=1` | the app's own sound at zero volume: the timer's and breathing's players, the breathing voice, the song and the call's speaker side. Nothing else changes: every cue still plays and logs as played, and the call's silent-mixer check still hears the call. `sim-smoke.sh` sets it on every launch, so a smoke run is quiet without muting the Mac |
| `GRABBER_NO_ANIMATIONS=1` | UIKit's animations off: a pushed screen, a sheet or a menu is there at once (story 754). Every UI test sets it through `XCUIApplication.forTests()`, apart from the whiteboard's classes (`forTests(animated: true)`: without the Board menu's closing animation its closing tap reached the canvas); the smoke and the phone keep their animations |
| `GRABBER_TIMER_DIAL=drums\|knobs\|arc\|sliders` | which control sets Custom's Work, Rest and Rounds upright (story 184): the drums are what ships; the knobs, the arc and the old sliders are only for trying and screenshots. Alone it opens the timer on CUSTOM, not started (`ui` open_timer with dial); with `GRABBER_TIMER` it draws that control for the run. Not remembered |
| `GRABBER_TIMER_SETTINGS=1` | open the Gym Timer, not started, with *Timer settings* up (logs `ui` action: timer_settings), for a screenshot of the sheet |
| `GRABBER_WHATS_NEW=open` | open What's new (logs `ui` action: open_whats_new with from, days, changes), for a screenshot of the build's own history (story 148) |
| `GRABBER_WINDOW=<screen>[,again][,close]` | on an iPad simulator (a phone has one window): once the home window is up, opens that screen (`chat`, `today`, `cockpit`, `places`, `whiteboard`, `card`) in its own window as *New window* would, then three seconds apart asks again and closes it (story 460, 461). Read `window` from the log: `open`, `appear`, `bring_forward`, `close` and `gone`, with `scenes`, the windows connected; and `title`, what the app just named a window, read back from the scene, and what it was (#661). A hold on a tile, iPadOS's own New Window, what the windows look like beside each other and where iPadOS shows a window's name are checked on the iPad |
| `GRABBER_WINDOW_CHOOSE=<screen>` | on an iPad simulator: once the home window is up, opens a new window as the Mac's Option+Command+N or iPadOS's New Window would, which shows the chooser since home is taken, and the chooser picks that screen as a tap would (story 731, #782). Read `window` from the log: `extra_home` and `appear` for the chooser, then `choose` with screen and scenes, `open` (or `bring_forward`) with from: new_window, and the chooser's `gone`; `choose_close` with ok: false when iOS refused to close it. The chooser's rows and their order are checked on the iPad or the Mac |
| `GRABBER_PAPER_STAGE=<draw\|select>[,cancel]` | a bare PaperKit paper over the app, set up as the board sets it up (its feature set and inks, the tool picker shown, its touch watcher on the view around it) with none of the board's handling, and a state line above it (`paper-stage-state`: strokes, markup changes, whether PaperKit can undo, the watcher's ended and cancelled lifts and the last lift's touch phase, the undo's name) and an Undo for PaperKit's stack. `select` sets a finger to select, as the board does while marks show; `cancel` calls off any touch still down 0.3 s after it began. `PaperKitTouchContractUITests` uses it (story 1020) |
| `GRABBER_WHITEBOARD=open` | open the boards, as the Whiteboard tile on the home screen would (`ui` open_whiteboard, from: hook, then `whiteboard` list with the count, and `whiteboard_sync`: on a simulator with no iCloud account, ok: false with skipped: account_…, never an error). `just native-test-sim` runs it and reads those three. Drawing, the tool picker and a board from another device need a real iPad and iPhone signed into iCloud |
| `GRABBER_HOME=settings` | open the home screen's Settings sheet (logs `ui` action: home_settings), for a screenshot of the launchers and the diagnostics (story 147) |
| `GRABBER_HOME=ink-side-by-side` | open Settings with Ink side by side pushed on it, on the iPad or the Mac only (logs `ink_side_by_side` action: open; story 1209) |
| `GRABBER_SUPERMIX=workout\|liked\|feel_good` | open that mix as a choice from the music tile's press-and-hold popover would (story 221; the simulator has no YouTube Music, so it opens in Safari); the log's `ui` open_workout_supermix carries the mix, from: hook and how |
| `GRABBER_INBOX_FIXTURE=1` / `GRABBER_INBOX=open` | write three Inbox items as the share extension would (a link with a note and two texts; their ids start `fixture-`, so they are never sent to Larry, since the simulator reaches the tailnet too), and open Chat (#305; `ui` open_chat, from: hook). The share sheet itself is a phone check: simctl cannot drive it |
| `GRABBER_CHAT_NEW=open\|voice` | open Chat with its + tapped: a new, empty thread with the ordinary bar on screen (`ui` open_new_chat, from: hook; #536). `voice` taps the voice button beside the + instead, so the thread opens recording (`voice`: true, then `chat_voice`; #637). Typing, speaking and *Paste image* are phone checks |
| `GRABBER_CHAT_SELECT=archive` | with `GRABBER_INBOX=open` and `GRABBER_CHAT_URL`: once the list is read, *Review* and *Archive (N)* tap themselves (`chat` select, from: hook, with count; archive, from: select; stories 312, 314). `sim-smoke.sh`'s chat section checks it against the fake Cockpit |
| `GRABBER_CHAT_DECISION_FOLD=<ask>` | on the simulator, folds and reopens the named card once it appears in Chat (story 1131). Smoke opens its thread against the fake Cockpit and checks the `decision_fold` and `decision_unfold` events. `GRABBER_DECISION_FOLDS=reset` starts with empty simulator fixture prefs, and `keep` reads those same prefs on a test relaunch |
| `GRABBER_WHITEBOARD_QUESTION_FOLD=<ask>` | on the simulator, opens the named question on the fixture board and taps its fold control (story 1119). Smoke asks the fake Cockpit to name the fixture board in its ask and checks the board's `open` and `collapse` events with `answered: false` |
| `scripts/native/test-chat-ui.sh <name or udid>` | the chat UI tests against the fake Cockpit (its POST /chat held 3 s, `FAKE_COCKPIT_NEW_DELAY`), one class a line in [The chat suite's classes](#the-chat-suites-classes). See the [build-lane example](#climbing-just-test-ladder) for running under `caffeinate -i` (#536). |
| `scripts/native/test-whiteboard-ui.sh <name or udid>` | the whiteboard UI tests on an iPad simulator against the fake Cockpit, one class a line in [The whiteboard suite's classes](#the-whiteboard-suites-classes). See [simulator lane selection](#climbing-just-test-ladder). |
| `GRABBER_WHITEBOARD_AFTER_KEEP=<seconds>,undo,redo,...` | on a board on paper, those presses of undo and redo that long after a kept ghost, 3 s apart (`whiteboard` action: paper_press_hook): a phone's tool picker has no Undo, and keys reach only a run's first test. `WhiteboardPaperGhostsUITests`, run by `test-whiteboard-ui.sh`, uses it, and reads where ghosts and ink sit off the screen's pixels: a ghost that can be seen, kept where it was in its colour, a tap off it that leaves no dot, a pinch that takes the ghost with the ink (skipped on an iPad simulator, where XCUITest's pinch barely moves; an iPhone draws nothing since story 746, so the ladder never runs it), one undo for a kept mark (the pages a far mark brings are `BoardPagesTests`, on the host), keeping one of Larry's marks leaving the pen as it was (the next stroke black, at the same width, none of his purple; stories 774, 778), a ghost not saved, and the same stroke ids from the fake's `GET /fake/strokes` before and after a reopen. The bar, the note and the turns are `WhiteboardTurnUITests`'. The Pencil holding a pause, a finger drag with ghosts showing, a real mic, and how a ghost looks under ink are the iPad's |
| `GRABBER_WHITEBOARD_AFTER_OPS=<seconds>,undo,redo,...` | on a board on paper, those presses of undo and redo that long after a batch of Larry's changes moved the board, 3 s apart (`whiteboard` action: paper_press_hook; the batch's own lines are `board_ops` and `paper_ops`). `WhiteboardPaperGhostsUITests` uses it with the fake Cockpit's `POST /fake/larry-ops`, which makes Larry's next board answer a batch (room below the middle of the picture he got, plain text in the gap, on the message's rev, one behind it with `behind`, which still applies, or before anything the board remembers with `stale`), and `GET /fake/ops`, which says the rev and op_result each board message carried: the ink below moves and the ink above stays, by the screen's pixels, one undo puts it back and redo pushes it again, his text shows as a ghost in his purple and keeps where it showed, goes back to him as one text under its id, a push from an older look still applies (story 961), a stale push moves nothing and his next turn says `stale` (stories 814, 816–818), and a refused push shows *Larry's edit blocked · Retry*, × puts it away asking nothing and Retry is his turn (stories 970–972; the chip's rules are `BoardBlockedEditTests`, on the host). With `"kind": "ink_and_button"` the batch is his purple line and a green button instead: the line lands as ink and goes back under his name, the button is no stroke, and a tap on it reaches the fake's `POST /whiteboard/events` at once (`GET /fake/ops`' `event_posts`; stories 840, 845, 846). `scripts/native/test-fake-cockpit-ops.py`, in `just test`, holds the fake's half. Which strokes move, the page growth and the rules are `BoardOpsTests`, on the host; a push under a live Pencil and how the text reads are the iPad's |
| `GRABBER_WHITEBOARD_BAR_UNDO=<seconds>,undo,redo,...` | on a board drawn on here, those presses of the bar's own Undo and Redo that long after it opens, 3 s apart, through the buttons' own press (`whiteboard` action: paper_undo_button; #965, stories 1008, 1009). The smoke opens a fixture board on an iPad with `GRABBER_WHITEBOARD_PASTE` and this, and reads that Undo took the *Paste* step and Redo brought it back; the buttons themselves, dimmed and named for VoiceOver, are `WhiteboardPaperGhostsUITests`' |
| `GRABBER_WHITEBOARD_AFTER_INK=copy,paste` | on a board on paper, a second after the first ink: *copy* selects all the ink and puts it on the clipboard in PaperKit's own format, since nothing takes the system's Copy with a selection set on the simulator; *paste* presses Paste as ⌘V would, since keys reach the app for one test per boot (`whiteboard` actions paper_copy_hook, paper_paste), and that boot's keys are `WhiteboardPasteUITests`' one test of ⌘V and ⌘Z. `WhiteboardPaperPasteUITests`, run by `test-whiteboard-ui.sh`, uses it, and checks a paste in the middle of the paper from the screen's pixels, a tall paste's pages and its one undo, the same stroke ids at the fake Cockpit after a relaunch, and that a picture stays off the board. The text's layout, its caps and the bar's note are `WhiteboardPasteTests`, on the host. The bar's paste button, a real lasso Copy followed by ⌘V, whether ⌘V of something copied in another app shows *Allow Paste?*, whether ink ever goes missing there (`paper_ink_look`), and whether the small redraw of story 650 can be felt are the iPad's |
| `GRABBER_WHITEBOARD_SELECT_NEWEST=<n>` | on a board on paper, once it holds `n` strokes, the newest is selected as the lasso would leave it, since a UI test can't draw a lasso (`board_connectors` action: select_newest_hook). `WhiteboardConnectUITests` uses it: a drawn arrow between two words, selected, brings Connect, and a tap on it puts a connector in its place (story 910). Routing, following and Larry's connector op are `BoardConnectorsTests`, on the host; a real lasso and the Pencil are the iPad's |
| `GRABBER_WHITEBOARD_ZIGZAG=<n>` | on a board on paper, the stroke that brings it to `n` strokes is read as a fast zigzag across its own frame, since a UI test can only drag straight. `WhiteboardScratchOutUITests` uses it: a word scratched out stays gone, on the sheet and in the strokes Larry gets, when the next stroke is drawn (story 890, #999), and so does a folded section scratched out by its header line (story 905, #1015). What counts as a zigzag is `WhiteboardScratchOutTests`, on the host; the Pencil's own zigzag is the iPad's |
| `GRABBER_WHITEBOARD_PENCIL=seen` | a board acts as if the Pencil had touched a board this launch, so a finger never draws (story 1153, context-grabber-2eml). `WhiteboardPaperGhostsUITests.testOnceThePencilHasTouchedAFingerNeverDraws` uses it; the rule itself is `WhiteboardFingerTests` on the host, and the real Pencil is the iPad's |
| `GRABBER_WHITEBOARD_FINGER_LABEL=1` | on a board on paper, whether a finger draws as an element, `whiteboard-finger`: *draws* or *taps*, with the rule that decided as its value (`marks`, `tap_off`, `no_marks`, `pencil`; stories 1152, 1153). XCUITest's finger drag draws on the simulator whatever PaperKit's touch is set to (the iPad's finger pans), so `WhiteboardPaperGhostsUITests` reads the verdict here and the ink only where a finger draws |
| `GRABBER_WHITEBOARD_KEPT_INK_LABEL=1` | on a board on paper, every look at kept ink this launch as an element, `whiteboard-kept-ink`: its label each look's verdict in turn (`whole`, `cut`, `dark`, `none`, `out` of view), its value how many redraws they asked for (story 650, context-grabber-qko5). A redraw is a blink or a jump too quick for a UI test to catch, so `WhiteboardPaperGhostsUITests` reads it here |
| `GRABBER_WHITEBOARD_UNDO_LOOK=label` or `=miss` | on a board on paper, every look after an Undo or Redo this launch as an element, `whiteboard-undo-look`: its label each look's verdict in turn (`whole`, `missing`), its value how many heals they asked for (story 1203, bead context-grabber-9bll). With `miss` the first look after each step takes every piece it checks as missing, so the heal runs on the simulator, which misses only now and then; `WhiteboardUndoRedrawUITests` uses it |
| `GRABBER_WHITEBOARD_FEEDBACK_SECONDS=<seconds>` | how long a pen gesture's feedback stays after the finger or the Pencil lifts (#1000), so a UI test can see and photograph it: the room handle's band, which otherwise goes on the lift, stays that long (`board_room` band_hidden, then the band); a scratch-out's flash stays bright that long before it fades; and *Nothing under the scribble to erase* shows that long, or its usual 3 s if longer. `WhiteboardOutlineUITests.testTheRoomHandleShowsABandWhileHeld` (stories 1044, 1038) and `WhiteboardScratchOutUITests.testWordScratchOutAndEraserSweep` and `testAZigzagOverNothingSaysSoAndGoes` (stories 1050, 1108, 1051) use it; the easing under Reduce Motion and the Pencil's hold are the iPad's |
| `GRABBER_WHITEBOARD_REVIEW_IDLE=<seconds>`, `GRABBER_WHITEBOARD_REVIEW_FINDING=1` | the wait before a session's review, in place of five minutes, and a stand-in Keep that changed the pen after the first stroke, so the review has a finding the simulator can show (stories 1237, 1243–1245). `WhiteboardReviewUITests` |
| `GRABBER_WHITEBOARD_AFTER_INK=select` | on a board on paper, a second after the first ink, all the ink selected as the lasso would leave it (`whiteboard` action paper_select_hook), since the simulator can't work the lasso: its label reads *Ink · hold for To text*. `WhiteboardToTextUITests`, run by `test-whiteboard-ui.sh`, holds a finger on it and chooses the hold menu's *To text* (stories 1309, 1310) against the fake Cockpit's `POST /ink/to-text` (which reads every picture as *hello*, or as `POST /fake/to-text` says) and checks the ink becomes the text (story 920); that one undo brings the ink back is the iPad's to show. The request, the answer and where the words go are `BoardToTextTests`, on the host; the real Cockpit's reading of real handwriting, and a real lasso, are the iPad's. `WhiteboardRewordUITests`, by the same script, taps that text with a finger, types into the field that opens and checks Return draws the new words from the same left, or deletes the text when emptied (stories 940, 941) |
| `GRABBER_WHITEBOARD_PAGE_AFTER_INK=<page>` | on a board on paper, a second after the first ink, the view goes to that page's top, as far as the column lets it (`whiteboard` action: paper_page_hook, with visible): a finger draws on the simulator and XCUITest has no two-finger drag. `WhiteboardPaperGhostsUITests.testThePictureIsThePageOnScreen` uses it: page 1's ink off screen leaves Send disabled, and ink on page 2 goes as a picture whose frame, read back from the fake's `GET /chat/<key>`, is page 2's alone (stories 433, 522). Which pages are on screen, which are empty and the frame that covers them are `BoardPicturePagesTests`, on the host; whether the picture reads well to Larry is the iPad's |
| `GRABBER_WHITEBOARD_SAVE_FAILS=1` | every board's save fails as a full disk's would (stories 599, 612): the problem on the board, and on the list after leaving it (`WhiteboardOnPaperUITests`). The save's rules, through a disk that fills (`FullDisk`, what this hook installs), are `BoardKeepingTests`, on the host: the last good drawing kept, the list's problem staying until that board saves, a new board closed without a stroke dropped |
| `GRABBER_WHITEBOARD_UNREADABLE=stuck` | a reopened board's drawing reads as nonsense and can't be moved aside (story 1060, #1042): the board opens look only, *Couldn't be read: look only*, with a copyable problem (`WhiteboardOnPaperUITests`). That the original and any older set-aside copy are kept byte for byte, through an edit's save, a relaunch and a reopen (`StuckUnreadableDisk`, what this hook installs), is `BoardKeepingTests`, on the host |
| `GRABBER_WHITEBOARD_GRID=on` | a board turns its grid on as it opens (`whiteboard` action: grid_on with board). The smoke opens a fixture board with it, and on the same launch reads the list's `new_board` and the board's `editable` and `look_only` (story 746 on an iPhone: no New board, *Look only on iPhone: draw on the iPad*; `new_board` is the rule the list's button reads, and `editable` is what shows the Board menu, *Ask at my pauses*, story 758); whether the lines show is `WhiteboardPaperLinesUITests`, from the screenshot's pixels |
| `GRABBER_WHITEBOARD_GRID=off` | a new board starts without the grid it opens with since #915 (story 410). Every UI test launches with it (`XCUIApplication.forTests`), so a board's pixels are read against plain paper; `WhiteboardPaperLinesUITests.testANewBoardOpensWithTheGrid` drops it to see the real default |
| `GRABBER_WHITEBOARD_PANEL=fresh` | the board conversation's kept height, float and card are forgotten as the first board opens, once per launch, so `WhiteboardConversationPlaceUITests` starts from the panel's own place after an earlier run left the card moved (story 1313, #1416) |
| `GRABBER_WHITEBOARD_LARRY_TIMEOUT=<seconds>[,dismiss]` | a turn of Larry's is out that many seconds, not 3 minutes, before the board stops waiting and shows *Larry didn't answer* (`whiteboard` action: larry_turn_over, why: timeout, with what the problem says; story 669). With `dismiss` the problem goes 3 s after it shows, as a tap on *Dismiss* would take it (`whiteboard` action: problem_dismissed; story 761). It needs a turn out, which takes a tap on *Send to Larry* against a Cockpit (its three minutes count from when the outbox sent it, story 1176); no UI test or smoke step uses it yet (Igor wants fewer simulator tests), so it is for a run by hand |
| `GRABBER_WHITEBOARD_LARRY_WAIT=retry` / `dismiss` / `interrupt` | that control taps itself, once, 3 s after the board first offers it twenty seconds into a turn of Larry's (`whiteboard` action: larry_wait with wait: stuck or working, then larry_retry, larry_dismiss or larry_interrupt; stories 775–777). The twenty seconds are the real ones. Against the fake Cockpit, *Interrupt* needs a slow Larry (`FAKE_COCKPIT_LARRY_DELAY=30`: the first picture's turn is out past 20 s; `FAKE_COCKPIT_NEW_DELAY=25` instead holds the first picture's sending, so Interrupt lets go of a picture still going up, sending: true, and the next tap sends), and *Retry* and *Dismiss* need a Cockpit that marks and holds a picture (`FAKE_COCKPIT_BOARD_HOLD=25`: the board's second picture is held once and is stuck at 20 s; Retry's resend lands at once and Larry answers). *Interrupt* needs a tap on *Send to Larry*; *Retry* and *Dismiss* need a picture a pause hands him on a Larry board, since a Send waits in the outbox and is never stuck (story 1176); no UI test or smoke step uses this hook (`WhiteboardLarryWaitUITests` taps the controls itself, against the fake's one-shot knobs; see `scripts/native/test-whiteboard-ui.sh` above), so it is for a run by hand. Which state offers which control is `WhiteboardLarryWaitTests`', on the host |
| `GRABBER_WHITEBOARD_LIST_CHAT=<board>` | on an iPhone, once the boards list is up, that board's chat bubble taps itself (`whiteboard` action: chat_lookup, from: list; #1163, story 1097). The smoke opens the list on a fixture board with it and reads that the lookup ran and how it ended (on a simulator, usually without a thread: no Cockpit, or none found). A thread found among Larry's chats and Chat opening on it are the phone's; the rules are `BoardThreadFindTests`, on the host |
| `GRABBER_WHITEBOARD_SAY=<words>` | a tap on the board's mic hears these words instead of the microphone, so `WhiteboardTurnUITests` can test a spoken turn on the simulator |
| `GRABBER_WHITEBOARD_GHOST_SECONDS=<n>` | Claude's ghosts fade after n seconds instead of 30: `WhiteboardPaperGhostsUITests` holds them for 600 while it looks, and a short value shows them go and Larry's stay by hand; the rule itself is `WhiteboardGhostTurnsTests`, on the host |
| `GRABBER_WHITEBOARD_PASTE=<text>` | a second after a board opens, that text lands as a paste would (`whiteboard` action: paste). XCUITest's taps never reach the system's Paste button (it never fires under them), so `WhiteboardPasteUITests` uses this and ⌘V; the button itself, whether it dims and that no prompt shows are checked on the iPad |
| `GRABBER_CHAT_HOLD=yes` / `no` / `quote` / `copy` / `new-chat` | once the open thread is read, that choice of the press-and-hold menu taps itself on Larry's newest message (`chat` reaction, quote or copy; #629, stories 518–519, 540–541); use it with `GRABBER_CHAT_URL` and `GRABBER_LINK=grabbernative://chat?thread=igor2-88g.629` (`new-chat` with thread=igor2-88g.900, which holds a message of Igor's). `ChatReactionUITests` holds the message for real against the fake Cockpit (the smoke no longer launches it: the choices and the bare Yes are `ChatReactionTests`' on the host). Before it, the chat suite (`test-chat-ui.sh`) and the ladder's chat step (#812) run `scripts/native/forget-chat-thread.sh`, which removes the simulator outbox's earlier answers in that thread: the outbox keeps what it sent, a fresh fake Cockpit never heard it, and the thread would show it as newer than Larry's question (#801). `new-chat` taps *Send to new chat* on Igor's newest message instead, the only ones that offer it (`chat` moved_to_new_chat with ok and to, or ok: false with reason; story 820): the fake Cockpit moves it (`POST /chat/move`) and the new chat opens over the old one, which keeps *Moved to a new chat*. `ChatMoveUITests` holds the message for real (on igor2-88g.820, in the chat suite); the request, the answers and the moved line are `ChatMoveTests`' on the host |
| `GRABBER_CHAT_LINKS=fold` / `all` | once an open thread's strip of links shows, *Links* folds it (`chat` links_folded with thread and folded; a second launch with it opens it again, since the fold is remembered) or *All links* opens its list (#736, stories 549–552); use it with `GRABBER_CHAT_URL` and a `GRABBER_LINK` to a thread that holds a link. A chip's tap leaves the app, so the phone checks that |
| `GRABBER_CHAT_REVIEW=open` | once a blog-review card shows in the open thread, its first note opens by itself (`chat` review_note with thread, note 0, open true, from: hook; story 748); use it with `GRABBER_CHAT_URL` and a `GRABBER_LINK` to a thread holding a message that is exactly a batch. The fake Cockpit has no such thread yet, so the smoke does not run it; what is a batch and what each chip reads are host tests (`ChatReviewBatchTests`) |
| `GRABBER_CHAT_ENTER=<words>` | once a chat bar shows, those words and two new lines land in it in one change, as a dictation tool writes them, and the bar's own rule sends them (`chat` double_enter_sent with thread and how: one_change, then the send's own events; story 749); use it only with `GRABBER_CHAT_URL` and a `GRABBER_LINK` to a thread. Two separate Returns and their 400 ms are host tests (`ChatDoubleEnterTests`) and a phone check; the smoke does not run it yet |
| `GRABBER_CHAT_IMAGE=open` | a picture in the open thread opens full size by itself (`ui` open_chat_image); use it with `GRABBER_CHAT_URL` and `GRABBER_LINK=grabbernative://chat?thread=igor2-88g.592`, the fake Cockpit's thread holding a white picture (story 306). `ChatImageUITests`, run by `test-chat-ui.sh`, checks Done's badge shows over the white and that Done and a swipe down both close it |
| `GRABBER_BOARD_FIXTURE_FROM=<device name>` | makes `GRABBER_BOARD_FIXTURE`'s board another device's, drawn on that name, so `WhiteboardRowDeleteUITests` can delete one (story 396, #613). The delete crossing iCloud needs two real devices: the simulator has no account |
| `GRABBER_BOARD_FIXTURE_THREAD=<thread>` | gives `GRABBER_BOARD_FIXTURE`'s board that thread with Larry, as if it had sent him a picture, so *Open in Chat* has somewhere to go on the simulator (stories 1206, 1207, bead context-grabber-dbku); `ChatImageUITests` uses it with the fake Cockpit's thread igor2-88g.603 |
| `GRABBER_BOARD_FIXTURE=<id>` | an empty board on paper, of this device, with that id, so a chat picture's *Jump to board* has somewhere to go (story 317, #603); use it with the fake Cockpit's thread igor2-88g.603 (board-603). Its thread igor2-88g.604 names a board no device has. `ChatImageUITests` checks the jump, no button on a picture with no board, and the problem on a missing one. A board that comes down from iCloud on the jump needs a real device signed in |
| `GRABBER_CHAT_URL=http://localhost:<port>` | Chat (and the Inbox's sending) talks to that Cockpit instead of the tailnet's: `scripts/native/fake-cockpit.py <port> <report>` stands in for the chat routes, with one thread to talk in, one holding a white picture, one Larry marks as looking done, a pinned one with no messages that refuses an archive, and a Larry who answers each message a second later. It has no open asks until a test posts `/fake/asks` {"open": true} (#878), and the same with false takes them and their chats away. Its `GET /asks/search` searches those asks and one answered one as the Cockpit's does, with a 400 for no words and a 502 for the word *bdfail* (story 1132, `ChatAskSearchUITests`). Its `GET /chat?q=<words>` is the Cockpit's chat search (cockpit story 335): the list's rows whose title or any message says every word; `POST /fake/search-thread` {"on": true} adds thread igor2-88g.1443, whose word *passport* is only in its first message (false takes it away), and `POST /fake/search-down` {"status": 502} fails the search alone, the plain list staying up, until `{}` (stories 1616–1618, `ChatThreadSearchUITests`). `POST /fake/down` {"status": 502} makes its list and thread reads answer that status until `{}` brings them back (stories 1604–1606, `ChatCockpitDownUITests`). `POST /fake/slow` {"seconds": 6} makes each thread read wait that long before it answers, until `{}` (story 1608). It has no skill thread until a test asks with `POST /fake/skill-thread` (#632), because an extra row moves the list under the archive tests. The same holds for the delivered PDF's thread, `POST /fake/file-thread` (story 1125). Its `/attachments` takes pictures, PDFs and plain text and refuses the rest with the Cockpit's 400 (the real one also takes Word, Excel and PowerPoint). Without it a simulator reaches no Cockpit for chat, the Inbox or a board's turn, as with the archive (#525): what waits stays waiting, and the log's `chat` no_address and `inbox` no_address say so. A Mac build named `https://no-address.invalid` behaves the same way. On a Mac build it also names a call's Cockpit. A phone, an iPad or a Mac build with no address uses the real Cockpit, so on a Mac a `GRABBER_CHAT_SEND` with no address reaches Larry. The share card, which gets no hooks, never has an address on a simulator |
| `GRABBER_CHAT_SEND=<thread>\|<text>` | that text written in that thread as the compose bar would (`new\|<text>` starts a thread), then sent; use it only with `GRABBER_CHAT_URL`, or on a simulator to see the message held (#525). That it stays waiting with no address and that a later launch naming one delivers it once are host tests (`InboxOutboxTests`, `ChatCockpitTests`); `sim-smoke.sh`'s chat section checks only the launch's and the list's no-address lines. With `GRABBER_LINK=grabbernative://chat?thread=<key>` the thread is on screen |
| `GRABBER_CHAT_SEND_FILE=<thread>\|<path>` | that file attached and sent as the bar's paperclip would (`new\|<path>` starts a thread; stories 480, 487, the picker itself is a phone check); use it only with `GRABBER_CHAT_URL`. The fake Cockpit refuses a non-picture as the real one does today. The refusal, with no message after it, is a host test (`InboxOutboxTests`, `ChatFileTests`); the smoke no longer runs it |
| `GRABBER_CHAT_SEND_AGAIN=1` | every refused file on the phone sent again, as a tap on its *Send again* would (story 489); use it only with `GRABBER_CHAT_URL`. That the kept file uploads a second time, is refused again and that still no message follows is a host test (`InboxOutboxTests`); the smoke no longer runs it |
| `GRABBER_ARCHIVE=run` / `GRABBER_ARCHIVE_URL=<url>` | run the stats archive now (story 270), as a background refresh would, sending to that URL. On a simulator or Mac build the URL is required and nothing is sent without it (both reach the tailnet, and a simulator's fixture week and imported trail must never land in the real archive); the run itself (an unreachable Cockpit failing the trail's first page and stopping the run, a locked run recording nothing, a cancel keeping cursors, when the next run is due) is `ArchiveTests` on the host, so `just native-test-sim` no longer runs it |
| `GRABBER_LINK=<url>` | route that link as if iOS had opened it (`simctl openurl` stops at an "Open in Grabber Native?" confirmation a script cannot tap): `grabbernative://timer?preset=10,10,2`, `grabbernative://breathe?breath=5&minutes=2`; the log's `open_url` says how it was read. `LinksUITests` opens real links through iOS instead, cold and warm |
| `GRABBER_DRILL=card_to_position\|position_to_card\|mixed` | open the card screen (`ui` open_card, from: hook) and the trainer's drill over it in that direction, as a tap on *Drill the stack* would (story 220); `just native-test-sim` runs `mixed` and reads the library's `drill` how: open |
| `GRABBER_COCKPIT=open` | open the Cockpit screen, as its row on the home screen would |
| `GRABBER_COCKPIT=browser` | open the Cockpit and, once its first page shows, press the footer's browser button (story 326): the log's `cockpit_open_in_browser` has the address, and an `error` with where: cockpit_open_in_browser follows if iOS would not open it |
| `GRABBER_COCKPIT_URL=<url or page>` | load the Cockpit from elsewhere: a URL (`https://127.0.0.1:65530/` shows the unreachable panel; the panel itself, and that it comes down when the next page loads, are `CockpitPageStateTests` on the host), or the name of a page in the app bundle — `cockpit-bridge-test` speaks the audio bridge the way the Cockpit does and reports the round trip as `getRoute("roundtrip:<microphones>:tagged")`. A Mac build without it loads the real Cockpit; named `https://no-address.invalid`, it loads nothing and shows the error panel, saying so |

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
| Hiding and moving a row on Settings → Launchers changes the home screen; Reset (what holds after a relaunch is `HomeLayoutTests`' on the host) | Simulator | `HomeSettingsUITests` (`xcodebuild … -only-testing:GrabberNativeUITests/HomeSettingsUITests test`), then the `ui` home_rows lines in the log |
| Ink side by side (story 1209): the pen-to-frame numbers, the median, a dropped sample, the readout, the log fields, the web board's address and its probe | Host | `InkLatencyTests` |
| Settings → PaperKit board opens full screen with the tool picker and its **+** showing at once; a finger stroke lands; the **+** offers *Add Shape* and *Add Text* (story 1222: a merged feature Igor can't reach fails the gate) | iPad simulator | `IPadPaperKitBoardUITests`, one launch (skips on a phone) |
| Settings → Ink side by side opens both halves; a stroke on the left half is counted in its corner (the web half needs the real Cockpit, and the feel needs the iPad) | iPad simulator | `IPadInkSideBySideUITests`, one launch (skips on a phone) |
| Three tiles to a line, Recent beside Random, Settings the last tile (#284–#286); the Report a problem tile opens the report sheet (story 252) | Simulator | `HomeGridUITests`, one launch |
| The home screen and the sheet, drawn | Simulator screenshot | launch plain, and with `SIMCTL_CHILD_GRABBER_HOME=settings`, then `simctl io screenshot` |

What the native rungs can and cannot see of the Gym Timer:

| Change | Where it must be verified | How |
|---|---|---|
| Phases, rounds, when each cue and duck hold falls, pause and resume, the catch-up after being away | Host | `TimerEngineTests`, `DeriveTimerStateTests` (the engine takes the clock as an argument) |
| The duck window's opening, holding and letting go | Host | `DuckWindowTests` with a hand-advanced clock |
| The workout in the app's hands: cues on their seconds, one window per boundary, the session taken at START and let go at the end (through the last window, or at once for a finish found on coming back), a stop keeping the session, RESET letting go once, the card pushed per phase, the lit screen following the screen, yielding to breathing or a call (story 191), a workout surviving *Done* (story 188) | Host | `TimerSessionTests`, `TimerAndBreathingTests` with a fake phone and a hand-moved clock |
| Who gives way over the audio session, and who has the microphone: a call takes it from chat's dictation or the report's, anyone else waits for whoever has it, a holder that stopped lets go ([spec](superpowers/specs/2026-11-10-microphone-floor-design.md)) | Host | `AudioFloorTests` (every pair of recorders has a row; a call refuses the timer and breathing the session, story 1071) |
| Two recognizers on the real microphone: a call starting mid-recording, the report's mic during a chat recording; on an iPad, chat's mic beside a board's (after #821) | Phone only | record a message, start a call or shake, `just pull-logs`, read `mic_floor` / `chat_voice` |
| The Custom dials' arithmetic: drag and turn into whole steps, the flick multiplier, the ranges held, the arc's angles | Host | `TimerDialsTests` |
| The drums (and the knobs and arc to try): their look, a swipe and a tap moving Work | Simulator | `GRABBER_TIMER_DIAL=<style>` screenshots; `GymTimerDialsUITests` (taps and a swipe on the Work drum). The haptic ticks are the phone's |
| Custom preset snapping, the LED glyphs and geometry, the turn's margins, the stopwatch, the accessory log's SQL and grouping | Host | `CustomPresetTests`, `SevenSegmentTests`, `DeviceTurnTests`, `StopwatchTests`, `AccessoryLogTests` (real SQLite, in memory, in a pinned time zone) |
| The timer in the app: every cue's file playing in the count voice, nothing about the audio session failing | Simulator | the `timer:` checks in `sim-smoke.sh` (one 15 s workout, judged once its last lines are in, story 1010) |
| A breathing link pausing a workout left running, found paused (story 191, #791); the breathing link closing the timer, the workout giving way and an unknown preset starting nothing | Host | `HomeStackTests`' `testWarmLinksOverTheTimer` |
| Which voice counts: the default, the remembered choice, every voice having all six files | Host, then simulator | `CountVoiceTests` (the files on disk); the `voice:` checks in `sim-smoke.sh` (`voice: adam` by default, the hook's `aussie`) |
| Timer settings: the gear, the three rows and the checkmark | Simulator screenshot | `SIMCTL_CHILD_GRABBER_TIMER_SETTINGS=1 xcrun simctl launch …`, then `simctl io screenshot` |
| Hearing each voice, the sample on a tap, a change taking effect mid-workout | Phone only | choose each voice in the sheet, start 30 SEC, `just pull-logs`, read `ui` count_voice / `timer_voice_sample` / `timer_cue` voice |
| The face, upright and turned | Simulator screenshot | `SIMCTL_CHILD_GRABBER_TIMER=10,10,2 SIMCTL_CHILD_GRABBER_TURN=left xcrun simctl launch …`, then `simctl io screenshot` |
| Music dipping and coming back, a podcast pausing and resuming, cues with the phone locked or the timer left running (*Done* mid-workout), the real turn, the screen staying lit | Phone only | run a workout with music, lock for a round, `just pull-logs`, read `timer_session` / `timer_duck` / `timer_cue` / `timer_interruption` |
| The Cockpit's bridge wire format (parsing, payloads, the injected scripts run in JavaScriptCore), the output roster and re-assert rules, the client tag, which links stay | Host | `BridgeParseTests`, `BridgePayloadTests`, `BridgeScriptTests`, `AudioRoutingTests`, `CockpitPageTests` |
| The Cockpit in the app: page loaded with the tag, `audio.ready`, a device list delivered and acknowledged by the page, one answer per request, the call's screen hold | Simulator | the `cockpit:` checks in `sim-smoke.sh` (the bridge test page); `GRABBER_COCKPIT=open` alone loads the real tailnet page when the Mac is on the tailnet |
| The Cockpit screen's loading, page and panel: the unreachable panel with its reason, a 404 or a failure, Back or Cockpit taking the panel down, which of Back and Cockpit show | Host | `CockpitPageStateTests`; `CockpitBackUITests` keeps one real Back, Cockpit from two deep and Done |
| Real microphones and headsets in the pickers, a route put back after the page's capture starts, AirPods arriving mid-call, the microphone prompt, the screen held through a call, Done and back keeping the page | Phone only | open the Cockpit with AirPods paired, pick them, start a page call, `just pull-logs`, read `audio_route` / `cockpit_bridge` / `keep_awake` |

What the native rungs can and cannot see of links and Shortcuts ([spec](superpowers/specs/2026-10-06-native-links-design.md)):

| Change | Where it must be verified | How |
|---|---|---|
| What every link asks for, its parameters, ranges, bad input, the link each route is written as, the Links screen's list | Host | `AppLinkTests` |
| Where a link lands from every screen, which screen is in front and what a report names, who wins when two links come within the 0.7 s wait (#818), a link home, the warm links over a running timer, what each held tile's choice opens | Host | `HomeStackTests` (the stack's reducer over every link pair), `HoldChoicesTests` |
| A link through iOS opening the app cold and starting the timer, Copy on the Links screen | Simulator | `xcodebuild … -only-testing:GrabberNativeUITests/LinksUITests test`, then the log's `open_url` |
| The Shortcuts actions and Siri phrases, the Action Button, a link from another app or a widget | Phone only | build a shortcut of *Start Gym Timer* (1 MIN), run it with the app closed, `just pull-logs`, read `open_url` from: shortcut |

What the native rungs can and cannot see of the eulogy song ([spec](superpowers/specs/2026-10-07-native-eulogy-design.md)):

| Change | Where it must be verified | How |
|---|---|---|
| Play, pause and resume where it was, a scrub (playing or paused as it was), restart, the ✕, the finish, a call pausing it and holding it off, a refused play's two retries, a song that cannot load or start and letting the audio go, the #370 reload and drift lines | Host | `SongPlaybackTests` with a fake player and clock |
| The song really playing, restart, the small player's pause, open and ✕ | Simulator | `EulogyUITests` (`testThePlayRestartAndTheSmallPlayer`) |
| The blog's launchers and *Open on Suno* leaving for Safari | Simulator | `EulogyUITests` |
| The lock screen's play, pause and scrubber, a call or Siri interrupting, music pausing and coming back, the car's hands-free line | Phone only | play it with music on, lock, use the lock screen, start a call; `just pull-logs`, read `eulogy_song` |

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
| The session in the app's hands: steps on their seconds, each phrase or tone in order, the keepalive for the session (stopped on a pause), the lit screen held and given back, the card per step, Back and leaving letting go, VoiceOver's words | Host | `BreathSessionTests`, `TimerAndBreathingTests` with a fake phone and a hand-moved clock |
| The session in the app: every phrase from its file | Simulator | the `breathe:` checks in `sim-smoke.sh` (one 10 s session) |
| The look of Setup, the circle (running, on a hold, paused) and Done | Simulator screenshot | `SIMCTL_CHILD_GRABBER_BREATHE=open` for Setup; `6,1,off` and a screenshot at ~3 s (inhale), ~8 s (hold) and ~26 s (Done); `6,1,off,3` for the paused circle; then `simctl io screenshot` |
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
| The screen's choices: the Today · 7 days switch and its remembered setting (an unknown value, an unsavable one, an import leaving it alone, the real export's week path), retention and its prune, the naming card (the offer to grow first, *Create new*, closing on a save, staying open on a failure, the default radius), naming a grey dot on the real export, the line under the map and its copyable failure (a refused import, the latest import winning, a re-read keeping it, no database, bad JSON, a failed delete), the export file, only the newest read shown | Host | `PlacesScreenTests` (real SQLite in a temp file, the real export where geometry matters); the rules are the spec's "Who wins" |
| Place icons: the name's guess, the Apple Maps rules (by name, then the nearest), what is remembered, chosen over everything, the twenty symbols existing | Host | `PlaceIconsTests` (the real fixture's Apple Maps answers, as the simulator got them, in the cases) |
| Apple Maps' answers for real places, the icons on the pins, the picker changing a pin at once | Simulator, online | `place_icon` lookup lines in the session log; `GRABBER_PLACES=map` and `open,edit:Home` screenshots; `PlaceIconUITests` |
| A grey dot's card, *Name this place*, the dot becoming a named pin | Simulator | `GRABBER_PLACES=map,unnamed` (and `,name`) screenshots; `PlacesUnnamedUITests` names the place and deletes it again (the fixture copied to `Documents/import-fixture.db` first, as `sim-smoke.sh` does) |
| The permission prompts (While Using, then Always; *Keep Only While Using* turning the switch back off), points with the app in the background and after it was closed (the significant-change relaunch), the blue indicator, an overnight at home read as one stay, the precise fix moving You, Use current at a real place, sharing the export to the Mac and sharing Context Grabber's export into the app, battery with both apps tracking | Phone only | turn tracking on, leave the app closed for a day, `just pull-logs`, read `location_permission`, `tracking`, `location_point` (background: true), `location_fix`, `prune`, `import`, `export` |

What the native rungs can and cannot see of the call:

| Change | Where it must be verified | How |
|---|---|---|
| The call's states, frames both ways, captions, mute, restart, the no-first-frame reset and redial, the zeros re-arm, the probe, the five-second counters, audio not arriving, the problem line (who wins, one mic restart per call), endings | Host | `CallSession*Tests` (fake socket, fake audio layer, a hand-advanced `FakeScheduler`: the jest cases of `callSession.test.ts` translated) |
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

### The chat suite's classes

What `scripts/native/test-chat-ui.sh` runs, one class a line in name order, so PRs that add classes touch different lines;
`scripts/native/test-testing-lists.sh` fails when this list and the script's disagree (story 1502). The chat views
decide nothing: the rules behind each class are host tests, named on its line. A table in a bubble (story 747) is
`ChatTablesTests` on the host: the parsing and what VoiceOver reads (story 770).

- `ChatArchiveUITests`: archiving (stories 307–309, 311, 316, 506): only what the real list shows — the + and the voice button floating over it with the pinned thread on top, a real swipe and its Undo, Select's ticks and *Archive (2)* clear of the buttons with one Undo, the ⋯ menu archiving and going back, and a swipe under Done unarchiving. Which row offers what, Review, Cancel, the counts and lines, a refusal putting a row back, the five seconds, an Undo waiting for its archive's answer and a list read racing a change are `ChatArchiverTests` on the host
- `ChatAskSearchUITests`: searching the asks on *Decisions* (story 1132, against the fake's `/asks/search`): an option's word finds its ask, an answered-only match shows once *Answered too* is ticked, a 502 is a copyable problem, a tap opens the ask's chat with its card; the request, decoding, count line and tap rule are `ChatAskSearchTests` on the host
- `ChatCockpitDownUITests`: the Cockpit down (stories 1604–1606, against the fake's `/fake/down`): a list that never read shows *Cockpit not answering* at once and fills, losing it, on its 15-second retry; an open thread keeps its messages under the banner and loses it at the first poll through; when it shows and its words are `CockpitDownTests` on the host; a thread whose first read is slow (the fake's `/fake/slow`) says *Loading this chat…* until its messages replace it (story 1608, the rule is `ChatThreadLoadingTests`)
- `ChatDecisionUITests`: decision cards (stories 830–832, #878): against the fake Cockpit's three asks, which it holds only once a test posts `/fake/asks`: the chat an ask was filed from marked *Decision waiting* (the ask's `thread`), *Decisions (3)* under Larry's thread, the card answering with what the fake records (`post_to_chat` among it) and giving way to Igor's message *Decided: …* in the thread, the mark and the count going, a refused answer leaving the card with a copyable problem, and with `"long": true` a context longer than the screen opened inside a card that stays at about 60% of the thread, scrolling to its last option with the message bar on screen (story 1603); the requests, outcomes, order, marks and lines are `ChatDecisionsTests` on the host
- `ChatFileUITests`: a delivered PDF as a file row that opens in the system preview (story 1125, on a thread it adds with `POST /fake/file-thread`)
- `ChatImageUITests`: the full-size picture's two ways back in one launch
- `ChatMoveUITests`: *Send to new chat* (story 820, on thread igor2-88g.820): not offered on Larry's message, Igor's moved to a new chat that opens and that Larry answers, and the old chat, opened afresh, keeping Larry's reply and a *Moved to a new chat* line that opens the new one; the fake Cockpit's move lasts its life, so a rerun needs a fresh one, as the script starts
- `ChatNewChatAgainUITests`: the + opens a new chat again after the last one landed and was left by Back, by Home and back to Chat, by another thread, and by two quick Backs to Home, with animations on (#1365, story 1607)
- `ChatNewThreadUITests`: a new chat's typed first Send starts the thread under its first line, the bar holds the next back until it lands, the next goes into that thread and the field empties with the keyboard up (story 274); the voice button beside the + and the + after it opening the ordinary bar with the keyboard up and, against `scripts/native/fake-bridge.py` (port `CHAT_BRIDGE_PORT`, default 8797), a live call keeping the mic from it (#637), the bar's mic beside Send and its picker (#625). Where a Send goes, when it can, the bar's lines, the title and the focus rule are `ChatNewThreadScreenTests` on the host
- `ChatReactionUITests`: holding a message (stories 518–519, 540–541): the menu on Larry's and on Igor's own, *Yes* on the newest, *No* on an older one under its quote, read from what the fake's Larry repeats, and *Quote in reply* filling the bar and sending nothing
- `ChatSkillThreadUITests`: a skill's thread (stories 512–515): pinned under Larry's with no way to archive it, its reply arriving by itself, a failure as a copyable error with 👀 on Igor's message, and the list row naming it
- `ChatThreadSearchUITests`: searching the chat list (stories 1616–1618, #1443, against the fake's `/chat?q`): a title's word shows only that thread, a word only in an older message shows it once the Cockpit answers, *No chats match.*, a failed search keeps the phone's own match under a copyable 502, an emptied box brings the list back, a tap opens the thread; the matching, merge and request are `ChatThreadSearchTests` on the host

### The whiteboard suite's classes

What `scripts/native/test-whiteboard-ui.sh` runs, one class a line in name order, so PRs that add classes touch different
lines; the script lists them one a line too, and the ladder reads its whiteboard classes from the script, so a new class
is its file, its line there and its line here. `scripts/native/test-testing-lists.sh` fails when this list, the
script's and the `Whiteboard*UITests` files disagree, or the script's list is out of name order (story 1502). Every board is on paper (the old canvas went 2026-11-07, its boards 2026-11-22). The suite boots a fresh simulator
once, first, and leaves it booted after (story 980), because keys reach the app only in the first test after a boot
that presses any: the ⌘V test fails on a simulator that has already had one. An iPhone only looks at boards (story 746).
Ghosts staying when the Pencil touches down, a ghost tapped during a Pencil stroke, a second turn after the Pencil lifts
(story 359's rules are `WhiteboardPacerTests`, on the host), undo of a kept ghost, a colour reaching another device
over iCloud, and Larry's marks landing by eye on what he saw are checked on the iPad; how the ghosts sit beside real ink
on the iPad is for Igor's eye. How faint the grid looks, and how it feels at 120 Hz on a big board, is too.

- `WhiteboardBubblesUITests`: opens a board's conversation, switches it to Bubbles and has the fake's `POST /fake/larry-says` add twelve long replies: the bubbles replace the lines, keep the panel to a fifth of the window, show Larry's newest on the left and in view, Bubbles is still picked on a new board after a relaunch, and Lines brings the text back (story 1277, #1384); which messages become bubbles and on which side is `WhiteboardPanelLookTests`, on the host, and the Pencil on the bubbles is the iPad's
- `WhiteboardConnectUITests`: an arrow drawn from one word to another, selected (`GRABBER_WHITEBOARD_SELECT_NEWEST`, as the simulator can't draw a lasso), offers Connect, and Connect leaves one clean arrow in its place (story 910); where its ends land, how it routes and how it follows are `BoardConnectorsTests`, on the host
- `WhiteboardConversationPlaceUITests`: opens a board's conversation, drags its grip down and reads the page moving down with it (the ? button's frame); taps Float and finds the card at the board's top left with the page back up, drags its top edge and its corner and reads it move and grow, relaunches to find it where it was left, and docks it back at its dragged height and double-taps the grip back to its own size (stories 1278, 1272, 1275, 1279, 1307, 1308, #1384); the bounds are `WhiteboardPanelPlaceTests`, on the host, and the Pencil on the card is the iPad's
- `WhiteboardDropRoomUITests`: draws a line, keeps Larry's three marks as one group, draws a second line lower down, taps the group to select it and drags it onto that line: the group stays where it was let go, the line moves straight down clear of it, the line above stays, and one Undo puts both back, read from the sheet's pixels (stories 1169, 973, 974); whether a move is a drop at all, however it was picked up, is `PaperProbePickupTests`, and the room it opens `BoardRoomDropTests`, on the host
- `WhiteboardEraserUITests`: picks the eraser by a tap in the real tool picker and draws on bare paper, reading the strokes from the Send button's label and the sheet's pixels: an eraser kept from the last launch draws no ink from the first stroke, and neither does one picked after BugKit's report sheet (story 1098, #1078)
- `WhiteboardGroupTapUITests`: picks the pen (an earlier launch can leave the eraser picked), keeps three marks of Larry's as one group, taps one of their strokes with a finger and reads the selection from its label (`whiteboard-selection-label`), then drags the group slowly with a hold before the lift and takes the drag back with one Undo, each circle read from the sheet's pixels (stories 947, 1144, #947, bead context-grabber-z93g), and with `GRABBER_WHITEBOARD_FAKE_OFFER=1` a stand-in for the iPad's handwriting popover comes over the tapped group and empties its selection silently, and the board puts the popover away and the group back so the drag still moves it (stories 945, 946, bead context-grabber-4nnh); which strokes a tap reaches is `BoardOutlineTests`, on the host
- `WhiteboardHelpFeedbackUITests`: ? and Feedback, one tap each at the board's top right: the cheat sheet lists the board's gestures and closes; Feedback opens BugKit's report sheet over the board, and once it is logged the board says *Feedback logged ✓*; the top bar keeps the Board menu (stories 950–953, #848)
- `WhiteboardLarryWaitUITests`: waits out the real twenty seconds of a board turn: with the fake's `POST /fake/larry-ops` `{"kind": "slow"}` Larry takes 45 s over one answer, nothing shows before twenty seconds, then *Interrupt* and no *Retry*, and a tap frees the board for a fresh ask (stories 777, 805); with `POST /fake/board-stuck` the newest board thread marks and its next picture is held, so the board says *Larry hasn't got the picture* with *Retry* and *Dismiss*, and a tap on *Retry* lands it (stories 775, 802, 804). `scripts/native/test-fake-cockpit-ops.py` holds the fake's half, and which state offers which control is `WhiteboardLarryWaitTests`, on the host
- `WhiteboardLetteringUITests`: pastes HI through `GRABBER_WHITEBOARD_PASTE` and reads the strokes from the Send button's label: single strokes on a new board, the Board menu's *Real font* redrawing nothing, still on when the board reopens, the next paste as closed outlines, and a new board back to single strokes (stories 1056, 1057); the outlines, a text's own lettering and reword are `BoardRealFontTests`, on the host
- `WhiteboardLinkChipUITests`: has the fake's `POST /fake/larry-ops` `{"kind": "link_reply"}` make Larry's reply end on a Lavish link, and checks the open conversation shows the *Larry: Lavish* chip with no tailnet address and that a tap on it opens the page (story 1127, #1138); how a link reads is `ChatBubbleLinksTests`, on the host
- `WhiteboardListeningUITests`: Larry holds on the board's picture with *waiting for more*, so the turn's clock stops, an ear and his words start the note's line and the panel's chip, and his next row takes them away (story 929); what counts as a hold is `WhiteboardLarryListeningTests`, on the host
- `WhiteboardOnPaperUITests`: a new board is a real board on paper (stories 590–612); a board drawn on the old canvas being dropped (story 1204) is `BoardIndexTests` on the host
- `WhiteboardOutlineUITests`: checks the gestures reach paper: a paste landing selected and its Delete, a margin tap making a header and a tap on its mark folding it, a Send on the folded board giving Larry the section whole and shaded with `picture_folds` beside the frame while the iPad stays folded (story 900, #1013), a hold bringing the menu with a margin drag making room (stories 853, 855, 858, 872, 874), a hold on ink offering Select and Delete, Delete taking only that line, and a hold off ink offering no Delete (stories 1186, 1187), and [header Undo and Redo](stories/10-whiteboard-outline.md#user-story-1179), including Undo after removing a folded header; where things land, how a section ends and what a fold moves are `BoardRoomTests` and `BoardOutlineTests`, on the host
- `WhiteboardPanelScrollUITests`: opens a board's conversation and has the fake's `POST /fake/larry-says` add more of Larry's long replies than the panel holds: the panel and the paper under it keep their frames, a reply after a finger scrolled up leaves it on the older messages, and scrolled back to the bottom it follows the newest again, read from the panel's VoiceOver label (story 887, bead context-grabber-97s); when it follows is `WhiteboardNoteTests`, on the host, and what the mic hears (story 1184) is the iPad's, as no hook keeps the board's mic on
- `WhiteboardPaperGhostsUITests`: with `WhiteboardPaperLinesUITests`, what paper shows: ghosts, a tap on one showing Keep and Dismiss and each doing its part, a tap off them dismissing nothing and giving a finger its pen back, or not with the Pencil in use (stories 825, 1152, 1153; the rules are `WhiteboardMarkChoiceTests`, on the host), and undo on the sheet
- `WhiteboardPaperLinesUITests`: ruled lines, the grid and page lines on every colour read from the screen's pixels, a colour and its lines staying with the board, and the first stroke after the Board menu (stories 434, 523, 538, 613–635, 652–657, with `WhiteboardPaperGhostsUITests`)
- `WhiteboardPaperPasteUITests`: what a page adds to a paste, through hooks, as XCUITest's taps never reach the system's paste button (stories 637–650)
- `WhiteboardPasteUITests`: a clipboard set by the test reaches a board on paper through ⌘V and one ⌘Z takes it all back (keys reach the app only in the first test after a boot that presses any, so this is the one test that presses them), and `GRABBER_WHITEBOARD_PASTE` brings a stroke a letter, the pause and the emoji note (stories 390–393, 638, 639); the layout, the caps and which note the bar shows are `WhiteboardPasteTests`, on the host
- `WhiteboardPlaybackUITests`: picks the pen (an earlier class can leave the eraser picked), draws three strokes, taps *Play* and reads the bar's status (*Stroke 3 of 3, paused* at the end), taps the second stroke's element to go back to when it began, steps the speed from 1× to 1.25×, plays to the end and skips 10 s back to the start, checks no *Writing above/below* label shows with all three strokes on the screen, then checks *Done* leaves the board as it was: the same strokes, saved, the same Undo and Send not used (stories 954–958, bead context-grabber-3tdv, #1169); the timeline, the pauses, the shared moments and the playhead are `BoardPlaybackTests`, and the stroke being drawn above, below or on the screen `BoardPlaybackOffScreenTests`, on the host, and the Pencil's real pace and a big board's frame rate are the iPad's
- `WhiteboardQuestionUITests`: has Larry put a question card on a board through the fake's `POST /fake/larry-asks`, answers it with an option through the fake's `/act`, and checks the card keeps the question over the answer, opens read-only and folds to a chip (stories 880, 882, 883, 885), and hides a card to its '?', brings it back and drags the '?' and the card without opening the popup (stories 1273, 1169, 1274); where cards land, the open asks naming a board, the answers fetched from `GET /ink/answers` and the eraser are `WhiteboardQuestionsTests`, on the host
- `WhiteboardQuietTapUITests`: finger taps on a board, with the Pencil seen and ink and text on the clipboard, bring up no system *Paste* or *Select All* (story 1276, #1385). The simulator never brought that menu up even before the fix: on the iPad it comes with Only Draw with Apple Pencil on, which a simulator can't set, so the iPad's log (`tap_menu_quiet`) is what shows the fix
- `WhiteboardReviewUITests`: a stroke, then the session's review after `GRABBER_WHITEBOARD_REVIEW_IDLE` seconds with `GRABBER_WHITEBOARD_REVIEW_FINDING` standing in a Keep that changed the pen: the note *Reviewed · 1 to look at*, the finding listed with *Copy* and *Show me*, the step's before and after, and the note gone once opened; a clean session after idle showing no note with no review row in the Board menu, and a board left right after writing whose review, started as it closed, shows when it opens again and goes with the next stroke (stories 1237, 1238, 1240, 1242–1246); the checks are `BoardReviewTests` and the recorder `BoardReviewRecorderTests` (a board opening with ink, erase, Undo and Redo, folds, paste, Larry's ops, a drop's room, owners put apart), on the host, and a real session reviewed after idle is the iPad's
- `WhiteboardRewordUITests`: a kept text made by To text (the fake reads every picture as "hello"), a finger tap on it, and its words changed or emptied in the field that opens where it is (stories 940, 941); the words, the wrap and Larry's event are `BoardRewordTests`, on the host
- `WhiteboardRowDeleteUITests`: the boards list's delete (stories 396, 399)
- `WhiteboardScratchOutUITests` uses three launches. The word scratch-out flashes and fades, Undo restores the word, and Redo takes it again so it stays gone when he writes on (stories 890, 1050). On a fresh board in the same launch, the eraser's sweep produces neither a flash nor a message (1108). The other launches check that a scratched-out fold stays gone (905) and that a zigzag on an empty board goes with a message, leaving zero strokes until Redo restores it (1051). `GRABBER_WHITEBOARD_ZIGZAG` reads the stroke that brings the board to that count as a fast zigzag (#999). `WhiteboardScratchOutTests` checks what counts as a zigzag on the host.
- `WhiteboardTheirsTapUITests`: keeps three marks of Larry's one at a time with *Keep*, taps the first with a finger and deletes the selection, which takes that circle alone, the other two staying, and one Undo puts it back, read from the sheet's pixels (story 1140, #1171); a tap on one circle of his reply of three reads *Keep group*, and *Dismiss group* takes all three (stories 1285, 1286)
- `WhiteboardTitleRenameUITests`: taps a board's name in its bar and renames it there: the bar and the list's row take the name, a long name stays cut short with every bar button there, the next stroke draws and the Board menu still opens and closes, and another device's board has no tappable name (story 1160)
- `WhiteboardToTextUITests`: the hold menu's To text on the selected ink (`GRABBER_WHITEBOARD_AFTER_INK=select`), nothing beside it, its picture read by the fake's `POST /ink/to-text`, and the words in the ink's place, or a copyable problem with the ink left alone (stories 920, 921)
- `WhiteboardTurnUITests`: the whiteboard turn against the fake Cockpit, Claude's ghosts from `POST /whiteboard/suggest` and Larry's marks over chat (cockpit#85; the fake answers a message with a board's picture with a row of marks, and `POST /fake/larry-draws` has him draw unprompted): a stroke and a pause bring one ghost, *Send to Larry* brings his two beside Claude's one with no further tap, unprompted marks replace his, a reopened board shows his newest set, a dismissed set stays gone on the next look and the next open, and words on an empty board bring a ghost and reach the Cockpit in the turn's text (stories 344, 345, 349, 357, 360, 371, 380, 382, 383, 386, 388), read from the *Ask at my pauses* accessibility label (the ghosts showing) and the Send button's label (the strokes drawn); `testAPauseBringsAGhostAndLarryTakesATurn` keeps a screenshot of Claude's and Larry's ghosts in its result (story 371), and `testAskAtMyPausesOffAsksNoOneOnALarryOrAHaikuBoard` counts the fake Cockpit's pause requests via `GET /fake/turns` and reads the UI through accessibility ([story 1171](stories/10-whiteboard-boards.md#user-story-1171)). The turn's rules are `WhiteboardGhostTurnsTests`, on the host: Claude's fade and Larry's stay, each author's set replacing only their own, a stream's marks landing one at a time, a Cockpit that doesn't stream, whether the switch gates pauses and speech, a stale answer, words held for the next turn (stories 351, 357, 358, 367, 370, 373; the fake's `/many` and `/plain` addresses are left for a look by hand); a reading broken part way is `WhiteboardStreamTests`, on the host
- `WhiteboardUndoRedrawUITests`: a kept group dragged down near Igor's lower line and undone, with `GRABBER_WHITEBOARD_UNDO_LOOK=miss` so the first look after the Undo takes what it checks as missing: the strokes are taken out and put back, the next look finds them whole (`whiteboard-undo-look` reads `missing,whole`, one heal), both halves of the line are drawn, and Redo and Undo still take one step each (story 1203, bead context-grabber-9bll); which pieces near a change are looked at is `BoardUndoRedrawTests`, on the host. The simulator's own miss, a tile left blank after an Undo, shows only now and then


## Igor's pen touches replayed on the Mac: `just touch-fixture`

A gesture bug on the iPad (a scratch-out that stayed ink, a shape that didn't snap, a margin hold that drew) is settled on
the host against Igor's real stroke (stories 1104, 1105). The iPad's session log keeps each drawing touch's path
(`board_touch` path) and the stroke each gesture judged (the `path` on `scratch`, `shape_snap`, `shape_snap_none` and
`hold_stroke`; docs/debugging/whiteboard.md). After `just pull-logs`:

```bash
just touch-fixture ~/tmp/agent/grabber-logs/ipad/<log>.jsonl [--board <id>] [--all]
just touch-fixture <log>.jsonl --out native/ContextCore/Tests/ContextCoreTests/Fixtures/touches/<name>.json
```

- **Each case** prints what the iPad decided and what the Mac decides for the same points, the board's own rules
  (`BoardTouchReplay`); DIFFERS marks a case where they part, which for a gesture's own stroke means the rule changed
  since that build.
- **The fixture**: `--out` writes the cases with `expect` as the Mac says now. Edit a case's `expect` to what Igor
  meant and `BoardTouchReplayTests` fails until the rule does; that is the fix's test. Name the case for what Igor drew.
- **Gestures only, by default**: scratch-outs, snaps, margin holds and touches held still at the lift. `--all` takes
  every pen touch, writing too: a committed fixture is in a public repo, so keep writing out unless it is the bug.
- A scratch-out's verdict here is its shape and speed; whether ink was under it needs the board's strokes, as in
  `Fixtures/scratch-out/`.

## The Board Lab: a whiteboard UI test without the whole app (story 1501)

`BoardLab` is a second app target, simulator only (`native/project.yml`, plan
`docs/superpowers/plans/2026-11-22-board-lab-plan.md`). It is the app's own sources with their own `@main` in
`native/BoardLab/`, and its only window is the boards list. It has the same `AppModel`, board and launch hooks, but
no home window and no scene-phase work. A whiteboard UI test class moves to it by changing which bundle it is in: its
file stays in `native/UITests/`, leaves `GrabberNativeUITests`' sources and is listed under `BoardLabUITests`, and
the ladder's `board_lab_classes` and `test-whiteboard-ui.sh` call it `BoardLabUITests/<Class>`. The GrabberNative
scheme runs both bundles. Today `WhiteboardEraserUITests` and `WhiteboardTitleRenameUITests` are in it. Measured on
the iPad simulator, the lab saves about 1.2 s a case for about 4 s more build; the plan has the table.
`GRABBER_LAB_SESSION=<name>`, with `GRABBER_CHAT_URL` set to the fake Cockpit, has the fake play that recorded session
(story 1174) on the lab's first board message.

## A view's preview as a picture: `just render-preview` (story 1625)

`just render-preview App/Breathe/BreatheView.swift ~/tmp/out.png` renders the file's first `#Preview` (a third argument
picks another, counting from 0) on the iPad Pro 11-inch (M5) simulator and copies the picture to the path. It goes
through Xcode's own tool service, `xcrun mcpbridge` (JSON-RPC over stdio): no Xcode window, no MCP client. A cold render
builds the app (35-105 s on the M5 Pro, depending on load); a warm one takes about half a second. A render runs in a
build lane, like the other simulator rungs, and waits for one when every lane is busy.

Once per Mac, Igor types (it needs sudo): `xcrun mcp-server status` shows headless mode and what is pending;
`sudo xcrun mcp-server allow-folder ~/gits/context-grabber` and `sudo xcrun mcp-server allow-folder ~/.treehouse` let it
serve the main checkout and every slot; `sudo xcrun mcp-server approve <id>` approves the caller, which is always
`/usr/bin/timeout` because the script puts it in front of the bridge. A project under `/private/tmp` is refused outright,
so render from a checkout, not the scratchpad.

The screens agents change most have `#Preview`s on offline fixtures that never reach the network, the Cockpit or
HealthKit (`native/App/Previews/`, Debug builds only): `AppPreviews.swift` holds the chat list (0), the decision card
(1), the Decisions row and line (2) and the home tiles (3); the chat's private thread rows (0) and message bubbles (1)
are at the end of `ChatViews.swift`. The whiteboard's menus and hold menu need a live board model and PaperKit, so
they have none yet. For another screen, add a `#Preview` to its file, on `PreviewFixtures`.

## The board's rules as WebAssembly: `just wasm`, `just wasm-test` (story 1503)

The Cockpit's web board runs BoardCore compiled for WASI (spec
`docs/superpowers/specs/2026-11-22-board-rules-on-the-web-design.md`, which holds the interface the Cockpit codes
against). `just wasm` builds the `BoardWasm` reactor release and stripped to `native/Build/wasm/BoardWasm.wasm` and
prints its size and sha256; `just wasm-test` builds it and replays the recorded board sessions through it under node,
with the checks `BoardSessionReplayTests` makes natively, plus a board loaded whole against the same board loaded in two
halves, a hand-worked outline's rows and folds (story 1508), a hand-worked paste and drop (story 1513), a hand-worked board's Pencil and finger holds (story 1620), and a
hand-worked connector's route round a box (story 1621), a hand-worked batch of Larry's ops (story 1622), a hand-worked board's lines that look like headers (story 1267), a hand-worked board's units and rows, their edges exact (story 1263), a hand-worked fold opened over ink written under it (story 1264), a hand-worked fold erased whole (story 1265), a hand-worked Keep all and Tidy overlaps (story 1163), a hand-worked run of the board's applier (story 1164), and a hand-worked zigzag and snapped stroke (story 1165). Both need a Swift toolchain with its wasm SDK (`scripts/native/build-wasm.sh` lists the settings; a box
whose `wasm-ld` needs extra libraries passes `LINUX_LIB_DIR` as for `just test-linux`), and `wasm-test` says it
skipped without one. Both run on Larry's Linux VM, not the Mac (AGENTS.md, "Which machine builds what"): push the
branch and ask Larry on the lead thread, and he posts the result. Neither is on a rung: a release build of the board for WASI takes minutes. Run them when a
change touches BoardCore's imports, the module's exports or the board's replay. BoardCore must keep building for
WASI: no `URLRequest` (FoundationNetworking) and no atomic file writes in it; the HTTP requests live in ContextCore.

## Larry's board changes on a copy of a board: `just board-ops`

Larry checks what a batch of his changes will do to Igor's board before he sends it, and an agent reproduces a
board-ops bug, on the Mac with no simulator, in seconds (#936, story 990). The board's own applier and planner
(`BoardOpApplier`, `BoardOps.plan`, through `BoardReplay` in ContextCore) run on a snapshot, and the
`board-ops-harness` tool draws the result:

```bash
just board-ops --board <snapshot.json> --ops <batch.json> [--ops <next.json>] [--keep id,id] [--out <prefix>]
just board-ops --board <snapshot.json> --ops <reply.json> [--tap x,y] [--keep-all -|<reply id>@<picture ms>,…]
```

- **The snapshot** is the board's strokes JSON, the body the board posts to `POST /whiteboard/strokes` or the
  Cockpit's stored copy of it (`whiteboard-strokes/<board>/<picture_id>.json`), kept texts as `kind: "text"` entries.
  It may add `rev` (the board's revision; without it the first batch's `base_rev`), `ghosts` (his text ghosts still
  showing, each an `add_text` op as he sends it) and `touched` (`[{rev, ids}]`: what Igor moved or erased since an
  older look, so a batch from that look rebases or is refused stale exactly as on the iPad).
- **A batch file** is the `ops` object of his message, the whole chat message, or a list of either. `--keep id,id`
  between them is Igor tapping Keep on those ghosts. Steps run in the order given.
- **A reply with marks** (#941): his chat message with `shapes` shows them as his ghosts, placed by the message's
  frame as the iPad places them, and tries a tap on each: the result's `taps` say which mark each chose, and
  `unreachable` (ringed in red on the picture) names a mark a tap can't reach with the mark that takes it instead.
  `--tap x,y` is a finger tap at a board point. `--keep-all -` is Igor's Keep all (#942, bead context-grabber-yqau):
  every mark showing becomes ink, each reply of two or more under the one group `reply-<id>`, which a later batch can
  move or erase by that name, and his text ghosts become kept texts, making room for what they land on (#938).
  `--keep-all <reply id>@<ms>,…` keeps them as if each reply's picture was taken at that unix ms (#894). A step file
  can also specify `{"keep_all": {"reply-id": 1763432004500}}`, with `{}` for unknown picture times. Each entry must
  give a nonempty reply ID and a signed 64-bit integer timestamp. Repeated reply IDs in the flag and invalid entries
  fail the replay.
  `covered` counts distinct things made after the corresponding picture that a reply's marks sit on. `room`
  describes the push for those collisions or for change text landing on existing ink. The saved board records the
  resulting page count and the names touched by that push for later batches.
- **Out**: `<prefix>.png` (the board after, with what each step moved in orange, drew or kept in green, erased in red
  dashes, his ghosts in purple dashes, and each step's `op_result` on top, a missing id in capitals),
  `<prefix>-before.png`, `<prefix>.result.json` (each step's `op_result` and the names it moved, erased, drew and left
  as ghosts) and `<prefix>.board.json`, the board after, to replay his next batch on. The default prefix is
  `~/tmp/agent/board-ops/replay-<time>`. Where there is no CoreGraphics (Larry's Linux box, #943), the
  pictures are `<prefix>.svg` and `<prefix>-before.svg` instead, the same marks, colours and words; the result's
  `picture` and `picture_before` name whichever was written. With no fonts there, a reply's labels are dropped, so
  its mark ids and taps after the first label are not the iPad's (the marks step's `why` says so). `just test-linux` builds the harness and replays the
  Judge batch to an SVG.
- The fixtures in `native/ContextCore/Tests/ContextCoreTests/Fixtures/board-ops/` are copies of board 13f700bf as
  the night of 2026-11-17 left it, with his batches as he sent them (#937–#939).
- **A whole recorded session** (stories 1182, 1183): `just board-ops --session <name>` replays one of the Cockpit's recorded
  board conversations (its board contract, *Recorded sessions*): each of Larry's batches on the board as it stood when it
  arrived, beside the answer the iPad sent on its next turn, and each turn's board fields as the Cockpit's hint put them;
  `mismatches` lists where today's board and the recording part. `BoardSessionReplayTests` pins all four.
- **The sessions are vendored scrubbed**, never raw (the repo is public; they are Igor's writing):
  `scripts/native/board-sessions.py vendor [--sha <cockpit sha>]` fetches them into a temporary directory outside the
  repo, turns every free text into x's and every stroke into a straight line across its box snapped to a 40-point grid, refuses a field it doesn't
  know or a word left readable, and writes `Fixtures/board-sessions/` with `SOURCE.json` naming the commit. A new
  contract version or session is a re-vendor and a review of the diff. `just test` checks the copies
  (`test-board-sessions.py`).
- **On the simulator**, the fake Cockpit plays a session back (story 1174): `POST /fake/session {"name": "<name>",
  "thread": "<key>"}`, then the board's turns on that thread get Larry's recorded replies and receipts in order
  (`test-fake-cockpit-session.py`).

What it doesn't show: the Pencil's hold (a batch always applies at once), folds (a snapshot's `folds` are left out),
connectors' routes, and anything PaperKit itself does; those are the simulator's (`WhiteboardPaperGhostsUITests`) and
the iPad's.

## What PaperKit itself does: `just native-test-contracts`

The whiteboard leans on PaperKit and PencilKit doing things their documentation doesn't promise, and 14 of its 18
platform fixes were behaviour nobody knew about until Igor's iPad showed it. `native/ContractTests` pins that
behaviour on real PaperKit: a test bundle hosted in the app, on an iPad simulator in a build lane, each test setting the
paper up as the board does (its feature set and inks, the tool picker shown) on its own window. No retry: a contract
that fails once has moved. Run it after every Xcode or iOS update, and with any change to how the board drives PaperKit.
When one fails, the platform changed: read what the board does with that behaviour before changing the test.

What it pins (iOS 27.2 simulator, 2026-11-21):

- **The tool.** A pick made in code moves the picker's `selectedToolItem` and tells its observers at once, while the
  paper's `drawingTool` stays the pen, half a second on (#1078). Setting `drawingTool` leaves the picker where it was.
  The picker offers the board's eight inks, an eraser and a lasso.
- **Setting the markup.** A set is held at once, told to the delegate at once and once, and is no undo step. A set
  built from an older markup than the one held (a sibling of it, with ink of its own, or ink taken away) is refused
  whole, and the held one's newer ink goes too: the paper falls back to what both were built from (#999, #1015). A set
  built from `paper.markup` as it is now, a markup it held before, or a new one built from nothing is held, from inside
  PaperKit's change callback too. A set that takes the selected stroke leaves its id selected.
- **Undo.** A step the board registers on PaperKit's undo manager says its own name, past the turn.
- **Ink.** Every ink reads its kind through the Objective-C `inkType` key, through a markup and the paper; an ink of a
  kind the Swift enum lacks (#1083) rides them unchanged, and a drawing holding one writes but is refused when read
  back ("from a future version").

What needs a real touch is `PaperKitTouchContractUITests` (story 1020), in the same recipe and also with no retry: a UI
test that launches a bare PaperKit paper over the app (`GRABBER_PAPER_STAGE`: the board's feature set, inks and picker
and its own touch watcher, none of its handling) and touches it with a finger, reading what PaperKit did off the stage's
state line. It pins:

- **A stroke's undo name.** A finger's stroke is one step on PaperKit's undo stack named *Add Strokes*, the name the
  bar's Undo reads as plain *Undo* (#965), and its lift reaches the watcher as ended.
- **Cancelled against ended.** A touch called off while it is down (the stage takes its view out of the window and puts
  it back, as the system calls off a palm) reaches the watcher as cancelled, its phase cancelled, and never also as
  ended: the fold erase reads that to take no fold by its marker (#1105).
- **A finger tap's dot.** With the finger set to select, as the board sets it while marks show, a tap still leaves a
  dot, and PaperKit's own undo takes it back: what the board's tap-dot take-back rests on (#883).

The ladder runs both whenever a change drives PaperKit (the map above). What none of it sees: the Pencil, and a pick
made with a finger in the tool picker (#1078's, the iPad's).

## A worktree that keeps its build

Every recipe builds into the worktree's own `native/Build` (about 500 MB each), and each new worktree left one
behind: 24 GB across worktrees on 2026-11-09 (#803). The fix is to stop making new worktrees. The win is mainly
bounded disk and the seeded device ids; speed gains are modest. Measured on this Mac with Xcode's machine-wide caches
warm: a first build in a new slot took 39 s, a rebuild 6 s, and a returned slot re-leased for a new branch with one
file touched 7 s. [treehouse](https://github.com/kunchenguid/treehouse)
keeps a pool of twelve (`treehouse.toml`; two per build lane at the M5 Pro's six, story 785) under `~/.treehouse/`, and a slot is leased, returned and leased again:

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
- **A full pool is an error, not a thirteenth worktree.** `treehouse status` shows who holds what; return one.
- **Disk is bounded at twelve build folders.** For a slot's build alone, delete its `native/Build` (the next build
  there is cold; also the cure for a build that fails only in one slot). `treehouse prune` lists every idle returned
  slot and `--yes` deletes them, warm builds included, so it is for reclaiming disk, not for tidying.
- **Slots share nothing.** Each has its own Swift package checkouts: one shared folder
  (`-clonedSourcePackagesDirPath`) would let a branch that moves a pin switch the checkout under another slot's
  running build, and a device build takes no `build.lock` to keep the two apart. A slot fetches them once.

## How long a change takes: `just lead-times`

`scripts/lead-times.py` (story 828) reads the last 120 merged PRs through `gh` (`--count` for more or fewer), the issues
they name, the deploys ledger and the ladder logs, and writes `data.json` and a page, `index.html`, with each stage's
minutes: asked, first commit, opened, merged, on a device. The ledger is `LEAD_TIMES_DEPLOYS` (default
`~/tmp/agent/notes/lead-times/deploys.jsonl`), the ladder logs are `*ladder*.log` in `LEAD_TIMES_LADDER_LOGS` (default
`~/tmp/agent/notes`), and the output goes to `LEAD_TIMES_OUT` (default `~/tmp/agent/notes/lead-times`), never the repo.
Only a cable or network install (`cable`, `network`) or a build TestFlight offers (`testflight_available`) counts as on
a device; an upload
(`testflight_upload`) has its own column (#1038).

The ledger is written by `scripts/native/record-deploy.sh <phone|ipad|testflight> <sha> [kind]`: `just
native-run-device` records each cable install, `just deploy` each network install, `just ota` the build it posts
(`ota_posted`, story 1511), `just testflight` its upload, and the day TestFlight offers the build
is recorded by hand with `testflight_available`. Until 2026-11-21 the recorder was a mac-driver script that was never
checked out on this Mac, so no install had been recorded.

## Where a change's test time goes: the run ledger and `just ladder-report`

Every climb of the ladder (not a dry run) writes its events to the run ledger, `LADDER_LEDGER` (default
`~/tmp/agent/notes/ladder/runs.jsonl`; `off` writes none), one JSON line each, under one run id the climb prints as
`ladder run id: …` (#1038, story 1016):

| Event | What it holds |
|---|---|
| `start` | the source sha, branch, base and fork point, the changed paths, the classes chosen by group (chat, whiteboard, places, the iPad's, the rest), the smoke sections, the iPhone and iPad simulators, the host-only and unmapped paths, and the flags |
| `lane` | the rung, the lane it got, and the seconds from asking to holding it (the lock and the other xcodebuilds) |
| `device` | the simulator a step ran on, and whether it is the phone's or the iPad's |
| `step` | each step of rung 2 and the Mac build: its seconds and exit status; a build step says whether the lane's build folder already held a build (`warm`) |
| `destination_skip` | an iPad class that skipped on the iPad (#1037) |
| `rung` | each rung's seconds, its wait and its status, or that it was skipped |
| `finish` | `pass`, `fail`, `unavailable` (exit 75: a locked screen, a busy lane), `timeout` or `interrupted`, with the rung it first failed on. A climb with a start and no finish (a crash, a reboot) is the report's `censored` |

The UI test timing lines (`ui-timings.jsonl`) carry the climb's run id, so a case retried by xcodebuild joins its climb.
`just ladder-report` (`scripts/native/ladder-report.py`) reads the ledger, the older climbs' logs (`*ladder*.log` in
`~/tmp/agent/notes`; a log naming a run id the ledger has is counted once), every slot's timing lines and the deploys
ledger, and prints each climb (its area, attempt, outcome and first failure, queue and execution seconds, cases
retried, coverage skipped, warm or cold build, and when it first reached a device, or that none is known, or that it was
only uploaded), then by area the climbs, median and p90 queue and execution, first-pass failures, skipped coverage, the
share with a known delivery, and the rank: climbs times avoidable lane minutes (the queue, a failed, timed-out or
interrupted attempt's execution, and retried cases). A climb that failed on cases that passed only on their retry and
nothing else is `flaky`: a failed attempt, its flakes and quarantined cases named (story 1017). Retries and flakes
are read from each logged run's states, not the lines' old `retry` flag, which also marked a repeat asked for. A climb that could not run (a locked screen, interrupted, never
finished) is counted apart and does not use up an attempt. A climb whose `start` line is missing (dropped, or interleaved away by another lane's
append) is still listed, under area `unknown` and marked `(no start line)`. The timing lines no climb claims are summed by class, which is where the flakes'
minutes show, with each class's passes only on retry apart from its repeats. `--sample N` takes the latest N climbs; `--json` writes it all. `scripts/native/test-ladder-report.sh`
pins it on a fixture with a retry, a flaky climb and a quarantined flake, a wrong-device skip, a missing deploy, an
upload alone, a censored climb, a failure on the rerun after a locked screen, and a climb with no start line.

## Walking the store: `just walk` (story 1628)

The walk-the-store skill's Mac half. `just walk [OUT]` runs each rung once: the lint, ContextCore's `swift test` (a red
case gets one serial retry), each script check a story names, the Mac build, and the simulator rung with every UI class
(`test-ladder --all --rung 2` with `LADDER_KEEP_GOING=1`, so a red class doesn't stop the rest); the rung gets 240 minutes, `LADDER_SIM_MINUTES`, since every class takes longer than the usual 60. The whiteboard and
chat suite scripts aren't run a second time: each reads as the simulator rung's whiteboard or chat classes step, and
neither counts toward `just test`. It writes
`OUT/checks.json` and runs the skill's `walk.py judge` (set `WALK_PY` if the skill isn't installed). Refs only the Linux
VM runs (wasm, the Linux rung, board-ops, node and web checks) and recipes that aren't checks (installs, uploads, bug
filing) are written skipped with the reason. A named class, test, recipe or script missing from the tree is red. The
newest walk is `~/tmp/agent/walks/context-grabber/latest`, the next walk's `--previous`. File reds with
`walk.py file-reds OUT/walk.json --apply --parent <bead>`; a first walk files nothing (its reds are the baseline).

## The phone

How a build gets to a device at all, the cable and network install, the over-the-air `just ota` and its watcher,
signing and adding a device, is [DEPLOYING.md](DEPLOYING.md).

`just native-run-device` builds, installs and launches; `just pull-logs` brings back the session logs, reports and
crashes. What only the phone can show: HealthKit and CoreLocation (and CoreLocation's silence while the phone is
still), the audio session — the Gym Timer's ducking window, a podcast resuming, echo cancellation on a call, the
keepalive with the screen locked — the Live Activity and the widgets, Shortcuts and Siri, the Cockpit page over the
tailnet, and everything visual on an OLED.

**Log before theorizing.** When a phone symptom is unexplained, the first change is a log line, not a fix. Every
session log and report carries the build it came from. [DEBUGGING.md](DEBUGGING.md) says what each holds and how to
get it.

## TestFlight: `just testflight`

The cable install stays the everyday path. `just testflight` is the lane beside it, for a build that has to reach the
phone or the iPad without the cable ([spec](superpowers/specs/2026-11-20-testflight-lane-design.md), stories
1011–1013, #1012). From a clean checkout of the commit to ship, it archives the app in Release with the same build
stamps as the device build (the commit, the branch, BugKit's commit), signs the app, the widgets and the share
extension for App Store distribution, and uploads the package with an App Store Connect API key. The version is the
project's (2.0.0); the build number is `git rev-list --count HEAD`, so it grows with main and points back to its
commit (`--build-number <n>` or `BUILD_NUMBER` overrides it; App Store Connect refuses a number it has seen). Uncommitted
changes stop it before building (`--allow-dirty` overrides, and the BugKit commit then says `-dirty`). It takes the
Mac's one signing lock and BugKit's screen-lock guard, as `native-build-device` does. The archive and the package
stay under `native/Build/Archives` and `native/Build/Export`, named by version, build number and commit; the logs are
`native/Build/logs/testflight-{archive,export}.log`.

- `just testflight --export-only`: the archive and the signed package, no upload and no key. It is how a Release-only
  compile failure or a distribution-signing problem shows up before the day it matters.
- `just testflight --dry-run`: checks the key and the checkout and prints the plan. The host rung runs
  `scripts/native/test-testflight.sh` against it: each refusal above, the plan, and that the key's values are never
  printed.

**The key** comes from the environment, `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_PATH` (the `.p8` file), else from
the same three as `KEY=value` lines in `scripts/native/testflight.local`, which git ignores. The repository is public:
none of the three is committed, and the lane refuses a key file inside the checkout. Without them, the upload stops
before building and names what is missing.

**Once, by Igor:**

1. [App Store Connect](https://appstoreconnect.apple.com) → Apps → + → New App: iOS, bundle id
   `com.idvorkin.grabbernative` (registered already by the development builds), any name and SKU. The widgets
   (`.widgets`) and the share extension (`.share`) need no app records of their own.
2. Users and Access → Integrations → App Store Connect API → Team Keys → +: a key with the App Manager role. Download
   the `.p8` (it downloads once) to somewhere outside the repository, such as `~/.appstoreconnect/private_keys/`, and
   note its key id and the issuer id shown above the list.
3. Put the three values in your shell's environment or in `scripts/native/testflight.local`.
4. TestFlight → Internal Testing → +: a group with yourself in it, so every processed build is offered to the phone.
5. Archive and export use Xcode's signed-in account (Settings → Accounts), as the device build does; the first export
   lets Xcode create the team's cloud-managed Apple Distribution certificate and the App Store profiles.

**What a TestFlight build gives up:**

- **`just pull-logs` can't read it.** A distribution-signed app's container is closed to `devicectl`, so its session
  logs, reports and crash files stay on the phone. Use the cable install to debug.
- **Reports and crashes go through BugKit's iCloud delivery, to the production database.** The Mac's listener reads
  the development one, so until BugKit's report schema is deployed to production and the Mac has a production reader
  (BugKit's `docs/integration.md`, "Mac reader and listener"), a TestFlight build's shake reports and crashes do not
  reach `~/tmp/agent/bugs/inbox.jsonl`.
- **Apple's processing takes 5–30 minutes** after the upload before TestFlight offers the build.
- **`#if DEBUG` code is absent.** Checked 2026-11-20 for #1012: the only such code is the Cockpit page's Safari Web
  Inspector (`isInspectable`), a development aid. The launch hooks are read from the launch environment, which a
  TestFlight install never sets; BugKit and ThinkACard have no debug-only code. A new `#if DEBUG` must be something
  the app can do without.
- **It is optimized.** Code that only works unoptimized (a timing that depended on it) shows up here first;
  `--export-only` is the cheap way to look.
