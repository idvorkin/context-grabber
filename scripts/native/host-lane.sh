#!/usr/bin/env bash
# Stories 795, 797, 798 (context-grabber-mkd0): the host slots. Host builds and tests (swift-format, SwiftLint, ContextCore's
# swift test, the Mac Catalyst xcodebuild) each take one of HOST_LANES slots machine-wide before they start, so twenty
# agents' `just test` runs queue instead of loading 18 cores to 281 (2026-11-22). The count is HOST_LANES, else a
# quarter of the cores, at most four, at least one (four on the 18-core M5 Pro). Slot N's lock is
# ~/tmp/agent/locks/host-N.lock (BUILD_LOCK_DIR, as build-lane.sh). A lock is the kernel's (lockf), so a holder that
# dies, even by kill -9, frees its slot at once and a lock file left behind holds nothing.
# Take a slot at the leaf only, never inside another: a slot holder waiting for a second slot can deadlock. A build
# lane may take a host slot inside it (lane, then slot), never the reverse.
# Usage:
#   host-lane.sh count            the number of host slots on this Mac
#   host-lane.sh lock <slot>      that slot's lock file
#   host-lane.sh busy <slot>      exits 0 when a job holds that slot's lock
#   host-lane.sh run <command…>   runs the command in the first free slot, waiting up to HOST_LANE_WAIT seconds (an hour)
#                                 while every slot is busy, then exit 75; exports HOST_LANE and HOST_LANES
set -uo pipefail
self=$0
# Story 1901: refuse branch work in the main checkout.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/main-checkout-guard.sh"
locks=${BUILD_LOCK_DIR:-$HOME/tmp/agent/locks}

slots() {
  local n cores
  if [ -n "${HOST_LANES:-}" ]; then
    if [[ $HOST_LANES =~ ^[0-9]+$ ]]; then
      n=$((10#$HOST_LANES))
      [ "$n" -ge 1 ] || n=1
      echo "$n"
      return
    fi
    echo "host-lane: HOST_LANES=$HOST_LANES is not a number; counting slots from the cores" >&2
  fi
  cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null) || cores=0
  [[ $cores =~ ^[0-9]+$ ]] || cores=0
  n=$((cores / 4))
  [ "$n" -le 4 ] || n=4
  [ "$n" -ge 1 ] || n=1
  echo "$n"
}

lock() { echo "$locks/host-$1.lock"; }

# Free when the lock can be taken at once (and let go).
free() { lockf -k -t 0 "$(lock "$1")" true 2>/dev/null; }

run() {
  [ $# -gt 0 ] || { echo "host-lane: run needs a command" >&2; exit 2; }
  main_checkout_guard host-lane
  local n wait poll start i status said=
  n=$(slots)
  wait=${HOST_LANE_WAIT:-3600} poll=${HOST_LANE_POLL:-3}
  mkdir -p "$locks"
  export HOST_LANES=$n
  # The command's own exit status can be 75, as lockf's is for a busy lock: the marker says the command ran.
  marker=$(mktemp "${TMPDIR:-/tmp}/host-lane.XXXXXX") || exit 1
  rm -f "$marker"
  trap 'rm -f "$marker"' EXIT
  start=$SECONDS
  while :; do
    for ((i = 1; i <= n; i++)); do
      free "$i" || continue
      HOST_LANE=$i lockf -k -t 0 "$(lock "$i")" "$self" _ran "$marker" "$@"
      status=$?
      [ -e "$marker" ] && exit "$status"
      [ "$status" -eq 75 ] || { echo "host-lane: lockf on host slot $i's lock failed (exit $status)" >&2; exit "$status"; }
    done
    if [ $((SECONDS - start)) -ge "$wait" ]; then
      echo "host-lane: all $n host slots were still busy after $((SECONDS - start))s; nothing started" >&2
      exit 75
    fi
    [ -n "$said" ] || { echo "host-lane: all $n host slots are busy: waiting for a host slot (up to ${wait}s)" >&2; said=1; }
    sleep "$poll"
  done
}

ran() {  # <marker> <command…>: inside the slot's lock
  : >"$1"
  shift
    exec "$@"
}

case ${1:-} in
  count) slots ;;
  lock) lock "${2:?a slot}" ;;
  busy) ! free "${2:?a slot}" ;;
  run) shift; run "$@" ;;
  _ran) shift; ran "$@" ;;
  *) sed -n '/^# Usage/,/^set /p' "$self" | sed -e '$d' -e 's/^# *//' >&2; exit 2 ;;
esac
