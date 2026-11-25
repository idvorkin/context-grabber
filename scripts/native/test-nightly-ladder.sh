#!/usr/bin/env bash
# Bead context-grabber-3rk: nightly-ladder.sh starts the full ladder only when the Mac is idle, once a day, and says why
# not otherwise; a failed climb leaves a summary and fails. Every Mac reading is stood in for; no ladder really runs.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dir=$(mktemp -d "${TMPDIR:-/tmp}/cg-nightly.XXXXXX")
trap 'rm -rf "$dir"' EXIT
fail=0
out=$dir/out
ok() { echo "ok   nightly: $1"; }
bad() { echo "FAIL nightly: $1"; sed 's/^/     /' "$out"; fail=1; }
has() { if grep -qF -- "$2" "$out"; then ok "$1"; else echo "     wanted: $2"; bad "$1"; fi; }

idle() { NIGHTLY_HOME=$dir/home NIGHTLY_HOUR=3 NIGHTLY_POWER=ac NIGHTLY_CPU=5 NIGHTLY_BUSY=0 NIGHTLY_TODAY=2026-11-25 "$@"; }

idle env NIGHTLY_HOUR=14 "$here/nightly-ladder.sh" --dry-run >"$out" 2>&1
has "outside the window it waits" "the hour (14) is outside 1-6"
idle env NIGHTLY_HOUR=6 "$here/nightly-ladder.sh" --dry-run >"$out" 2>&1
has "at 6:00 the window has closed" "the hour (6) is outside 1-6"
idle env NIGHTLY_HOUR=1 "$here/nightly-ladder.sh" --dry-run >"$out" 2>&1
has "at 1:00 the window is open" "would run the full ladder"
idle env NIGHTLY_POWER=battery "$here/nightly-ladder.sh" --dry-run >"$out" 2>&1
has "on battery it waits" "the Mac is on battery"
idle env NIGHTLY_CPU=55 "$here/nightly-ladder.sh" --dry-run >"$out" 2>&1
has "a busy CPU makes it wait" "the CPU is 55% busy"
idle env NIGHTLY_BUSY=2 "$here/nightly-ladder.sh" --dry-run >"$out" 2>&1
has "a held build lane makes it wait" "2 build lane(s) held"
idle "$here/nightly-ladder.sh" --dry-run >"$out" 2>&1
has "idle, it would run" "would run the full ladder"
[ -e "$dir/home/ran-2026-11-25" ] && bad "a dry run marks nothing" || ok "a dry run marks nothing"

# A checkout that can't be updated leaves its reason, fails, and leaves the day to the next check.
mkdir -p "$dir/home/checkout"
git -C "$dir/home/checkout" init -q 2>/dev/null
idle env NIGHTLY_LADDER="echo climbed" "$here/nightly-ladder.sh" >"$out" 2>&1
code=$?
[ "$code" -eq 1 ] && ok "a checkout that can't update fails" || bad "a checkout that can't update fails (exit $code)"
grep -q "could not update the checkout" "$dir/home/2026-11-25.fail" 2>/dev/null && ok "and leaves its reason" || bad "and leaves its reason"
[ -e "$dir/home/ran-2026-11-25" ] && bad "and the day stays open" || ok "and the day stays open"
rm -rf "$dir/home/checkout"

# A real run, with the checkout made by hand and the ladder a stand-in, so nothing is built.
mkdir -p "$dir/home/checkout"
git -C "$dir/home/checkout" init -q 2>/dev/null
git -C "$dir/home/checkout" -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed
git -C "$dir/home/checkout" remote add origin "$dir/home/checkout"
git -C "$dir/home/checkout" branch -q -M main
idle env NIGHTLY_LADDER="echo climbed; exit 0" "$here/nightly-ladder.sh" >"$out" 2>&1
has "idle, it climbs and says it passed" "the full ladder passed"
[ -e "$dir/home/2026-11-25.fail" ] && bad "a pass clears the day's earlier failure" || ok "a pass clears the day's earlier failure"
grep -q climbed "$dir/home/2026-11-25.log" && ok "the climb's output is in the day's log" || bad "the climb's output is in the day's log"
idle env NIGHTLY_LADDER="echo climbed" "$here/nightly-ladder.sh" >"$out" 2>&1
has "once a day" "already ran on 2026-11-25"

idle env NIGHTLY_TODAY=2026-11-26 NIGHTLY_LADDER="echo 'FAIL WhiteboardTurnUITests'; exit 2" "$here/nightly-ladder.sh" >"$out" 2>&1
code=$?
[ "$code" -eq 2 ] && ok "a failed climb fails" || bad "a failed climb fails (exit $code)"
grep -q "FAIL WhiteboardTurnUITests" "$dir/home/2026-11-26.fail" 2>/dev/null && ok "and leaves its failures" || bad "and leaves its failures"
exit $fail
