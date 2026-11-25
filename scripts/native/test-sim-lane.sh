#!/usr/bin/env bash
# Host test for story 1516 (bead context-grabber-w7nl): a simulator is driven only from the build lane that owns it.
# scripts/native/sim-lane.sh, and the guard in sim-boot.sh and xcodebuild-log.sh, with a fake xcrun (simctl) and a fake
# xcodebuild, so nothing boots and nothing builds:
#   which lane owns a simulator (its " lane N", lane 1 for the named models, none for others or for an id this Mac
#   lacks); a run holding no lane, or another lane, refused with exit 64 and told how to run it; the lane's own allowed;
#   xcodebuild-log.sh refusing a test run on another lane's simulator but not a build; a script run outside any lane
#   taking one (take_lane) and reading a lane's udid as that model in its own lane (lane_target).
set -uo pipefail
unset BUILD_LANES BUILD_LANE BUILD_LANE_PORT_OFFSET SIM_LANE_TAKEN SIM WHITEBOARD_SIM SIMSLIM
export SIM_SLIM=0
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-sim-lane-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0
out=$tmp/out
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; sed 's/^/     /' "$out" 2>/dev/null; fail=1; }
is() { if [ "$2" = "$3" ]; then ok "$1"; else echo "     wanted: $3"; echo "     got:    $2"; bad "$1"; fi; }
has() { if grep -qF -- "$3" "$2" 2>/dev/null; then ok "$1"; else echo "     wanted in ${2##*/}: $3"; bad "$1"; fi; }

PAD=00000000-0000-0000-0000-00000000000A PAD_LOWER=00000000-0000-0000-0000-00000000000a
L2PAD=00000000-0000-0000-0000-000000000002
PHONE=00000000-0000-0000-0000-000000000003 OTHER=00000000-0000-0000-0000-000000000004
GONE=00000000-0000-0000-0000-000000000009
fakes=$tmp/bin
mkdir -p "$fakes" "$tmp/marks"
export MARKS=$tmp/marks
cat >"$fakes/xcrun" <<F
#!/usr/bin/env bash
echo "xcrun \$*" >>"\$MARKS/xcrun"
[ "\$1 \$2" != "simctl install" ] || exit 31
[ "\$1 \$2 \$3" = "simctl list devices" ] || exit 0
cat <<'DEVICES'
== Devices ==
-- iOS 27.0 --
    iPad Pro 11-inch (M5) ($PAD) (Booted)
    iPad Pro 11-inch (M5) lane 2 ($L2PAD) (Shutdown)
    iPhone 17 ($PHONE) (Shutdown)
    iPhone 16e ($OTHER) (Booted)
DEVICES
F
cat >"$fakes/xcodebuild" <<'F'
#!/usr/bin/env bash
echo "xcodebuild lane=${BUILD_LANE:-none} $*" >>"$MARKS/xcodebuild"
case " $* " in
  *" test "*) echo "** TEST SUCCEEDED **" ;;
  *) echo "** BUILD SUCCEEDED **" ;;
esac
F
printf '#!/usr/bin/env bash\nexit 0\n' >"$fakes/xcodegen"
printf '#!/usr/bin/env bash\nexit 1\n' >"$fakes/pgrep"
chmod +x "$fakes"/*
with() { env PATH="$fakes:$PATH" BUILD_LOCK_DIR="$tmp/locks" SIM_DEVICES_DIR="$tmp/devices" SMOKE_LOCK_PROBE="echo unlocked" "$@"; }
lib() { with bash -c '. scripts/native/sim-lane.sh; "$@"' _ "$@"; }

# Who owns a simulator.
is "a lane's copy: that lane" "$(lib sim_owner "$L2PAD")" 2
is "the named iPad: lane 1" "$(lib sim_owner "$PAD")" 1
is "the named iPhone, by name: lane 1" "$(lib sim_owner "iPhone 17")" 1
is "a simulator of no lane: none" "$(lib sim_owner "$OTHER")" ""
is "an id this Mac doesn't have (a test's fake): none" "$(lib sim_owner "$GONE")" ""
is "WHITEBOARD_SIM names lane 1's model" "$(lib env WHITEBOARD_SIM="iPad Air" bash -c '. scripts/native/sim-lane.sh; sim_owner "iPad Air"')" 1

# The guard.
lib sim_lane_guard "$PAD" sim-boot >"$out" 2>&1
is "no lane, lane 1's simulator: refused, exit 64" "$?" 64
has "and says how to run it" "$out" "scripts/native/build-lane.sh run <this command>"
with BUILD_LANE=2 bash -c '. scripts/native/sim-lane.sh; sim_lane_guard "$1" sim-boot' _ "$PAD" >"$out" 2>&1
is "lane 2, lane 1's simulator: refused, exit 64" "$?" 64
has "and names both lanes" "$out" "is build lane 1's and this run holds lane 2"
with BUILD_LANE=1 bash -c '. scripts/native/sim-lane.sh; sim_lane_guard "$1" sim-boot' _ "$PAD" >"$out" 2>&1
is "lane 1, its own simulator: allowed" "$?" 0
with BUILD_LANE=2 bash -c '. scripts/native/sim-lane.sh; sim_lane_guard "$1" sim-boot' _ "$L2PAD" >"$out" 2>&1
is "lane 2, its own copy: allowed" "$?" 0
lib sim_lane_guard "$OTHER" sim-boot >"$out" 2>&1
is "no lane, a simulator of no lane: allowed" "$?" 0
lib sim_lane_guard "SIM-UDID-1022" sim-boot >"$out" 2>&1
is "no lane, a fake id: allowed" "$?" 0

# lane_target: a lane's udid, in a run that took its own lane, means that model in this lane.
is "took a lane, given lane 2's iPad: the model" "$(with SIM_LANE_TAKEN=1 bash -c '. scripts/native/sim-lane.sh; lane_target "$1"' _ "$L2PAD")" "iPad Pro 11-inch (M5)"
is "took a lane, given lane 1's iPad: the model" "$(with SIM_LANE_TAKEN=1 bash -c '. scripts/native/sim-lane.sh; lane_target "$1"' _ "$PAD")" "iPad Pro 11-inch (M5)"
is "already in a lane: the udid as given" "$(lib lane_target "$L2PAD")" "$L2PAD"
is "took a lane, a simulator of no lane: as given" "$(with SIM_LANE_TAKEN=1 bash -c '. scripts/native/sim-lane.sh; lane_target "$1"' _ "$OTHER")" "$OTHER"

# take_lane: a script run outside any lane runs again inside one, marked.
cat >"$tmp/job.sh" <<'F'
#!/usr/bin/env bash
. scripts/native/sim-lane.sh
take_lane "$0" "$@"
echo "lane=${BUILD_LANE:-none} taken=${SIM_LANE_TAKEN:-no} arg=$1"
F
with BUILD_LANES=1 bash "$tmp/job.sh" hello >"$out" 2>&1
has "outside a lane: it takes one" "$out" "lane=1 taken=1 arg=hello"
has "and says so" "$out" "not in a build lane, so taking one"
with BUILD_LANE=3 bash "$tmp/job.sh" hello >"$out" 2>&1
has "inside a lane: it runs as it is" "$out" "lane=3 taken=no arg=hello"

xlog() {
  local udid=$1
  shift
  with NATIVE_LOG_DIR="$tmp/logs" "$@" scripts/native/xcodebuild-log.sh lane-test "BUILD SUCCEEDED" \
    xcodebuild -scheme X -destination "platform=iOS Simulator,id=$udid" "${XACT:-test}" >"$out" 2>&1
}

# Story 1517 requires both commands to refuse the same owned simulator regardless of UUID case.
hold_lane_one=(lockf -k -t 0 "$tmp/locks/build.lock")
for udid in "$PAD" "$PAD_LOWER"; do
  : >"$MARKS/xcrun"
  with BUILD_LANES=4 "${hold_lane_one[@]}" scripts/native/sim-boot.sh "$udid" >"$out" 2>&1
  is "sim-boot outside a lane on $udid: exit 64" "$?" 64
  if grep -qE 'bootstatus|shutdown' "$MARKS/xcrun"; then
    bad "sim-boot on $udid reached boot or shutdown"
  fi

  rm -f "$MARKS/xcodebuild"
  xlog "$udid" "${hold_lane_one[@]}"
  is "a test run outside a lane on $udid: exit 64" "$?" 64
  [ ! -e "$MARKS/xcodebuild" ] && ok "xcodebuild never ran on $udid" || bad "xcodebuild ran on $udid"
  has "and says which simulator" "$out" "xcodebuild-log.sh lane-test: refused: the simulator '$udid' is build lane 1's"
done

# xcodebuild-log.sh: a test run on another lane's simulator is refused before xcodebuild runs; a build isn't.
rm -f "$MARKS/xcodebuild"
XACT=test-without-building xlog "$PAD" BUILD_LANE=2
is "a run of built tests in lane 2 on lane 1's iPad: exit 64" "$?" 64
rm -f "$MARKS/xcodebuild"
XACT=build xlog "$PAD"
[ -e "$MARKS/xcodebuild" ] && ok "a build for the simulator, outside a lane: it runs" || bad "a build for the simulator, outside a lane: it runs"

# Story 1627: sim-boot.sh slims the simulator once it is booted, and waits for it to be booted again after the slim.
printf '#!/usr/bin/env bash\necho "simslim $*" >>"$MARKS/xcrun"\n[ "$1" != verify ]\n' >"$tmp/simslim"
chmod +x "$tmp/simslim"
: >"$MARKS/xcrun"
with BUILD_LANES=1 BUILD_LANE=1 SIM_SLIM=1 SIMSLIM="$tmp/simslim" scripts/native/sim-boot.sh "$PAD" >"$out" 2>&1
is "sim-boot with simslim: exit 0" "$?" 0
is "it boots, slims, then waits for the boot again" \
  "$(sed -nE 's/^xcrun simctl (bootstatus) .*/\1/p; s/^simslim (verify|on) .*/\1/p' "$MARKS/xcrun" | tr '\n' ' ')" \
  "bootstatus verify on bootstatus "
has "and slims the simulator it booted" "$MARKS/xcrun" "simslim on $PAD --except siri,health,icloud,photos"

recipe() {
  with SIM="iPad Pro 11-inch (M5)" BUILD_LANES=2 BUILD_LANE_WAIT=0 SMOKE_ONLY=mirror \
    NATIVE_LOG_DIR="$tmp/logs" "$@" >"$out" 2>&1
}
: >"$MARKS/xcodebuild"
: >"$MARKS/xcrun"
recipe lockf -k -t 0 "$tmp/locks/build.lock" just native-test-sim
is "the standalone smoke waits for lane 1 even when lane 2 is free" "$?" 75
if [ -s "$MARKS/xcodebuild" ] || [ -s "$MARKS/xcrun" ]; then
  bad "busy lane 1: the standalone smoke started work"
fi

recipe just native-sim-health
is "the default Health grant succeeds" "$?" 0
has "the default Health grant runs on lane 1's iPad" "$MARKS/xcodebuild" "xcodebuild lane=1 -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath native/Build -destination platform=iOS Simulator,id=$PAD"

recipe just native-test-sim
has "the standalone smoke installs on the iPad with the default Health grant" "$MARKS/xcrun" "simctl install $PAD "

recipe BUILD_LANE=2 just native-test-sim
has "a smoke already in lane 2 installs on its own iPad" "$MARKS/xcrun" "simctl install $L2PAD "

exit "$fail"
