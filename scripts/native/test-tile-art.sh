#!/usr/bin/env bash
# #304, #299: compiles the asset catalog with actool, as the build does, and reads the result with assetutil: every
# home tile has its drawn art, and the strip's poodle and quill are template images (so they take the item's colour).
set -uo pipefail
out=$(mktemp -d "${TMPDIR:-/tmp}/tile-art.XXXXXX")
trap 'rm -rf "$out"' EXIT
xcrun actool native/App/Assets.xcassets --compile "$out" --platform iphoneos --minimum-deployment-target 17.0 \
  --app-icon AppIcon --output-partial-info-plist "$out/p.plist" >/dev/null || { echo "FAIL tile-art: actool"; exit 1; }
xcrun assetutil --info "$out/Assets.car" | python3 -c '
import json, sys
assets = {a["Name"]: a for a in json.load(sys.stdin) if "Name" in a}
# The home tiles, Settings included (HomeRow.all minus the daily strip, plus HomeRow.settings).
tiles = "call today gym_timer breathe places think_a_card exercise_analyzer workout_supermix cockpit eulogy_song eulogy recent random settings".split()
bad = [f"tile-{t}: missing" for t in tiles if f"tile-{t}" not in assets]
for t in tiles:
    a = assets.get(f"tile-{t}")
    if a and (a.get("PixelWidth") != a.get("PixelHeight") or a.get("PixelWidth", 0) < 168):
        w, h = a.get("PixelWidth"), a.get("PixelHeight")
        bad.append(f"tile-{t}: {w}x{h}, not square or under 168 px")
for g in ("strip-poodle", "strip-quill"):
    if assets.get(g, {}).get("Template Mode") != "template":
        bad.append(f"{g}: not a template image")
for b in bad: print("FAIL tile-art:", b)
if not bad: print("ok   tile-art: %d tiles and 2 strip glyphs" % len(tiles))
sys.exit(1 if bad else 0)
'
