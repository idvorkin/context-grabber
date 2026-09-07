#!/usr/bin/env bash
# Bump the OTA runtime version — do this with every change to the native
# surface (ios/, modules/, patches/, a new pod, app.json plugins), so an
# over-the-air bundle can only ever land on a binary built for it. The two
# files must agree (CLAUDE.md: a literal string, in both); `just deploy`
# refuses when they do not.
#
#   scripts/bump-runtime-version.sh            # today's date, YYYY.MM.DD
#   scripts/bump-runtime-version.sh 2026.09.07
set -euo pipefail
cd "$(dirname "$0")/.."
v=${1:-$(date +%Y.%m.%d)}
python3 - "$v" <<'PY'
import json, pathlib, re, sys
v = sys.argv[1]
app = pathlib.Path("app.json"); s = app.read_text()
s2, n = re.subn(r'"runtimeVersion": "[^"]*"', f'"runtimeVersion": "{v}"', s)
assert n == 1, "app.json: expected one runtimeVersion"
app.write_text(s2)
plist = pathlib.Path("ios/ContextGrabber/Supporting/Expo.plist"); p = plist.read_text()
p2, n = re.subn(r'(<key>EXUpdatesRuntimeVersion</key>\s*<string>)[^<]*(</string>)', rf'\g<1>{v}\g<2>', p)
assert n == 1, "Expo.plist: expected one EXUpdatesRuntimeVersion"
plist.write_text(p2)
print(f"runtimeVersion → {v} (app.json, Expo.plist)")
PY
