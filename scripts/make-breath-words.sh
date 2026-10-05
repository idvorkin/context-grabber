#!/usr/bin/env bash
# Render the breathing screen's six spoken phrases into assets/audio/breathe/*.wav (story 165).
#
#   VOICE_ID=<an ElevenLabs voice> scripts/make-breath-words.sh   → that voice (ELEVEN_API_KEY from the
#                                                                    environment, else Igor's secretbox)
#   scripts/make-breath-words.sh                                  → the Mac's Australian voice, Karen
#
# The story asks for a soothing woman's voice with an Australian accent. Igor's ElevenLabs account has none
# (2026-10-04), so there is no default VOICE_ID: without one this renders Karen. Overrides: MODEL (default
# eleven_multilingual_v2), VOICE and RATE for the `say` path.
# Spec: docs/superpowers/specs/2026-10-04-box-breathing-design.md
set -euo pipefail
cd "$(dirname "$0")/.."

SECRETBOX=${SECRETBOX:-$HOME/gits/igor2/secretBox.json}
if [ -z "${ELEVEN_API_KEY:-}" ] && [ -f "$SECRETBOX" ]; then
  ELEVEN_API_KEY=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("ELEVEN_API_KEY",""))' "$SECRETBOX")
fi

out=assets/audio/breathe
mkdir -p "$out"
tmp=$(mktemp -d)

# name|text|say rate (words a minute; the second hold is slower). The app's BreathPhrase names the same files.
PHRASES=(
  "breath-begin|Let's begin.|150"
  "breath-in|Breathe in.|140"
  "breath-hold|Hold.|140"
  "breath-out|Breathe out.|140"
  "breath-hold-low|Hold.|105"
  "breath-done|Well done.|140"
)

for entry in "${PHRASES[@]}"; do
  IFS='|' read -r name text rate <<<"$entry"
  if [ -n "${VOICE_ID:-}" ] && [ -n "${ELEVEN_API_KEY:-}" ]; then
    # Calm and even; the slower second hold is asked for with a lower speed.
    speed=1.0; [ "$name" = "breath-hold-low" ] && speed=0.8
    body=$(python3 -c 'import json,sys; print(json.dumps({"text": sys.argv[1], "model_id": sys.argv[2], "voice_settings": {"stability": 0.8, "similarity_boost": 0.8, "style": 0, "speed": float(sys.argv[3])}}))' "$text" "${MODEL:-eleven_multilingual_v2}" "$speed")
    http=$(curl -sS -o "$tmp/$name.mp3" -w '%{http_code}' \
      -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=mp3_44100_128" \
      -H "xi-api-key: $ELEVEN_API_KEY" -H "Content-Type: application/json" -H "Accept: audio/mpeg" -d "$body")
    if [ "$http" != "200" ]; then echo "ElevenLabs said $http for \"$text\": $(head -c 300 "$tmp/$name.mp3")" >&2; exit 1; fi
    afconvert -f WAVE -d LEI16@44100 -c 1 "$tmp/$name.mp3" "$out/$name.wav"
    echo "$name.wav  (ElevenLabs $VOICE_ID: \"$text\")"
  else
    say -v "${VOICE:-Karen}" -r "${RATE:-$rate}" -o "$tmp/$name.aiff" "$text"
    afconvert -f WAVE -d LEI16@44100 -c 1 "$tmp/$name.aiff" "$out/$name.wav"
    echo "$name.wav  (${VOICE:-Karen}: \"$text\")"
  fi
done
