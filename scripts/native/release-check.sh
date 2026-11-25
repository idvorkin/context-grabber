#!/usr/bin/env bash
# Story 1519 (bead context-grabber-6ocd): ContextCore compiled the way an archive compiles it (Release, -O), run by
# `just pre-merge`. The debug builds every other rung uses never run the optimizer, so a compiler crash in it (Swift
# 6.4.2's CopyPropagation on BoardReview.movedWithoutAim, 2026-11-24) only surfaced in `just ota`, after the merge.
# It looks at the branch as pushed, as pre-merge.sh does (the pipeline adds its own commits to the PR), and builds
# the checkout only when its HEAD is that commit, so it never passes stale code.
# Skipped when the branch leaves native/ContextCore as origin/main has it; RELEASE_CHECK=1 builds anyway.
# Usage: scripts/native/release-check.sh [branch]   (default: the current branch). PRE_MERGE_REMOTE overrides origin.
# RELEASE_CHECK_BUILD replaces the build command (the host test's fake).
# The build takes a host slot and the checkout's own .build, so a slot's second run is incremental (~1 min; cold ~2).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
remote=${PRE_MERGE_REMOTE:-origin}
here=$(cd "$(dirname "$0")" && pwd)
branch=$("$here/pr-branch.sh" release-check "${1:-}") || exit 1
git fetch -q "$remote" main || { echo "FAIL release-check: can't fetch $remote main"; exit 1; }
if git fetch -q "$remote" "$branch" 2>/dev/null; then
  ref=$remote/$branch
else
  ref=$branch
fi
sha=$(git rev-parse -q --verify "$ref^{commit}") || { echo "FAIL release-check: no branch $branch"; exit 1; }
if [ "${RELEASE_CHECK:-}" != 1 ] && git diff --quiet "$remote/main...$ref" -- native/ContextCore; then
  echo "ok   release-check: $ref leaves native/ContextCore as $remote/main has it, Release build skipped"
  exit 0
fi
if [ "$(git rev-parse HEAD)" != "$sha" ]; then
  echo "FAIL release-check: the checkout's HEAD ($(git rev-parse --short HEAD)) isn't $ref ($(git rev-parse --short "$sha")), what the PR merges; check it out (git switch $branch && git pull --ff-only), then rerun"
  exit 1
fi
build=${RELEASE_CHECK_BUILD:-"cd native/ContextCore && '$here/host-lane.sh' run swift build -c release"}
if out=$(bash -c "$build" 2>&1); then
  echo "ok   release-check: ContextCore's Release build passes"
else
  grep -E "error:|While running pass|fatal error" <<<"$out" | head -8 | sed 's/^/     /'
  echo "FAIL release-check: ContextCore doesn't build in Release (-O), as an archive (just ota, TestFlight) compiles it"
  exit 1
fi
