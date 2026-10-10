#!/usr/bin/env bash
# Quick check: copies only bugs.jsonl from each device (the phone and the iPad, scripts/native/devices.sh) and
# lists the reports not yet filed as issues. Exit 1 when there are new reports, 0 when clean.
set -euo pipefail
REPO=${REPO:-idvorkin/context-grabber}
ROOT=$HOME/tmp/agent/grabber-logs
bodies=$(gh issue list -R "$REPO" --state all --limit 1000 --json body --jq '.[].body')
filed=$(grep -o 'bug:[0-9TZ:-]*' <<<"$bodies" || true)
new=0
while read -r name udid; do
  out="$ROOT/$name/bugs.jsonl"
  mkdir -p "$(dirname "$out")"
  if ! xcrun devicectl device copy from --device "$udid" --domain-type appDataContainer \
    --domain-identifier com.idvorkin.grabbernative --source Documents/bugs.jsonl --destination "$out" >/dev/null 2>&1; then
    echo "$name not reachable"; continue
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    at=$(jq -r '.reported_at' <<<"$line")
    grep -q "bug:$at" <<<"$filed" || { new=$((new + 1)); echo "new ($name): $at  $(jq -r '.note' <<<"$line" | awk 'NF && !found { print; found = 1 }' | cut -c1-90)"; }
  done <"$out"
done < <("$(dirname "$0")/devices.sh")
if [ "$new" -gt 0 ]; then echo "$new new bug report(s): run just pull-logs && just file-bugs"; exit 1; fi
echo "no new bug reports"
