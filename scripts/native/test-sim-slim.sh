#!/usr/bin/env bash
# Story 1627: sim-slim.sh slims a lane simulator once, with the profile that keeps what the app's tests use, and never
# fails its caller. A fake simslim records its calls.
set -uo pipefail
unset SIM_SLIM SIMSLIM
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

# The fake: `verify` exits $VERIFY (0 slim already, 1 not), `on` exits $ON; every call is appended to calls.
cat >"$tmp/simslim" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$CALLS"
case $1 in verify) exit "${VERIFY:-1}" ;; on) exit "${ON:-0}" ;; esac
EOF
# A fake xcrun too: `simctl bootstatus` exits $BOOT (0 booted), and is recorded after the simslim calls.
cat >"$tmp/xcrun" <<'EOF'
#!/usr/bin/env bash
echo "xcrun $*" >>"$CALLS"
exit "${BOOT:-0}"
EOF
chmod +x "$tmp/simslim" "$tmp/xcrun"
export CALLS=$tmp/calls PATH="$tmp:$PATH"
run() { : >"$CALLS"; out=$(SIMSLIM=$tmp/simslim "$here/sim-slim.sh" UDID-1 2>&1); status=$?; }

VERIFY=1 ON=0 run
check "a stock simulator is slimmed with the kept categories" \
  'grep -qx "on UDID-1 --except siri,health,icloud,photos,widgets --keep com.apple.linkd" "$CALLS" && grep -qx "verify UDID-1 --except siri,health,icloud,photos,widgets --keep com.apple.linkd" "$CALLS" && [ $status -eq 0 ] && [[ $out == *"slimmed UDID-1"* ]]'

check "the slim's reboot is waited for" '[ "$(tail -1 "$CALLS")" = "xcrun simctl bootstatus UDID-1 -b" ]'

VERIFY=1 ON=0 BOOT=1 run
check "a simulator that doesn't come back after its slim fails, and says so" \
  '[ $status -ne 0 ] && [[ $out == *"did not boot after its slim"* ]]'

VERIFY=0 run
check "an already slim simulator is left alone, and not waited for again" \
  '! grep -q -e "^on " -e "^xcrun " "$CALLS" && [ $status -eq 0 ] && [ -z "$out" ]'

VERIFY=1 ON=1 run
check "a failed slim never fails the caller, and says so" \
  '[ $status -eq 0 ] && [[ $out == *"couldn'"'"'t slim UDID-1"* ]] && ! grep -q "^xcrun " "$CALLS"'

: >"$CALLS"; out=$(SIM_SLIM=0 SIMSLIM=$tmp/simslim "$here/sim-slim.sh" UDID-1 2>&1); status=$?
check "SIM_SLIM=0 skips it" '[ ! -s "$CALLS" ] && [ $status -eq 0 ]'

: >"$CALLS"; out=$(SIMSLIM=$tmp/no-such-simslim "$here/sim-slim.sh" UDID-1 2>&1); status=$?
check "no simslim installed is a quiet no-op" '[ ! -s "$CALLS" ] && [ $status -eq 0 ] && [ -z "$out" ]'

[ "$fails" -eq 0 ] && echo "sim-slim: all passed" || { echo "sim-slim: $fails failed"; exit 1; }
