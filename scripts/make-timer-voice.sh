#!/usr/bin/env bash
# Render one of the native Gym Timer's count voices (story 182) and put its
# cues in the app's bundle:
#
#   scripts/make-timer-voice.sh <name> <voice_id> <style>
#     → assets/audio/timer-voices/<name>-{three,two,one,go,rest,done}.wav
#
# The words are rendered by make-timer-words.sh (ElevenLabs, MODEL default
# eleven_v3, STABILITY default 0.5, STYLE = <style>: plain, firm or excited)
# and composed by make-timer-cues.mjs in a working directory outside the repo
# (WORK, default ~/tmp/agent/skill/timer-voice-<name>), so Igor's own set in
# assets/audio/timer — which the React Native app also plays — is untouched,
# and the keepalive stays his. It costs ElevenLabs credits: run it once per
# voice. A count word longer than a second can run into the next second's
# cue; re-render just that word with more takes and keep the shortest:
#
#   ONLY=one TAKES=4 scripts/make-timer-voice.sh aussie fZ7qV5MCpftIbraon8xo excited
#
# The voices today:
#   adam    pNInz6obpgDQGcFmaJgB  firm     (the default)
#   aussie  fZ7qV5MCpftIbraon8xo  excited  (an Australian woman)
#   igor    — his clone; the plain set in assets/audio/timer (make-timer-words.sh)
# Spec: docs/superpowers/specs/2026-10-04-swift-native-app-design.md (step 2)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -ne 3 ]; then
  echo "usage: $0 <name> <voice_id> <plain|firm|excited>" >&2
  exit 2
fi
name=$1 voice_id=$2 style=$3
work=${WORK:-$HOME/tmp/agent/skill/timer-voice-$name}
dest=assets/audio/timer-voices
mkdir -p "$work" "$dest"

TIMER_DIR=$work VOICE_ID=$voice_id STYLE=$style MODEL=${MODEL:-eleven_v3} STABILITY=${STABILITY:-0.5} \
  TAKES=${TAKES:-1} scripts/make-timer-words.sh

for cue in three two one go rest done; do
  cp -f "$work/$cue.wav" "$dest/$name-$cue.wav"
  seconds=$(afinfo "$dest/$name-$cue.wav" | awk '/estimated duration/ {print $3}')
  warn=""
  case $cue in three | two | one) awk -v s="$seconds" 'BEGIN { exit !(s > 1.0) }' && warn="  (over 1 s: re-render with ONLY=$cue TAKES=4)" ;; esac
  printf '%-28s %.2fs%s\n' "$name-$cue.wav" "$seconds" "$warn"
done
