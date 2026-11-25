#!/usr/bin/env bash
# Bead context-grabber-3rk (Igor approved 2026-11-12): once a day, when the Mac is idle, climb the whole ladder with every
# UI test class (`test-ladder.sh --all`) on a fresh copy of origin/main, so a test the per-change ladder never picks
# still runs daily. A locked screen doesn't stop it: the wrapper skips only the tests that open the mic (bead wm8y).
# Usage: nightly-ladder.sh [--dry-run]   --dry-run says whether it would run and why, and runs nothing.
# It runs only when all hold: the hour is inside the window, the Mac is on AC power, the 1-minute CPU average is under
# the ceiling, no build lane is held, and it hasn't already run today. Otherwise it says why and exits 0.
# Environment (defaults in brackets), the last five to stand in for the Mac in the self-test:
#   NIGHTLY_HOME [~/tmp/agent/nightly]      the checkout, the day's log, the ran-today marker, a failure's summary
#   NIGHTLY_WINDOW [1-6]                    the local hours it may start in, first-last inclusive
#   NIGHTLY_CPU_MAX [30]                    the busiest 1-minute CPU average (percent) it starts under
#   NIGHTLY_LADDER [<checkout>/scripts/native/test-ladder.sh --all]   what it runs in the checkout
#   NIGHTLY_HOUR, NIGHTLY_POWER (ac|battery), NIGHTLY_CPU, NIGHTLY_BUSY (lanes held), NIGHTLY_TODAY (YYYY-MM-DD)
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
dry=0
[ "${1:-}" = "--dry-run" ] && dry=1

home=${NIGHTLY_HOME:-$HOME/tmp/agent/nightly}
window=${NIGHTLY_WINDOW:-1-6}
cpu_max=${NIGHTLY_CPU_MAX:-30}
today=${NIGHTLY_TODAY:-$(date +%F)}
hour=${NIGHTLY_HOUR:-$(date +%H)}
hour=$((10#$hour))

power=${NIGHTLY_POWER:-}
if [ -z "$power" ]; then
  if pmset -g batt 2>/dev/null | grep -q "AC Power"; then power=ac; else power=battery; fi
fi
cpu=${NIGHTLY_CPU:-}
if [ -z "$cpu" ]; then
  cpu=$(/usr/bin/top -l 7 -n 0 -s 10 2>/dev/null | grep 'CPU usage' | tail -6 |
    awk '{gsub("%","",$7); s+=100-$7} END{if (NR) print int(s/NR); else print 100}')
fi
busy=${NIGHTLY_BUSY:-}
if [ -z "$busy" ]; then
  busy=0
  lanes=$("$here/build-lane.sh" count 2>/dev/null || echo 1)
  for lane in $(seq 1 "$lanes"); do
    "$here/build-lane.sh" busy "$lane" 2>/dev/null && busy=$((busy + 1))
  done
fi

why=""
first=${window%-*} last=${window#*-}
if [ "$hour" -lt "$first" ] || [ "$hour" -gt "$last" ]; then why="the hour ($hour) is outside $window"
elif [ "$power" != ac ]; then why="the Mac is on battery"
elif [ "$cpu" -ge "$cpu_max" ]; then why="the CPU is ${cpu}% busy (starts under ${cpu_max}%)"
elif [ "$busy" -gt 0 ]; then why="$busy build lane(s) held"
elif [ -e "$home/ran-$today" ]; then why="already ran on $today"
fi
if [ -n "$why" ]; then
  echo "nightly: not now: $why"
  exit 0
fi
if [ "$dry" -eq 1 ]; then
  echo "nightly: would run the full ladder on origin/main ($today)"
  exit 0
fi

mkdir -p "$home"
touch "$home/ran-$today"
log=$home/$today.log
checkout=$home/checkout
{
  echo "nightly: $today, starting $(date +%T)"
  if [ ! -d "$checkout/.git" ] && [ ! -f "$checkout/.git" ]; then
    git -C "$repo" worktree add --detach "$checkout" origin/main || exit 1
  fi
  git -C "$checkout" fetch -q origin main && git -C "$checkout" checkout -q --detach FETCH_HEAD || exit 1
  echo "nightly: origin/main at $(git -C "$checkout" rev-parse --short HEAD)"
} >>"$log" 2>&1 || { echo "nightly: could not update the checkout; see $log"; exit 1; }

ladder=${NIGHTLY_LADDER:-"$checkout/scripts/native/test-ladder.sh --all"}
(cd "$checkout" && eval "$ladder") >>"$log" 2>&1
status=$?
echo "nightly: finished $(date +%T), exit $status" >>"$log"
if [ "$status" -ne 0 ]; then
  grep -E "FAIL|failed|error:" "$log" | tail -40 >"$home/$today.fail"
  echo "nightly: the full ladder failed (exit $status); the failures are in $home/$today.fail, the run in $log"
  exit "$status"
fi
echo "nightly: the full ladder passed; the run is in $log"
