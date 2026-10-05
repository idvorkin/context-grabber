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

# Stories 129, 133: the card. An open deals; Think of a card counts five seconds face down and deals a different card;
# Never mind mid-count leaves the open's card face up; the tap count is remembered across launches.
SIMCTL_CHILD_GRABBER_CARD=think relaunch
wait_for card_think 20 || echo "      (timed out waiting for card_think)"
sleep 7  # the count is five seconds
f=$(newest_log)
opened=$(jq -sr '[.[] | select(.type=="card_open")][0] | "\(.from) \(.think)"' "$f")
dealt=$(jq -sr '[.[] | select(.type=="card_deal") | "\(.how):\(.card)"] | join(" ")' "$f")
think=$(jq -sr '[.[] | select(.type=="card_think") | .action] | join(" ")' "$f")
open_card=$(jq -sr '[.[] | select(.type=="card_deal" and .how=="open")][0].card' "$f")
think_card=$(jq -sr '[.[] | select(.type=="card_deal" and .how=="think")][0].card' "$f")
ms=$(jq -s '([.[] | select(.type=="card_think" and .action=="start")][0].t) as $a
  | ([.[] | select(.type=="card_think" and .action=="done")][0].t) as $b | $b - $a' "$f")
if [ "$opened" = "hook true" ] && [ "$think" = "start done" ] && [ "$dealt" = "open:$open_card think:$think_card" ] \
  && [ "$open_card" != "$think_card" ] && [ "$ms" -ge 4900 ] && [ "$ms" -le 5400 ]; then
  ok "card: open deals $open_card, think reveals $think_card after $ms ms"
else bad "card: open '$opened', deals '$dealt', think '$think', $ms ms"; fi
nonce1=$(jq -sr '[.[] | select(.type=="card_deal")][-1].nonce' "$f")

SIMCTL_CHILD_GRABBER_CARD=never_mind relaunch
wait_for card_think 20 || echo "      (timed out waiting for card_think)"
sleep 4  # cancelled two seconds in
f=$(newest_log)
think=$(jq -sr '[.[] | select(.type=="card_think") | .action] | join(" ")' "$f")
open_card=$(jq -sr '[.[] | select(.type=="card_deal" and .how=="open")][0].card' "$f")
kept=$(jq -sr '[.[] | select(.type=="card_think" and .action=="cancel")][0] | "\(.card) \(.why) \(.left)"' "$f")
deals=$(jq -s '[.[] | select(.type=="card_deal")] | length' "$f")
nonce2=$(jq -sr '[.[] | select(.type=="card_deal")][0].nonce' "$f")
if [ "$think" = "start cancel" ] && [ "$kept" = "$open_card never_mind 3" ] && [ "$deals" = "1" ] \
  && [ "$nonce2" -gt "$nonce1" ]; then
  ok "card: never mind keeps $open_card face up; tap count $nonce1 → $nonce2 across launches"
else bad "card: think '$think', cancel '$kept' (open $open_card), $deals deals, count $nonce1 → $nonce2"; fi
failed=$(jq -c 'select(.type=="error")' "$f")
if [ -z "$failed" ]; then ok "card: no error events"; else bad "card: $failed"; fi

xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
exit $fail
