#!/usr/bin/env bash
# The whiteboard UI tests on the simulator, with a fake Cockpit (their stories are in docs/TESTING.md, under The
# whiteboard suite's classes): scripts/native/fake-cockpit.py on a local port.
# The tests read the address as GRABBER_FAKE_COCKPIT (xcodebuild passes TEST_RUNNER_* through to the runner).
# Usage: test-whiteboard-ui.sh <iPad simulator udid or model name> (story 746). For a timed run that prevents idle sleep:
#   scripts/native/build-lane.sh run scripts/native/time-limit.sh 40 caffeinate -i \
#     scripts/native/test-whiteboard-ui.sh "iPad Pro 11-inch (M5)"   (a name is the lane's own device: story 785)
set -uo pipefail
# Story 1516: run outside a build lane, it takes the first free one and uses that lane's own simulator.
# shellcheck source=scripts/native/sim-lane.sh
. "$(dirname "$0")/sim-lane.sh"
take_lane "$0" "$@"
udid=$("$(dirname "$0")/sim-udid.sh" "$(lane_target "${1:?simulator udid or name}")") || exit 1
port=${CHAT_PORT:-$((8799 + ${BUILD_LANE_PORT_OFFSET:-0}))}
report=$(mktemp -t fake-cockpit)
cd "$(dirname "$0")/../.."
cockpit=
# Story 980: the simulator is left booted for the next run. Story 987: the shut-down ones' wallpaper snapshots go.
trap 'kill $cockpit 2>/dev/null || true; scripts/native/sim-poster-prune.sh || true' EXIT
# Keys reach the app only in the first test after a boot that presses any, so the suite boots a fresh simulator once and
# has one test that presses keys (WhiteboardPasteUITests' ⌘V and ⌘Z, on both canvases).
xcrun simctl shutdown "$udid" 2>/dev/null
scripts/native/sim-boot.sh "$udid" || exit 1
scripts/native/fake-cockpit.py "$port" "$report" >/dev/null 2>&1 &
cockpit=$!
sleep 1
kill -0 "$cockpit" 2>/dev/null || { echo "the fake Cockpit did not start on port $port" >&2; exit 1; }
# Story 1501: the classes under BoardLabUITests launch the Board Lab, a small app that opens on the boards list; the
# GrabberNative scheme builds and runs both bundles.
# The classes, one a line in name order, so PRs that add classes touch different lines (story 1502). The ladder reads
# this list for its whiteboard area, and scripts/native/test-testing-lists.sh holds it to docs/TESTING.md and the
# native/UITests/Whiteboard*UITests.swift files.
classes=(
  -only-testing:GrabberNativeUITests/WhiteboardBubblesUITests
  -only-testing:GrabberNativeUITests/WhiteboardCockpitBoardsUITests
  -only-testing:GrabberNativeUITests/WhiteboardConnectUITests
  -only-testing:GrabberNativeUITests/WhiteboardConversationPlaceUITests
  -only-testing:GrabberNativeUITests/WhiteboardDiagramBoxesUITests
  -only-testing:GrabberNativeUITests/WhiteboardDropRoomUITests
  -only-testing:BoardLabUITests/WhiteboardEraserUITests
  -only-testing:GrabberNativeUITests/WhiteboardGroupTapUITests
  -only-testing:GrabberNativeUITests/WhiteboardHelpFeedbackUITests
  -only-testing:GrabberNativeUITests/WhiteboardLarryWaitUITests
  -only-testing:GrabberNativeUITests/WhiteboardLetteringUITests
  -only-testing:GrabberNativeUITests/WhiteboardLinkChipUITests
  -only-testing:GrabberNativeUITests/WhiteboardListeningUITests
  -only-testing:GrabberNativeUITests/WhiteboardOnPaperUITests
  -only-testing:GrabberNativeUITests/WhiteboardOutlineUITests
  -only-testing:GrabberNativeUITests/WhiteboardPanelScrollUITests
  -only-testing:GrabberNativeUITests/WhiteboardPaperGhostsUITests
  -only-testing:GrabberNativeUITests/WhiteboardPaperLinesUITests
  -only-testing:GrabberNativeUITests/WhiteboardPaperPasteUITests
  -only-testing:GrabberNativeUITests/WhiteboardPasteUITests
  -only-testing:GrabberNativeUITests/WhiteboardPlaybackUITests
  -only-testing:GrabberNativeUITests/WhiteboardQuestionUITests
  -only-testing:GrabberNativeUITests/WhiteboardQuietTapUITests
  -only-testing:GrabberNativeUITests/WhiteboardReviewUITests
  -only-testing:GrabberNativeUITests/WhiteboardRewordUITests
  -only-testing:GrabberNativeUITests/WhiteboardRowDeleteUITests
  -only-testing:GrabberNativeUITests/WhiteboardScratchOutUITests
  -only-testing:GrabberNativeUITests/WhiteboardTheirsTapUITests
  -only-testing:BoardLabUITests/WhiteboardTitleRenameUITests
  -only-testing:GrabberNativeUITests/WhiteboardToTextUITests
  -only-testing:GrabberNativeUITests/WhiteboardTurnUITests
  -only-testing:GrabberNativeUITests/WhiteboardUndoRedrawUITests
)
# SUITE_PREBUILT=1 (the ladder's --full, after its own build-for-testing): run what was built rather than build again.
action=test done="TEST SUCCEEDED"
[ "${SUITE_PREBUILT:-}" = 1 ] && action=test-without-building done="TEST EXECUTE SUCCEEDED"
TEST_RUNNER_GRABBER_FAKE_COCKPIT="http://localhost:$port" scripts/native/xcodebuild-log.sh whiteboard-ui "$done" \
  xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath native/Build \
  -destination "platform=iOS Simulator,id=$udid" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" \
  "${classes[@]}" "$action"
status=$?
grep -q 'Igor just said: draw a circle' "$report" || { echo "the spoken words never reached the fake Cockpit"; status=1; }
echo "fake Cockpit: $(grep -c "\"turn\": \"claude\"" "$report") ghost turns, $(grep "\"body\"" "$report" | grep -c "\"picture_id\"") board pictures to Larry"
exit $status
