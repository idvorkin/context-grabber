#!/usr/bin/env bash
# Story 1627: a lane's simulator runs slim. simslim (https://github.com/MobAI-App/simslim, a Homebrew tap Igor installs
# by hand) turns off the background daemons a test run never needs. Done once per simulator, it persists across
# reboots, so this only acts on a simulator that isn't slim yet (a new lane clone, a recreated or erased device).
# Measured 2026-11-24 on an idle iPad Pro 11-inch (M5) lane simulator, iOS 27.2: 180 processes down to 84, summed RSS
# 10.2 GB down to 7.0 GB. It doesn't shrink the disk image.
# Kept on, because the app or its tests use them: Siri & Intelligence (dictation and speech), Health (HealthKit), iCloud
# (CloudKit, the board sync, BugKit) and Photos (the picker, pasted images). Pasteboard, keyboard, location and audio are
# core daemons simslim never turns off.
# Usage: sim-slim.sh <udid>. Run it where that lane's simulator is yours (inside its build lane; sim-boot.sh calls it).
# Never fails the caller: no simslim, SIM_SLIM=0, or a failed slim each print one line and exit 0.
# SIMSLIM (default: simslim on PATH) is the binary, for the self-test.
set -uo pipefail
udid=${1:?simulator udid}
[ "${SIM_SLIM:-1}" = 0 ] && exit 0
bin=${SIMSLIM:-simslim}
command -v "$bin" >/dev/null 2>&1 || exit 0
keep=siri,health,icloud,photos
# verify exits 0 when the simulator's disables already match this profile exactly.
"$bin" verify "$udid" --except "$keep" >/dev/null 2>&1 && exit 0
start=$SECONDS
if "$bin" on "$udid" --except "$keep" >/dev/null 2>&1; then
  echo "sim-slim: slimmed $udid (all but $keep off) in $((SECONDS - start)) s"
else
  echo "sim-slim: simslim couldn't slim $udid; it runs stock (simslim off $udid undoes a partial slim)" >&2
fi
exit 0
