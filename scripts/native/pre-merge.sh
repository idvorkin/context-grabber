#!/usr/bin/env bash
# Run right before `gh pr merge` (story 793, bead context-grabber-jg3w): the story ID check on the branch as it
# would merge into main now. Each PR passes the check alone, yet two that took the same "next free ID" collide once
# both merge; this sees main as it is at the moment of merging. It fetches origin/main and the branch as pushed (the
# pipeline adds its own commits to the PR, so the local branch can be behind), merges them with git merge-tree,
# which touches neither the checkout nor the index, and runs story-ids.py on the merged tree's docs/stories.
# Usage: scripts/native/pre-merge.sh [branch]   (default: the current branch, or on a detached HEAD the one pushed branch
# at it; scripts/native/pr-branch.sh). PRE_MERGE_REMOTE overrides origin.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
cd "$(git rev-parse --show-toplevel)" || exit 1
remote=${PRE_MERGE_REMOTE:-origin}
branch=$("$here/pr-branch.sh" pre-merge "${1:-}") || exit 1
git fetch -q "$remote" main || { echo "FAIL pre-merge: can't fetch $remote main"; exit 1; }
if git fetch -q "$remote" "$branch" 2>/dev/null; then
  ref=$remote/$branch
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse "$ref")" ] && [ "$branch" = "$(git branch --show-current)" ]; then
    echo "note pre-merge: checking $ref ($(git rev-parse --short "$ref")), what the PR merges, not the local HEAD ($(git rev-parse --short HEAD))"
  fi
else
  ref=$branch
  echo "note pre-merge: $branch is not on $remote; checking the local branch"
fi
if ! tree=$(git merge-tree --write-tree --name-only "$remote/main" "$ref"); then
  echo "FAIL pre-merge: $ref conflicts with $remote/main; rebase on it, rerun the checks, then this:"
  sed -n '2,/^$/p' <<<"$tree" | sed 's/^/     /'
  exit 1
fi
tree=$(head -1 <<<"$tree")
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-pre-merge.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
git archive "$tree" docs/stories | tar -x -C "$tmp" || { echo "FAIL pre-merge: can't read docs/stories from the merge"; exit 1; }
if out=$("$here/story-ids.py" "$tmp/docs/stories"); then
  echo "ok   pre-merge: $ref merged with $remote/main ($(git rev-parse --short "$remote/main")): ${out#ok   story-ids: }"
else
  sed "s|$tmp/docs/stories/||" <<<"$out"
  echo "FAIL pre-merge: $ref and $remote/main together break the story IDs; renumber this branch's stories (story-ids.py reserve), push, rerun"
  exit 1
fi
