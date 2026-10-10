#!/usr/bin/env bash
# Copies Grabber Native's session logs, bug reports (with their screenshots) and crash files from each of Igor's
# devices (scripts/native/devices.sh: the phone and the iPad) to ~/tmp/agent/grabber-logs/<phone|ipad>/.
# A device that is not reachable is said and skipped.
set -uo pipefail
BUNDLE=com.idvorkin.grabbernative
ROOT=$HOME/tmp/agent/grabber-logs
"$(dirname "$0")/devices.sh" | while read -r name udid; do
  out="$ROOT/$name"
  mkdir -p "$out"
  copy() { xcrun devicectl device copy from --device "$udid" --domain-type appDataContainer \
    --domain-identifier "$BUNDLE" --source "Documents/$1" --destination "$out/$1" >/dev/null 2>&1; }
  if ! copy logs; then echo "== $name: not reachable"; continue; fi
  copy bugs.jsonl; copy bugs; copy crashes  # absent until a report or a crash happens
  echo "== $name: $(\ls "$out/logs" 2>/dev/null | wc -l | tr -d ' ') logs in $out"
  tail -3 "$out/bugs.jsonl" 2>/dev/null | jq -c '{reported_at, note: (.note[0:70]), log, screen}' || true
done
