#!/usr/bin/env bash
# Rung 2 of the native test ladder: run the simulator build from launch hooks and judge it from the session log.
# Usage: sim-smoke.sh <simulator name or udid> <bundle id> <app path>
set -euo pipefail
SIM=$("$(dirname "$0")/sim-udid.sh" "$1"); BUNDLE=$2; APP=$3  # one device, whatever runtimes share the name
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"
DOCS="$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)/Documents"
fail=0
newest_log() { ls -t "$DOCS"/logs/*.jsonl 2>/dev/null | head -1; return 0; }  # no logs yet on a fresh install
# Waits (up to $2 s) until a log newer than $previous_log has an event of type $1, so a slow start cannot reuse
# the previous launch's result.
wait_for() {
  local waited=0
  while [ "$waited" -lt "$2" ]; do
    sleep 1; waited=$((waited + 1))
    local f; f=$(newest_log)
    [ -n "$f" ] && [ "$f" != "$previous_log" ] && jq -e --arg t "$1" 'select(.type==$t)' "$f" >/dev/null 2>&1 && return 0
  done
  fail=1  # a timeout fails the run even if a later assertion finds an old result
  return 1
}
relaunch() {  # env assignments come from the caller's environment (SIMCTL_CHILD_*)
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
  previous_log=$(newest_log)
  xcrun simctl launch "$SIM" "$BUNDLE" >/dev/null
}
ok() { echo "ok    $1"; }
bad() { echo "FAIL  $1"; fail=1; }

# Stories 140, 141: a launch writes a log whose first line names the build, and prunes (even when zero).
relaunch
wait_for logs_pruned 20 || echo "      (timed out waiting for logs_pruned)"
f=$(newest_log)
sha=$(jq -r 'select(.type=="session_start") | .sha' "$f" | head -1)
first=$(head -1 "$f" | jq -r .type)
if [ "$first" = "session_start" ] && [ -n "$sha" ] && [ "$sha" != "null" ]; then ok "launch: session_start first, build $sha"
else bad "launch: first line '$first', sha '$sha'"; fi

# Story 142: a report carries the note, the screen, the log's name and a screenshot.
note="smoke $(date +%s)"
SIMCTL_CHILD_GRABBER_BUG="$note" relaunch
wait_for bug_report 20 || echo "      (timed out waiting for bug_report)"
sleep 1
f=$(newest_log)
last=$(tail -1 "$DOCS/bugs.jsonl" 2>/dev/null || echo '{}')
got_note=$(jq -r '.note // empty' <<<"$last")
got_log=$(jq -r '.log // empty' <<<"$last")
shot=$(jq -r '.screenshot // empty' <<<"$last")
screen=$(jq -r '.screen // empty' <<<"$last")
if [ "$got_note" = "$note" ] && [ "$got_log" = "$(basename "$f")" ] && [ "$screen" = "home" ] \
  && [ -n "$shot" ] && [ -s "$DOCS/$shot" ]; then ok "report: note, screen, log $got_log, $shot"
else bad "report: note '$got_note' log '$got_log' screen '$screen' screenshot '$shot'"; fi

# No launch may log an error.
errors=$(jq -c 'select(.type=="error")' "$f")
if [ -z "$errors" ]; then ok "report: no error events"; else bad "report: error events: $errors"; fi

# Stories 096, 097, 200: the Cockpit screen on the bundled bridge test page, which speaks only the protocol
# (docs/cockpit-audio-bridge.md): it asks for the roster on audio.ready, sets an output and an input, asks for a
# missing microphone, says its call went live and ended, and reports the round trip as getRoute("roundtrip:<inputs>:
# tagged|untagged") — so the log alone shows the page received a device list and its address carried the tag.
wait_jq() {  # like wait_for, on any jq filter
  local waited=0
  while [ "$waited" -lt "$2" ]; do
    sleep 1; waited=$((waited + 1))
    local f; f=$(newest_log)
    [ -n "$f" ] && [ "$f" != "$previous_log" ] && [ -n "$(jq -c "$1" "$f" 2>/dev/null)" ] && return 0
  done
  fail=1
  return 1
}
SIMCTL_CHILD_GRABBER_COCKPIT=open SIMCTL_CHILD_GRABBER_COCKPIT_URL=cockpit-bridge-test relaunch
wait_jq 'select(.type=="cockpit_bridge" and .dir=="in" and ((.request_id // "") | startswith("roundtrip:")))' 30 \
  || echo "      (timed out waiting for the page's roundtrip)"
sleep 2  # the answers to the last requests
f=$(newest_log)
load=$(jq -sr '[.[] | select(.type=="cockpit_load")][0] | "\(.ok) \(.url)"' "$f")
if [[ "$load" == "true "*"client=context-grabber&v="* ]]; then ok "cockpit: page loaded with the client tag"
else bad "cockpit: load '$load'"; fi
ready=$(jq -s '[.[] | select(.type=="cockpit_bridge" and .dir=="out" and .kind=="audio.ready")] | length' "$f")
listed=$(jq -sr '[.[] | select(.type=="cockpit_bridge" and .dir=="out" and .kind=="audio.devices" and .request_id=="smoke-list")][0].inputs // 0' "$f")
trip=$(jq -sr '[.[] | select(.type=="cockpit_bridge" and .dir=="in" and ((.request_id // "") | startswith("roundtrip:")))][0].request_id // ""' "$f")
if [ "$ready" = "1" ] && [ "$listed" -ge 1 ] && [[ "$trip" =~ ^roundtrip:[1-9][0-9]*:tagged$ ]]; then
  ok "cockpit: handshake, $listed microphone(s) delivered, page says $trip"
else bad "cockpit: ready $ready, smoke-list inputs '$listed', page roundtrip '$trip'"; fi
# Every request with a requestId gets exactly one answer; a missing microphone is an audio.error, never silence.
asked=$(jq -s '[.[] | select(.type=="cockpit_bridge" and .dir=="in" and .request_id != null)] | length' "$f")
answered=$(jq -s '[.[] | select(.type=="cockpit_bridge" and .dir=="out" and .request_id != null)] | length' "$f")
missing=$(jq -sr '[.[] | select(.type=="cockpit_bridge" and .dir=="out" and .request_id=="smoke-missing")][0].kind // ""' "$f")
if [ "$asked" -ge 5 ] && [ "$asked" = "$answered" ] && [ "$missing" = "audio.error" ]; then
  ok "cockpit: $asked requests, $answered answers, a missing mic is audio.error"
else bad "cockpit: $asked requests, $answered answers, missing mic answered '$missing'"; fi
roster=$(jq -sr '[.[] | select(.type=="audio_route" and .action=="audio.listDevices")][0] | "\(.inputs | length) \(.output)"' "$f")
awake=$(jq -sr '[.[] | select(.type=="keep_awake" and .reason=="cockpit_call") | .on] | map(tostring) | join(",")' "$f")
if [[ "$roster" =~ ^[1-9] ]] && [ "$awake" = "true,false" ]; then
  ok "cockpit: audio_route logged ($roster), screen held for the call and let go"
else bad "cockpit: audio_route '$roster', keep_awake '$awake'"; fi
errors=$(jq -c 'select(.type=="error")' "$f")
if [ -z "$errors" ]; then ok "cockpit: no error events"; else bad "cockpit: error events: $errors"; fi

# Story 096: an unreachable Cockpit is the error panel with its reason, never a blank page.
SIMCTL_CHILD_GRABBER_COCKPIT=open SIMCTL_CHILD_GRABBER_COCKPIT_URL=https://127.0.0.1:65530/ relaunch
wait_for cockpit_load 30 || echo "      (timed out waiting for cockpit_load)"
f=$(newest_log)
failed_load=$(jq -sr '[.[] | select(.type=="cockpit_load")][0] | "\(.ok) \(.error)"' "$f")
if [[ "$failed_load" == "false "* ]] && [[ "$failed_load" != "false null" ]]; then ok "cockpit: unreachable → '${failed_load#false }'"
else bad "cockpit: unreachable load '$failed_load'"; fi

# Stories 100, 104, 105: a 10 s work / 10 s rest / 2 round workout started as a widget tile would. Every cue
# falls on its second (within 0.4 s), the duck window opens once per boundary, and the session is let go at the end.
SIMCTL_CHILD_GRABBER_TIMER="10,10,2" relaunch
wait_for timer_finished 70 || echo "      (timed out waiting for timer_finished)"
sleep 4  # "done" sounds, then the window lets go of the session
f=$(newest_log)
cues=$(jq -sr '
  ([.[] | select(.type=="timer_start")][0].t) as $t0 |
  [.[] | select(.type=="timer_cue") | "\(((.t - $t0) / 1000 + 0.3) | floor):\(.cue)\(if .ok then "" else "!" end)"] | join(" ")' "$f")
want="2:three 3:two 4:one 5:go 12:three 13:two 14:one 15:rest 22:three 23:two 24:one 25:go 32:three 33:two 34:one 35:done"
late=$(jq -s '
  ([.[] | select(.type=="timer_start")][0].t) as $t0 |
  [.[] | select(.type=="timer_cue") | ((.t - $t0) % 1000)] | map(select(. > 400 and . < 700)) | length' "$f")
if [ "$cues" = "$want" ] && [ "$late" = "0" ]; then ok "timer: 16 cues, each on its second"
else bad "timer: cues '$cues' ($late late)"; fi
opens=$(jq -s '[.[] | select(.type=="timer_duck" and .action=="open")] | length' "$f")
closes=$(jq -s '[.[] | select(.type=="timer_duck" and .action=="released")] | length' "$f")
last_session=$(jq -sr '[.[] | select(.type=="timer_session")][-1] | "\(.action) \(.ok)"' "$f")
if [ "$opens" = "4" ] && [ "$closes" = "4" ] && [ "$last_session" = "inactive true" ]; then
  ok "timer: 4 duck windows, session let go at the end"
else bad "timer: $opens opens, $closes releases, last session event '$last_session'"; fi
failed=$(jq -c 'select(.type=="error" or ((.type|startswith("timer_")) and .ok == false))' "$f")
if [ -z "$failed" ]; then ok "timer: nothing failed"; else bad "timer: $failed"; fi

xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
exit $fail
