#!/usr/bin/env bash
# Files each shake-to-report bug from the native app's bugs.jsonl as a GitHub issue, once (story 143).
# Each issue body carries a `<!-- bug:<reported_at> -->` marker; reports whose marker already exists are skipped.
# The repo is public and a screenshot can show health, places or the journal, so the picture is never uploaded:
# the issue names where `just pull-logs` left it on this Mac.
# Usage: scripts/native/file-bugs.sh [path/to/bugs.jsonl]   (default: ~/tmp/agent/grabber-logs/bugs.jsonl, see `just pull-logs`)
set -euo pipefail
REPO="${REPO:-idvorkin/context-grabber}"
BUGS="${1:-$HOME/tmp/agent/grabber-logs/bugs.jsonl}"
[ -f "$BUGS" ] || { echo "no bug file at $BUGS" >&2; exit 1; }

bodies=$(gh issue list -R "$REPO" --state all --limit 500 --json body --jq '.[].body')
existing=$(grep -o 'bug:[0-9TZ:-]*' <<<"$bodies" || true)

while IFS= read -r line; do
  [ -n "$line" ] || continue
  at=$(jq -r '.reported_at' <<<"$line")
  if grep -q "bug:$at" <<<"$existing"; then echo "skip  $at (already filed)"; continue; fi
  note=$(jq -r '.note' <<<"$line")
  title=$(printf '%s\n' "$note" | sed -e 's/^[-* ]*//' | awk 'NF && !found { print; found = 1 }' | cut -c1-80)
  title=${title:-Report from the phone, $at}
  body=$(jq -r '
    "**Report from the phone** (native app, shake to report), " + .reported_at + "\n\n" +
    "> " + (.note | gsub("\n"; "\n> ")) + "\n\n" +
    "| | |\n|---|---|\n" +
    "| Screen | " + (.screen // "–") + " |\n" +
    "| Build | `" + (.build // "–") + "` |\n" +
    "| Log | `" + (.log // "–") + "` at " + ((.session_t_ms // 0) | tostring) + " ms (pull with `just pull-logs`) |\n" +
    "| Screenshot | " + (if .screenshot then "`~/tmp/agent/grabber-logs/" + .screenshot + "` on the Mac, not uploaded" else "–" end) + " |\n\n" +
    "<!-- bug:" + .reported_at + " -->"' <<<"$line")
  url=$(gh issue create -R "$REPO" --title "$title" --body "$body" --label bug)
  echo "filed $at → $url"
done <"$BUGS"
