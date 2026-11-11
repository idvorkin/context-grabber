#!/usr/bin/env bash
# xcodebuild-log.sh against a fake xcodebuild (the pipeline report of 2026-11-10): a test run gets a time limit per
# test, a build doesn't, and an xcodebuild that hangs after its suite closes is stopped and judged by the log.
set -uo pipefail
cd "$(dirname "$0")/../.."
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
mkdir -p "$dir/bin"
cat >"$dir/bin/xcodebuild" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >"$FAKE_ARGS"
echo "Test Suite 'Selected tests' ${FAKE_RESULT:-passed} at now."
[ -n "${FAKE_HANG:-}" ] && while :; do sleep 1; done  # stays this script, so the watchdog sees "/xcodebuild "
echo "** TEST SUCCEEDED **"
FAKE
chmod +x "$dir/bin/xcodebuild"
run() { PATH="$dir/bin:$PATH" NATIVE_LOG_DIR="$dir/logs" FAKE_ARGS="$dir/args" UI_TIMINGS_JSONL="$dir/t.jsonl" \
  scripts/native/xcodebuild-log.sh fake "TEST SUCCEEDED" "$@" >/dev/null 2>&1; }

run xcodebuild -scheme X test-without-building
args=$(cat "$dir/args")
case " $args " in *" -test-timeouts-enabled YES -default-test-execution-time-allowance 120 "*) ok "a test run gets a 2-minute limit per test";; *) bad "no time limit on a test run: $args";; esac
case " $args " in *" -retry-tests-on-failure -test-iterations 2 "*) ok "and a failed case is retried once, alone";; *) bad "no retry on a test run: $args";; esac
UI_TEST_RETRY=0 run xcodebuild -scheme X test
case " $(cat "$dir/args") " in *"-retry-tests-on-failure"*) bad "UI_TEST_RETRY=0 still retried";; *) ok "UI_TEST_RETRY=0 turns the retry off";; esac
run xcodebuild -scheme X build
case " $(cat "$dir/args") " in *"-test-timeouts-enabled"*) bad "a build got a test time limit";; *) ok "a build gets none";; esac

start=$SECONDS
FAKE_HANG=1 XCODEBUILD_IDLE_SECONDS=1 run xcodebuild -scheme X test
status=$?
[ $((SECONDS - start)) -lt 30 ] && ok "a hang after a passing suite is stopped" || bad "the hang wasn't stopped"
[ "$status" -eq 0 ] && ok "and the log's passed decides" || bad "a passed suite that hung exited $status"
FAKE_HANG=1 FAKE_RESULT=failed XCODEBUILD_IDLE_SECONDS=1 run xcodebuild -scheme X test
[ $? -eq 65 ] && ok "a failed suite that hung exits 65" || bad "a failed suite that hung didn't exit 65"
exit $fail
