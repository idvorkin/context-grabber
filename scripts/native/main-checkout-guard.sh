#!/usr/bin/env bash
# Story 1901 (bead context-grabber-8w8c): branch work belongs in a treehouse slot, never in the main checkout.
# Sourced by build-lane.sh and host-lane.sh; `main_checkout_guard` exits 64 when the current directory is the
# repository's primary worktree and it isn't on main.

# The primary worktree's top: the parent of the shared .git directory.
main_checkout_top() {
  local common
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  (cd "$common/.." && pwd -P)
}

main_checkout_guard() {
  local who=${1:-lane} top main branch
  top=$(git rev-parse --show-toplevel 2>/dev/null) || return 0   # not in a repository: nothing to guard
  top=$(cd "$top" && pwd -P)
  main=$(main_checkout_top) || return 0
  [ "$top" = "$main" ] || return 0                               # a slot or another worktree: fine
  branch=$(git symbolic-ref --short -q HEAD || echo "(detached HEAD)")
  [ "$branch" = main ] && return 0                               # the lead on main (just deploy): fine
  echo "$who: refusing to run in the main checkout ($top) on $branch: branch work belongs in a slot." >&2
  echo "$who: lease one with scripts/native/lease-slot.sh <branch>, or put the main checkout back on main (story 1901)." >&2
  exit 64
}
