#!/usr/bin/env bash
# Which branch the pre-merge checks judge (bead context-grabber-9g0j): the one named, else the checkout's branch,
# else, on a detached HEAD (a temp worktree, a pipeline head), the one branch on the remote whose tip is HEAD.
# Prints it, or fails naming what to pass, so `just pre-merge && gh pr merge` stops instead of merging past it
# (twice on 2026-11-23 a detached HEAD failed pre-merge and the agent merged anyway).
# Usage: scripts/native/pr-branch.sh <check-name> [branch]   PRE_MERGE_REMOTE overrides origin.
set -uo pipefail
name=$1
branch=${2:-}
[ -n "$branch" ] && { echo "$branch"; exit 0; }
branch=$(git branch --show-current)
[ -n "$branch" ] && { echo "$branch"; exit 0; }
remote=${PRE_MERGE_REMOTE:-origin}
head=$(git rev-parse HEAD) || exit 1
git fetch -q "$remote" 2>/dev/null
found=$(git for-each-ref --format='%(refname:strip=3)' --points-at "$head" "refs/remotes/$remote" |
  grep -vxE 'HEAD|main' || true)
if [ "$(grep -c . <<<"$found")" = 1 ]; then
  echo "note $name: detached HEAD at ${head:0:8}; judging $remote/$found, the one branch there" >&2
  echo "$found"
  exit 0
fi
if [ -n "$found" ]; then
  echo "FAIL $name: detached HEAD at ${head:0:8}, where $(tr '\n' ' ' <<<"$found")all point; name the PR's branch: just pre-merge <branch>" >&2
else
  echo "FAIL $name: detached HEAD at ${head:0:8}, and no branch on $remote points at it; name the PR's branch: just pre-merge <branch>" >&2
fi
exit 1
