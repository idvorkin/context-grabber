#!/usr/bin/env bash
# Host test for the ladder (story 683): runs the real scripts/native/test-ladder.sh and reads what it says. The dry runs
# check which rungs and UI test classes a change gets; the rest run it with fake just, xcodebuild, xcrun, lockf, pgrep and
# uv, so nothing builds, nothing boots and nothing takes the real lock.
set -uo pipefail
# The lane settings come from each run, never from this shell: ~/.zshenv may set BUILD_LANES (#1008), and a run inside a
# lane carries BUILD_LANE and its port offset.
unset BUILD_LANES BUILD_LANE BUILD_LANE_PORT_OFFSET
# Story 1627: sim-boot.sh slims the simulator it boots; these are fake simulators, so the real simslim stays out.
unset SIMSLIM
export SIM_SLIM=0
cd "$(dirname "$0")/../.."
ladder=scripts/native/test-ladder.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-ladder-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0
out=$tmp/out
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; sed 's/^/     /' "$out"; fail=1; }
says() { if grep -qxF -- "$2" "$out"; then ok "$1"; else echo "     wanted: $2"; bad "$1"; fi; }
never() { if grep -qF -- "$2" "$out"; then echo "     unwanted: $2"; bad "$1"; else ok "$1"; fi; }
# Fakes first on the path: pgrep so a real xcodebuild on this Mac can't change what the dry runs print.
fakes=$tmp/bin
mkdir -p "$fakes"
export MARKS=$tmp/marks
mkdir -p "$MARKS"
cat >"$fakes/pgrep" <<'F'
#!/usr/bin/env bash
case ${FAKE_BUSY:-} in
  always) echo 1; exit 0 ;;
  after-build) [ -e "$MARKS/xcodebuild" ] && { echo 1; exit 0; } ;;
esac
exit 1
F
cat >"$fakes/just" <<'F'
#!/usr/bin/env bash
echo "just $*" >>"$MARKS/just"
[ "$1" = "${FAKE_JUST_FAILS:-}" ] && exit 7
exit 0
F
cat >"$fakes/xcodebuild" <<'F'
#!/usr/bin/env bash
echo "xcodebuild $*" >>"$MARKS/xcodebuild"
if [ -n "${FAKE_XCODEBUILD_FAILS:-}" ]; then exit 65; fi
# Each class it is asked to run passes one case, or skips it when FAKE_SKIPS names the class (#1037).
for a in "$@"; do
  case $a in -only-testing:GrabberNativeUITests/*)
    c=${a#*/}
    echo "Test Case '-[GrabberNativeUITests.$c testOne]' started."
    case " ${FAKE_SKIPS:-} " in *" $c "*) st=skipped ;; *) st=passed ;; esac
    echo "Test Case '-[GrabberNativeUITests.$c testOne]' $st (1.000 seconds)." ;;
  esac
done
case " $* " in
  *" build-for-testing "*) echo "** TEST BUILD SUCCEEDED **" ;;
  *) echo "** TEST EXECUTE SUCCEEDED **" ;;
esac
F
cat >"$fakes/xcrun" <<'F'
#!/usr/bin/env bash
echo "xcrun $*" >>"$MARKS/xcrun"
case "$*" in
  "simctl list devices available")
    printf '    iPhone 17 (00000000-0000-0000-0000-000000000000) (Shutdown)\n'
    printf '    iPad Pro 11-inch (M5) (00000000-0000-0000-0000-000000000001) (Shutdown)\n' ;;  # the whiteboard's (story 746)
  "simctl list devices booted")  # story 981: FAKE_BOOTED names the one already up
    [ -z "${FAKE_BOOTED:-}" ] || printf '    Booted One (%s) (Booted) \n' "$FAKE_BOOTED" ;;
  "simctl list devices -j")  # story 984: the prune's view, FAKE_BOOTED up; FAKE_BOOTS_LATER boots that one after the first look
    looks=$(( $(cat "$MARKS/looks" 2>/dev/null || echo 0) + 1 )); echo "$looks" >"$MARKS/looks"
    up=${FAKE_BOOTED:-}; [ "$looks" -gt 1 ] && [ -n "${FAKE_BOOTS_LATER:-}" ] && up=$FAKE_BOOTS_LATER
    dev() { local st=Shutdown; [ "$2" = "$up" ] && st=Booted; printf '{"udid":"%s","state":"%s","name":"%s"}' "$2" "$st" "$1"; }
    printf '{"devices":{"iOS-27":[%s,%s]}}\n' "$(dev "iPhone 17" 00000000-0000-0000-0000-000000000000)" \
      "$(dev "iPad Pro 11-inch (M5)" 00000000-0000-0000-0000-000000000001)" ;;
  "simctl get_app_container "*) echo "${FAKE_CONTAINER:-}" ;;
  "simctl launch "*)
    # The app, importing as its launch hook says: the session log's import event.
    echo "launch hook ${SIMCTL_CHILD_GRABBER_IMPORT_DB:-}" >>"$MARKS/xcrun"
    if [ -n "${SIMCTL_CHILD_GRABBER_IMPORT_DB:-}" ] && [ -n "${FAKE_IMPORTS:-}" ]; then
      mkdir -p "$FAKE_CONTAINER/Documents/logs"
      echo '{"type":"import","ok":true,"places_added":4}' >"$FAKE_CONTAINER/Documents/logs/session.jsonl"
    fi ;;
esac
exit 0
F
cat >"$fakes/lockf" <<'F'
#!/usr/bin/env bash
echo "lockf $3 $4" >>"$MARKS/lockf"
shift 4
exec "$@"
F
# macOS's caffeinate -i <command>: here it only runs the command, so the self-test also runs on the Linux rung.
# The smoke (story 755): only what it was asked to run, on what.
cat >"$fakes/sim-smoke" <<'F'
#!/usr/bin/env bash
echo "smoke ${SMOKE_ONLY:-} $1 $3" >>"$MARKS/smoke"
F
export SIM_SMOKE="$fakes/sim-smoke"
# macOS's caffeinate [-d] [-i] [-u] [-t <s>] [command]: it notes its flags and runs the command, if any (story 782).
cat >"$fakes/caffeinate" <<'F'
#!/usr/bin/env bash
flags=()
while [ $# -gt 0 ] && [ "${1#-}" != "$1" ]; do
  [ "$1" = -t ] && { flags+=("$1"); shift; }
  flags+=("$1")
  shift
done
echo "caffeinate ${flags[*]}" >>"$MARKS/caffeinate"
[ $# -eq 0 ] || exec "$@"
F
# The screen lock's probe (smoke-lock.sh): unlocked, unless a run says otherwise, so this Mac's own lock can't fail it.
printf '#!/usr/bin/env bash\necho "  | |   \\"CGSSessionOnConsoleKey\\"=Yes"\n' >"$fakes/unlocked"
printf '#!/usr/bin/env bash\necho "  | |   \\"CGSSessionScreenIsLocked\\"=Yes"\n' >"$fakes/locked"
# The heat check (story 983): a cool Mac, unless FAKE_HOT says otherwise, so this Mac's own heat can't fail it.
cat >"$fakes/pmset" <<'F'
#!/usr/bin/env bash
case "${FAKE_HOT:-}" in
  "") echo "Note: No thermal warning level has been recorded" ;;
  0) echo "Thermal warning level set to 0."; echo "Performance warning level set to 0." ;;
  *) echo "CPU_Scheduler_Limit = 50"; echo "Thermal warning level set to 2" ;;
esac
F
cat >"$fakes/uv" <<'F'
#!/usr/bin/env bash
exec sleep 30
F
# The rung's time limit (mac-driver's time-limit) is a zsh script, and zsh reads ~/.zshenv: this one sets BUILD_LANES
# the way Igor's does, so a lane count that doesn't survive it fails here on every Mac (context-grabber-jacw).
cat >"$fakes/time-limit" <<'F'
#!/usr/bin/env bash
shift
export BUILD_LANES=6
exec "$@"
F
chmod +x "$fakes"/*
# One build lane unless a run says otherwise (story 785), so this Mac's own memory can't change what the checks see.
dry() { PATH="$fakes:$PATH" BUILD_LANES=${BUILD_LANES:-1} "$ladder" --dry-run "$@" >"$out" 2>&1; }
# Every class the ladder can discover, by the parser its --all uses: a mapped class missing from it would run nothing.
dry --all --changed docs/TESTING.md
known=" $(sed -n 's/^rung 2 UI tests[^:]*: //p' "$out" | tr '\n' ' ') "
# Ports the OS says are free: fixed ones collide when another worktree's pipeline runs this self-test at the same time,
# and a fake Cockpit that cannot bind exits before the ladder's one-second check.
read -r chat_port bridge_port board_port < <(python3 -c '
import socket
socks = [socket.socket() for _ in range(3)]
for s in socks: s.bind(("127.0.0.1", 0))
print(*(s.getsockname()[1] for s in socks))')
run() {  # <env assignments...> -- <ladder arguments...>
  local vars=()
  while [ "$1" != "--" ]; do vars+=("$1"); shift; done
  shift
  rm -f "$MARKS"/* "$tmp/ledger.jsonl" "$tmp/logs/ui-timings.jsonl"
  env PATH="$fakes:$PATH" LADDER_LEDGER="$tmp/ledger.jsonl" LADDER_TIME_LIMIT="$fakes/time-limit" BUILD_LANES=1 BUILD_LOCK_DIR="$tmp/locks" SIM="iPhone 17" NATIVE_LOG_DIR="$tmp/logs" CHAT_PORT="$chat_port" CHAT_BRIDGE_PORT="$bridge_port" WHITEBOARD_PORT="$board_port" \
    XCODEBUILD_IDLE_POLL=1 SMOKE_LOCK_PROBE="$fakes/unlocked" SIM_DEVICES_DIR="$tmp/devices" ${vars[@]+"${vars[@]}"} "$ladder" "$@" >"$out" 2>&1
}

chat_all="ChatArchiveUITests ChatAskSearchUITests ChatCockpitDownUITests ChatDecisionUITests ChatFileUITests ChatImageUITests ChatMoveUITests ChatNewChatAgainUITests ChatNewThreadUITests ChatReactionUITests ChatSkillThreadUITests"
# Every whiteboard UI test file's class, in name order (story 1502): the ladder's list, read from the suite's script, has to
# name them all.
board_all=$(cd native/UITests && ls Whiteboard*UITests.swift | sed 's/\.swift$//' | LC_ALL=C sort | paste -sd ' ' -)

dry --changed native/App/Chat/ChatViews.swift
says "chat code: lint names the file" "rung 0 Lint: swift-format over 1 touched Swift file(s), SwiftLint over the tree"
says "chat code: the host rung" "rung 1 Host: ContextCore's tests and the script checks"
says "chat code: the Mac build" "rung 1.5 Mac: the Catalyst build"
says "chat code: the simulator build" "rung 2 Simulator: the build with its UI tests"
says "chat code: chat's classes" "rung 2 UI tests (chat, fake Cockpit and bridge): $chat_all"
never "chat code: no class runs apart" "rung 2 UI tests: "
never "chat code: no whiteboard" "Whiteboard"
never "chat code: no suite without --full" "rung 2 full"

dry --changed native/App/Whiteboard/PaperBoard.swift
says "whiteboard code: its classes" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): $board_all"
# Story 770: the iPhone's look at boards is the smoke's, so the whiteboard's classes are the only ones, and all on the iPad.
never "whiteboard code: no iPhone class of its own" "rung 2 UI tests: "
says "whiteboard code: the smoke's whiteboard section" "rung 2 smoke, on the same build and boot: whiteboard"
never "whiteboard code: no chat" "Chat"

# The whiteboard's rules run only the classes that show them; its views still run them all.
# Story 1021: a file that drives PaperKit runs the contract tests beside its own classes; the contracts' own files run
# them alone, with no smoke; a whiteboard file that doesn't import PaperKit doesn't run them.
contracts_line="rung 2 contract tests (real PaperKit, on the iPad, no retry): GrabberNativeContractTests PaperKitTouchContractUITests"
dry --changed native/App/Whiteboard/PaperBoard.swift
says "the canvas: the contract tests too" "$contracts_line"
dry --changed native/App/Whiteboard/PaperBoard+FoldErase.swift
says "a split file of the canvas: the contract tests" "$contracts_line"
dry --changed native/App/Whiteboard/PaperScratch.swift
says "a file that imports PaperKit: the contract tests" "$contracts_line"
dry --changed native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardInk.swift
says "the ink kinds: the contract tests" "$contracts_line"
for f in native/ContractTests/PaperStage.swift native/UITests/PaperKitTouchContractUITests.swift native/App/Whiteboard/PaperTouchStage.swift; do
  dry --changed "$f"
  says "$(basename "$f"): the contract tests" "$contracts_line"
  says "$(basename "$f"): no smoke" "rung 2 smoke, on the same build and boot: none"
  never "$(basename "$f"): no whiteboard class" "rung 2 UI tests (whiteboard"
  never "$(basename "$f"): not on the phone" "rung 2 UI tests: PaperKit"
done
dry --changed native/App/Whiteboard/WhiteboardQuestionsModel.swift
never "a board file with no PaperKit: no contract tests" "rung 2 contract tests"
dry --all --changed docs/TESTING.md
says "--all: the contract tests" "$contracts_line"
never "--all: the touch class not on the phone" "PaperKitTouchContractUITests CardUITests"
dry --changed native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardPaste.swift
says "a paste rule: the two paste classes" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): WhiteboardPaperPasteUITests WhiteboardPasteUITests"
dry --changed scripts/lead-times.py
says "the lead-time report: no Mac build (story 828)" "rung 1.5 Mac: skipped, nothing the Mac build compiles changed"
says "the lead-time report: no simulator build" "rung 2 Simulator: skipped, nothing the simulator build compiles changed"
dry --changed native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardGhostTurns.swift
says "a ghost rule: the turn and ghosts classes" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): WhiteboardPaperGhostsUITests WhiteboardTurnUITests"
never "a ghost rule: not the lines" "WhiteboardPaperLinesUITests"
dry --changed native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardFrame.swift
says "the picture's frame: the turn and ghosts classes" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): WhiteboardPaperGhostsUITests WhiteboardTurnUITests"
never "the picture's frame: not the lines" "WhiteboardPaperLinesUITests"
for f in WhiteboardLarryClock WhiteboardNote; do
  dry --changed "native/ContextCore/Sources/ContextCore/Whiteboard/$f.swift"
  says "$f: the turn and ghosts classes" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): WhiteboardPaperGhostsUITests WhiteboardTurnUITests"
done
dry --changed native/App/Whiteboard/WhiteboardStore.swift
says "the board list: row delete and on paper" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): WhiteboardOnPaperUITests WhiteboardRowDeleteUITests"
never "the board list: no iPhone class of its own" "rung 2 UI tests: "
# Story 784: the board fixture hook runs only the classes that launch with a fixture board, chat's picture one among them.
dry --changed native/App/Whiteboard/WhiteboardHooks.swift
says "the fixture hook: row delete" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): WhiteboardRowDeleteUITests"
says "the fixture hook: and the chat picture from a board" "rung 2 UI tests (chat, fake Cockpit and bridge): ChatImageUITests"
for c in WhiteboardRowDeleteUITests ChatImageUITests; do
  case $known in *" $c "*) ok "the fixture hook: $c is a real class" ;; *) : >"$out"; bad "the fixture hook: $c is a real class" ;; esac
  if grep -q '"GRABBER_BOARD_FIXTURE"' "native/UITests/$c.swift"; then ok "the fixture hook: $c launches with a fixture"
  else : >"$out"; bad "the fixture hook: $c launches with a fixture"; fi
done
# Larry's question cards: their own class, and every whiteboard class's list has it.
for f in native/App/Whiteboard/WhiteboardQuestionsModel.swift native/App/Whiteboard/WhiteboardQuestionViews.swift \
  native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardQuestions.swift; do
  dry --changed "$f"
  says "question cards, $(basename "$f"): their class" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): WhiteboardQuestionUITests"
  if [ -e "$f" ]; then ok "a real file: $f"; else : >"$out"; bad "a real file: $f"; fi
done
case $known in *" WhiteboardQuestionUITests "*) ok "question cards: a real class" ;; *) : >"$out"; bad "question cards: a real class" ;; esac
# #1041: the conversation strip runs the classes that use it, not the board's fifteen; the iPhone's side is the smoke's.
strip=native/App/Whiteboard/WhiteboardConversationStrip.swift
if [ -e "$strip" ]; then ok "a real file: $strip"; else : >"$out"; bad "a real file: $strip"; fi
dry --changed "$strip"
says "the strip: the turn, connect and on-paper classes" \
  "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): WhiteboardConnectUITests WhiteboardOnPaperUITests WhiteboardTurnUITests"
says "the strip: the smoke's whiteboard, for the iPhone's tap to Chat" "rung 2 smoke, on the same build and boot: whiteboard"
never "the strip: not the lines" "WhiteboardPaperLinesUITests"
for c in WhiteboardConnectUITests WhiteboardOnPaperUITests WhiteboardTurnUITests; do
  case $known in *" $c "*) ok "the strip: $c is a real class" ;; *) : >"$out"; bad "the strip: $c is a real class" ;; esac
done
# A strip change with the shared canvas in it takes the union: every class.
dry --changed "$strip" --changed native/App/Whiteboard/PaperBoard.swift
says "the strip and the canvas: every class" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): $board_all"
dry --changed "$strip" --changed native/App/Whiteboard/WhiteboardView.swift
says "the strip and the drawing screen: every class" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): $board_all"

# Every Whiteboard*UITests class the tree declares is in the whiteboard's list, so a new one isn't left out of a view change.
for c in $(sed -nE 's/^(final )?class (Whiteboard[A-Za-z0-9_]*UITests):.*/\2/p' native/UITests/*.swift); do
  case " $board_all " in *" $c "*) ok "the whiteboard's list has $c" ;; *) : >"$out"; bad "the whiteboard's list has $c" ;; esac
done
dry --changed native/App/Whiteboard/WhiteboardView.swift
says "the board's view: every class" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): $board_all"
dry --changed native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardLaunchHooks.swift
says "the hooks: every class" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): $board_all"

# #1036: the replay of Larry's board changes runs only in the harness and the host tests, so a change to it alone gets
# the host rung's replay fixtures and the Mac build, and no simulator, UI class or smoke.
replay=native/ContextCore/Sources/ContextCore/Whiteboard/BoardReplay.swift
dry --changed $replay
says "the replay alone: the host rung" "rung 1 Host: ContextCore's tests and the script checks"
says "the replay alone: the Mac build compiles it" "rung 1.5 Mac: the Catalyst build"
says "the replay alone: no simulator" "rung 2 Simulator: skipped, the app never runs what changed; the host rung's replay fixtures do"
says "the replay alone: says why" "no UI test or smoke of their own, the host rung's replay fixtures hold them (#1036): $replay"
says "the replay alone: no UI class" "rung 2 UI tests: none, no app UI change"
never "the replay alone: no whiteboard class" "UITests"
never "the replay alone: no smoke" "rung 2 smoke"
never "the replay alone: not unmapped" "no UI test map"
dry --changed native/ContextCore/Sources/BoardOpsHarness/main.swift --changed native/ContextCore/Sources/BoardOpsHarness/Sketch.swift
says "the harness: in no app build, so no Mac build" "rung 1.5 Mac: skipped, nothing the Mac build compiles changed"
says "the harness: no simulator" "rung 2 Simulator: skipped, the app never runs what changed; the host rung's replay fixtures do"
never "the harness: not unmapped" "no UI test map"
# The planner and applier the replay calls are the canvas's too: every class and the smoke, as before.
for f in BoardOpsPlan BoardOps BoardOpApplier; do
  dry --changed "native/ContextCore/Sources/ContextCore/Whiteboard/$f.swift"
  says "the shared planning, $f: every class" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): $board_all"
  says "the shared planning, $f: the smoke's whiteboard" "rung 2 smoke, on the same build and boot: whiteboard"
done
# A mixed change keeps the union: the canvas's classes and smoke, and the replay's host fixtures.
dry --changed $replay --changed native/App/Whiteboard/PaperBoard.swift
says "replay and canvas: every class" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): $board_all"
says "replay and canvas: the smoke's whiteboard" "rung 2 smoke, on the same build and boot: whiteboard"
says "replay and canvas: the simulator builds" "rung 2 Simulator: the build with its UI tests"
says "replay and canvas: the Mac build" "rung 1.5 Mac: the Catalyst build"
dry --changed $replay --changed native/App/Chat/ChatViews.swift
says "replay and chat: chat's classes" "rung 2 UI tests (chat, fake Cockpit and bridge): $chat_all"
says "replay and chat: chat's smoke, not the whiteboard's" "rung 2 smoke, on the same build and boot: chat"
never "replay and chat: no whiteboard class" "rung 2 UI tests (whiteboard"
for f in $replay native/ContextCore/Sources/BoardOpsHarness/main.swift native/ContextCore/Sources/BoardOpsHarness/Sketch.swift \
  native/ContextCore/Sources/ContextCore/Whiteboard/BoardOpsPlan.swift native/ContextCore/Sources/ContextCore/Whiteboard/BoardOps.swift \
  native/ContextCore/Sources/ContextCore/Whiteboard/BoardOpApplier.swift; do
  if [ -e "$f" ]; then ok "a real file: $f"; else : >"$out"; bad "a real file: $f"; fi
done

dry --changed docs/TESTING.md --changed README.md
says "docs: nothing to format" "rung 0 Lint: swift-format over 0 touched Swift file(s), SwiftLint over the tree"
says "docs: no Mac build" "rung 1.5 Mac: skipped, nothing the Mac build compiles changed"
says "docs: no simulator build" "rung 2 Simulator: skipped, nothing the simulator build compiles changed"
says "docs: no UI tests" "rung 2 UI tests: none, no app UI change"

dry --changed native/UITests/CardUITests.swift
says "a test file: its own class" "rung 2 UI tests: CardUITests"
says "a test file: the simulator builds it" "rung 2 Simulator: the build with its UI tests"
says "a test file: not in the Mac build" "rung 1.5 Mac: skipped, nothing the Mac build compiles changed"

# #795: each feature's directory, in the app and in ContextCore, gets that feature's own classes.
feature() {  # <name> <app path> <ContextCore path, or ""> <the line's label> <classes>
  local label="rung 2 UI tests$4: $5" c
  dry --changed "$2"
  says "$1 code: its classes" "$label"
  never "$1 code: nothing unmapped" "no UI test map"
  never "$1 code: no chat" "Chat"
  if [ -n "$3" ]; then
    dry --changed "$3"
    says "$1 in ContextCore: its classes" "$label"
  fi
  # A class renamed or deleted would leave the map naming nothing: xcodebuild runs no test for a name it can't find.
  for c in $5; do
    case $known in *" $c "*) ok "$1: $c is a real class" ;; *) : >"$out"; bad "$1: $c is a real class" ;; esac
  done
  # A row for a file that moved would check nothing.
  for f in "$2" ${3:+"$3"}; do
    if [ -e "$f" ]; then ok "a real file: $f"; else : >"$out"; bad "a real file: $f"; fi
  done
}
core=native/ContextCore/Sources/ContextCore
feature gym native/App/Gym/GymTimerView.swift $core/Gym/TimerEngine.swift "" "GymTimerDialsUITests GymTimerUITests"
feature breathe native/App/Breathe/BreatheView.swift $core/Breathe/BreathEngine.swift "" "BreathePresetsUITests BreatheStyleUITests"
never "breathe code: not the Health write's 60 s session (story 770)" "BreatheMindfulUITests"
feature "the Health source" native/App/Mirror/HealthKitSource.swift "" "" "BreatheMindfulUITests HomeTodayCardUITests MetricDetailUITests"
feature places native/App/Places/PlacesView.swift $core/Places/StayClustering.swift " (places, the real export in Documents)" "PlaceIconUITests PlacesUnnamedUITests"
feature mirror native/App/Mirror/MetricDetailView.swift $core/Mirror/MirrorGrab.swift "" "HomeTodayCardUITests MetricDetailUITests"
feature card native/App/Card/CardView.swift $core/Card/CardDeal.swift "" "CardUITests TodaysHandUITests"
feature cockpit native/App/Cockpit/CockpitView.swift $core/Cockpit/CockpitPage.swift "" "CockpitBackUITests"
# The usage tile's test needs the real Cockpit, so only the usage files ask for it.
feature usage native/App/Cockpit/UsageModel.swift $core/Cockpit/UsageSnapshot.swift "" "UsageTileUITests"
feature "usage strip" native/App/Cockpit/UsageStripView.swift $core/Cockpit/CockpitUsage.swift "" "UsageTileUITests"
never "usage: not the Cockpit's" "CockpitBackUITests"
dry --changed native/App/Cockpit/CockpitView.swift
never "cockpit code: not the usage tile, which needs the tailnet" "UsageTileUITests"
feature daily native/App/Daily/DailyStripView.swift $core/Daily/DailyStrip.swift "" "DailyStripUITests"
feature eulogy native/App/Eulogy/EulogySong.swift $core/Eulogy/SongPlayback.swift "" "EulogyUITests"
feature links native/App/Links/LinksView.swift $core/Links/AppLink.swift "" "LinksUITests"
# Files whose feature isn't their directory's.
feature "the role of the day" $core/Card/EulogyRoles.swift "" "" "TodaysHandUITests"
never "the role of the day: not the trainer's screen" "CardUITests"
feature "the blog's links" $core/Links/BlogLinks.swift "" "" "EulogyUITests"
never "the blog's links: not the link screen" "LinksUITests"
feature "the supermix link" $core/Links/WorkoutSupermix.swift "" "" "WorkoutSupermixUITests"
never "the supermix link: not the link screen" "LinksUITests"
feature "a tile's choices" $core/Links/HoldChoices.swift "" "" "HoldPopoverUITests"
never "a tile's choices: not the link screen" "LinksUITests"
for f in $core/Links/WindowLedger.swift native/App/Windows/WindowViews.swift; do
  if [ -e "$f" ]; then ok "a real file: $f"; else : >"$out"; bad "a real file: $f"; fi
done
dry --changed $core/Links/WindowLedger.swift
says "the window ledger: unmapped, as the windows are" "no UI test map for: $core/Links/WindowLedger.swift"
never "the window ledger: not the link screen" "LinksUITests"

dry --changed native/App/Gym/GymTimerView.swift --changed native/App/Places/PlacesModel.swift --changed native/App/Chat/ChatViews.swift
says "three features: places apart" "rung 2 UI tests (places, the real export in Documents): PlaceIconUITests PlacesUnnamedUITests"
says "three features: the timer's" "rung 2 UI tests: GymTimerDialsUITests GymTimerUITests"
says "three features: chat's" "rung 2 UI tests (chat, fake Cockpit and bridge): $chat_all"

# No class on the ladder's simulator opens a second window (IPadUITests opens the launchers), so Windows stays unmapped.
dry --changed native/App/Windows/WindowViews.swift
says "unmapped code: says so" "no UI test map for: native/App/Windows/WindowViews.swift"
says "unmapped code: names the option" "so no UI tests were chosen for them; --all runs every UI test class"
never "unmapped code: chooses nothing" "rung 2 UI tests"

# #1037: IPadUITests skips on a phone, so wherever it is chosen it runs on the iPad, never in the iPhone's run.
dry --changed native/UITests/IPadUITests.swift
says "the iPad's class: on the iPad" "rung 2 UI tests (on the iPad, which they need): IPadUITests"
never "the iPad's class: not on the iPhone" "rung 2 UI tests: IPadUITests"
dry --changed native/UITests/IPadUITests.swift --changed native/UITests/CardUITests.swift --changed native/UITests/WhiteboardTurnUITests.swift
says "iPad, iPhone and whiteboard classes: the iPad's apart" "rung 2 UI tests (on the iPad, which they need): IPadUITests"
says "iPad, iPhone and whiteboard classes: the phone's alone" "rung 2 UI tests: CardUITests"
says "iPad, iPhone and whiteboard classes: the whiteboard's" "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): WhiteboardTurnUITests"
dry --all --changed docs/TESTING.md
# Story 1216: Ink side by side is iPad-only, so its class rides with the iPad's, never in the iPhone's run.
says "--all: the iPad's classes on the iPad" "rung 2 UI tests (on the iPad, which they need): IPadInkSideBySideUITests IPadPaperKitBoardUITests IPadUITests"
if grep -E "^rung 2 UI tests: .*IPad[A-Za-z]*UITests" "$out" >/dev/null; then bad "--all: the iPad's classes not in the iPhone's run"; else ok "--all: the iPad's classes not in the iPhone's run"; fi
case $known in *" IPadUITests "*) ok "the iPad's class: a real class" ;; *) : >"$out"; bad "the iPad's class: a real class" ;; esac

# Story 1222: the scratch page and the Settings row that opens it run its iPad class.
dry --changed native/App/Whiteboard/PaperKitBoard.swift --changed native/App/DiagnosticsView.swift
says "the PaperKit board: its iPad class" "rung 2 UI tests (on the iPad, which they need): IPadPaperKitBoardUITests"
never "the PaperKit board: not the whiteboard suite" "rung 2 UI tests (whiteboard"

dry --changed native/UITests/HomeScreen.swift
says "a shared test helper: says so" "no UI test map for: native/UITests/HomeScreen.swift"

dry --changed native/ContextCore/Tests/ContextCoreTests/StatsTests.swift
says "a host test: no Mac build" "rung 1.5 Mac: skipped, nothing the Mac build compiles changed"
says "a host test: no simulator build" "rung 2 Simulator: skipped, nothing the simulator build compiles changed"

dry --changed native/ContextCore/Sources/ContextCore/Chat/ChatCockpit.swift
says "Mac-only code in the package: the Mac build" "rung 1.5 Mac: the Catalyst build"

dry --changed native/App/Chat/ChatViews.swift --full
says "--full: the area's suite" "rung 2 full: scripts/native/test-chat-ui.sh"
never "--full: in place of its classes" "rung 2 UI tests (chat"

dry --changed docs/TESTING.md --all
says "--all: chat" "rung 2 UI tests (chat, fake Cockpit and bridge): $chat_all"
says "--all: the simulator builds" "rung 2 Simulator: the build with its UI tests"

BUILD_LANES=1 FAKE_BUSY=always dry --changed native/App/Chat/ChatViews.swift
says "dry run: says another xcodebuild would be waited for" "another xcodebuild is running now: the Mac and simulator rungs would wait for it"

# The diff itself, in a throwaway repository holding a copy of the script: committed, staged and untracked all count.
repo=$tmp/repo
mkdir -p "$repo/scripts/native"
cp -f "$ladder" "$repo/scripts/native/"
(
  cd "$repo" || exit 1
  git init -q -b main .
  git -c user.name=t -c user.email=t@example.com add .
  git -c user.name=t -c user.email=t@example.com commit -qm base
  git checkout -qb work
  mkdir -p docs native/App/Chat native/App/Whiteboard native/UITests
  echo a >docs/a.md
  git add .
  git -c user.name=t -c user.email=t@example.com commit -qm words
  PATH="$fakes:$PATH" scripts/native/test-ladder.sh --dry-run --base main >"$tmp/words" 2>&1
  echo b >native/App/Chat/New.swift
  PATH="$fakes:$PATH" scripts/native/test-ladder.sh --dry-run --base main >"$tmp/untracked" 2>&1
  # No test file in the tree holds two classes or a subclass, so these stand in for one that does.
  printf 'final class FirstUITests: XCTestCase {}\nfinal class SecondUITests: XCTestCase {}\n' >native/UITests/TwoUITests.swift
  printf 'class BaseUITests: XCTestCase {}\n' >native/UITests/BaseUITests.swift
  printf 'final class ChildUITests: BaseUITests {}\n' >native/UITests/ChildUITests.swift
  PATH="$fakes:$PATH" scripts/native/test-ladder.sh --dry-run --changed native/UITests/TwoUITests.swift >"$tmp/two" 2>&1
  PATH="$fakes:$PATH" scripts/native/test-ladder.sh --dry-run --changed native/UITests/BaseUITests.swift >"$tmp/inherits" 2>&1
)
cp -f "$tmp/two" "$out"
says "a test file of two classes: both" "rung 2 UI tests: FirstUITests SecondUITests"
cp -f "$tmp/inherits" "$out"
says "a test class: and what inherits it" "rung 2 UI tests: BaseUITests ChildUITests"
cp -f "$tmp/words" "$out"
says "the diff, docs committed: measured from the base" "test ladder: 1 changed path(s), measured from main"
says "the diff, docs committed: no UI tests" "rung 2 UI tests: none, no app UI change"
cp -f "$tmp/untracked" "$out"
says "the diff, chat untracked: chat's classes" "rung 2 UI tests (chat, fake Cockpit and bridge): $chat_all"

# Climbing, with fakes.
run FAKE_JUST_FAILS=native-test-host -- --changed native/App/Chat/ChatViews.swift
status=$?
if [ "$status" -eq 7 ]; then ok "a host failure: the rung's exit"; else bad "a host failure: exit $status"; fi
says "a host failure: names the rung" "stopped on rung 1 Host (exit 7)"
# A build lane's lock: rung 0's swift-format takes a host slot's (stories 795, 797, 798), not a lane's.
if grep -qE "build(-[0-9]+)?\.lock" "$MARKS/lockf" 2>/dev/null; then bad "a host failure: nothing climbs past it"; else ok "a host failure: nothing climbs past it"; fi
if grep -qE "/host-[0-9]+\.lock$" "$MARKS/lockf" 2>/dev/null; then ok "rung 0's swift-format takes a host slot"; else bad "rung 0's swift-format takes a host slot"; fi
if grep -qF "rung 0 Lint: ok," "$out"; then ok "a host failure: lint's seconds"; else bad "a host failure: lint's seconds"; fi

run FAKE_JUST_FAILS=native-build-mac -- --changed native/App/Chat/ChatViews.swift
says "a Mac failure: names the rung" "stopped on rung 1.5 Mac (exit 7)"
if [ -e "$MARKS/xcodebuild" ]; then bad "a Mac failure: the simulator never starts"; else ok "a Mac failure: the simulator never starts"; fi

run -- --changed docs/TESTING.md
status=$?
if [ "$status" -eq 0 ] && ! grep -qE "build(-[0-9]+)?\.lock" "$MARKS/lockf" 2>/dev/null; then ok "docs: climbs without the lane"; else bad "docs: climbs without the lane"; fi
says "docs: the Mac skipped in the seconds" "  rung 1.5 Mac: skipped"
says "docs: the end names the phone" "every rung passed; rung 3, the phone, is yours: just native-run-device"

# #1036: a climb for the replay alone runs the host tests and the Mac build, and starts no simulator.
run -- --changed native/ContextCore/Sources/ContextCore/Whiteboard/BoardReplay.swift
status=$?
if [ "$status" -eq 0 ]; then ok "the replay alone: climbs"; else bad "the replay alone: climbs, exit $status"; fi
if grep -qxF "just native-test-host" "$MARKS/just" && grep -qxF "just native-build-mac" "$MARKS/just"; then ok "the replay alone: the host tests and the Mac build"
else bad "the replay alone: the host tests and the Mac build: $(cat "$MARKS/just" 2>/dev/null)"; fi
if [ -e "$MARKS/xcodebuild" ] || [ -e "$MARKS/smoke" ]; then bad "the replay alone: no simulator build, class or smoke"; else ok "the replay alone: no simulator build, class or smoke"; fi
says "the replay alone: the simulator skipped in the seconds" "  rung 2 Simulator: skipped"

run -- --changed native/UITests/CardUITests.swift
status=$?
if [ "$status" -eq 0 ]; then ok "a test file: climbs"; else bad "a test file: climbs, exit $status"; fi
if grep -qE "build(-[0-9]+)?\.lock" "$MARKS/lockf"; then ok "the simulator rung takes a build lane's lock"; else bad "the simulator rung takes a build lane's lock"; fi
if grep -qxF "lockf 3600 $tmp/locks/build.lock" "$MARKS/lockf"; then ok "one lane: the old build.lock, an hour's wait"; else bad "one lane: the old build.lock, an hour's wait"; fi
if head -1 "$MARKS/xcodebuild" | grep -q " build-for-testing"; then ok "the build comes first"; else bad "the build comes first"; fi
if grep -q "only-testing:GrabberNativeUITests/CardUITests test-without-building" "$MARKS/xcodebuild"; then ok "then its class alone"; else bad "then its class alone"; fi
if grep -q "simctl shutdown" "$MARKS/xcrun"; then bad "the simulator is left booted after (story 980)"; else ok "the simulator is left booted after (story 980)"; fi
if grep -q "simctl bootstatus 00000000-0000-0000-0000-000000000000 -b" "$MARKS/xcrun"; then ok "the phone boots only if it isn't up"; else bad "the phone boots only if it isn't up"; fi
if grep -q "^smoke none 00000000-0000-0000-0000-000000000000 native/Build/Build/Products/Debug-iphonesimulator/GrabberNative.app$" "$MARKS/smoke" 2>/dev/null; then
  ok "then the smoke's sections on that build and simulator (story 755)"
else bad "then the smoke's sections on that build and simulator (story 755): $(cat "$MARKS/smoke" 2>/dev/null)"; fi
says_smoke() {  # <label> <expected sections> <path...>
  local got
  got=$(scripts/native/smoke-features.sh main "${@:3}")
  if [ "$got" = "$2" ]; then ok "$1"; else bad "$1: $got"; fi
}
says_smoke "the smoke: a Gym Timer file runs the timer section" timer native/App/Gym/GymTimerView.swift
says_smoke "the smoke: a UI test file runs none of it" none native/UITests/CardUITests.swift
says_smoke "the smoke: shared code runs all of it" all native/App/AppModel.swift
says_smoke "the smoke: its audio-lock helper runs all of it (story 827)" all scripts/native/smoke-lock.sh
says_smoke "the smoke: the lead-time report runs none of it (story 828)" none scripts/lead-times.py
says_smoke "the smoke: the ladder report and the deploy recorder run none of it (#1038)" none \
  scripts/native/ladder-report.py scripts/native/record-deploy.sh scripts/native/fixtures/ladder-report/runs.jsonl
says_smoke "the smoke: the replay runs none of it (#1036)" none native/ContextCore/Sources/ContextCore/Whiteboard/BoardReplay.swift
says_smoke "the smoke: nor its harness (#1036)" none native/ContextCore/Sources/BoardOpsHarness/main.swift
says_smoke "the smoke: the replay beside the canvas, the whiteboard's (#1036)" whiteboard \
  native/ContextCore/Sources/ContextCore/Whiteboard/BoardReplay.swift native/App/Whiteboard/PaperBoard.swift
says_smoke "the smoke: the shared planner, the whiteboard's (#1036)" whiteboard native/ContextCore/Sources/ContextCore/Whiteboard/BoardOpsPlan.swift

# Story 782: the simulator rung holds the display on and wakes it first; the Mac rung only keeps the Mac awake.
if grep -qxF "caffeinate -d -i" "$MARKS/caffeinate"; then ok "rung 2 holds the display on"; else bad "rung 2 holds the display on: $(cat "$MARKS/caffeinate")"; fi
if grep -qxF "caffeinate -u -t 5" "$MARKS/caffeinate"; then ok "rung 2 wakes the display first"; else bad "rung 2 wakes the display first: $(cat "$MARKS/caffeinate")"; fi
run -- --rung 1.5 --changed native/App/Chat/ChatViews.swift
if grep -qxF "caffeinate -i" "$MARKS/caffeinate" && ! grep -q -- "-d" "$MARKS/caffeinate"; then ok "the Mac rung keeps the Mac awake, not the display"
else bad "the Mac rung's caffeinate: $(cat "$MARKS/caffeinate")"; fi
# Story 1507 (context-grabber-xmwp): a time limit that can't be found stops the rung; it never runs with none.
run LADDER_TIME_LIMIT="$tmp/no-such-time-limit" -- --rung 1.5 --changed native/App/Chat/ChatViews.swift
status=$?
if [ "$status" -eq 2 ]; then ok "no time limit: the rung refuses"; else bad "no time limit: the rung refuses, exit $status"; fi
says "no time limit: says which" "no time limit at $tmp/no-such-time-limit: rung 1.5 not started, as a hang would hold build lane 1"
if [ -e "$MARKS/xcodebuild" ]; then bad "no time limit: nothing built"; else ok "no time limit: nothing built"; fi
# Bead context-grabber-wm8y: a locked screen no longer holds rung 2 back; the wrapper skips the tests that open the mic.
run SMOKE_LOCK_PROBE="$fakes/locked" -- --changed native/UITests/CardUITests.swift
status=$?
if [ "$status" -eq 0 ]; then ok "a locked screen: rung 2 runs"; else bad "a locked screen: rung 2 runs, exit $status"; fi
says "a locked screen: says it skips the mic tests" "the Mac's screen is locked: rung 2 runs, skipping the tests that open the mic (scripts/native/mic-tests.txt)"
if grep -q "only-testing:GrabberNativeUITests/CardUITests" "$MARKS/xcodebuild"; then ok "a locked screen: its class ran"; else bad "a locked screen: its class ran"; fi

run -- --changed native/UITests/WhiteboardPasteUITests.swift
status=$?
if [ "$status" -eq 0 ]; then ok "paste: climbs"; else bad "paste: climbs, exit $status"; fi
if grep -q "only-testing:GrabberNativeUITests/WhiteboardPasteUITests test-without-building" "$MARKS/xcodebuild"; then ok "paste: its class, keys test and all"; else bad "paste: its class, keys test and all"; fi
if grep -q "skip-testing" "$MARKS/xcodebuild"; then bad "paste: nothing held back"; else ok "paste: nothing held back"; fi
if grep -q "simctl shutdown 00000000-0000-0000-0000-000000000001" "$MARKS/xcrun"; then ok "paste: the iPad fresh-booted for its keys (until story 982)"; else bad "paste: the iPad fresh-booted for its keys (until story 982)"; fi
run -- --changed native/UITests/WhiteboardTurnUITests.swift
if grep -q "simctl shutdown 00000000-0000-0000-0000-000000000001" "$MARKS/xcrun"; then bad "the turn class: no reboot of the iPad"; else ok "the turn class: no reboot of the iPad"; fi
if grep -q "simctl bootstatus 00000000-0000-0000-0000-000000000001 -b" "$MARKS/xcrun"; then ok "paste: on the iPad, booted if it isn't up"; else bad "paste: on the iPad, booted if it isn't up"; fi

# #1037: the iPad's class runs on the iPad's simulator, the phone's on the phone's, and a skip on the iPad fails.
run -- --changed native/UITests/IPadUITests.swift --changed native/UITests/CardUITests.swift
status=$?
if [ "$status" -eq 0 ]; then ok "iPad and iPhone classes: climbs"; else bad "iPad and iPhone classes: climbs, exit $status"; fi
if grep "only-testing:GrabberNativeUITests/IPadUITests " "$MARKS/xcodebuild" | grep -q "id=00000000-0000-0000-0000-000000000001"; then
  ok "the iPad's class: on the iPad's simulator"
else bad "the iPad's class: on the iPad's simulator: $(grep IPadUITests "$MARKS/xcodebuild")"; fi
if grep "only-testing:GrabberNativeUITests/CardUITests " "$MARKS/xcodebuild" | grep -q "id=00000000-0000-0000-0000-000000000000"; then
  ok "the phone's class: on the phone's simulator"
else bad "the phone's class: on the phone's simulator"; fi
if grep "IPadUITests" "$MARKS/xcodebuild" | grep -q "CardUITests"; then bad "the iPad's class: a run of its own"; else ok "the iPad's class: a run of its own"; fi
says "the iPad's class: says what ran" "  the iPad's classes on 00000000-0000-0000-0000-000000000001: 1 passed, 0 failed, 0 skipped"
run FAKE_SKIPS=IPadUITests -- --changed native/UITests/IPadUITests.swift
status=$?
if [ "$status" -ne 0 ]; then ok "the iPad's class skipped on the iPad: fails"; else bad "the iPad's class skipped on the iPad: fails"; fi
says "the iPad's class skipped: counted" "  the iPad's classes on 00000000-0000-0000-0000-000000000001: 0 passed, 0 failed, 1 skipped"
says "the iPad's class skipped: says it is the destination, not a pass" "the iPad's classes skipped 1 test(s) on the iPad simulator: a skip there is the wrong destination, not a pass (#1037)"
run LADDER_SMOKE=0 -- --full --changed native/UITests/IPadUITests.swift
status=$?
if [ "$status" -eq 0 ]; then ok "--full with the iPad's class: climbs"; else bad "--full with the iPad's class: climbs, exit $status"; fi
if grep "only-testing:GrabberNativeUITests/IPadUITests " "$MARKS/xcodebuild" | grep -q "id=00000000-0000-0000-0000-000000000001"; then
  ok "--full: the iPad's class still runs, on the iPad"
else bad "--full: the iPad's class still runs, on the iPad"; fi

# Story 981: a climb on both devices switches once, starting with the one already booted.
order() { sed -nE 's/.*simctl bootstatus 0{8}-0{4}-0{4}-0{4}-0{11}([0-9]) -b.*/\1/p' "$MARKS/xcrun" | tr -d '\n'; }
run -- --changed native/UITests/WhiteboardPasteUITests.swift --changed native/UITests/CardUITests.swift
if [ "$(order)" = "01" ]; then ok "both devices, none up: the phone, then the iPad"; else bad "both devices, none up: $(order)"; fi
run FAKE_BOOTED=00000000-0000-0000-0000-000000000001 -- --changed native/UITests/WhiteboardPasteUITests.swift --changed native/UITests/CardUITests.swift
if [ "$(order)" = "10" ]; then ok "both devices, the iPad up: the iPad, then the phone"; else bad "both devices, the iPad up: $(order)"; fi
if grep -q "simctl shutdown 00000000-0000-0000-0000-000000000001" "$MARKS/xcrun"; then ok "both devices: the iPad is shut before the phone boots"; else bad "both devices: the iPad is shut before the phone boots"; fi
# Stories 984, 987, 988, 989: the shut-down simulators' wallpaper snapshots are pruned before a boot and when the rung ends; never a booted one's.
stores() {  # fresh fake snapshots, 1 MB each, under both fake simulators
  local d
  for d in 00000000-0000-0000-0000-000000000000 00000000-0000-0000-0000-000000000001; do
    mkdir -p "$tmp/devices/$d/data/Library/Application Support/PRBPosterExtensionDataStore/1"
    head -c 1048576 /dev/zero >"$tmp/devices/$d/data/Library/Application Support/PRBPosterExtensionDataStore/1/snap"
  done
}
store_of() { echo "$tmp/devices/$1/data/Library/Application Support/PRBPosterExtensionDataStore"; }
prune() {  # <env assignments...>: the prune alone, against the fakes
  rm -f "$MARKS"/*
  env PATH="$fakes:$PATH" SIM_DEVICES_DIR="$tmp/devices" "$@" scripts/native/sim-poster-prune.sh >"$out" 2>&1
}
stores
prune FAKE_BOOTED=00000000-0000-0000-0000-000000000001
status=$?
if [ ! -e "$(store_of 00000000-0000-0000-0000-000000000000)" ]; then ok "prune: a shut-down simulator's snapshots go"; else bad "prune: a shut-down simulator's snapshots go"; fi
if [ -e "$(store_of 00000000-0000-0000-0000-000000000001)/1/snap" ]; then ok "prune: a booted one's stay"; else bad "prune: a booted one's stay"; fi
if [ -d "$tmp/devices/00000000-0000-0000-0000-000000000000/data/Library/Application Support" ]; then ok "prune: only the snapshots, not the simulator"; else bad "prune: only the snapshots, not the simulator"; fi
says "prune: one line, the simulators and the MB" "sim-poster-prune: cleared the wallpaper snapshots of 1 shut-down simulator (iPhone 17), freed 1 MB"
if [ "$status" -eq 0 ]; then ok "prune: exit 0"; else bad "prune: exit 0, got $status"; fi
stores
prune FAKE_BOOTS_LATER=00000000-0000-0000-0000-000000000001
if [ -e "$(store_of 00000000-0000-0000-0000-000000000001)/1/snap" ]; then ok "prune: one booted since the list was read is left alone"; else bad "prune: one booted since the list was read is left alone"; fi
says "prune: the other is still cleared" "sim-poster-prune: cleared the wallpaper snapshots of 1 shut-down simulator (iPhone 17), freed 1 MB"
prune
says "prune: once it is shut down again, its snapshots go" "sim-poster-prune: cleared the wallpaper snapshots of 1 shut-down simulator (iPad Pro 11-inch (M5)), freed 1 MB"
prune
says "prune: nothing left, one line says so" "sim-poster-prune: no wallpaper snapshots on a shut-down simulator"
mkdir -p "$tmp/broken-bin"
printf '#!/usr/bin/env bash\nexit 1\n' >"$tmp/broken-bin/xcrun"
chmod +x "$tmp/broken-bin/xcrun"
prune PATH="$tmp/broken-bin:$fakes:$PATH"
status=$?
if [ "$status" -eq 0 ]; then ok "prune: a simctl that fails is a line, not a failure"; else bad "prune: a simctl that fails is a line, not a failure, exit $status"; fi
says "prune: says nothing was pruned" "sim-poster-prune: no simulators listed by simctl; nothing pruned"
stores
run -- --changed native/UITests/CardUITests.swift
first_look=$(grep -n "simctl list devices -j" "$MARKS/xcrun" | head -1 | cut -d: -f1)
first_boot=$(grep -n "simctl bootstatus" "$MARKS/xcrun" | head -1 | cut -d: -f1)
if [ -n "$first_look" ] && [ -n "$first_boot" ] && [ "$first_look" -lt "$first_boot" ]; then ok "a boot prunes the snapshots first (story 984)"; else bad "a boot prunes the snapshots first (story 984)"; fi
if [ ! -e "$(store_of 00000000-0000-0000-0000-000000000000)" ] && [ ! -e "$(store_of 00000000-0000-0000-0000-000000000001)" ]; then ok "the climb clears both shut-down simulators' snapshots"
else bad "the climb clears both shut-down simulators' snapshots"; fi
last_boot=$(grep -n "simctl bootstatus" "$MARKS/xcrun" | tail -1 | cut -d: -f1)
last_look=$(grep -n "simctl list devices -j" "$MARKS/xcrun" | tail -1 | cut -d: -f1)
if [ -n "$last_look" ] && [ "$last_look" -gt "$last_boot" ]; then ok "the rung prunes again when it ends (story 987)"; else bad "the rung prunes again when it ends (story 987)"; fi
# Story 983: a hot Mac gets its simulator shut down at the end.
run FAKE_HOT=1 -- --changed native/UITests/CardUITests.swift
if grep -q "simctl shutdown 00000000-0000-0000-0000-000000000000" "$MARKS/xcrun"; then ok "a hot Mac: the simulator is shut down"; else bad "a hot Mac: the simulator is shut down"; fi
says "a hot Mac: says why" "the Mac is hot (Thermal warning level set to 2): the simulator is shut down rather than left booted"
run FAKE_HOT=0 -- --changed native/UITests/CardUITests.swift
if grep -q "simctl shutdown" "$MARKS/xcrun"; then bad "a Mac cooled after a warning: the simulator is left booted"; else ok "a Mac cooled after a warning: the simulator is left booted"; fi
run LADDER_SMOKE=0 -- --full --changed native/UITests/WhiteboardTurnUITests.swift
if [ "$(grep -c "simctl boot.* 00000000-0000-0000-0000-000000000001" "$MARKS/xcrun")" -eq 1 ]; then ok "--full whiteboard: the iPad boots once"
else bad "--full whiteboard: the iPad boots once: $(grep "simctl boot" "$MARKS/xcrun")"; fi

run -- --changed native/App/Chat/ChatViews.swift
status=$?
if [ "$status" -eq 0 ]; then ok "chat: climbs against the fakes"; else bad "chat: climbs against the fakes, exit $status"; fi
if grep -q "GrabberNativeUITests/ChatArchiveUITests" "$MARKS/xcodebuild"; then ok "chat: runs its classes"; else bad "chat: runs its classes"; fi

run FAKE_CONTAINER="$tmp/container" FAKE_IMPORTS=1 -- --changed native/App/Places/PlacesView.swift
status=$?
if [ "$status" -eq 0 ]; then ok "places: climbs against the fakes"; else bad "places: climbs against the fakes, exit $status"; fi
if cmp -s __tests__/fixtures/context-grabber.db "$tmp/container/Documents/import-fixture.db"; then ok "places: the real export is in Documents"; else bad "places: the real export is in Documents"; fi
if grep -q "simctl install .*GrabberNative.app" "$MARKS/xcrun"; then ok "places: the app is installed first"; else bad "places: the app is installed first"; fi
if grep -q "simctl bootstatus .* -b" "$MARKS/xcrun"; then ok "places: a boot that can fail, not one waited for"; else bad "places: a boot that can fail, not one waited for"; fi
if grep -q "simctl launch " "$MARKS/xcrun"; then ok "places: one launch imports it before any class"; else bad "places: one launch imports it before any class"; fi
if grep -q "import-fixture.db,recent" "$MARKS/xcrun"; then ok "places: with the import hook"; else bad "places: with the import hook"; fi
if grep -q "only-testing:GrabberNativeUITests/PlacesUnnamedUITests test-without-building" "$MARKS/xcodebuild"; then ok "places: runs its classes"; else bad "places: runs its classes"; fi

run FAKE_CONTAINER="$tmp/container-quiet" PLACES_IMPORT_WAIT=1 -- --changed native/UITests/PlaceIconUITests.swift
status=$?
if [ "$status" -ne 0 ]; then ok "places, no import: fails"; else bad "places, no import: fails"; fi
says "places, no import: says why" "the real export was not imported within 1 s, so Places' tests would skip or see no places"
if grep -q "PlaceIconUITests" "$MARKS/xcodebuild"; then bad "places, no import: no class runs to skip"; else ok "places, no import: no class runs to skip"; fi

run -- --changed native/App/Places/PlacesView.swift
status=$?
if [ "$status" -ne 0 ]; then ok "places, no container: fails"; else bad "places, no container: fails"; fi
says "places, no container: says why" "no data container for the app on the simulator"
if grep -q "PlacesUnnamedUITests" "$MARKS/xcodebuild"; then bad "places, no container: no class runs"; else ok "places, no container: no class runs"; fi

run -- --changed native/App/Gym/GymTimerView.swift
status=$?
if [ "$status" -eq 0 ]; then ok "the timer: climbs against the fakes"; else bad "the timer: climbs against the fakes, exit $status"; fi
if grep -q "only-testing:GrabberNativeUITests/GymTimerDialsUITests -only-testing:GrabberNativeUITests/GymTimerUITests test-without-building" "$MARKS/xcodebuild"; then ok "the timer: runs its classes"; else bad "the timer: runs its classes"; fi

# #1038 (story 1016): every climb writes its events to the run ledger under one run id, the selection and where it ran
# included, and the UI test timings it made carry that id. The ledger is the report's input, read here as its consumer
# reads it.
ledger_says() {  # <label> <python assertions over `ev`, the ledger's events, and `rows`, the timing lines>
  if python3 - "$tmp/ledger.jsonl" "$tmp/logs/ui-timings.jsonl" "$2" <<'PY' >>"$out" 2>&1; then ok "$1"; else bad "$1"; fi
import json, os, sys
read = lambda p: [json.loads(l) for l in open(p)] if os.path.exists(p) else []
ev, rows = read(sys.argv[1]), read(sys.argv[2])
kinds = [e["event"] for e in ev]
by = {k: [e for e in ev if e["event"] == k] for k in set(kinds)}
exec(sys.argv[3])
PY
}
run -- --changed native/UITests/CardUITests.swift
ledger_says "the ledger: one run id for the whole climb, the lane's events too" \
  'assert len({e["run_id"] for e in ev}) == 1 and {"start", "lane", "device", "step", "rung", "finish"} <= set(kinds), kinds'
ledger_says "the ledger: the start names the source, the change and what it chose, and where" \
  'st = by["start"][0]; assert len(st["sha"]) == 40 and st["base"] == "--changed" and st["changed"] == ["native/UITests/CardUITests.swift"], st
assert st["classes"]["other"] == ["CardUITests"] and st["classes"]["whiteboard"] == [] and st["smoke"] == "none", st
assert st["destinations"]["phone"] == "iPhone 17" and st["flags"]["sim_build"] == 1, st'
ledger_says "the ledger: the lane and its wait, the device, the build warm or cold" \
  'assert by["lane"][0]["lane"] == 1 and by["lane"][0]["rung"] == "2" and by["lane"][0]["waited_s"] >= 0, by["lane"]
assert by["device"][0]["udid"] == "00000000-0000-0000-0000-000000000000" and by["device"][0]["device"] == "phone"
c = [s for s in by["step"] if s["label"] == "compile"][0]; assert c["status"] == 0 and isinstance(c["warm"], bool), c
assert [s for s in by["step"] if s["label"] == "other classes"][0]["status"] == 0'
ledger_says "the ledger: each rung, and the finish passed" \
  'assert [(r["rung"], r["status"]) for r in by["rung"]] == [("0", 0), ("1", 0), ("1.5", 0), ("2", 0)], by["rung"]
assert by["rung"][2].get("skipped") is True and by["finish"][-1]["outcome"] == "pass" and kinds[-1] == "finish", ev[-3:]'
ledger_says "the ledger: the UI timings carry the climb's run id" \
  'assert rows and {r.get("run_id") for r in rows} == {ev[0]["run_id"]}, rows'
run FAKE_JUST_FAILS=native-test-host -- --changed native/App/Chat/ChatViews.swift
ledger_says "the ledger: a failure, and the rung it first failed on" \
  'f = by["finish"][-1]; assert f["outcome"] == "fail" and f["status"] == 7 and f["first_failure"] == {"rung": "1"}, f
assert "lane" not in kinds'
run FAKE_SKIPS=IPadUITests -- --changed native/UITests/IPadUITests.swift
ledger_says "the ledger: a skip on the iPad is a destination skip" \
  'd = by["destination_skip"][0]; assert d["classes"] == "IPadUITests" and d["skipped"] == 1 and d["udid"].endswith("1"), d
assert by["finish"][-1]["outcome"] == "fail"'
run LADDER_LEDGER=off -- --changed native/UITests/CardUITests.swift
if [ -e "$tmp/ledger.jsonl" ]; then bad "the ledger: off writes nothing"; else ok "the ledger: off writes nothing"; fi
rm -f "$tmp/ledger.jsonl"
LADDER_LEDGER="$tmp/ledger.jsonl" dry --changed native/UITests/CardUITests.swift
if [ -e "$tmp/ledger.jsonl" ]; then bad "the ledger: a dry run writes nothing"; else ok "the ledger: a dry run writes nothing"; fi

# Story 785: four lanes take the first free lane's lock, and one other xcodebuild is no contention.
run BUILD_LANES=4 FAKE_BUSY=always -- --changed native/UITests/CardUITests.swift
status=$?
if [ "$status" -eq 0 ]; then ok "four lanes: one other xcodebuild, still climbs"; else bad "four lanes: one other xcodebuild, still climbs, exit $status"; fi
if grep -qE "^lockf 0 .*/build(-[0-9]+)?\.lock$" "$MARKS/lockf"; then ok "four lanes: a lane's lock, taken at once"; else bad "four lanes: a lane's lock, taken at once"; fi
never "four lanes: no contention note for one other" "more xcodebuilds than the 4 build lanes"
FAKE_BUSY=always BUILD_LANES=4 dry --changed native/App/Chat/ChatViews.swift
never "four lanes: a dry run doesn't wait for one other" "the Mac and simulator rungs would wait"

run FAKE_BUSY=always XCODEBUILD_IDLE_WAIT=0 -- --changed native/UITests/CardUITests.swift
status=$?
if [ "$status" -eq 75 ]; then ok "contention: the Mac or simulator rung refuses"; else bad "contention: refuses, exit $status"; fi
says "contention: says why" "another xcodebuild is running: waiting up to 0s, because a simulator run under contention counts as failed"
if [ -e "$MARKS/xcodebuild" ]; then bad "contention: nothing started"; else ok "contention: nothing started"; fi

run FAKE_BUSY=after-build FAKE_XCODEBUILD_FAILS=1 -- --changed native/UITests/CardUITests.swift
status=$?
if [ "$status" -ne 0 ]; then ok "a failure beside another build: fails"; else bad "a failure beside another build: fails"; fi
says "a failure beside another build: rerun, not debugged" "another xcodebuild ran during this rung: startup waits fail under contention, so this counts as failed; rerun it, don't debug it"
says "a failure beside another build: names the rung" "stopped on rung 2 Simulator (exit 65)"

exit $fail
