# Agent instructions: Context Grabber

iOS app that holds up a humane mirror of Igor's week — health, places, roles, a journal — and feeds it to Larry, his
AI coach, as a context export and over a voice call. Also a gym timer and box breathing. The app is **Grabber
Native**, Swift and SwiftUI under `native/` (Igor, 2026-10-04; bead `context-grabber-3ss`, spec
`docs/superpowers/specs/2026-10-04-swift-native-app-design.md`): `native/ContextCore/` is the platform-free SwiftPM
package (host tests), `native/App/` the SwiftUI app, `native/Widgets/` the widgets and Live Activities, `native/Share/` the share extension (the Inbox, #305),
`native/project.yml` the XcodeGen spec (the `.xcodeproj` is generated, never committed or hand-edited). The React
Native app it replaced was removed 2026-10-17; "Ported from lib/….ts" comments name where logic came from, and git
history has the rest. The stories are what must stay true, not the old TypeScript. Work lands on a branch as one PR
per bead or issue, through the no-mistakes pipeline (below); the agent merges it.

Recipes: `just native-test` (which first runs `native-lint-format` and `native-lint`; `native-format` fixes the
layout, a SwiftLint finding is rewritten or justified on a `swiftlint:disable:next` line), `native-test-sim`,
`native-run-device`, `native-run-mac`, `deploy` (every network install goes through it, so the ledger holds it; `device-build-check` says which build a device really runs: check it before telling anyone, story 1511), `pull-logs`, `bugs-check`. Reports and crashes are filed by BugKit's always-on listener on the
Mac, never by hand: watch `~/tmp/agent/bugs/inbox.jsonl` (or its Herdr notification) and fix what lands.

## Read these before working

| File | What it settles |
|---|---|
| [VISION.md](VISION.md) | what the app is for and who it serves: the humane mirror, the front door, the phone's line to Larry |
| [docs/TESTING.md](docs/TESTING.md) | the test ladder (lint → host → Mac → simulator → phone), which change is verified where, the launch hooks, the real-data fixtures, what only the phone can show |
| [docs/DEPLOYING.md](docs/DEPLOYING.md) | how a build reaches the phone and the iPad: the cable and network install, `just ota` and `ota-watch` over the air, signing, renewing the profile, adding a device, iCloud development vs production, what would make it faster |
| [docs/DEBUGGING.md](docs/DEBUGGING.md) | the session log and its events, copyable errors, instrument before theorizing, how a bug goes from the phone to a closed issue |
| [docs/stories/README.md](docs/stories/README.md) | the spec: user stories per journey, each with its status and commits |
| [docs/superpowers/specs/](docs/superpowers/specs/) | the design spec behind each feature — functionality, not implementation; updated before the code |
| [docs/jtbd.md](docs/jtbd.md) | why: the two-way mirror, the two dragons, what the app is NOT (a fitness tracker, a habit tracker, a journal app) |

## Rules

- **Apple docs and Simulator/Previews: follow the `ios-codev` skill** (Igor, 2026-11-24). It covers looking up Apple APIs on Sosumi before coding, and previews first, then the Simulator, from the CLI on the Mac only. Read [`skills/ios-codev/SKILL.md`](https://github.com/idvorkin/chop-conventions/blob/main/skills/ios-codev/SKILL.md) (lands with chop-conventions #275), or `~/.claude/skills/ios-codev/SKILL.md` once the skill is symlinked.
  This repo's own simulator and build-lane rules (test ladder, `build-lane.sh`) still apply.
- Shared practices for all apps live in idvorkin/bug-kit (README: Shared practices for every app). A bug in BugKit's own code (the report dialog, dictation, the store, crash capture, CloudKit, the listener, What's new) or a practice that applies to every app is filed there and linked from this repo's issue, never fixed here.
- **Test ladder**: `just test-ladder` climbs it, cheapest rung first, stopping at the first failure (`--dry-run` says
  what it would run). Rung 0 lint and 1 host are `just test` (swift-format and SwiftLint, `ContextCore`'s XCTest, the
  script checks; seconds); off the Mac, rung 1L `just test-linux` stands in first (ContextCore's tests on Linux, the
  package and the app's sources compiled for Apple, the portable script checks) → 1.5 the Mac build (`just native-build-mac`) → 2 the simulator (`just native-test-sim`,
  launch hooks judged from the session log, and the UI tests in `native/UITests/`; never while as many other xcodebuilds run as there are build lanes)
  → 3 the phone (`just native-run-device`). Verify on the cheapest rung that can see the change and **say which rung
  you used**. Audio session behaviour, HealthKit, GPS, widgets, Live Activities,
  Shortcuts and the voice bridge exist only on the phone ([TESTING.md](docs/TESTING.md)).
- **Which machine builds what** (Igor, 2026-11-24). Larry's Linux VM builds and tests all WebAssembly (BoardWasm,
  AudioWasm: `just wasm`, `just wasm-test`), runs the Linux Swift tests, and does xtool iPad builds when the Mac is
  busy. The Mac does Xcode, the simulators, the Mac app, signing, `/builds` and device installs. When a branch changes
  BoardCore's exports or anything the wasm builds, push it and ask Larry on the lead thread (`igor2-88g.1620`) to build
  and test it; he posts the result. Don't run `just wasm-test` on the Mac or report "no wasm SDK" as a skip: the wasm
  check belongs to the VM, so say it's with Larry.
- **Spec first, story always.** The design spec (`docs/superpowers/specs/`) is updated before the code — the full
  rule is below. And every feature or behaviour change updates the user stories (`docs/stories/`) in the same PR: a
  new capability gets a story in its journey (Cohn + Gherkin, the `user-story` skill) with a `Status:` line naming
  its commit and where it was verified; a changed behaviour edits the story's acceptance criteria and adds its
  commit to the `Status:` line. Status lives only on the stories. **No story, not done.** A new story's ID comes
  from `scripts/native/story-ids.py reserve <journey> [n]` (story 791), never from "the next free ID" on your own
  branch: parallel PRs that each picked one put duplicates on main four times on 2026-11-22. That holds for a story
  the pipeline's review or document step adds or splits off too. Never add a journey's block to
  `docs/stories/README.md` by hand: when reserve says a journey is full, stop and say so (bead context-grabber-1vvb:
  the review step added block 1600–1619 itself, and took 232 by hand, on 2026-11-22).
- **Instrument before theorizing.** For any phone-only symptom add the session-log event that would settle it (or a
  copyable error carrying the state), ship it, reproduce, pull the logs, read the evidence, then fix. Never ship a
  second guessed fix ([DEBUGGING.md](docs/DEBUGGING.md)).
- **Track work in beads; GitHub issues are for what BugKit files** (Igor, 2026-11-21: "Beads is the right place.
  GitHub should be for bigger issues that came in over Bugkit"). Shake reports and crashes arrive as GitHub issues,
  filed by the listener. Everything else is a bead (`bd create`) with the evidence on it: a copied error, Igor's
  voice in the session, a follow-up, a review finding left for later, a flaky test, work an agent finds. Never open
  a GitHub issue for those, and never backfill beads from old GitHub issues.
- **Bugs**: before fixing, find or write the story in `docs/stories/` that covers it (a bug gets an `Issues:` line
  naming the GitHub issue or the bead, a request becomes a story, no story means the spec has a hole). One PR per
  bead or issue, referencing it; never bundle fixes. Close it once the build is on the phone with a note saying what
  was verified where and what Igor should feel (a comment on a GitHub issue, `bd close --reason` on a bead); Igor
  reopens if it is not fixed. Never leave a fixed bug open.
- **Igor runs beads on several machines**: `bd dolt pull` before every `bd dolt push`.
- **A bug in BugKit code is fixed in [idvorkin/bug-kit](https://github.com/idvorkin/bug-kit), not here.** That covers
  the dialog, the shake, dictation, the store and its format, crash capture, pruning, What's new, the listener and the
  scripts. File the bug there, fix it test-first, open a PR, then bump BugKit here. Until that lands, work around it
  only through BugKit's hooks or options, with a `ponytail:` comment that names the bug-kit issue. Bugs in our own
  hooks are fixed here. See "Where a bug gets fixed" in the bug-kit README (bug-kit PR #5).
- **Every user-visible error is copyable** (BugKit's `BugProblemView`): the message, a `context` naming the screen and
  operation, and the state that explains it — never a bare red string.
- **Sanity-check geometry thresholds against the real fixtures** (`__tests__/fixtures/locations.json`,
  `context-grabber.db`) before shipping clustering, place-matching or distance rules; synthetic tests miss what real
  data exposes.
- **Never run `xcodebuild test` on a simulator outside the wrapper; on a locked Mac it skips only the tests that open
  the mic** (stories 1022–1024, 1509, beads `context-grabber-208e`, `context-grabber-wm8y`). A locked Mac starves the
  simulator's audio server, and the app aborts in Apple's audio toolbox when a test opens the mic (now a simulator crash
  ends at `Documents/crashes/signal-*.txt` in the app's container); every other UI test runs locked as unlocked (Igor,
  2026-11-22, after the evidence in [TESTING.md](docs/TESTING.md)). `scripts/native/xcodebuild-log.sh` skips the tests
  `scripts/native/mic-tests.txt` lists as opening the mic and names them to rerun unlocked, and stops a run when the
  screen locks only while one of those is still to run. A new UI test that taps a mic control or starts a call goes on
  that list (`mic` or `reviewed`), or `just test` fails. A 75 there means unlock and rerun, not debug.
- **Build lanes scale with RAM; one booted simulator per lane, left booted between runs** (stories 785, 980; #954).
  The Mac and simulator rungs run in `scripts/native/build-lane.sh run`: one job per lane, `BUILD_LANES` or one lane
  per 12 GB, at most four (4 on this 48 GB Mac, 1 on a 16 GB one, where everything is one job at a time as before).
  Each lane has its own simulators (lane 1 the named ones, lane N "<name> lane N", cloned once; `just
  native-sim-lanes`). Boot one only inside a lane, through `scripts/native/sim-boot.sh <name|udid>`: it never shuts
  down a busy lane's simulator, keeps the booted count at or under the lane count, and boots yours only if it isn't
  up. Don't shut it down when done: the lane's next run reuses it. Switch device only when the device changes. Every
  iOS 27 boot writes about 300 MB of wallpaper snapshots that are never evicted (the disk filled on 2026-11-17) and
  spikes the CPU, and booted simulators past the RAM starve each other (about 10 GB each).
  Host builds and tests (swift-format, SwiftLint, ContextCore's `swift test`, the Mac build) take one of
  `HOST_LANES` host slots (a quarter of the cores, at most four) through `scripts/native/host-lane.sh run` inside the
  recipes (stories 795, 797, 798): run a host test by hand from `native/ContextCore` as
  `../../scripts/native/host-lane.sh run swift test --filter …`, never a raw `swift test`, and never take a slot inside
  another.
- **Build in a pool slot, not a new worktree.** `slot=$(treehouse get --lease -b <branch>)`, work and build there,
  `treehouse return "$slot"` once the branch is pushed. A slot keeps its `native/Build` across returns, so disk stays
  bounded and the device ids are seeded; a new worktree leaves another build folder behind (the speed gain is ~30 s). Twelve slots (`treehouse.toml`), two per build lane on the M5 Pro's six;
  [TESTING.md](docs/TESTING.md) has the rest, pruning included.
- **Background agents** that investigate are read-only, in a worktree, notes under `~/tmp/agent/notes/`; confirm
  scope before an agent that writes to the repo. Reap background commands when done.
- **Every change goes through the no-mistakes pipeline, and the agent merges it.** The gate is installed in
  this repo: `no-mistakes axi run --intent "…"` (or push to the `no-mistakes` remote). When the run reaches
  `checks-passed`, run `just pre-merge` in the branch's checkout immediately before `gh pr merge` (story 793: the
  story IDs on the branch as pushed, merged with main as it is now; if it fails, renumber with a fresh reservation,
  push and rerun), then merge the PR yourself and check that its commits reached `origin/main`. Chain them, `just
  pre-merge && gh pr merge …`, so its exit status decides: never pipe its output (`| tail` hid a failure and #1400
  merged duplicate story IDs onto main, 2026-11-24). It also compiles the app on the branch merged onto main as it is now (story 1629: #1459 and #1465 each passed alone and broke main's build together). The pipeline's lint step (`just pipeline-lint`, story 1515)
  already fails a branch that adds a story ID another open PR adds. Don't wait for PR
  feedback, because nobody gives it: the pipeline is the review.
- **One pipeline run per train** (Igor, 2026-10-11). Finish the whole stack before the first push, and don't push
  while a run is in flight unless review or test asked for that fix. Never restart the no-mistakes daemon or reboot
  while runs are active. Live simulator and device checks happen once, in your build turn, and go in the PR body;
  the pipeline's test step is host-only.
- **Merge a ready PR before anything that touches its files** (Igor, 2026-11-01, after #583 stalled). When a PR
  reaches `checks-passed`, run its simulator check right away and merge it. Never merge another PR into main ahead
  of it if that PR edits the same files (the smoke script, `AppModel`, `docs/TESTING.md`). A base change that
  conflicts makes no-mistakes rebase the waiting PR and re-run it from Review: a second review, a second test pass
  and new approval gates, about 15 minutes, for nothing. Two PRs that both edit one file go in one after the other.
  The second one starts only once the first has merged, or the second waits.
- **No CI here, so don't wait on the review bots.** The repo declares `no_ci: true`, but GitHub can still attach
  Copilot's PR reviewer and CodeRabbit to a push as checks. Once they are attached, no-mistakes' CI step waits for
  them. Once the run's review, test, document, lint, push and PR steps have all completed, and the only thing left
  is the CI step "waiting for results" on those bots, merge the PR. Don't wait for them.
- **Review settles in one fix round.** In round 1, fix every error and warning together. In later rounds, fix errors
  only and decide info findings in one pass. Cap review at two rounds; file the rest as beads.
- **Architecture is discussed, not assumed**: propose with a trade-off table or a numeric plan, then one "do it".
  Prefer `just` recipes over raw commands — they carry the project generation, the signing lock and the build stamps.

## Spec-First Workflow

**ALWAYS UPDATE THE SPECS BEFORE UPDATING THE CODE.** No exceptions. This applies to new features, bug fixes that change visible behavior, UX tweaks, and refactors that alter contracts. If you catch yourself opening a `.swift` file before a `.md` spec file, stop and go to the spec first.

**Specs describe FUNCTIONALITY, not implementation.** A spec says what the user sees, what the feature does, and what the acceptance criteria are. It does NOT name files, prop shapes, type definitions, function signatures, cache keys, component hierarchies, or where code goes. Implementation details belong in a plan (`docs/superpowers/plans/`) or in the code itself, not the spec. If a reader could use the spec as a QA checklist without ever opening the codebase, it's at the right level. If it reads like a refactor diff, strip it.

- **In the spec:** user-visible behavior, UX flows, edge cases, acceptance criteria, screenshots/mocks, goals/non-goals, rationale.
- **NOT in the spec:** file paths, prop names, type definitions, component names, function signatures, state shapes, cache key names, "in `Foo.swift`, change X", or any sentence that only makes sense if you've read the code.

Specs live in `docs/superpowers/specs/` as `YYYY-MM-DD-<feature>-design.md`; implementation plans (if needed) live alongside in `docs/superpowers/plans/`. The sequence for ANY change request is:

1. Find or write the spec (summary, goals/non-goals, user-visible behavior, acceptance criteria).
2. Confirm the spec with the user — they can edit it independently of code.
3. Only then touch code. For non-trivial changes, write an implementation plan in `docs/superpowers/plans/` in the same step as the spec update — the spec stays functional, the plan holds types/files/rollout.

**Bug reports and UX tweaks on existing features are spec changes.** "This thing is wonky" / "I don't like how X works" / "what should happen if Y" are all triggers to re-open the feature's spec FIRST, not to triage fixes. If the spec no longer matches reality, update the spec in the same change as the code. Never let implementation drift silently from spec.

## Build & Run

**Prefer `just` commands over running raw commands.**

```bash
just setup                # swiftlint, xcbeautify, imagemagick, xcodegen from Homebrew
just test-ladder          # climb: lint, host, Mac, simulator's touched UI tests; stops at the first failure (--dry-run, --full, --all)
just test                 # = just native-test: lint, ContextCore's host tests, the script checks
just native-test-sim      # simulator build + the launch-hook smoke (scripts/native/sim-smoke.sh)
just native-sim-health    # grant simulator Health access (see docs/TESTING.md)
just native-run-device    # build under the signing lock, install and launch on the iPhone
just testflight           # the commit to TestFlight beside the cable (--export-only needs no key; docs/TESTING.md)
just ota                  # main, development-signed, to the Cockpit's /builds for the iPad (docs/DEPLOYING.md)
just ota-watch            # just ota after each merge batch, posted to Igor's thread (foreground; docs/DEPLOYING.md)
just pull-logs            # session logs, reports and crashes from the phone (and the iPad)
just bugs-check           # unfiled reports on every plugged-in device
```

Requires Xcode, an Apple ID signed into Xcode, Developer Mode on the iPhone, and the `just setup` tools
(`native/.swiftlint.yml` pins SwiftLint's version; the tile-art check measures the art with `magick`). The phone's hardware UDID is `DEVICE=<udid>` or the gitignored
`scripts/native/phone-udid.local`: the repo is public, so device ids are never committed. UI tests run through the
wrapper, `scripts/native/xcodebuild-log.sh <name> "TEST SUCCEEDED" xcodebuild … -only-testing:GrabberNativeUITests/<Test> test`
([TESTING.md](docs/TESTING.md)).

## Key Patterns

- **Never run a signing build while the Mac's screen is locked.** `native-run-device` goes through BugKit's
  `signing-guard.sh`, which waits while the screen is locked and fails Xcode's "No Accounts" with exit 78; a build
  that loses the Apple ID needs it re-added in Xcode → Settings → Accounts. One signing build at a time, under
  `~/tmp/agent/locks/xcode-signing.lock` (the recipe takes it; don't wrap it in another `lockf` on that lock).
- All timestamps: UTC unix milliseconds in storage, ISO 8601 UTC in export.
- Day bucketing uses **local time** (not UTC) — "your Tuesday" means local Tuesday.
- Sleep bucketing is **noon-to-noon** — a pre-noon sample belongs to the PREVIOUS night. Sleep merges overlapping
  intervals before summing (Watch and iPhone both report the same period).
- Today's health is always live; past days are cached in SQLite. Each HealthKit query fails on its own: one metric's
  failure is that metric's `null`, never the whole grab's.
- Background location tracking is opt-in (defaults to OFF); retention defaults to 30 days and prunes at launch and
  when lowered. Clustering is computed when Places opens or the export is made, not on every point.
- **iOS CoreLocation suppresses GPS updates when the phone is stationary** (motion-coprocessor confirmed). Multi-hour
  overnight gaps are normal — fix it at the clustering layer (the consecutive same-place merge), not by collecting
  more often.
- **The export JSON is a contract Larry depends on** (`docs/user-needs.md`, Export Contract). `MirrorFixtureTests`
  pins it byte for byte against the files the React Native app produced; change those files only with a deliberate
  behaviour change.
- **The Gym Timer's cues are sound files, never synthesis.** Spoken — *three, two, one, go! / rest / done* — in
  Igor's own voice (his ElevenLabs clone, `ELEVEN_API_KEY` from the environment or the secretbox; the Mac's `say`
  when absent) by `scripts/make-timer-words.sh`, padding trimmed and composed into `assets/audio/timer/*.wav` by
  `scripts/make-timer-cues.mjs` (`just timer-cues`). Three count voices from a gear on the timer (stories 182, 187;
  setting `gym_count_voice`): Adam (the default), Igor (those same files) and an excited Australian woman — the other
  two are `assets/audio/timer-voices/<voice>-<cue>.wav`, rendered once each (it costs credits) by
  `scripts/make-timer-voice.sh <name> <voice_id> <plain|firm|excited>` (eleven_v3; it flags a count word over 1 s,
  re-render it with `ONLY=<word> TAKES=4`). A near-silent keepalive loop holds the session with the phone locked.
- **The Gym Timer's audio session is `playback` mixed with others; a workout never pauses the music.** Around each cue
  a *duck window* adds `duckOthers` + `interruptSpokenAudioAndMixWithOthers` to the live session, then lets go with
  a deactivate-and-reactivate with `notifyOthersOnDeactivation` (a paused podcast resumes only on deactivation) and
  restarts the keepalive loop. Per-tick ducking makes music pump; the window is the unit. Spec:
  `docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md`.
- **Echo cancellation on iOS is VoiceProcessingIO, not a session mode.** `AVAudioSession.Mode.voiceChat` alone leaves
  `AVAudioEngine` on RemoteIO and the speaker feeds straight back into the mic (#80). The call switches it on with
  `inputNode.setVoiceProcessingEnabled(true)` on a stopped engine before reading the input format (VPIO reports a
  different one). Anything that re-`setCategory`s the session must preserve `.voiceChat` while a call is live.
- **WebKit enumerates one nameless microphone and zero outputs, and has no `setSinkId`.** That is every browser
  engine on iOS, `WKWebView` included, and it is why a hosted page's device pickers vanish inside the app while
  working fine on a laptop. There is nothing to fix in the page. The roster only exists in `AVAudioSession`; the
  Cockpit's audio bridge carries it into the web view (`docs/cockpit-audio-bridge.md`). Corollary: the web view's own
  capture reconfigures the shared audio session when it starts, so a route set *before* a call begins has to be
  re-asserted on `routeChangeNotification` or it silently reverts. `WKWebView` denies `getUserMedia` unless its UI
  delegate answers `requestMediaCapturePermissionFor`.
- **A new whiteboard feature gets its own file, not a bigger one** (Igor, 2026-11-21, context-grabber-jp6z). The
  board model's methods live in `native/App/Whiteboard/WhiteboardModel+<Feature>.swift` (its state, init and load in
  `WhiteboardModel.swift`, the SwiftUI view alone in `WhiteboardView.swift`), and the canvas's in
  `PaperBoard+<Feature>.swift`. A new feature adds its own `+Feature.swift` file and its own story section rather
  than growing `WhiteboardView.swift` or `PaperBoard.swift`: two PRs that edit one file go one after the other, so a
  big shared file serialises every whiteboard PR behind the one before it.
- **Never put `invalidatableContent()` on a `Button(intent:)` label.** With it, the tap stops running the intent and
  falls through to `widgetURL` (opens the app) — bisected on the memdeck card, 2026-09-07. If a dim-while-changing
  look is wanted, mark a sibling view, not the button's own label. Keep widget intents discoverable. iPhone
  lock-screen (accessory) widgets run no in-place actions at all — a `Button(intent:)` there rendered blank; they get
  a `widgetURL`.
- **Ignore recurring `bd doctor` warnings for `Dolt Status / Dolt Locks: config: modified`.** Every `bd` read
  (including `bd doctor` itself) re-creates that state; `bd vc commit` clears it but the next read brings it back.
  Cosmetic, not actionable.

## SQLite Tables

`locations` (GPS breadcrumbs), `settings` (key/value), `known_places` and `known_place_icons`, `health_raw_cache`,
`health_computed_cache` and `health_cache_meta` (bumping the cache version purges both caches), `daily_strip`
and `daily_strip_peers` (other devices' strip rows, synced over iCloud), `activity_log`, `accessory_log`, `archive_cursor` (where each stats-archive stream's last taken page ended, story 270; for a strip stream, the value the archive last took for each day, story 271). The file is opened in WAL mode with a 2 s busy timeout, and every transaction is `BEGIN IMMEDIATE`: the app holds two connections to it (the health cache is written from a grab's task group). The export is the database file itself (*Export database*), and *Import from
Context Grabber* reads the old app's export.

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
