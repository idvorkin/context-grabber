#!/usr/bin/env bash
# Story 1625 (bead context-grabber-7xme): render-preview.sh names the file the way Xcode's project does, asks for the
# iPad, and refuses a file that isn't there, without Xcode (PREVIEW_DRY_RUN prints the JSON-RPC it would send).
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
script="$here/scripts/native/render-preview.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

out=$(PREVIEW_DRY_RUN=1 "$script" App/Breathe/BreatheView.swift)
render=$(printf '%s\n' "$out" | tail -1)
check "four requests, render last" '[ "$(printf "%s\n" "$out" | wc -l | tr -d " ")" = 4 ]'
check "source path is the project's" 'printf "%s" "$render" | grep -q "\"sourceFilePath\": \"GrabberNative/App/Breathe/BreatheView.swift\""'
check "iPad by default" 'printf "%s" "$render" | grep -q "\"deviceModelName\": \"iPad Pro 11-inch (M5)\""'
check "first preview by default" 'printf "%s" "$render" | grep -q "\"previewDefinitionIndexInFile\": 0"'
check "opens the checkout's project" 'printf "%s\n" "$out" | sed -n 3p | grep -q "$here/native/GrabberNative.xcodeproj"'

out=$(PREVIEW_DRY_RUN=1 PREVIEW_DEVICE="iPad Pro 13-inch (M5)" "$script" "$here/native/App/Breathe/BreatheView.swift" /tmp/x.png 2 | tail -1)
check "absolute path, index and device" 'printf "%s" "$out" | grep -q "GrabberNative/App/Breathe/BreatheView.swift" && printf "%s" "$out" | grep -q "\"previewDefinitionIndexInFile\": 2" && printf "%s" "$out" | grep -q "13-inch"'

out=$(PREVIEW_DRY_RUN=1 "$script" native/App/Breathe/BreatheView.swift | tail -1)
check "native/ prefix accepted" 'printf "%s" "$out" | grep -q "\"sourceFilePath\": \"GrabberNative/App/Breathe/BreatheView.swift\""'

set +e
PREVIEW_DRY_RUN=1 "$script" App/NoSuchView.swift >/dev/null 2>&1
code=$?
set -e
check "missing file exits 2" '[ "$code" = 2 ]'

exit $fail
