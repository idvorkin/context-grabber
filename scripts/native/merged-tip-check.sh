#!/usr/bin/env bash
# Story 1629: the app compiled on the merged tip, run by `just pre-merge`. Two PRs can each pass every rung alone and
# still break main once both land: on 2026-11-24 #1459 added MessageBubble's `group:` and #1465, merged minutes
# later, called it without one, and main's Debug build failed for every lane and device install. So this merges the
# branch as pushed onto main as the remote has it now, in a scratch worktree (never the checkout, the branch or main),
# and compiles the app there: the Debug build for the iOS simulator, no simulator booted, no signing (it caught that
# break in ~30 s warm; the Mac Catalyst build caught it too, in ~40 s).
# Skipped when the branch leaves native/ as origin/main has it; MERGED_TIP_CHECK=1 compiles anyway.
# Usage: scripts/native/merged-tip-check.sh [branch]   (default: the current branch). PRE_MERGE_REMOTE overrides origin.
# MERGED_TIP_DIR: where the scratch worktree (src/) and its build folder (dd/) live, kept between runs so a slot's next
# run is incremental (default: native/Build/merged-tip, ignored by git). MERGED_TIP_BUILD replaces the compile command,
# run in the scratch worktree (the host test's fake).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
remote=${PRE_MERGE_REMOTE:-origin}
here=$(cd "$(dirname "$0")" && pwd)
branch=$("$here/pr-branch.sh" merged-tip "${1:-}") || exit 1
git fetch -q "$remote" main || { echo "FAIL merged-tip: can't fetch $remote main"; exit 1; }
if git fetch -q "$remote" "$branch" 2>/dev/null; then
  ref=$remote/$branch
else
  ref=$branch
fi
sha=$(git rev-parse -q --verify "$ref^{commit}") || { echo "FAIL merged-tip: no branch $branch"; exit 1; }
main=$(git rev-parse "$remote/main")
if [ "${MERGED_TIP_CHECK:-}" != 1 ] && git diff --quiet "$remote/main...$ref" -- native; then
  echo "ok   merged-tip: $ref leaves native/ as $remote/main has it, compile skipped"
  exit 0
fi
dir=${MERGED_TIP_DIR:-$PWD/native/Build/merged-tip}
mkdir -p "$dir" && dir=$(cd "$dir" && pwd -P)
wt=$dir/src
if [ "$(git -C "$wt" rev-parse --show-toplevel 2>/dev/null)" != "$wt" ]; then
  git worktree prune
  rm -rf "$wt"
  git worktree add -q --detach "$wt" "$main" || { echo "FAIL merged-tip: can't make the scratch worktree at $wt"; exit 1; }
fi
cd "$wt" || exit 1
git merge --abort 2>/dev/null
git checkout -q --detach -f "$main" && git clean -fdq || { echo "FAIL merged-tip: can't reset the scratch worktree at $wt"; exit 1; }
if ! git -c user.name=merged-tip -c user.email=merged-tip@localhost merge -q --no-ff --no-edit "$sha" >/dev/null 2>&1; then
  files=$(git diff --name-only --diff-filter=U | head -5 | tr '\n' ' ')
  git merge --abort 2>/dev/null
  echo "FAIL merged-tip: $ref doesn't merge cleanly onto $remote/main ($(git rev-parse --short "$main")): ${files:-conflict}; rebase it first"
  exit 1
fi
build=${MERGED_TIP_BUILD:-"just native-project >/dev/null && '$here/host-lane.sh' run xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath '$dir/dd' -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -quiet build"}
start=$(date +%s)
if out=$(bash -c "$build" 2>&1); then
  echo "ok   merged-tip: the app compiles on $ref merged onto $remote/main ($(git rev-parse --short "$main"), $(($(date +%s) - start)) s)"
else
  # A compile error's own line (path:line:col: error: …) names the break; the build's summary lines don't.
  errs=$(grep -E '^[^ ].*:[0-9]+:[0-9]+: error:' <<<"$out" | sed "s|$wt/||" | awk '!seen[$0]++' | head -6)
  [ -n "$errs" ] || errs=$(grep -E "error:" <<<"$out" | grep -v "^error: recipe" | awk '!seen[$0]++' | head -6)
  [ -n "$errs" ] && sed 's/^/     /' <<<"$errs"
  first=$(head -1 <<<"$errs")
  echo "FAIL merged-tip: the app doesn't compile with $ref merged onto $remote/main ($(git rev-parse --short "$main")): ${first:-see the build output}"
  exit 1
fi
