#!/usr/bin/env bash
# Render the Gym Timer's spoken cues — in Igor's own voice, his ElevenLabs clone,
# when ELEVEN_API_KEY is in the environment; the Mac's system voice (`say`)
# otherwise. Then compose the cue files:
#
#   scripts/make-timer-words.sh            → assets/audio/timer/words/*.wav
#   node scripts/make-timer-cues.mjs       → assets/audio/timer/*.wav
#
# Overrides: VOICE_ID (ElevenLabs voice; default the clone named "Igor"),
# MODEL (default eleven_multilingual_v2 — plain eleven_v3 is plan-gated,
# see the Cockpit's voice_bridge.py), VOICE and RATE for the `say` path.
# The key: ELEVEN_API_KEY in the environment, else Igor's secretbox.
# Spec: docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md
set -euo pipefail
cd "$(dirname "$0")/.."

SECRETBOX=${SECRETBOX:-$HOME/gits/igor2/secretBox.json}
if [ -z "${ELEVEN_API_KEY:-}" ] && [ -f "$SECRETBOX" ]; then
  ELEVEN_API_KEY=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("ELEVEN_API_KEY",""))' "$SECRETBOX")
fi

out=assets/audio/timer/words
mkdir -p "$out"
tmp=$(mktemp -d)

# The six words. "go!" with the exclamation so the clone leans into it.
WORDS=(three two one go rest done)
say_for() { case "$1" in go) echo "go!";; *) echo "$1";; esac; }

if [ -n "${ELEVEN_API_KEY:-}" ]; then
  VOICE_ID=${VOICE_ID:-Nvd5I2HGnOWHNU0ijNEy}   # "Igor" — the clone (lib/callVoices.ts)
  MODEL=${MODEL:-eleven_multilingual_v2}
  echo "ElevenLabs, voice $VOICE_ID, model $MODEL"
  for w in "${WORDS[@]}"; do
    text=$(say_for "$w")
    body=$(printf '{"text":%s,"model_id":"%s","voice_settings":{"stability":0.5,"similarity_boost":0.8,"style":0.2}}' "$(printf '%s' "$text" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" "$MODEL")
    http=$(curl -sS -o "$tmp/$w.mp3" -w '%{http_code}' \
      -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=mp3_44100_128" \
      -H "xi-api-key: $ELEVEN_API_KEY" -H "Content-Type: application/json" -H "Accept: audio/mpeg" \
      -d "$body")
    if [ "$http" != "200" ]; then echo "ElevenLabs said $http for \"$text\": $(head -c 300 "$tmp/$w.mp3")" >&2; exit 1; fi
    afconvert -f WAVE -d LEI16@44100 -c 1 "$tmp/$w.mp3" "$out/$w.wav"
    echo "$w.wav  (Igor: \"$text\")"
  done
else
  VOICE=${VOICE:-Samantha}
  RATE=${RATE:-190}
  echo "no ELEVEN_API_KEY — the Mac's $VOICE"
  for w in "${WORDS[@]}"; do
    text=$(say_for "$w")
    say -v "$VOICE" -r "$RATE" -o "$tmp/$w.aiff" "$text"
    afconvert -f WAVE -d LEI16@44100 -c 1 "$tmp/$w.aiff" "$out/$w.wav"
    echo "$w.wav  ($VOICE: \"$text\")"
  done
fi

node scripts/make-timer-cues.mjs
