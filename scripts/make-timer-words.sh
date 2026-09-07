#!/usr/bin/env bash
# Render the Gym Timer's spoken cues with macOS `say` — offline, no keys, and
# the same bytes again for the same voice and OS. Then compose the cue files:
#
#   scripts/make-timer-words.sh            → assets/audio/timer/words/*.wav
#   node scripts/make-timer-cues.mjs       → assets/audio/timer/*.wav
#
# VOICE and RATE can be overridden: VOICE=Daniel RATE=180 scripts/make-timer-words.sh
# Spec: docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md
set -euo pipefail
cd "$(dirname "$0")/.."

VOICE=${VOICE:-Samantha}
RATE=${RATE:-190}
out=assets/audio/timer/words
mkdir -p "$out"
tmp=$(mktemp -d)

render() { # name, words
  say -v "$VOICE" -r "$RATE" -o "$tmp/$1.aiff" "$2"
  afconvert -f WAVE -d LEI16@44100 -c 1 "$tmp/$1.aiff" "$out/$1.wav"
  echo "$1.wav  ($VOICE: \"$2\")"
}

render three "three"
render two "two"
render one "one"
render go "go!"
render rest "rest"
render done "done"

node scripts/make-timer-cues.mjs
