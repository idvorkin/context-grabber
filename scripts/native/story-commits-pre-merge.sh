#!/usr/bin/env bash
# The first pre-merge step (story 1638, bead context-grabber-zisx): renames story links to commits a pipeline rebase
# replaced. Every rebase rewrites the branch's shas, so a Status line written before it names a commit the branch no
# longer has, and each one cost a review round (#1492, #1498, #1501, #1509, #1510 on 2026-11-25). story-commits.py
# lets such a link through when one branch commit carries the same change (same patch-id); this renames it before the
# merge, so main only ever links commits it has.
# It judges the branch as pushed. When the checkout is that branch at the pushed head with docs/stories clean, it
# rewrites the links, commits that docs-only change and pushes it to the branch; otherwise it fails naming the steps.
# Usage: scripts/native/story-commits-pre-merge.sh [branch]   (default: the current branch). PRE_MERGE_REMOTE
# overrides origin.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
cd "$(git rev-parse --show-toplevel)" || exit 1
remote=${PRE_MERGE_REMOTE:-origin}
branch=${1:-$(git branch --show-current)}
[ -n "$branch" ] || { echo "FAIL story-commits: not on a branch; name one"; exit 1; }
git fetch -q "$remote" main 2>/dev/null
if git fetch -q "$remote" "$branch" 2>/dev/null; then ref=$remote/$branch; else ref=$branch; fi
sha=$(git rev-parse -q --verify "$ref^{commit}") || { echo "FAIL story-commits: no branch $branch"; exit 1; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-story-commits.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
git archive "$sha" docs/stories | tar -x -C "$tmp" || { echo "FAIL story-commits: can't read docs/stories at $ref"; exit 1; }
out=$("$here/story-commits.py" --repo "$PWD" --rev "$sha" --fix "$tmp/docs/stories")
status=$?
if [ "$status" != 0 ]; then
  sed "s|$tmp/docs/stories/||" <<<"$out"
  echo "FAIL story-commits: $ref links commits it doesn't have; name them as they are on the branch, push, rerun"
  exit 1
fi
fixes=$(grep -c '^fixed ' <<<"$out")
if [ "$fixes" = 0 ]; then
  echo "ok   story-commits: $ref names only its own commits"
  exit 0
fi
grep '^fixed ' <<<"$out"
if [ "$(git branch --show-current)" != "$branch" ] || [ "$(git rev-parse HEAD)" != "$sha" ] ||
  ! git diff --quiet HEAD -- docs/stories; then
  echo "FAIL story-commits: $ref names $fixes commit(s) a rebase replaced; on the branch at $ref (git switch $branch && git pull --ff-only), rerun this to rename them"
  exit 1
fi
"$here/story-commits.py" --fix docs/stories >/dev/null || { echo "FAIL story-commits: the rename failed in the checkout"; exit 1; }
git add docs/stories &&
  git commit -q -m "Stories: name the commits as the rebase left them (story 1638)" &&
  git push -q "$remote" "HEAD:refs/heads/$branch" ||
  { echo "FAIL story-commits: couldn't commit and push the renamed links to $remote/$branch"; exit 1; }
echo "ok   story-commits: renamed $fixes link(s) to the rebased commits, pushed $(git rev-parse --short HEAD) to $remote/$branch"
