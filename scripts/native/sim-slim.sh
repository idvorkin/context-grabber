#!/usr/bin/env bash
# Story 1627: a lane's simulator runs slim. simslim (https://github.com/MobAI-App/simslim, a Homebrew tap Igor installs
# by hand) turns off the background daemons a test run never needs. Done once per simulator, it persists across
# reboots, so this only acts on a simulator that isn't slim yet (a new lane clone, a recreated or erased device).
# Measured 2026-11-25, paired on one iPad Pro 11-inch (M5) lane simulator, iOS 27.2, Widgets on: idle, 214 processes and
# 29.9 GB summed RSS stock against 120 and 16.6 GB slim; test time unchanged. It saves memory, not time, and doesn't shrink
# the disk image.
# Kept on, because the app or its tests use them: Siri & Intelligence (dictation and speech), Health (HealthKit), iCloud
# (CloudKit, the board sync, BugKit), Photos (the picker, pasted images) and Widgets (with it off the widget gallery lists
# none of the app's widgets, so the tile tests fail: bead context-grabber-3hj9.4). Pasteboard, keyboard, location and audio are
# core daemons simslim never turns off.
# Usage: sim-slim.sh <udid>. Run it where that lane's simulator is yours (inside its build lane; sim-boot.sh calls it).
# Never fails the caller: no simslim, SIM_SLIM=0, or a failed slim each print one line and exit 0. A slim reboots the
# simulator, so after one it waits for the boot again (bootstatus -b), and exits 1 only if the simulator isn't back up.
# SIMSLIM (default: simslim on PATH) is the binary, for the self-test.
set -uo pipefail
udid=${1:?simulator udid}
[ "${SIM_SLIM:-1}" = 0 ] && exit 0
bin=${SIMSLIM:-simslim}
command -v "$bin" >/dev/null 2>&1 || exit 0
keep=siri,health,icloud,photos,widgets
# verify exits 0 when the simulator's disables already match this profile exactly.
"$bin" verify "$udid" --except "$keep" >/dev/null 2>&1 && exit 0
start=$SECONDS
if "$bin" on "$udid" --except "$keep" >/dev/null 2>&1; then
  echo "sim-slim: slimmed $udid (all but $keep off) in $((SECONDS - start)) s"
  xcrun simctl bootstatus "$udid" -b >/dev/null || { echo "the simulator $udid did not boot after its slim" >&2; exit 1; }
else
  echo "sim-slim: simslim couldn't slim $udid; it runs stock (simslim off $udid undoes a partial slim)" >&2
fi
exit 0
