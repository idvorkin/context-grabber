#!/usr/bin/env bash
# Files each shake-to-report bug from the native app's bugs.jsonl as a GitHub issue, once (story 143).
# Each issue body carries a `<!-- bug:<reported_at> -->` marker; reports whose marker already exists are skipped.
# A report's screenshot (Documents/bugs/<stamp>/, pulled next to bugs.jsonl) is hosted on a gist by
# scripts/native/gist-images.sh and embedded in the issue.
# Usage: scripts/native/file-bugs.sh [path/to/bugs.jsonl]   (default: ~/tmp/agent/grabber-logs/bugs.jsonl, see `just pull-logs`)
set -euo pipefail
REPO="${REPO:-idvorkin/context-grabber}"
BUGS="${1:-$HOME/tmp/agent/grabber-logs/bugs.jsonl}"
[ -f "$BUGS" ] || { echo "no bug file at $BUGS" >&2; exit 1; }
PULLED=$(dirname "$BUGS")
HERE=$(cd "$(dirname "$0")" && pwd)

existing=$(gh issue list -R "$REPO" --state all --limit 500 --json body --jq '.[].body' | grep -o 'bug:[0-9TZ:-]*' || true)

while IFS= read -r line; do
  [ -n "$line" ] || continue
  at=$(jq -r '.reported_at' <<<"$line")
  if grep -q "bug:$at" <<<"$existing"; then echo "skip  $at (already filed)"; continue; fi
  note=$(jq -r '.note' <<<"$line")
  title=$(printf '%s' "$note" | sed -e 's/^[-* ]*//' | head -1 | cut -c1-80)
  body=$(jq -r '
    "**Report from the phone** (native app, shake to report), " + .reported_at + "\n\n" +
    "> " + (.note | gsub("\n"; "\n> ")) + "\n\n" +
    "| | |\n|---|---|\n" +
    "| Screen | " + (.screen // "–") + " |\n" +
    "| Build | `" + (.build // "–") + "` |\n" +
    "| Log | `" + (.log // "–") + "` at " + ((.session_t_ms // 0) | tostring) + " ms (pull with `just pull-logs`) |\n\n" +
    "<!-- bug:" + .reported_at + " -->"' <<<"$line")
  rel=$(jq -r '.screenshot // empty' <<<"$line")
  if [ -n "$rel" ] && [ -f "$PULLED/$rel" ]; then
    url=$("$HERE/gist-images.sh" "context-grabber bug $at" "$PULLED/$rel")
    body="$body"$'\n\n'"**What the screen showed:**"$'\n\n'"![screen.png]($url)"
  fi
  url=$(gh issue create -R "$REPO" --title "$title" --body "$body" --label bug)
  echo "filed $at → $url"
done <"$BUGS"
