#!/usr/bin/env bash
# Host test for the ladder (story 683): runs the real scripts/native/test-ladder.sh and reads what it says. The dry runs
# check which rungs and UI test classes a change gets; the rest run it with fake just, xcodebuild, xcrun, lockf, pgrep and
# uv, so nothing builds, nothing boots and nothing takes the real lock.
set -uo pipefail
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
case " $* " in
  *" build-for-testing "*) echo "** TEST BUILD SUCCEEDED **" ;;
  *) echo "** TEST EXECUTE SUCCEEDED **" ;;
esac
F
cat >"$fakes/xcrun" <<'F'
#!/usr/bin/env bash
echo "xcrun $*" >>"$MARKS/xcrun"
case "$*" in
  "simctl list devices available") printf '    iPhone 17 (00000000-0000-0000-0000-000000000000) (Shutdown)\n' ;;
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
cat >"$fakes/uv" <<'F'
#!/usr/bin/env bash
exec sleep 30
F
chmod +x "$fakes"/*
dry() { PATH="$fakes:$PATH" "$ladder" --dry-run "$@" >"$out" 2>&1; }
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
  rm -f "$MARKS"/*
  env PATH="$fakes:$PATH" SIM="iPhone 17" NATIVE_LOG_DIR="$tmp/logs" CHAT_PORT="$chat_port" CHAT_BRIDGE_PORT="$bridge_port" WHITEBOARD_PORT="$board_port" \
    XCODEBUILD_IDLE_POLL=1 ${vars[@]+"${vars[@]}"} "$ladder" "$@" >"$out" 2>&1
}

chat_all="ChatArchiveUITests ChatImageUITests ChatNewThreadUITests ChatReactionUITests ChatSkillThreadUITests ChatVoiceUITests"
board_all="WhiteboardOnPaperUITests WhiteboardPaperGhostsUITests WhiteboardPaperLinesUITests WhiteboardPaperPasteUITests WhiteboardPasteUITests WhiteboardRowDeleteUITests WhiteboardTurnUITests"

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
says "whiteboard code: its classes" "rung 2 UI tests (whiteboard, fake Cockpit, fresh boot): $board_all"
never "whiteboard code: no chat" "Chat"

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
feature breathe native/App/Breathe/BreatheView.swift $core/Breathe/BreathEngine.swift "" "BreatheMindfulUITests BreathePresetsUITests BreatheStyleUITests"
feature places native/App/Places/PlacesView.swift $core/Places/StayClustering.swift " (places, the real export in Documents)" "PlaceIconUITests PlacesUnnamedUITests"
feature mirror native/App/Mirror/MetricDetailView.swift $core/Mirror/MirrorGrab.swift "" "HomeTodayCardUITests MetricDetailUITests"
feature card native/App/Card/CardView.swift $core/Card/CardDeal.swift "" "CardUITests TodaysHandUITests"
feature cockpit native/App/Cockpit/CockpitView.swift $core/Cockpit/CockpitPage.swift "" "CockpitBackUITests CockpitCallUITests"
# The usage tile's test needs the real Cockpit, so only the usage files ask for it.
feature usage native/App/Cockpit/UsageModel.swift $core/Cockpit/UsageSnapshot.swift "" "UsageTileUITests"
feature "usage strip" native/App/Cockpit/UsageStripView.swift $core/Cockpit/CockpitUsage.swift "" "UsageTileUITests"
never "usage: not the Cockpit's" "CockpitBackUITests"
dry --changed native/App/Cockpit/CockpitView.swift
never "cockpit code: not the usage tile, which needs the tailnet" "UsageTileUITests"
feature daily native/App/Daily/DailyStripView.swift $core/Daily/DailyStrip.swift "" "DailyStripUITests"
feature eulogy native/App/Eulogy/EulogySong.swift "" "" "EulogyUITests"
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

# No class on the ladder's simulator opens a second window (IPadUITests skips on a phone), so Windows stays unmapped.
dry --changed native/App/Windows/WindowViews.swift
says "unmapped code: says so" "no UI test map for: native/App/Windows/WindowViews.swift"
says "unmapped code: names the option" "so no UI tests were chosen for them; --all runs every UI test class"
never "unmapped code: chooses nothing" "rung 2 UI tests"

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

FAKE_BUSY=always dry --changed native/App/Chat/ChatViews.swift
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
if [ -e "$MARKS/lockf" ]; then bad "a host failure: nothing climbs past it"; else ok "a host failure: nothing climbs past it"; fi
if grep -qF "rung 0 Lint: ok," "$out"; then ok "a host failure: lint's seconds"; else bad "a host failure: lint's seconds"; fi

run FAKE_JUST_FAILS=native-build-mac -- --changed native/App/Chat/ChatViews.swift
says "a Mac failure: names the rung" "stopped on rung 1.5 Mac (exit 7)"
if [ -e "$MARKS/xcodebuild" ]; then bad "a Mac failure: the simulator never starts"; else ok "a Mac failure: the simulator never starts"; fi

run -- --changed docs/TESTING.md
status=$?
if [ "$status" -eq 0 ] && [ ! -e "$MARKS/lockf" ]; then ok "docs: climbs without the lane"; else bad "docs: climbs without the lane"; fi
says "docs: the Mac skipped in the seconds" "  rung 1.5 Mac: skipped"
says "docs: the end names the phone" "every rung passed; rung 3, the phone, is yours: just native-run-device"

run -- --changed native/UITests/CardUITests.swift
status=$?
if [ "$status" -eq 0 ]; then ok "a test file: climbs"; else bad "a test file: climbs, exit $status"; fi
if grep -qF "build.lock" "$MARKS/lockf"; then ok "the simulator rung takes the build lock"; else bad "the simulator rung takes the build lock"; fi
if head -1 "$MARKS/xcodebuild" | grep -q " build-for-testing"; then ok "the build comes first"; else bad "the build comes first"; fi
if grep -q "only-testing:GrabberNativeUITests/CardUITests test-without-building" "$MARKS/xcodebuild"; then ok "then its class alone"; else bad "then its class alone"; fi
if grep -q "simctl shutdown" "$MARKS/xcrun"; then ok "the simulator is shut down after"; else bad "the simulator is shut down after"; fi

run -- --changed native/UITests/WhiteboardPasteUITests.swift
status=$?
if [ "$status" -eq 0 ]; then ok "paste: climbs"; else bad "paste: climbs, exit $status"; fi
if grep -q "only-testing:GrabberNativeUITests/WhiteboardPasteUITests test-without-building" "$MARKS/xcodebuild"; then ok "paste: its class, keys test and all"; else bad "paste: its class, keys test and all"; fi
if grep -q "skip-testing" "$MARKS/xcodebuild"; then bad "paste: nothing held back"; else ok "paste: nothing held back"; fi
if [ "$(grep -c "simctl boot " "$MARKS/xcrun")" -eq 1 ]; then ok "paste: one boot"; else bad "paste: one boot"; fi

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
