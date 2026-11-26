#!/usr/bin/env bash
# Story 785 (#954): the build lanes. The Mac and simulator rungs run one job per lane, and the Mac has as many lanes as
# its memory holds: BUILD_LANES, else one per 12 GB (one booted simulator takes about 10 GB), at most four, at least one.
# Four on the 48 GB M5 Pro, one on a 16 GB Mac, where everything is one job at a time exactly as before lanes. Lane 1's
# lock is ~/tmp/agent/locks/build.lock, the one older checkouts take, so they still exclude lane 1; lane N's is
# build-N.lock. Each lane has its own simulators (story 980): lane 1's are the named ones, lane N's "<name> lane N".
# Usage:
#   build-lane.sh count            the number of lanes on this Mac
#   build-lane.sh lock <lane>      that lane's lock file
#   build-lane.sh busy <lane>      exits 0 when another job holds that lane's lock
#   build-lane.sh run <command…>   runs the command in the first free lane, waiting up to BUILD_LANE_WAIT seconds
#                                  (an hour) while every lane is busy, then exit 75; exports BUILD_LANE, BUILD_LANES and
#                                  BUILD_LANE_PORT_OFFSET (ten per lane, for the fake servers' ports)
#   build-lane.sh sim <name>       the simulator name for this job's lane ($BUILD_LANE), made once for a lane past 1
#   build-lane.sh sims             makes every lane's iPhone and iPad simulators now (`just native-sim-lanes`)
#   build-lane.sh sims refresh     story 786 (#980): lane by lane, under that lane's lock and lane 1's, deletes each lane's
#                                  copies and copies lane 1's again; a busy lane (or a busy lane 1) is skipped, named,
#                                  and the exit is 75. Waits BUILD_LANE_REFRESH_WAIT seconds (none) for a lock
#   build-lane.sh sims list        story 788: each lane's copies, their ids and states, or missing; changes nothing
set -uo pipefail
self=$0
# Story 1901: refuse branch work in the main checkout.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/main-checkout-guard.sh"
here=$(dirname "$0")
locks=${BUILD_LOCK_DIR:-$HOME/tmp/agent/locks}

lanes() {
  local n mem
  if [ -n "${BUILD_LANES:-}" ]; then
    if [[ $BUILD_LANES =~ ^[0-9]+$ ]]; then
      n=$((10#$BUILD_LANES))
      [ "$n" -ge 1 ] || n=1
      echo "$n"
      return
    fi
    echo "build-lane: BUILD_LANES=$BUILD_LANES is not a number; counting lanes from the memory" >&2
  fi
  mem=$(sysctl -n hw.memsize 2>/dev/null) || mem=0
  [[ $mem =~ ^[0-9]+$ ]] || mem=0
  n=$((mem / 1073741824 / 12))
  [ "$n" -le 4 ] || n=4
  [ "$n" -ge 1 ] || n=1
  echo "$n"
}

lock() {  # <lane>
  if [ "$1" -le 1 ]; then echo "$locks/build.lock"; else echo "$locks/build-$1.lock"; fi
}

# Free when the lock can be taken at once (and let go). Anything but a clean take counts as busy, so a failed probe
# never lets a job shut down another's simulator.
free() { lockf -k -t 0 "$(lock "$1")" true 2>/dev/null; }

run() {
  [ $# -gt 0 ] || { echo "build-lane: run needs a command" >&2; exit 2; }
  main_checkout_guard build-lane
  local n wait poll start i status said=
  n=$(lanes)
  wait=${BUILD_LANE_WAIT:-3600} poll=${BUILD_LANE_POLL:-5}
  mkdir -p "$locks"
  export BUILD_LANES=$n
  if [ "$n" -eq 1 ]; then
    # One lane: the lock as it always was.
    export BUILD_LANE=1 BUILD_LANE_PORT_OFFSET=0
    exec lockf -k -t "$wait" "$(lock 1)" "$@"
  fi
  # The command's own exit status can be 75, as lockf's is for a busy lock: the marker says the command ran.
  marker=$(mktemp "${TMPDIR:-/tmp}/build-lane.XXXXXX") || exit 1
  rm -f "$marker"
  trap 'rm -f "$marker"' EXIT
  start=$SECONDS
  while :; do
    for ((i = 1; i <= n; i++)); do
      free "$i" || continue
      BUILD_LANE=$i BUILD_LANE_PORT_OFFSET=$(((i - 1) * 10)) lockf -k -t 0 "$(lock "$i")" "$self" _ran "$marker" "$@"
      status=$?
      [ -e "$marker" ] && exit "$status"
      [ "$status" -eq 75 ] || { echo "build-lane: lockf on lane $i's lock failed (exit $status)" >&2; exit "$status"; }
    done
    if [ $((SECONDS - start)) -ge "$wait" ]; then
      echo "build-lane: all $n build lanes were still busy after $((SECONDS - start))s; nothing started" >&2
      exit 75
    fi
    [ -n "$said" ] || { echo "build-lane: all $n build lanes are busy: waiting up to ${wait}s for one" >&2; said=1; }
    sleep "$poll"
  done
}

ran() {  # <marker> <command…>: inside the lane's lock
  : >"$1"
  shift
  echo "build lane $BUILD_LANE of $BUILD_LANES"
  exec "$@"
}

exists() { xcrun simctl list devices available 2>/dev/null | grep -qF -- "    $1 ("; }

# Under lane 1's lock, so its simulator is idle: shut down if booted, then copied with its Health grant and its data.
clone() {  # <lane 1's udid> <new name>
  exists "$2" && return 0
  if xcrun simctl list devices booted 2>/dev/null | grep -qF "($1)"; then xcrun simctl shutdown "$1" 2>/dev/null; fi
  xcrun simctl clone "$1" "$2" >/dev/null || { echo "build-lane: could not clone $1 as '$2'" >&2; return 1; }
  echo "build-lane: made the simulator '$2', a copy of lane 1's with its Health access and data" >&2
}

sim() {  # <name>
  local name=${1:?simulator name} lane=${BUILD_LANE:-1} want src status info
  if [[ $name =~ ^[0-9A-Fa-f-]{36}$ ]] || [ "$lane" -le 1 ] || [[ $name =~ \ lane\ [0-9]+$ ]]; then
    echo "$name"
    return
  fi
  want="$name lane $lane"
  if exists "$want"; then echo "$want"; return; fi
  src=$(BUILD_LANE=1 "$here/sim-udid.sh" "$name") || return 1
  mkdir -p "$locks"
  # Lane 1's simulator can only be copied shut down, so its lock is taken: never under a job using it.
  free 1 || echo "build-lane: lane $lane has no '$want' yet; waiting up to ${BUILD_LANE_CLONE_WAIT:-600}s for lane 1 to be idle to copy its '$name'" >&2
  lockf -k -t "${BUILD_LANE_CLONE_WAIT:-600}" "$(lock 1)" "$self" _clone "$src" "$want"
  status=$?
  if ! exists "$want"; then
    [ "$status" -eq 75 ] || return 1
    # Lane 1 stayed busy: a fresh simulator of the same model and runtime, which has no Health access yet.
    info=$(xcrun simctl list devices -j 2>/dev/null | jq -r --arg u "$src" \
      '.devices | to_entries[] | .key as $rt | .value[] | select(.udid == $u) | "\(.deviceTypeIdentifier) \($rt)"' | head -1)
    [ -n "$info" ] || { echo "build-lane: no model or runtime for $src, so no '$want'" >&2; return 1; }
    # shellcheck disable=SC2086  # the model and the runtime, two words
    xcrun simctl create "$want" $info >/dev/null || { echo "build-lane: could not create '$want'" >&2; return 1; }
    echo "build-lane: lane 1 was busy, so '$want' is a fresh simulator without Health access or the seeded data: run BUILD_LANE=$lane just native-sim-health once (or just native-sim-lanes, which waits for lane 1 and copies it)" >&2
  fi
  echo "$want"
}

bases() { printf '%s\n' "${SIM:-iPhone 17}" "${WHITEBOARD_SIM:-iPad Pro 11-inch (M5)}"; }

# The newest runtime's simulator of that name, as sim-udid.sh picks it: "<udid> <state>", or nothing.
found() {
  xcrun simctl list devices available 2>/dev/null | grep -F -- "    $1 (" | tail -1 |
    sed -nE 's/.*\(([0-9A-Fa-f-]{36})\) \(([^)]*)\).*/\1 \2/p'
}

list() {
  local n lane base name got
  n=$(lanes)
  for ((lane = 1; lane <= n; lane++)); do
    while IFS= read -r base; do
      name=$base
      [ "$lane" -le 1 ] || name="$base lane $lane"
      got=$(found "$name")
      if [ -n "$got" ]; then echo "lane $lane: $name: ${got% *} (${got#* })"; else echo "lane $lane: $name: missing"; fi
    done < <(bases)
  done
}

# Under lane <lane>'s lock and lane 1's: that lane's copies deleted and copied again from lane 1's.
reclone() {  # <lane>
  local lane=$1 base want src got
  while IFS= read -r base; do
    src=$(BUILD_LANE=1 "$here/sim-udid.sh" "$base") || return 1
    want="$base lane $lane"
    while got=$(found "$want") && [ -n "$got" ]; do
      [ "${got#* }" != Booted ] || xcrun simctl shutdown "${got% *}" 2>/dev/null
      xcrun simctl delete "${got% *}" || { echo "build-lane: could not delete '$want' (${got% *})" >&2; return 1; }
    done
    clone "$src" "$want" >/dev/null 2>&1 || { echo "build-lane: could not copy lane 1's '$base' as '$want'" >&2; return 1; }
    echo "lane $lane: '$want' copied again from lane 1's '$base'"
  done < <(bases)
}

# Under lane <lane>'s lock: lane 1's taken in turn, so the copy is never a blank simulator. 76: lane 1 was busy.
relane() {  # <lane>
  lockf -k -t "${BUILD_LANE_REFRESH_WAIT:-0}" "$(lock 1)" "$self" _reclone "$1"
  local status=$?
  [ "$status" -ne 75 ] || { echo "lane $1: skipped, lane 1 is busy (it is shut down to be copied)"; exit 76; }
  exit "$status"
}

refresh() {
  local n lane status skipped= failed=0
  n=$(lanes)
  [ "$n" -gt 1 ] || { echo "one build lane on this Mac: lane 1's simulators are the named ones, nothing to refresh"; return 0; }
  mkdir -p "$locks"
  for ((lane = 2; lane <= n; lane++)); do
    lockf -k -t "${BUILD_LANE_REFRESH_WAIT:-0}" "$(lock "$lane")" "$self" _relane "$lane"
    status=$?
    case $status in
      0) ;;
      75) echo "lane $lane: skipped, a job is using it; its copies are left as they are"; skipped+=" $lane" ;;
      76) skipped+=" $lane" ;;
      *) echo "build-lane: refreshing lane $lane failed (exit $status)" >&2; failed=$status ;;
    esac
  done
  [ -z "$skipped" ] || echo "build-lane: skipped while busy, lanes${skipped}: run just native-sim-lanes refresh again once they are idle" >&2
  [ "$failed" -eq 0 ] || return "$failed"
  [ -z "$skipped" ] || return 75
}

sims() {
  local n lane base
  case ${1:-} in
    "") ;;
    refresh | --refresh) refresh; return ;;
    list | --list) list; return ;;
    *) echo "build-lane: sims takes nothing, refresh or list, not '$1'" >&2; return 2 ;;
  esac
  n=$(lanes)
  for ((lane = 2; lane <= n; lane++)); do
    for base in "${SIM:-iPhone 17}" "${WHITEBOARD_SIM:-iPad Pro 11-inch (M5)}"; do
      BUILD_LANE=$lane BUILD_LANE_CLONE_WAIT=${BUILD_LANE_CLONE_WAIT:-3600} sim "$base" >/dev/null || return 1
      echo "lane $lane: $base lane $lane"
    done
  done
  [ "$n" -gt 1 ] || echo "one build lane on this Mac: lane 1's simulators are the named ones, nothing to make"
}

case ${1:-} in
  count) lanes ;;
  lock) lock "${2:?a lane}" ;;
  busy) ! free "${2:?a lane}" ;;
  run) shift; run "$@" ;;
  _ran) shift; ran "$@" ;;
  _clone) shift; clone "$@" ;;
  sim) shift; sim "$@" ;;
  sims) shift; sims "$@" ;;
  _relane) shift; relane "$@" ;;
  _reclone) shift; reclone "$@" ;;
  *) sed -n '/^# Usage/,/^set /p' "$self" | sed -e '$d' -e 's/^# *//' >&2; exit 2 ;;
esac
