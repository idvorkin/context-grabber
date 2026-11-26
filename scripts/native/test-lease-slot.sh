#!/usr/bin/env bash
# Story 1901 (bead context-grabber-8w8c): lease-slot.sh prints a slot or nothing, and the lane runs refuse branch work
# in the main checkout. Runs against a throwaway repository with one linked worktree and a stand-in treehouse.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-lease-slot-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }

repo="$tmp/repo"
mkdir -p "$repo/scripts/native"
cp "$here/lease-slot.sh" "$here/main-checkout-guard.sh" "$here/host-lane.sh" "$repo/scripts/native/"
git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$repo" worktree add -q "$tmp/slot" -b native/x 2>/dev/null
slot=$(cd "$tmp/slot" && pwd -P)
lease="$repo/scripts/native/lease-slot.sh"

# A stand-in treehouse: STUB_MODE picks its answer.
stub="$tmp/treehouse"
cat >"$stub" <<STUB
#!/usr/bin/env bash
case "\${STUB_MODE:-}" in
  slot) echo "$slot" ;;
  main) echo "$repo" ;;
  empty) exit 0 ;;
  full) echo "error: every worktree in the pool is leased" >&2; exit 1 ;;
  later) n=\$(cat "$tmp/calls" 2>/dev/null || echo 0); n=\$((n + 1)); echo \$n >"$tmp/calls"
         [ \$n -ge 3 ] && echo "$slot" && exit 0; echo "pool full" >&2; exit 1 ;;
esac
STUB
chmod +x "$stub"
run_lease() { (cd "$repo" && TREEHOUSE="$stub" LEASE_SLOT_POLL=0 LEASE_SLOT_WAIT="${WAIT:-0}" "$lease" native/x); }

out=$(STUB_MODE=slot run_lease 2>/dev/null); rc=$?
[ $rc -eq 0 ] && [ "$out" = "$slot" ] && ok "a free slot: its path, exit 0" || bad "a free slot: got rc=$rc out='$out'"

out=$(STUB_MODE=full run_lease 2>"$tmp/err"); rc=$?
[ $rc -eq 75 ] && [ -z "$out" ] && grep -q "Nothing leased" "$tmp/err" && ok "every slot leased: nothing printed, exit 75" || bad "full pool: rc=$rc out='$out'"

out=$(STUB_MODE=empty run_lease 2>/dev/null); rc=$?
[ $rc -eq 70 ] && [ -z "$out" ] && ok "an empty answer: nothing printed, exit 70" || bad "empty answer: rc=$rc out='$out'"

out=$(STUB_MODE=main run_lease 2>"$tmp/err"); rc=$?
[ $rc -eq 70 ] && [ -z "$out" ] && grep -q "main checkout" "$tmp/err" && ok "the main checkout handed back: refused, exit 70" || bad "main path: rc=$rc out='$out'"

rm -f "$tmp/calls"
out=$(STUB_MODE=later WAIT=60 run_lease 2>/dev/null); rc=$?
[ $rc -eq 0 ] && [ "$out" = "$slot" ] && ok "a slot that frees up within the wait: leased on the retry" || bad "retry: rc=$rc out='$out'"

out=$("$lease" 2>/dev/null); rc=$?
[ $rc -eq 2 ] && ok "no branch: usage, exit 2" || bad "usage: rc=$rc"

hl="$repo/scripts/native/host-lane.sh"
git -C "$repo" checkout -q -b feature
(cd "$repo" && HOST_LANES=1 "$hl" run true) 2>"$tmp/err"; rc=$?
[ $rc -eq 64 ] && grep -q "lease-slot.sh" "$tmp/err" && ok "host-lane run in the main checkout on a branch: refused, exit 64" || bad "guard on branch: rc=$rc"
(cd "$repo" && LANE_ALLOW_MAIN_CHECKOUT=1 HOST_LANES=1 "$hl" run true) 2>/dev/null; rc=$?
[ $rc -eq 0 ] && ok "the deliberate override runs" || bad "override: rc=$rc"
git -C "$repo" checkout -q main
(cd "$repo" && HOST_LANES=1 "$hl" run true) 2>/dev/null; rc=$?
[ $rc -eq 0 ] && ok "host-lane run in the main checkout on main: runs (the lead's just deploy)" || bad "main on main: rc=$rc"
(cd "$slot" && HOST_LANES=1 "$repo/scripts/native/host-lane.sh" run true) 2>/dev/null; rc=$?
[ $rc -eq 0 ] && ok "host-lane run from a slot on its branch: runs" || bad "slot: rc=$rc"

[ $fails -eq 0 ] && echo "test-lease-slot: all passed" || { echo "test-lease-slot: $fails failed"; exit 1; }
