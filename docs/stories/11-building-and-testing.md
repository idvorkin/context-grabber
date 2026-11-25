# Building and testing

How a change gets from a commit to Igor's phone quickly, without giving up the evidence that it works. Written for this
app and meant to be shared with Igor's other apps once it has proved itself here.

The numbers these stories start from (2026-11-04, the whiteboard's UI tests on the iPhone 17 simulator): 56 tests in
about 25 minutes, one at a time, about 27 seconds each. Almost none of that is compiling or moving between tests. Of the
steps timed, about a third is waiting for the app to go idle, a fifth starting and stopping the app, a fifth finding
things on screen, and a sixth waiting for things to appear.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 670:

- **Summary:** Most of what a change needs proved is proved on the Mac, in seconds
- **Status:** not implemented; bead `context-grabber-3k6`. Moved to host tests so far, each with the UI or smoke checks that only repeated it cut: the whiteboard turn's rules (`WhiteboardGhostTurnsTests`, [3985337](https://github.com/idvorkin/context-grabber/commit/3985337)), the whiteboard's persistence policy (`BoardKeepingTests`, [f41be39](https://github.com/idvorkin/context-grabber/commit/f41be39)), the Inbox's send orchestration (`InboxOutboxTests`, [845a6f2](https://github.com/idvorkin/context-grabber/commit/845a6f2)) and the chat archive and new-thread rules (`ChatArchiverTests`, `ChatNewThreadScreenTests`, [23dd212](https://github.com/idvorkin/context-grabber/commit/23dd212)); verified together at [f83889f](https://github.com/idvorkin/context-grabber/commit/f83889f) on the Mac host (rung 1, 1,123 ContextCore tests) and the simulator (rung 2: the whiteboard and chat UI suites and the smoke). The duplicates the 2026-11-12 assessment found: story 770

#### Use Case:
- **As Igor,** waiting for a fix to reach his phone
- **I want to** have each rule tested on the Mac, in a library with no simulator, and keep the simulator for what only a real screen can show
- **so that** a change is proved in seconds, and the simulator's queue stays short

#### Acceptance Criteria:
- **Scenario:** A rule that needs no screen
- **Given:** a UI test whose check does not depend on a real view, gesture or system service
- **When:** the test is reviewed
- **Then:** its check moves to a host test, and the UI test is deleted or shrinks to what only the screen can show

---

### User Story 671:

- **Summary:** My other apps share the testing tools instead of each growing its own
- **Status:** not implemented; bead `context-grabber-3k6`

#### Use Case:
- **As Igor,** with several apps on one Mac
- **I want to** have the test helpers and the practice that worked here available to my other apps
- **so that** a speedup found in one app reaches the rest, and no app solves it again

#### Acceptance Criteria:
- **Scenario:** A practice that has proved itself here
- **Given:** a testing helper or practice has shortened this app's runs, with the measurement to show it
- **When:** another app starts its testing work
- **Then:** it can take the helper from the shared library and read the practice in the shared practices for every app

---

### User Story 672:

- **Summary:** UI tests keep the app open unless a restart is the point
- **Status:** started: `ChatArchiveUITests` shares one running app in [9fd6dbe4](https://github.com/idvorkin/context-grabber/commit/9fd6dbe4) and [3edeacae](https://github.com/idvorkin/context-grabber/commit/3edeacae) and goes back to the list by its own Back, verified on the simulator (iPhone 17, 2026-11-11: three tests, one launch, 26 s against 56-70 s relaunching each). A link home as the reset was tried first and dropped: XCTest waited 33 s for the app to idle after it. The other classes follow one at a time, each measured: `ChatSkillThreadUITests` shares one too in [9c2c9834](https://github.com/idvorkin/context-grabber/commit/9c2c9834) (iPhone 17, 2026-11-11: two tests, 22 s against 27 s). The whiteboard's paper classes stay as they are: `WhiteboardPaperLinesUITests` shared saved 11 s of 191 s, as their time is their own drawing and waiting, not launches, and a keyboard left up (#850) carried into the next test; bead `context-grabber-3k6`

#### Use Case:
- **As Igor,** waiting on a test run
- **I want to** have UI tests share a running app and move it to the state each one needs
- **so that** the run doesn't spend minutes starting and stopping the app

#### Acceptance Criteria:
- **Scenario:** A test that isn't about restarting
- **Given:** a UI test that doesn't check what survives a restart
- **When:** it begins after another test
- **Then:** it runs in the already open app, starting from the same clean state a fresh launch would give it

---

### User Story 673:

- **Summary:** A test checks for what it needs without a fixed wait
- **Status:** partly implemented in d91ca4d, 2e67445, 2fcd476: the UI tests wait with `appears(within:)`, verified on the simulator (rung 2, the board suite 63 tests in 1621 s, chat 22 of 22); on branch `native/673-waits` the whiteboard's waits for the save (the page number's *saved* value) and for ink to settle on screen replace 11 fixed pauses, verified on the simulator (2026-11-10: all 30 whiteboard tests pass in a ladder climb, 545 s against 661 s for the run before it; the four save waits pass alone on the iPad; PhoneBoardsUITests passes alone, its failure in the climb's order is #868); a wait for something to go away is story 1504; the rest remain: a new board settling (tangled with #850), a wait that proves nothing happened, and pauses before a screenshot kept for a person; bead `context-grabber-3k6`

#### Use Case:
- **As Igor,** waiting on a test run
- **I want to** have tests move on as soon as what they're waiting for is there
- **so that** looks that come a second late, and pauses of a set length, stop adding up to minutes

#### Acceptance Criteria:
- **Scenario:** The thing is already on screen
- **Given:** a UI test is waiting for something already on screen
- **When:** it checks
- **Then:** it moves on in well under a second

---

### User Story 674:

- **Summary:** After the pipeline, only what its changes touched runs again
- **Status:** not implemented; bead `context-grabber-3k6`

#### Use Case:
- **As Igor,** waiting for a ready PR to merge
- **I want to** have the last check before merging rerun only the tests a pipeline's changes could affect
- **so that** a change to a doc comment doesn't cost another full run

#### Acceptance Criteria:
- **Scenario:** The pipeline touched one test and a comment
- **Given:** the whole suite passed before the pipeline ran
- **and Given:** the pipeline changed only documents, comments and one test class
- **When:** the check before merging runs
- **Then:** it runs that test class, says what it skipped and why, and the PR's comment names the rung

---

### User Story 675:

- **Summary:** The most urgent work goes first on the simulator
- **Status:** not implemented; bead `context-grabber-3k6`

#### Use Case:
- **As Igor,** waiting for something he asked for
- **I want to** have a ready PR's last check run ahead of exploratory runs and repeats
- **so that** a fix one check away from my phone doesn't wait behind a test being repeated

#### Acceptance Criteria:
- **Scenario:** Two runs waiting on the one simulator
- **Given:** a ready PR's last check and an exploratory run are both waiting
- **When:** the simulator comes free
- **Then:** the PR's check runs first

---

### User Story 676:

- **Summary:** A full whiteboard run takes under ten minutes
- **Status:** not implemented; bead `context-grabber-3k6`; ten minutes is a proposed target, Igor's to change

#### Use Case:
- **As Igor,** deciding whether a whiteboard change is safe
- **I want to** have the whole whiteboard suite finish in under ten minutes
- **so that** running it is an easy choice rather than a half-hour wait

#### Acceptance Criteria:
- **Scenario:** A full run on an idle Mac
- **Given:** nothing else is using the simulator
- **When:** the full whiteboard suite runs
- **Then:** it finishes in under ten minutes and proves every behaviour the 25-minute suite proved, on the simulator or on the Mac

---

### User Story 799:

- **Summary:** The host rung's script checks pass or fail the same way when several run at once
- **Status:** implemented in [96aab44b](https://github.com/idvorkin/context-grabber/commit/96aab44b) (#990); verified on the host rung: the signing-guard check, 24 copies started 0.3 s apart in batches of six (0 failures; before the fix, 5 of 18 failed this way, exit 143 or the No Accounts case killed), then 43 more, 20 of them with all 18 cores busy at a load average of 133, in batches of five and alone (0 failures)
- **Issues:** [#981](https://github.com/idvorkin/context-grabber/issues/981) (the signing-guard check's clean build killed with exit 143 while another agent's copy of the same check ran; the copy's cleanup ended every process naming the shared fake device, the other run's build included); its "held the display awake" check failing about 1 run in 8 (the fake build could finish before the background display-awake stand-in wrote its line)

#### Use Case:
- **As Igor,** with several agents and the pipeline's test step running `just test` on one Mac at once
- **I want to** have every host check touch only its own run's processes and files, and wait for what it checks rather than race it
- **so that** a red host rung means the change broke something, and one agent's run never fails another's or parks a pipeline

#### Acceptance Criteria:
- **Scenario:** The same host check runs in two places at once
- **Given:** two copies of a host check run on one Mac, under load, with the real screen locked or not
- **When:** each sets up its fakes, runs its cases and cleans up
- **Then:** each passes or fails on its own merits: its cleanup stops only its own processes, none of its inputs is the Mac's real state, and a check of something started in the background waits for it to happen rather than racing it

---

### User Story 683:

- **Summary:** One command climbs the test ladder, cheapest rung first, and stops at the first failure
- **Status:** implemented in 735f6b4, e1dde12; the lint, host and simulator rungs ran for real on 2026-11-05 (rung 2 on one chat class: build 34 s, `ChatArchiveUITests` 7 of 7 in 198 s, the project generated first); the Mac rung has run only in dry runs; bead `context-grabber-3k6`; [spec](../superpowers/specs/2026-10-04-swift-native-app-design.md)

#### Use Case:
- **As Igor,** waiting to know whether a change is safe
- **I want to** run one command that tries the cheapest checks first and only goes on to the simulator tests this change touches
- **so that** a mistake shows up in seconds, and a change to one screen doesn't cost a half-hour run

#### Acceptance Criteria:
- **Scenario:** A change to the chat screen, and a failure on a cheap rung
- **Given:** the branch changed only chat's code
- **and Given:** the Mac build fails on it
- **and Given:** no other Xcode build is running
- **When:** the ladder runs
- **Then:** it stops at the Mac rung without starting the simulator, printing the seconds for each rung and that it stopped on the Mac

---

### User Story 686:

- **Summary:** A change to one screen runs that screen's own UI tests
- **Status:** implemented in 0712a24, 0e7e7b1; verified on the host rung (`scripts/native/test-ladder-map.sh`)
- **Issues:** [#795](https://github.com/idvorkin/context-grabber/issues/795)

#### Use Case:
- **As Igor,** changing one screen of the app
- **I want to** have the ladder run that screen's own UI tests
- **so that** the change is checked on the simulator before it reaches my phone, without the forty-five minutes of every test

#### Acceptance Criteria:
- **Scenario:** A change to the Gym Timer
- **Given:** the branch changed only the Gym Timer's code
- **When:** the ladder reaches the simulator rung
- **Then:** it runs the Gym Timer's own UI tests and no other screen's, naming them before it starts

---

### User Story 687:

- **Summary:** A change to a screen no simulator test opens is named, not passed over
- **Status:** implemented in 0712a24, 0e7e7b1; verified on the host rung (`scripts/native/test-ladder-map.sh`)
- **Issues:** [#795](https://github.com/idvorkin/context-grabber/issues/795)

#### Use Case:
- **As Igor,** reading what the ladder checked
- **I want to** be told when a change got no UI tests of its own
- **so that** a green run is never mistaken for a tested screen

#### Acceptance Criteria:
- **Scenario:** A change to the iPad's windows
- **Given:** the branch changed only the iPad's windows, which no simulator UI test opens
- **When:** the ladder runs
- **Then:** it chooses no UI tests for that change, names the changed file, and says how to run every UI test

---

### User Story 745:

- **Summary:** Every UI test run says where its time went
- **Status:** implemented in 28af189; verified on the host rung (`scripts/native/test-ui-timings.sh`, against a real whiteboard run's log); each line carries the ladder climb's run id on branch `native/ladder-ledger-1038` (story 1016), verified on the host rung by `scripts/native/test-ladder-map.sh`
- **Issues:** [#826](https://github.com/idvorkin/context-grabber/issues/826); [#1038](https://github.com/idvorkin/context-grabber/issues/1038)

#### Use Case:
- **As Igor,** waiting on slow simulator runs
- **I want to** see, after every UI test run, how long each test took and how much of that was launching the app, retried steps and waiting
- **so that** we speed up the part that actually costs the time, and can tell whether a change helped

#### Acceptance Criteria:
- **Scenario:** A UI test run finishes
- **Given:** a run of one or more UI test classes on the simulator
- **When:** its tests have finished, passed or failed
- **Then:** the run prints the slowest tests, each class's total and launch time, and the kinds of wait that cost the most, and keeps one line per test that later runs can be compared against

---

### User Story 750:

- **Summary:** A box with no Mac checks the whole app's Swift before anything reaches the Mac
- **Status:** implemented in [97a0b57](https://github.com/idvorkin/context-grabber/commit/97a0b57); verified on the Linux rung (`just test-linux` on aarch64 Ubuntu: 1,185 tests, the three cross-builds, the app's sources for iOS and the three script checks all ok); the Mac's own rungs are unchanged; a missing kept build directory created in [7dae5d56](https://github.com/idvorkin/context-grabber/commit/7dae5d56) (#904), verified on the host rung by running the new block alone: a relative path not yet there made and resolved against the caller, an uncreatable one stops with exit 2 naming it; the full Linux rung was not run, as this Mac has no Linux box; bare Apple-only imports caught on the Mac in [6b0bb364](https://github.com/idvorkin/context-grabber/commit/6b0bb364) and checked by the compiler's import scan in [f55f865e](https://github.com/idvorkin/context-grabber/commit/f55f865e) (bead context-grabber-cmk), verified on the host rung (`just native-test`: the check named BoardRoomBandTests and PaperProbeMoveAuditTests before their guards, passes after) and the Mac build
- **Issues:** the test-ladder audit of 2026-11-10 ("Linux as a real rung"); [#904](https://github.com/idvorkin/context-grabber/issues/904) (a kept build directory that did not exist yet failed the rung); bead `context-grabber-cmk` (two board tests imported CoreGraphics bare and broke Linux's swift test)

#### Use Case:
- **As Igor,** with agents working on Linux boxes while the Mac is busy or locked
- **I want to** have every change compiled and host-tested off the Mac first, app code included
- **so that** a type slip in a view or a broken ladder map shows up on the agent's box in minutes, not in the Mac's build an hour later

#### Acceptance Criteria:
- **Scenario:** An agent checks a Swift change that must build on Linux
- **Given:** a change to app code or package sources or tests, and a Linux box with Swift and the Darwin SDK
- **When:** the change goes through the Mac host rung or the Linux rung
- **Then:** the Mac host rung fails with the file and framework when an Apple-only import is reachable on Linux. A branch guarded by `#if canImport` or `#if os` passes when it excludes Linux. The Linux rung creates and uses a requested build directory (relative to the caller or absolute), or stops immediately and names it if creation fails. It runs ContextCore's tests, cross-compiles the package and the app, widgets, share extension and UI tests for Apple, then checks scripts including the ladder map and Linux imports. Each step reports success, failure or a skip with its reason.

---

### User Story 688:

- **Summary:** A new branch builds in a worktree that already has a build
- **Status:** implemented in 0e0cf96; verified on the Mac rung (a slot returned and re-leased for a new branch rebuilt in 7 s with one file touched, against 39 s for its first build); the pool raised from eight to twelve slots, two per build lane at the M5 Pro's six, in 7dfe36ee (config and docs only; `treehouse.toml` read back)
- **Issues:** [#803](https://github.com/idvorkin/context-grabber/issues/803)

#### Use Case:
- **As Igor,** with several agents each working on a branch of its own
- **I want to** have a new branch start in a worktree that was built before
- **so that** its first build takes the time of what changed, and build folders stop filling the disk

#### Acceptance Criteria:
- **Scenario:** A second branch in a returned worktree
- **Given:** a pool worktree was built for one branch and returned
- **When:** an agent leases it for a new branch and builds for the simulator
- **Then:** the build reuses what the earlier one compiled, and the Mac holds no more build folders than the pool has worktrees

---

### User Story 689:

- **Summary:** A stuck or flaky UI test costs a minute or two, not a whole rerun
- **Status:** implemented in 4337f19; verified on the host by `scripts/native/test-xcodebuild-log.sh` (a fake xcodebuild: the time limit, the retry, the stopped hang, a retry printing past the idle limit) and `scripts/native/test-ui-timings.sh` (a retried case named); the hang wait cut from 30 s to 10 s in e427499 (retries run before the one closing suite line, so the cut skips only xcodebuild's idle tail), verified on the host by the same check; on branch `native/flaky-retry-86z1` (story 1017) a case that passed only on its retry fails the run, verified on the host rung by the same two checks
- **Issues:** the pipeline timing study of 2026-11-10 (Igor: "I don't want to be spending 20 minutes in the simulator"; "fix all the issues"); bead context-grabber-tne1 (2026-11-22: the wrapper's end-of-run cleanup killed a watchdog by a number it had left long before, which a busy Mac had since given to another run's wrapper; that run exited 143 with nothing said. A watchdog is now stopped only while it is still the wrapper's own child)

#### Use Case:
- **As Igor,** waiting on a change to reach the phone
- **I want to** have a UI test that hangs or fails once cost little, while still being told about it
- **so that** one flaky case doesn't buy another 10-minute pass of the whole list

#### Acceptance Criteria:
- **Scenario:** A UI test run on the simulator
- **Given:** a run where one case fails once and passes on a second try, one case runs past two minutes, and xcodebuild sits idle after the last suite closes
- **When:** the run ends
- **Then:** the failed case alone ran again and the run's timing summary names it as passed only on retry, and the run fails for it unless it is quarantined (story 1017), the long case failed at two minutes, and xcodebuild was stopped 10 s after the suite closed (once its result bundle is written, story 790) with the log's result kept

---

### User Story 790:

- **Summary:** A failed UI test's screenshots can still be opened after the run
- **Status:** implemented in [ce8857d2](https://github.com/idvorkin/context-grabber/commit/ce8857d2); verified on the host by `scripts/native/test-xcodebuild-log.sh` (a fake xcodebuild that writes its bundle for 8 s, silently, after its suite closes and then hangs: the stop waits for `Info.plist`, the failure names the bundle; one that never finishes is given up on at the limit and says so; a command's own bundle path is kept, a build gets none; the check fails against the old script), and on the simulator (rung 2, `GymTimerUITests`): the run's bundle at `native/Build/logs/ladder-ui-tests.xcresult` opened with `xcrun xcresulttool get test-results summary` (Passed, 1 test). That run's xcodebuild ended by itself, so the stop's wait was seen only with the fake. Amended in ff27c838 (bead `context-grabber-wyp5`): the stop waits for the last of several test targets, verified on the host by the same script (a second target quiet for 12 s past 1 s idle and 2 s bundle limits runs to its pass; the check fails against the old script)
- **Issues:** bead `context-grabber-r4wh` (2026-11-21: every recent result bundle in the pool slots held only `Staging`, no `Info.plist`, so `xcresulttool` called it corrupted and the screenshots failed tests keep were gone; evidence for two flaky tests had to be re-gathered by making the tests write PNGs); bead `context-grabber-wyp5` (2026-11-22: the stop armed on the first target's closing suite, so a second target that went quiet past the limits was stopped as hung; not yet seen on a run, the contracts' second target takes about 10 s)

#### Use Case:
- **As Igor,** or an agent, looking into a UI test that failed
- **I want to** open the run's result bundle and see the screenshots and view trees the failed test kept
- **so that** a failure is read from its evidence, not run again with extra instrumentation

#### Acceptance Criteria:
- **Scenario:** xcodebuild sits quiet after the last suite closes
- **Given:** a UI test run whose last suite has closed (in a run of several test targets, the last target's), while xcodebuild is still writing the run's result bundle
- **When:** the run's idle stop would fire
- **Then:** the run waits until the bundle is written in full (up to two minutes after the suite closed), then stops xcodebuild if it is still there; the bundle sits beside the run's log, named for the run, and opens with `xcrun xcresulttool`; a failed run names it; a bundle not written in time is given up on and the run says it can't be opened

---

### User Story 782:

- **Summary:** The simulator rung keeps the Mac's display on, and runs on a locked screen without its tests that open the mic
- **Status:** implemented in c58dba5; verified on the host by `scripts/native/test-ladder-map.sh` (fake `caffeinate` and lock probe: rung 2 runs under `caffeinate -d -i` after a `caffeinate -u`, the Mac rung under `-i` alone, and a locked screen stops rung 2 with exit 75 before anything builds); not yet seen on a real dark Mac; amended in a344919f (story 1022: a locked screen first waits up to 2 minutes for an unlock); amended on branch `fix/locked-skip-mic-wm8y` (bead `context-grabber-wm8y`: a locked screen no longer stops the rung, verified on the host by the same script: rung 2 on a locked screen runs its class and says it skips the tests that open the mic)
- **Issues:** the fast-sim-tests study of 2026-11-16 (the 915 run's whiteboard step: 29 minutes, 17 of them waiting for a dark, locked screen; a run that morning, two hours)

#### Use Case:
- **As Igor,** away from the Mac while a change climbs the ladder
- **I want to** have the simulator rung keep the display lit, and run on a locked screen with only the tests that open the mic held back
- **so that** a run that takes 11 to 14 minutes doesn't take 30 minutes or two hours, and a locked Mac still tests everything it safely can

#### Acceptance Criteria:
- **Scenario:** Starting the simulator rung
- **Given:** the Mac's display may be asleep, and its screen may be locked
- **When:** the ladder starts rung 2
- **Then:** it wakes the display and holds it on for the whole rung, and if the screen is locked it says *the Mac's screen is locked: rung 2 runs, skipping the tests that open the mic* and runs, the wrapper skipping those tests (story 1022)

---

### User Story 783:

- **Summary:** A UI test run that never starts is stopped in three minutes, naming the likely cause
- **Status:** implemented in c58dba5; verified on the host by `scripts/native/test-xcodebuild-log.sh` (a fake xcodebuild that never starts a suite is stopped and exits 75 with the message; one that compiles first, a build, and a run that starts in time are left alone)
- **Issues:** the fast-sim-tests study of 2026-11-16 (the only bound on a run that never started was the rung's 60-minute limit)

#### Use Case:
- **As Igor,** waiting on a UI test run
- **I want to** have a run whose first test hasn't started within three minutes stopped and blamed on the likely cause
- **so that** a dark or locked screen costs three minutes and a clear line, not a quarter of an hour or the whole time limit

#### Acceptance Criteria:
- **Scenario:** A run of built tests that doesn't start
- **Given:** a test run of an existing build, with no test suite started 180 s after xcodebuild began
- **When:** the 180 s pass
- **Then:** xcodebuild is stopped and the run fails with exit 75, saying no test started, that UI tests don't start with the display asleep or the screen locked, and whether the screen is locked now; a run that compiles first, or starts in time, runs on

---

### User Story 784:

- **Summary:** A change to one of the board's own view files runs only the UI test classes that open it
- **Status:** implemented in 1f27906 and 9d8c81c for the one such file on main, the board fixture hook (`WhiteboardRowDeleteUITests` and `ChatImageUITests`, where it ran all eight whiteboard classes and missed the chat one); verified on the host by `scripts/native/test-ladder-map.sh`. The board's two big views (the board and its paper) draw every board and still run every class. The view files on branches tonight get their rows as they land: the name in the bar (`WhiteboardRowDeleteUITests`), the panel's newest line (`WhiteboardTurnUITests`). The question cards (#919) have theirs: their two view files and their rules in `ContextCore` run `WhiteboardQuestionUITests` alone, and that class joined the whiteboard's list, which the map's check now holds to every `Whiteboard*UITests` class in the tree; #1041 (bead context-grabber-cplo): the conversation strip (#1039) runs `WhiteboardTurnUITests`, `WhiteboardConnectUITests` and `WhiteboardOnPaperUITests` and the smoke's whiteboard section instead of all fifteen, and a change with the canvas or the drawing screen in it takes every class; verified on the host by `scripts/native/test-ladder-map.sh` in `just test`
- **Issues:** the fast-sim-tests study of 2026-11-16 (any view file ran all eight whiteboard classes, 11 to 14 minutes); [#1041](https://github.com/idvorkin/context-grabber/issues/1041)

#### Use Case:
- **As Igor,** waiting on a fix to one small part of the board
- **I want to** have the simulator run the classes that open that part, not every whiteboard class
- **so that** a one-file view fix costs a minute or two of UI tests, not the whole whiteboard step

#### Acceptance Criteria:
- **Scenario:** A change to the board fixture hook
- **Given:** a branch that changes only the app's board fixture hook
- **When:** the test ladder climbs
- **Then:** the simulator runs the row-delete class and chat's picture-from-a-board class and no other whiteboard class, while a change to the board's own view still runs every whiteboard class, and `--full` still runs the whole suite

---

### User Story 753:

- **Summary:** A change to one whiteboard rule runs only the whiteboard tests that show it
- **Status:** implemented in 1107aad; verified on the host by `scripts/native/test-ladder-map.sh` (the paste, ghost and board-list rules, and the hooks running every class)
- **Issues:** the pipeline timing study of 2026-11-10 (any whiteboard file ran all 8 classes, 9–11 min)

#### Use Case:
- **As Igor,** waiting on a whiteboard fix to reach the iPad
- **I want to** have the simulator run only the whiteboard tests a change can break
- **so that** a change to how a paste is laid out doesn't cost a 10-minute pass of every board test

#### Acceptance Criteria:
- **Scenario:** A change to the paste rule
- **Given:** a branch that changes only how a paste is laid out on a board
- **When:** the test ladder climbs
- **Then:** the simulator runs the two paste test classes and no other whiteboard class, while a change to the board's own views or its launch hooks still runs every whiteboard class

---

### User Story 756:

- **Summary:** A change to the picture's frame, Larry's clock or the note runs only the turn and ghosts tests
- **Status:** implemented in [2b6dade](https://github.com/idvorkin/context-grabber/commit/2b6dade); verified on the host by `scripts/native/test-ladder-map.sh` (each of the three rules alone selecting the turn and the ghosts-on-paper classes)
- **Issues:** the pipeline timing study of 2026-11-10 (any whiteboard file ran all 8 classes, 9–11 min)

#### Use Case:
- **As Igor,** waiting on a fix to Larry's turn to reach the iPad
- **I want to** have the simulator run only the classes that show the picture's frame, Larry's clock and the note
- **so that** such a change doesn't cost a pass of every board test (story 753)

#### Acceptance Criteria:
- **Scenario:** A change to the picture's frame
- **Given:** a branch that changes only where Larry's picture is framed on the board
- **When:** the test ladder climbs
- **Then:** the simulator runs the turn and the ghosts-on-paper classes and no other whiteboard class (it ran all 8)

---

### User Story 754:

- **Summary:** UI tests don't wait for screens to slide
- **Status:** implemented in ed896a9 and be6e45f; verified on the simulator (iPhone 17, 2026-11-10): the chat suite's 16 tests went from about 243 s to 193 s, all passing; the whiteboard's classes keep their animations, as PaperLines on the iPad simulator counted a second stroke after the Board menu without them (the menu's closing tap reaching the canvas), until #850 is settled

#### Use Case:
- **As Igor,** waiting on a test run
- **I want to** have the app under UI test skip its sliding and fading animations
- **so that** each step stops waiting out an animation nobody is watching, and a whiteboard pass gets shorter

#### Acceptance Criteria:
- **Scenario:** A UI test opens a screen and a menu
- **Given:** any UI test but the whiteboard's, launched the way every UI test launches the app
- **When:** it pushes a screen, opens a sheet or a menu
- **Then:** the screen, sheet or menu is there at once rather than after its animation, and the app the phone runs is unchanged

---

### User Story 755:

- **Summary:** One climb of the ladder runs the touched UI tests and the smoke on one build and one boot
- **Status:** implemented on branch `native/755-ladder-smoke`; verified by the ladder's map self-test (host: the smoke runs on the rung's build and simulator; a Gym Timer file maps to the timer section, a UI test file to none, shared code to all) and one real climb (iPhone 17, 2026-11-10: `--rung 2 --changed` a Gym Timer file built once, ran its two classes in 62 s, then the timer smoke on the same boot in 60 s, 145 s in all)

#### Use Case:
- **As Igor,** waiting on a change's simulator check
- **I want to** have the ladder run the smoke's touched sections right after the touched UI test classes, on the build and the simulator it already has
- **so that** a change pays for one simulator build, one boot and one wait for the build lock, not two

#### Acceptance Criteria:
- **Scenario:** A change to one feature
- **Given:** a branch that changes the Gym Timer's screen
- **When:** I run `just test-ladder`
- **Then:** rung 2 builds once, runs the timer's UI test classes, then the smoke's timer section on the same booted simulator, times each step, and stops at the first failure; `--dry-run` names the smoke's sections; `LADDER_SMOKE=0` leaves the smoke out

---

### User Story 770:

- **Summary:** A UI test that only repeats a host test or another UI test is cut, after the host test is seen to fail
- **Status:** implemented in [ebc153f](https://github.com/idvorkin/context-grabber/commit/ebc153f), [49d577c](https://github.com/idvorkin/context-grabber/commit/49d577c), [4abeb11](https://github.com/idvorkin/context-grabber/commit/4abeb11); verified on the host: before each delete the rule it held was broken by a one-line change and the host test that guards it was seen to fail, then the source restored (the mutations are in the PR). Where no host test held the rule it moved into `ContextCore` first (why a board can't open, what a table reads aloud), with host tests. The rest of the same trim is stories 757–759, 780 and 781. #905's pass over the call, export, home, drill and mirror suites: [105485e7](https://github.com/idvorkin/context-grabber/commit/105485e7) removes `HomeTodayCardUITests`' three-to-a-line checks, which `HomeGridUITests` makes on the same screen. Its other cuts are launches shared (story 757). The drill (`MetricDetailUITests`) and the strip sheets were already one launch each (49d29014). Export's one class, `HealthAccessUITests`, is the smoke's HealthKit grant and has nothing to cut
- **Issues:** the simulator assessment of 2026-11-12 (`~/tmp/agent/notes/2026-11-12-sim-tests-down-the-ladder.md`); story 670; #905

#### Use Case:
- **As Igor,** waiting on a whiteboard or chat change to reach the iPad
- **I want to** have the simulator run each rule once, where only a screen can show it
- **so that** a whiteboard pass costs about a minute and a half less, without a rule losing its test

#### Acceptance Criteria:
- **Scenario:** A UI test that repeats a host test
- **Given:** a UI test whose rule a host test already holds
- **When:** the rule is broken in the source by one line
- **Then:** the host test fails, and only then is the UI test deleted; when no host test fails, a host test is written first or the UI test stays

---

### User Story 757:

- **Summary:** Two UI tests that check one screen share a launch
- **Status:** implemented in [ebc153f](https://github.com/idvorkin/context-grabber/commit/ebc153f) (the whiteboard's two ghost tests in one launch, the colours test checking one colour, Larry's marks without a reopen); [6347bd17](https://github.com/idvorkin/context-grabber/commit/6347bd17) (bead context-grabber-3rk) puts the paper lines' four tests in two launches (a new board's grid with a board keeping its colour and lines; ruled or grid with the lines on Lilac), measured on the iPad simulator (rung 2): 97.9 s on average for the four today, 61.3 s for the two; verified on the host only (the UI tests typecheck); the simulator run of the changed UI tests and the smoke comes before the merge, on the final code. #905: [105485e7](https://github.com/idvorkin/context-grabber/commit/105485e7) applies it to the call, home and mirror suites. The Cockpit page's ☎ is the last step of `CockpitBackUITests`' launch, Report a problem's tile is checked in `HomeGridUITests`' launch, and the daily strip's two-week sheet shares the counters' launch: eight launches become five. Measured on the iPhone 17 simulator (rung 2), back to back on one lane, 2026-11-22: the seven classes' clean passes took 128.7 s and 142.7 s on main and 96.0 s after, about 40 s less in all. That is about 11 s less for a Cockpit change, 12 s for a daily strip change and 16 s for a `--full` or `--all` run's home classes, with nothing changed for the mirror
- **Issues:** the simulator assessment of 2026-11-12; story 770; #905

#### Use Case:
- **As Igor,** waiting on a whiteboard change's simulator pass
- **I want to** have checks of the same screen made in one launch of the app
- **so that** a launch, the slowest step of a UI test, is paid once per screen and not once per check

#### Acceptance Criteria:
- **Scenario:** Two UI tests that open the same screen
- **Given:** two UI tests that each launch the app to check one thing on the same screen
- **When:** they are merged
- **Then:** one launch makes every check both made, in the order the screen allows

---

### User Story 758:

- **Summary:** What an iPhone does with boards is read from the smoke's log, not from a test class of its own
- **Status:** implemented in [c9ec172](https://github.com/idvorkin/context-grabber/commit/c9ec172) and the review fix after it (the list's New board and the log's `new_board` read one rule); verified on the host (`BoardIndexTests`: a phone starts no board, draws on none, and the bar says to draw on the iPad; `scripts/native/test-ladder-map.sh`: a whiteboard change runs no iPhone class); the simulator run of the changed UI tests and the smoke comes before the merge, on the final code. The smoke reads `editable` as described in [the grid launch hook](../TESTING.md). No test looks at the phone's screen for the missing buttons any more, only at the rules they read, and *Send to Larry* still being there on a phone has no test
- **Issues:** the simulator assessment of 2026-11-12; stories 746, 770

#### Use Case:
- **As Igor,** waiting on a whiteboard change, whose UI tests run on an iPad simulator
- **I want to** have the iPhone's look at boards judged in the smoke's launch on the iPhone simulator
- **so that** a whiteboard change doesn't boot a second simulator for one class (about 65 s)

#### Acceptance Criteria:
- **Scenario:** The iPhone's look at the boards
- **Given:** a whiteboard change, whose UI test classes run on an iPad simulator
- **When:** the ladder climbs
- **Then:** what an iPhone does with boards (no New board, its own board look-only with the bar's reason) is read from the smoke's session log on the iPhone simulator it already booted, rather than from a class of its own in a second test session

---

### User Story 759:

- **Summary:** The minute-long Health session runs for a Health change, not a breathing change, and stops waiting for a sheet that isn't coming
- **Status:** implemented in [dc31beb](https://github.com/idvorkin/context-grabber/commit/dc31beb); verified on the host (`scripts/native/test-ladder-map.sh`: breathing code doesn't select `BreatheMindfulUITests`, the Health source does); the simulator run of the changed UI tests and the smoke comes before the merge, on the final code
- **Issues:** the simulator assessment of 2026-11-12; stories 242, 770

#### Use Case:
- **As Igor,** waiting on a change to the breathing screen
- **I want to** have the session that writes to Health run only when the Health code changes
- **so that** a breathing change is about 160 s shorter, and the write to Health is still checked when it can break

#### Acceptance Criteria:
- **Scenario:** A breathing change and a Health change
- **Given:** a branch that changes the breathing screen, and another that changes how the app writes to Health
- **When:** the ladder climbs each
- **Then:** the breathing change runs the breathing classes without the minute-long Health session, the Health change runs that session, and the session's wait for Health's sheet ends as soon as Today's cards show

---

### User Story 780:

- **Summary:** A chat change runs no check that belongs to the whiteboard or to a host test
- **Status:** implemented in [49d577c](https://github.com/idvorkin/context-grabber/commit/49d577c), [4abeb11](https://github.com/idvorkin/context-grabber/commit/4abeb11); verified on the host (`BoardIndexTests`: why a board can't open; `ChatTablesTests`: what a table reads aloud; `scripts/native/test-ladder-map.sh`); the simulator run of the changed UI tests and the smoke comes before the merge, on the final code. The table's label inside the bubble's combined label has no simulator check
- **Issues:** the simulator assessment of 2026-11-12; story 770

#### Use Case:
- **As Igor,** waiting on a chat change's simulator pass
- **I want to** have the chat classes hold only what a chat screen alone can show
- **so that** a chat pass is about half a minute shorter

#### Acceptance Criteria:
- **Scenario:** A chat change
- **Given:** a branch that changes the chat screens
- **When:** the ladder climbs
- **Then:** the chat classes run without a check that is whiteboard code (a link to a missing board) or a host test's (what a table reads aloud), and the picture's two ways out and the bar's mic share one launch each with the tests that already open those screens

---

### User Story 781:

- **Summary:** A metric's detail, the blog's tiles and the strip's sheets are each checked in fewer launches
- **Status:** implemented in [49d2901](https://github.com/idvorkin/context-grabber/commit/49d2901); verified on the host only (the strip's rules are `CounterWeekTests`; the UI tests typecheck); the simulator run of the changed UI tests and the smoke comes before the merge, on the final code
- **Issues:** the simulator assessment of 2026-11-12; story 770

#### Use Case:
- **As Igor,** waiting on a change to the mirror
- **I want to** have each screen's checks made in as few launches as the screen allows
- **so that** the mirror's UI tests stop paying a launch per check

#### Acceptance Criteria:
- **Scenario:** A screen's checks in one launch
- **Given:** a metric's detail, the blog's three tiles and the daily strip's press-and-hold sheets, each with its rules on the host
- **When:** their UI tests run
- **Then:** the detail's form, the report over it and its close are one launch; the three tiles are one launch that comes back from Safari between them; and each strip sheet makes one round of edit and save

---

### User Story 827:

- **Summary:** The smoke skips its audio checks on a locked Mac, and says so
- **Status:** implemented on branch `native/batch-decided-1114`; verified by the script check `scripts/native/test-smoke-lock.sh` in `just native-test` (the lock probe faked); and by a real smoke run on a locked Mac (`SMOKE_ONLY=call just native-test-sim` at 76eb6552, 2026-11-19, for #364): the real-audio call printed *skipped: Mac screen locked*, the run's last lines counted it as skipped, and the synthetic and dropped calls still ran and passed; amended in a344919f (story 1022: a smoke asked for on a locked screen waits for an unlock, then exits 75); amended in 4ee1f8a0 (story 1025: the real-audio call is also skipped with the lid closed on the built-in mic)
- **Issues:** [#419](https://github.com/idvorkin/context-grabber/issues/419) (a locked Mac starves the simulator's audio); [#364](https://github.com/idvorkin/context-grabber/issues/364) (the real-audio call's mic gave exact zeros and the clean call filed an automatic report; unlocked, it passes); Igor, 2026-11-14: skip them rather than rerun for 5 to 12 minutes

#### Use Case:
- **As Igor,** waiting on a simulator run while the Mac's screen has locked
- **I want to** have the audio checks skipped and named as skipped
- **so that** a locked screen doesn't fail the run and cost a rerun, and a skipped check is never read as a pass

#### Acceptance Criteria:
- **Scenario:** A smoke run on a locked Mac
- **Given:** a smoke run under way
- **When:** the screen locks after the smoke started (a smoke asked for on a locked screen starts as usual and skips the same checks, story 1022), and the smoke reaches the timer, breathing and the real-audio call
- **Then:** each prints *skipped: Mac screen locked* and doesn't run, the run's last lines count them as skipped and not passed, and unlocked they run as before (the real-audio call is also skipped while the lid is closed on the built-in mic, story 1025)

---

### User Story 828:

- **Summary:** A report of how long a change takes, from the repo
- **Status:** implemented on branch `native/batch-decided-1114`; run once by hand against GitHub and the deploys ledger, writing to a scratch folder; no automated check (it reads live GitHub). On branch `native/ladder-ledger-1038` (story 1016) only a cable install or a build TestFlight offers counts as on a device, the upload has its own column, and the ledger is written by the repo's own recorder: the one it named was never checked out, so the ledger did not exist (2026-11-21)
- **Issues:** the lead-time study of 2026-11-14; [#1038](https://github.com/idvorkin/context-grabber/issues/1038)

#### Use Case:
- **As Igor,** wanting to know where a change's time goes, week after week
- **I want to** run one recipe that reads the merged PRs and the deploys and writes the lead-time page
- **so that** the report outlives the scratch folder it was born in, and nothing private goes into the public repo

#### Acceptance Criteria:
- **Scenario:** Running the report
- **Given:** `gh` is signed in and the deploys ledger is where `LEAD_TIMES_DEPLOYS` says, or its default
- **When:** I run `just lead-times`
- **Then:** it writes `data.json` and `index.html` to the output folder, each PR's minutes from asked to merged to on a device, and nothing in the repo changes


---

### User Story 785:

- **Summary:** Up to four Mac and simulator jobs at once, as many as the Mac's memory allows
- **Status:** implemented in 33c2bb47; verified on the host by `scripts/native/test-build-lane.sh` (the lane count from the memory and from `BUILD_LANES`, the first free lane's lock, lane N's simulator named and cloned once, the wait for other xcodebuilds per lane, one lane unchanged) and the ladder's map self-test (the simulator rung takes a lane's lock); 3773facd (#1008) keeps both self-tests blind to a `BUILD_LANES` or `BUILD_LANE` in the shell, verified on the host by `just test` with `BUILD_LANES=6 BUILD_LANE=3` set and unset; the simulator rung keeps its lane count past its time limit, whose zsh reads `~/.zshenv` (context-grabber-jacw), verified on the host by the ladder's map self-test with a time limit that sets `BUILD_LANES=6` (fails without the fix, on a Mac with or without mac-driver); e5d9097f keeps the lane self-tests blind to a caller's `SIM`, `WHITEBOARD_SIM`, lane waits and lock folder (context-grabber-2l07), verified on the host by `scripts/native/test-lane-env.sh` (fails 6 checks before the fix, fewer than the ladder's 14 because its hostile environment is its own and not the ladder's; passes after) and `just test` with `SIM="iPad Pro 11-inch (M5)"` set
- **Issues:** #954 (Igor, 2026-11-19, on the M5 Pro MacBook Pro, 48 GB, 18 cores: "this machine has way more horsepower so you can run multi simulators", "we can run 4 builds at once on this machine"); #1008 (a `BUILD_LANES` set in the shell, `BUILD_LANES=6` in Igor's `~/.zshenv` on 2026-11-20, leaked into the lane and ladder self-tests and failed `just test`); context-grabber-jacw (2026-11-21, once `~/gits/mac-driver` was cloned: its `time-limit` is a zsh script, so the timed rung read `BUILD_LANES=6` from `~/.zshenv` and the map self-test failed every `just test`); context-grabber-2l07 (2026-11-24: the ladder's `SIM="iPad Pro 11-inch (M5)"`, which AGENTS.md sets on every run, leaked into the lane self-test and failed 14 of its checks, so the ladder stopped at rung 1)

#### Use Case:
- **As Igor,** with several agents fixing issues in parallel on a 48 GB Mac
- **I want to** have their Mac builds and simulator runs go side by side, up to what the Mac's memory holds, instead of queueing behind one lock
- **so that** an agent's simulator check waits for a free lane, not for every other agent's whole run, while a 16 GB Mac still runs one at a time

#### Acceptance Criteria:
- **Scenario:** The lane count
- **Given:** a Mac with 48 GB of memory and no `BUILD_LANES` set
- **When:** a Mac or simulator rung starts
- **Then:** the Mac has four build lanes (one for every 12 GB, at most four, at least one): one on a 16 GB Mac, and `BUILD_LANES` names any other number

- **Scenario:** A job takes the first free lane
- **Given:** four lanes, with lanes 1 and 2 busy
- **When:** a third agent's simulator rung starts
- **Then:** it runs at once in lane 3, says so, and uses lane 3's own simulators (*iPhone 17 lane 3*, *iPad Pro 11-inch (M5) lane 3*) and its own fake-server ports; when all four are busy it waits, for up to an hour, and the ladder counts that wait apart from the rung's own seconds

- **Scenario:** A lane's simulator, the first time
- **Given:** lane 3 has never run on this Mac
- **When:** its first job needs the iPhone simulator
- **Then:** *iPhone 17 lane 3* is made once as a copy of *iPhone 17*, taken while lane 1 is idle so the copy keeps Health access and the seeded data; `just native-sim-lanes` makes every lane's copies ahead of time

- **Scenario:** Other Xcode builds
- **Given:** four lanes and three other xcodebuilds running
- **When:** a simulator rung is about to start
- **Then:** it starts; with four others running it waits, and refuses after half an hour; on a one-lane Mac it waits for any other, as before

- **Scenario:** A one-lane Mac
- **Given:** a 16 GB Mac
- **When:** two agents start simulator rungs
- **Then:** the second waits for the first on the same lock as before lanes, older checkouts included, and runs on the same named simulators

---

### User Story 795:

- **Summary:** At most four host builds and tests at once, machine-wide
- **Status:** implemented in 1cb4e8c2; verified on the host by `scripts/native/test-host-lane.sh` (part of `just test`) and by `just test` and `just native-build-mac` passing through the slots: six jobs on four slots, never more than four running, all six run; the slot count from the cores and from `HOST_LANES`
- **Issues:** context-grabber-mkd0 (2026-11-22: about twenty agents ran `swift build` and `swift test` at once, 27 swift-frontend processes, load 281 on the 18-core Mac, from Larry's five-minute check; the Xcode builds queued in build lanes, the host builds didn't)

#### Use Case:
- **As Igor,** with many agents running `just test` and Mac builds on one Mac at the same time
- **I want to** have the host builds and tests (the lint, ContextCore's tests, the Mac build) take one of a few slots and the rest queue
- **so that** the Mac stays usable and each run finishes sooner than when all of them fight for the cores

#### Acceptance Criteria:
- **Scenario:** Six host jobs on four slots
- **Given:** an 18-core Mac with no `HOST_LANES` set, so four host slots (a quarter of the cores, at most four, at least one; `HOST_LANES` names any other number)
- **When:** six agents start `just test` at once
- **Then:** four run their host build and tests, the other two wait, and never more than four run at the same moment; all six finish

---

### User Story 797:

- **Summary:** A host job waiting for a slot says so, and gives up after an hour
- **Status:** implemented in 1cb4e8c2; verified on the host by `scripts/native/test-host-lane.sh` (part of `just test`) and by `just test` and `just native-build-mac` passing through the slots: the queued jobs say they are waiting for a host slot; every slot held past the wait is exit 75 with nothing run; the command's own exit 75 is its own
- **Issues:** context-grabber-mkd0 (2026-11-22: about twenty agents ran `swift build` and `swift test` at once, 27 swift-frontend processes, load 281 on the 18-core Mac, from Larry's five-minute check; the Xcode builds queued in build lanes, the host builds didn't)

#### Use Case:
- **As** an agent whose `just test` is queued behind others
- **I want to** see that it is waiting for a host slot rather than hung
- **so that** I wait for it instead of killing it or debugging a slow test

#### Acceptance Criteria:
- **Scenario:** Every slot busy
- **Given:** every host slot is held by another job
- **When:** I run `just test`
- **Then:** it prints once that every host slot is busy and it is waiting for a host slot, runs as soon as one frees, and after an hour (`HOST_LANE_WAIT` seconds) exits 75 having run nothing

---

### User Story 798:

- **Summary:** A host slot whose holder died is free at once
- **Status:** implemented in 1cb4e8c2; verified on the host by `scripts/native/test-host-lane.sh` (part of `just test`) and by `just test` and `just native-build-mac` passing through the slots: a holder killed with `kill -9` frees its slot, and the next job runs in it without waiting though its lock file is still there
- **Issues:** context-grabber-mkd0 (2026-11-22: about twenty agents ran `swift build` and `swift test` at once, 27 swift-frontend processes, load 281 on the 18-core Mac, from Larry's five-minute check; the Xcode builds queued in build lanes, the host builds didn't)

#### Use Case:
- **As** an agent starting a host build after another agent's run was killed or crashed
- **I want to** take the slot that run held without anyone cleaning up after it
- **so that** a dead run never leaves the Mac with fewer slots than it has

#### Acceptance Criteria:
- **Scenario:** A killed holder
- **Given:** a host job holding a slot was killed with `kill -9`, leaving its lock file behind
- **When:** the next host job starts
- **Then:** it takes that slot at once, without waiting

---

### User Story 786:

- **Summary:** A lane's simulator copies can be made again from lane 1's, after lane 1 gains Health access or new data
- **Status:** implemented in 7ae00520; verified on the host by `scripts/native/test-build-lane.sh` (rung 1; no simulator run, the Mac's screen locked)
- **Issues:** #980 (found 2026-11-19 after #954: the lane copies were made before lane 1's *iPhone 17* had Health access, so every lane's Health check skipped, and `just native-sim-lanes` never replaces a copy that exists)

#### Use Case:
- **As Igor,** whose lane simulators were copied from lane 1's before it was granted Health access
- **I want to** have every lane's copies thrown away and copied again from lane 1's with one command
- **so that** every lane runs with lane 1's Health access and data, without deleting simulators by hand under each lane's lock

#### Acceptance Criteria:
- **Scenario:** Refreshing the copies
- **Given:** four lanes, each of lanes 2–4 with copies of lane 1's iPhone and iPad, and no job running
- **When:** I run `just native-sim-lanes refresh`
- **Then:** lane by lane, holding that lane's lock and lane 1's, each lane's iPhone and iPad copies are deleted and copied again from lane 1's, and it says which lanes it refreshed

---

### User Story 787:

- **Summary:** Refreshing the lane copies skips a busy lane instead of pulling its simulator from under its job
- **Status:** implemented in 7ae00520; verified on the host by `scripts/native/test-build-lane.sh` (rung 1; no simulator run, the Mac's screen locked)
- **Issues:** #980; split from story 786

#### Use Case:
- **As Igor,** refreshing the lane copies while other agents run simulator jobs
- **I want to** have a lane in use left alone and named, and a copy never replaced by a blank simulator
- **so that** no agent's run loses its simulator, and I know which lanes to refresh again

#### Acceptance Criteria:
- **Scenario:** A busy lane, or a busy lane 1
- **Given:** lane 3 is running a job, or lane 1 stays busy past the wait (`BUILD_LANE_REFRESH_WAIT`, default none)
- **When:** I run `just native-sim-lanes refresh`
- **Then:** lane 3's copies are left as they are (with a busy lane 1, every lane's are), the other lanes are refreshed, it names each lane it skipped, and it exits 75

---

### User Story 788:

- **Summary:** A report of every lane's simulator copies, which exist and which are missing
- **Status:** implemented in 7ae00520; verified on the host by `scripts/native/test-build-lane.sh` (rung 1; no simulator run, the Mac's screen locked)
- **Issues:** #980

#### Use Case:
- **As Igor,** or an agent, about to refresh the lane copies or wondering why a lane's Health check skipped
- **I want to** see each lane's iPhone and iPad copy, with its simulator id and whether it is booted, or that it is missing
- **so that** I can tell what a refresh would replace, without changing anything

#### Acceptance Criteria:
- **Scenario:** The report
- **Given:** four lanes, lane 2 with both copies and lane 4 with none
- **When:** I run `just native-sim-lanes list`
- **Then:** it prints one line per lane and device (lane 1's named simulators first), lane 2's with their ids and states, lane 4's as missing, and no simulator is made, deleted, shut down or booted

---

### User Story 789:

- **Summary:** A story ID used twice, or outside its journey's range, fails the host rung by name
- **Status:** implemented on branch `native/story-id-check-993`; verified on the host rung by `scripts/native/test-story-ids.sh` in `just test`: hand-written story trees (a duplicate in one file and across two, an ID outside its journey, overlapping ranges, an unlisted file, a missing one, a heading in another form, an unreadable IDs column) each fail with exactly the expected lines, a clean tree passes, and docs/stories passes once the duplicates on main (480–482 in the home screen journey, 980 in the whiteboard's) were renumbered and the journey table brought up to the IDs in use. The Linux lane's 1620–1639 (bead context-grabber-py4h): implemented in a2c281b8 on branch `chore/story-ids-linux-range-py4h`, verified on the host rung by `scripts/native/test-story-ids.sh`: a story numbered 1620 in a journey that doesn't hold it passes the check. The Linux lane's range is gone with the shared ledger (bead context-grabber-py4h, d30f74d1): 1620–1639 are Building and testing's, and a story there outside its journey's IDs fails like any other
- **Issues:** [#993](https://github.com/idvorkin/context-grabber/issues/993) (parallel PRs on 2026-11-19 collided on story IDs four times, each caught only by a reviewer or by luck; 480–482 and 980 were already duplicated on main), bead context-grabber-py4h (the Linux lane numbers its stories 1620–1639 without a row in the journey table until py4h's shared ledger lands)

#### Use Case:
- **As Igor,** with several agents adding stories at once
- **I want to** have the host rung fail on a story ID that is taken twice or sits outside its journey's ranges
- **so that** two stories never share an ID, and a collision costs a renumber before merge rather than a reviewer's luck

#### Acceptance Criteria:
- **Scenario:** A story takes an ID that is already used, or that its journey doesn't hold
- **Given:** the stories and the journey table with each journey's IDs, where no two journeys hold the same ID
- **When:** the host rung runs (on the Mac or the Linux box)
- **Then:** it fails naming each ID used twice with both places, each ID outside its journey's IDs, any two journeys whose IDs overlap, and any story file or heading it can't check; with none of these it passes

---

### User Story 791:

- **Summary:** A new story's ID is reserved, never picked from the branch alone
- **Status:** implemented in f50b4ddc, c195bb52 on branch `native/story-id-reserve` (bead context-grabber-jg3w); Mac build passes (rung 1.5); verified on the host rung by `scripts/native/test-story-ids.sh` in `just test`, against a fake gh and a fake main: an ID on the branch, on main, added by an open PR or reserved earlier is skipped; six reservations held open at once inside the ledger's lock get six different IDs, and a journey is found by a word from its row. This story's own ID, and 792 to 794, came from the command. A full journey's message (bead context-grabber-0e04): implemented in be441483 on branch `native/story-ids-range-0e04`, verified on the host rung by `scripts/native/test-story-ids.sh`: a full journey hands out nothing and its message names the journey, the next unused block (above every row's IDs on the branch and on main, and every ID on main, in an open PR or reserved) and every journey's free IDs; the whiteboard took 1160–1499. The pipeline's review and document steps and the agent instructions (bead context-grabber-1vvb): on branch `native/story-ids-pipeline-1vvb`, their instructions say a story they add or split off takes its ID from reserve and that none of them adds a journey's block by hand; docs and config only, checked by reading the merged instructions (no host test reads them). A too-large open PR (bead context-grabber-1338): implemented in e68a6a2e on branch `fix/story-ids-big-pr-1338`, verified on the host rung by `scripts/native/test-story-ids.sh`: the story-file patches from a too-large PR's file list, and the headings in a story file that has no patch, take their IDs; a PR that can be read neither way, or whose file list comes up short of its changed files, is named in a warning and the reservation still hands out IDs. The Linux lane's 1620–1639 (bead context-grabber-py4h): implemented in a2c281b8 on branch `chore/story-ids-linux-range-py4h`, verified on the host rung by `scripts/native/test-story-ids.sh`: reserve steps over 1620–1639 in a journey whose IDs run through them, never hands one out however many are asked for, and a full journey's next unused block skips 1600–1699 for 1700–1799. The shared ledger (bead context-grabber-py4h): implemented in d30f74d1 on branch `chore/shared-story-ledger-py4h`, verified on the host rung by `scripts/native/test-story-ids.sh` in `just test`, with a bare repository as the shared remote and two repositories as two machines: three reservations at once on each of two machines get six different IDs and the ledger holds all six, a reservation one machine made is skipped by the other's, the remote is picked by its idvorkin/context-grabber URL when origin is a fork, and 1620–1639 are handed out like any other IDs; one real reservation (1514) pushed refs/story-ids/ledger to GitHub
- **Issues:** bead context-grabber-1338 (gh refuses a very large PR's whole diff, and that one failure failed every reservation), bead context-grabber-jg3w (parallel PRs each took "the next free ID" from their own branch; each passed story 789's check alone, and main took duplicates four times on 2026-11-22: 955, 1101, 1155, 1113–1115), bead context-grabber-0e04 (the whiteboard ran out of IDs on 2026-11-22; agents went back to picking by hand), bead context-grabber-1vvb (the pipeline's review step picked IDs itself twice on 2026-11-22: #1274 added block 1600–1619 and used 1600–1602, #1276 used 232), bead context-grabber-py4h (the Linux lane numbers its stories 1620–1639 until py4h's shared ledger lands)
- **Spec:** [Story ID reservations](../superpowers/specs/2026-11-22-story-id-reservations-design.md)

#### Use Case:
- **As Igor,** with several agents adding stories at once, on this Mac and others
- **I want to** have each new story's ID handed out by one command that looks at main, every open PR and every agent's reservations, on any machine
- **so that** two branches stop taking the same "next free ID" and colliding once both merge

#### Acceptance Criteria:
- **Scenario:** Two agents reserve IDs in the same journey
- **Given:** main, the branch's own stories, the story headings open PRs add, and IDs any agent on any machine reserved in the last day
- **When:** each runs `scripts/native/story-ids.py reserve <journey> [n]`, at the same moment, on this Mac or one on this Mac and one on the Linux lane
- **Then:** each gets the lowest free IDs of that journey's ranges, one per line, none of them taken by any of those or by the other

- **Scenario:** A journey runs out of IDs (bead context-grabber-0e04)
- **Given:** a journey whose IDs column has fewer free IDs than asked for
- **When:** an agent reserves IDs in it
- **Then:** no ID is handed out, and the message names the journey as its row does, its IDs, the next unused block above every journey's IDs (on the branch and on main) and every ID taken on main, in an open PR or reserved, to add to the end of its row, and how many free IDs every journey has left

- **Scenario:** An open PR too large for GitHub to show whole (bead context-grabber-1338)
- **Given:** an open PR whose whole diff GitHub refuses
- **When:** an agent reserves IDs
- **Then:** the IDs that PR's stories add are still skipped, read from its story files' changes (or, for a story file too large to show, every story in that file on the PR), and if the PR can't be read either way (or GitHub's list of its files comes up short) the reservation still hands out IDs and its message names that PR as unread

---

### User Story 792:

- **Summary:** A reservation lapses after a day, or once its story is on main
- **Status:** implemented in f50b4ddc, c195bb52 on branch `native/story-id-reserve` (bead context-grabber-jg3w); Mac build passes (rung 1.5); verified on the host rung by `scripts/native/test-story-ids.sh` in `just test`: a reservation two days old is handed out again, one whose ID reached main is dropped from the ledger, a live one is kept. The shared ledger (bead context-grabber-py4h): implemented in d30f74d1 on branch `chore/shared-story-ledger-py4h`, verified on the host rung by `scripts/native/test-story-ids.sh` in `just test`, with a bare repository as the shared remote and two repositories as two machines: a reservation two days old is handed out again and one whose ID reached main leaves the shared ledger
- **Issues:** bead context-grabber-jg3w
- **Spec:** [Story ID reservations](../superpowers/specs/2026-11-22-story-id-reservations-design.md)

#### Use Case:
- **As Igor,** with agents that sometimes abandon a branch
- **I want to** have an unused reservation give its ID back on its own
- **so that** a journey's range doesn't fill with IDs no story will ever use

#### Acceptance Criteria:
- **Scenario:** An old reservation
- **Given:** the shared ledger holds one reservation made over 24 hours ago and another whose story has merged
- **When:** the next reservation runs
- **Then:** neither holds its ID any longer: the first ID can be handed out again, and the second is taken because main has it; both leave the ledger

---

### User Story 793:

- **Summary:** Right before merging, the story IDs are checked on the branch merged with main as it is now
- **Status:** implemented in f50b4ddc, c195bb52 on branch `native/story-id-reserve` (bead context-grabber-jg3w); Mac build passes (rung 1.5); verified on the host rung by `scripts/native/test-story-ids.sh` in `just test`, on a throwaway repository: a branch that passes alone but adds an ID main took since fails naming both places, a branch with a free ID passes, a branch that conflicts with main fails
- **Issues:** bead context-grabber-jg3w
- **Spec:** [Story ID reservations](../superpowers/specs/2026-11-22-story-id-reservations-design.md)

#### Use Case:
- **As Igor,** with PRs merging while others wait at the end of the pipeline
- **I want to** have the agent check the story IDs against main once more, right before it merges
- **so that** a collision another merge made in the meantime is caught on the branch, not on main

#### Acceptance Criteria:
- **Scenario:** Main gained a story with the same ID since the branch was checked
- **Given:** the branch's PR has passed the pipeline, and main has since merged another PR that added a story with one of its IDs
- **When:** the agent runs `just pre-merge` immediately before `gh pr merge`
- **Then:** it fails naming the ID and both places, judging the branch as pushed (the pipeline's own commits included, even when the checkout is behind them) merged with main, without touching the checkout

---

### User Story 794:

- **Summary:** A reservation that can't see everything hands out nothing
- **Status:** implemented in f50b4ddc, c195bb52 on branch `native/story-id-reserve` (bead context-grabber-jg3w); Mac build passes (rung 1.5); verified on the host rung by `scripts/native/test-story-ids.sh` in `just test`: with the fake gh failing to list the open PRs it prints no ID, exits 1 and leaves the ledger unwritten; a word that names two journeys and a journey with too few free IDs fail the same way, the last naming the next unused block to add (story 791; be441483, dbb7d43b on branch `native/story-ids-range-0e04`, bead context-grabber-0e04). The shared ledger (bead context-grabber-py4h): implemented in d30f74d1 on branch `chore/shared-story-ledger-py4h`, verified on the host rung by `scripts/native/test-story-ids.sh` in `just test`, with a bare repository as the shared remote and two repositories as two machines: with the shared ledger unreachable it prints no ID and names the shared ledger; with no remote at idvorkin/context-grabber it names the remote to add
- **Issues:** bead context-grabber-jg3w
- **Spec:** [Story ID reservations](../superpowers/specs/2026-11-22-story-id-reservations-design.md)

#### Use Case:
- **As Igor,** with agents that reserve IDs from flaky networks
- **I want to** have a reservation fail rather than guess when it can't read main, the open PRs or the shared ledger
- **so that** an ID chosen blind, the bug reservations exist to stop, is never handed out

#### Acceptance Criteria:
- **Scenario:** The open PRs can't be listed
- **Given:** gh can't reach GitHub, main can't be fetched, or the shared ledger can't be read or written
- **When:** an agent runs the reserve command
- **Then:** it prints no ID, says what it couldn't read, exits non-zero and reserves nothing; it fails the same way when the journey word names more than one journey or the journey has no free ID left, which names the next unused block to add to its row (story 791)

---

### User Story 1515:

- **Summary:** The pipeline won't push a story ID another open PR holds
- **Status:** implemented in babe86bc on branch `chore/story-ids-claimed-6p52` (bead context-grabber-6p52); verified on the host rung by `scripts/native/test-story-ids.sh` in `just test`, against a fake gh and a throwaway repository: a new ID no open PR adds passes, one another open PR adds fails naming the ID, the PR and its branch, one whose only other PR shares a commit subject with the branch passes, and with the open PRs unlisted it fails; run once against GitHub from this branch it passed (1515, 3 open PRs). The gate runs it as its lint command once this config is on main
- **Issues:** bead context-grabber-6p52 (on 2026-11-24 the pipeline's review and document steps picked story IDs themselves three times despite the instruction to reserve: 1609/1610, and 1292/1293 twice, the last two colliding with another open PR and failing every lane's pre-merge until main was renumbered in #1408)
- **Spec:** [Story ID reservations](../superpowers/specs/2026-11-22-story-id-reservations-design.md)

#### Use Case:
- **As Igor,** with the pipeline's own steps adding and splitting stories on many branches at once
- **I want to** have the pipeline refuse to push a story ID that another open PR already adds
- **so that** a hand-picked ID is caught on its branch, not on main where it blocks every merge

#### Acceptance Criteria:
- **Scenario:** The review step splits a story and takes an ID another open PR adds
- **Given:** an open PR on another branch adds story N, and this branch's commits over main add story N too
- **When:** the pipeline's lint step runs the story ID claim check
- **Then:** it fails naming N, that PR and its branch, and says to take a new ID from `story-ids.py reserve` and renumber; it passes when the only open PR adding N is this branch's own, found by a shared commit subject even after a rebase, and fails rather than guess when it can't fetch main or list the open PRs

---

### User Story 796:

- **Summary:** A journey's stories can live in several files, and every ID is still checked once and in range
- **Status:** implemented on branch `native/whiteboard-stories-split-9yxo` (bead context-grabber-9yxo), where the whiteboard's 8,400-line story file became nine files by feature area with no story changed; verified on the host rung by `scripts/native/test-story-ids.sh` in `just test`: a two-file journey passes, and an ID used in two of its files, an ID outside its ranges in its second file, a part the row doesn't link, a linked part that is missing and a file linked by two journeys each fail with exactly the expected lines; docs/stories passes with the whiteboard split
- **Issues:** bead context-grabber-9yxo (parallel PRs kept colliding in the one whiteboard story file)

#### Use Case:
- **As Igor,** with several agents adding whiteboard stories at once
- **I want to** have a big journey's stories split into files by feature area, still under one row of the journey table
- **so that** parallel PRs stop colliding in one file, while two stories still never share an ID

#### Acceptance Criteria:
- **Scenario:** A journey's row links several files
- **Given:** the journey table, where one journey's row links each of its files and gives one IDs column
- **When:** the host rung runs
- **Then:** every story in any of those files is checked against that journey's IDs and against every other story's ID, and a story file no row links, a linked file that is missing, or a file two rows link fails by name

---

### User Story 980:

- **Summary:** One booted simulator per build lane, left booted between runs
- **Status:** implemented in f63a8e0, d1e8e18; verified on the host by the ladder's map self-test (265 checks: the phone and the iPad booted with `bootstatus -b`, nothing shut down at the end) and on the simulator 2026-11-17 (rung 2, `--changed` WhiteboardTurnUITests and GymTimerUITests, twice in a row): the old scripts booted 3 times each run (236 s, 273 s), these 2 then 1 (240 s, 178 s); the second run found the iPad booted and used it with no boot (CoreSimulator.log, boots inside each rung's own window). Per lane (#954): implemented in 33c2bb47; verified on the host by `scripts/native/test-build-lane.sh` (a busy lane's simulator left booted, the lane's other device and a simulator of no lane shut down, an idle lane's shut down only past the lane count, one lane shutting every other down as before)
- **Issues:** the boot-less brief of 2026-11-15 (Igor: "sure do it"); 31 boots on 2026-11-14, and the disk full of wallpaper snapshots on 2026-11-17; #954 (Igor, 2026-11-19, on the 48 GB M5 Pro: "we can run 4 builds at once on this machine")

#### Use Case:
- **As Igor,** running simulator checks many times a day, from several agents at once on a Mac with the memory for it
- **I want to** have the simulator a run used left booted for that lane's next run, and no more booted than the Mac has build lanes
- **so that** each run doesn't pay a boot's 300 MB of wallpaper snapshots that are never removed, its heat and its wait, and booted simulators never starve each other or get shut down under another job

#### Acceptance Criteria:
- **Scenario:** Two runs on one device
- **Given:** a simulator run that just passed or failed on the iPhone simulator of its lane
- **When:** the next run in that lane needs the iPhone simulator too
- **Then:** it finds it booted and uses it without a boot, and the simulator log shows no new boot

- **Scenario:** Another lane is busy
- **Given:** a Mac with four build lanes, and a job in lane 1 running its tests on the iPhone simulator
- **When:** a job in lane 2 boots its own iPhone simulator (*iPhone 17 lane 2*)
- **Then:** lane 1's simulator stays booted and its tests run on; lane 2's iPad, if booted, and any simulator that belongs to no lane are shut down first

- **Scenario:** More booted than there are lanes
- **Given:** a Mac with two build lanes, lane 2's job about to boot, and lane 1 idle with its simulator still booted from its last run, plus lane 3's from when the Mac had more lanes
- **When:** lane 2 boots its simulator
- **Then:** idle simulators are shut down until no more than two are booted, its own included, and a busy lane's never is

- **Scenario:** A one-lane Mac
- **Given:** a 16 GB Mac, or `BUILD_LANES=1`
- **When:** a job boots its simulator
- **Then:** every other booted simulator is shut down first, exactly as before lanes

---

### User Story 981:

- **Summary:** A climb on both the iPhone and the iPad switches device at most once
- **Status:** implemented in f63a8e0, d1e8e18; verified on the host by the ladder's map self-test (none booted: the phone, then the iPad; the iPad booted: the iPad, then the phone, the iPad shut first). verified on the simulator 2026-11-17: a second climb started on the iPad the first left booted (`rung 2 iPad simulator: 0 s`), then switched once to the iPhone

#### Use Case:
- **As Igor,** waiting on a whiteboard change, which runs its drawing classes on the iPad and the smoke on the iPhone
- **I want to** have the ladder run all of one device's steps, then all of the other's, starting with the one already booted
- **so that** a climb costs one boot at most, and a second climb right after costs no more than the first

#### Acceptance Criteria:
- **Scenario:** The iPad left booted by the last climb
- **Given:** the iPad simulator is booted and a branch that changes the whiteboard and the Gym Timer
- **When:** I run `just test-ladder`
- **Then:** the whiteboard's classes run first on the iPad as it is, then the iPad is shut down and the iPhone booted once for the timer's classes and the smoke, and the iPhone is left booted

---

### User Story 982:

- **Summary:** The whiteboard's ⌘V test runs on a simulator that is already up
- **Status:** not implemented. The ladder still fresh-boots the iPad when `WhiteboardPasteUITests` runs, and only then, and `test-whiteboard-ui.sh` still reboots once per suite run. The one experiment (the ⌘V test three times on one boot, 2026-11-17) failed before any key was pressed, on a tap, at load 300 on a stalled screen, so it says nothing about keys yet

#### Use Case:
- **As Igor,** running the whiteboard's paste tests again and again
- **I want to** have ⌘V and ⌘Z reach the app on a simulator that earlier runs used
- **so that** the whiteboard suite doesn't reboot the iPad on every run to get its keys through

#### Acceptance Criteria:
- **Scenario:** The keys test, twice on one boot
- **Given:** the iPad simulator booted, with the keys test already run on it
- **When:** the whiteboard suite or the ladder runs `WhiteboardPasteUITests` again
- **Then:** ⌘V pastes and ⌘Z takes it back, with no reboot in between

---

### User Story 983:

- **Summary:** A hot Mac gets its simulator shut down at the end of a run
- **Status:** implemented in f63a8e0, 1390e3d; verified on the host by the ladder's map self-test (a thermal warning from `pmset` shuts the simulator down and says why; a warning level back at 0 leaves it booted). The heat watch's own messages are not read: they live off the repo
- **Issues:** Larry's heat stop of 2026-11-17 (heavy thermal at load 84 during a ladder run)

#### Use Case:
- **As Igor,** whose Air throttles when it runs hot
- **I want to** have the ladder shut its simulator down rather than leave it booted when the Mac is hot
- **so that** a simulator left up for the next run never adds to the heat that stopped this one

#### Acceptance Criteria:
- **Scenario:** A run ends on a hot Mac
- **Given:** macOS reports a thermal or performance warning level above 0 (a level back at 0 after an earlier warning is cool; the load alone doesn't count: on this Mac it counts hung processes, and shut a cool run's simulator down at load 71 on 2026-11-17)
- **When:** the ladder's simulator rung ends, pass or fail
- **Then:** it shuts its simulator down and prints why; on a cool Mac it leaves it booted

---

### User Story 984:

- **Summary:** The wallpaper snapshots of every shut-down simulator are pruned before a boot
- **Status:** implemented in c2067b7 (through machine-doctor, which skipped every time: its `sims` command was never merged); our own prune in 9ae4b49, 0230c40; verified on the host by the ladder's map self-test (the prune runs before the boot and clears both shut-down simulators' snapshots) and on the simulator rung, 2026-11-18 (GymTimerUITests: the boot cleared the iPhone 17 and iPad snapshots, 910 MB, while both were shut down)
- **Issues:** health-04, 2026-11-17: 3.5 GB of snapshots on the iPad simulator since the morning, the disk twice under 10 GB free

#### Use Case:
- **As Igor,** whose Air's disk fills with wallpaper snapshots no one evicts
- **I want to** have them deleted on the shut-down simulators before a boot
- **so that** the boots can't push the disk under the line that stops every build, and no one has to clear it by hand

#### Acceptance Criteria:
- **Scenario:** A boot
- **Given:** the target simulator is shut down
- **When:** a run boots it
- **Then:** the wallpaper snapshots of every shut-down simulator, the target among them, are deleted first, whatever the free disk, then the simulator boots

---

### User Story 985:

- **Summary:** No more simulators booted than the Mac has build lanes (one on a 16 GB Mac)
- **Status:** implemented in f63a8e0; verified on the host by the ladder's map self-test (the iPad booted: it is shut down before the phone boots). Per lane (#954): implemented in 33c2bb47; verified on the host by `scripts/native/test-build-lane.sh`
- **Issues:** split from story 980; #954

#### Use Case:
- **As Igor,** on a 16 GB Air where one booted simulator takes about 10 GB, or a 48 GB Mac with room for four
- **I want to** have any simulator past the Mac's lane count shut down before a run's own device boots, never one a busy lane is using
- **so that** booted simulators never starve each other, and no job loses its simulator mid-run

#### Acceptance Criteria:
- **Scenario:** Another simulator is up, on a one-lane Mac
- **Given:** a Mac with one build lane, and a different simulator booted by any earlier run
- **When:** a run needs its own device
- **Then:** the other is shut down before its device boots, so only one is ever booted

- **Scenario:** Another lane's simulator is up
- **Given:** a Mac with four build lanes and another lane's simulator booted
- **When:** a run needs its own device
- **Then:** the other lane's simulator is left booted, busy or idle, while no more than four are booted with this run's

---

### User Story 986:

- **Summary:** A simulator already booted is used as it is, with no prune and no boot
- **Status:** implemented in c2067b7; verified on the host by the ladder's map self-test (the device boots with `bootstatus -b`, which returns at once when it is up)
- **Issues:** split from story 984

#### Use Case:
- **As Igor,** running checks one after another on the same device
- **I want to** have a run that finds its simulator booted skip the snapshot prune and the boot
- **so that** a run on a booted simulator costs no extra wait

#### Acceptance Criteria:
- **Scenario:** The target is already booted
- **Given:** the target simulator is booted
- **When:** a run uses it
- **Then:** nothing is pruned and nothing boots

---

### User Story 987:

- **Summary:** The wallpaper snapshots of every shut-down simulator are pruned when a simulator run ends
- **Status:** implemented in 9ae4b49, 0230c40; verified on the host by the ladder's map self-test (the rung prunes again after its last boot) and on the simulator rung, 2026-11-18 (GymTimerUITests: the teardowns ran and found nothing more after the boot's prune; the iPhone left booted kept its own)
- **Issues:** split from story 984; Igor, 2026-11-18: "can we do that cleanup as part of test tear down since it's in sim"

#### Use Case:
- **As Igor,** whose Air's disk fills with wallpaper snapshots no one evicts
- **I want to** have them deleted on the shut-down simulators when a simulator run ends
- **so that** the snapshots a run's boots left behind are gone before the next build needs the disk

#### Acceptance Criteria:
- **Scenario:** A simulator run ends
- **Given:** the ladder's simulator rung, the whiteboard suite or the smoke is running
- **When:** it tears down, pass or fail
- **Then:** the wallpaper snapshots of every shut-down simulator are deleted; the simulator left booted keeps its own

---

### User Story 988:

- **Summary:** A booted simulator's wallpaper snapshots are never pruned
- **Status:** implemented in 9ae4b49; verified on the host by the ladder's map self-test (a booted one's snapshots stay; one booted between the look and the delete stays, and goes once it is shut down again)
- **Issues:** split from story 984

#### Use Case:
- **As Igor,** whose simulators PosterBoard holds open while they run
- **I want to** have the prune leave a booted simulator's snapshots alone, even one that booted after the prune looked
- **so that** a prune never pulls files out from under a running simulator

#### Acceptance Criteria:
- **Scenario:** A booted simulator
- **Given:** a simulator is booted, even one that booted after the prune looked
- **When:** the prune runs
- **Then:** its snapshots are left alone

---

### User Story 989:

- **Summary:** The prune says what it did in one line and never fails a boot or a run
- **Status:** implemented in 9ae4b49; verified on the host by the ladder's map self-test (one line with the simulators and the MB; one line when there is nothing; a failing `simctl` is a line and exit 0)
- **Issues:** split from story 984

#### Use Case:
- **As Igor,** reading a run's output
- **I want to** see one line naming the simulators cleared and the MB freed, and have a failed prune ignored
- **so that** housekeeping never hides a test result or stops a run

#### Acceptance Criteria:
- **Scenario:** What the prune says
- **Given:** any prune, including one whose `simctl` fails
- **When:** it finishes
- **Then:** one line names the simulators cleared and the MB freed (or says there was nothing), and it exits 0 so the boot or the run goes on

---

### User Story 1010:

- **Summary:** The smoke judges the Gym Timer's workout only once its last line has landed, and says which way a short one went
- **Status:** implemented in 20d11016; verified on the host rung (`just test`) and the simulator rung (`SMOKE_ONLY=timer just native-test-sim`, iPhone, 2026-11-19: all passed, the log read 18253 ms into the launch against the last `timer_` line, the finish's `timer_session inactive`, at 17839 ms)
- **Issues:** [#389](https://github.com/idvorkin/context-grabber/issues/389) (a workout seen ending early: 3 of 4 duck windows, no Live Activity end; the run could not say whether the workout stopped or the smoke read too soon)

#### Use Case:
- **As Igor,** reading a simulator smoke run that failed the timer's checks
- **I want to** have the smoke wait for the workout's last lines before it judges, and say how long after the last one it read the log
- **so that** a slow simulator never fails a good workout, and a failure says whether the workout stopped early or the smoke read too soon

#### Acceptance Criteria:
- **Scenario:** The smoke's timer run
- **Given:** the smoke starts its short Gym Timer workout
- **When:** the workout finishes
- **Then:** the smoke judges the log only after the finish's letting go of the audio and the Live Activity's end (or its one *unavailable* line) have been logged, waiting a bounded time for each, and prints how long after the workout's last `timer_` line it read the log
- **And:** a line that never comes is a failure naming what was missing and the last `timer_` line the workout did log, with its second into the workout, so a stopped workout reads differently from a slow one

---

### User Story 1011:

- **Summary:** One command sends the current commit to TestFlight, beside the cable install
- **Status:** implemented in 1b6d88dc and e38dd576; the archive and App Store export verified on the Mac (`just testflight --export-only`, 2026-11-20: 2.0.0 (2305) from 53f4dd93, the app, widgets and share extension signed Apple Distribution with App Store profiles); the upload and the TestFlight install wait for Igor's key and app record (docs/TESTING.md "TestFlight")
- **Issues:** [#1012](https://github.com/idvorkin/context-grabber/issues/1012)

#### Use Case:
- **As Igor,** away from the Mac or with the phone not on its cable
- **I want to** send a commit to TestFlight with one command and install it from the TestFlight app
- **so that** a build reaches my phone without a cable, while the cable install stays for everyday work ([spec](../superpowers/specs/2026-11-20-testflight-lane-design.md))

#### Acceptance Criteria:
- **Scenario:** Shipping a clean commit
- **Given:** a clean checkout and the App Store Connect key set up in the environment or the ignored local file
- **When:** Igor runs `just testflight`
- **Then:** the app is archived in its release build with the commit stamped in, signed with its widgets and share extension for App Store distribution, and uploaded, with version 2.0.0 and the commit count as its build number
- **And:** the lane ends by naming the version, the build number and the commit, and installed from TestFlight the build names that commit in its session log's first line

---

### User Story 1012:

- **Summary:** The TestFlight lane says what is missing before it spends a build
- **Status:** implemented in 1b6d88dc; verified on the Mac by hand (no key: exit 78 naming the three values; a dirty checkout: exit 65 naming the files; a key file inside the checkout refused), and on the host rung from the dry run (`scripts/native/test-testflight.sh`, ff17cac9)
- **Issues:** [#1012](https://github.com/idvorkin/context-grabber/issues/1012)

#### Use Case:
- **As Igor,** running the TestFlight lane before its one-time setup is done, or from a checkout with changes in it
- **I want to** have the lane stop at once, naming what is missing or changed
- **so that** a five-minute release build never ends in an upload that could not happen, and no build on TestFlight is a commit that doesn't exist

#### Acceptance Criteria:
- **Scenario:** No key, or uncommitted changes
- **Given:** the key's id, its issuer or its file is missing, or the checkout has uncommitted changes
- **When:** Igor runs `just testflight`
- **Then:** it stops before building, naming which of the three is missing and where they are read from, or the changed files

---

### User Story 1013:

- **Summary:** The TestFlight lane can build and sign without uploading, and needs no key to do it
- **Status:** implemented in 1b6d88dc and e38dd576; verified on the Mac (`just testflight --export-only`, 2026-11-20, no key set: the package signed and named, nothing uploaded); that it needs no key, on the host rung from the dry run (`scripts/native/test-testflight.sh`, ff17cac9)
- **Issues:** [#1012](https://github.com/idvorkin/context-grabber/issues/1012)

#### Use Case:
- **As Igor,** or an agent without the App Store Connect key
- **I want to** run the release build and its App Store signing on their own
- **so that** a release-only compile failure or a signing problem shows up before the day a build has to reach the phone

#### Acceptance Criteria:
- **Scenario:** Export only
- **Given:** a clean checkout, with or without the key
- **When:** `just testflight --export-only` runs
- **Then:** it archives and signs the package for App Store distribution, names where the package is, and uploads nothing

---

### User Story 1014:

- **Summary:** A change only to the replay of Larry's board changes runs its host fixtures, not the whiteboard's UI tests
- **Status:** implemented on branch `native/replay-host-route-1036`; verified on the host rung (`scripts/native/test-ladder-map.sh` runs the real selector and smoke selector: the replay alone, the harness, the shared planner, the replay with the canvas and with chat) and compared on one commit (944718ed, 2026-11-21): the old route ran 15 whiteboard classes, 63 cases, first run passed with one skip, plus the whiteboard smoke, 1,605 s of a simulator lane; the new route ran lint 1 s, the host rung 181 s and the Mac build 38 s, and no simulator. A one-line break of the replay's Keep step failed the host's replay fixtures (`BoardReplayTests`), which no UI test could see, as the app never calls the replay
- **Issues:** [#1036](https://github.com/idvorkin/context-grabber/issues/1036); bead `context-grabber-wcmi`

#### Use Case:
- **As Igor,** waiting on a fix to how Larry's board changes replay on a copy of a board
- **I want to** have the ladder run the host tests that replay the real boards, and not every whiteboard UI test on the iPad
- **so that** a change no screen can show costs seconds on the host, not twenty minutes of a build lane, while a change to what the canvas draws still runs everything

#### Acceptance Criteria:
- **Scenario:** A change to the replay alone, to what it shares with the canvas, or to both
- **Given:** a branch that changes only the replay, which the app never runs
- **When:** the test ladder climbs
- **Then:** it runs lint, the host tests with their replay fixtures and the Mac build, and no simulator build, UI test class or smoke section, saying why; a change to the planner the replay shares with the canvas still runs every whiteboard class and the whiteboard smoke, and a change to the replay and the canvas together gets everything either would

---

### User Story 1015:

- **Summary:** The iPad's own UI test runs on the iPad, and a skip there fails rather than passes
- **Status:** implemented on branch `native/ipad-class-destination-1037`; verified on the host rung (`scripts/native/test-ladder-map.sh`: the class alone, beside an iPhone and a whiteboard class, and under `--all`, from the real selector's dry run; climbs with fakes put it on the iPad's simulator and the iPhone class on the iPhone's, a skip there fails, `--full` keeps it) and on the simulator (2026-11-21, lane 5's *iPad Pro 11-inch (M5)*: `just test-ladder --rung 2 --changed native/UITests/IPadUITests.swift` ran the landscape test on the iPad for the first time, 0 passed, 2 failed, 0 skipped, 214 s: the location prompt over Places, and on the retry the call launcher; before, it went to the iPhone and skipped. The failure is bead `context-grabber-4j2p`, fixed in [1f81cc1e](https://github.com/idvorkin/context-grabber/commit/1f81cc1e): green on lane 2's iPad, 2026-11-22, 1 passed and 0 skipped on the ladder's rung 2)
- **Issues:** [#1037](https://github.com/idvorkin/context-grabber/issues/1037); bead `context-grabber-hkqy`

#### Use Case:
- **As Igor,** trusting a green ladder to mean the iPad's home screen was checked
- **I want to** have the test that turns the iPad to landscape and opens each launcher run on an iPad simulator whenever it is chosen
- **so that** a passing run never hides that the iPad's test only skipped on a phone

#### Acceptance Criteria:
- **Scenario:** The iPad's test chosen with iPhone classes, and the iPad's test skipping
- **Given:** a change that selects the iPad's launcher test and an iPhone class, or a run of every class
- **When:** the test ladder climbs
- **Then:** the iPad's test runs on the iPad's simulator in a run of its own and the iPhone class on the iPhone's, the step says how many of the iPad's tests passed and skipped, and a skip on the iPad fails the climb, saying the destination was wrong

---

### User Story 1016:

- **Summary:** A change can be followed from what the ladder chose, through the lanes, to the phone
- **Status:** implemented on branch `native/ladder-ledger-1038`; verified on the host rung: `scripts/native/test-ladder-map.sh` reads the ledger a climb with fakes writes (one run id across the lane's process, the start's selection and simulators, the lane and its wait, the device, a warm or cold build, each rung, a pass, a failure's first rung, a locked screen as unavailable, a skip on the iPad, the timing lines' run id, none for a dry run or `off`), and `scripts/native/test-ladder-report.sh` holds a fixture's retry, wrong-device skip, missing deploy, upload alone, interrupted and censored climbs apart and records an install through the recorder. Two real climbs on 2026-11-21 wrote the ledger (lint passed; rung 2 on a locked screen: lane 1, no wait, unavailable). The sample of the 20 latest climbs from the logs already on this Mac: the whiteboard's 11 climbs ran a median of 611 s (p90 2,178 s, 9 known) with 7 first-pass failures and 106 avoidable lane minutes, chat's 5 ran 262 s (p90 442 s) with 2, and not one change had a known delivery: no install had ever been recorded. A climb with no start line is listed under area unknown, marked `(no start line)`, instead of stopping the report in [9d84db3b](https://github.com/idvorkin/context-grabber/commit/9d84db3b) (bead `context-grabber-o9sv`); verified on the host rung (`scripts/native/test-ladder-report.sh`'s orphan fixture)
- **Issues:** [#1038](https://github.com/idvorkin/context-grabber/issues/1038); bead `context-grabber-qawx`; bead `context-grabber-o9sv`

#### Use Case:
- **As Igor,** deciding whether the next hour goes into test selection, a slow test, lane capacity or getting builds onto the phone
- **I want to** see, for each change, what the ladder chose and why, how long it waited for a lane, how long it ran, what retried or skipped, and when it reached a device
- **so that** I put the work where the minutes actually go, not where a class's duration alone suggests

#### Acceptance Criteria:
- **Scenario:** A failure and its retry, a skip on the wrong device, and a change never installed
- **Given:** climbs of the ladder that failed and then passed on a second attempt with a case retried, one whose iPad test skipped, one that never finished, and a change that was merged but never installed or only uploaded to TestFlight
- **When:** I run `just ladder-report`
- **Then:** each climb shows as itself (its attempt, its outcome and first failure, the retried case, the skipped coverage, a delivery that is unknown, only uploaded, or the install that delivered it), and by kind of change I see the median and slowest-tenth queue and execution times with their counts, the first-pass failures, the skipped coverage, the share delivered, and the kinds ranked by the lane minutes they could save

- **Scenario:** A climb whose start line is missing
- **Given:** a climb in the ledger with its other lines but no start line (dropped, or interleaved away by another lane)
- **When:** I run `just ladder-report`
- **Then:** the report still runs, that climb is listed under area unknown and said to have no start line, and the climbs beside it are reported as before

---

### User Story 1017:

- **Summary:** A UI test that passed only on its retry fails the run, unless it is a quarantined known flake
- **Status:** implemented on branch `native/flaky-retry-86z1`; verified on the host rung: `scripts/native/test-xcodebuild-log.sh` (a fake xcodebuild whose case fails, then passes on its retry: the run fails with exit 65 naming it, after a stopped hang too; a quarantine line with a bead lets the run pass, one for the whole class too, one without a tracker quarantines nothing), `scripts/native/test-ui-timings.sh` (the flake named as counted, the quarantined one named apart, a repeat of a passing case is no retry), `scripts/native/test-ladder-report.sh` (a climb that passed on a retried case and one the wrapper failed for it are flaky, a quarantined flake still passes, a repeat is no retry). Read against every slot's timing lines on 2026-11-22: counted from the states, 7 cases in the whole history passed only on retry (PaperGhosts 5 of them, fixed by #1051); the 57 retried PaperPaste lines and PaperLines' 32 were repeats asked for (#906's 40 iterations), not retries, so the one quarantine is the paste flake still open (bead `context-grabber-2jw`). After a hang, a suite failed only by retried tries is judged as a flake in [037e2870](https://github.com/idvorkin/context-grabber/commit/037e2870) and [a76fb07e](https://github.com/idvorkin/context-grabber/commit/a76fb07e) (bead `context-grabber-36f`); verified on the host rung (`just test`: `test-xcodebuild-log.sh`'s fake xcodebuild fails a case, passes it on its retry, closes the suite *failed* and hangs; the run fails naming the flake, passes when it is quarantined, and still fails as a failed run when another case's last try failed or the flake count can't read the log). The fail-closed check was introduced in [7f23b42a](https://github.com/idvorkin/context-grabber/commit/7f23b42a) and completed in [ad951fd8](https://github.com/idvorkin/context-grabber/commit/ad951fd8) (bead `context-grabber-z8p7`). Verified on the host rung with `scripts/native/test-xcodebuild-log.sh` (normal exits, a stopped hang, screen locks, a clean pass with a parser error, and a quarantined retry with a timing ledger write error).
- **Issues:** bead `context-grabber-86z1` (whiteboard architecture review, item 7: "the retry hides flakes from pass/fail"); bead `context-grabber-z8p7` (review finding on #1110: with ui-timings failing, a run that passed only on its retry exited 0, its flake list empty); bead `context-grabber-36f` (2026-11-14 trim run: `WhiteboardPaperLinesUITests.testTheFirstStrokeAfterTheMenuDraws` failed once and passed on its retry, then xcodebuild hung and was stopped; the suite line said *failed* because one try had, so the rung failed as a failed run and stopped before the other classes and the smoke)

#### Use Case:
- **As Igor,** reading whether a change's UI tests passed
- **I want to** have a test that failed once and passed on its retry count as a failure, unless it is a known flake someone is chasing
- **so that** flakes get fixed instead of hiding behind the retry, and a green run means every test passed the first time

#### Acceptance Criteria:
- **Scenario:** A flake, a quarantined flake and a repeat
- **Given:** a UI test run where one case fails and then passes on its retry, another does the same but is quarantined with the bead that tracks it, and a third is asked to run three times and passes each time; whether xcodebuild ends by itself or hangs after the tests and is stopped, with the suite's closing line saying *failed* because a try failed; and whether or not the flake check can read the run
- **When:** the run ends and I run `just ladder-report`
- **Then:** the run fails, naming the first case as a flake; the quarantined case is named as quarantined with its bead and doesn't fail the run; the repeats are counted as repeats, not retries; a quarantine line with no bead or issue quarantines nothing; and the report calls a climb that failed on flakes alone flaky, counts it as a failed attempt, and shows each class's passes on retry apart from its repeats; after a stopped hang the flakes are judged the same way, and a run where any case's last try failed still fails as a failed run; when the flake check can't read the run, a run in which any try failed exits 65 saying the flakes weren't checked, including after a hang or screen lock, while a run with no failed try keeps its ordinary result; and a failure to save the timing records leaves a completed flake verdict in effect

---

### User Story 1018:

- **Summary:** A UI test that fails after the Mac's screen has locked during the run is sent back to be rerun, rather than failing as if it were broken
- **Status:** implemented on branch `native/voice-test-lock-2v63`; verified on the host by `scripts/native/test-xcodebuild-log.sh` (the lock probe faked: a case that fails after the screen locked makes the run exit 75 with the line, whether xcodebuild hangs or ends, and so does a case that passed only on its retry; a passed run stands with a note; a locked run that failed with no failed case, a case that failed before the lock, and a run never locked fail as before). On the simulator (iPhone 17, 2026-11-21 at 07880738, the Mac's screen locked), the voice button test's app aborted where the bead's runs did, both tries, and the wrapper ended that run with exit 75 and the line. Unlocked, the same test passed twice that morning (05:29 and 05:35, the screen unlocked from 04:32); its pass unlocked on this branch is still to see; amended in a344919f (story 1023: a simulator run is stopped at the lock instead)
- **Issues:** bead `context-grabber-2v63` (`ChatNewThreadUITests.testTheVoiceButtonOpensANewChatWithItsMicTapped` failed, then the app crashed on the retry, on two agents' runs of 2026-11-21: all four crash reports are the app aborting inside Apple's audio toolbox, its call to the simulator's audio server timing out as the mic opened, each while the Mac's screen was locked); [#419](https://github.com/idvorkin/context-grabber/issues/419) (a locked Mac starves the simulator's audio)

#### Use Case:
- **As Igor,** reading a UI test run while I'm away from the Mac
- **I want to** have a test that failed after the screen locked named as that, and sent back to be rerun unlocked
- **so that** nobody chases a crash in the mic, the call or the timer that only a locked Mac makes, and a real failure still fails

#### Acceptance Criteria:
- **Scenario:** The screen locks during a UI test run
- **Given:** a UI test run, during which the Mac's screen locks at some point, even for a few seconds
- **When:** the run ends
- **Then:** if every case that failed (a retried pass's first try included) failed after the screen was first seen locked, the run stops with exit 75, as a run that could not run does, saying the screen locked during it and when, that a locked Mac starves the simulator's audio and stalls UI tests, and to unlock and rerun; if a case had already failed before the lock, or nothing that failed was a test (a build that failed), the run fails as before and names the lock; a run that passed stands, with a line saying the screen locked; a run during which the screen never locked is as before
- **And:** on a simulator the run doesn't wait to end: a lock seen while its tests are still running stops it at once (story 1023), so this reading applies to a run that isn't on a simulator, and to a simulator run whose tests had all finished when the lock was seen. A failed try whose flake check couldn't complete exits 65 under story 1017.

---

### User Story 1019:

- **Summary:** What PaperKit itself does, that the whiteboard relies on, is checked on the simulator before it reaches the iPad
- **Status:** implemented in 5edb8156; verified on the simulator rung (iOS 27.2, 2026-11-21: `just native-test-contracts` on lane 1's *iPad Pro 11-inch (M5)*, 12 of 12 on each of two runs, after a run on lane 3's iPad failed two checks because the picker kept a pick from an earlier launch, so each run now starts it on the pen). Writing them found two things nobody knew: a set built from an older markup than the held one is refused and takes the held one's newer ink with it (the shape of #999 and #1015), and a pick made in code moves the picker but not the paper's tool (the shape of #1078)
- **Issues:** bead `context-grabber-0u3k`

#### Use Case:
- **As Igor,** drawing on the iPad on a new iOS
- **I want to** have what the board relies on PaperKit and PencilKit doing checked on the simulator, by tests that fail when the platform changes it
- **so that** the next surprise of the platform is a red test on the Mac, not ink that comes back or an eraser that draws on my board

#### Acceptance Criteria:
- **Scenario:** The platform changes something the board relies on
- **Given:** an Xcode or iOS update, or a change to how the board drives PaperKit
- **When:** `just native-test-contracts` runs
- **Then:** each behaviour the board relies on (the picker's tool against the paper's, which markup sets are held and which refused, the undo names, the kinds of ink) is checked on real PaperKit on an iPad simulator, a change in any of them fails its test naming the board's code that rests on it, and a failure is never retried into a pass

---

### User Story 1020:

- **Summary:** What PaperKit does with a real touch, that the whiteboard relies on, is checked on the simulator
- **Status:** implemented in 53a78aec; verified on the simulator rung (iOS 27.2, 2026-11-21: `just native-test-contracts` on lane 2's *iPad Pro 11-inch (M5)*, the 12 hosted contracts and the 3 touch contracts passing) and the Mac build
- **Issues:** bead `context-grabber-8o93` (follow-up of story 1019's bead `context-grabber-0u3k`); the contracts pin what #883, #965 and #1105 rest on. The eraser picked with a finger in the tool picker (#1078) is another agent's, under the same bead

#### Use Case:
- **As Igor,** drawing on the iPad on a new iOS
- **I want to** have what PaperKit does with my finger checked on the simulator
- **so that** a tap that leaves a dot, an Undo that reads wrong, or an eraser that takes a fold it shouldn't is a red test on the Mac, not a surprise on my board

#### Acceptance Criteria:
- **Scenario:** The platform changes what a touch does
- **Given:** a bare PaperKit paper set up as the board sets it up, with the board's own touch watcher and none of its handling, opened by a launch hook
- **When:** `just native-test-contracts` runs and a UI test touches it with a finger
- **Then:** a finger's stroke is one step on PaperKit's undo stack named *Add Strokes* (the name the bar's Undo reads as plain *Undo*), and its lift reaches the watcher as ended; a touch called off while it is down reaches the watcher as cancelled and never also as ended (the fold erase takes no fold by its marker on that); and with the finger set to select, as the board sets it while marks show, a tap still leaves a dot that PaperKit's own undo takes back (what the board's tap-dot take-back rests on)
- **And:** each test names the board's behaviour that rests on it, and a failure is never retried into a pass

---

### User Story 1021:

- **Summary:** The test ladder runs the contract tests when a change touches how the board drives PaperKit
- **Status:** implemented in 53a78aec; verified on the host rung (`just native-test`, the ladder's map: a file that imports PaperKit runs the contract tests beside its own classes, the contracts' own files run them alone, a board file that doesn't drive PaperKit doesn't)
- **Issues:** bead `context-grabber-8o93`, with story 1020

#### Use Case:
- **As Igor,** changing the whiteboard
- **I want to** have the ladder run the contract tests whenever a change touches how the board drives PaperKit
- **so that** a change that leans on something PaperKit stopped doing is a red test before it ships, without running them for every board change

#### Acceptance Criteria:
- **Scenario:** A change touches how the board drives PaperKit
- **Given:** a change to a file that imports PaperKit (the board's canvas and any file it is split into), the tool it reads, its ink kinds or its board files, or to the contract tests themselves
- **When:** the test ladder climbs to the simulator
- **Then:** it runs the contract tests on the iPad simulator, beside the classes the file has of its own, with no retry
- **And:** a change to the contract tests, their stage or its hook runs them alone, with no whiteboard class and no smoke, and a whiteboard file that doesn't drive PaperKit doesn't run them

---

### User Story 1022:

- **Summary:** A simulator test run on a locked screen skips only the tests that open the mic, so a locked Mac never crashes the app and still runs the rest
- **Status:** implemented in a344919f (spec 73476853); verified on the host by `scripts/native/test-xcodebuild-log.sh`, `scripts/native/test-build-lane.sh` and `scripts/native/test-ladder-map.sh` (the lock probe faked: a simulator test run on a locked screen waits its time and exits 75 without starting xcodebuild, and starts when the screen unlocks within it; a build and a test off the simulator aren't held; sim-boot on a locked screen boots and shuts down nothing and exits 75; rung 2 refuses with its line). Amended on branch `fix/locked-skip-mic-wm8y` (bead `context-grabber-wm8y`, Igor 2026-11-22: "remove those tests or skip those tests"): verified on the host by `scripts/native/test-xcodebuild-log.sh`, `scripts/native/test-build-lane.sh` and `scripts/native/test-ladder-map.sh` (the lock probe faked: a locked run starts at once with `-skip-testing` for the listed test and names it, in the ladder's ledger too; a locked run of no listed test skips nothing; one of only listed tests doesn't start, 75; one that ran nothing but them isn't a pass, 75; sim-boot boots; rung 2 runs)
- **Issues:** bead `context-grabber-208e` (Igor, 2026-11-22: "I keep seeing crashes from runs. Can we make sure I don't see them?"). Seven `GrabberNative` crash reports on the Mac on 2026-11-21 between 19:00 and 19:48, on the iPhone simulators of lanes 2, 3 and 4, each the app aborting in Apple's audio toolbox (`_ReportRPCTimeout` under `AVAudioEngine.inputNode`) as a test opened the mic, each while the screen was locked (the system log: locked 19:00:19 to 19:02:34, and from 19:11:58 on); story 1018 only read such a run's failure once it was over, after the crash and its dialog. Bead `context-grabber-wm8y`: in that same locked window the PaperKit touch contract UI tests, the contract tests, ChatReaction and ChatSkillThread all passed (slot 12's and slot 13's logs), the voice-button test the only failure; and on 2026-11-22 at 22:42, locked throughout, `WhiteboardTitleRenameUITests` started within seconds on the iPad simulator and passed 2 of 2 in 25 s (`~/tmp/agent/notes/lock-experiment/run1.log`): only a test that opens the mic needs an unlocked Mac

#### Use Case:
- **As Igor,** away from the Mac or back at it after it locked while agents test
- **I want to** have simulator test runs hold back only the tests that open the mic until I unlock, and run the rest
- **so that** a locked Mac never crashes the app, agents keep testing overnight, and what was held back is named and rerun

#### Acceptance Criteria:
- **Scenario:** A simulator test run asked for while the screen is locked
- **Given:** the Mac's screen is locked
- **When:** anything starts a test run on a simulator, or boots one for it (a UI test run through the wrapper every run goes through, the simulator smoke, the ladder's rung 2, the contract tests, the Health grant)
- **Then:** it starts at once, without the tests that open the mic, and names each one it held back, on screen and in the ladder's ledger, saying a locked Mac starves the simulator's audio and can crash the app when a test opens the mic, and to rerun them unlocked; a simulator boots as on an unlocked Mac
- **And:** a run that names only tests that open the mic doesn't start, exit 75, saying so; one that ran nothing but them (a class that holds only such tests) ends with exit 75, not a pass; a run with none of them says the screen is locked and runs as it is
- **And:** a build, a Mac build and a test run that isn't on a simulator start as before

---

### User Story 1023:

- **Summary:** A simulator test run in flight is stopped when the Mac's screen locks while a test that opens the mic is still to run, before it can crash the app
- **Status:** implemented in a344919f (spec 73476853); verified on the host by `scripts/native/test-xcodebuild-log.sh` (the lock probe faked: a lock mid-run stops it within seconds, ends the app and its runner on that simulator and exits 75, or 65 after an earlier failure; a lock after the tests finished changes nothing). Amended on branch `native/sim-lock-targets-i5x4` (bead `context-grabber-i5x4`): a run of two test targets is guarded to its last, verified on the host by the same script (a lock between the targets stops the run once the second starts, exit 75; one lifted before it starts lets the run pass). On the simulator (iPhone 17 lane 2, 2026-11-22, the probe reading a file flipped to locked 3 s into `GymTimerUITests`): the run was stopped and exited 75 with the line, no xcodebuild and no app left running, no new crash report; flipped back, the same class passed. Amended on branch `fix/locked-skip-mic-wm8y` (bead `context-grabber-wm8y`): verified on the host by `scripts/native/test-xcodebuild-log.sh` (with the listed test still to come, the stops above as before; the run that goes on is story 1510)
- **Issues:** bead `context-grabber-208e`, as story 1022; bead `context-grabber-wm8y`, as story 1022; bead `context-grabber-i5x4` (the stop stood down after the first of two test targets: `just native-test-contracts` closes a suite per target, two in slot 12's log of 2026-11-21, so a lock during the second wasn't stopped)

#### Use Case:
- **As Igor,** stepping away from the Mac while agents test
- **I want to** have a simulator test run stop when the screen locks under it while a test that opens the mic is still to run, and otherwise run on
- **so that** the app is never left running into a locked Mac's starved audio, crashing into a *quit unexpectedly* dialog, and the run says it was stopped and is rerun

#### Acceptance Criteria:
- **Scenario:** The screen locks during a simulator test run
- **Given:** a test run on a simulator whose tests are still running, with a test that opens the mic (`scripts/native/mic-tests.txt`) still to run
- **When:** the screen is seen locked (it is looked at every 2 s)
- **Then:** the run is stopped within seconds, naming the tests that open the mic still to run: xcodebuild is ended and the app and its test runner are ended on that simulator before a test can open the mic, and the run exits 75 saying when the screen locked, that the run was stopped so the app could not crash, and to unlock and rerun. If a case had already failed before the lock or a failed try went unchecked under story 1017, the run exits 65 and names the lock. Once the run's tests have all finished, a lock no longer stops it, and its result stands.
- **And:** a run of several test targets (the contract tests are two) is guarded to the end of its last: a lock seen during any target stops the run as above, and one seen between two targets stops it as soon as the next target starts while the screen is still locked; unlocked by then, the run goes on: a pass stands with a line saying the screen locked, a failure after that lock is read as story 1018 says, and a later lock that stops the run is the one it names, its 75 or 65 counting the cases that had failed before it

---

### User Story 1024:

- **Summary:** Agents run simulator tests only through the wrapper, so the lock rules of stories 1022 and 1023 always hold
- **Status:** implemented in a344919f (spec 73476853), the rule in the agent instructions and the testing guide; verified by reading them: every `xcodebuild … test` in the testing guide goes through the wrapper
- **Issues:** bead `context-grabber-208e`, as story 1022

#### Use Case:
- **As Igor,** with agents running tests on the Mac
- **I want to** have every simulator test run go through the wrapper
- **so that** no bare `xcodebuild test` slips past the lock check and crashes the app on a locked Mac

#### Acceptance Criteria:
- **Scenario:** Agents run simulator tests
- **Given:** an agent wants to run a UI test or a test class on a simulator
- **When:** it runs it
- **Then:** it runs it through the wrapper or a recipe that uses it, never a bare `xcodebuild test` on a simulator, so the lock rules of stories 1022 and 1023 always hold

---

### User Story 1025:

- **Summary:** The smoke skips the real-audio call while the Mac's lid is closed on the built-in mic
- **Status:** implemented in 4ee1f8a0 on branch `native/smoke-lid-mic-qj5y`; verified by the script check `scripts/native/test-smoke-lock.sh` in `just native-test` (the lid and input probes faked: closed on the built-in mic skips, open, a USB default input and no probe run), and on the simulator (rung 2, lane 1, 2026-11-22, lid closed): `SMOKE_ONLY=call just native-test-sim` before the fix failed the clean call on *the microphone is delivering silence*; after it, two runs printed the skip and passed. A real-audio call with the lid open is not yet run on this branch
- **Issues:** bead `context-grabber-qj5y` (a clean real-audio call filed *the microphone is delivering silence*)

#### Use Case:
- **As Igor,** running the simulator smoke with the MacBook's lid closed on an external display
- **I want to** have the real-audio call skipped and named as skipped when the built-in mic can't hear
- **so that** a closed lid doesn't fail the run, and a skipped check is never read as a pass

#### Acceptance Criteria:
- **Scenario:** A smoke run with the lid closed
- **Given:** the Mac's lid is closed and its default input is the built-in microphone
- **When:** the smoke reaches the real-audio call
- **Then:** it prints *skipped: Mac lid closed, the built-in mic hears nothing* and doesn't run it, the run's last lines count it as skipped and not passed, and the timer, breathing, the synthetic call and the dropped call still run; with the lid open, another input as the default, or a Mac that can't say (Linux), it runs as before

---

### User Story 1026:

- **Summary:** A report the ten-minute window held back still fails a call the smoke expects to be clean
- **Status:** implemented in 4ee1f8a0 on branch `native/smoke-lid-mic-qj5y`; verified on the simulator (rung 2, lane 1, 2026-11-22, lid closed): two `SMOKE_ONLY=call just native-test-sim` runs back to back with the lid probe forced to run both failed the real-audio call's clean check, the second's report held back by the window
- **Issues:** bead `context-grabber-qj5y` (the rerun passed only because the ten-minute window held its report back)

#### Use Case:
- **As Igor,** rerunning the simulator smoke soon after a call went wrong
- **I want to** have each clean call judged on its own log, a report filed or held back both counting
- **so that** a rerun doesn't pass by hiding the same failure

#### Acceptance Criteria:
- **Scenario:** A rerun inside the report window
- **Given:** a call that went wrong filed a report less than ten minutes ago
- **When:** a call the smoke expects to be clean goes wrong again and its report is held back by the window
- **Then:** that call's check still fails

---

### User Story 1027:

- **Summary:** One command puts main, development-signed, on the Cockpit's /builds page for the iPad
- **Status:** implemented in a00720be. Host coverage in `scripts/native/test-ota.sh` covers recipe arguments, the dry run and destination selection. The real development export from 9ec60f90 listed the iPad in all three profiles, expiring 2027-11-20. A full `just ota` from the main checkout is owed after the merge
- **Issues:** bead `context-grabber-omes` (Igor, 2026-11-22: staying on development builds; record and optimise the build loop)

#### Use Case:
- **As Igor,** staying on development builds and away from the Mac's cable
- **I want to** have one command build main, sign it for development and put it on the Cockpit's /builds page
- **so that** the iPad installs the newest main over the air, and I know exactly which build it is

#### Acceptance Criteria:
- **Scenario:** An over-the-air build
- **Given:** a clean main and the Mac unlocked
- **When:** `just ota` runs
- **Then:** it archives main as `just testflight --export-only` does, exports it development-signed under the signing lock and the screen-lock guard, publishes the completed transfer as `grabber-<commit>.ipa`, and prints the version, build, commit, the start of its SHA-256 and each step's seconds
- **And:** `--dry-run` prints that plan and builds, switches and copies nothing

---

### User Story 1028:

- **Summary:** The over-the-air build refuses a package the iPad can't install, and never prints its id
- **Status:** implemented in a00720be. Host coverage in `scripts/native/test-ota.sh` covers the local ID, masking, and a partially unreadable package. The Mac check against the real development export also rejected an ID absent from all three profiles
- **Issues:** bead `context-grabber-omes`

#### Use Case:
- **As Igor,** installing from /builds on the iPad
- **I want to** have a build whose profile lacks the iPad stopped before it is published, and one ota at a time
- **so that** /builds never offers a package that fails to install, and the public repo never carries a device id

#### Acceptance Criteria:
- **Scenario:** A profile without the iPad
- **Given:** the iPad's id in the gitignored local file
- **When:** the exported package's profiles (the app, the widgets, the share extension) are checked
- **Then:** an unreadable profile or one that doesn't list the iPad stops the run before the copy. The command shows the ID only in masked form and prints readable profiles' expiry dates. A missing ID stops the run, and a second ota while one runs stops at once (exit 75)

---

### User Story 1029:

- **Summary:** After each merge batch, main is built over the air and Igor's thread says what it holds
- **Status:** implemented in a00720be. The host fixture in `scripts/native/test-ota.sh` exercises polling remote merges, a merge arriving before OTA selects the checkout, announcement retry across restart, and the build exit codes
- **Issues:** bead `context-grabber-omes`

#### Use Case:
- **As Igor,** whose agents merge several PRs in a row
- **I want to** have a new over-the-air build made once a batch of merges settles, and told in my thread which PRs it holds
- **so that** the iPad is never far behind main and I know when to install

#### Acceptance Criteria:
- **Scenario:** A batch of merges settles
- **Given:** the watcher is running and main has merges since the last build
- **When:** ten minutes pass with no newer merge
- **Then:** it builds the checked commit, posts *New build on /builds: <version> (<build>) <commit>, with: <the PRs merged since the last build>* to `igor2-88g.1620`, and remembers the build outside the repository. A newer merge before the build is selected makes it wait again. A failed post is retried after a restart without rebuilding. Busy and locked builds are retried at the next poll, and other build failures stop the watcher with local diagnostics

---

### User Story 1509:

- **Summary:** Every UI test that taps a mic control or starts a call is listed as opening the mic or not, so a new one can't crash a locked Mac unnoticed
- **Status:** implemented on branch `fix/locked-skip-mic-wm8y`; verified on the host by `scripts/native/test-mic-tests.sh` (fixtures: a test that taps the mic through a helper and isn't listed fails the check and is named, one that touches no mic control isn't; a listed test that is gone fails; a mic line without its test target is refused; the real UI tests: 2 open the mic, 9 reviewed)
- **Issues:** bead `context-grabber-wm8y` (Igor, 2026-11-22: skip the tests a locked Mac can't run, after story 1022's evidence showed only the mic crashes one)

#### Use Case:
- **As Igor,** with agents testing on the Mac while it is locked
- **I want to** have the list of tests that open the mic kept whole by a check
- **so that** a test someone adds that opens the mic is skipped on a locked Mac, not run into a crash

#### Acceptance Criteria:
- **Scenario:** A UI test that touches a mic control
- **Given:** a UI test that taps, holds or looks for a mic control, the voice button, a microphone picker or a call, itself or through a helper in its file
- **When:** `just test` runs
- **Then:** the check fails, naming it, unless `scripts/native/mic-tests.txt` lists it as one that opens the mic (with its test target, skipped on a locked Mac) or as reviewed and not, each with why; a listed test that no longer exists fails the check too

---

### User Story 1510:

- **Summary:** A simulator test run with no test that opens the mic still to run goes on when the Mac's screen locks
- **Status:** implemented on branch `fix/locked-skip-mic-wm8y`; verified on the host by `scripts/native/test-xcodebuild-log.sh` (the lock probe faked: a lock mid-run with no listed test to come doesn't stop the run, and a test that fails after it fails the run, 65; a lock after the listed test passed, or skipped itself, doesn't stop it, and a pass stands with a line)
- **Issues:** bead `context-grabber-wm8y`, as story 1022

#### Use Case:
- **As Igor,** stepping away from the Mac while agents test
- **I want to** have a simulator test run that can no longer open the mic run on when the screen locks
- **so that** a locked Mac doesn't send back a run it can't crash, and its result stands

#### Acceptance Criteria:
- **Scenario:** The screen locks with no test that opens the mic to come
- **Given:** a simulator test run with no test that opens the mic, or whose ones have all passed, skipped themselves or failed, or that skipped them as it started locked
- **When:** the screen is seen locked
- **Then:** the run goes on; a pass stands with a line saying the screen locked and no test that opens the mic could start, and a test that fails after the lock fails the run as on an unlocked Mac

---

### User Story 1500:

- **Summary:** One document says how a build reaches each device, and what would make it faster
- **Status:** implemented in a00720be. Verified by resolving both relative links from AGENTS.md and docs/TESTING.md to the deploy guide
- **Issues:** bead `context-grabber-omes`

#### Use Case:
- **As Igor,** or an agent about to deploy
- **I want to** read one page covering the cable and network install, the over-the-air build, signing, renewing the profile, adding a device and iCloud's two environments
- **so that** a deploy, a lost account or an expiring profile is handled the same way each time, and the next speed-up is chosen from measured numbers

#### Acceptance Criteria:
- **Scenario:** Before a deploy
- **Given:** an agent or Igor needs a build on a device
- **When:** they open the deploy document from the agent instructions or the testing guide
- **Then:** it names the command for each path, what *unavailable* means, how to wait for a device, the signing rules, what to do before the profile expires, how to add a device, which iCloud environment each build uses, and a table of speed-ups with their estimated savings

---

### User Story 1501:

- **Summary:** A whiteboard UI test launches the Board Lab, the board alone, instead of the whole app
- **Status:** implemented in 86cc1677 (two classes, `WhiteboardEraserUITests` and `WhiteboardTitleRenameUITests`); verified on the iPad simulator (iPad Pro 11-inch (M5), rung 2): the two classes 3 runs each way, median 85.8 s in the app against 81.1 s in the lab, and the whole `test-whiteboard-ui.sh` with both bundles passing (82 app cases and 4 lab cases, 1,648 s); host `just native-test`. No iPhone run (Igor, 2026-11-22)
- **Spec:** [The Board Lab](../superpowers/specs/2026-11-22-board-lab-design.md)
- **Issues:** bead context-grabber-09tx

#### Use Case:
- **As Igor,** waiting on the whiteboard's UI tests on the iPad simulator
- **I want to** have them launch a small app that opens straight onto the boards list, with the same board
- **so that** a test doesn't wait for the parts of a launch the board doesn't need

#### Acceptance Criteria:
- **Scenario:** A class moved to the lab
- **Given:** a whiteboard UI test class listed in the Board Lab's bundle
- **When:** the whiteboard UI test script runs on the iPad simulator
- **Then:** the class launches the Board Lab, finds the boards list as the app's whiteboard hook leaves it, passes with its code unchanged, and the plan records its time before and after with the lab's added build time

---

### User Story 1631:

- **Summary:** The Board Lab never answers Grabber's links, so a link opens the app even with the lab installed
- **Status:** implemented in 21eefd14; verified on the iPad simulator (iPad Pro 11-inch (M5), rung 2): `LinksUITests.testWarmLinksOverEachKindOfScreenBringTheirScreenUp` failed with the old lab installed (every warm link opened the lab) and passed with the rebuilt lab, whose Info.plist has no `CFBundleURLTypes`
- **Spec:** [The Board Lab](../superpowers/specs/2026-11-22-board-lab-design.md)
- **Issues:** bead context-grabber-3hj9.1

#### Use Case:
- **As Igor,** running the app's UI tests on a simulator that also has the Board Lab
- **I want to** have every `grabbernative://` link open Grabber Native
- **so that** a link test checks the app, not whichever of two apps the system picked

#### Acceptance Criteria:
- **Scenario:** A warm link on a simulator with the lab installed
- **Given:** the Board Lab and Grabber Native are both installed on the iPad simulator, and Grabber Native is running
- **When:** a `grabbernative://` link opens through the system, as a Shortcut's *Open URL* does
- **Then:** Grabber Native stays in front and shows the linked screen, and the lab never opens

---

### User Story 1632:

- **Summary:** The ladder puts Exercise Analyzer on the simulator before the test that opens it
- **Status:** implemented in 6632349e; verified by `scripts/native/test-install-exercise-analyzer.sh` (host) and on the iPad simulator (iPad Pro 11-inch (M5), rung 2, 2026-11-25): the ladder installed Exercise Analyzer's simulator build and `ExerciseAnalyzerLinkUITests` passed, where both store walks had failed it with the app missing
- **Issues:** bead context-grabber-3hj9.3; bead context-grabber-3hj9.6 (the Status named the other repo's recipe, which the store walk read as a missing check)

#### Use Case:
- **As Igor,** reading a store walk or a full ladder run
- **I want to** see `ExerciseAnalyzerLinkUITests` test the home row against a real Exercise Analyzer
- **so that** a red there means the row is broken, not that the other app was never installed

#### Acceptance Criteria:
- **Scenario:** The other app's simulator build is on this Mac
- **Given:** Exercise Analyzer's simulator build exists in its repo's build folder (or `EXERCISE_ANALYZER_APP` names one)
- **When:** the ladder's chosen classes include `ExerciseAnalyzerLinkUITests`
- **Then:** it installs that build on the lane's simulator first, and the test runs against it

---

### User Story 1633:

- **Summary:** With no Exercise Analyzer build on this Mac, the ladder leaves out the test that opens it and says why
- **Status:** implemented in 6632349e; verified by `scripts/native/test-install-exercise-analyzer.sh` (host: with no build it installs nothing and exits 3, naming the path it looked for and how to build it); the ladder leaving the class out on exit 3 is not checked yet
- **Issues:** bead context-grabber-89sb (split from story 1632)

#### Use Case:
- **As Igor,** on a Mac that has never built Exercise Analyzer
- **I want to** have the run skip `ExerciseAnalyzerLinkUITests` and say what's missing
- **so that** a missing build reads as a setup gap, not a red test

#### Acceptance Criteria:
- **Scenario:** The other app's simulator build isn't on this Mac
- **Given:** no Exercise Analyzer simulator build in its repo's build folder and no `EXERCISE_ANALYZER_APP`
- **When:** the ladder's chosen classes include `ExerciseAnalyzerLinkUITests`
- **Then:** the class is left out, and the run says which file it looked for and how to build it

---

### User Story 1502:

- **Summary:** The lists every PR adds to in the testing guide are one item a line, and the host rung fails when one drifts from its script
- **Status:** implemented on branch `native/testing-lists-2b54`; verified on the host rung by `scripts/native/test-testing-lists.sh` in `just test` (a dropped class, two classes out of order, a new UI test file and a new host check each fail by name on a copy of the tree; the real tree passes) and the Mac build (rung 1.5); no simulator or phone run, as nothing in the app changed; the scripts' whiteboard lists one a line on branch `native/ui-lists-one-a-line-b295`, verified on the host rung (the suite's 25 classes the same before and after; the ladder's dry run for a whiteboard file, the fake Cockpit, the suite script and the conversation strip the same byte for byte; `scripts/native/test-ladder-map.sh` and `scripts/native/test-testing-lists.sh`, which now also fails on a script list out of name order, in `just test`) and the Mac build (rung 1.5); no simulator or phone run, as nothing in the app changed
- **Issues:** bead context-grabber-2b54 (#1217 hit a merge conflict in the whiteboard suite's one long table row on every rebase, four rounds, each sending the pipeline back to review); bead context-grabber-b295 (adding a whiteboard class still meant editing three one-line lists in the scripts: the suite's and its story list, the ladder's and the ladder check's)

#### Use Case:
- **As Igor,** with several agents landing whiteboard PRs at once
- **I want to** have the testing guide list the host rung's script checks and each UI suite's classes one to a line, in name order for the classes
- **so that** two PRs that each add a class or a check edit different lines and merge without a conflict, and the guide can't silently fall behind what the scripts run

#### Acceptance Criteria:
- **Scenario:** A PR adds a whiteboard or chat UI test class, or a host script check
- **Given:** the testing guide's lists of the host checks, the chat suite's classes and the whiteboard suite's classes, each item on its own line
- **When:** the host rung runs (on the Mac or the Linux box)
- **Then:** it fails naming each class or check that the suite's script, the whiteboard's test files or the host recipe has and the guide doesn't list, or the guide lists and they don't have, and each suite list that is out of name order; with none of these it passes

- **Scenario:** A PR adds a whiteboard UI test class to the scripts
- **Given:** the whiteboard suite's script names its classes one to a line, in name order
- **When:** the PR adds the class's file, its line in the script and its line in the testing guide
- **Then:** nothing else needs editing: the ladder runs the new class for any whiteboard change, its own check expects every whiteboard test file, and the host rung fails if the script's list is out of name order

---

### User Story 1624:

- **Summary:** A story's Status never names a test that is gone
- **Status:** on branch `docs/stale-status-tests`; verified on the host rung by `scripts/native/test-story-tests.sh` in `just test`: hand-written stories citing a live class, a live method, a test file named for its class, another repo's test (`bug-kit:WhatsNewTests`) and a test target's folder pass; a missing class, a missing method of a live class and a missing bare method each fail by name; only Status lines are read. docs/stories passed only once the 99 stale citations on main were moved: 29 say in words what took the test away (the old canvas, the gist, BoardOpLedger's setters) or that its verification was lost; the other 70 point at the test that covers the story now, and where that test is on another rung or checks less than the old one did, the old test is named in words for what it showed then
- **Issues:** Larry's walk-the-store dry run on 2026-11-24 (27 whiteboard stories citing 14 tests gone from main c65b94e9); bead context-grabber-o2kz (stories 252 and 643, whose verification was lost)

#### Use Case:
- **As Igor,** reading a story's Status to see how it was checked
- **I want to** have every test the Status names still exist in the app's code
- **so that** "verified by" means a test I can run today, and a renamed or deleted test is caught the day it goes, not weeks later by a dry run

#### Acceptance Criteria:
- **Scenario:** A story's Status cites a test that is no longer in the code
- **Given:** the stories, and the app's test files
- **When:** the host rung runs
- **Then:** it fails naming the story file, the line and the test that is gone; a test in another repo, written with that repo's name first, is not looked for here

---

### User Story 1630:

- **Summary:** A UI test that isn't about Health launches the app without asking HealthKit, so a crash inside HealthKit's own logging can't fail a whiteboard or chat test
- **Status:** implemented in 49e6300f; verified by `just test` (host, 1083 tests) and on an iPad Pro 11-inch (M5) simulator, 2026-11-24: `WhiteboardPaperGhostsUITests.testKeepingHisMarkLeavesMyPenAsItWas` passed (8 of 8 earlier with the refresh on; the failure was the launch crash, not the test) and its session log shows `mirror_refresh_skipped` with `health_off` and no `mirror_grab`; `HomeTodayCardUITests` (`GRABBER_MIRROR=fixture`) still grabbed its fixture week (`mirror_fixture_done`)
- **Issues:** bead `context-grabber-8dnk` (cause: `WhiteboardPaperGhostsUITests.testKeepingHisMarkLeavesMyPenAsItWas` failed its first try on 2026-11-24 22:20 because the app died 1.6 s after launch, SIGSEGV in libc `dtoa` under `HKQuery` writing its predicate to os_log during the launch Health refresh; the same crash as bead `context-grabber-2xyj`, its fifth sighting on the lane simulators)

#### Use Case:
- **As Igor,** relying on the simulator's UI tests to tell me whether the whiteboard and chat work
- **I want to** have the tests that don't touch Health launch the app with its Health refresh switched off
- **so that** a crash inside Apple's HealthKit on the simulator fails only the tests about Health, not every class that happens to launch at that moment

#### Acceptance Criteria:
- **Scenario:** A UI test launches the app with `GRABBER_HEALTH=off`
- **Given:** every UI test launches through `XCUIApplication.forTests`, which sets `GRABBER_HEALTH=off`
- **When:** the app comes to the front at launch or later
- **Then:** it asks HealthKit nothing for its Today refresh and logs `mirror_refresh_skipped` with `health_request_status` `health_off`; a test that sets `GRABBER_MIRROR` still grabs its fixture week (fixture or HealthKit) as before, and the launch smoke, which doesn't use `forTests`, still runs the real Health refresh

---

### User Story 1627:

- **Summary:** A build lane's simulator runs slim: simslim turns off the background daemons a test run never needs, once per simulator
- **Status:** implemented in 72d9a381, f2009eed, 8cc3a605 and ad364760 (Widgets kept on); verified by `scripts/native/test-sim-slim.sh`, `scripts/native/test-sim-lane.sh` and `scripts/native/test-ladder-map.sh` (host; a simulator that isn't slimmed is waited for once, as before) and on the simulator rung, 2026-11-24: all four iPad Pro 11-inch (M5) lane simulators slimmed (102 of 173 daemons off), then the whiteboard smoke and `WhiteboardUndoRedrawUITests`, `WhiteboardDropRoomUITests` and the PaperKit contract classes on a slim lane passed. Retimed 2026-11-25 with Widgets on, paired on lane 4's simulator (slim, stock, slim, stock under its lock): the rung took the same time slim and stock (184 s slim, 178 and 194 s stock), each class within a second or two; idle a minute after boot it ran 120 processes and 16.6 GB summed RSS slim against 214 and 29.9 GB stock, CPU 0.3% against 1.4%; its disk image is unchanged. The first comparison, 185 s slim against 255 s stock on other lanes, mixed lanes, load and build caches, and is withdrawn. `WhiteboardDropRoomUITests` failed one run on a slim lane while the Mac ran three builds, the same drop-short failure seen on stock lanes the same day (beads d455, mph6). 2026-11-25, ad364760: `UsageTileUITests` passed on an iPad Pro 11-inch (M5) lane simulator with Widgets on (28.7 s) after failing 2 of 2 runs with it off, and `just test` passed (host). 2026-11-25, bead 505v: with `com.apple.linkd` kept, the large widget's tap deals on an iPad Pro 11-inch (M5) lane (`deal_tap` in the extension's log; before, `Failed to fetch metadata for DealCardIntent` and no deal), and `TodaysHandUITests` passed
- **Issues:** chop-conventions ios-codev skill (Igor, 2026-11-24: "did we get the slim sims too"); bead context-grabber-3hj9.4 (Widgets off emptied the widget gallery, so `UsageTileUITests` failed on the slim iPad lanes; `TodaysHandUITests` adds its widget through the same gallery); bead context-grabber-505v (`com.apple.linkd`, in simslim's "other" set, was off, so the large widget's `DealCardIntent` had no metadata and its tap never dealt; now kept)

#### Use Case:
- **As Igor,** running several build lanes, each with its own booted simulator
- **I want to** have each lane's simulator run only the daemons the app and its tests use
- **so that** more lanes fit in the Mac's memory and CPU without starving each other

#### Acceptance Criteria:
- **Scenario:** A lane boots a simulator that isn't slim
- **Given:** simslim is installed and the simulator runs stock
- **When:** sim-boot.sh brings it up for its lane
- **Then:** it is slimmed once, keeping Siri and dictation, Health, iCloud, Photos and Widgets on, and the App Intents index a widget's tap needs, and the run waits for it to be booted again after the slim's reboot (a simulator that doesn't come back fails the boot); a simulator already slim, a Mac without simslim, `SIM_SLIM=0` or a failed slim all leave the run going as before

---

### User Story 1623:

- **Summary:** The web board asks the app's own rules how much room a reply of Larry's opens when kept over ink written since its picture, and where a text of his set on ink lands
- **Status:** implemented in ee948947 and 21039401 (where a text of his set on ink lands; on the Cockpit 4,055 text landings agree but for two classes counted apart: the Cockpit lands a text a full half line under the writing above where the app lands half of that, and a few whole-line 32-bit ties); verified by `just wasm-test` (157 checks, a hand-worked late room among them), the Linux rung (894 tests) and the Cockpit's comparison (recorded, 60 seeded and its five real boards: 9,732 keeps, 3,034 opening room, 0 differences), 2026-11-23. On the Mac, `just native-test` passes (SwiftLint, swift-format, host tests), 2026-11-23.
- **Spec:** [The board's rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), The interface, version 8
- **Issues:** bead `context-grabber-edl`

#### Use Case:
- **As Igor,** keeping Larry's replies on the Cockpit's web ink board after I have written more
- **I want to** have the web board ask the app's own rules how far my newer writing moves out from under his marks
- **so that** a kept reply makes the same room on the web as on the iPad

#### Acceptance Criteria:
- **Scenario:** A late reply's room through the module
- **Given:** the module built by `just wasm` with an outline of two lines, one written after the picture and one before
- **When:** `just wasm-test` asks for the room a mark over the newer line opens, with the picture taken before it and after it, and for a mark on clear paper; and where a text set on the newer line and one on clear paper land
- **Then:** over the newer line the room is two lines from that line's top, so it is half a line under the mark; with the picture after it, and on clear paper, there is none; with no `seen` it says so; the text on the line lands where it is and the line goes down two lines, the one on clear paper sits on nothing; with no box it says so

---

### User Story 1625:

- **Summary:** A SwiftUI preview renders to a picture from the command line, with no Xcode window
- **Status:** implemented in 82665bcd; verified by `scripts/native/test-render-preview.sh` (host) and a real render of a temporary preview from a treehouse slot and a worktree (the same 1033x1500 picture; 35-105 s cold, about 0.5 s warm), 2026-11-24
- **Issues:** bead `context-grabber-7xme`

#### Use Case:
- **As** an agent working on Grabber's screens on the Mac
- **I want to** render a view's preview to a PNG with one command
- **so that** I can look at a screen without opening Xcode or booting the app

#### Acceptance Criteria:
- **Scenario:** One preview, one command
- **Given:** a Swift file under the app with a preview, on a Mac where Xcode's headless tool service may serve the checkout's folder
- **When:** `just render-preview <file> [out.png]` runs
- **Then:** the preview renders on the iPad simulator and its picture lands at the given path, the time taken is printed, and nothing opens on the screen; a file that isn't there, or a folder Xcode hasn't been allowed to serve, stops with a message saying what to do

---

### User Story 1622:

- **Summary:** The web board asks the app's own rules what Larry's batch of board changes does
- **Status:** implemented in 67d04b51 (the batch read and planned, `bw_ops_plan`) and 5c1afd32 (spec, story and wasm-test checks); verified by `just wasm-test` (hand-worked batch: a refusal, the names used, a whole-line make-room, a group moved whole, a missing name, a text on clear paper) and the Cockpit's comparison (35 batches against its old JavaScript port: 29 the same, 6 differing by this app's rules, each named), 2026-11-23. On the Mac, `just native-test` passes (SwiftLint, swift-format, 979 host tests), 2026-11-23.
- **Spec:** [The board's rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), The interface, version 7
- **Issues:** Cockpit bead `cockpit-ang` (ops lane, slice 2)

#### Use Case:
- **As Igor,** letting Larry change my Cockpit web ink board as he changes the iPad's
- **I want to** have the web board read his batch and work out each move, erase, group and text with the app's own rules
- **so that** his changes land the same way on the web as on the iPad

#### Acceptance Criteria:
- **Scenario:** Larry's batch through the module
- **Given:** the module built by `just wasm`
- **When:** `just wasm-test` sends a batch with an unknown op, then a make-room, a move of a grouped stroke with a missing name and a text, on a small board
- **Then:** the first is refused as `unknown_op`; the make-room opens whole lines; the group moves whole, the missing name is listed and the text stays where he put it

- **Scenario:** Connectors and controls on the web board
- **Given:** a web board with named boxes and existing ink
- **When:** Larry connects from a point inside a box, moves a box into a connector's route, or sets and removes controls in a batch
- **Then:** the connector attaches to the box by name and routes around boxes in its way, and the Cockpit receives the control changes in batch order

- **Scenario:** A text name is reused
- **Given:** the Cockpit measures each showing ghost and each new text where it appears in the batch
- **When:** Larry replaces a text with another one of the same name
- **Then:** each operation places the text and makes room using that instance's dimensions

---

### User Story 1621:

- **Summary:** The web board asks the app's own rules where a connector's shaft runs
- **Status:** implemented in e3a1668f; verified by `just wasm-test` (148 checks, a hand-worked straight route and one elbow round a box among them), the Linux rung (894 tests) and the Cockpit's comparison (60 seeded layouts, 3,432 routes, 548 with an elbow, 0 differences), 2026-11-23. Owed on the Mac: `just native-test` (SwiftLint and the Mac's swift-format)
- **Spec:** [The board's rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), The interface, version 6
- **Issues:** bead `context-grabber-edl`

#### Use Case:
- **As Igor,** linking things with connectors on the Cockpit's web ink board as well as on the iPad
- **I want to** have the web board ask the app's own rules how a connector routes around what is in the way
- **so that** an arrow takes the same path on the web as on the iPad

#### Acceptance Criteria:
- **Scenario:** A connector's route through the module
- **Given:** the module built by `just wasm`
- **When:** `just wasm-test` asks for the route between two boxes with nothing between them, then with a box across the straight line, then with no boxes
- **Then:** the first is straight from one's right to the other's left; the second goes across then down to the far box's top, clear of the box in the way; the third says it has no boxes

---

### User Story 1620:

- **Summary:** The web board asks the app's own rules what a Pencil hold picks up and what a finger hold offers
- **Status:** implemented in ada3676b; verified by `just wasm-test` (145 checks, a hand-worked board of a header, a word, a far stroke, a group and a kept text among them), the Linux rung (894 tests) and the Cockpit's comparison (every recorded board and 60 seeded ones, 40,498 Pencil holds and 42,038 finger holds: 0 differences; where its own older pick goes another way than the app, counted apart), 2026-11-23. Owed on the Mac: `just native-test` (SwiftLint and the Mac's swift-format)
- **Spec:** [The board's rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), The interface, version 5
- **Issues:** bead `context-grabber-edl`

#### Use Case:
- **As Igor,** holding the Pencil or a finger on writing on the Cockpit's web ink board as well as on the iPad
- **I want to** have the web board ask the app's own rules what the hold is on and which rows its menu offers
- **so that** a hold picks up the same word, and the menu offers Select and Delete, as on the iPad

#### Acceptance Criteria:
- **Scenario:** Holds through the module
- **Given:** the module built by `just wasm` with an outline loaded (a header, a line of two strokes a little apart and one far off, a group of Larry's, a kept text)
- **When:** `just wasm-test` asks what a Pencil picks up on each, and what a finger hold offers on a word, the header, the group, blank paper and the margin
- **Then:** the near strokes come as one word and the far one alone, the kept text whole from inside it, the header its row, nothing off ink; the menus offer Select and Delete then the line's rows on a word and the group (no Make header on the group), Select without Delete on the header with Not a header, the line's rows on paper, and the outline beside a header in the margin; with no outline each says so

---

### User Story 1512:

- **Summary:** The web board asks the app's own rules what an underline or a # written in ink makes, and what Fold all and Collapse to a level fold
- **Status:** implemented in 28991f72 and adb683ed (a fold plan with an unreadable request or level says so; a fold left from an Undo that does not fold again is not listed); verified by `just wasm-test` (a hand-worked underline header, and Fold all and Collapse to 1 and 2 over a header with a deeper one inside it, among its checks), and by the Cockpit's comparison with its own rules (every recorded board and 60 seeded ones: 9,246 strokes read for headers, underlines, #s, ## and writing joining a header, and 320 Fold all and Collapse plans, 0 differences; one rule apart, counted: the app reads every grouped stroke as not his writing, the Cockpit only Larry's groups, and only the web lets him group his own writing), 2026-11-23. Owed on the Mac: `just native-test` (SwiftLint and the Mac's swift-format)
- **Spec:** [The board's rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), The interface, version 4
- **Issues:** bead `context-grabber-edl`

#### Use Case:
- **As Igor,** writing headers in ink and folding them on the Cockpit's web ink board as well as on the iPad
- **I want to** have the web board ask the app's own rules which strokes make a header and which headers Fold all and Collapse fold
- **so that** a header I underline or mark with a # on the web is the header the iPad would make, and folding the board looks the same on both

#### Acceptance Criteria:
- **Scenario:** Headers and folding through the module
- **Given:** the module built by `just wasm` with an outline loaded (a line of two words with a flat stroke under it; then two headers, one over two lines and one over an indented line)
- **When:** `just wasm-test` asks what the underline, a word and a missing stroke make, and asks for Fold all and Collapse to levels 1 and 2
- **Then:** the underline makes its line header `H` with itself as the mark, the word and the missing stroke make nothing, the loaded outline is unchanged; Fold all and both collapses fold the lower header's line first and then the upper header's two lines with the rest sliding up 120; with no outline each says so

---

### User Story 1511:

- **Summary:** A build on Igor's device that isn't the one we installed is named, with both builds
- **Status:** implemented in 4639bc68; verified on the host rung (`just test`): `scripts/native/test-device-build-check.sh` (a mismatch named with both builds and exit 1, a match, no session yet after an install, a build posted over the air, nothing recorded; `just deploy` with a fake deploy-all records the device that took the build, not the one that refused, and checks its next session). Run on the real ledger and logs of 2026-11-22 it reported both devices MISMATCH: no network install had been recorded since 11-21. Not yet run after a real install. Fixed for plain `just deploy` (hb5y): the same test runs deploy.sh with no options under /bin/bash 3.2 and checks deploy-all gets only the app's name
- **Issues:** bead `context-grabber-hb5y` (2026-11-24: plain `just deploy`, no options, failed under macOS bash 3.2 with `args[@]: unbound variable` before it installed anything); bead `context-grabber-yfsz` part 1 (2026-11-22: an agent told Larry the iPad was on b3e9de18 while its board posts and session log said 5569178f, installed around 22:57 by an install nobody recorded)
- **Spec:** [Knowing which build is on Igor's devices](../superpowers/specs/2026-11-22-device-build-check-design.md)

#### Use Case:
- **As Igor,** asking agents what's on my iPad
- **I want to** have every install recorded and checked against the build my device reports
- **so that** nobody points me at a feature that isn't on my device, or misses one that is

#### Acceptance Criteria:
- **Scenario:** The device runs another build than the last install
- **Given:** an install of one commit to the iPad, recorded by `just deploy`, `just native-run-device` or `just ota`
- **When:** the iPad's newest session after it names another commit, and `just device-build-check` runs (on its own, or after `just deploy`)
- **Then:** it says MISMATCH with both commits and their times, and exits 1

---

### User Story 1513:

- **Summary:** The web board asks the app's own rules where a paste lands and how much room a drop opens
- **Status:** implemented in 9810a283, and 50e9918b makes the rules ask their own `CGRect.overlaps` (boxes that only touch do not overlap, as Apple answers `intersects`; Foundation on Linux and WASI says they do); verified by `just wasm-test` (120 checks, a hand-worked paste and drop among them), the Linux rung (`just test-linux`, 894 tests, `BoardRectOverlapTests` among them) and the Cockpit's paste comparison (0 differences, none left on touching), 2026-11-23. Owed on the Mac: `just native-test` (SwiftLint and the Mac's swift-format)
- **Spec:** [The board's rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), The interface, version 3
- **Issues:** bead `context-grabber-edl`

#### Use Case:
- **As Igor,** pasting text and dragging writing around on the Cockpit's web ink board as well as on the iPad
- **I want to** have the web board ask the app's own rules where a paste lands and how far a drop pushes the writing below
- **so that** a paste or a drop lands on the web exactly where it would on the iPad

#### Acceptance Criteria:
- **Scenario:** A paste and a drop through the module
- **Given:** the module built by `just wasm` with a board loaded (a line of writing, a kept text, two strokes grouped)
- **When:** `just wasm-test` asks where a paste lands in a clear view and in views too small to hold it, and what a drop on the line, on clear paper and back on its own line opens
- **Then:** the paste lands on the clear patch nearest the view's middle on the 20-point grid; with none, under the writing above the view's middle, with room opened only when the blank paper there is short, in whole lines; the drop on the line pushes it down one line from the clear line at the drop's top, and the other two open nothing; with nothing loaded each says so

---

### User Story 1514:

- **Summary:** A simulator test run with a failed try keeps the session logs its app wrote, beside the run's log
- **Status:** implemented on branch `native/keep-session-logs-7un4`; verified on the host rung by `scripts/native/test-xcodebuild-log.sh` (a fake xcodebuild on a named simulator whose case fails while the app writes a session log: the log is kept in `<run>.session-logs/` and named on screen, an older log in the container isn't taken, and a passed run keeps none)
- **Issues:** bead `context-grabber-7un4` (`WhiteboardPaperGhostsUITests.testASmallLabelKeptStaysOnTheCanvasAndInThePicture` failed once on 2026-11-24 with the pasted ink and then the kept label never drawn, both on the screenshots; the app's session log of that run was gone by the time it was looked for, cleared by the next run's install)

#### Use Case:
- **As Igor,** chasing a UI test that failed once on the simulator
- **I want to** have the session log the app wrote during that run kept with the run's log and screenshots
- **so that** the board's own events say what happened, instead of a guess from the pixels

#### Acceptance Criteria:
- **Scenario:** A failed try on the simulator
- **Given:** a UI test run on a simulator in which a try fails, and the app wrote a session log during the run
- **When:** the run ends
- **Then:** the session logs the app wrote during the run are copied beside the run's log and the run says where they are; logs from before the run aren't copied, and a run with no failed try copies nothing

---

### User Story 1508:

- **Summary:** The web board asks the app's own outline which row of writing a tap is on and what folding a header does
- **Status:** implemented in 2314e279; verified by the Linux rung (`just test-linux`: ContextCore's 890 tests, the cross-builds and the app compile, every portable script check) and `just wasm-test` (113 checks, the hand-worked outline among them), 2026-11-22. The Cockpit's side compares it with its own rules on every recorded board and 150 seeded random boards with no difference. Owed on the Mac: `just native-test` (SwiftLint and the Mac's swift-format)
- **Spec:** [The board's rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), The interface, version 2
- **Issues:** bead `context-grabber-edl`

#### Use Case:
- **As Igor,** writing headers and folding them on the Cockpit's web ink board as well as on the iPad
- **I want to** have the web board ask the app's own outline which row a tap is on and what a fold tucks away
- **so that** a header made or folded on the web lands exactly where it would on the iPad

#### Acceptance Criteria:
- **Scenario:** Rows and folds from the module's outline
- **Given:** the module built by `just wasm`, and a board's outline (its writing with real points, its kept texts as boxes, its groups and headers) sent to it
- **When:** `just wasm-test` asks which row heights are on and what folding a header would do, adds new writing, and sends ink it can't read
- **Then:** the row is the header's on a header's line, the line's strokes in board order elsewhere, none on blank paper; the fold names what it tucks away, how far the rest slides, how many lines it hides and where its section ended, and leaves the outline as it was; new writing goes in at the end; ink with no id or no points is refused saying why; and with nothing loaded each question says so

---

### User Story 1507:

- **Summary:** A time limit that can't be found stops the rung instead of running it with none
- **Status:** implemented in e701ccf2; verified on the host rung (`just test`): the ladder's map self-test (a missing time limit stops rung 1.5, exit 2, nothing built; that case fails against the ladder before this change, which ran the rung with no limit)
- **Issues:** bead `context-grabber-xmwp`

#### Use Case:
- **As Igor,** trusting that no rung can hold a build lane for hours
- **I want to** have a rung refuse to start when its time limit is missing
- **so that** a broken path shows up at once instead of as a hang nothing stops

#### Acceptance Criteria:
- **Scenario:** A time limit that can't be found
- **Given:** `LADDER_TIME_LIMIT` names a time limit that doesn't exist
- **When:** a rung would run
- **Then:** the rung doesn't start, and the ladder says which time limit is missing, instead of running with none

---

### User Story 1506:

- **Summary:** A rung that hangs is stopped at its limit, with everything it started, and frees its build lane
- **Status:** implemented in e701ccf2; verified on the host rung (`just test`): `scripts/native/test-time-limit.sh` (a hang and the child it started stopped in seconds with exit 124, a command that ignores TERM stopped by the KILL, a finished command's status kept)
- **Issues:** bead `context-grabber-xmwp`

#### Use Case:
- **As Igor,** with agents sharing the Mac's build lanes
- **I want to** have every Mac and simulator rung stopped when it runs past its minutes
- **so that** a hung build or test frees its lane for the next agent instead of holding it for hours

#### Acceptance Criteria:
- **Scenario:** A rung that hangs
- **Given:** a Mac or simulator rung in its build lane
- **When:** it runs past the rung's minutes
- **Then:** it and everything it started are stopped, the lane is free, and the ladder says the rung ran past its limit (exit 124)

---

### User Story 1505:

- **Summary:** A Mac or simulator rung gets its time limit from this repo, so a Mac without mac-driver still has one
- **Status:** implemented in e701ccf2; verified on the host rung (`just test`): `scripts/native/test-time-limit.sh` (the repo's own time limit, needing no `~/gits/mac-driver`: a hang stopped with exit 124, a finished command's status kept, bad calls refused, the lane count unchanged past it)
- **Issues:** bead `context-grabber-xmwp` (2026-11-21: every Mac and simulator rung printed "no …/mac-driver/bin/time-limit: rung N runs with no time limit, and a hang holds the build lock", because `~/gits/mac-driver` wasn't checked out)

#### Use Case:
- **As Igor,** with agents running the ladder on any Mac, mac-driver checked out or not
- **I want to** have every Mac and simulator rung run under its time limit
- **so that** a hung build or test can be stopped whether or not mac-driver is on that Mac

#### Acceptance Criteria:
- **Scenario:** A Mac without mac-driver
- **Given:** `~/gits/mac-driver` isn't checked out
- **When:** a rung runs
- **Then:** it still has its time limit, from the repo's own `scripts/native/time-limit.sh`

---

### User Story 1504:

- **Summary:** A UI test waits for something to go away without its own loop
- **Status:** implemented in 2261718a: `disappears(within:)` replaces the Connect and cheat-sheet tests' own loops, verified on the iPad simulator (rung 2, both classes pass)
- **Issues:** bead `context-grabber-u76`

#### Use Case:
- **As Igor,** waiting on a test run
- **I want to** have a UI test move on as soon as a button or sheet it is waiting on has gone
- **so that** no test writes its own loop to check that something has gone

#### Acceptance Criteria:
- **Scenario:** The thing goes away
- **Given:** a UI test is waiting for a button or sheet to go away
- **When:** it goes
- **Then:** the test moves on in well under a second

---

### User Story 1503:

- **Summary:** The Cockpit's web board runs the app's own board rules, built as WebAssembly
- **Status:** implemented in 4dfdaec2, 3f12df04, 65a97722, bb54eb09, 76bdc64e, f0c2cce0 and 5d0f079d; verified by the Linux rung (just test-linux: ContextCore's tests under Linux Swift, 2,405 passed; the board's rules built for WASI with the Swift 6.4.2 wasm SDK and `just wasm-test` passing under node), the Mac's host tests and lint (just native-test, 2026-11-22), the Mac build (just native-build-mac) and the iPad simulator (rung 2: WhiteboardTurnUITests, WhiteboardQuestionUITests, CockpitBackUITests, the nine chat classes and the whiteboard classes from Connect to Listening pass; WhiteboardLarryWaitUITests fails on main too, bead context-grabber-5ulm). The web board itself is not yet on the Cockpit.
- **Spec:** [The board's rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md)

#### Use Case:
- **As Igor,** drawing on the Cockpit's web ink board as well as on the iPad
- **I want to** have the web board ask the app's own board rules where a cut lands, not a copy of them in JavaScript
- **so that** a board answers the same on the web as on the iPad, and a rule fixed once is fixed in both

#### Acceptance Criteria:
- **Scenario:** The recorded sessions through the WebAssembly module
- **Given:** the board's rules built as WebAssembly by `just wasm`, and the Cockpit's recorded board sessions vendored in the repo
- **When:** `just wasm-test` loads the module under node and replays each session, then loads each session's last board whole and again in two halves
- **Then:** every session replays as the app's own replay test expects (contract 1, no mismatch but ops-move's known one, each turn's hint the end of the recorded one), the board answers every cut the same whole or in halves, a cut with nothing loaded is NaN with a reason, and the one 32-bit midpoint case answers as pinned

---

### User Story 1516:

- **Summary:** Simulator scripts started by hand take the first free build lane
- **Status:** implemented in [49957cd5](https://github.com/idvorkin/context-grabber/commit/49957cd5a6c07231a0300429cc1464413422c050). Verified on the host by `scripts/native/test-sim-lane.sh` with a script started outside any lane. The Mac's screen was locked, so there was no simulator run.
- **Issues:** bead context-grabber-w7nl (2026-11-22 ~21:20: a dead-code lane's timer smoke, run outside any lane, went to lane 1's iPad while lane 1 ran the whiteboard suite on it: three smoke failures, each different, and the suite's own run spoiled)

#### Use Case:
- **As Igor,** with several agents running simulator checks on one Mac at once
- **I want to** have the smoke and UI suite scripts take a lane when I start them directly
- **so that** I can run them by hand while other jobs use their own simulators

#### Acceptance Criteria:
- **Scenario:** A simulator script started by hand
- **Given:** no build lane is held
- **When:** I start the smoke, chat UI or whiteboard UI script directly with a model name or a lane simulator's UUID
- **Then:** it announces that it is taking a lane and runs on the first free lane's simulator for that model

---

### User Story 1517:

- **Summary:** Booting or testing on a build lane's simulator requires its lane
- **Status:** implemented in [49957cd5](https://github.com/idvorkin/context-grabber/commit/49957cd5a6c07231a0300429cc1464413422c050), with case-insensitive UUID matching in [b905f89f](https://github.com/idvorkin/context-grabber/commit/b905f89fece3aed49d94c46ef8134f611273f85a). Verified on the host by `scripts/native/test-sim-lane.sh` with simulated boot and test commands refused with exit 64. Both UUID spellings were verified with lane 1's lock held.
- **Issues:** bead context-grabber-w7nl

#### Use Case:
- **As Igor,** sharing the Mac with other simulator jobs
- **I want to** have boot and test commands refused outside the simulator's owning lane
- **so that** a command started by hand cannot interrupt another job's tests

#### Acceptance Criteria:
- **Scenario:** Another lane's simulator
- **Given:** a command holds build lane 2 or holds no lane
- **When:** it targets lane 1's simulator for booting or testing, by name or by UUID in any letter case
- **Then:** it exits 64 before booting or running Xcode, and the message names the simulator and its lane and explains how to run the command

---

### User Story 1518:

- **Summary:** Simulator operations that require no build lane still run
- **Status:** implemented in [49957cd5](https://github.com/idvorkin/context-grabber/commit/49957cd5a6c07231a0300429cc1464413422c050). Verified on the host by `scripts/native/test-sim-lane.sh` with a simulator build command and an unowned simulator accepted by the guard.
- **Issues:** bead context-grabber-w7nl

#### Use Case:
- **As Igor,** building for the simulator or testing on a device outside the build lanes
- **I want to** run those operations without taking a lane
- **so that** they can run while the build lanes are occupied

#### Acceptance Criteria:
- **Scenario:** A build, or a simulator of no lane
- **Given:** no build lane is held
- **When:** I build for a lane's simulator or run tests on a simulator no lane owns
- **Then:** the command proceeds without requiring a build lane

---

### User Story 1519:

- **Summary:** Right before merging, ContextCore is compiled the way an archive compiles it
- **Status:** implemented in 5e3718a8, 9b62205d; verified on the host rung by scripts/native/test-release-check.sh in `just test`, and a real Release build of ContextCore (scripts/native/release-check.sh) on this branch
- **Issues:** bead context-grabber-6ocd
- **Spec:** [Story ID reservations](../superpowers/specs/2026-11-22-story-id-reservations-design.md), *The pre-merge check*

#### Use Case:
- **As Igor,** waiting for main's build to reach /builds and TestFlight
- **I want to** have the agent compile the shared core with the optimizer on before it merges a change to it
- **so that** a compiler crash only an optimized build hits stops the PR, instead of the next `just ota` after the merge

#### Acceptance Criteria:
- **Scenario:** A branch that changes the shared core
- **Given:** a PR that changes ContextCore has passed the pipeline
- **When:** the agent runs `just pre-merge` immediately before `gh pr merge`
- **Then:** if ContextCore's Release build fails, pre-merge ends with a FAIL line naming the Release build and a nonzero exit

---

### User Story 1628:

- **Summary:** The store is walked on the Mac: every implemented story's named check runs again
- **Status:** implemented in 92ed7fbd, 0c95fab8 (the whiteboard and chat suite scripts read from the simulator rung); verified by a full walk of main on this Mac (scripts/native/walk.py, `just walk`)
- **Issues:** Igor 2026-11-24, "Drive build and walk store tonight"
- **Spec:** [The store walk on the Mac](../superpowers/specs/2026-11-24-store-walk-design.md)

#### Use Case:
- **As Igor,** wanting to know which features still work as their stories say
- **I want to** have the Mac run every check the stories name, once, and report per story
- **so that** a feature that quietly broke, or a story whose test is gone, shows up as a red I can act on

#### Acceptance Criteria:
- **Scenario:** A walk with one red UI class
- **Given:** a UI test class fails on the iPad simulator
- **When:** the agent runs `just walk`
- **Then:** the walk still runs every other class and the report names that class's stories red

---

### User Story 1626:

- **Summary:** Every UI test runs once a day while the Mac is idle
- **Status:** implemented in d5f3ea25 and 238a7d3e; verified on the host by `scripts/native/test-nightly-ladder.sh` in `just test`, with every Mac reading stood in for. The schedule is installed by hand (`just nightly-install`).
- **Issues:** bead context-grabber-3rk (Igor approved the daily run, 2026-11-12)

#### Use Case:
- **As Igor,** whose changes each run only the UI test classes they touch
- **I want to** have the whole ladder, every UI test class, run once a day on main when the Mac isn't working
- **so that** a test no recent change picked still runs daily, without slowing anyone's day

#### Acceptance Criteria:
- **Scenario:** The Mac is idle in the night
- **Given:** it is between 1 and 6 in the morning, the Mac is on AC power, its CPU is under 30% busy, no build lane is held, and the full ladder hasn't run today
- **When:** the scheduled check runs
- **Then:** the full ladder climbs on a fresh copy of main, once that day; if anything fails, the failures are written beside the day's log and the run ends with a failure (a checkout that can't reach main writes its reason there and leaves the day to the next check); at any other time it says why it waited and starts nothing

---

### User Story 1629:

- **Summary:** Right before merging, the app is compiled with the branch merged onto main as it is now
- **Status:** implemented in 3f20a7d4; verified on the host rung by scripts/native/test-merged-tip-check.sh in `just test`, and a real run (scripts/native/merged-tip-check.sh) that caught main's MessageBubble `group:` break of 2026-11-24
- **Issues:** #1459 and #1465 broke main's Debug build together, 2026-11-24
- **Spec:** [Story ID reservations](../superpowers/specs/2026-11-22-story-id-reservations-design.md), *The pre-merge check*

#### Use Case:
- **As Igor,** with many agents merging into main at once
- **I want to** have the agent compile the app on its branch merged onto main as main is right now, before it merges
- **so that** two PRs that each pass alone can't land minutes apart and leave main unable to build for every lane and device install

#### Acceptance Criteria:
- **Scenario:** Two branches that only break the build together
- **Given:** one PR changed a view's parameters and merged, and another PR that calls the old way passed its pipeline before that merge
- **When:** the agent runs `just pre-merge` on the second PR immediately before `gh pr merge`
- **Then:** pre-merge ends with a FAIL line naming the compile error and a nonzero exit, and the PR doesn't merge

---

### User Story 1634:

- **Summary:** Every build installed on a device is also on the Cockpit's /builds page, so the page is never behind the devices
- **Status:** implemented on branch `native/ota-on-every-install` with BugKit's `ota-upload.sh` (bug-kit bead `bug-a5y`, its PR not merged yet; the hook does nothing until it is in `~/gits/bug-kit`); verified on the host by bug-kit's tests of the uploader and of `deploy-all.sh` with fake Xcode tools, a slow copy and a `tee` pipe; the uploader itself published `audio-debugger-89c1cabb.ipa` and `magic-monitor-2c84beaf.ipa` to /builds on 2026-11-25. No install was run here (an install restarts the app on Igor's devices)
- **Why:** Igor, 2026-11-25 (via Larry): "Why new builds not uploaded", and "And any other updated apps": /builds had only the 06:40 build while newer ones went straight to his devices.
- **Issues:** bead `context-grabber-59m0` (bug-kit `bug-a5y`)

#### Use Case:
- **As Igor,** installing from the Cockpit's /builds page when the Mac can't reach the iPad
- **I want to** find there the build the devices last got
- **so that** the page is never behind what is installed, without anyone remembering to run `just ota`

#### Acceptance Criteria:
- **Scenario:** A network install
- **Given:** BugKit's `ota-upload.sh` is in `~/gits/bug-kit` and BugKit's config names the builds folder
- **When:** `just deploy` installs a commit on one device or more
- **Then:** that installed bundle is copied to /builds as `grabber-<first 8 of the commit>.ipa` in the background, the deploy goes on to its build check without waiting, and its outcome is a line in `~/tmp/agent/notes/ota-uploads.log`

- **Scenario:** A cable install
- **Given:** the same
- **When:** `just native-run-device` installs on the phone or the iPad
- **Then:** the installed bundle is copied the same way, before the launch, which doesn't wait for it

- **Scenario:** Already on the page, or uncommitted
- **Given:** /builds already has that commit's ipa, or the build was made from uncommitted changes
- **When:** an install finishes
- **Then:** an existing ipa is touched rather than copied, so it shows as the newest; an uncommitted build goes up as `grabber-<commit>-dirty.ipa`, never under the clean name

- **Scenario:** The Cockpit is unreachable
- **Given:** the copy fails
- **When:** the install finishes
- **Then:** the install and the launch still succeed, nothing on the page is replaced, and the log says the copy failed
