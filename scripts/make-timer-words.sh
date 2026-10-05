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
# see the Cockpit's voice_bridge.py), STABILITY (default 0.9; eleven_v3 takes
# only 0, 0.5 or 1), STYLE (the words' text: plain — "Three." … "Go!", the
# default; firm — Adam's eleven_v3 tags; excited — the Australian woman's),
# TAKES (renders per word; the composer keeps the shortest trimmed take — a
# filler always adds length), ONLY (render just these words, e.g. ONLY="one
# three", keeping the others' takes), TIMER_DIR (default assets/audio/timer;
# words go to $TIMER_DIR/words, cues to $TIMER_DIR), VOICE and RATE for the
# `say` path. scripts/make-timer-voice.sh wraps this for the native app's
# other count voices.
# The key: ELEVEN_API_KEY in the environment, else Igor's secretbox.
# Spec: docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md
set -euo pipefail
cd "$(dirname "$0")/.."

SECRETBOX=${SECRETBOX:-$HOME/gits/igor2/secretBox.json}
if [ -z "${ELEVEN_API_KEY:-}" ] && [ -f "$SECRETBOX" ]; then
  ELEVEN_API_KEY=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("ELEVEN_API_KEY",""))' "$SECRETBOX")
fi

TIMER_DIR=${TIMER_DIR:-assets/audio/timer}
export TIMER_DIR
out=$TIMER_DIR/words
mkdir -p "$out"
tmp=$(mktemp -d)

# The six words, punctuated as sentences: a bare word invites the clone to
# hum and hesitate around it; "Three." is said and finished. eleven_v3 reads
# the bracketed tags as direction, not text.
STYLE=${STYLE:-plain}
read -r -a WORDS <<<"${ONLY:-three two one go rest done}"
say_for() {
  case "$STYLE:$1" in
    plain:three) echo "Three.";; plain:two) echo "Two.";; plain:one) echo "One.";;
    plain:go) echo "Go!";; plain:rest) echo "Rest.";; plain:done) echo "Done.";;
    firm:three) echo "[firm] Three!";; firm:two) echo "[firm] Two!";; firm:one) echo "[firm] One!";;
    firm:go) echo "[shouting] Go!";; firm:rest) echo "[calm] Rest.";; firm:done) echo "[proud] Done!";;
    excited:three) echo "[excited] Three!";; excited:two) echo "[excited] Two!";; excited:one) echo "[excited] One!";;
    excited:go) echo "[excited, shouting] Go!";; excited:rest) echo "[cheerful] Rest!";;
    excited:done) echo "[excited, cheering] Done!";;
    *) echo "unknown STYLE \"$STYLE\" (plain, firm, excited) or word \"$1\"" >&2; return 1;;
  esac
}
for w in "${WORDS[@]}"; do say_for "$w" >/dev/null; rm -f "$out/$w".*.wav "$out/$w.wav"; done

if [ -n "${ELEVEN_API_KEY:-}" ]; then
  VOICE_ID=${VOICE_ID:-Nvd5I2HGnOWHNU0ijNEy}   # "Igor" — the clone (lib/callVoices.ts)
  MODEL=${MODEL:-eleven_multilingual_v2}
  STABILITY=${STABILITY:-0.9}
  TAKES=${TAKES:-3}
  echo "ElevenLabs, voice $VOICE_ID, model $MODEL, stability $STABILITY, style $STYLE, $TAKES takes per word"
  for w in "${WORDS[@]}"; do
    text=$(say_for "$w")
    for t in $(seq 1 "$TAKES"); do
      # Steady and plain by default: high stability, no style exaggeration — the
      # settings that keep a clone from adding breaths, ums and flourishes to one
      # word. An excited voice wants STABILITY=0.5, the tags doing the acting.
      body=$(printf '{"text":%s,"model_id":"%s","seed":%d,"voice_settings":{"stability":%s,"similarity_boost":0.9,"style":0,"use_speaker_boost":true}}' "$(printf '%s' "$text" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" "$MODEL" "$((1000 + t))" "$STABILITY")
      http=$(curl -sS -o "$tmp/$w.$t.mp3" -w '%{http_code}' \
        -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=mp3_44100_128" \
        -H "xi-api-key: $ELEVEN_API_KEY" -H "Content-Type: application/json" -H "Accept: audio/mpeg" \
        -d "$body")
      if [ "$http" != "200" ]; then echo "ElevenLabs said $http for \"$text\": $(head -c 300 "$tmp/$w.$t.mp3")" >&2; exit 1; fi
      afconvert -f WAVE -d LEI16@44100 -c 1 "$tmp/$w.$t.mp3" "$out/$w.$t.wav"
    done
    echo "$w  (\"$text\", $TAKES takes)"
  done
else
  VOICE=${VOICE:-Samantha}
  RATE=${RATE:-190}
  echo "no ELEVEN_API_KEY — the Mac's $VOICE"
  for w in "${WORDS[@]}"; do
    text=$(say_for "$w")
    say -v "$VOICE" -r "$RATE" -o "$tmp/$w.aiff" "$text"
    afconvert -f WAVE -d LEI16@44100 -c 1 "$tmp/$w.aiff" "$out/$w.1.wav"
    echo "$w.1.wav  ($VOICE: \"$text\")"
  done
fi

node scripts/make-timer-cues.mjs
