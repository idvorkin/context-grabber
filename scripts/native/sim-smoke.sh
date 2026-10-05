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

# Stories 080–084, 093: a call to a fake bridge on this Mac (scripts/native/fake-bridge.py), started by the launch
# hook and hung up by it after 8 s. Judged from the session log and the bridge's own report: the start frame went up
# with the client tag, mic frames flowed up, PCM came down and was scheduled, captions arrived, and the hang-up
# sent the dump, stt_stop and stop and ended as "stopped". Once with synthetic audio (the protocol path, whatever
# the simulator's audio does), once with the real engine (voice processing, the tap, the player node).
xcrun simctl privacy "$SIM" grant microphone "$BUNDLE" 2>/dev/null || true
PORT=${CALL_PORT:-8799}
REPORT=$(mktemp -t fake-bridge); : >"$REPORT"
"$(dirname "$0")/fake-bridge.py" "$PORT" "$REPORT" >/dev/null 2>&1 &
BRIDGE=$!
trap 'kill $BRIDGE 2>/dev/null || true' EXIT
sleep 2
# Another bridge already on the port would answer instead and leave this report empty.
kill -0 "$BRIDGE" 2>/dev/null || bad "call: the fake bridge did not start on port $PORT (is one already running?)"
call_check() {  # $1: label, $2: audio (synthetic or empty)
  local label=$1 lines before
  before=$(wc -l <"$REPORT" | tr -d ' ')
  SIMCTL_CHILD_GRABBER_CALL="ws://localhost:$PORT" SIMCTL_CHILD_GRABBER_CALL_AUDIO="$2" relaunch
  wait_for call_ended 30 || echo "      (timed out waiting for call_ended)"
  sleep 2
  f=$(newest_log)
  local start ready first_mic mic_frames rx sched larry igor ended sent_tail failed
  start=$(jq -sr '[.[] | select(.type=="call_sent" and .frame=="start")] | length' "$f")
  ready=$(jq -sr '[.[] | select(.type=="call_ready")][0].out_rate // empty' "$f")
  first_mic=$(jq -sr '[.[] | select(.type=="call_mic" and .action=="first_frame")][0].rate // empty' "$f")
  mic_frames=$(jq -sr '[.[] | select(.type=="call_ended")][0].mic_frames // 0' "$f")
  rx=$(jq -sr '[.[] | select(.type=="call_ended")][0].rx_frames // 0' "$f")
  sched=$(jq -sr '[.[] | select(.type=="call_ended")][0].scheduled_s // 0' "$f")
  larry=$(jq -sr '[.[] | select(.type=="call_caption" and .who=="larry")][0].text // empty' "$f")
  igor=$(jq -sr '[.[] | select(.type=="call_caption" and .who=="igor")][0].text // empty' "$f")
  ended=$(jq -sr '[.[] | select(.type=="call_ended")][0] | "\(.reason) \(.badly)"' "$f")
  sent_tail=$(jq -sr '[.[] | select(.type=="call_sent") | .frame] | .[-3:] | join(",")' "$f")
  if [ "$start" = "1" ] && [ "$ready" = "16000" ] && [ -n "$first_mic" ] && [ "$mic_frames" -gt 20 ] \
    && [ "$rx" -ge 20 ] && awk "BEGIN{exit !($sched >= 0.9)}" && [ -n "$larry" ] && [ "$igor" = "hello Larry" ] \
    && [ "$ended" = "stopped false" ] && [ "$sent_tail" = "diagnostics,stt_stop,stop" ]; then
    ok "call ($label): start, ready, $mic_frames mic frames up, $rx frames / ${sched}s down, captions, hung up"
  else
    bad "call ($label): start $start ready '$ready' first mic '$first_mic' mic $mic_frames rx $rx scheduled $sched larry '$larry' igor '$igor' ended '$ended' last sent '$sent_tail'"
  fi
  lines=$(tail -n +"$((before + 1))" "$REPORT")
  local client up stopped diag
  client=$(jq -sr '.[-1].start.client // empty' <<<"$lines")
  up=$(jq -sr '.[-1].binary_frames // 0' <<<"$lines")
  stopped=$(jq -sr '.[-1].stopped // false' <<<"$lines")
  diag=$(jq -sr '.[-1].diagnostics_bytes // 0' <<<"$lines")
  if [ "$client" = "context-grabber" ] && [ "$up" -gt 20 ] && [ "$stopped" = "true" ] && [ "$diag" -gt 0 ]; then
    ok "call ($label): the bridge saw the client tag, $up mic frames, the dump ($diag bytes) and stop"
  else bad "call ($label): bridge report client '$client' frames $up stopped $stopped dump $diag"; fi
  failed=$(jq -c 'select(.type=="error" or ((.type|startswith("call_")) and .ok == false))' "$f")
  if [ -z "$failed" ]; then ok "call ($label): nothing failed"; else bad "call ($label): $failed"; fi
}
call_check synthetic synthetic
call_check "real audio" ""

xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
exit $fail
