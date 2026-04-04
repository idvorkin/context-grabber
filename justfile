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
# Runs prebuild to sync app.json -> native config, then builds and installs.
# Uses platform+name destination (works over Wi-Fi, not just USB).
deploy device="Igor iPhone 17" udid="00008150-000A31D10CF2401C": generate-version
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> Syncing native config from app.json..."
    npx expo prebuild --platform ios
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

# Build debug for development (connects to Metro dev server, no OTA)
build device="Igor iPhone 17": generate-version
    npx expo run:ios --device "{{device}}"

# Start Metro dev server
dev: generate-version
    npx expo start --dev-client

# Install dependencies and pods
setup:
    npm install
    npx expo prebuild --platform ios
    cd ios && pod install
