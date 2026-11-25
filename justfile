# Context Grabber task runner: Grabber Native, the Swift app under native/
# (docs/superpowers/specs/2026-10-04-swift-native-app-design.md). The React Native app's code was removed 2026-10-17.

# Shared entry points across Igor's native repos: just build, test, install, run.
alias build := native-build-sim
alias run := native-run-mac

# Every host check (the native rungs 0 and 1, the whole tree's layout included)
test: native-test

# The ladder, cheapest rung first, stopping at the first failure (docs/TESTING.md, story 683):
# --dry-run prints the rungs and classes, --full runs the touched areas' suites, --all every UI test class.
test-ladder *args:
    scripts/native/test-ladder.sh {{args}}

# Story 1628: walk the store: every implemented story's named check, run once on this Mac, judged by the
# walk-the-store skill's walk.py (WALK_PY). Writes ~/tmp/agent/walks/context-grabber/<stamp>/report.md (docs/TESTING.md).
walk *args:
    scripts/native/walk.py {{args}}

# Story 1626 (bead context-grabber-3rk): the full ladder once a day on main while the Mac is idle (--dry-run says why
# not). `nightly-install` schedules it every half hour as a LaunchAgent; `nightly-uninstall` removes it.
nightly-ladder *args:
    scripts/native/nightly-ladder.sh {{args}}

nightly-install:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(git rev-parse --absolute-git-dir)" != "$(cd "$(git rev-parse --git-common-dir)" && pwd -P)" ]; then
        echo "nightly: install from the primary checkout, not a worktree (a pool slot changes branch or is pruned)" >&2
        exit 1
    fi
    plist=~/Library/LaunchAgents/com.idvorkin.grabber.nightly-ladder.plist
    mkdir -p ~/tmp/agent/nightly
    cat >"$plist" <<PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>Label</key><string>com.idvorkin.grabber.nightly-ladder</string>
      <key>ProgramArguments</key><array><string>$PWD/scripts/native/nightly-ladder.sh</string></array>
      <key>StartInterval</key><integer>1800</integer>
      <key>StandardOutPath</key><string>$HOME/tmp/agent/nightly/launchd.log</string>
      <key>StandardErrorPath</key><string>$HOME/tmp/agent/nightly/launchd.log</string>
      <key>EnvironmentVariables</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
    </dict></plist>
    PLIST
    launchctl bootout gui/$(id -u) "$plist" 2>/dev/null || true
    launchctl bootstrap gui/$(id -u) "$plist"
    echo "nightly: scheduled every 30 min from $plist (runs only when idle, once a day)"

nightly-uninstall:
    launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.idvorkin.grabber.nightly-ladder.plist 2>/dev/null || true
    rm -f ~/Library/LaunchAgents/com.idvorkin.grabber.nightly-ladder.plist

# New story IDs come from `scripts/native/story-ids.py reserve <journey> [n]` (story 791). This, story 793, runs
# right before `gh pr merge`: the story IDs on the branch as pushed, merged with origin/main as it is now. Story 1519:
# then ContextCore compiled in Release, as an archive compiles it, when the branch changes it (release-check.sh).
pre-merge *branch:
    scripts/native/pre-merge.sh {{branch}}
    scripts/native/release-check.sh {{branch}}

# The pipeline's lint step (.no-mistakes.yaml commands.lint; it runs after review and document, before the push): the
# whole tree's lint, then story 1515's check that no story ID this branch adds is added by another open PR too.
pipeline-lint: native-lint-format native-lint
    scripts/native/story-ids.py claimed

# --- The native app (native/, docs/superpowers/specs/2026-10-04-swift-native-app-design.md) ---

native_sim := env("SIM", "iPhone 17")
# The phone's hardware UDID is DEVICE=<udid>, else the untracked scripts/native/phone-udid.local (the repo is
# public, so it is not committed); scripts/native/phone-udid.sh reads it for the recipes and the scripts.
native_device := `scripts/native/phone-udid.sh 2>/dev/null || true`
native_bundle := "com.idvorkin.grabbernative"
native_sim_app := "native/Build/Build/Products/Debug-iphonesimulator/GrabberNative.app"
native_device_app := "native/Build/Build/Products/Debug-iphoneos/GrabberNative.app"
native_mac_app := "native/Build/Build/Products/Debug-maccatalyst/GrabberNative.app"
native_logs := "~/tmp/agent/grabber-logs"
# BugKit's scripts at the pinned version, as SwiftPM checked them out (tests point it elsewhere).
bugkit_scripts := "native/Build/SourcePackages/checkouts/bug-kit/scripts"

# Every tracked native Swift file: the app, the package (its manifest too), the UI tests, the contract tests, the widgets, the share extension, the Board Lab.
native_swift := "native/App native/ContextCore/Package.swift native/ContextCore/Sources native/ContextCore/Tests native/UITests native/ContractTests native/Widgets native/Shared native/Share native/BoardLab"

# The native app in swift-format's layout (native/.swift-format), in place.
native-format:
    xcrun swift-format format -i --recursive --parallel --configuration native/.swift-format {{native_swift}}

# Fails on any swift-format finding: what native-format would change, or a rule it cannot fix.
native-lint-format:
    scripts/native/host-lane.sh run xcrun swift-format lint --strict --recursive --parallel --configuration native/.swift-format {{native_swift}}

# Fails on any SwiftLint finding (native/.swiftlint.yml: force unwraps, casts, tries and implicitly unwrapped
# optionals, each allowed only under a `swiftlint:disable:next` with its reason).
native-lint:
    #!/usr/bin/env bash
    set -uo pipefail
    command -v swiftlint >/dev/null || { echo "swiftlint is not installed: just setup (or brew install swiftlint)" >&2; exit 1; }
    cd native && ../scripts/native/host-lane.sh run swiftlint lint --strict --quiet

# Native rung 0 on its own: swift-format over the Swift files this branch touched, SwiftLint over the tree.
native-lint-touched:
    scripts/native/test-ladder.sh --rung 0

# What the gate runs: the whole tree's lint, then the host rung.
native-test: native-lint-format native-lint native-test-host

# Native rung 1: ContextCore's host tests on the Mac and the script checks (seconds)
native-test-host:
    #!/usr/bin/env bash
    # pipefail: a failing suite must fail the recipe instead of hiding behind tail's exit 0; -e: so must every script
    # check, not only the last (the ladder's map check failed unseen from story 746 until 2026-11-10).
    set -euo pipefail
    # Stories 795, 797, 798: in one of the host slots, whose waiting line stays outside the filtered pipe.
    scripts/native/host-lane.sh run bash -c "set -o pipefail; cd native/ContextCore && swift test 2>&1 | grep -E \"Test Suite 'All tests'|Executed|failed|error\" | tail -20" || exit 1
    # The device build's signing path, with fakes: BugKit's screen-lock guard and "No Accounts" (bug-kit#53).
    scripts/native/test-signing-guard.sh
    # #279: every breathing clip ends in silence, not on a click.
    scripts/native/test-breath-clips.py
    # #304, #299: every home tile has its drawn art; the strip's poodle and quill are template images.
    scripts/native/test-tile-art.sh
    # Story 683: which rungs and UI test classes a change gets, from the real script's dry run.
    scripts/native/test-ladder-map.sh
    # Story 1626 (bead context-grabber-3rk): the daily full ladder starts only on an idle Mac, once a day.
    scripts/native/test-nightly-ladder.sh
    # Story 785 (#954): the build lanes, their locks and simulators, sim-boot and the xcodebuild wait per lane.
    scripts/native/test-build-lane.sh
    # Stories 1505, 1506 (context-grabber-xmwp): the repo's own rung time limit stops a hang and all it started, exit 124.
    scripts/native/test-time-limit.sh
    # Simulator lane guards, standalone lane selection and Health access (bead context-grabber-w7nl).
    scripts/native/test-sim-lane.sh
    # Stories 795, 797, 798 (context-grabber-mkd0): the host slots, six jobs on four, the wait, a killed holder.
    scripts/native/test-host-lane.sh
    # Story 1627: lane simulators run slim (simslim) once, keeping what the tests use, and never fail the caller.
    scripts/native/test-sim-slim.sh
    # Bead context-grabber-2l07: the lane script tests pass with the caller's SIM and lane settings set.
    scripts/native/test-lane-env.sh
    # Story 1519 (context-grabber-6ocd): pre-merge's Release build of ContextCore runs when the branch changes it, and fails loudly.
    scripts/native/test-release-check.sh
    # The board wasm's sources use no Foundation-only types (NSNumber broke the VM's wasm build, 2026-11-24).
    scripts/native/wasm-essentials-check.sh
    scripts/native/test-wasm-essentials-check.sh
    # Where a UI test run's time went, from a real run's log.
    scripts/native/test-ui-timings.sh
    # #1038 (story 1016): the ladder report keeps a retry, a wrong-device skip and a missing deploy apart, on a fixture.
    scripts/native/test-ladder-report.sh
    # Story 1511 (context-grabber-yfsz): the build a device reports against the last install, and just deploy's ledger.
    scripts/native/test-device-build-check.sh
    # Story 1311 (context-grabber-7xv6): the pen-latency lines read off the pulled logs.
    scripts/native/test-pen-latency.sh
    # Story 1625 (context-grabber-7xme): render-preview names the file as Xcode's project does, without Xcode.
    scripts/native/test-render-preview.sh
    # Story 689: a UI test run gets a time limit per case and one retry of a failed case; a hang after it is stopped.
    # Story 790: the hang stop waits for the result bundle to be written, so failed tests' screenshots survive.
    # Story 783: a run of built tests whose first suite never starts (a dark or locked Mac) is stopped, exit 75.
    scripts/native/test-xcodebuild-log.sh
    # Bead context-grabber-tne1: the wrapper stops only watchdogs still its own, never a reused process number.
    scripts/native/test-own-child.sh
    # Story 827 (#419): the smoke's audio checks are skipped, and said to be, on a locked Mac.
    scripts/native/test-smoke-lock.sh
    # Bead context-grabber-wm8y: every UI test that touches a mic control is listed as opening the mic or not.
    scripts/native/test-mic-tests.sh
    # Stories 814-818: the fake Cockpit's board ops, which the whiteboard UI tests rely on.
    scripts/native/test-fake-cockpit-ops.py
    # Stories 1173, 1174: the Cockpit's recorded board sessions are vendored scrubbed, and the fake Cockpit plays them back.
    scripts/native/test-board-sessions.py
    scripts/native/test-fake-cockpit-session.py
    # Stories 1012, 1013 (#1012): what just testflight refuses before it builds, from its dry run.
    scripts/native/test-testflight.sh
    # Stories 1027-1029 (bead context-grabber-omes): just ota's arguments and dry run; ota-watch's batch rule and post.
    scripts/native/test-ota.sh
    # #943: URL loading on Linux needs FoundationNetworking. Bead cmk: check Apple-only imports against Linux branches,
    # including #if canImport and #if os, on the Mac host rung.
    scripts/native/test-linux-imports.sh
    # Story 789 (#993): every story ID is used once and sits in its journey's ranges in docs/stories/README.md.
    # Stories 791-794: reserve hands out free IDs against main, open PRs and a locked ledger; pre-merge catches a collision.
    scripts/native/test-story-ids.sh
    # Beads t309, lldg: every commit a story links is in this branch's history (no sha left behind by a rebase).
    scripts/native/test-story-commits.sh
    # Story 1624: every test a story's Status names still exists in native/ (or names its other repo).
    scripts/native/test-story-tests.sh
    # Bead wq2j: every board test file is in BoardCoreTests or listed as staying in ContextCoreTests.
    scripts/native/test-board-tests-listed.sh
    # Story 1502 (bead 2b54): docs/TESTING.md's one-a-line lists match the host checks and the suites' classes.
    scripts/native/test-testing-lists.sh

# The board's host tests alone (bead wq2j): builds ChatWireKit, BoardCore and BoardCoreTests, not the rest of ContextCore,
# and runs that bundle. FILTER is a test class or class/test (`just board-test BoardRoomTests`). Mac only (xctest);
# `just native-test` still runs every test, these included.
board-test filter="":
    #!/usr/bin/env bash
    set -euo pipefail
    cd native/ContextCore
    swift build --target BoardCoreTests 2>&1 | grep -E "error|Build complete" | tail -20
    bundle="$(swift build --show-bin-path)/BoardCoreTests.xctest"
    filter=()
    [ -n "{{filter}}" ] && filter=(-XCTest "BoardCoreTests.{{filter}}")
    xcrun xctest ${filter[@]+"${filter[@]}"} "$bundle" 2>&1 | grep -E "error|failed|Executed [0-9]+ tests" | tail -20

# The board's rules as WebAssembly for the Cockpit's web board (story 1503): BoardWasm built for WASI and stripped, to
# native/Build/wasm/BoardWasm.wasm, with its size and sha256. Needs a Swift toolchain with a wasm SDK; the script's
# header lists the settings (LINUX_LIB_DIR and LINUX_SWIFT_BIN as for test-linux).
wasm:
    scripts/native/build-wasm.sh

# Builds the module, then replays the recorded board sessions through it under node (story 1503). Skips, saying so,
# with no wasm SDK.
wasm-test:
    scripts/native/test-board-wasm.sh

# Rung 1L, on a Linux box (scripts/native/test-linux.sh says what it needs): ContextCore's portable tests run on Linux,
# the package and its tests cross-built for macOS, iOS and the simulator with a Darwin Swift SDK, the app's sources
# (App, widgets, share extension, UI tests) compiled for iOS, and the portable script checks.
test-linux:
    scripts/native/test-linux.sh

# GrabberNative.xcodeproj is generated from native/project.yml and not committed. --use-cache skips the generation when
# the spec and the files it names are what the last one saw (XcodeGen's cache, under ~/.xcodegen/cache per spec path),
# so a climb doesn't rewrite an unchanged project and make Xcode plan the build again.
native-project:
    cd native && xcodegen --quiet --use-cache

native-build-sim: native-project
    #!/usr/bin/env bash
    set -uo pipefail
    scripts/native/xcodebuild-log.sh build-sim "BUILD SUCCEEDED" xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative \
      -derivedDataPath native/Build -destination "platform=iOS Simulator,id=$(scripts/native/sim-udid.sh "{{native_sim}}")" \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" BUGKIT_COMMIT="$(git describe --always --dirty --exclude='*')" build
    # Signed to run locally, not unsigned: HealthKit refuses an app without its entitlement, even on the simulator.

# Grant access through the Health sheet so the smoke can check the simulator's HealthKit exports.
native-sim-health:
    #!/usr/bin/env bash
    set -uo pipefail
    . scripts/native/sim-lane.sh
    export SIM="{{ native_sim }}"
    take_lane_one bash "$0" || exit
    just native-project || exit
    scripts/native/sim-boot.sh "{{ native_sim }}" || exit  # the one booted simulator (story 980)
    scripts/native/xcodebuild-log.sh sim-health "TEST SUCCEEDED" xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative \
      -derivedDataPath native/Build -destination "platform=iOS Simulator,id=$(scripts/native/sim-udid.sh "{{ native_sim }}")" \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" BUGKIT_COMMIT="$(git describe --always --dirty --exclude='*')" \
      -only-testing:GrabberNativeUITests/HealthAccessUITests test

# Story 785: every build lane's own iPhone and iPad simulators ("<name> lane N"), copied from lane 1's so they keep its
# Health access and data. A lane makes its own the first time it needs them; this makes them all now, waiting for lane 1
# to be idle (it is shut down to be copied). Nothing to do on a one-lane Mac. `refresh` (story 786, #980) deletes and
# copies again each idle lane's copies, after lane 1 gains Health access or data; `list` (story 788) reports them.
native-sim-lanes *mode:
    scripts/native/build-lane.sh sims {{mode}}

# Native rung 2's smoke: the simulator build driven by launch hooks, judged from its session log. It waits while another
# xcodebuild runs: a simulator run under contention counts as failed.
# Only the features this branch touched (scripts/native/smoke-features.sh), the app silent; SMOKE_ONLY=all for every one.
native-test-sim:
    #!/usr/bin/env bash
    set -euo pipefail
    . scripts/native/sim-lane.sh
    export SIM="{{ native_sim }}"
    take_lane_one bash "$0"
    just native-build-sim
    scripts/native/xcodebuild-idle.sh
    SMOKE_ONLY="${SMOKE_ONLY-$(scripts/native/smoke-features.sh)}" bash scripts/native/sim-smoke.sh "{{ native_sim }}" {{ native_bundle }} {{ native_sim_app }}

# Story 1019 (bead 0u3k): the contract tests on real PaperKit and PencilKit (native/ContractTests), hosted in the app on
# an iPad simulator in a build lane: what the whiteboard relies on the platform doing. Story 1020 (bead 8o93): with the
# touch contracts, a UI test class that touches a bare PaperKit stage. Run it after every Xcode or iOS
# update, and with a change to how the board drives PaperKit. No retry: a contract that fails once has moved.
native-test-contracts: native-project
    #!/usr/bin/env bash
    set -uo pipefail
    # Bead context-grabber-wm8y: no test here opens the mic, so it runs on a locked Mac too (the wrapper skips any that did).
    scripts/native/build-lane.sh run bash -c 'name=$(scripts/native/build-lane.sh sim "${CONTRACT_SIM:-iPad Pro 11-inch (M5)}") && udid=$(scripts/native/sim-udid.sh "$name") && scripts/native/sim-boot.sh "$udid" && UI_TEST_RETRY=0 scripts/native/xcodebuild-log.sh contracts "TEST SUCCEEDED" xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath native/Build -destination "platform=iOS Simulator,id=$udid" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" -only-testing:GrabberNativeContractTests -only-testing:GrabberNativeUITests/PaperKitTouchContractUITests test'

# Stops a phone recipe with how to name the phone when it has no id
_phone:
    @scripts/native/phone-udid.sh >/dev/null

# One signing build at a time on this Mac, across every app and agent: the build waits on the shared lock. Don't wrap
# this recipe in the same lockf yourself; a second lockf on the lock would wait for the first forever.
native-build-device: _phone native-project
    #!/usr/bin/env bash
    set -uo pipefail
    mkdir -p ~/tmp/agent/locks
    # BugKit's screen-lock guard (bug-kit#53, docs/ops/signing.md), from the pinned checkout so it matches the pin: a
    # provisioning build never starts while the Mac is locked, and "No Accounts" fails the build (78) before an install.
    guard="{{bugkit_scripts}}/signing-guard.sh"
    xcodebuild -resolvePackageDependencies -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath native/Build -quiet || exit 1
    [ -x "$guard" ] || { echo "no BugKit signing guard at $guard (BugKit 0.3.3 or later)" >&2; exit 69; }
    scripts/native/xcodebuild-log.sh build-device "BUILD SUCCEEDED" lockf ~/tmp/agent/locks/xcode-signing.lock "$guard" xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative \
      -derivedDataPath native/Build -destination "platform=iOS,id={{native_device}}" \
      -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
      GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" BUGKIT_COMMIT="$(git describe --always --dirty --exclude='*')" build

# Native rung 3: build, install and launch Grabber Native on the iPhone (a locked phone fails the launch only)
native-run-device: native-build-device
    xcrun devicectl device install app --device {{native_device}} {{native_device_app}}
    @# The deploy ledger, once the app is installed: a locked device then fails the launch below, and that still counts.
    @# #1038: the repo's own recorder; the mac-driver one it used was never checked out, so no install was ever recorded.
    @scripts/native/record-deploy.sh "$([ "{{native_device}}" = "$(tr -d '[:space:]' 2>/dev/null <scripts/native/ipad-udid.local)" ] && echo ipad || echo phone)" "$(git rev-parse HEAD)" cable || true
    xcrun devicectl device process launch --device {{native_device}} {{native_bundle}}

# The current commit to TestFlight, beside the cable install (#1012, stories 1011-1013; docs/TESTING.md "TestFlight"):
# a Release archive with the build stamps, signed for App Store distribution, uploaded with the App Store Connect key
# (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, or the ignored scripts/native/testflight.local). --export-only needs no key.
testflight *args: native-project
    scripts/native/testflight.sh {{args}}

# A development build of main over the air (bead context-grabber-omes, stories 1027-1028; docs/DEPLOYING.md): archived as
# testflight --export-only does, exported development-signed, checked that its profile lists the iPad, and copied to
# the Cockpit's /builds as grabber-<sha>.ipa (OTA_HOST, OTA_DIR). --dry-run builds nothing; --check-ipa <ipa> only checks.
[positional-arguments]
ota *args:
    scripts/native/ota.sh "$@"

# Runs just ota after each merge batch (merges, then 10 quiet minutes) and posts the build to Igor's Cockpit thread
# (story 1029, docs/DEPLOYING.md). Runs in the foreground.
[positional-arguments]
ota-watch *args:
    scripts/native/ota-watch.sh "$@"

# Native rung 1.5, the Mac app (#638), with no signing identity: no iCloud, nothing asked of Xcode's account.
native-build-mac: native-project
    #!/usr/bin/env bash
    set -uo pipefail
    scripts/native/host-lane.sh run scripts/native/xcodebuild-log.sh build-mac "BUILD SUCCEEDED" xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative \
      -derivedDataPath native/Build -destination "platform=macOS,variant=Mac Catalyst,arch=arm64" \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGN_ENTITLEMENTS=Mac/AdHoc.entitlements \
      GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" BUGKIT_COMMIT="$(git describe --always --dirty --exclude='*')" build

# Build and open the Mac app. It reaches the real Cockpit unless told: COCKPIT=<url> names chat, the page, the usage strip and
# a call, the stand-in (scripts/native/fake-cockpit.py) or nowhere (https://no-address.invalid). A test launch names one. Its logs are under
# ~/Library/Containers/com.idvorkin.grabbernative/Data/Documents/logs.
native-run-mac: native-build-mac
    #!/usr/bin/env bash
    set -uo pipefail
    c="${COCKPIT:-}"
    open -n ${c:+--env GRABBER_CHAT_URL="$c" --env GRABBER_COCKPIT_URL="$c" --env GRABBER_USAGE_URL="$c"} {{native_mac_app}}

# Larry's board changes replayed on a copy of a board, drawn to a PNG, on the Mac with no simulator, in seconds (#936,
# story 990): the board's own applier and planner. Paths are from where you run it.
#   just board-ops --board <strokes snapshot.json> --ops <batch.json> [--ops ...] [--keep id,id] [--out <prefix>]
# Writes <prefix>.png, <prefix>-before.png, <prefix>.result.json and <prefix>.board.json (docs/TESTING.md).
[no-cd]
board-ops *args:
    swift run --quiet --package-path "{{justfile_directory()}}/native/ContextCore" board-ops-harness {{args}}

# A pulled iPad log's pen touches judged again on the Mac, and written as a host fixture (story 1105): its scratch-outs,
# shape snaps, margin holds and held lifts, each with what the iPad decided and what the Mac decides (docs/TESTING.md).
#   just touch-fixture <log.jsonl> [<log.jsonl> ...] [--board <id>] [--all] [--out <fixture.json>]
# Fixtures go in native/ContextCore/Tests/ContextCoreTests/Fixtures/touches/, where BoardTouchReplayTests holds them.
[no-cd]
[positional-arguments]
touch-fixture *args:
    swift run --quiet --package-path "{{justfile_directory()}}/native/ContextCore" touch-replay "$@"

# Copy the native app's session logs, bug reports (with screenshots) and crash files from the phone and the iPad to
# ~/tmp/agent/grabber-logs/<phone|ipad>/ (the iPad's id: IPAD=<udid> or scripts/native/ipad-udid.local)
pull-logs:
    scripts/native/pull-logs.sh

# Story 1311: the board's Pencil-to-frame latency lines from the pulled logs (just pull-logs first)
pen-latency *args:
    scripts/native/pen-latency.sh {{args}}

# Story 1625: render a SwiftUI #Preview to a PNG through Xcode's headless tool service, no window (docs/TESTING.md)
render-preview file *args:
    scripts/native/render-preview.sh {{file}} {{args}}

# Story 1511: the network install on Igor's paired devices (BugKit's deploy-all; --only ipad|phone), each install in the
# deploys ledger, then the device's next session checked against it (docs/DEPLOYING.md). Agents install through this.
deploy *args:
    scripts/native/deploy.sh {{args}}

# Story 1511: is the build each device last reported (its newest pulled session log) the one we last installed? MATCH,
# MISMATCH (exit 1), NO SESSION YET or UNKNOWN per device. Run just pull-logs first for the latest.
device-build-check *args:
    scripts/native/device-build-check.py {{args}}

# Story 828: how long a change takes, asked to merged to on a device, from GitHub and the deploys ledger (docs/TESTING.md)
lead-times *args:
    scripts/lead-times.py {{args}}

# #1038 (story 1016): each climb of the ladder from its selection to the phone, and the areas ranked by the lane minutes
# a better selection, a fixed flake or a free lane would save (docs/TESTING.md "Where a change's test time goes")
ladder-report *args:
    scripts/native/ladder-report.py {{args}}

# The same from the simulator
pull-logs-sim:
    mkdir -p {{native_logs}}/sim
    cp -Rf "$(xcrun simctl get_app_container "$(scripts/native/sim-udid.sh "{{native_sim}}")" {{native_bundle}} data)/Documents/." {{native_logs}}/sim/
    \ls -t {{native_logs}}/sim/logs | head -5

# Print a session log, one event per line
log-summary file:
    @jq -c . {{file}}

# Quick check for unfiled bug reports on every plugged-in iPhone and iPad (exit 1 when there are any): BugKit's
# pull-reports --check, from the checkout SwiftPM pinned (build once), else ~/gits/bug-kit
bugs-check:
    "$(\ls -d native/Build/SourcePackages/checkouts/bug-kit 2>/dev/null || echo ~/gits/bug-kit)/scripts/pull-reports.sh" --check context-grabber

# Resolve a MetricKit crash JSON's addresses with the last device build's dSYM
symbolicate file:
    scripts/native/symbolicate.sh {{file}}

# Re-render the Gym Timer's spoken cues (ElevenLabs or macOS `say`) and compose the cue files
timer-cues:
    scripts/make-timer-words.sh

# The tools the recipes need, from Homebrew: the native app's lint (native-lint, version pinned in
# native/.swiftlint.yml), the build-log digest (xcbeautify), and ImageMagick for the tile-art check.
setup:
    command -v swiftlint >/dev/null || brew install swiftlint
    command -v xcbeautify >/dev/null || brew install xcbeautify
    command -v magick >/dev/null || brew install imagemagick
    command -v xcodegen >/dev/null || brew install xcodegen
