#!/usr/bin/env bash
# Rung 2 of the native test ladder: run the simulator build from launch hooks and judge it from the session log.
# Usage: sim-smoke.sh <simulator name or udid> <bundle id> <app path>
set -euo pipefail
SIM=$("$(dirname "$0")/sim-udid.sh" "$1"); BUNDLE=$2; APP=$3  # one device, whatever runtimes share the name
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"
# BugKit's smoke-lib: launch freshness (wait only for a log newer than the launch), a timeout that fails the run,
# error events, the stash; this script keeps CG's checks, fixtures and hooks. From the checkout SwiftPM pinned, else
# ~/gits/bug-kit.
root=$(cd "$(dirname "$0")/../.." && pwd)
BUG_KIT=$(\ls -d "$root/native/Build/SourcePackages/checkouts/bug-kit" 2>/dev/null || echo ~/gits/bug-kit)
# BugKit's wait_for looks every SMOKE_POLL seconds, 2 by default, and the smoke waits on it 22 times: 1 halves the slack.
# (Whole seconds only: its count is integer arithmetic.)
export SMOKE_POLL=${SMOKE_POLL:-1}
# shellcheck source=/dev/null
source "$BUG_KIT/scripts/smoke-lib.sh"
smoke_init "$SIM" "$BUNDLE"
DOCS=$SMOKE_DOCS
relaunch() { launch "$@"; }  # CG's call sites pass their hooks as SIMCTL_CHILD_* assignments in front
bad() { not_ok "$@"; }
# #801: a failed check's session log is pruned or overwritten before anyone reads it, so the check keeps what it judged.
keep_evidence() {  # keep_evidence <check> <file>...: copies them to $SMOKE_EVIDENCE/<check>-<time>/ and says where
  local dir; dir="${SMOKE_EVIDENCE:-$HOME/tmp/agent/notes/smoke}/$1-$(date +%Y%m%d-%H%M%S)"; shift
  if mkdir -p "$dir" && cp -f "$@" "$dir/"; then echo "      evidence kept in $dir"
  else echo "      could not keep evidence in $dir"; fi
}
listening() {  # listening <port>: waits up to 5 s for a fake server to take connections, a tenth of a second at a time; the caller judges
  local tries=0
  until nc -z localhost "$1" 2>/dev/null || [ "$tries" -ge 50 ]; do
    tries=$((tries + 1))
    sleep 0.1
  done
}

# Igor, 2026-11-01: only the features a change touched (SMOKE_ONLY, which the recipe takes from smoke-features.sh;
# unset, empty or "all" runs everything, "none" only the checks that always run). The launch and report checks just below always run.
want() { [[ -z "${SMOKE_ONLY:-}" || "$SMOKE_ONLY" == all || ",$SMOKE_ONLY," == *",$1,"* ]]; }
echo "smoke: ${SMOKE_ONLY:-all}"

# #419: a locked Mac seems to starve the simulator's audio (timer cues late or empty, keepalive ok:false, breathe
# silent), inferred from comparing runs. Said at both ends because the screen can lock mid-run. The audio checks still
# run and fail on purpose, to keep the evidence: an audio failure under this line isn't read as a regression.
mac_locked_note() {
  case "$(ioreg -n Root -d1)" in
    *'"CGSSessionScreenIsLocked"=Yes'*) echo "smoke: the Mac is locked ($1); audio failures here don't count, rerun unlocked (#419)" ;;
  esac
}
mac_locked_note "at the start"

# Igor, 2026-11-01: the app under test is muted, not the Mac (GRABBER_SILENT on every launch: its players at zero,
# every cue still played and logged), so the timer's counts, the breathing voice and the call stay out of the room.
export SIMCTL_CHILD_GRABBER_SILENT=1
BRIDGE=; DROP=; COCKPIT=
cleanup() {
  # shellcheck disable=SC2086  # each is empty when its section did not run
  kill $BRIDGE $DROP $COCKPIT 2>/dev/null || true
  unstash  # smoke-lib's: puts stashed data back
}
trap cleanup EXIT

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
# BugKit names the log by its path under Documents (logs/<file>).
if [ "$got_note" = "$note" ] && [ "$got_log" = "logs/$(basename "$f")" ] && [ "$screen" = "home" ] \
  && [ -n "$shot" ] && [ -s "$DOCS/$shot" ]; then ok "report: note, screen, log $got_log, $shot"
else bad "report: note '$got_note' log '$got_log' screen '$screen' screenshot '$shot'"; fi

# No launch may log an error.
errors=$(jq -c 'select(.type=="error")' "$f")
if [ -z "$errors" ]; then ok "report: no error events"; else bad "report: error events: $errors"; fi

wait_jq() {  # like wait_for, on any jq filter; looks five times a second, so a line costs at most 0.2 s past its arrival
  local waited=0
  while [ "$waited" -lt $(($2 * 5)) ]; do
    sleep 0.2; waited=$((waited + 1))
    local f; f=$(newest_log)
    [ -n "$f" ] && [ "$f" != "$previous_log" ] && [ -n "$(jq -c "$1" "$f" 2>/dev/null)" ] && return 0
  done
  fail=1
  return 1
}

if want cockpit; then
# Stories 096, 097, 200: the Cockpit screen on the bundled bridge test page, which speaks only the protocol
# (docs/cockpit-audio-bridge.md): it asks for the roster on audio.ready, sets an output and an input, asks for a
# missing microphone, says its call went live and ended, and reports the round trip as getRoute("roundtrip:<inputs>:
# tagged|untagged") — so the log alone shows the page received a device list and its address carried the tag.
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

fi  # cockpit

if want whiteboard; then
# Stories 340, 348, 347: the whiteboard tile opens the boards, the list read (and any single board from before the
# list moved into it), iCloud tried: on a simulator with no iCloud account the sync is skipped, never an error.
SIMCTL_CHILD_GRABBER_WHITEBOARD=open relaunch
wait_jq 'select(.type=="whiteboard_sync")' 30 || echo "      (timed out waiting for whiteboard_sync)"
f=$(newest_log)
opened=$(jq -sr '[.[] | select(.type=="ui" and .action=="open_whiteboard")][0].from // ""' "$f")
boards=$(jq -sr '[.[] | select(.type=="whiteboard" and .action=="list")][0].boards // ""' "$f")
synced=$(jq -sr '[.[] | select(.type=="whiteboard_sync")][0] | "\(.ok) \(.skipped // .message // "")"' "$f")
errors=$(jq -c 'select(.type=="error")' "$f")
if [ "$opened" = "hook" ] && [[ "$boards" =~ ^[0-9]+$ ]] && [[ "$synced" == "true "* || "$synced" == "false account_"* ]] \
  && [ -z "$errors" ]; then
  ok "whiteboard: the boards opened from the hook, $boards board(s), iCloud: $synced, no error events"
else bad "whiteboard: open_whiteboard from '$opened', boards '$boards', sync '$synced', errors: $errors"; fi
# Story 407: a board's grid turned on from the hook, logged with its board. How it looks is WhiteboardTurnUITests'.
SIMCTL_CHILD_GRABBER_BOARD_FIXTURE=smoke-grid SIMCTL_CHILD_GRABBER_WHITEBOARD_GRID=on \
  SIMCTL_CHILD_GRABBER_LINK="grabbernative://whiteboard?board=smoke-grid" relaunch
wait_jq 'select(.type=="whiteboard" and .action=="grid_on")' 30 || echo "      (timed out waiting for grid_on)"
f=$(newest_log)
grid=$(jq -sr '[.[] | select(.type=="whiteboard" and .action=="grid_on")][0].board // ""' "$f")
errors=$(jq -c 'select(.type=="error")' "$f")
if [ "$grid" = "smoke-grid" ] && [ -z "$errors" ]; then ok "whiteboard: the grid on from the hook, no error events"
else bad "whiteboard: grid_on for board '$grid', errors: $errors"; fi
# Story 658: a board drawn on the old canvas opens on paper to look at only, its 40 strokes moved onto the first page
# (the ink's box starts at the page's margin).
SIMCTL_CHILD_GRABBER_BOARD_FIXTURE=smoke-old-canvas SIMCTL_CHILD_GRABBER_BOARD_FIXTURE_OLD_INK=40 \
  SIMCTL_CHILD_GRABBER_LINK="grabbernative://whiteboard?board=smoke-old-canvas" relaunch
wait_jq 'select(.type=="whiteboard" and .action=="paper_open")' 30 || echo "      (timed out waiting for paper_open)"
f=$(newest_log)
opened=$(jq -sr '[.[] | select(.type=="whiteboard" and .action=="open")][0] | "\(.editable) \(.old_canvas)"' "$f")
shown=$(jq -sr '[.[] | select(.type=="whiteboard" and .action=="paper_open")][0] | "\(.strokes) \(.editable) \(.ink[0]) \(.ink[1])"' "$f")
errors=$(jq -c 'select(.type=="error")' "$f")
if [ "$opened" = "false true" ] && [ "$shown" = "40 false 40 40" ] && [ -z "$errors" ]; then
  ok "whiteboard: an old-canvas board opened look-only on paper, 40 strokes at the first page's corner, no error events"
else bad "whiteboard: old-canvas board open '$opened', shown '$shown', errors: $errors"; fi
fi  # whiteboard

if want timer; then
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

# Story 187's own rules are host tests, not a relaunch here: each voice's files on disk and which it plays
# (CountVoiceTests.testEveryVoiceHasEveryCueOnDisk, testIgorPlaysTheSharedFilesAndTheOthersTheirOwn). The run above
# still plays a voice's own files on the simulator.

fi  # timer

if want breathe; then
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

# Story 162's pause is a host test, not a relaunch here: nothing moves on while paused and a resume picks up mid-step
# (BreathRunTests.testPauseFreezesEverythingAndResumeContinuesMidPhaseWithNoJump). GRABBER_BREATHE's fourth field
# still pauses by itself, for watching the paused circle by hand.

fi  # breathe

if want places; then
# Places (stories 040-047, 052, 055). A clean trail, then Context Grabber's real export (the 36 601-point fixture)
# imported by the hook, shifted by whole days so its newest point falls in the last 24 hours.
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
# Story 055: the same file again adds nothing, shifted as the hook shifts it, is a host test, not a relaunch here
# (PlacesFixtureTests.testImportTheRealExportTwice, testARecentImportTwiceAddsNothingTheSecondTime).
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

# Story 270: the archive run against an unreachable Cockpit (the trail's first page fails with the reason, the run
# stops, the next foreground is due) is ArchiveTests on the host; the phone runs it for real.

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

fi  # places

if want call; then
# Stories 080–084, 093: a call to a fake bridge on this Mac (scripts/native/fake-bridge.py), started by the launch
# hook and hung up by it after 8 s. Judged from the session log and the bridge's own report: the start frame went up
# with the client tag, mic frames flowed up, PCM came down and was scheduled, captions arrived, and the hang-up
# sent the dump, stt_stop and stop and ended as "stopped". Once with synthetic audio (the protocol path, whatever
# the simulator's audio does), once with the real engine (voice processing, the tap, the player node).
xcrun simctl privacy "$SIM" grant microphone "$BUNDLE" 2>/dev/null || true
PORT=${CALL_PORT:-8799}
REPORT=$(mktemp -t fake-bridge); : >"$REPORT"
# Taken already, another bridge would answer instead; checked first, as the wait below can't tell whose it is.
nc -z localhost "$PORT" 2>/dev/null && bad "call: port $PORT is taken before the fake bridge started"
"$(dirname "$0")/fake-bridge.py" "$PORT" "$REPORT" >/dev/null 2>&1 &
BRIDGE=$!
listening "$PORT"
# Another bridge already on the port would answer instead and leave this report empty.
kill -0 "$BRIDGE" 2>/dev/null || bad "call: the fake bridge did not start on port $PORT (is one already running?)"
call_check() {  # $1: label, $2: audio (synthetic or empty)
  local label=$1 lines before
  before=$(wc -l <"$REPORT" | tr -d ' ')
  SIMCTL_CHILD_GRABBER_CALL="ws://localhost:$PORT" SIMCTL_CHILD_GRABBER_CALL_AUDIO="$2" relaunch
  wait_for call_ended 30 || echo "      (timed out waiting for call_ended)"
  sleep 2
  f=$(newest_log)
  local start ready first_mic mic_frames rx sched larry igor igor_sent restated ended sent_tail failed
  start=$(jq -sr '[.[] | select(.type=="call_sent" and .frame=="start")] | length' "$f")
  ready=$(jq -sr '[.[] | select(.type=="call_ready")][0].out_rate // empty' "$f")
  first_mic=$(jq -sr '[.[] | select(.type=="call_mic" and .action=="first_frame")][0].rate // empty' "$f")
  mic_frames=$(jq -sr '[.[] | select(.type=="call_ended")][0].mic_frames // 0' "$f")
  rx=$(jq -sr '[.[] | select(.type=="call_ended")][0].rx_frames // 0' "$f")
  sched=$(jq -sr '[.[] | select(.type=="call_ended")][0].scheduled_s // 0' "$f")
  larry=$(jq -sr '[.[] | select(.type=="call_caption" and .who=="larry")][0].text // empty' "$f")
  igor=$(jq -sr '[.[] | select(.type=="call_caption" and .who=="igor")][0].text // empty' "$f")
  # Story 216: two sentences sent before Larry answers are two rows, each sent; the late final is not a third.
  igor_sent=$(jq -sr '[.[] | select(.type=="call_caption" and .who=="igor") | "\(.text)/\(.sent)"] | join(",")' "$f")
  restated=$(jq -sr '[.[] | select(.type=="call_caption_restated")] | length' "$f")
  ended=$(jq -sr '[.[] | select(.type=="call_ended")][0] | "\(.reason) \(.badly)"' "$f")
  sent_tail=$(jq -sr '[.[] | select(.type=="call_sent") | .frame] | .[-3:] | join(",")' "$f")
  if [ "$start" = "1" ] && [ "$ready" = "16000" ] && [ -n "$first_mic" ] && [ "$mic_frames" -gt 20 ] \
    && [ "$rx" -ge 20 ] && awk "BEGIN{exit !($sched >= 0.9)}" && [ -n "$larry" ] && [ "$igor" = "hello Larry" ] \
    && [ "$igor_sent" = "hello Larry/true,are you there/true" ] && [ "$restated" = "1" ] \
    && [ "$ended" = "stopped false" ] && [ "$sent_tail" = "diagnostics,stt_stop,stop" ]; then
    ok "call ($label): start, ready, $mic_frames mic frames up, $rx frames / ${sched}s down, captions, hung up"
  else
    bad "call ($label): start $start ready '$ready' first mic '$first_mic' mic $mic_frames rx $rx scheduled $sched larry '$larry' igor '$igor' sent '$igor_sent' restated $restated ended '$ended' last sent '$sent_tail'"
    # #364: the heals behind a short call, with what the mic and the playback held at each.
    jq -c 'select(.type=="call_heal")' "$f" | sed 's/^/      heal /'
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
  # #584: the simulator has no archive URL on purpose (the fixture call never reaches the real archive), and
  # the call's own trouble rule already lets that ending pass.
  failed=$(jq -c 'select(.type=="error" or ((.type|startswith("call_")) and .ok == false
    and (.type != "call_archive" or .reason != "no archive URL")))' "$f")
  if [ -z "$failed" ]; then ok "call ($label): nothing failed"; else bad "call ($label): $failed"; fi
}
call_check synthetic synthetic
call_check "real audio" ""

# Story 248: a call that goes wrong files one BugKit automatic report with the call's log; a clean call files none.
# The second fake bridge cuts every connection.
clean=$(jq -s '[.[] | select(.type=="bug_report_auto")] | length' "$(newest_log)")
if [ "$clean" = "0" ]; then ok "call: a clean call files no automatic report"; else bad "call: a clean call filed $clean automatic report(s)"; fi
stash bugs-auto.json  # an earlier run's ten-minute window would skip the first report; put back at exit
DROP_PORT=$((PORT + 1))
DROP_REPORT=$(mktemp -t fake-bridge-drop); : >"$DROP_REPORT"
nc -z localhost "$DROP_PORT" 2>/dev/null && bad "trouble: port $DROP_PORT is taken before the dropping fake bridge started"
"$(dirname "$0")/fake-bridge.py" "$DROP_PORT" "$DROP_REPORT" drop >/dev/null 2>&1 &
DROP=$!
listening "$DROP_PORT"
kill -0 "$DROP" 2>/dev/null || bad "trouble: the dropping fake bridge did not start on port $DROP_PORT"
trouble_call() {
  SIMCTL_CHILD_GRABBER_CALL="ws://localhost:$DROP_PORT" SIMCTL_CHILD_GRABBER_CALL_AUDIO=synthetic relaunch
  wait_for call_ended 60 || echo "      (timed out waiting for call_ended)"
  sleep 3
}
trouble_call
f=$(this_log)
last=$(tail -1 "$DOCS/bugs.jsonl" 2>/dev/null || echo '{}')
src=$(jq -r '.source // empty' <<<"$last"); why=$(jq -r '.reason // empty' <<<"$last")
folder=$(jq -r '.folder // empty' <<<"$last"); files=$(jq -r '(.files // []) | join(",")' <<<"$last")
logged=$(jq -s '[.[] | select(.type=="bug_report_auto")] | length' "$f")
dropped=$(jq -s '[.[] | select(.dropped == true)] | length' "$DROP_REPORT")
# BugKit lists a report's files by their path under Documents.
if [ "$src" = "auto" ] && [ "$why" = "call_trouble" ] && [[ ",$files," == *",$folder/call-log.txt,"* ]] \
  && [ -s "$DOCS/$folder/call-log.txt" ] && [ "$logged" = "1" ] && [ "$dropped" -ge 1 ]; then
  ok "trouble: the dropped call filed one automatic report, $folder with $files"
else
  bad "trouble: source '$src' reason '$why' folder '$folder' files '$files' bug_report_auto $logged bridge drops $dropped"
fi
# A second within ten minutes, after a relaunch, is skipped: BugKit's host tests, not a relaunch here
# (AutoReportTests.oneReportPerReasonPerWindow, theWindowHoldsAcrossARelaunch, with the 600 s window the app keeps).
kill "$DROP" 2>/dev/null || true

fi  # call

if want mirror; then
# Stories 020, 029 (spec step 4): the grab runs end to end on the simulator, every series arrives and no query fails.
# `fixture` answers from the file; `healthkit` from the simulator's Health store, which needs the access
# `just native-sim-health` grants once (skipped with a note when it has not). Each run's summary and raw must equal,
# byte for byte, the fixture code path over that run's own fixture.json, the path MirrorFixtureTests pins on the host
# against the React Native app's own exports (the TypeScript that made them was removed 2026-10-17). So HealthKit's
# units, dates and values are checked: a wrong adapter can still write ten nonempty series.
MIRROR_RUNS=$(mktemp -d -t mirror-runs)
mirror_check() {  # $1 = fixture | healthkit
  local before=$fail
  mkdir -p "$DOCS/exports"
  : >"$DOCS/exports/fixture.json"; : >"$DOCS/exports/summary.json"; : >"$DOCS/exports/raw.json"
  SIMCTL_CHILD_GRABBER_MIRROR="$1" relaunch
  if ! wait_for mirror_fixture_done 120; then
    if [ "$1" = healthkit ]; then fail=$before; echo "skip  mirror ($1): no Health access on this simulator; run just native-sim-health"; return; fi
    bad "mirror ($1): no mirror_fixture_done"; return
  fi
  f=$(newest_log)
  mkdir -p "$MIRROR_RUNS/$1"
  cp -f "$DOCS/exports/fixture.json" "$DOCS/exports/summary.json" "$DOCS/exports/raw.json" "$MIRROR_RUNS/$1/"
  if [ -s "$MIRROR_RUNS/$1/fixture.json" ] && [ -s "$MIRROR_RUNS/$1/summary.json" ] && [ -s "$MIRROR_RUNS/$1/raw.json" ] \
    && MIRROR_COMPARE_DIR="$MIRROR_RUNS/$1" swift test --package-path "$root/native/ContextCore" \
      --filter MirrorFixtureTests/testSimulatorExportsMatchTheFixturePathOverTheirOwnFixture >/dev/null 2>&1; then
    ok "mirror ($1): summary $(wc -c <"$MIRROR_RUNS/$1/summary.json" | tr -d ' ') B and raw byte-identical to the fixture path over its own fixture"
  else bad "mirror ($1): exports missing or differ from the fixture path over its own fixture ($MIRROR_RUNS/$1; rerun the test there with MIRROR_COMPARE_DIR for the diff)"; fi
  grabbed=$(jq -c 'select(.type=="mirror_grabbed") | {series, failed_queries}' "$f" | tail -1)
  errors=$(jq -c 'select(.type=="error" or .type=="health_query_failed")' "$f")
  if [ "$(jq -r .series <<<"$grabbed")" = "10" ] && [ -z "$errors" ]; then ok "mirror ($1): 10 series, nothing failed"
  else bad "mirror ($1): $grabbed $errors"; fi
}
mirror_check fixture
mirror_check healthkit

fi  # mirror

if want drill; then
# Story 220: Drill the stack opens the trainer's drill over the card screen, in the direction asked for.
SIMCTL_CHILD_GRABBER_DRILL=mixed relaunch
wait_for drill 20 || echo "      (timed out waiting for drill)"
f=$(newest_log)
drill=$(jq -sr '[.[] | select(.type=="drill")][0] | "\(.how) \(.mode) \(.positions)"' "$f")
card=$(jq -sr '[.[] | select(.type=="ui" and .action=="open_card")][0].from // ""' "$f")
if [ "$card" = "hook" ] && [[ "$drill" =~ ^open\ mixed\ (52|27)$ ]]; then ok "drill: opened over the card, $drill"
else bad "drill: open_card '$card', drill '$drill'"; fi

fi  # drill

if want chat; then
# Chat (spec 2026-10-25): against a fake Cockpit (scripts/native/fake-cockpit.py), a message written for a new thread
# goes up once as POST /chat with its id and the app as source, and one written in a thread as POST /chat/<key>;
# opening that thread reads it and marks it seen. The log names the thread, never the text.
CHAT_PORT=${CHAT_PORT:-8797}
CHAT_REPORT=$(mktemp -t fake-cockpit); : >"$CHAT_REPORT"
nc -z localhost "$CHAT_PORT" 2>/dev/null && bad "chat: port $CHAT_PORT is taken before the fake Cockpit started"
"$(dirname "$0")/fake-cockpit.py" "$CHAT_PORT" "$CHAT_REPORT" >/dev/null 2>&1 &
COCKPIT=$!
listening "$CHAT_PORT"
kill -0 "$COCKPIT" 2>/dev/null || bad "chat: the fake Cockpit did not start on port $CHAT_PORT"
SIMCTL_CHILD_GRABBER_CHAT_URL="http://localhost:$CHAT_PORT" SIMCTL_CHILD_GRABBER_CHAT_SEND="new|smoke: a new thread" relaunch
wait_for chat 20 || echo "      (timed out waiting for chat)"
sleep 2
f=$(newest_log)
sent=$(jq -sr '[.[] | select(.type=="chat" and .action=="sent" and .new_thread==true)][0].thread // ""' "$f")
posts=$(jq -sr '[.[] | select(.method=="POST" and .path=="/chat" and .body.source=="app" and .body.title=="smoke: a new thread")] | length' "$CHAT_REPORT")
leaked=$(grep -c "smoke: a new thread" "$f" || true)
if [[ "$sent" == igor2-88g.* ]] && [ "$posts" = 1 ] && [ "$leaked" = 0 ]; then ok "chat: a new thread went up once ($sent)"
else bad "chat: sent '$sent', POST /chat x$posts, text in the log x$leaked"; fi
SIMCTL_CHILD_GRABBER_CHAT_URL="http://localhost:$CHAT_PORT" SIMCTL_CHILD_GRABBER_CHAT_SEND="igor2-88g.900|smoke: and a reply" \
  SIMCTL_CHILD_GRABBER_LINK="grabbernative://chat?thread=igor2-88g.900" relaunch
wait_for chat 20 || echo "      (timed out waiting for chat)"
sleep 3
f=$(newest_log)
replied=$(jq -sr '[.[] | select(.method=="POST" and .path=="/chat/igor2-88g.900")] | length' "$CHAT_REPORT")
read_it=$(jq -sr '[.[] | select(.method=="GET" and .path=="/chat/igor2-88g.900")] | length' "$CHAT_REPORT")
seen=$(jq -sr '[.[] | select(.path=="/chat-seen" and .body.thread=="igor2-88g.900")] | length' "$CHAT_REPORT")
opened=$(jq -sr '[.[] | select(.type=="ui" and .action=="open_chat_thread")][0].thread // ""' "$f")
if [ "$replied" = 1 ] && [ "$read_it" -ge 1 ] && [ "$seen" -ge 1 ] && [ "$opened" = igor2-88g.900 ]; then
  ok "chat: a reply went to its thread once, which opened, was read and marked seen"
else bad "chat: POST /chat/<key> x$replied, GET x$read_it, seen x$seen, opened '$opened'"; fi
failed=$(jq -c 'select(.type=="error")' "$f")
if [ -z "$failed" ]; then ok "chat: no error events"; else bad "chat: $failed"; fi
# Story 306: a thread's picture opened full size from the hook; ChatImageUITests taps its way back.
SIMCTL_CHILD_GRABBER_CHAT_URL="http://localhost:$CHAT_PORT" SIMCTL_CHILD_GRABBER_CHAT_IMAGE=open \
  SIMCTL_CHILD_GRABBER_LINK="grabbernative://chat?thread=igor2-88g.592" relaunch
wait_jq 'select(.type=="ui" and .action=="open_chat_image")' 20 || echo "      (timed out waiting for open_chat_image)"
f=$(newest_log)
pictured=$(jq -sr '[.[] | select(.type=="ui" and .action=="open_chat_image")] | length' "$f")
failed=$(jq -c 'select(.type=="error")' "$f")
if [ "$pictured" -ge 1 ] && [ -z "$failed" ]; then ok "chat: a picture opened full size from the hook, no error events"
else bad "chat: open_chat_image x$pictured, errors: $failed"; fi
# Stories 518-519, 540-541 (#629): the hold menu's choices tap themselves on Larry's newest; ChatReactionUITests holds it for real.
# #801: an earlier run's Yes stays in the simulator's outbox, and this fake Cockpit never heard it, so the thread would
# show it as still on its way and Larry's question would not be the newest. The thread starts as the Cockpit has it.
xcrun simctl terminate "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
forgot=$("$(dirname "$0")/forget-chat-thread.sh" "$SIM" "$BUNDLE" igor2-88g.629) || bad "chat: the outbox's leftovers for igor2-88g.629 could not be removed"
SIMCTL_CHILD_GRABBER_CHAT_URL="http://localhost:$CHAT_PORT" SIMCTL_CHILD_GRABBER_CHAT_HOLD=yes \
  SIMCTL_CHILD_GRABBER_LINK="grabbernative://chat?thread=igor2-88g.629" relaunch
wait_jq 'select(.type=="chat" and .action=="sent" and .thread=="igor2-88g.629")' 20 || echo "      (timed out waiting for the Yes to send)"
f=$(newest_log)
reacted=$(jq -sr '[.[] | select(.type=="chat" and .action=="reaction" and .reaction=="yes" and .thread=="igor2-88g.629" and .newest==true)] | length' "$f")
yes_posts=$(jq -sr '[.[] | select(.method=="POST" and .path=="/chat/igor2-88g.629" and .chars==3)] | length' "$CHAT_REPORT")
failed=$(jq -c 'select(.type=="error")' "$f")
if [ "$reacted" = 1 ] && [ "$yes_posts" = 1 ] && [ -z "$failed" ]; then ok "chat: Yes on the newest went up once as the bare word, no error events"
else
  bad "chat: reaction x$reacted, POST of three characters x$yes_posts, outbox leftovers removed x${forgot:-?}, errors: $failed"
  keep_evidence chat-hold "$f" "$CHAT_REPORT"
fi
# Quote and Copy (stories 540-541) are not relaunches here: which choices a message offers and what GRABBER_CHAT_HOLD
# names are ChatReactionTests' (`ChatHold`), the quote's words are `ChatQuote`'s, and ChatReactionUITests holds a
# message for real and quotes it. Neither calls the outbox; the Yes above is the hold menu reaching a Cockpit.

# Stories 312, 314: the hook reviews what looks done and archives it; ChatArchiveUITests taps Select and Undo.
SIMCTL_CHILD_GRABBER_CHAT_URL="http://localhost:$CHAT_PORT" SIMCTL_CHILD_GRABBER_INBOX=open \
  SIMCTL_CHILD_GRABBER_CHAT_SELECT=archive relaunch
wait_jq 'select(.type=="chat" and .action=="archive" and .from=="select")' 20 || echo "      (timed out waiting for the archive)"
f=$(newest_log)
reviewed=$(jq -sr '[.[] | select(.type=="chat" and .action=="select" and .from=="hook")][0].count // 0' "$f")
archived=$(jq -sr '[.[] | select(.type=="chat" and .action=="archive" and .from=="select" and .ok==true)][0].thread // ""' "$f")
posted=$(jq -sr '[.[] | select(.method=="POST" and .path=="/chat/igor2-88g.593/archive")] | length' "$CHAT_REPORT")
failed=$(jq -c 'select(.type=="error")' "$f")
if [ "$reviewed" = 1 ] && [ "$archived" = igor2-88g.593 ] && [ "$posted" = 1 ] && [ -z "$failed" ]; then
  ok "chat: Review ticked the one that looks done and Archive (1) archived it, no error events"
else bad "chat: reviewed $reviewed, archived '$archived', POST archive x$posted, errors: $failed"; fi

# The outbox's own rules (context-grabber-gp7) are host tests, not relaunches here: a refused file kept and sent again
# with no message (stories 487-489), and a message held with no address that a later launch delivers once (#525,
# stories 507-510), in InboxOutboxTests, ChatFileTests and ChatCockpitTests. The sends above stay as the app's outbox
# reaching a Cockpit over real HTTP. What stays here is the launch's wiring with no address, which only the app has:
# the launch says so, the list says why (naming GRABBER_CHAT_URL), and nothing is tried.
SIMCTL_CHILD_GRABBER_INBOX=open relaunch
wait_jq 'select(.type=="chat" and .action=="refresh_failed")' 20 || echo "      (timed out waiting for the list)"
f=$(newest_log)
why=$(jq -sr '[.[] | select(.type=="chat" and .action=="no_address")] | length' "$f")
listed=$(jq -sr '[.[] | select(.type=="chat" and .action=="refresh_failed" and (.reason | contains("GRABBER_CHAT_URL")))] | length' "$f")
left=$(jq -sr '[.[] | select(.type=="chat" and (.action=="sent" or .action=="failed" or .action=="refused"))] | length' "$f")
if [ "$why" = 1 ] && [ "$listed" -ge 1 ] && [ "$left" = 0 ]; then ok "chat: no address: the launch and the list say why and nothing is tried"
else bad "chat: no address: launch line x$why, list said x$listed, sends tried x$left"; fi
fi  # chat

xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
mac_locked_note "at the end"
smoke_done
