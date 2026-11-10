#!/usr/bin/env bash
# Story 683: climb the test ladder (docs/TESTING.md), cheapest rung first, stopping at the first failure, printing the
# seconds per rung and which rung it stopped on. The change is everything on this branch since the base, committed or
# not. Rung 3, the phone, stays Igor's.
#   0 Lint        swift-format over the touched Swift files, SwiftLint over the tree
#   1 Host        ContextCore's tests and the script checks
#   1.5 Mac       the Catalyst build, when the change touches what it compiles (host tests can't compile Mac-only code)
#   2 Simulator   the build with its UI tests, then the UI test classes the change touches; --full: the area's suites
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
    --in-lane) in_lane=1 ;;  # the script itself, once it holds the build lock
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

# The areas' classes. The suite scripts hold what each area runs in full.
chat_area="ChatArchiveUITests ChatImageUITests ChatNewThreadUITests ChatReactionUITests ChatSkillThreadUITests ChatVoiceUITests"
whiteboard_area="WhiteboardOnPaperUITests WhiteboardPaperGhostsUITests WhiteboardPaperLinesUITests WhiteboardPaperPasteUITests WhiteboardPasteUITests WhiteboardRowDeleteUITests WhiteboardTurnUITests"
# #795: the other features' own classes, by directory. Only classes that run on the ladder's simulator and open that
# feature: Windows has none (IPadUITests skips on a phone, MacKeysUITests is the Mac build's), nor Call, Archive or
# LiveActivity, so those paths stay unmapped and the output says so.
gym_area="GymTimerDialsUITests GymTimerUITests"
breathe_area="BreatheMindfulUITests BreathePresetsUITests BreatheStyleUITests"
places_area="PlaceIconUITests PlacesProblemUITests PlacesRangeUITests PlacesUnnamedUITests"
mirror_area="HomeTodayCardUITests MetricDetailUITests"
card_area="CardUITests TodaysHandUITests"
cockpit_area="CockpitBackUITests CockpitCallUITests"
# Apart from the Cockpit's: it asserts the real Cockpit answers, so it would fail every Cockpit change off the tailnet.
usage_area="UsageTileUITests"
daily_area="DailyStripUITests"
eulogy_area="EulogyUITests"
links_area="LinksUITests"

classes=()
unknown=()
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
    scripts/native/bundle-trainer.sh) sim_build=1 mac_build=1 ;;
    scripts/native/*) ;;
    native/UITests/*) sim_build=1 ;;
    *) sim_build=1 mac_build=1 ;;
  esac
  # Which UI test classes can see it.
  case $f in
    *.md) ;;
    native/App/Assets.xcassets/*) ;;  # the host rung's tile-art check
    native/App/Chat/* | native/App/Inbox/* | native/ContextCore/Sources/ContextCore/Chat/* | \
      native/ContextCore/Sources/ContextCore/Inbox/* | scripts/native/test-chat-ui.sh | scripts/native/fake-bridge.py)
      add_classes $chat_area ;;
    native/App/Whiteboard/* | native/ContextCore/Sources/ContextCore/Whiteboard/* | scripts/native/test-whiteboard-ui.sh)
      add_classes $whiteboard_area ;;
    scripts/native/fake-cockpit.py) add_classes $chat_area $whiteboard_area ;;
    native/App/Gym/* | native/ContextCore/Sources/ContextCore/Gym/*) add_classes $gym_area ;;
    native/App/Breathe/* | native/ContextCore/Sources/ContextCore/Breathe/*) add_classes $breathe_area ;;
    native/App/AppSessionHost.swift | native/ContextCore/Sources/ContextCore/Session/*) add_classes $gym_area $breathe_area ;;
    native/App/Places/* | native/ContextCore/Sources/ContextCore/Places/*) add_classes $places_area ;;
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
    native/App/Eulogy/*) add_classes $eulogy_area ;;
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
  # What rung 0 formats: the paths the justfile's native_swift names, if the file is still there.
  case $f in
    native/App/*.swift | native/ContextCore/Package.swift | native/ContextCore/Sources/*.swift | native/ContextCore/Tests/*.swift | \
      native/UITests/*.swift | native/Widgets/*.swift | native/Shared/*.swift | native/Share/*.swift)
      [ -e "$f" ] && swift+=("$f") ;;
  esac
done

if [ "$all" -eq 1 ]; then
  while IFS= read -r c; do classes+=("$c"); done < <(classes_in native/UITests/*.swift)
  unknown=()
fi

# One run per kind of class: chat's fakes differ from the whiteboard's, the whiteboard's needs a fresh boot, and
# Places' need Context Grabber's real export in the app's Documents.
chat=() whiteboard=() places=() other=()
if [ "${#classes[@]}" -gt 0 ]; then
  while IFS= read -r c; do
    case $c in
      Chat*) chat+=("$c") ;;
      Whiteboard*) whiteboard+=("$c") ;;
      Place*) places+=("$c") ;;
      *) other+=("$c") ;;
    esac
  done < <(printf '%s\n' "${classes[@]}" | sort -u)
  sim_build=1
fi
[ "$all" -eq 1 ] && sim_build=1

n_chat=${#chat[@]} n_whiteboard=${#whiteboard[@]} n_places=${#places[@]} n_other=${#other[@]}
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
      echo "rung 2 Simulator: skipped, nothing the simulator build compiles changed"
    fi
    [ "$run_chat_classes" -gt 0 ] && echo "rung 2 UI tests (chat, fake Cockpit and bridge): ${chat[*]}"
    [ "$run_whiteboard_classes" -gt 0 ] && echo "rung 2 UI tests (whiteboard, fake Cockpit, fresh boot): ${whiteboard[*]}"
    [ "$n_places" -gt 0 ] && echo "rung 2 UI tests (places, the real export in Documents): ${places[*]}"
    [ "$n_other" -gt 0 ] && echo "rung 2 UI tests: ${other[*]}"
    if [ "$n_chat" -eq 0 ] && [ "$n_whiteboard" -eq 0 ] && [ "$n_places" -eq 0 ] && [ "$n_other" -eq 0 ] && [ "${#unknown[@]}" -eq 0 ]; then
      echo "rung 2 UI tests: none, no app UI change"
    fi
    if [ "$full" -eq 1 ]; then
      [ "$n_chat" -gt 0 ] && echo "rung 2 full: scripts/native/test-chat-ui.sh"
      [ "$n_whiteboard" -gt 0 ] && echo "rung 2 full: scripts/native/test-whiteboard-ui.sh"
      [ "$n_chat" -eq 0 ] && [ "$n_whiteboard" -eq 0 ] && echo "rung 2 full: no area with a suite touched"
    fi
    say_unmapped
    if [ "$((mac_build + sim_build))" -gt 0 ] && pgrep -x xcodebuild >/dev/null; then
      echo "another xcodebuild is running now: the Mac and simulator rungs would wait for it"
    fi
  fi
  return 0
}

say_unmapped() {
  [ "${#unknown[@]}" -gt 0 ] || return 0
  echo "no UI test map for: ${unknown[*]}"
  echo "so no UI tests were chosen for them; --all runs every UI test class"
}

# The build lane: one job at a time on the simulator and in Xcode, across every agent. Inside the lock the rung first
# waits for other xcodebuilds, then runs under a time limit so a hung run can't hold it (docs/TESTING.md).
lane() {
  mkdir -p "$HOME/tmp/agent/locks"
  LADDER_ASKED=$(date +%s) LADDER_WAITED=$waited LADDER_MINUTES=$2 lockf -k -t 3600 "$HOME/tmp/agent/locks/build.lock" \
    "$self" ${orig[@]+"${orig[@]}"} --rung "$1" --in-lane
}

rung_0() {
  if [ "${#swift[@]}" -gt 0 ]; then
    xcrun swift-format lint --strict --parallel --configuration native/.swift-format "${swift[@]}" || return
  fi
  just native-lint
}

rung_1() { just native-test-host; }

rung_mac() {
  [ "$in_lane" -eq 1 ] || { lane 1.5 30; return; }
  just native-build-mac
}

# Set while rung 2 holds the simulator.
udid= cockpit= bridge= sampler= contended=
stop_fakes() {
  [ -z "$cockpit" ] || kill "$cockpit" 2>/dev/null
  [ -z "$bridge" ] || kill "$bridge" 2>/dev/null
  cockpit= bridge=
}
leave_simulator() {
  stop_fakes
  [ -z "$sampler" ] || { pkill -P "$sampler" 2>/dev/null; kill "$sampler" 2>/dev/null; }
  [ -z "$udid" ] || xcrun simctl shutdown "$udid" 2>/dev/null
  rm -f "${contended:-/nonexistent}"
}
fresh_boot() {
  xcrun simctl shutdown "$udid" 2>/dev/null
  xcrun simctl boot "$udid" && xcrun simctl bootstatus "$udid" >/dev/null || { echo "the simulator did not boot" >&2; return 1; }
}
start_cockpit() {  # <port> <seconds POST /chat is held>
  FAKE_COCKPIT_NEW_DELAY=$2 scripts/native/fake-cockpit.py "$1" "$(mktemp -t fake-cockpit)" >/dev/null 2>&1 &
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
    GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" ${packages[@]+"${packages[@]}"} "$@"
}
only_testing() { for c in "$@"; do printf -- '-only-testing:GrabberNativeUITests/%s\n' "$c"; done; }
step() {  # <label> <command...>: times one step of rung 2
  local label=$1 start=$SECONDS status
  shift
  "$@"
  status=$?
  stop_fakes
  echo "  rung 2 $label: $((SECONDS - start)) s"
  return $status
}

chat_classes() {
  start_cockpit "${CHAT_PORT:-8798}" "${FAKE_COCKPIT_NEW_DELAY:-2}" || return
  scripts/native/fake-bridge.py "${CHAT_BRIDGE_PORT:-8797}" "$(mktemp -t fake-bridge)" >/dev/null 2>&1 &
  bridge=$!
  disown
  sleep 1
  kill -0 "$bridge" 2>/dev/null || { echo "the fake bridge did not start" >&2; return 1; }
  # #812: the hold-menu thread starts without the outbox's earlier answers, as test-chat-ui.sh does (#801).
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl terminate "$udid" com.idvorkin.grabbernative >/dev/null 2>&1 || true
  scripts/native/forget-chat-thread.sh "$udid" com.idvorkin.grabbernative igor2-88g.629 >/dev/null \
    || echo "the outbox's leftovers for igor2-88g.629 could not be removed: ChatReactionUITests may fail on them (#801)" >&2
  TEST_RUNNER_GRABBER_FAKE_COCKPIT="http://localhost:${CHAT_PORT:-8798}" TEST_RUNNER_GRABBER_FAKE_BRIDGE="ws://localhost:${CHAT_BRIDGE_PORT:-8797}" \
    xcodebuild_sim chat "TEST EXECUTE SUCCEEDED" $(only_testing "${chat[@]}") test-without-building
}

whiteboard_classes() {
  local port=${WHITEBOARD_PORT:-8799}
  # Keys reach the app only in the first test after a boot that presses any (test-whiteboard-ui.sh), and one test does.
  fresh_boot || return
  start_cockpit "$port" 0 || return
  TEST_RUNNER_GRABBER_FAKE_COCKPIT="http://localhost:$port" \
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
  # -b boots it if it isn't booted: a bare bootstatus after a boot that failed waits, holding the build lock.
  xcrun simctl bootstatus "$udid" -b >/dev/null || { echo "the simulator did not boot" >&2; return 1; }
  xcrun simctl install "$udid" "$app" || return
  container=$(xcrun simctl get_app_container "$udid" "$bundle" data)
  [ -n "$container" ] || { echo "no data container for the app on the simulator" >&2; return 1; }
  mkdir -p "$container/Documents" || return
  cp -f __tests__/fixtures/context-grabber.db "$container/Documents/import-fixture.db" || return
  since=$(mktemp -t ladder-places)
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

other_classes() { xcodebuild_sim ui-tests "TEST EXECUTE SUCCEEDED" $(only_testing "${other[@]}") test-without-building; }

simulator_steps() {
  # A fresh worktree has no project until it is generated, and a new test file needs it regenerated.
  step project just native-project || return
  step compile xcodebuild_sim build-for-testing "TEST BUILD SUCCEEDED" build-for-testing || return
  if [ "$run_chat_classes" -gt 0 ]; then step "chat classes" chat_classes || return; fi
  if [ "$run_whiteboard_classes" -gt 0 ]; then step "whiteboard classes" whiteboard_classes || return; fi
  if [ "$n_places" -gt 0 ]; then step "places classes" places_classes || return; fi
  if [ "$n_other" -gt 0 ]; then step "other classes" other_classes || return; fi
  [ "$full" -eq 1 ] || return 0
  # The build above is the suites' too (SUITE_PREBUILT; the whiteboard's script doesn't read it yet).
  if [ "$n_chat" -gt 0 ]; then step "chat suite" env SUITE_PREBUILT=1 scripts/native/test-chat-ui.sh "$udid" || return; fi
  if [ "$n_whiteboard" -gt 0 ]; then step "whiteboard suite" scripts/native/test-whiteboard-ui.sh "$udid" || return; fi
}

rung_simulator() {
  [ "$in_lane" -eq 1 ] || { lane 2 $(($full == 1 ? 130 : 60)); return; }
  trap leave_simulator EXIT
  udid=$(scripts/native/sim-udid.sh "${SIM:-iPhone 17}") || return
  # Our own xcodebuild is one; a second is someone else's, and device builds don't take the build lock.
  contended=$(mktemp -u)
  (
    while :; do
      [ "$(pgrep -x xcodebuild | wc -l)" -gt 1 ] && : >"$contended"
      sleep 30
    done
  ) >/dev/null 2>&1 &
  sampler=$!
  disown
  simulator_steps
  local status=$?
  # Our xcodebuild is done here, so any still running is another's.
  pgrep -x xcodebuild >/dev/null && : >"$contended"
  if [ -e "$contended" ]; then
    if [ "$status" -ne 0 ]; then
      echo "another xcodebuild ran during this rung: startup waits fail under contention, so this counts as failed; rerun it, don't debug it"
    else
      echo "note: another xcodebuild ran during this rung; what passed still passed"
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
    tl=$HOME/gits/mac-driver/bin/time-limit limit=()
    if [ -x "$tl" ]; then
      limit=("$tl" "${LADDER_MINUTES:?}")
    else
      echo "no $tl: rung $only runs with no time limit, and a hang holds the build lock" >&2
    fi
    LADDER_TIMED=1 exec ${limit[@]+"${limit[@]}"} caffeinate -i "$self" "${orig[@]}"
  fi
  case $only in
    1.5) rung_mac ;;
    2) rung_simulator ;;
  esac
  exit
fi

report=()
waited=$(mktemp -t ladder-wait)
trap 'rm -f "$waited"' EXIT
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
  if [ "$status" -eq 0 ]; then
    report+=("rung $1 $2: ok, $took")
    return 0
  fi
  report+=("rung $1 $2: FAILED, $took")
  finish
  case $status in
    75) echo "stopped on rung $1 $2: it could not start, the build lock or another xcodebuild was still busy (exit 75)" ;;
    124) echo "stopped on rung $1 $2: it ran past its time limit (exit 124)" ;;
    *) echo "stopped on rung $1 $2 (exit $status)" ;;
  esac
  exit "$status"
}
skipped() { wanted "$1" && report+=("rung $1 $2: skipped"); return 0; }

climb 0 Lint rung_0
climb 1 Host rung_1
if [ "$mac_build" -eq 1 ]; then climb 1.5 Mac rung_mac; else skipped 1.5 Mac; fi
if [ "$sim_build" -eq 1 ]; then climb 2 Simulator rung_simulator; else skipped 2 Simulator; fi
finish
if [ -z "$only" ]; then
  echo "every rung passed; rung 3, the phone, is yours: just native-run-device"
else
  echo "rung $only passed"
fi
