#!/usr/bin/env bash
# Story 1632 (bead context-grabber-3hj9.3): put Exercise Analyzer's simulator build on a simulator before
# ExerciseAnalyzerLinkUITests, which taps the home row and waits for that app to come to the front. Without it the
# app's open fails (`open_exercise_analyzer` ok:false) and the test reads as a broken row.
# Usage: install-exercise-analyzer.sh <udid>
# EXERCISE_ANALYZER_APP: the .app to install (default: the main checkout's `just build-sim` product in
# ~/gits/exercise-analyzer).
# Exit: 0 installed, 1 the install failed, 2 usage, 3 no build to install (the caller leaves the class out).
set -uo pipefail
[ $# -eq 1 ] || { echo "usage: install-exercise-analyzer.sh <udid>" >&2; exit 2; }
udid=$1
app=${EXERCISE_ANALYZER_APP:-$HOME/gits/exercise-analyzer/Build/Build/Products/Debug-iphonesimulator/ExerciseAnalyzer.app}
if [ ! -d "$app" ]; then
  echo "no Exercise Analyzer simulator build at $app: run \`just build-sim\` in ~/gits/exercise-analyzer" \
    "(or set EXERCISE_ANALYZER_APP), so ExerciseAnalyzerLinkUITests is left out of this run" >&2
  exit 3
fi
if ! xcrun simctl install "$udid" "$app"; then
  echo "could not install $app on $udid" >&2
  exit 1
fi
echo "installed Exercise Analyzer ($app) on $udid"
