# Context Grabber task runner

# Generate version info from git
generate-version:
    node scripts/generate-version.js

# Deploy OTA update to production channel (used by `just deploy` builds)
ota message="OTA update": generate-version
    CI=1 npx eas-cli update --branch production --message "{{message}}" --environment production --platform ios

# Run tests
test:
    npx jest

# Build release and deploy to physical iPhone (supports OTA updates)
# NOTE: ios/ is committed to git. Do NOT run `expo prebuild` here — it wipes
# DEVELOPMENT_TEAM from pbxproj and breaks expo-live-activity. Use
# `just resync-native` if you need to apply app.json changes to the native project.
deploy device="Igor iPhone 17" udid="856A38BD-04D3-5D27-8485-E09FEF892783": generate-version
    #!/usr/bin/env bash
    set -euo pipefail
    # Pods are stale when they're absent OR when Podfile.lock has moved on
    # from the installed Pods/Manifest.lock — which is what happens after a
    # new native module lands in package.json (e.g. react-native-webview).
    # Without this check the build succeeds and the app red-screens at
    # runtime with a missing native view manager.
    #
    # A LOCAL module (modules/<name>/) does not move Podfile.lock at all until
    # pod install runs, so the diff above cannot see it. Check each local
    # podspec against the installed manifest by name instead — otherwise the
    # build succeeds and the module is silently absent at runtime.
    pods_stale=""
    if [ ! -d ios/Pods ] || ! diff -q ios/Podfile.lock ios/Pods/Manifest.lock >/dev/null 2>&1; then
      pods_stale="Podfile.lock moved"
    else
      for spec in modules/*/ios/*.podspec; do
        [ -e "$spec" ] || continue
        pod_name=$(basename "$spec" .podspec)
        if ! grep -q " ${pod_name} (" ios/Pods/Manifest.lock 2>/dev/null; then
          pods_stale="local module ${pod_name} not installed"
        fi
      done
    fi
    if [ -n "$pods_stale" ]; then
      echo "==> Pods out of date (${pods_stale}) — running pod install..."
      (cd ios && PATH="/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH" pod install)
    fi
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
