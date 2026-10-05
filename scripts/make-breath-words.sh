#!/usr/bin/env bash
# Render the breathing screen's six spoken phrases into assets/audio/breathe/*.wav (story 165).
#
#   scripts/make-breath-words.sh    → ElevenLabs, a calm Australian woman, slowly (ELEVEN_API_KEY from the
#                                     environment, else Igor's secretbox); the Mac's Karen when there is no key
#
# Overrides: VOICE_ID (default "Her - A calm gently spoken Australian female" from the ElevenLabs library,
# added to Igor's account 2026-10-04), MODEL (default eleven_v3, which reads the [bracketed] direction and does
# not say it), VOICE and RATE for the `say` path. Silence before and after each phrase is trimmed (ffmpeg), so
# a phrase starts when its step does.
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

# name|text|say rate (words a minute; the second hold is slower)|the length in seconds a slow, calm take has.
# v3 varies from take to take, so TAKES (default 4) are rendered and the one nearest that length is kept.
# The app's BreathPhrase names the same files.
PHRASES=(
  "breath-begin|Let's begin.|150|1.7"
  "breath-in|Breathe in.|140|1.6"
  "breath-hold|Hold.|140|1.1"
  "breath-out|Breathe out.|140|1.6"
  "breath-hold-low|Hold.|105|1.6"
  "breath-done|Well done.|140|1.5"
)

for entry in "${PHRASES[@]}"; do
  IFS='|' read -r name text rate want <<<"$entry"
  if [ -n "${ELEVEN_API_KEY:-}" ]; then
    VOICE_ID=${VOICE_ID:-fZ7qV5MCpftIbraon8xo}
    direction="[calm, slow, soothing, gentle]"; [ "$name" = "breath-hold-low" ] && direction="[calm, very slow, lower, soft]"
    best=""; best_gap=99
    for take in $(seq 1 "${TAKES:-4}"); do
      body=$(python3 -c 'import json,sys; print(json.dumps({"text": sys.argv[1], "model_id": sys.argv[2], "seed": int(sys.argv[3]), "voice_settings": {"stability": 1.0, "similarity_boost": 0.8, "speed": 0.8}}))' "$direction ${text%.}..." "${MODEL:-eleven_v3}" "$take")
      http=$(curl -sS -o "$tmp/$name.$take.mp3" -w '%{http_code}' \
        -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=mp3_44100_128" \
        -H "xi-api-key: $ELEVEN_API_KEY" -H "Content-Type: application/json" -H "Accept: audio/mpeg" -d "$body")
      if [ "$http" != "200" ]; then echo "ElevenLabs said $http for \"$text\": $(head -c 300 "$tmp/$name.$take.mp3")" >&2; exit 1; fi
      ffmpeg -loglevel error -y -i "$tmp/$name.$take.mp3" -af "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,afade=t=in:d=0.02" -ar 44100 -ac 1 -c:a pcm_s16le "$tmp/$name.$take.wav"
      gap=$(python3 -c 'import sys,wave; w=wave.open(sys.argv[1]); print(abs(w.getnframes()/w.getframerate()-float(sys.argv[2])))' "$tmp/$name.$take.wav" "$want")
      if python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)' "$gap" "$best_gap"; then best=$take; best_gap=$gap; fi
    done
    cp -f "$tmp/$name.$best.wav" "$out/$name.wav"
    echo "$name.wav  (ElevenLabs $VOICE_ID: \"$text\")"
  else
    say -v "${VOICE:-Karen}" -r "${RATE:-$rate}" -o "$tmp/$name.aiff" "$text"
    afconvert -f WAVE -d LEI16@44100 -c 1 "$tmp/$name.aiff" "$out/$name.wav"
    echo "$name.wav  (${VOICE:-Karen}: \"$text\")"
  fi
done
