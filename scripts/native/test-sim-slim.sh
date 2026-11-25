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
chmod +x "$tmp/simslim"
export CALLS=$tmp/calls
run() { : >"$CALLS"; out=$(SIMSLIM=$tmp/simslim "$here/sim-slim.sh" UDID-1 2>&1); status=$?; }

VERIFY=1 ON=0 run
check "a stock simulator is slimmed with the kept categories" \
  'grep -qx "on UDID-1 --except siri,health,icloud,photos" "$CALLS" && [ $status -eq 0 ] && [[ $out == *"slimmed UDID-1"* ]]'

VERIFY=0 run
check "an already slim simulator is left alone" '! grep -q "^on " "$CALLS" && [ $status -eq 0 ] && [ -z "$out" ]'

VERIFY=1 ON=1 run
check "a failed slim never fails the caller, and says so" '[ $status -eq 0 ] && [[ $out == *"couldn'"'"'t slim UDID-1"* ]]'

: >"$CALLS"; out=$(SIM_SLIM=0 SIMSLIM=$tmp/simslim "$here/sim-slim.sh" UDID-1 2>&1); status=$?
check "SIM_SLIM=0 skips it" '[ ! -s "$CALLS" ] && [ $status -eq 0 ]'

: >"$CALLS"; out=$(SIMSLIM=$tmp/no-such-simslim "$here/sim-slim.sh" UDID-1 2>&1); status=$?
check "no simslim installed is a quiet no-op" '[ ! -s "$CALLS" ] && [ $status -eq 0 ] && [ -z "$out" ]'

[ "$fails" -eq 0 ] && echo "sim-slim: all passed" || { echo "sim-slim: $fails failed"; exit 1; }
