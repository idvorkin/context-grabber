#!/usr/bin/env bash
# What's new (story 148), made at build time: the native app's last month of `git log` plus the stories'
# summaries, turned into the JSON the app bundles by ContextCore's WhatsNew (compiled here with plain swiftc,
# as `just check-deal` does). Never fails the build: without git history the app gets an empty feed and says
# "nothing new". Usage: scripts/native/whats-new.sh <out.json>   (the Xcode build phase passes the bundle path)
set -uo pipefail
out=${1:?output json path}
repo=$(cd "$(dirname "$0")/../.." && pwd)
work=${DERIVED_FILE_DIR:-${TMPDIR:-/tmp}/grabber-whats-new}
mkdir -p "$work" "$(dirname "$out")"
empty() { echo "whats-new: $1; writing an empty feed" >&2; printf '{"days":[],"generated":""}\n' > "$out"; exit 0; }

core="$repo/native/ContextCore/Sources/ContextCore/WhatsNew.swift"
main="$repo/scripts/native/whats-new/main.swift"
tool="$work/whats-new-tool"
if [ ! -x "$tool" ] || [ "$core" -nt "$tool" ] || [ "$main" -nt "$tool" ]; then
  # A host build: Xcode's environment points SDKROOT and the architectures at the phone or the simulator.
  env -i PATH=/usr/bin:/bin HOME="$HOME" ${DEVELOPER_DIR:+DEVELOPER_DIR="$DEVELOPER_DIR"} \
    xcrun --sdk macosx swiftc -module-name WhatsNewTool -o "$tool" "$core" "$main" >&2 || empty "swiftc failed"
fi
# Unit separators between the fields and a record separator after each commit: a subject or a message can hold
# any other character, newlines included (#246: the message may name the story).
git -C "$repo" log --since=31.days --format='%h%x1f%cI%x1f%s%x1f%b%x1e' -- native > "$work/log.txt" 2>/dev/null \
  || empty "no git history"
"$tool" "$work/log.txt" "$repo/docs/stories" "$out" || empty "the tool failed"
