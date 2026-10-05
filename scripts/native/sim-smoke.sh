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

# Story 106: the Live Activity is requested with the ready count, pushed once at each phase (not every second),
# and ended on DONE!, each accepted. A card an earlier launch left behind is ended at launch (reason leftover) and
# is not part of this workout. With Live Activities off, one `unavailable` line per session is what the app must say instead.
la=$(jq -sr '[.[] | select(.type=="live_activity" and .reason != "leftover" and .kind == "gymTimer")
  | "\(.action):\(.title // "")\(if .ok == false then "!" else "" end)"] | join(" ")' "$f")
if [ "$la" = "start:GET READY update:WORK update:REST update:WORK end:DONE!" ]; then
  ok "live activity: started, pushed at 3 phases, ended on DONE!"
elif [ "$la" = "unavailable:" ]; then ok "live activity: Live Activities are off on this simulator (logged once per session)"
else bad "live activity: '$la'"; fi

# Stories 160, 163, 165: two cycles of 2 s breaths with the voice. Every step is noticed on its second, each
# phrase is a bundled file that played (none fell back to the phone's voice), and the screen lock is given back.
SIMCTL_CHILD_GRABBER_BREATHE="2,2,voice" relaunch
wait_for breath_finished 40 || echo "      (timed out waiting for breath_finished)"
sleep 3  # "Well done", and the Live Activity's end, which ActivityKit takes most of a second to accept
f=$(newest_log)
steps=$(jq -sr '
  ([.[] | select(.type=="breath_start")][0]) as $s |
  [.[] | select(.type=="breath_phase" or .type=="breath_finished")
       | "\(((.t - $s.t - $s.lead_in_ms) / 1000 + 0.3) | floor):\(.phase // "done")"] | join(" ")' "$f")
want="0:inhale 2:holdFull 4:exhale 6:holdEmpty 8:inhale 10:holdFull 12:exhale 14:holdEmpty 16:done"
late=$(jq -s '[.[] | select(.type=="breath_phase" or .type=="breath_finished") | .late_ms] | max' "$f")
if [ "$steps" = "$want" ] && [ "${late:-999}" -le 150 ] 2>/dev/null; then ok "breathe: 8 steps and the finish, each on its second (worst ${late} ms late)"
else bad "breathe: steps '$steps' (worst ${late} ms late)"; fi
said=$(jq -sr '[.[] | select(.type=="breath_cue") | "\(.name)\(if .ok and (.fallback|not) then "" else "!" end)"] | join(" ")' "$f")
want_said="breath-begin breath-in breath-hold breath-out breath-hold-low breath-in breath-hold breath-out breath-hold-low breath-done"
awake=$(jq -sr '[.[] | select(.type=="keep_awake") | "\(.on)"] | join(" ")' "$f")
if [ "$said" = "$want_said" ] && [ "$awake" = "true false" ]; then ok "breathe: 10 phrases from their files, screen lock given back"
else bad "breathe: said '$said', keep_awake '$awake'"; fi
# Story 169: the keepalive runs for the session, so a locked phone keeps it going, and stops at the end.
alive=$(jq -sr '[.[] | select(.type=="breath_keepalive") | "\(.action)\(if .ok then "" else "!" end)"] | join(" ")' "$f")
if [ "$alive" = "start stop" ]; then ok "breathe: keepalive for the session, stopped at the end"
else bad "breathe: keepalive '$alive'"; fi
# Story 166: the Live Activity appears at Begin saying Ready, is pushed once per step, and ends on Done.
la=$(jq -sr '[.[] | select(.type=="live_activity" and .reason != "leftover" and .kind == "breathe")
  | "\(.action):\(.title // "")\(if .ok == false then "!" else "" end)"] | join(" ")' "$f")
if [ "$la" = "start:Ready update:Inhale update:Hold update:Exhale update:Hold update:Inhale update:Hold update:Exhale update:Hold end:Done" ]; then
  ok "breathe: live activity started at Begin, pushed at 8 steps, ended on Done"
elif [ "$la" = "unavailable:" ]; then ok "breathe: Live Activities are off on this simulator (logged once per session)"
else bad "breathe: live activity '$la'"; fi

# Story 164: the same with tones, one cycle of 1 s breaths.
SIMCTL_CHILD_GRABBER_BREATHE="1,1,tone" relaunch
wait_for breath_finished 20 || echo "      (timed out waiting for breath_finished)"
sleep 1
f=$(newest_log)
tones=$(jq -sr '[.[] | select(.type=="breath_cue") | "\(.name)\(if .ok then "" else "!" end)"] | join(" ")' "$f")
if [ "$tones" = "rising tick falling tick closing" ]; then ok "breathe: a tone per step and the closing tone"
else bad "breathe: tones '$tones'"; fi
failed=$(jq -c 'select(.type=="error" or ((.type|startswith("breath_")) and .ok == false))' "$f")
if [ -z "$failed" ]; then ok "breathe: nothing failed"; else bad "breathe: $failed"; fi

# Story 162: paused 3 s into a 6 s inhale (as a tap on the circle would), the session stays put: no further step,
# no finish, while well past when the hold was due.
SIMCTL_CHILD_GRABBER_BREATHE="6,1,off,3" relaunch
wait_for breath_pause 20 || echo "      (timed out waiting for breath_pause)"
sleep 5
f=$(newest_log)
paused=$(jq -sr '[.[] | select(.type=="breath_pause") | "\(.reason):\(.phase)"] | join(" ")' "$f")
after=$(jq -sr '[.[] | select(.type=="breath_phase" or .type=="breath_finished") | .phase // "done"] | join(" ")' "$f")
if [ "$paused" = "hook:inhale" ] && [ "$after" = "inhale" ]; then ok "breathe: paused mid-inhale, nothing moved on"
else bad "breathe: pauses '$paused', steps '$after'"; fi

xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
exit $fail
