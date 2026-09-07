#!/usr/bin/env bash
# app.json and Expo.plist must name the same OTA runtime version (CLAUDE.md).
set -euo pipefail
cd "$(dirname "$0")/.."
a=$(python3 -c 'import json; print(json.load(open("app.json"))["expo"]["runtimeVersion"])')
p=$(python3 -c 'import re; print(re.search(r"<key>EXUpdatesRuntimeVersion</key>\s*<string>([^<]*)</string>", open("ios/ContextGrabber/Supporting/Expo.plist").read()).group(1))')
if [ "$a" != "$p" ]; then
  echo "==> runtimeVersion disagrees: app.json '$a' vs Expo.plist '$p' — run scripts/bump-runtime-version.sh" >&2
  exit 1
fi
echo "==> runtimeVersion $a (app.json and Expo.plist agree)"
