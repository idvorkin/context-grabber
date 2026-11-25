#!/usr/bin/env bash
# Host test for scripts/native/story-commits.py (beads context-grabber-t309, context-grabber-lldg): a throwaway
# repository with reachable and stale commit links, including uppercase abbreviations and a shallow clone;
# then the repo's own docs/stories, which must pass.
set -uo pipefail
cd "$(dirname "$0")/../.."
here=$PWD
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-story-commits.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0
U=https://github.com/idvorkin/context-grabber/commit

g() { git -C "$tmp/repo" -c user.name=t -c user.email=t@example.com "$@"; }
mkdir -p "$tmp/repo/docs/stories"
g init -q -b main
g commit -q --allow-empty -m one
kept=$(g rev-parse HEAD)
g checkout -q -b side
g commit -q --allow-empty -m before-rebase
gone=$(g rev-parse HEAD)
g checkout -q main
g branch -q -D side
g reflog expire --expire=now --all
g gc -q --prune=now

story() {  # story <body> [checkout]: the one story file, then the check's output and status
  local stories="${2:-$tmp/repo}/docs/stories"
  printf '%s\n' "$1" >"$stories/01-a.md"
  out=$("$here/scripts/native/story-commits.py" "$stories")
  status=$?
}
expect() {  # expect <name> <exit> <exact output>
  if [ "$status" != "$2" ] || [ "$out" != "$3" ]; then
    echo "FAIL $1: exit $status (want $2), output:"
    echo "$out"
    fail=1
  else
    echo "ok   $1"
  fi
}

story "- **Status:** implemented in [${kept:0:7}]($U/${kept:0:7})"
expect "a short sha in the history" 0 "story-commits: 1 commit links, every one in this branch's history"
story "- **Status:** in [x]($U/$kept) and [y]($U/${kept:0:8})"
expect "a full and an 8-character sha" 0 "story-commits: 2 commit links, every one in this branch's history"
story "first line
- **Status:** implemented in [${gone:0:7}]($U/${gone:0:7})"
expect "a sha from before a rebase" 1 "FAIL 01-a.md:2: links commit ${gone:0:7}, which is not in this branch's history (a sha from before a rebase? name the commit as it is on the branch)"

upper_kept=$(printf '%s' "${kept:0:8}" | tr 'a-f' 'A-F')
upper_gone=$(printf '%s' "$gone" | tr 'a-f' 'A-F')
story "Implemented in [kept]($U/$upper_kept) and [stale]($U/$upper_gone)"
expect "uppercase commit hashes" 1 "FAIL 01-a.md:1: links commit $upper_gone, which is not in this branch's history (a sha from before a rebase? name the commit as it is on the branch)"

g commit -q --allow-empty -m current || exit 1
tip=$(g rev-parse HEAD)
g clone -q --depth=1 "file://$tmp/repo" "$tmp/shallow" || exit 1
mkdir -p "$tmp/shallow/docs/stories" || exit 1
story "Implemented in [current]($U/$tip)" "$tmp/shallow"
expect "a shallow clone can verify a recent commit" 0 "story-commits: 1 commit links, every one in this branch's history"
story "Implemented in [older]($U/$kept) and [stale]($U/$gone)" "$tmp/shallow"
expect "a shallow clone fails if it cannot verify a link" 1 "FAIL 01-a.md:1: links commit $kept, which is not in this checkout's available history
FAIL 01-a.md:1: links commit $gone, which is not in this checkout's available history
story-commits: this clone is shallow. Fetch the full history (git fetch --unshallow) and rerun."

# --- Story 1638 (bead context-grabber-zisx): a link to a commit a rebase replaced. A branch's story links its own
# commit; main moves; the branch is rebased, which gives that commit a new sha with the same change (patch-id).
r=$tmp/rb
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
rg() { git -C "$r" -c user.name=t -c user.email=t@example.com "$@"; }
git init -q --bare "$tmp/rb-origin.git"
git clone -q "$tmp/rb-origin.git" "$r" 2>/dev/null
mkdir -p "$r/docs/stories"
echo base >"$r/code.txt"
printf '### User Story 1:\n' >"$r/docs/stories/01-a.md"
rg checkout -q -b main && rg add -A && rg commit -qm base && rg push -q origin main
rg checkout -q -b feature
echo feature >>"$r/code.txt" && rg commit -qam feature
old=$(rg rev-parse HEAD)
printf -- '- **Status:** implemented in [%s](%s/%s)\n' "${old:0:8}" "$U" "${old:0:8}" >>"$r/docs/stories/01-a.md"
rg commit -qam status
prerebase=$(rg rev-parse HEAD)
rg checkout -q main && echo other >"$r/other.txt" && rg add -A && rg commit -qm "main moves" && rg push -q origin main
rg checkout -q feature && rg rebase -q main && rg push -q -f origin feature
new=$(rg rev-parse HEAD~1)
out=$("$here/scripts/native/story-commits.py" "$r/docs/stories")
status=$?
expect "a link to a commit the rebase replaced passes with a note" 0 "note 01-a.md:2: ${old:0:8} was rebased to ${new:0:8}
story-commits: 1 commit links, every one in this branch's history; 1 name a commit a rebase replaced (just pre-merge renames them, or story-commits.py --fix)"
rg reset -q --hard "$prerebase"
echo staged >"$r/staged.txt" && rg add staged.txt
out=$(cd "$r" && "$here/scripts/native/story-commits-pre-merge.sh" 2>&1)
status=$?
pushed=$(git -C "$tmp/rb-origin.git" rev-parse feature)
expect "pre-merge behind a force-pushed branch renames the link and pushes it" 0 "fixed 01-a.md:2: ${old:0:8} was rebased to ${new:0:8}
ok   story-commits: renamed 1 link(s) to the rebased commits, pushed ${pushed:0:7} to origin/feature"
if [ "$(git -C "$tmp/rb-origin.git" diff --name-only feature~1 feature)" = "docs/stories/01-a.md" ] &&
  [ "$(rg rev-parse HEAD)" = "$prerebase" ] && [ "$(rg diff --cached --name-only)" = "staged.txt" ]; then
  echo "ok   the pushed commit changes only the story, and the checkout is left as it was"
else
  echo "FAIL the pushed commit or the checkout changed beyond the story"
  fail=1
fi
if git -C "$tmp/rb-origin.git" show feature:docs/stories/01-a.md | grep -q "commit/${new:0:8})"; then
  echo "ok   the pushed story links the rebased commit"
else
  echo "FAIL the pushed story doesn't link ${new:0:8}"
  fail=1
fi
out=$(cd "$r" && "$here/scripts/native/story-commits-pre-merge.sh" 2>&1)
status=$?
expect "pre-merge again has nothing to rename" 0 "ok   story-commits: origin/feature names only its own commits"

if out=$(scripts/native/story-commits.py docs/stories); then
  echo "ok   the repo's own stories: $out"
else
  echo "FAIL the repo's own stories:"
  echo "$out"
  fail=1
fi
exit $fail
