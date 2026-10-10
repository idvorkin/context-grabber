#!/usr/bin/env bash
# Prints "<name> <udid>" for each of Igor's devices this Mac knows: the phone (phone-udid.sh) and the iPad
# (IPAD=<udid>, else the untracked scripts/native/ipad-udid.local). The ids are not committed: the repo is public.
set -euo pipefail
here="$(dirname "$0")"
if phone=$("$here/phone-udid.sh" 2>/dev/null); then echo "phone $phone"; fi
ipad="${IPAD:-}"
[ -z "$ipad" ] && [ -s "$here/ipad-udid.local" ] && ipad=$(tr -d '[:space:]' <"$here/ipad-udid.local")
[ -n "$ipad" ] && echo "ipad $ipad"
exit 0
