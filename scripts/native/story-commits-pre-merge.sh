#!/usr/bin/env bash
# The first pre-merge step (story 1638, bead context-grabber-zisx): renames story links to commits a pipeline rebase
# replaced. Every rebase rewrites the branch's shas, so a Status line written before it names a commit the branch no
# longer has, and each one cost a review round (#1492, #1498, #1501, #1509, #1510 on 2026-11-25). story-commits.py
# lets such a link through when one branch commit carries the same change (same patch-id); this renames it before the
# merge, so main only ever links commits it has.
# It judges the branch as pushed (the pipeline force-pushes its rebase, so the local branch can be behind): it checks
# the pushed head out in a scratch worktree, rewrites the links there, commits only docs/stories and pushes that
# docs-only commit to the branch. The checkout, its index and its branch are left alone.
# Usage: scripts/native/story-commits-pre-merge.sh [branch]   (default: the current branch, or the one pushed branch at a detached HEAD). PRE_MERGE_REMOTE
# overrides origin.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
cd "$(git rev-parse --show-toplevel)" || exit 1
remote=${PRE_MERGE_REMOTE:-origin}
branch=$("$here/pr-branch.sh" story-commits "${1:-}") || exit 1
git fetch -q "$remote" main 2>/dev/null
if git fetch -q "$remote" "$branch" 2>/dev/null; then ref=$remote/$branch; else ref=$branch; fi
sha=$(git rev-parse -q --verify "$ref^{commit}") || { echo "FAIL story-commits: no branch $branch"; exit 1; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-story-commits.XXXXXX")
wt=$tmp/wt
trap 'git worktree remove --force "$wt" 2>/dev/null; rm -rf "$tmp"; git worktree prune 2>/dev/null' EXIT
git worktree add -q --detach "$wt" "$sha" || { echo "FAIL story-commits: can't check $ref out"; exit 1; }
out=$("$here/story-commits.py" --repo "$wt" --base "$remote/main" --fix "$wt/docs/stories")
status=$?
if [ "$status" != 0 ]; then
  echo "$out"
  echo "FAIL story-commits: $ref links commits it doesn't have; name them as they are on the branch, push, rerun"
  exit 1
fi
fixes=$(grep -c '^fixed ' <<<"$out")
if [ "$fixes" = 0 ]; then
  echo "ok   story-commits: $ref names only its own commits"
  exit 0
fi
grep '^fixed ' <<<"$out"
git -C "$wt" commit -q -m "Stories: name the commits as the rebase left them (story 1638)" -- docs/stories &&
  git -C "$wt" push -q "$remote" "HEAD:refs/heads/$branch" ||
  { echo "FAIL story-commits: couldn't commit and push the renamed links to $remote/$branch"; exit 1; }
git fetch -q "$remote" "$branch" 2>/dev/null
echo "ok   story-commits: renamed $fixes link(s) to the rebased commits, pushed $(git -C "$wt" rev-parse --short HEAD) to $remote/$branch"
