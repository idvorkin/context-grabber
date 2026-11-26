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
cp "$here/lease-slot.sh" "$here/main-checkout-guard.sh" "$here/build-lane.sh" "$here/host-lane.sh" "$repo/scripts/native/"
git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$repo" worktree add -q "$tmp/slot" -b native/x 2>/dev/null
slot=$(cd "$tmp/slot" && pwd -P)
lease="$repo/scripts/native/lease-slot.sh"

# A stand-in treehouse: STUB_MODE picks get's answer, STUB_STATUS is what status shows (every slot leased by default).
stub="$tmp/treehouse"
cat >"$stub" <<STUB
#!/usr/bin/env bash
[ "\$1" = status ] && { echo "\${STUB_STATUS:-slot-1  leased  native/y}"; exit 0; }
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

start=$SECONDS
out=$(STUB_MODE=full STUB_STATUS="slot-1  available" WAIT=60 run_lease 2>"$tmp/err"); rc=$?
[ $rc -eq 70 ] && [ -z "$out" ] && [ $((SECONDS - start)) -lt 30 ] && grep -q "leased" "$tmp/err" \
  && ok "a lease that fails with a slot available: treehouse's error, exit 70 at once" || bad "failed get, slot available: rc=$rc out='$out'"

out=$(cd "$repo" && TREEHOUSE="$tmp/no-such-treehouse" "$lease" native/x 2>/dev/null); rc=$?
[ $rc -eq 127 ] && [ -z "$out" ] && ok "no treehouse command: exit 127" || bad "no treehouse: rc=$rc out='$out'"

out=$("$lease" 2>/dev/null); rc=$?
[ $rc -eq 2 ] && ok "no branch: usage, exit 2" || bad "usage: rc=$rc"

# The guard, through the lane scripts' own run. A stand-in lockf runs the command (no lock taken, so this runs on
# Linux too); BUILD_LANES and HOST_LANES pin one lane each.
fakes="$tmp/fakes"
mkdir -p "$fakes"
printf '#!/usr/bin/env bash\nshift 4\nexec "$@"\n' >"$fakes/lockf"
chmod +x "$fakes/lockf"
lane() {  # <dir> <script>: runs `<script> run touch $tmp/ran-<script>` from dir
  rm -f "$tmp/ran-$2"
  (cd "$1" && PATH="$fakes:$PATH" BUILD_LOCK_DIR="$tmp/locks" BUILD_LANES=1 HOST_LANES=1 \
    "$repo/scripts/native/$2" run touch "$tmp/ran-$2")
}
for s in build-lane.sh host-lane.sh; do
  git -C "$repo" checkout -q -b feature
  lane "$repo" "$s" 2>"$tmp/err"; rc=$?
  [ $rc -eq 64 ] && [ ! -e "$tmp/ran-$s" ] && grep -q "lease-slot.sh" "$tmp/err" \
    && ok "$s run in the main checkout on a branch: refused, exit 64, nothing ran" || bad "$s guard on branch: rc=$rc"
  lane "$repo/scripts" "$s" 2>/dev/null; rc=$?
  [ $rc -eq 64 ] && [ ! -e "$tmp/ran-$s" ] && ok "$s run from a subdirectory of the main checkout: refused" || bad "$s guard in subdir: rc=$rc"
  git -C "$repo" checkout -q main
  git -C "$repo" branch -q -D feature
  lane "$repo" "$s" 2>/dev/null; rc=$?
  [ $rc -eq 0 ] && [ -e "$tmp/ran-$s" ] && ok "$s run in the main checkout on main: runs (the lead's just deploy)" || bad "$s main on main: rc=$rc"
  lane "$slot" "$s" 2>/dev/null; rc=$?
  [ $rc -eq 0 ] && [ -e "$tmp/ran-$s" ] && ok "$s run from a slot on its branch: runs" || bad "$s slot: rc=$rc"
  lane "$tmp" "$s" 2>/dev/null; rc=$?
  [ $rc -eq 0 ] && [ -e "$tmp/ran-$s" ] && ok "$s run outside any repository: runs" || bad "$s no repo: rc=$rc"
done

[ $fails -eq 0 ] && echo "test-lease-slot: all passed" || { echo "test-lease-slot: $fails failed"; exit 1; }
