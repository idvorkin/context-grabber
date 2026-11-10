# Agent instructions: Context Grabber

iOS app that holds up a humane mirror of Igor's week — health, places, roles, a journal — and feeds it to Larry, his
AI coach, as a context export and over a voice call. Also a gym timer and box breathing. The app is **Grabber
Native**, Swift and SwiftUI under `native/` (Igor, 2026-10-04; bead `context-grabber-3ss`, spec
`docs/superpowers/specs/2026-10-04-swift-native-app-design.md`): `native/ContextCore/` is the platform-free SwiftPM
package (host tests), `native/App/` the SwiftUI app, `native/Widgets/` the widgets and Live Activities, `native/Share/` the share extension (the Inbox, #305),
`native/project.yml` the XcodeGen spec (the `.xcodeproj` is generated, never committed or hand-edited). The React
Native app it replaced was removed 2026-10-17; "Ported from lib/….ts" comments name where logic came from, and git
history has the rest. The stories are what must stay true, not the old TypeScript. Work lands on a branch as one PR
per issue, through the no-mistakes pipeline (below); the agent merges it.

Recipes: `just native-test` (which first runs `native-lint-format` and `native-lint`; `native-format` fixes the
layout, a SwiftLint finding is rewritten or justified on a `swiftlint:disable:next` line), `native-test-sim`,
`native-run-device`, `native-run-mac`, `pull-logs`, `bugs-check`. Reports and crashes are filed by BugKit's always-on listener on the
Mac, never by hand: watch `~/tmp/agent/bugs/inbox.jsonl` (or its Herdr notification) and fix what lands.

## Read these before working

| File | What it settles |
|---|---|
| [VISION.md](VISION.md) | what the app is for and who it serves: the humane mirror, the front door, the phone's line to Larry |
| [docs/TESTING.md](docs/TESTING.md) | the test ladder (lint → host → Mac → simulator → phone), which change is verified where, the launch hooks, the real-data fixtures, what only the phone can show |
| [docs/DEBUGGING.md](docs/DEBUGGING.md) | the session log and its events, copyable errors, instrument before theorizing, how a bug goes from the phone to a closed issue |
| [docs/stories/README.md](docs/stories/README.md) | the spec: user stories per journey, each with its status and commits |
| [docs/superpowers/specs/](docs/superpowers/specs/) | the design spec behind each feature — functionality, not implementation; updated before the code |
| [docs/jtbd.md](docs/jtbd.md) | why: the two-way mirror, the two dragons, what the app is NOT (a fitness tracker, a habit tracker, a journal app) |

## Rules

- Shared practices for all apps live in idvorkin/bug-kit (README: Shared practices for every app). A bug in BugKit's own code (the report dialog, dictation, the store, crash capture, CloudKit, the listener, What's new) or a practice that applies to every app is filed there and linked from this repo's issue, never fixed here.
- **Test ladder**: `just test-ladder` climbs it, cheapest rung first, stopping at the first failure (`--dry-run` says
  what it would run). Rung 0 lint and 1 host are `just test` (swift-format and SwiftLint, `ContextCore`'s XCTest, the
  script checks; seconds); off the Mac, rung 1L `just test-linux` stands in first (ContextCore's tests on Linux, the
  package and the app's sources compiled for Apple, the portable script checks) → 1.5 the Mac build (`just native-build-mac`) → 2 the simulator (`just native-test-sim`,
  launch hooks judged from the session log, and the UI tests in `native/UITests/`; never while another xcodebuild runs)
  → 3 the phone (`just native-run-device`). Verify on the cheapest rung that can see the change and **say which rung
  you used**. Audio session behaviour, HealthKit, GPS, widgets, Live Activities,
  Shortcuts and the voice bridge exist only on the phone ([TESTING.md](docs/TESTING.md)).
- **Spec first, story always.** The design spec (`docs/superpowers/specs/`) is updated before the code — the full
  rule is below. And every feature or behaviour change updates the user stories (`docs/stories/`) in the same PR: a
  new capability gets a story in its journey (Cohn + Gherkin, the `user-story` skill) with a `Status:` line naming
  its commit and where it was verified; a changed behaviour edits the story's acceptance criteria and adds its
  commit to the `Status:` line. Status lives only on the stories. **No story, not done.**
- **Instrument before theorizing.** For any phone-only symptom add the session-log event that would settle it (or a
  copyable error carrying the state), ship it, reproduce, pull the logs, read the evidence, then fix. Never ship a
  second guessed fix ([DEBUGGING.md](docs/DEBUGGING.md)).
- **Bugs**: a report Igor makes — a shake report, a copied error, or his voice in the session — becomes a GitHub
  issue with the evidence attached (shake reports and crashes by the listener, the rest by you). Before fixing, find
  or write the story in `docs/stories/` that covers it (a bug gets an `Issues:` line, a request becomes a story, no
  story means the spec has a hole). One PR per issue, referencing it; never bundle fixes. Close the issue once the
  build is on the phone with a comment saying what was verified where and what Igor should feel; Igor reopens if it
  is not fixed. Never leave a fixed bug open.
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
- **Only one simulator on this Mac at a time.** Before booting one, check `xcrun simctl list devices booted` and
  wait until it is empty; shut yours down when done (`xcrun simctl shutdown <udid>`). Other agents and other repos'
  pipelines share this Mac, and two simulators at once starve both.
- **Build in a pool slot, not a new worktree.** `slot=$(treehouse get --lease -b <branch>)`, work and build there,
  `treehouse return "$slot"` once the branch is pushed. A slot keeps its `native/Build` across returns, so disk stays
  bounded and the device ids are seeded; a new worktree leaves another build folder behind (the speed gain is ~30 s). Four slots (`treehouse.toml`);
  [TESTING.md](docs/TESTING.md) has the rest, pruning included.
- **Background agents** that investigate are read-only, in a worktree, notes under `~/tmp/agent/notes/`; confirm
  scope before an agent that writes to the repo. Reap background commands when done.
- **Every change goes through the no-mistakes pipeline, and the agent merges it.** The gate is installed in
  this repo: `no-mistakes axi run --intent "…"` (or push to the `no-mistakes` remote). When the run reaches
  `checks-passed`, merge the PR yourself and check that its commits reached `origin/main`. Don't wait for PR
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
  only and decide info findings in one pass. Cap review at two rounds; file the rest as issues.
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
just native-sim-health    # once per simulator: grant Health access (a UI test taps the sheet)
just native-run-device    # build under the signing lock, install and launch on the iPhone
just pull-logs            # session logs, reports and crashes from the phone (and the iPad)
just bugs-check           # unfiled reports on every plugged-in device
```

Requires Xcode, an Apple ID signed into Xcode, Developer Mode on the iPhone, and the `just setup` tools
(`native/.swiftlint.yml` pins SwiftLint's version; the tile-art check measures the art with `magick`). The phone's hardware UDID is `DEVICE=<udid>` or the gitignored
`scripts/native/phone-udid.local`: the repo is public, so device ids are never committed. UI tests run with
`xcodebuild … -only-testing:GrabberNativeUITests/<Test> test` ([TESTING.md](docs/TESTING.md)).

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
