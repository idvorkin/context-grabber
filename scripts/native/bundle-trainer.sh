#!/bin/sh
# The card screen's stack and voice (the trainer's screen, shared from think-a-card-trainer): copies the private
# stack file into the bundle as deck.json, and with --voice the trainer's rendered clips (voice/cards,
# voice/spectators). Neither is in this public repository, ever; both come from Igor's Mac at build time.
#
#   bundle-trainer.sh <resources dir> [--voice]
#
# Sources: $THINK_A_CARD_DECK, else ~/gits/igor2/secrets/particle-stack.json; $THINK_A_CARD_VOICE, else
# ~/gits/think-a-card-trainer/voice. A missing stack is a warning, not a failed build: the card screen then says
# the build has no stack, with a copyable error. Missing clips mean the phone's own voice says the card.
set -eu

dest="$1"
deck="${THINK_A_CARD_DECK:-$HOME/gits/igor2/secrets/particle-stack.json}"
voice="${THINK_A_CARD_VOICE:-$HOME/gits/think-a-card-trainer/voice}"
mkdir -p "$dest"

# Only whether it is JSON at all; the deck's own decoder checks the rest at launch and says what is wrong.
if [ -f "$deck" ] && /usr/bin/python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$deck" 2>/dev/null; then
  cp -f "$deck" "$dest/deck.json"
else
  rm -f "$dest/deck.json"
  echo "warning: no stack at $deck (set THINK_A_CARD_DECK); the card screen will say so"
fi

if [ "${2:-}" = "--voice" ]; then
  rm -rf "$dest/voice"
  if [ -d "$voice/cards" ]; then
    mkdir -p "$dest/voice"
    cp -Rf "$voice/cards" "$dest/voice/cards"
    [ -d "$voice/spectators" ] && cp -Rf "$voice/spectators" "$dest/voice/spectators"
  else
    echo "warning: no voice clips at $voice (just voice-clips in think-a-card-trainer); the phone's voice will speak"
  fi
fi
