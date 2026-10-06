# Context Grabber task runner

# Generate version info from git
generate-version:
    node scripts/generate-version.js

# Deploy OTA update to production channel (used by `just deploy` builds)
ota message="OTA update": generate-version
    #!/usr/bin/env bash
    set -euo pipefail
    # An OTA bundle must match the binary it lands on. Refuse when the native
    # surface changed since the last `just deploy` from this Mac (the marker
    # it leaves), and always when app.json and Expo.plist disagree on the
    # runtime version. See docs/superpowers/specs/2026-09-07-ota-first-architecture-design.md
    scripts/check-runtime-version.sh
    if [ -f .native-build-sha ]; then
      base=$(cat .native-build-sha)
      if ! git diff --quiet "$base" HEAD -- ios modules patches package.json app.json; then
        echo "==> REFUSING: the native surface changed since the last native build ($base):" >&2
        git diff --stat "$base" HEAD -- ios modules patches package.json app.json >&2
        echo "==> Run 'just deploy' (and scripts/bump-runtime-version.sh if you have not) instead." >&2
        exit 1
      fi
    else
      echo "==> NOTE: no record of a native build from this Mac (.native-build-sha); trusting you." >&2
    fi
    CI=1 npx eas-cli update --branch production --message "{{message}}" --environment production --platform ios

# Every host check: jest (unit + component), the type check, the Swift deal check, runtimeVersion agreement
test: generate-version
    npx jest
    npx tsc --noEmit
    just check-deal
    scripts/check-runtime-version.sh
    just native-test

# --- The native app (native/, docs/superpowers/specs/2026-10-04-swift-native-app-design.md) ---

native_sim := env("SIM", "iPhone 17")
# The phone's hardware UDID is DEVICE=<udid>, else the untracked scripts/native/phone-udid.local (the repo is
# public, so it is not committed); scripts/native/phone-udid.sh reads it for the recipes and the scripts.
native_device := `scripts/native/phone-udid.sh 2>/dev/null || true`
native_bundle := "com.idvorkin.grabbernative"
native_sim_app := "native/Build/Build/Products/Debug-iphonesimulator/GrabberNative.app"
native_device_app := "native/Build/Build/Products/Debug-iphoneos/GrabberNative.app"
native_logs := "~/tmp/agent/grabber-logs"

# Native rung 1: ContextCore's host tests on the Mac (seconds)
native-test:
    #!/usr/bin/env bash
    # pipefail: a failing suite must fail the recipe instead of hiding behind tail's exit 0.
    set -uo pipefail
    cd native/ContextCore && swift test 2>&1 | grep -E "Test Suite 'All tests'|Executed|failed|error" | tail -20

# GrabberNative.xcodeproj is generated from native/project.yml and not committed
native-project:
    cd native && xcodegen --quiet

native-build-sim: native-project
    #!/usr/bin/env bash
    # The grep alone would exit 0 on "BUILD FAILED" and let the smoke run install the previous bundle.
    set -uo pipefail
    out=$(xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative \
      -derivedDataPath native/Build -destination "platform=iOS Simulator,id=$(scripts/native/sim-udid.sh "{{native_sim}}")" \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" build 2>&1)
    echo "$out" | grep -E "error:|BUILD"
    echo "$out" | grep -q "BUILD SUCCEEDED"
    # Signed to run locally, not unsigned: HealthKit refuses an app without its entitlement, even on the simulator.

# Once per simulator: grant Health access through Health's own sheet (a UI test taps it; nothing else can) and
# grab the fixture week from the simulator's Health store. sim-smoke.sh then checks the exports.
native-sim-health: native-project
    #!/usr/bin/env bash
    set -uo pipefail
    out=$(xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative \
      -derivedDataPath native/Build -destination "platform=iOS Simulator,id=$(scripts/native/sim-udid.sh "{{native_sim}}")" \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" \
      -only-testing:GrabberNativeUITests/HealthAccessUITests test 2>&1)
    echo "$out" | grep -E "error:|Test Case|TEST (SUCCEEDED|FAILED)"
    echo "$out" | grep -q "TEST SUCCEEDED"

# Native rung 2: the simulator build driven by launch hooks, judged from its session log
native-test-sim: native-build-sim
    bash scripts/native/sim-smoke.sh "{{native_sim}}" {{native_bundle}} {{native_sim_app}}

# Stops a phone recipe with how to name the phone when it has no id
_phone:
    @scripts/native/phone-udid.sh >/dev/null

native-build-device: _phone native-project
    #!/usr/bin/env bash
    set -uo pipefail
    out=$(xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative \
      -derivedDataPath native/Build -destination "platform=iOS,id={{native_device}}" \
      -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
      GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" build 2>&1)
    echo "$out" | grep -E "error:|BUILD"
    echo "$out" | grep -q "BUILD SUCCEEDED"

# Native rung 3: build, install and launch Grabber Native on the iPhone (a locked phone fails the launch only)
native-run-device: native-build-device
    xcrun devicectl device install app --device {{native_device}} {{native_device_app}}
    xcrun devicectl device process launch --device {{native_device}} {{native_bundle}}

# Copy the native app's session logs, bug reports and crash files from the iPhone to ~/tmp/agent/grabber-logs
pull-logs: _phone
    mkdir -p {{native_logs}}
    xcrun devicectl device copy from --device {{native_device}} --domain-type appDataContainer \
      --domain-identifier {{native_bundle}} --source Documents/logs --destination {{native_logs}}/logs
    xcrun devicectl device copy from --device {{native_device}} --domain-type appDataContainer \
      --domain-identifier {{native_bundle}} --source Documents/bugs.jsonl --destination {{native_logs}}/bugs.jsonl || true
    xcrun devicectl device copy from --device {{native_device}} --domain-type appDataContainer \
      --domain-identifier {{native_bundle}} --source Documents/bugs --destination {{native_logs}}/bugs || true
    xcrun devicectl device copy from --device {{native_device}} --domain-type appDataContainer \
      --domain-identifier {{native_bundle}} --source Documents/crashes --destination {{native_logs}}/crashes || true
    \ls -t {{native_logs}}/logs | head -5
    @echo "--- bug reports (newest last); each names its log file:"
    @tail -5 {{native_logs}}/bugs.jsonl 2>/dev/null | jq -c '{reported_at, note, log, screen}' || true

# The same from the simulator
pull-logs-sim:
    mkdir -p {{native_logs}}/sim
    cp -Rf "$(xcrun simctl get_app_container "$(scripts/native/sim-udid.sh "{{native_sim}}")" {{native_bundle}} data)/Documents/." {{native_logs}}/sim/
    \ls -t {{native_logs}}/sim/logs | head -5

# Print a session log, one event per line
log-summary file:
    @jq -c . {{file}}

# Quick check for unfiled bug reports on the phone (exit 1 when there are any)
bugs-check: _phone
    scripts/native/bugs-check.sh {{native_device}}

# File each new shake report from the pulled bugs.jsonl as a GitHub issue (skips ones already filed)
file-bugs:
    scripts/native/file-bugs.sh

# Resolve a MetricKit crash JSON's addresses with the last device build's dSYM
symbolicate file:
    scripts/native/symbolicate.sh {{file}}

# --- The React Native app ---

# Re-render the Gym Timer's spoken cues (macOS `say`) and compose the cue files
timer-cues:
    scripts/make-timer-words.sh

# The memdeck deal's promises (no repeats, one of each per run, taps always change the card), under plain swiftc
check-deal:
    #!/usr/bin/env bash
    set -euo pipefail
    out=$(mktemp -d)
    xcrun swiftc -O -module-name carddeal ios/LiveActivity/PlayingCard.swift scripts/card-deal-check/main.swift -o "$out/check"
    "$out/check"

# Build release and deploy to physical iPhone (supports OTA updates)
# NOTE: ios/ is committed to git. Do NOT run `expo prebuild` here — it wipes
# DEVELOPMENT_TEAM from pbxproj and breaks expo-live-activity. Use
# `just resync-native` if you need to apply app.json changes to the native project.
deploy device="Igor iPhone 17" udid="856A38BD-04D3-5D27-8485-E09FEF892783": generate-version
    #!/usr/bin/env bash
    set -euo pipefail
    # Always run pod install (~10s when nothing changed). Diffing
    # Podfile.lock against Pods/Manifest.lock is not enough: a PR that adds a
    # native module without re-running pod install (react-native-webview in
    # #66) leaves both files equally stale, the check passes, and the app
    # red-screens at runtime with a missing native view manager.
    echo "==> Installing pods..."
    (cd ios && PATH="/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH" pod install)
    if ! git diff --quiet -- ios/Podfile.lock; then
      echo "==> NOTE: pod install changed ios/Podfile.lock — commit it so the next clone builds correctly."
    fi
    scripts/check-runtime-version.sh
    echo "==> Building release..."
    DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
    xcodebuild -workspace ios/ContextGrabber.xcworkspace \
        -configuration Release \
        -scheme ContextGrabber \
        -destination "platform=iOS,name={{device}}" \
        -allowProvisioningUpdates
    echo "==> Installing on {{device}}..."
    APP=$(find "$DERIVED_DATA" -path "*/ContextGrabber-*/Build/Products/Release-iphoneos/ContextGrabber.app" -maxdepth 5 | head -1)
    xcrun devicectl device install app --device "{{udid}}" "$APP"
    # What the phone now carries, for `just ota`'s native-surface check.
    git rev-parse HEAD > .native-build-sha

# Re-sync native iOS project from app.json after plugin/config changes.
# Destructive: wipes ios/, re-runs prebuild cleanly, reinstalls Pods.
# After running, re-apply DEVELOPMENT_TEAM in Xcode Signing UI for both
# ContextGrabber and LiveActivity targets, then commit ios/ changes.
resync-native:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Cleaning and regenerating ios/ from app.json..."
    rm -rf ios
    npx expo prebuild --platform ios --clean
    echo "==> Installing pods..."
    (cd ios && PATH="/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH" pod install)
    echo "==> Done. Set DEVELOPMENT_TEAM for ContextGrabber + LiveActivity in Xcode, then commit ios/."

# Build debug for development (connects to Metro dev server, no OTA)
build device="Igor iPhone 17": generate-version
    npx expo run:ios --device "{{device}}"

# Start Metro dev server
dev: generate-version
    npx expo start --dev-client

# Install dependencies and pods (first-time clone or after resync-native)
setup:
    npm install
    cd ios && pod install
