#!/usr/bin/env bash
# Story 1632 (bead context-grabber-3hj9.3): install-exercise-analyzer.sh puts Exercise Analyzer's simulator build on a
# lane's simulator, or says plainly which build it looked for and exits 3 so the ladder leaves the class out. A fake
# xcrun records its calls.
set -uo pipefail
unset EXERCISE_ANALYZER_APP
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

# The fake: `simctl install` exits $INSTALL (0 installed); every call is appended to calls.
cat >"$tmp/xcrun" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$CALLS"
exit "${INSTALL:-0}"
EOF
chmod +x "$tmp/xcrun"
export CALLS=$tmp/calls PATH="$tmp:$PATH"
app=$tmp/ExerciseAnalyzer.app
run() { : >"$CALLS"; out=$("$here/install-exercise-analyzer.sh" UDID-1 2>&1); status=$?; }

mkdir -p "$app"
EXERCISE_ANALYZER_APP=$app INSTALL=0 run
check "a build that exists is installed on the simulator it names" \
  'grep -qx "simctl install UDID-1 $app" "$CALLS" && [ $status -eq 0 ] && [[ $out == *"installed Exercise Analyzer"* ]]'

EXERCISE_ANALYZER_APP=$app INSTALL=1 run
check "an install that fails fails the step, and says so" \
  '[ $status -eq 1 ] && [[ $out == *"could not install"* ]]'

EXERCISE_ANALYZER_APP=$tmp/missing.app run
check "no build: nothing is installed, exit 3, and the message names the file and how to build it" \
  '[ ! -s "$CALLS" ] && [ $status -eq 3 ] && [[ $out == *"$tmp/missing.app"* ]] && [[ $out == *"just build-sim"* ]]'

out=$("$here/install-exercise-analyzer.sh" 2>&1)
status=$?
check "no simulator named is a usage error" '[ $status -eq 2 ] && [[ $out == *"usage"* ]]'

[ "$fails" -eq 0 ] || { echo "$fails failing"; exit 1; }
