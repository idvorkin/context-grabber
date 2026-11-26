#!/usr/bin/env bash
# Story 1901 (bead context-grabber-8w8c): lease a treehouse slot for a branch and print its path, or print nothing
# and fail. A bare `slot=$(treehouse get --lease -b …)` that fails with every slot leased leaves slot empty, and the
# lane's next checkout, reset and rebase run in the main checkout; twice on 2026-11-26.
#
#   slot=$(scripts/native/lease-slot.sh native/123-my-change) || exit 1
#
# Retries every LEASE_SLOT_POLL seconds (30) for up to LEASE_SLOT_WAIT seconds (1800) while the pool is full. Exits 75
# when the wait runs out; 70 when treehouse hands back nothing usable or the main checkout, or its lease fails while
# `treehouse status` shows a slot available (not a full pool); 127 when there is no treehouse; 2 on bad usage.
# TREEHOUSE overrides the treehouse command (the tests use a stand-in).
set -uo pipefail

[ $# -eq 1 ] && [ -n "$1" ] || { echo "usage: lease-slot.sh <branch>" >&2; exit 2; }
branch=$1
wait=${LEASE_SLOT_WAIT:-1800} poll=${LEASE_SLOT_POLL:-30}
treehouse=${TREEHOUSE:-treehouse}
command -v "$treehouse" >/dev/null 2>&1 || { echo "lease-slot: no treehouse command ($treehouse)" >&2; exit 127; }
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=main-checkout-guard.sh
. "$here/main-checkout-guard.sh"
main=$(cd "$here" && main_checkout_top) || { echo "lease-slot: not in a git repository" >&2; exit 2; }

errf=$(mktemp "${TMPDIR:-/tmp}/lease-slot.XXXXXX") || exit 1
trap 'rm -f "$errf"' EXIT
start=$SECONDS said=
while :; do
  if out=$("$treehouse" get --lease -b "$branch" 2>"$errf"); then
    slot=$(printf '%s\n' "$out" | tail -1)
    if [ -z "$slot" ] || [ ! -d "$slot" ]; then
      echo "lease-slot: treehouse leased nothing usable for $branch (got '${slot}')" >&2
      exit 70
    fi
    real=$(cd "$slot" && pwd -P)
    if [ "$real" = "$main" ]; then
      echo "lease-slot: treehouse returned the main checkout ($real) for $branch; refusing" >&2
      exit 70
    fi
    printf '%s\n' "$slot"
    exit 0
  fi
  err=$(cat "$errf" 2>/dev/null)
  if "$treehouse" status 2>/dev/null | grep -qiw available; then
    echo "lease-slot: treehouse couldn't lease a slot for $branch though one is available: ${err:-no error}" >&2
    exit 70
  fi
  if [ $((SECONDS - start)) -ge "$wait" ]; then
    echo "lease-slot: no slot for $branch after ${wait}s; last error: ${err:-none}. Nothing leased; stop, don't work in the main checkout." >&2
    exit 75
  fi
  [ -n "$said" ] || { echo "lease-slot: no slot yet for $branch (${err:-lease failed}); retrying every ${poll}s for up to ${wait}s" >&2; said=1; }
  sleep "$poll"
done
