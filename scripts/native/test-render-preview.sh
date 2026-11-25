#!/usr/bin/env bash
# Story 1625 (bead context-grabber-7xme): render-preview.sh names the file the way Xcode's project does, asks for the
# iPad, and refuses a file that isn't there, without Xcode (PREVIEW_DRY_RUN prints the JSON-RPC it would send).
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
script="$here/scripts/native/render-preview.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# field <json lines> <line number> <dotted path>: that line's value at the path, parsed as JSON
field() {
  printf '%s\n' "$1" | python3 -I -c '
import json, sys
value = json.loads(sys.stdin.read().splitlines()[int(sys.argv[1]) - 1])
for key in sys.argv[2].split("."):
    value = value[key]
print(value)' "$2" "$3"
}

out=$(PREVIEW_DRY_RUN=1 "$script" App/Breathe/BreatheView.swift)
check "four requests" '[ "$(printf "%s\n" "$out" | wc -l | tr -d " ")" = 4 ]'
check "opens the project, then renders" '[ "$(field "$out" 3 params.name)" = XcodeOpenWorkspace ] && [ "$(field "$out" 4 params.name)" = RenderPreview ]'
check "source path is the project's" '[ "$(field "$out" 4 params.arguments.sourceFilePath)" = GrabberNative/App/Breathe/BreatheView.swift ]'
check "iPad by default" '[ "$(field "$out" 4 params.arguments.preferredRenderDestination.deviceModelName)" = "iPad Pro 11-inch (M5)" ]'
check "first preview by default" '[ "$(field "$out" 4 params.arguments.previewDefinitionIndexInFile)" = 0 ]'
check "opens the checkout's project" '[ "$(field "$out" 3 params.arguments.path)" = "$here/native/GrabberNative.xcodeproj" ]'

out=$(PREVIEW_DRY_RUN=1 PREVIEW_DEVICE="iPad Pro 13-inch (M5)" "$script" "$here/native/App/Breathe/BreatheView.swift" /tmp/x.png 2)
check "absolute path" '[ "$(field "$out" 4 params.arguments.sourceFilePath)" = GrabberNative/App/Breathe/BreatheView.swift ]'
check "index from the argument" '[ "$(field "$out" 4 params.arguments.previewDefinitionIndexInFile)" = 2 ]'
check "device from the environment" '[ "$(field "$out" 4 params.arguments.preferredRenderDestination.deviceModelName)" = "iPad Pro 13-inch (M5)" ]'

out=$(PREVIEW_DRY_RUN=1 "$script" native/App/Breathe/BreatheView.swift)
check "native/ prefix accepted" '[ "$(field "$out" 4 params.arguments.sourceFilePath)" = GrabberNative/App/Breathe/BreatheView.swift ]'

set +e
PREVIEW_DRY_RUN=1 "$script" App/NoSuchView.swift >/dev/null 2>&1
code=$?
set -e
check "missing file exits 2" '[ "$code" = 2 ]'

exit $fail
