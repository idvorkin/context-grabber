#!/usr/bin/env bash
# Igor, 2026-11-01: "if only touched 1 feature don't re-run ALL test". Prints the simulator smoke's sections a change
# touches, comma-separated, for SMOKE_ONLY: "all" when it touches shared code or the smoke itself (or the base is
# unknown), "none" when it touches no feature the smoke drives (the launch and report checks still run). The change is everything on this
# branch since origin/main, committed or not.
# Usage: smoke-features.sh [base [path...]]   (default origin/main; paths given are the change, instead of git's)
set -uo pipefail
base=${1:-origin/main}
if [ "$#" -gt 1 ]; then
  files=$(printf '%s\n' "${@:2}")
else
  fork=$(git merge-base "$base" HEAD) || { echo all; exit 0; }
  files=$( { git diff --name-only "$fork"; git ls-files --others --exclude-standard; } | sort -u)
fi
features=()
add() { [[ " ${features[*]-} " == *" $1 "* ]] || features+=("$1"); }
for f in $files; do
  case $f in
    *.md | docs/* | .beads/* | .lavish/*) ;;  # words, not code
    native/ContextCore/Tests/*) ;;            # host tests, the host rung's
    native/UITests/*) ;;                      # UI tests, which the ladder runs as their own classes (story 755)
    native/App/Gym/* | native/ContextCore/Sources/ContextCore/Gym/* | assets/audio/timer*) add timer ;;
    native/App/Breathe/* | native/ContextCore/Sources/ContextCore/Breathe/* | assets/audio/breathe*) add breathe ;;
    native/App/Places/* | native/ContextCore/Sources/ContextCore/Places/*) add places ;;
    native/App/Archive/* | native/ContextCore/Sources/ContextCore/Archive/*) add places ;;  # its check rides the trail
    native/App/Call/* | native/ContextCore/Sources/ContextCore/Call/* | scripts/native/fake-bridge.py) add call ;;
    native/App/Cockpit/* | native/ContextCore/Sources/ContextCore/Cockpit/*) add cockpit ;;
    native/App/Chat/* | native/App/Inbox/* | native/ContextCore/Sources/ContextCore/Chat/* | \
      native/ContextCore/Sources/ContextCore/Inbox/* | scripts/native/fake-cockpit.py) add chat ;;
    native/App/Card/* | native/ContextCore/Sources/ContextCore/Card/*) add drill ;;
    native/App/Mirror/* | native/ContextCore/Sources/ContextCore/Mirror/*) add mirror ;;
    native/App/Whiteboard/* | native/ContextCore/Sources/ContextCore/Whiteboard/*) add whiteboard ;;
    native/App/Assets.xcassets/* | scripts/native/test-*) ;;
    *) echo all; exit 0 ;;  # shared code, the project, the smoke itself: everything
  esac
done
(IFS=,; echo "${features[*]:-none}")
