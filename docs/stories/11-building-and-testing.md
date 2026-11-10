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
- **Status:** not implemented; bead `context-grabber-3k6`. Moved to host tests so far, each with the UI or smoke checks that only repeated it cut: the whiteboard turn's rules (`WhiteboardGhostTurnsTests`, [3985337](https://github.com/idvorkin/context-grabber/commit/3985337)), the whiteboard's persistence policy (`BoardKeepingTests`, [f41be39](https://github.com/idvorkin/context-grabber/commit/f41be39)), the Inbox's send orchestration (`InboxOutboxTests`, [845a6f2](https://github.com/idvorkin/context-grabber/commit/845a6f2)) and the chat archive and new-thread rules (`ChatArchiverTests`, `ChatNewThreadScreenTests`, [23dd212](https://github.com/idvorkin/context-grabber/commit/23dd212)); verified together at [f83889f](https://github.com/idvorkin/context-grabber/commit/f83889f) on the Mac host (rung 1, 1,123 ContextCore tests) and the simulator (rung 2: the whiteboard and chat UI suites and the smoke)

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
- **Status:** not implemented; bead `context-grabber-3k6`

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
- **Status:** partly implemented in d91ca4d, 2e67445, 2fcd476: the UI tests wait with `appears(within:)`, verified on the simulator (rung 2, the board suite 63 tests in 1621 s, chat 22 of 22); the fixed `sleep` pauses remain; bead `context-grabber-3k6`

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
- **Status:** implemented in 28af189; verified on the host rung (`scripts/native/test-ui-timings.sh`, against a real whiteboard run's log)
- **Issues:** [#826](https://github.com/idvorkin/context-grabber/issues/826)

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
- **Status:** implemented in [97a0b57](https://github.com/idvorkin/context-grabber/commit/97a0b57); verified on the Linux rung (`just test-linux` on aarch64 Ubuntu: 1,185 tests, the three cross-builds, the app's sources for iOS and the three script checks all ok); the Mac's own rungs are unchanged
- **Issues:** the test-ladder audit of 2026-11-10 ("Linux as a real rung")

#### Use Case:
- **As Igor,** with agents working on Linux boxes while the Mac is busy or locked
- **I want to** have every change compiled and host-tested off the Mac first, app code included
- **so that** a type slip in a view or a broken ladder map shows up on the agent's box in minutes, not in the Mac's build an hour later

#### Acceptance Criteria:
- **Scenario:** An agent on Linux changes app code and a host test
- **Given:** a Linux box with the Swift toolchain and the Darwin SDK, and no Mac
- **When:** the agent runs the Linux rung
- **Then:** ContextCore's tests run, the package and the app's sources (the app, the widgets, the share extension and the UI tests) are compiled for Apple, the ladder's map is checked, and each step says ok, failed or skipped and why

---

### User Story 688:

- **Summary:** A new branch builds in a worktree that already has a build
- **Status:** implemented in 0e0cf96; verified on the Mac rung (a slot returned and re-leased for a new branch rebuilt in 7 s with one file touched, against 39 s for its first build)
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
