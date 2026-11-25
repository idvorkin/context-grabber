#!/usr/bin/env bash
# Story 980: makes this simulator the booted one for its build lane, booting it only if it isn't up, and leaves it
# booted afterwards for the lane's next run: an iOS 27 boot writes about 300 MB of wallpaper snapshots that are never
# evicted, and spikes the CPU. One booted simulator takes about 10 GB, so no more stay booted than the Mac has build
# lanes (story 985, #954; scripts/native/build-lane.sh). On a one-lane Mac every other booted simulator is shut down
# first, as before lanes. With more lanes: the lane's other device and any idle simulator of no lane are shut down, a
# busy lane's simulator never is (a name of no lane counts as lane 1's), and an idle lane's only to keep the booted
# count at or under the lane count.
# For a lane's simulator, run it inside the owning lane (build-lane.sh run).
# Bead context-grabber-wm8y: it boots on a locked Mac too. Only a test that opens the mic crashes on one, and the test
# run's wrapper skips those (scripts/native/mic-tests.txt).
# Usage: sim-boot.sh <simulator name or udid>
set -uo pipefail
here=$(dirname "$0")
udid=$("$here/sim-udid.sh" "${1:?simulator name or udid}") || exit
# Story 1517: a lane's simulator can be booted only from its owning lane (exit 64 otherwise).
# shellcheck source=scripts/native/sim-lane.sh
. "$here/sim-lane.sh"
sim_lane_guard "$udid" "sim-boot" || exit
lanes=$("$here/build-lane.sh" count)
if [ "$lanes" -le 1 ]; then
  xcrun simctl list devices booted | grep -oE '\(([0-9A-F-]{36})\) \(Booted\)' | grep -oE '[0-9A-F-]{36}' |
    while IFS= read -r other; do
      [ "$other" = "$udid" ] || xcrun simctl shutdown "$other" 2>/dev/null
    done
else
  own=${BUILD_LANE:-}  # unset: a run outside any lane, which owns none of them
  phone=${SIM:-iPhone 17} pad=${WHITEBOARD_SIM:-iPad Pro 11-inch (M5)}
  laned='^(.+) lane ([0-9]+)$'
  idle=() busy=0
  while IFS=' ' read -r other name; do
    [ -n "$other" ] && [ "$other" != "$udid" ] || continue
    base=$name lane=1
    if [[ $name =~ $laned ]]; then base=${BASH_REMATCH[1]} lane=${BASH_REMATCH[2]}; fi
    if [ "$base" != "$phone" ] && [ "$base" != "$pad" ]; then foreign=1; else foreign=; fi
    if [ "$lane" = "$own" ]; then
      [ -z "$foreign" ] || echo "sim-boot: shutting down '$name', which belongs to no build lane"
      xcrun simctl shutdown "$other" 2>/dev/null  # this lane's other device
    elif "$here/build-lane.sh" busy "$lane"; then
      busy=$((busy + 1))
      echo "sim-boot: leaving '$name' booted: build lane $lane is busy"
    elif [ -n "$foreign" ]; then
      if lockf -k -t 0 "$("$here/build-lane.sh" lock "$lane")" xcrun simctl shutdown "$other" 2>/dev/null; then
        echo "sim-boot: shut down '$name', which belongs to no build lane"
      else
        busy=$((busy + 1))
      fi
    else
      idle+=("$lane $other $name")
    fi
  done < <(xcrun simctl list devices booted | sed -nE 's/^ +(.+) \(([0-9A-F-]{36})\) \(Booted\).*$/\2 \1/p')
  # Idle lanes keep theirs booted for their next run while there is room: this one, the busy ones and the idle ones
  # within the lane count. Each shutdown holds that lane's lock, so a job starting there meanwhile keeps its simulator.
  over=$((1 + busy + ${#idle[@]} - lanes))
  for entry in ${idle[@]+"${idle[@]}"}; do
    [ "$over" -gt 0 ] || break
    read -r lane other name <<<"$entry"
    if lockf -k -t 0 "$("$here/build-lane.sh" lock "$lane")" xcrun simctl shutdown "$other" 2>/dev/null; then
      echo "sim-boot: shut down '$name' (build lane $lane is idle) to keep no more than $lanes booted"
      over=$((over - 1))
    fi
  done
fi
# Story 984: a boot grows the wallpaper snapshots by about 300 MB and nothing evicts them, so the shut-down simulators'
# are pruned first, the target among them while it is still shut down. A failed prune never stops the boot.
xcrun simctl list devices booted | grep -qF "($udid)" || "$here/sim-poster-prune.sh" || true
# -b boots it only if it isn't booted, and returns at once if it is; a bare bootstatus after a failed boot waits forever.
xcrun simctl bootstatus "$udid" -b >/dev/null || { echo "the simulator $udid did not boot" >&2; exit 1; }
# Story 1627: the lane's simulator runs slim (simslim, when it's installed; a no-op otherwise). Only a simulator that
# isn't slim yet is changed, and that reboots it once; sim-slim.sh waits for it to be booted again, and fails only if
# it isn't.
"$here/sim-slim.sh" "$udid" || exit 1
