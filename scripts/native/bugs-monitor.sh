#!/usr/bin/env bash
# Event stream for an agent Monitor: polls the phone's and the iPad's bugs.jsonl through bugs-check.sh and prints
# one line per report that is not yet an issue, each report once. Silent while nothing is new, so the agent is
# woken only when there is something to file (cheaper than a /loop that runs the model every few minutes to look).
# Until bug-kit's listener takes over (its migration checklist, step 5), this is the watcher.
# Usage: scripts/native/bugs-monitor.sh [poll seconds, default 60]
#   BUGS_CHECK=<script> swaps in another check (the self-test below uses it).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
CHECK=${BUGS_CHECK:-$HERE/bugs-check.sh}
EVERY=${1:-60}
ONCE=${BUGS_MONITOR_ONCE:-}
seen=" "
while true; do
  out=$("$CHECK" 2>/dev/null || true)
  # bugs-check's line since PR #241: "new (<device>): <reported_at>  <note>". Keyed on the device and the time.
  while IFS= read -r line; do
    case "$line" in
      "new ("*)
        key=$(awk '{print $2 $3}' <<<"$line")
        case "$seen" in *" $key "*) ;; *) seen="$seen$key "; echo "$line" ;; esac
        ;;
    esac
  done <<<"$out"
  [ -n "$ONCE" ] && [ "$ONCE" -le 1 ] && exit 0
  [ -n "$ONCE" ] && ONCE=$((ONCE - 1))
  sleep "$EVERY"
done
