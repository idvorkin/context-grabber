#!/usr/bin/env bash
# Story 683: climb the test ladder (docs/TESTING.md), cheapest rung first, stopping at the first failure, printing the
# seconds per rung and which rung it stopped on. The change is everything on this branch since the base, committed or
# not. Rung 3, the phone, stays Igor's.
#   0 Lint        swift-format over the touched Swift files, SwiftLint over the tree
#   1 Host        ContextCore's tests and the script checks
#   1.5 Mac       the Catalyst build, when the change touches what it compiles (host tests can't compile Mac-only code)
#   2 Simulator   the build with its UI tests, then the UI test classes the change touches, then the smoke's touched
#                 sections on the same build and boot (LADDER_SMOKE=0: not the smoke); --full: the area's suites
# Usage: test-ladder.sh [--dry-run] [--full] [--all] [--base <ref>] [--changed <path>]... [--rung 0|1|1.5|2]
#   --dry-run     print the rungs and classes, run nothing
#   --full        run the suite script of each area touched, in place of that area's classes
#   --all         run every UI test class, whatever changed
#   --base <ref>  what the change is measured from (default origin/main)
#   --changed <p> take this path as changed instead of asking git (repeatable); for trying the map
#   --rung <n>    run only that rung
set -uo pipefail
cd "$(dirname "$0")/../.."
self=scripts/native/test-ladder.sh
orig=("$@")
dry=0 full=0 all=0 in_lane=0 base=origin/main only= given=0
changed=()
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) dry=1 ;;
    --full) full=1 ;;
    --all) all=1 ;;
    --in-lane) in_lane=1 ;;  # the script itself, once it holds a build lane's lock
    --base) base=${2:?--base needs a ref}; shift ;;
    --changed) changed+=("${2:?--changed needs a path}"); given=1; shift ;;
    --rung) only=${2:?--rung needs a rung}; shift ;;
    *) sed -n '/^# Usage/,/^set /p' "$self" | sed -e '$d' -e 's/^# *//' >&2; exit 2 ;;
  esac
  shift
done
case $only in "" | 0 | 1 | 1.5 | 2) ;; *) echo "no rung $only: 0, 1, 1.5 or 2" >&2; exit 2 ;; esac

if [ "$given" -eq 0 ]; then
  fork=$(git merge-base "$base" HEAD) || { echo "no merge base with $base, so no way to say what changed" >&2; exit 2; }
  while IFS= read -r f; do changed+=("$f"); done < <({ git diff --name-only "$fork"; git ls-files --others --exclude-standard; } | sort -u)
fi

# #1038 (story 1016): the run ledger, one JSON line per event of a climb, so a change can be followed from what the
# ladder chose through the lanes to the phone (scripts/native/ladder-report.py). Every event of one climb carries its
# run id, in the lane's process too; LADDER_LEDGER=off writes none. A dry run writes nothing.
ledger=${LADDER_LEDGER:-$HOME/tmp/agent/notes/ladder/runs.jsonl}
note() {  # <event> [jq --arg/--argjson pairs...]
  [ "$dry" -eq 0 ] && [ "$ledger" != off ] && [ -n "${LADDER_RUN_ID:-}" ] || return 0
  command -v jq >/dev/null || return 0
  mkdir -p "${ledger%/*}" 2>/dev/null
  jq -cn --arg run_id "$LADDER_RUN_ID" --arg event "$1" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${@:2}" \
    '$ARGS.named' >>"$ledger" 2>/dev/null || true
}
json_list() { printf '%s\n' "$@" | jq -R . | jq -cs 'map(select(length > 0))'; }

# The areas' classes. The suite scripts hold what each area runs in full. What an iPhone does with boards (story 746) is
# the smoke's whiteboard section, on the phone's simulator (story 770): no class of its own, no second session.
chat_area="ChatArchiveUITests ChatAskSearchUITests ChatCockpitDownUITests ChatDecisionUITests ChatFileUITests ChatImageUITests ChatMoveUITests ChatNewChatAgainUITests ChatNewThreadUITests ChatReactionUITests ChatSkillThreadUITests"
# The whiteboard's are its suite's, one a line there (story 1502): a new class is added in one place.
whiteboard_area=$(grep -oE 'only-testing:[A-Za-z0-9]+UITests/[A-Za-z0-9]+' scripts/native/test-whiteboard-ui.sh | sed 's|.*/||' | LC_ALL=C sort | tr '\n' ' ')
# #795: the other features' own classes, by directory. Only classes that run on the ladder's simulator and open that
# feature: Windows has none (MacKeysUITests is the Mac build's), nor Call, Archive or LiveActivity, so those paths stay
# unmapped and the output says so. IPadUITests (story 150) skips on a phone, so wherever it is chosen (its own file,
# --all) it runs on the iPad's simulator (#1037).
gym_area="GymTimerDialsUITests GymTimerUITests"
breathe_area="BreathePresetsUITests BreatheStyleUITests"
# Story 770: the Mindful test's one rule only the simulator holds is the write to Health; when a session is saved is
# BreathSessionTests on the host. So it runs for the Health source, not for breathing (AppModel's save stays unmapped).
health_write="BreatheMindfulUITests"
places_area="PlaceIconUITests PlacesUnnamedUITests"
mirror_area="HomeTodayCardUITests MetricDetailUITests"
card_area="CardUITests TodaysHandUITests"
cockpit_area="CockpitBackUITests"  # the ☎ call shares its launch (#905)
# Apart from the Cockpit's: it asserts the real Cockpit answers, so it would fail every Cockpit change off the tailnet.
usage_area="UsageTileUITests"
daily_area="DailyStripUITests"
eulogy_area="EulogyUITests"
links_area="LinksUITests"

# #1036: the replay, which the host tests' fixtures run and the app doesn't (the planner and applier it calls are the
# canvas's too, and stay on the whiteboard's every-class row).
replay=native/ContextCore/Sources/ContextCore/Whiteboard/BoardReplay.swift

classes=()
unknown=()
host_only=()
# Story 1021 (bead 8o93): the contract tests on real PaperKit (story 1019's bundle and its touch class), on the iPad.
contracts=0
contract_tests="GrabberNativeContractTests PaperKitTouchContractUITests"
# What drives PaperKit, or is pinned by a contract: a file that imports PaperKit (the board's split files too, whatever
# they come to be called), the board's ink kinds and files, the tool it reads, and the contracts' own tests and stage.
drives_paperkit() {
  case $1 in
    native/ContractTests/* | native/UITests/PaperKitTouchContractUITests.swift | native/App/Whiteboard/PaperTouchStage.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/PaperStageHook.swift | native/App/Whiteboard/PaperBoard*.swift | \
      native/App/Whiteboard/PaperPickedTool.swift | native/App/Whiteboard/WhiteboardStore.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardInk.swift)
      return 0 ;;
    native/App/*.swift) [ -e "$1" ] && grep -qx 'import PaperKit' "$1" ;;
    *) return 1 ;;
  esac
}
# Story 1501: these classes launch the Board Lab, so they are in its bundle (the GrabberNative scheme runs both).
board_lab_classes=" WhiteboardEraserUITests WhiteboardTitleRenameUITests "
swift=()
sim_build=0
mac_build=0
add_classes() { for c in "$@"; do classes+=("$c"); done; }
classes_in() { sed -nE 's/^(final )?class ([A-Za-z0-9_]+): *(XCTestCase|[A-Za-z0-9_]+UITests).*/\2/p' "$@" 2>/dev/null; }
subclasses_of() { sed -nE "s/^(final )?class ([A-Za-z0-9_]+): *$1([^A-Za-z0-9_].*)?\$/\2/p" native/UITests/*.swift 2>/dev/null; }

for f in ${changed[@]+"${changed[@]}"}; do
  # What has to compile. A test script runs the build it needs; a UI test isn't in the Mac build.
  case $f in
    *.md | docs/* | .beads/* | .lavish/* | native/ContextCore/Tests/*) ;;
    scripts/lead-times.py) ;;  # a report read off GitHub, nothing the app builds (story 828)
    scripts/native/bundle-trainer.sh) sim_build=1 mac_build=1 ;;
    scripts/native/*) ;;
    # #1036: the replay of Larry's board changes on a copy of a board. Only the harness and the host tests run it; the
    # app never calls it, so no UI test or smoke can see it. The Mac build still compiles it, as the app links the
    # package; the harness is in no app build at all.
    "$replay") mac_build=1; host_only+=("$f") ;;
    native/ContextCore/Sources/BoardOpsHarness/*) host_only+=("$f") ;;
    native/UITests/* | native/ContractTests/* | native/BoardLab/*) sim_build=1 ;;
    *) sim_build=1 mac_build=1 ;;
  esac
  # Which UI test classes can see it.
  case $f in
    *.md | scripts/lead-times.py) ;;
    native/App/Assets.xcassets/*) ;;  # the host rung's tile-art check
    # Story 1021: the contracts' own stage, its hook and its tests run the contract tests alone (below).
    native/UITests/PaperKitTouchContractUITests.swift | native/App/Whiteboard/PaperTouchStage.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/PaperStageHook.swift | native/ContractTests/*) ;;
    "$replay" | native/ContextCore/Sources/BoardOpsHarness/*) ;;  # #1036: the host's replay fixtures, above
    native/App/Chat/* | native/App/Inbox/* | native/ContextCore/Sources/ContextCore/Chat/* | \
      native/ContextCore/Sources/ContextCore/Inbox/* | scripts/native/test-chat-ui.sh | scripts/native/fake-bridge.py)
      add_classes $chat_area ;;
    # The whiteboard's rules by what shows them (the timing study of 2026-11-10: any whiteboard file ran all 8 classes,
    # 9–11 min). The views, the hooks and the suite's script run them all; so does anything not named here.
    native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardPaste.swift)
      add_classes WhiteboardPasteUITests WhiteboardPaperPasteUITests ;;
    native/ContextCore/Sources/ContextCore/Whiteboard/BoardPaper.swift)
      add_classes WhiteboardPaperLinesUITests WhiteboardOnPaperUITests ;;
    native/ContextCore/Sources/ContextCore/Whiteboard/BoardPages.swift)
      add_classes WhiteboardOnPaperUITests WhiteboardPaperLinesUITests WhiteboardPaperPasteUITests ;;
    native/ContextCore/Sources/ContextCore/Whiteboard/PaperProbe.swift)
      add_classes WhiteboardOnPaperUITests ;;  # what the log says about a touch
    native/ContextCore/Sources/ContextCore/Whiteboard/BoardIndex.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/BoardKeeping.swift | native/App/Whiteboard/WhiteboardListView.swift | \
      native/App/Whiteboard/WhiteboardStore.swift)
      add_classes WhiteboardRowDeleteUITests WhiteboardOnPaperUITests ;;
    # Story 1160: the board's name in its bar renames it.
    native/App/Whiteboard/BoardTitleRename.swift) add_classes WhiteboardTitleRenameUITests WhiteboardPaperLinesUITests ;;
    native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardGhostTurns.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardPacer.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardTurn.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardStream.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardMarks.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardStrokes.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardResponder.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardLarryTurn.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardLarryClock.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardNote.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardSpeech.swift | \
      native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardFrame.swift)
      add_classes WhiteboardTurnUITests WhiteboardPaperGhostsUITests ;;
    # Story 784: the app's board fixture hook adds a board at launch; only the classes that launch with one see it.
    native/App/Whiteboard/WhiteboardHooks.swift) add_classes WhiteboardRowDeleteUITests ChatImageUITests ;;
    # Larry's question cards (stories 880-886): the cards, their model, and the rules in ContextCore.
    native/App/Whiteboard/WhiteboardQuestion* | native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardQuestions.swift)
      add_classes WhiteboardQuestionUITests ;;
    native/ContextCore/Sources/ContextCore/Whiteboard/BoardToText.swift | native/App/Whiteboard/BoardToTextFlow.swift)
      add_classes WhiteboardToTextUITests ;;  # stories 920-922
    native/ContextCore/Sources/ContextCore/Whiteboard/BoardReword.swift | native/App/Whiteboard/BoardRewordFlow.swift)
      add_classes WhiteboardRewordUITests ;;  # stories 940-942
    native/App/Whiteboard/PaperScratch.swift | native/ContextCore/Sources/ContextCore/Whiteboard/WhiteboardScratchOut.swift)
      add_classes WhiteboardScratchOutUITests ;;  # story 890, #999
    # #1041: the note's strip, the problem row and the conversation panel (#1039). The classes that tap or read them:
    # the note, its chevron and the panel (Turn), Keep all (Turn, Connect), the problem's Copy error (OnPaper). The
    # iPhone's tap to Chat is the smoke's whiteboard section.
    # Stories 954, 956–958: playback draws on a canvas of its own, opened only by Play.
    # Story 1203: the look after an Undo or Redo, and its heal.
    native/App/Whiteboard/PaperBoard+UndoRedraw.swift | native/ContextCore/Sources/ContextCore/Whiteboard/BoardUndoRedraw.swift)
      add_classes WhiteboardUndoRedrawUITests WhiteboardDropRoomUITests ;;
    native/App/Whiteboard/WhiteboardPlayback*.swift | native/ContextCore/Sources/ContextCore/Whiteboard/BoardPlayback.swift)
      add_classes WhiteboardPlaybackUITests ;;
    native/App/Whiteboard/WhiteboardConversationStrip.swift)
      add_classes WhiteboardTurnUITests WhiteboardConnectUITests WhiteboardOnPaperUITests ;;
    # A view file of its own gets a row here when it lands, naming the classes that open it (story 784); the board's two
    # big views draw every board, so they and anything unnamed run every class.
    # Story 1222: the PaperKit scratch page and the Settings row that opens it full screen.
    native/App/Whiteboard/PaperKitBoard.swift | native/App/DiagnosticsView.swift) add_classes IPadPaperKitBoardUITests ;;
    native/App/Whiteboard/* | native/ContextCore/Sources/ContextCore/Whiteboard/* | scripts/native/test-whiteboard-ui.sh)
      add_classes $whiteboard_area ;;
    scripts/native/fake-cockpit.py) add_classes $chat_area $whiteboard_area ;;
    native/BoardLab/*) add_classes $board_lab_classes ;;
    native/App/Gym/* | native/ContextCore/Sources/ContextCore/Gym/*) add_classes $gym_area ;;
    native/App/Breathe/* | native/ContextCore/Sources/ContextCore/Breathe/*) add_classes $breathe_area ;;
    native/App/AppSessionHost.swift | native/ContextCore/Sources/ContextCore/Session/*) add_classes $gym_area $breathe_area ;;
    native/App/Places/* | native/ContextCore/Sources/ContextCore/Places/*) add_classes $places_area ;;
    native/App/Mirror/HealthKitSource.swift) add_classes $mirror_area $health_write ;;
    native/App/Mirror/* | native/ContextCore/Sources/ContextCore/Mirror/*) add_classes $mirror_area ;;
    # A file whose feature isn't its directory's, before the directories.
    native/ContextCore/Sources/ContextCore/Card/EulogyRoles.swift) add_classes TodaysHandUITests ;;  # the large widget's role of the day
    native/ContextCore/Sources/ContextCore/Links/BlogLinks.swift) add_classes $eulogy_area ;;
    native/ContextCore/Sources/ContextCore/Links/WorkoutSupermix.swift) add_classes WorkoutSupermixUITests ;;
    native/ContextCore/Sources/ContextCore/Links/HoldChoices.swift) add_classes HoldPopoverUITests ;;
    native/ContextCore/Sources/ContextCore/Links/WindowLedger.swift) unknown+=("$f") ;;  # the windows', which have no class
    native/App/Cockpit/Usage* | native/ContextCore/Sources/ContextCore/Cockpit/Usage* | native/ContextCore/Sources/ContextCore/Cockpit/CockpitUsage.swift)
      add_classes $usage_area ;;
    native/App/Card/* | native/ContextCore/Sources/ContextCore/Card/*) add_classes $card_area ;;
    native/App/Cockpit/* | native/ContextCore/Sources/ContextCore/Cockpit/*) add_classes $cockpit_area ;;
    native/App/Daily/* | native/ContextCore/Sources/ContextCore/Daily/*) add_classes $daily_area ;;
    native/App/Eulogy/* | native/ContextCore/Sources/ContextCore/Eulogy/*) add_classes $eulogy_area ;;
    native/App/Links/* | native/ContextCore/Sources/ContextCore/Links/*) add_classes $links_area ;;
    native/UITests/*.swift)
      in_file=$(classes_in "$f")
      if [ -n "$in_file" ]; then
        # A subclass runs every test of the class it inherits.
        for c in $in_file; do add_classes "$c" $(subclasses_of "$c"); done
      elif [ -e "$f" ]; then
        unknown+=("$f")  # a helper the tests share: which ones use it is a guess
      fi ;;
    native/UITests/* | native/App/* | native/ContextCore/Sources/* | native/ContextCore/Package.swift | \
      native/Shared/* | native/Widgets/* | native/Share/* | native/project.yml)
      unknown+=("$f") ;;
  esac
  # Story 1021: beside its own classes, a file that drives PaperKit runs the contract tests.
  if drives_paperkit "$f"; then contracts=1; sim_build=1; fi
  # What rung 0 formats: the paths the justfile's native_swift names, if the file is still there.
  case $f in
    native/App/*.swift | native/ContextCore/Package.swift | native/ContextCore/Sources/*.swift | native/ContextCore/Tests/*.swift | \
      native/UITests/*.swift | native/Widgets/*.swift | native/Shared/*.swift | native/Share/*.swift | native/BoardLab/*.swift)
      [ -e "$f" ] && swift+=("$f") ;;
  esac
done

if [ "$all" -eq 1 ]; then
  while IFS= read -r c; do classes+=("$c"); done < <(classes_in native/UITests/*.swift)
  unknown=()
fi

# One run per kind of class: chat's fakes differ from the whiteboard's, the whiteboard's runs on the iPad, the iPad's
# own classes too (#1037), and Places' need Context Grabber's real export in the app's Documents.
chat=() whiteboard=() places=() tablet=() other=()
if [ "${#classes[@]}" -gt 0 ]; then
  while IFS= read -r c; do
    case $c in
      Chat*) chat+=("$c") ;;
      Whiteboard*) whiteboard+=("$c") ;;
      PaperKit*) contracts=1 ;;  # the contract tests' own step, on the iPad (story 1021)
      Place*) places+=("$c") ;;
      IPad*) tablet+=("$c") ;;
      *) other+=("$c") ;;
    esac
  done < <(printf '%s\n' "${classes[@]}" | sort -u)
  sim_build=1
fi
[ "$all" -eq 1 ] && sim_build=1 contracts=1

n_chat=${#chat[@]} n_whiteboard=${#whiteboard[@]} n_places=${#places[@]} n_tablet=${#tablet[@]} n_other=${#other[@]}
run_chat_classes=$n_chat run_whiteboard_classes=$n_whiteboard
if [ "$full" -eq 1 ]; then
  run_chat_classes=0
  run_whiteboard_classes=0
fi

wanted() { [ -z "$only" ] || [ "$only" = "$1" ]; }

plan() {
  echo "test ladder: ${#changed[@]} changed path(s), measured from $([ "$given" -eq 1 ] && echo "--changed" || echo "$base")"
  wanted 0 && echo "rung 0 Lint: swift-format over ${#swift[@]} touched Swift file(s), SwiftLint over the tree"
  wanted 1 && echo "rung 1 Host: ContextCore's tests and the script checks"
  if wanted 1.5; then
    if [ "$mac_build" -eq 1 ]; then
      echo "rung 1.5 Mac: the Catalyst build"
    else
      echo "rung 1.5 Mac: skipped, nothing the Mac build compiles changed"
    fi
  fi
  if wanted 2; then
    if [ "$sim_build" -eq 1 ]; then
      echo "rung 2 Simulator: the build with its UI tests"
    else
      if [ "${#host_only[@]}" -gt 0 ]; then
        echo "rung 2 Simulator: skipped, the app never runs what changed; the host rung's replay fixtures do"
      else
        echo "rung 2 Simulator: skipped, nothing the simulator build compiles changed"
      fi
    fi
    [ "${#host_only[@]}" -eq 0 ] || echo "no UI test or smoke of their own, the host rung's replay fixtures hold them (#1036): ${host_only[*]}"
    [ "$run_chat_classes" -gt 0 ] && echo "rung 2 UI tests (chat, fake Cockpit and bridge): ${chat[*]}"
    [ "$run_whiteboard_classes" -gt 0 ] && echo "rung 2 UI tests (whiteboard, on the iPad, fake Cockpit): ${whiteboard[*]}"
    [ "$n_places" -gt 0 ] && echo "rung 2 UI tests (places, the real export in Documents): ${places[*]}"
    [ "$n_tablet" -gt 0 ] && echo "rung 2 UI tests (on the iPad, which they need): ${tablet[*]}"
    [ "$contracts" -eq 1 ] && echo "rung 2 contract tests (real PaperKit, on the iPad, no retry): $contract_tests"
    [ "$n_other" -gt 0 ] && echo "rung 2 UI tests: ${other[*]}"
    if [ "$n_chat" -eq 0 ] && [ "$n_whiteboard" -eq 0 ] && [ "$n_places" -eq 0 ] && [ "$n_tablet" -eq 0 ] && [ "$n_other" -eq 0 ] &&
      [ "$contracts" -eq 0 ] && [ "${#unknown[@]}" -eq 0 ]; then
      echo "rung 2 UI tests: none, no app UI change"
    fi
    if [ "$sim_build" -eq 1 ] && [ "${LADDER_SMOKE:-1}" = 1 ]; then
      echo "rung 2 smoke, on the same build and boot: ${SMOKE_ONLY-$(smoke_sections)}"
    fi
    if [ "$full" -eq 1 ]; then
      [ "$n_chat" -gt 0 ] && echo "rung 2 full: scripts/native/test-chat-ui.sh"
      [ "$n_whiteboard" -gt 0 ] && echo "rung 2 full: scripts/native/test-whiteboard-ui.sh"
      [ "$n_chat" -eq 0 ] && [ "$n_whiteboard" -eq 0 ] && echo "rung 2 full: no area with a suite touched"
    fi
    say_unmapped
    if [ "$((mac_build + sim_build))" -gt 0 ] && [ "$(xcodebuilds)" -ge "$lanes" ]; then
      if [ "$lanes" -le 1 ]; then
        echo "another xcodebuild is running now: the Mac and simulator rungs would wait for it"
      else
        echo "$(xcodebuilds) xcodebuilds are running now, one for each of the $lanes build lanes: the Mac and simulator rungs would wait for one to finish"
      fi
    fi
  fi
  return 0
}

say_unmapped() {
  [ "${#unknown[@]}" -gt 0 ] || return 0
  echo "no UI test map for: ${unknown[*]}"
  echo "so no UI tests were chosen for them; --all runs every UI test class"
}

# The build lanes (story 785): one job per lane on the simulator and in Xcode, across every agent, as many lanes as the
# Mac's memory holds (one on a 16 GB Mac). Inside its lane's lock the rung first waits for other xcodebuilds, then runs
# under a time limit so a hung run can't hold it (docs/TESTING.md).
lane() {
  LADDER_ASKED=$(date +%s) LADDER_WAITED=$waited LADDER_MINUTES=$2 scripts/native/build-lane.sh run \
    "$self" ${orig[@]+"${orig[@]}"} --rung "$1" --in-lane
}
lanes=$(scripts/native/build-lane.sh count)
xcodebuilds() { pgrep -x xcodebuild 2>/dev/null | wc -l | tr -d ' '; }

rung_0() {
  if [ "${#swift[@]}" -gt 0 ]; then
    scripts/native/host-lane.sh run xcrun swift-format lint --strict --parallel --configuration native/.swift-format "${swift[@]}" || return
  fi
  just native-lint
}

rung_1() { just native-test-host; }

rung_mac() {
  [ "$in_lane" -eq 1 ] || { lane 1.5 30; return; }
  local start=$SECONDS warm=false status
  [ -d native/Build/Build/Products/Debug-maccatalyst ] && warm=true
  just native-build-mac
  status=$?
  note step --arg rung 1.5 --arg label "Mac build" --argjson secs $((SECONDS - start)) --argjson status "$status" \
    --argjson warm "$warm"
  return $status
}

# Set while rung 2 holds the simulator: udid is the device the current step runs on, the phone's or the iPad's.
udid= phone= ipad= cockpit= bridge= sampler= contended=
stop_fakes() {
  [ -z "$cockpit" ] || kill "$cockpit" 2>/dev/null
  [ -z "$bridge" ] || kill "$bridge" 2>/dev/null
  cockpit= bridge=
}
# Story 980: the simulator stays booted for the next run, as each boot writes about 300 MB of wallpaper snapshots the
# system never removes, and heats the Mac. Story 983: unless the Mac is hot, when a booted simulator only adds heat.
leave_simulator() {
  stop_fakes
  [ -z "$sampler" ] || { pkill -P "$sampler" 2>/dev/null; kill "$sampler" 2>/dev/null; }
  if [ -n "$udid" ] && mac_hot; then
    echo "the Mac is hot ($hot_why): the simulator is shut down rather than left booted"
    xcrun simctl shutdown "$udid" 2>/dev/null
  fi
  # Story 987: the shut-down simulators' wallpaper snapshots go when the rung ends (the booted one keeps its own).
  [ -z "$udid" ] || scripts/native/sim-poster-prune.sh || true
  rm -f "${contended:-/nonexistent}"
}
# A thermal or performance warning recorded by macOS. Not the load: on this Mac it counts hung processes, not heat.
hot_why=
mac_hot() {
  hot_why=$(pmset -g therm 2>/dev/null | grep -iE 'warning level set to [1-9]' | head -1)
  [ -n "$hot_why" ]
}
# Story 980: the step's device becomes the one booted simulator; it boots only if it isn't up already.
use_device() {  # <udid>
  udid=$1
  note device --arg rung 2 --arg udid "$udid" --arg device "$([ "$udid" = "${ipad:-}" ] && echo ipad || echo phone)"
  scripts/native/sim-boot.sh "$udid"
}
start_cockpit() {  # <port> <seconds POST /chat is held>
  FAKE_COCKPIT_NEW_DELAY=$2 scripts/native/fake-cockpit.py "$1" "$(mktemp "${TMPDIR:-/tmp}/fake-cockpit.XXXXXX")" >/dev/null 2>&1 &
  cockpit=$!
  disown
  sleep 1
  kill -0 "$cockpit" 2>/dev/null || { echo "the fake Cockpit did not start on port $1" >&2; return 1; }
}
xcodebuild_sim() {  # <log name> <done line> <xcodebuild arguments...>
  local name=$1 done=$2 packages=()
  shift 2
  # A run of what this climb just built: its packages were resolved by that build minutes ago, so don't ask the remotes
  # again. A build itself still resolves, so a moved BugKit or ThinkACard pin is fetched.
  case " $* " in *" test-without-building "*) packages=(-skipPackageUpdates) ;; esac
  scripts/native/xcodebuild-log.sh "ladder-$name" "$done" \
    xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath native/Build \
    -destination "platform=iOS Simulator,id=$udid" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
    GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" \
    BUGKIT_COMMIT="$(git describe --always --dirty --exclude='*')" ${packages[@]+"${packages[@]}"} "$@"
}
# The smoke's sections for the paths this climb takes as changed (--changed's, or git's since the base).
smoke_sections() { scripts/native/smoke-features.sh "$base" ${changed[@]+"${changed[@]}"}; }
only_testing() {
  for c in "$@"; do
    case "$board_lab_classes" in *" $c "*) printf -- '-only-testing:BoardLabUITests/%s\n' "$c" ;;
    *) printf -- '-only-testing:GrabberNativeUITests/%s\n' "$c" ;; esac
  done
}
step_warm=  # set just before a build step: whether the lane's build folder already held a build (#1038)
step() {  # <label> <command...>: times one step of rung 2
  local label=$1 start=$SECONDS status warm=$step_warm
  shift
  step_warm=
  "$@"
  status=$?
  stop_fakes
  echo "  rung 2 $label: $((SECONDS - start)) s"
  [ "$status" -eq 0 ] || echo "  rung 2 $label: failed (exit $status)"
  note step --arg rung 2 --arg label "$label" --argjson secs $((SECONDS - start)) --argjson status "$status" \
    ${warm:+--argjson warm "$warm"}
  return $status
}

# Story 1628: LADDER_KEEP_GOING=1 (the store walk) runs every class step even after one fails, so one red class can't
# hide the rest; the rung still fails. A failed build, project or device boot still stops it.
keep_failed=0
kept() {  # <status>: in keep-going mode, remember a failed step and carry on; otherwise pass the status through
  [ "$1" -eq 0 ] && return 0
  if [ "${LADDER_KEEP_GOING:-0}" = 1 ]; then keep_failed=1; return 0; fi
  return "$1"
}

chat_classes() {
  start_cockpit "${CHAT_PORT:-$((8798 + ${BUILD_LANE_PORT_OFFSET:-0}))}" "${FAKE_COCKPIT_NEW_DELAY:-2}" || return
  scripts/native/fake-bridge.py "${CHAT_BRIDGE_PORT:-$((8797 + ${BUILD_LANE_PORT_OFFSET:-0}))}" "$(mktemp "${TMPDIR:-/tmp}/fake-bridge.XXXXXX")" >/dev/null 2>&1 &
  bridge=$!
  disown
  sleep 1
  kill -0 "$bridge" 2>/dev/null || { echo "the fake bridge did not start" >&2; return 1; }
  # #812: the hold-menu thread starts without the outbox's earlier answers, as test-chat-ui.sh does (#801).
  xcrun simctl terminate "$udid" com.idvorkin.grabbernative >/dev/null 2>&1 || true
  scripts/native/forget-chat-thread.sh "$udid" com.idvorkin.grabbernative igor2-88g.629 >/dev/null \
    || echo "the outbox's leftovers for igor2-88g.629 could not be removed: ChatReactionUITests may fail on them (#801)" >&2
  TEST_RUNNER_GRABBER_FAKE_COCKPIT="http://localhost:${CHAT_PORT:-$((8798 + ${BUILD_LANE_PORT_OFFSET:-0}))}" TEST_RUNNER_GRABBER_FAKE_BRIDGE="ws://localhost:${CHAT_BRIDGE_PORT:-$((8797 + ${BUILD_LANE_PORT_OFFSET:-0}))}" \
    xcodebuild_sim chat "TEST EXECUTE SUCCEEDED" $(only_testing "${chat[@]}") test-without-building
}

# Story 746: an iPhone only looks at boards, so the drawing classes run on an iPad simulator (ipad_steps).
whiteboard_classes() {
  local port=${WHITEBOARD_PORT:-$((8799 + ${BUILD_LANE_PORT_OFFSET:-0}))}
  start_cockpit "$port" 0 \
    && TEST_RUNNER_GRABBER_FAKE_COCKPIT="http://localhost:$port" \
      xcodebuild_sim whiteboard "TEST EXECUTE SUCCEEDED" $(only_testing "${whiteboard[@]}") test-without-building
}

places_classes() {
  # Places' classes want Context Grabber's real export imported, as the smoke imports it (sim-smoke.sh): the file in
  # the app's Documents, then one launch with the import hook. PlaceIconUITests imports nothing itself and runs before
  # the classes that do, so without the launch it would skip on a clean simulator. The data container outlives the
  # install the test run makes.
  # The justfile's native_sim_app and native_bundle.
  local app=native/Build/Build/Products/Debug-iphonesimulator/GrabberNative.app bundle=com.idvorkin.grabbernative
  local container since waited=0
  xcrun simctl install "$udid" "$app" || return
  container=$(xcrun simctl get_app_container "$udid" "$bundle" data)
  [ -n "$container" ] || { echo "no data container for the app on the simulator" >&2; return 1; }
  mkdir -p "$container/Documents" || return
  cp -f __tests__/fixtures/context-grabber.db "$container/Documents/import-fixture.db" || return
  since=$(mktemp "${TMPDIR:-/tmp}/ladder-places.XXXXXX")
  xcrun simctl terminate "$udid" "$bundle" >/dev/null 2>&1
  SIMCTL_CHILD_GRABBER_IMPORT_DB="import-fixture.db,recent" xcrun simctl launch "$udid" "$bundle" >/dev/null || { rm -f "$since"; return 1; }
  # The import's own event in a session log this launch wrote: never a wait for a time.
  until find "$container/Documents/logs" -name '*.jsonl' -newer "$since" -exec cat {} + 2>/dev/null |
    jq -e 'select(.type == "import" and .ok == true)' >/dev/null 2>&1; do
    if [ "$waited" -ge "${PLACES_IMPORT_WAIT:-60}" ]; then
      echo "the real export was not imported within ${PLACES_IMPORT_WAIT:-60} s, so Places' tests would skip or see no places" >&2
      rm -f "$since"
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
  rm -f "$since"
  xcrun simctl terminate "$udid" "$bundle" >/dev/null 2>&1
  xcodebuild_sim places "TEST EXECUTE SUCCEEDED" $(only_testing "${places[@]}") test-without-building
}

# Story 1021: the contract tests, hosted and touched, on the iPad. No retry: a contract that fails once has moved.
contract_classes() {
  UI_TEST_RETRY=0 xcodebuild_sim contracts "TEST EXECUTE SUCCEEDED" -only-testing:GrabberNativeContractTests \
    -only-testing:GrabberNativeUITests/PaperKitTouchContractUITests test-without-building
}

other_classes() { xcodebuild_sim ui-tests "TEST EXECUTE SUCCEEDED" $(only_testing "${other[@]}") test-without-building; }

# #1037: the iPad's own classes, on the iPad. A test of theirs that skips there skipped for its destination (they skip
# only off an iPad), so it fails the step rather than pass as a skip; the step says how many ran, passed and skipped.
tablet_classes() {
  local log=${NATIVE_LOG_DIR:-native/Build/logs}/ladder-ipad-ui-tests.log status passed failed skipped
  xcodebuild_sim ipad-ui-tests "TEST EXECUTE SUCCEEDED" $(only_testing "${tablet[@]}") test-without-building
  status=$?
  # One line per run of a case: a failure and its retry count twice.
  ran() { grep -cE "^Test Case '-\[GrabberNativeUITests\.[A-Za-z0-9_]+ [A-Za-z0-9_]+\]' $1 " "$log" 2>/dev/null; }
  passed=$(ran passed) failed=$(ran failed) skipped=$(ran skipped)
  echo "  the iPad's classes on $udid: ${passed:-0} passed, ${failed:-0} failed, ${skipped:-0} skipped"
  if [ "${skipped:-0}" -gt 0 ]; then
    note destination_skip --arg udid "$udid" --arg classes "${tablet[*]}" --argjson skipped "$skipped"
    echo "the iPad's classes skipped ${skipped} test(s) on the iPad simulator: a skip there is the wrong destination, not a pass (#1037)" >&2
    return 1
  fi
  return $status
}

# The steps on the iPhone's simulator: everything but the whiteboard's drawing.
phone_steps() {
  step "iPhone simulator" use_device "$phone" || return
  if [ "$run_chat_classes" -gt 0 ]; then step "chat classes" chat_classes; kept $? || return; fi
  if [ "$n_places" -gt 0 ]; then step "places classes" places_classes; kept $? || return; fi
  if [ "$n_other" -gt 0 ]; then step "other classes" other_classes; kept $? || return; fi
  # Story 755: the smoke's touched sections on this build and this boot, rather than a second build and boot from
  # `just native-test-sim` (the same build: native-build-sim's flags). LADDER_SMOKE=0 leaves it out.
  if [ "${LADDER_SMOKE:-1}" = 1 ]; then
    step smoke env SMOKE_ONLY="${SMOKE_ONLY-$(smoke_sections)}" \
      bash "${SIM_SMOKE:-scripts/native/sim-smoke.sh}" "$udid" com.idvorkin.grabbernative \
      native/Build/Build/Products/Debug-iphonesimulator/GrabberNative.app; kept $? || return
  fi
  if [ "$full" -eq 1 ] && [ "$n_chat" -gt 0 ]; then
    step "chat suite" env SUITE_PREBUILT=1 scripts/native/test-chat-ui.sh "$udid" || return
  fi
  return 0
}
phone_needed() {
  [ "$run_chat_classes" -gt 0 ] || [ "$n_places" -gt 0 ] || [ "$n_other" -gt 0 ] || [ "${LADDER_SMOKE:-1}" = 1 ] ||
    { [ "$full" -eq 1 ] && [ "$n_chat" -gt 0 ]; }
}
# Story 746: the whiteboard's drawing classes, and its suite, on the iPad's simulator; #1037: the iPad's own classes
# after them, on the same boot.
ipad_steps() {
  if [ "$n_whiteboard" -gt 0 ]; then
    if [ "$full" -eq 1 ]; then
      udid=$ipad
      step "whiteboard suite" env SUITE_PREBUILT=1 scripts/native/test-whiteboard-ui.sh "$udid" || return
    else
      # ponytail: keys reach the app only in the first test after a boot that presses any (test-whiteboard-ui.sh), so
      # the ⌘V class still gets a fresh boot. Story 982 is to find the real fix; until then only that class pays a boot.
      case " ${whiteboard[*]-} " in
        *" WhiteboardPasteUITests "*) xcrun simctl shutdown "$ipad" 2>/dev/null ;;
      esac
      step "iPad simulator" use_device "$ipad" || return
      step "whiteboard classes" whiteboard_classes; kept $? || return
    fi
  fi
  if [ "$n_tablet" -gt 0 ]; then
    # After the whiteboard's suite the iPad is still up, so this boots only when nothing ran on it yet.
    step "iPad simulator" use_device "$ipad" || return
    step "iPad classes" tablet_classes; kept $? || return
  fi
  if [ "$contracts" -eq 1 ]; then
    step "iPad simulator" use_device "$ipad" || return
    step "contract tests" contract_classes; kept $? || return
  fi
  return 0
}
ipad_needed() { [ "$n_whiteboard" -gt 0 ] || [ "$n_tablet" -gt 0 ] || [ "$contracts" -eq 1 ]; }

simulator_steps() {
  # A fresh worktree has no project until it is generated, and a new test file needs it regenerated.
  step project just native-project || return
  step_warm=false
  [ -d native/Build/Build/Products/Debug-iphonesimulator/GrabberNative.app ] && step_warm=true
  step compile xcodebuild_sim build-for-testing "TEST BUILD SUCCEEDED" build-for-testing || return
  # Story 981: a climb switches device at most once. The device already booted goes first, so a run after a whiteboard
  # run starts on the iPad it left booted, and one after any other on the phone.
  local groups=()
  phone_needed && groups+=(phone)
  if ipad_needed; then
    ipad=$(scripts/native/sim-udid.sh "${WHITEBOARD_SIM:-iPad Pro 11-inch (M5)}") || return
    if xcrun simctl list devices booted | grep -qF "($ipad)"; then groups=(ipad ${groups[@]+"${groups[@]}"}); else groups+=(ipad); fi
  fi
  for g in ${groups[@]+"${groups[@]}"}; do "${g}_steps" || return; done
  [ "$keep_failed" -eq 0 ]
}

rung_simulator() {
  # Story 782: UI tests stall while the Mac's display is off (the 915 run of 2026-11-16 sat 17 minutes before its first
  # test on a dark Mac), so the rung lights the display and holds it on from here (`caffeinate -d` below); story 783
  # stops a run that still doesn't start. A locked screen is no reason to wait (bead context-grabber-wm8y): every UI test
  # runs locked as unlocked but those that open the mic, which the test run's wrapper skips and names.
  caffeinate -u -t 5 >/dev/null 2>&1 &
  # shellcheck source=scripts/native/smoke-lock.sh
  . scripts/native/smoke-lock.sh
  mac_locked && echo "the Mac's screen is locked: rung 2 runs, skipping the tests that open the mic (scripts/native/mic-tests.txt)" >&2
  [ "$in_lane" -eq 1 ] || { lane 2 $(($full == 1 ? 130 : 60)); return; }
  trap leave_simulator EXIT
  phone=$(scripts/native/sim-udid.sh "${SIM:-iPhone 17}") || return
  udid=$phone  # the build's destination
  # Our own xcodebuild is one, and each other lane may run one; more than the lanes is contention, and device builds
  # don't take a lane's lock.
  contended=$(mktemp -u)
  (
    while :; do
      [ "$(xcodebuilds)" -gt "$lanes" ] && : >"$contended"
      sleep 30
    done
  ) >/dev/null 2>&1 &
  sampler=$!
  disown
  simulator_steps
  local status=$?
  # Our xcodebuild is done here, so any still running is another's: as many as the lanes is contention.
  [ "$(xcodebuilds)" -ge "$lanes" ] && : >"$contended"
  if [ -e "$contended" ]; then
    if [ "$status" -ne 0 ]; then
      if [ "$lanes" -le 1 ]; then
        echo "another xcodebuild ran during this rung: startup waits fail under contention, so this counts as failed; rerun it, don't debug it"
      else
        echo "more xcodebuilds than the $lanes build lanes ran during this rung: startup waits fail under contention, so this counts as failed; rerun it, don't debug it"
      fi
    elif [ "$lanes" -le 1 ]; then
      echo "note: another xcodebuild ran during this rung; what passed still passed"
    else
      echo "note: more xcodebuilds than the $lanes build lanes ran during this rung; what passed still passed"
    fi
  fi
  return $status
}

[ "$in_lane" -eq 1 ] || plan
[ "$dry" -eq 0 ] || exit 0

if [ "$in_lane" -eq 1 ]; then
  if [ -z "${LADDER_TIMED:-}" ]; then
    scripts/native/xcodebuild-idle.sh || exit
    # How long the lock and the other xcodebuilds took, for the report: the rung's own seconds are the rest.
    [ -z "${LADDER_WAITED:-}" ] || echo $(($(date +%s) - LADDER_ASKED)) >"$LADDER_WAITED"
    note lane --arg rung "$only" --argjson lane "${BUILD_LANE:-1}" --argjson lanes "$lanes" \
      --argjson waited_s $(($(date +%s) - ${LADDER_ASKED:-$(date +%s)}))
    # Story 1505 (context-grabber-xmwp): the repo's own time limit, so a Mac without mac-driver still times the rung.
    # One that can't be found stops the rung, rather than letting it run with none and hold the lane.
    tl=${LADDER_TIME_LIMIT:-scripts/native/time-limit.sh}
    if [ ! -x "$tl" ]; then
      echo "no time limit at $tl: rung $only not started, as a hang would hold build lane ${BUILD_LANE:-1}" >&2
      exit 2
    fi
    limit=("$tl" "${LADDER_MINUTES:?}")
    # Story 782: the simulator rung holds the display on too (-d), as UI tests stall on a dark screen; -i alone keeps
    # the Mac awake but lets the display sleep, and with the lock set to "immediately" that locks it.
    keep=(-i)
    [ "$only" = 2 ] && keep=(-d -i)
    # The lane's settings go past the time limit by hand (context-grabber-jacw): a time limit given in LADDER_TIME_LIMIT
    # may be mac-driver's zsh one, which reads ~/.zshenv, and a BUILD_LANES there would replace this lane's count.
    LADDER_TIMED=1 exec "${limit[@]}" env BUILD_LANES="$lanes" caffeinate "${keep[@]}" "$self" "${orig[@]}"
  fi
  case $only in
    1.5) rung_mac ;;
    2) rung_simulator ;;
  esac
  exit
fi

report=()
waited=$(mktemp "${TMPDIR:-/tmp}/ladder-wait.XXXXXX")
trap 'rm -f "$waited"' EXIT
# #1038: the climb's start, with what it chose and why; the lane's process inherits the run id.
export LADDER_RUN_ID=${LADDER_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}
if [ "$ledger" != off ] && command -v jq >/dev/null; then
  note start --arg sha "$(git rev-parse HEAD 2>/dev/null)" --arg branch "$(git branch --show-current 2>/dev/null)" \
    --arg base "$([ "$given" -eq 1 ] && echo --changed || echo "$base")" --arg fork "${fork:-}" \
    --argjson changed "$(json_list ${changed[@]+"${changed[@]}"})" \
    --argjson classes "$(jq -cn --argjson chat "$(json_list ${chat[@]+"${chat[@]}"})" \
      --argjson whiteboard "$(json_list ${whiteboard[@]+"${whiteboard[@]}"})" --argjson places "$(json_list ${places[@]+"${places[@]}"})" \
      --argjson ipad "$(json_list ${tablet[@]+"${tablet[@]}"})" --argjson other "$(json_list ${other[@]+"${other[@]}"})" '$ARGS.named')" \
    --arg smoke "$([ "$sim_build" -eq 1 ] && [ "${LADDER_SMOKE:-1}" = 1 ] && echo "${SMOKE_ONLY-$(smoke_sections)}")" \
    --argjson destinations "$(jq -cn --arg phone "${SIM:-iPhone 17}" --arg ipad "${WHITEBOARD_SIM:-iPad Pro 11-inch (M5)}" '$ARGS.named')" \
    --argjson host_only "$(json_list ${host_only[@]+"${host_only[@]}"})" --argjson unknown "$(json_list ${unknown[@]+"${unknown[@]}"})" \
    --argjson flags "$(jq -cn --argjson full "$full" --argjson all "$all" --arg rung "$only" --argjson mac_build "$mac_build" \
      --argjson contracts "$contracts" \
      --argjson sim_build "$sim_build" '$ARGS.named')"
  echo "ladder run id: $LADDER_RUN_ID (the run ledger: $ledger)"
fi
# A climb stopped by a signal says so; one that ends with no finish line at all (a crash, a reboot) is the report's
# "censored".
trap 'note finish --arg outcome interrupted --argjson status 130; exit 130' INT TERM
finish() {
  echo "seconds per rung:"
  printf '  %s\n' "${report[@]}"
  say_unmapped
}
climb() {  # <rung> <name> <function>
  wanted "$1" || return 0
  local start=$SECONDS status took lock_wait=0
  : >"$waited"
  "$3"
  status=$?
  [ -s "$waited" ] && lock_wait=$(<"$waited")
  took="$((SECONDS - start - lock_wait)) s"
  [ "$lock_wait" -eq 0 ] || took="$took, after $lock_wait s waiting for the build lock and other xcodebuilds"
  note rung --arg rung "$1" --arg name "$2" --argjson secs $((SECONDS - start - lock_wait)) --argjson waited_s "$lock_wait" \
    --argjson status "$status"
  if [ "$status" -eq 0 ]; then
    report+=("rung $1 $2: ok, $took")
    return 0
  fi
  report+=("rung $1 $2: FAILED, $took")
  local outcome=fail
  case $status in 75) outcome=unavailable ;; 124) outcome=timeout ;; 130 | 143) outcome=interrupted ;; esac
  note finish --arg outcome "$outcome" --argjson status "$status" --argjson first_failure "$(jq -cn --arg rung "$1" '$ARGS.named')"
  finish
  case $status in
    75) echo "stopped on rung $1 $2: it could not run: the build lock or another xcodebuild was still busy, the screen was locked, no test started, or a test failed after the screen locked during it (story 1018); the lines above say which (exit 75)" ;;
    124) echo "stopped on rung $1 $2: it ran past its time limit (exit 124)" ;;
    *) echo "stopped on rung $1 $2 (exit $status)" ;;
  esac
  exit "$status"
}
skipped() {
  wanted "$1" || return 0
  report+=("rung $1 $2: skipped")
  note rung --arg rung "$1" --arg name "$2" --argjson secs 0 --argjson status 0 --argjson skipped true
}

climb 0 Lint rung_0
climb 1 Host rung_1
if [ "$mac_build" -eq 1 ]; then climb 1.5 Mac rung_mac; else skipped 1.5 Mac; fi
if [ "$sim_build" -eq 1 ]; then climb 2 Simulator rung_simulator; else skipped 2 Simulator; fi
note finish --arg outcome pass --argjson status 0
finish
if [ -z "$only" ]; then
  echo "every rung passed; rung 3, the phone, is yours: just native-run-device"
else
  echo "rung $only passed"
fi
