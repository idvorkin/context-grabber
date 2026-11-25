#!/usr/bin/env bash
# Host test for scripts/native/merged-tip-check.sh (story 1629): on a throwaway repository with a fake compiler, two
# branches that each compile alone but break the build together (one changes a signature on main, the other calls it
# the old way: #1459 and #1465, 2026-11-24) fail the second one's check on the merged tip with a FAIL line naming the
# compile error; a branch that compiles on main passes; a docs-only branch skips the compile unless forced; a branch
# that doesn't merge cleanly onto main fails without compiling; and the checkout and its branch are never touched.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-merged-tip.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0

git init -q -b main "$tmp/origin.git" --bare
git clone -q "$tmp/origin.git" "$tmp/repo" 2>/dev/null
cd "$tmp/repo" || exit 1
git config user.email t@t && git config user.name t
mkdir -p native/App docs
echo f1 >native/App/lib.txt && echo d >docs/x.md && : >native/App/uses.txt
git add -A && git commit -qm base && git push -q origin main
# The caller: calls f1, which main has today, so it compiles alone.
git checkout -qb caller main && echo "call f1" >native/App/uses.txt && git commit -qam caller && git push -q origin caller
# The signature change, which compiles alone too (nothing calls f yet on its side).
git checkout -qb sig main && echo f2 >native/App/lib.txt && git commit -qam sig && git push -q origin sig
git checkout -qb docs-only main && echo d2 >>docs/x.md && git commit -qam docs && git push -q origin docs-only
git checkout -qb clash main && echo f3 >native/App/lib.txt && git commit -qam clash && git push -q origin clash

# The fake compiler: every "call fN" must name lib.txt's signature, else a compile error the way Xcode prints one.
cat >"$tmp/fakecc" <<'EOF'
#!/usr/bin/env bash
touch "$BUILT"
sig=$(cat native/App/lib.txt)
while read -r c f; do
  [ "$c" = call ] || continue
  if [ "$f" != "$sig" ]; then
    echo "$PWD/native/App/uses.txt:1:6: error: missing argument for parameter 'group' in call"
    echo "** BUILD FAILED **"
    exit 65
  fi
done <native/App/uses.txt
echo "** BUILD SUCCEEDED **"
EOF
chmod +x "$tmp/fakecc"

# check <name> <branch> <want exit> <want built: 1|0> <want line regex> [env…]
check() {
  local name=$1 branch=$2 want=$3 built=$4 line=$5 out status ran=0 before
  shift 5
  git checkout -q "$branch"
  before=$(git rev-parse HEAD)
  rm -f "$tmp/built"
  out=$(env "$@" BUILT="$tmp/built" MERGED_TIP_DIR="$tmp/tip" MERGED_TIP_BUILD="$tmp/fakecc" \
    "$here/merged-tip-check.sh" 2>&1)
  status=$?
  [ -e "$tmp/built" ] && ran=1
  if [ "$status" -eq "$want" ] && [ "$ran" -eq "$built" ] && grep -qE "$line" <<<"$out" &&
    [ "$(git rev-parse HEAD)" = "$before" ] && [ "$(git branch --show-current)" = "$branch" ] && git diff --quiet; then
    echo "ok   $name"
  else
    echo "FAIL $name (exit $status, want $want; built $ran, want $built)"
    sed 's/^/     /' <<<"$out"
    fail=1
  fi
}

check "a branch that compiles on main passes" caller 0 1 '^ok   merged-tip: .*compiles'
check "the signature change compiles alone" sig 0 1 '^ok   merged-tip: .*compiles'
# The signature change lands on main; the caller, untouched, now breaks only on the merged tip.
git checkout -q main && git merge -q --no-edit sig && git push -q origin main
check "a branch that compiles alone but not merged onto main fails, naming the error" caller 1 1 \
  "^FAIL merged-tip: .*missing argument for parameter 'group'"
check "a docs-only branch skips the compile" docs-only 0 0 '^ok   merged-tip: .*skipped'
check "MERGED_TIP_CHECK=1 compiles even a docs-only branch" docs-only 0 1 '^ok   merged-tip: .*compiles' MERGED_TIP_CHECK=1
check "a branch that doesn't merge cleanly onto main fails without compiling" clash 1 0 '^FAIL merged-tip: .*merge cleanly'
check "the scratch copy is reused on the next run" caller 1 1 "^FAIL merged-tip: .*missing argument"
exit $fail
