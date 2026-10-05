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
# Story 182: with no voice chosen Adam counts; a choice left by hand on this simulator is forgotten first.
sqlite3 "$DOCS/SQLite/context-grabber.db" "DELETE FROM settings WHERE key='gym_count_voice'" 2>/dev/null || true
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
voices=$(jq -sr '[.[] | select(.type=="timer_cue") | .voice] | unique | join(",")' "$f")
if [ "$voices" = "adam" ]; then ok "voice: every cue by adam, the default"; else bad "voice: cues by '$voices'"; fi

# Story 106: the Live Activity is requested with the ready count, pushed once at each phase (not every second),
# and ended on DONE!, each accepted. A card an earlier launch left behind is ended at launch (reason leftover) and
# is not part of this workout. With Live Activities off, one `unavailable` line per session is what the app must say instead.
la=$(jq -sr '[.[] | select(.type=="live_activity" and .reason != "leftover" and .kind == "gymTimer")
  | "\(.action):\(.title // "")\(if .ok == false then "!" else "" end)"] | join(" ")' "$f")
if [ "$la" = "start:GET READY update:WORK update:REST update:WORK end:DONE!" ]; then
  ok "live activity: started, pushed at 3 phases, ended on DONE!"
elif [ "$la" = "unavailable:" ]; then ok "live activity: Live Activities are off on this simulator (logged once per session)"
else bad "live activity: '$la'"; fi

# Story 182: a launch hook picks the Australian woman for this visit; her first cue plays from her own file.
SIMCTL_CHILD_GRABBER_COUNT_VOICE=aussie SIMCTL_CHILD_GRABBER_TIMER="10,10,2" relaunch
wait_for timer_cue 20 || echo "      (timed out waiting for timer_cue)"
f=$(newest_log)
first=$(jq -sr '[.[] | select(.type=="timer_cue")][0] | "\(.cue) \(.voice) \(.ok)"' "$f")
errors=$(jq -c 'select(.type=="error")' "$f")
if [ "$first" = "three aussie true" ] && [ -z "$errors" ]; then ok "voice: the hook's aussie says three"
else bad "voice: first cue '$first', errors '$errors'"; fi

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

# Places (stories 040-047, 052, 055). A clean trail, then Context Grabber's real export (the 36 601-point fixture)
# imported by the hook, shifted by whole weeks so it falls in the last seven days.
FIXTURE="$(dirname "$0")/../../__tests__/fixtures/context-grabber.db"
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
rm -f "$DOCS/SQLite/context-grabber.db" "$DOCS/SQLite/context-grabber.db-journal"
cp -f "$FIXTURE" "$DOCS/import-fixture.db"
xcrun simctl privacy "$SIM" grant location-always "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl location "$SIM" set 47.641901,-122.304481
SIMCTL_CHILD_GRABBER_IMPORT_DB="import-fixture.db,recent" SIMCTL_CHILD_GRABBER_PLACES=open relaunch
wait_for places_open 30 || echo "      (timed out waiting for places_open)"
f=$(newest_log)
imp=$(jq -sr '[.[] | select(.type=="import")][0] | "\(.ok) \(.points_added) \(.points_already) \(.places_added)"' "$f")
opened=$(jq -sr '[.[] | select(.type=="places_open")][-1] | "\(.points) \(.known) \(.stays)"' "$f")
if [ "$imp" = "true 36601 0 4" ] && [ "$opened" = "36601 4 34" ]; then ok "places: imported 36601 points and 4 places; 34 stays, as the TypeScript makes"
else bad "places: import '$imp', open (points known stays) '$opened'"; fi
# Story 055: the same file again adds nothing.
SIMCTL_CHILD_GRABBER_IMPORT_DB="import-fixture.db,recent" SIMCTL_CHILD_GRABBER_PLACES=open relaunch
wait_for places_open 30 || echo "      (timed out waiting for places_open)"
f=$(newest_log)
imp=$(jq -sr '[.[] | select(.type=="import")][0] | "\(.ok) \(.points_added) \(.points_already) \(.places_added) \(.places_already)"' "$f")
if [ "$imp" = "true 0 36601 0 4" ]; then ok "places: a second import adds nothing"
else bad "places: second import '$imp'"; fi
failed=$(jq -c 'select(.type=="error")' "$f")
if [ -z "$failed" ]; then ok "places: no error events"; else bad "places: $failed"; fi

# Story 052: the export is a consistent copy with the whole trail and the places.
SIMCTL_CHILD_GRABBER_EXPORT=1 relaunch
wait_for export 20 || echo "      (timed out waiting for export)"
f=$(newest_log)
path=$(jq -sr '[.[] | select(.type=="export")][0].path // ""' "$f")
rows=$( [ -s "$path" ] && sqlite3 "$path" "select (select count(*) from locations) || ' ' || (select count(*) from known_places)" 2>/dev/null || echo "none")
if [ "$rows" = "36601 4" ]; then ok "places: export holds 36601 points and 4 places"
else bad "places: export '$path' rows '$rows'"; fi

# Story 040: the switch with Always granted records points as the simulator moves.
SIMCTL_CHILD_GRABBER_TRACKING=on relaunch
wait_for tracking 20 || echo "      (timed out waiting for tracking)"
xcrun simctl location "$SIM" start --speed=15 --interval=2 47.641901,-122.304481 47.6450,-122.3100 47.6500,-122.3200 >/dev/null 2>&1
wait_for location_point 30 || echo "      (timed out waiting for location_point)"
f=$(newest_log)
on=$(jq -sr '[.[] | select(.type=="tracking")][0] | "\(.on) \(.reason) \(.permission)"' "$f")
pts=$(jq -sr '[.[] | select(.type=="location_point")][0].count // 0' "$f")
if [ "$on" = "true hook always" ] && [ "$pts" -gt 0 ] 2>/dev/null; then ok "tracking: on with Always, $pts points stored in the first batch"
else bad "tracking: '$on', first batch '$pts'"; fi
# The switch survives a relaunch: recording resumes at launch.
relaunch
wait_for tracking 20 || echo "      (timed out waiting for tracking)"
f=$(newest_log)
on=$(jq -sr '[.[] | select(.type=="tracking")][0] | "\(.on) \(.reason)"' "$f")
if [ "$on" = "true launch" ]; then ok "tracking: resumed at launch"; else bad "tracking: relaunch '$on'"; fi

# Story 041: lowering retention to 7 days prunes at once (the fixture spans twelve days).
SIMCTL_CHILD_GRABBER_RETENTION=7 SIMCTL_CHILD_GRABBER_TRACKING=off relaunch
wait_for places_open 30 || echo "      (timed out waiting for places_open)"
f=$(newest_log)
pruned=$(jq -sr '[.[] | select(.type=="prune" and .reason=="lowered")][0] | "\(.retention_days) \(.removed)"' "$f")
off=$(jq -sr '[.[] | select(.type=="tracking")][-1] | "\(.on)"' "$f")
if [ "${pruned%% *}" = "7" ] && [ "${pruned##* }" -gt 0 ] 2>/dev/null && [ "$off" = "false" ]; then ok "places: retention 7 pruned ${pruned##* } points at once; tracking off"
else bad "places: prune '$pruned', tracking '$off'"; fi
failed=$(jq -c 'select(.type=="error")' "$f")
if [ -z "$failed" ]; then ok "places: no error events"; else bad "places: $failed"; fi
xcrun simctl location "$SIM" clear >/dev/null 2>&1 || true

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

# Stories 020, 029 (spec step 4): the exports equal, byte for byte, what the React Native app's own code makes of
# the same week. `fixture` answers from the file; `healthkit` from the simulator's Health store, which needs the
# access `just native-sim-health` grants once (skipped with a note when it has not). Needs typescript from
# node_modules (`npm ci`, or NODE_PATH pointing at a checkout that has it).
root="$(cd "$(dirname "$0")/../.." && pwd)"
expected="$HOME/tmp/agent/skill/mirror-smoke"
mirror_check() {  # $1 = fixture | healthkit
  local before=$fail
  SIMCTL_CHILD_GRABBER_MIRROR="$1" relaunch
  if ! wait_for mirror_fixture_done 120; then
    if [ "$1" = healthkit ]; then fail=$before; echo "skip  mirror ($1): no Health access on this simulator; run just native-sim-health"; return; fi
    bad "mirror ($1): no mirror_fixture_done"; return
  fi
  f=$(newest_log)
  mkdir -p "$expected/$1"
  TZ=$(jq -r .timeZone "$DOCS/exports/fixture.json") node --no-warnings "$root/scripts/native/make-mirror-expected.mjs" \
    --fixture "$DOCS/exports/fixture.json" --out "$expected/$1" >/dev/null
  if cmp -s "$DOCS/exports/summary.json" "$expected/$1/mirror-summary-expected.json" \
    && cmp -s "$DOCS/exports/raw.json" "$expected/$1/mirror-raw-expected.json"; then
    ok "mirror ($1): summary $(wc -c <"$DOCS/exports/summary.json" | tr -d ' ') B and raw byte-identical to the TypeScript"
  else bad "mirror ($1): exports differ from $expected/$1 (diff them)"; fi
  grabbed=$(jq -c 'select(.type=="mirror_grabbed") | {series, failed_queries}' "$f" | tail -1)
  errors=$(jq -c 'select(.type=="error" or .type=="health_query_failed")' "$f")
  if [ "$(jq -r .series <<<"$grabbed")" = "10" ] && [ -z "$errors" ]; then ok "mirror ($1): 10 series, nothing failed"
  else bad "mirror ($1): $grabbed $errors"; fi
}
mirror_check fixture
mirror_check healthkit

xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
exit $fail
