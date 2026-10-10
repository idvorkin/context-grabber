#!/usr/bin/env bash
# Files each shake-to-report bug from the native app's bugs.jsonl as a GitHub issue, once (story 143).
# Each issue body carries a `<!-- bug:<reported_at> -->` marker; reports whose marker already exists are skipped.
# The repo is public and a screenshot can show health, places or the journal, so the picture is never uploaded:
# the issue names where `just pull-logs` left it on this Mac.
# Usage: scripts/native/file-bugs.sh [path/to/<device>/bugs.jsonl ...]   (default: every device's file under
# ~/tmp/agent/grabber-logs/, which `just pull-logs` fills for the phone and the iPad). The folder names the device.
set -euo pipefail
REPO="${REPO:-idvorkin/context-grabber}"
ROOT="$HOME/tmp/agent/grabber-logs"
if [ $# -gt 0 ]; then files=("$@"); else files=("$ROOT"/*/bugs.jsonl); fi

bodies=$(gh issue list -R "$REPO" --state all --limit 1000 --json body --jq '.[].body')
existing=$(grep -o 'bug:[0-9TZ:-]*' <<<"$bodies" || true)

for BUGS in "${files[@]}"; do
[ -f "$BUGS" ] || continue
dir=$(dirname "$BUGS")
case "$(basename "$dir")" in ipad) device=iPad ;; phone) device=phone ;; *) device=$(basename "$dir") ;; esac
while IFS= read -r line; do
  [ -n "$line" ] || continue
  at=$(jq -r '.reported_at' <<<"$line")
  if grep -q "bug:$at" <<<"$existing"; then echo "skip  $at (already filed)"; continue; fi
  note=$(jq -r '.note' <<<"$line")
  title=$(printf '%s\n' "$note" | sed -e 's/^[-* ]*//' | awk 'NF && !found { print; found = 1 }' | cut -c1-80)
  title=${title:-Report from the $device, $at}
  body=$(jq -r --arg device "$device" --arg dir "$dir" '
    "**Report from the " + $device + "** (native app, shake to report), " + .reported_at + "\n\n" +
    "> " + (.note | gsub("\n"; "\n> ")) + "\n\n" +
    "| | |\n|---|---|\n" +
    "| Screen | " + (.screen // "–") + " |\n" +
    "| Build | `" + (.build // "–") + "` |\n" +
    "| Log | `" + (.log // "–") + "` at " + ((.session_t_ms // 0) | tostring) + " ms (pull with `just pull-logs`) |\n" +
    "| Screenshot | " + (if .screenshot then "`" + $dir + "/" + .screenshot + "` on the Mac, not uploaded" else "–" end) + " |\n\n" +
    "<!-- bug:" + .reported_at + " -->"' <<<"$line")
  url=$(gh issue create -R "$REPO" --title "$title" --body "$body" --label bug)
  echo "filed $at ($device) → $url"
  existing+=$'\n'"bug:$at"
done <"$BUGS"
done
