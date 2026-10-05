#!/usr/bin/env bash
# Prints the iPhone's hardware UDID: DEVICE=<udid>, else the untracked scripts/native/phone-udid.local.
# The id is not committed: the repo is public.
set -euo pipefail
FILE="$(dirname "$0")/phone-udid.local"
if [ -n "${DEVICE:-}" ]; then
  echo "$DEVICE"
elif [ -s "$FILE" ]; then
  tr -d '[:space:]' <"$FILE"
  echo
else
  echo "no phone id: set DEVICE=<udid> or write it to scripts/native/phone-udid.local (\`xcrun devicectl list devices\` shows it)" >&2
  exit 1
fi
