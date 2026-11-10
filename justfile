# Context Grabber task runner: Grabber Native, the Swift app under native/
# (docs/superpowers/specs/2026-10-04-swift-native-app-design.md). The React Native app's code was removed 2026-10-17.

# Every host check (the native rungs 0 and 1, the whole tree's layout included)
test: native-test

# The ladder, cheapest rung first, stopping at the first failure (docs/TESTING.md, story 683):
# --dry-run prints the rungs and classes, --full runs the touched areas' suites, --all every UI test class.
test-ladder *args:
    scripts/native/test-ladder.sh {{args}}

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

# Every tracked native Swift file: the app, the package (its manifest too), the UI tests, the widgets, the share extension.
native_swift := "native/App native/ContextCore/Package.swift native/ContextCore/Sources native/ContextCore/Tests native/UITests native/Widgets native/Shared native/Share"

# The native app in swift-format's layout (native/.swift-format), in place.
native-format:
    xcrun swift-format format -i --recursive --parallel --configuration native/.swift-format {{native_swift}}

# Fails on any swift-format finding: what native-format would change, or a rule it cannot fix.
native-lint-format:
    xcrun swift-format lint --strict --recursive --parallel --configuration native/.swift-format {{native_swift}}

# Fails on any SwiftLint finding (native/.swiftlint.yml: force unwraps, casts, tries and implicitly unwrapped
# optionals, each allowed only under a `swiftlint:disable:next` with its reason).
native-lint:
    #!/usr/bin/env bash
    set -uo pipefail
    command -v swiftlint >/dev/null || { echo "swiftlint is not installed: just setup (or brew install swiftlint)" >&2; exit 1; }
    cd native && swiftlint lint --strict --quiet

# Native rung 0 on its own: swift-format over the Swift files this branch touched, SwiftLint over the tree.
native-lint-touched:
    scripts/native/test-ladder.sh --rung 0

# What the gate runs: the whole tree's lint, then the host rung.
native-test: native-lint-format native-lint native-test-host

# Native rung 1: ContextCore's host tests on the Mac and the script checks (seconds)
native-test-host:
    #!/usr/bin/env bash
    # pipefail: a failing suite must fail the recipe instead of hiding behind tail's exit 0.
    set -uo pipefail
    (cd native/ContextCore && swift test 2>&1 | grep -E "Test Suite 'All tests'|Executed|failed|error" | tail -20) || exit 1
    # The device build's signing path, with fakes: BugKit's screen-lock guard and "No Accounts" (bug-kit#53).
    scripts/native/test-signing-guard.sh
    # #279: every breathing clip ends in silence, not on a click.
    scripts/native/test-breath-clips.py
    # #304, #299: every home tile has its drawn art; the strip's poodle and quill are template images.
    scripts/native/test-tile-art.sh
    # Story 683: which rungs and UI test classes a change gets, from the real script's dry run.
    scripts/native/test-ladder-map.sh
    # Where a UI test run's time went, from a real run's log.
    scripts/native/test-ui-timings.sh

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

# Once per simulator: grant Health access through Health's own sheet (a UI test taps it; nothing else can) and
# grab the fixture week from the simulator's Health store. sim-smoke.sh then checks the exports.
native-sim-health: native-project
    #!/usr/bin/env bash
    set -uo pipefail
    scripts/native/xcodebuild-log.sh sim-health "TEST SUCCEEDED" xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative \
      -derivedDataPath native/Build -destination "platform=iOS Simulator,id=$(scripts/native/sim-udid.sh "{{native_sim}}")" \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" BUGKIT_COMMIT="$(git describe --always --dirty --exclude='*')" \
      -only-testing:GrabberNativeUITests/HealthAccessUITests test

# Native rung 2's smoke: the simulator build driven by launch hooks, judged from its session log. It waits while another
# xcodebuild runs: a simulator run under contention counts as failed.
# Only the features this branch touched (scripts/native/smoke-features.sh), the app silent; SMOKE_ONLY=all for every one.
native-test-sim: native-build-sim
    scripts/native/xcodebuild-idle.sh && SMOKE_ONLY="${SMOKE_ONLY-$(scripts/native/smoke-features.sh)}" bash scripts/native/sim-smoke.sh "{{native_sim}}" {{native_bundle}} {{native_sim_app}}

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
    xcrun devicectl device process launch --device {{native_device}} {{native_bundle}}

# Native rung 1.5, the Mac app (#638), with no signing identity: no iCloud, nothing asked of Xcode's account.
native-build-mac: native-project
    #!/usr/bin/env bash
    set -uo pipefail
    scripts/native/xcodebuild-log.sh build-mac "BUILD SUCCEEDED" xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative \
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

# Copy the native app's session logs, bug reports (with screenshots) and crash files from the phone and the iPad to
# ~/tmp/agent/grabber-logs/<phone|ipad>/ (the iPad's id: IPAD=<udid> or scripts/native/ipad-udid.local)
pull-logs:
    scripts/native/pull-logs.sh

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
