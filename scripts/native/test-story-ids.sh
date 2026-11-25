#!/usr/bin/env bash
# Host test for scripts/native/story-ids.py (#993, story 789): hand-written story trees, each with the exact failures
# a reader finds in it; its reserve command against a fake gh and a fake main (stories 791, 792, 794); the pre-merge
# check on a throwaway repository (story 793); the pipeline's claim check (story 1515); then the repo's own docs/stories, which must pass. Runs anywhere with
# python3 and git.
set -uo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-story-ids.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0

# tree <case>: a README with two journeys, A (001–009, 020) and B (010–019); story adds the stories, by ID.
tree() {
  mkdir -p "$tmp/$1"
  cat >"$tmp/$1/README.md" <<'F'
| Journey | What it covers | IDs |
|---|---|---|
| [A](01-a.md) | the first | 001–009, 020 |
| [B](02-b.md) | the second | 010–019 |
F
}
story() {  # story <case> <file> <id>...
  local c=$1 f=$2
  shift 2
  for id in "$@"; do printf '### User Story %s:\n\n- **Summary:** s%s\n\n---\n\n' "$id" "$id" >>"$tmp/$c/$f"; done
}
expect() {  # expect <name> <case> <exit> <exact FAIL lines, one per line, or empty>
  local name=$1 c=$2 want=$3 lines=$4 out status
  out=$(scripts/native/story-ids.py "$tmp/$c")
  status=$?
  got=$(grep '^FAIL' <<<"$out" | sed "s|$tmp/$c/||")
  if [ "$status" -eq "$want" ] && [ "$got" = "$lines" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name (exit $status, want $want)"
    diff <(printf '%s\n' "$lines") <(printf '%s\n' "$got") | sed 's/^/     /'
    fail=1
  fi
}

tree good
story good 01-a.md 001 2 9 20
story good 02-b.md 10 19
expect "unique IDs, each in its journey's ranges, pass" good 0 ""

tree dup
story dup 01-a.md 1 2
story dup 02-b.md 10 11
story dup 01-a.md 2
story dup 02-b.md 10
expect "an ID used twice in one file is named with both places" dup 1 "FAIL story 2 is used 2 times: 01-a.md:7, 01-a.md:13
FAIL story 10 is used 2 times: 02-b.md:1, 02-b.md:13"

tree across
story across 01-a.md 1
story across 02-b.md 10 1
expect "an ID used in two journeys is named with both places" across 1 "FAIL 02-b.md:7: story 1 is outside its journey's IDs (10–19)
FAIL story 1 is used 2 times: 01-a.md:1, 02-b.md:7"

tree outside
story outside 01-a.md 1 10 21
story outside 02-b.md 11 9
expect "an ID outside its journey's ranges fails, even one inside another journey's" outside 1 "FAIL 01-a.md:7: story 10 is outside its journey's IDs (1–9, 20)
FAIL 01-a.md:13: story 21 is outside its journey's IDs (1–9, 20)
FAIL 02-b.md:7: story 9 is outside its journey's IDs (10–19)"

mkdir -p "$tmp/overlap"
cat >"$tmp/overlap/README.md" <<'F'
| [A](01-a.md) | the first | 001–012 |
| [B](02-b.md) | the second | 010–019 |
F
story overlap 01-a.md 1
story overlap 02-b.md 15
expect "two journeys' ranges sharing IDs fail" overlap 1 "FAIL ranges overlap: 01-a.md and 02-b.md both hold 10–12"

tree unlisted
story unlisted 01-a.md 1
story unlisted 02-b.md 10
story unlisted 03-c.md 30
expect "a story file the table doesn't list fails" unlisted 1 "FAIL 03-c.md: not in README.md's journey table"

tree missing
story missing 01-a.md 1
expect "a listed journey file that is missing fails" missing 1 "FAIL README.md:4: 02-b.md is listed but not there"

tree heading
story heading 01-a.md 1
printf '### User Story 3\n\n## User Story: 4\n' >>"$tmp/heading/01-a.md"
story heading 02-b.md 10
expect "a User Story heading in another form fails instead of going unchecked" heading 1 "FAIL 01-a.md:7: unreadable story heading '### User Story 3'
FAIL 01-a.md:9: unreadable story heading '## User Story: 4'"

mkdir -p "$tmp/column"
cat >"$tmp/column/README.md" <<'F'
| [A](01-a.md) | the first | 001–009, soon |
F
story column 01-a.md 1
expect "an IDs column it can't read fails" column 1 "FAIL README.md:1: 01-a.md: can't read 'soon' in its IDs column"

# A journey of several files (story 796): A spans 01-a.md and 01-a-more.md, sharing its IDs column.
split() {
  mkdir -p "$tmp/$1"
  cat >"$tmp/$1/README.md" <<'F'
| Journey | What it covers | IDs |
|---|---|---|
| A: [one](01-a.md), [more](01-a-more.md) | the first | 001–009, 020 |
| [B](02-b.md) | the second | 010–019 |
F
}

split parts
story parts 01-a.md 1 2
story parts 01-a-more.md 3 20
story parts 02-b.md 10
expect "a journey's IDs hold across all its files" parts 0 ""

split partdup
story partdup 01-a.md 1 2
story partdup 01-a-more.md 2
story partdup 02-b.md 10
expect "an ID used in two files of one journey is named with both places" partdup 1 "FAIL story 2 is used 2 times: 01-a-more.md:1, 01-a.md:7"

split partout
story partout 01-a.md 1
story partout 01-a-more.md 3 15
story partout 02-b.md 10
expect "an ID outside its journey's ranges in its second file fails" partout 1 "FAIL 01-a-more.md:7: story 15 is outside its journey's IDs (1–9, 20)"

split partunlisted
story partunlisted 01-a.md 1
story partunlisted 01-a-more.md 3
story partunlisted 01-a-extra.md 4
story partunlisted 02-b.md 10
expect "a part file the row doesn't link fails" partunlisted 1 "FAIL 01-a-extra.md: not in README.md's journey table"

split partmissing
story partmissing 01-a.md 1
story partmissing 02-b.md 10
expect "a linked part that is missing fails" partmissing 1 "FAIL README.md:3: 01-a-more.md is listed but not there"

mkdir -p "$tmp/tworows"
cat >"$tmp/tworows/README.md" <<'F'
| A: [one](01-a.md), [shared](01-x.md) | the first | 001–009 |
| B: [one](02-b.md), [shared](01-x.md) | the second | 010–019 |
F
story tworows 01-a.md 1
story tworows 02-b.md 10
story tworows 01-x.md 2
expect "a file linked by two journeys fails" tworows 1 "FAIL README.md:2: 01-x.md is listed twice"

# --- reserve (stories 791, 792, 794; beads context-grabber-jg3w, context-grabber-py4h): a fake gh, a dir standing in
# for main, and the shared ledger as refs/story-ids/ledger in a bare repository in $tmp standing in for origin. A "machine" is
# a git repository of its own with its own lock file; two of them sharing one bare remote stand in for this Mac and the
# Linux lane.
g() { git -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null -c init.defaultBranch=main "$@"; }
mkdir -p "$tmp/prs"
cat >"$tmp/gh" <<'F'
#!/usr/bin/env bash
# The fake gh: open PRs are the files $FAKE_PRS/<n>.diff; FAKE_GH_FAIL makes the listing fail like gh offline.
case "$1 $2" in
  "pr list") [ -z "${FAKE_GH_FAIL:-}" ] || { echo "error connecting to api.github.com" >&2; exit 1; }
    ls "$FAKE_PRS" | sed -n 's/\.diff$//p' | python3 -c 'import json,sys; print(json.dumps([{"number": int(l)} for l in sys.stdin]))' ;;
  "pr diff") if [ "$(cat "$FAKE_PRS/$3.diff")" = TOOLARGE ]; then
      echo "could not find pull request diff: HTTP 406: Sorry, the diff exceeded the maximum number of files (300)" >&2; exit 1
    fi
    cat "$FAKE_PRS/$3.diff" ;;
  # A PR whose diff is too large (bead context-grabber-1338): its file list is $FAKE_PRS/<n>.files (one {f, p} per
  # line, as the --jq gives), its head is "head<n>", and a file on that head is $FAKE_PRS/<n>.head.<basename>.
  # Its changed-file count is the list's length, or $FAKE_PRS/<n>.changed when GitHub's list would come up short.
  "api --paginate") n=$(sed -n 's|.*/pulls/\([0-9]*\)/files.*|\1|p' <<<"$3"); [ -e "$FAKE_PRS/$n.files" ] || exit 1
    cat "$FAKE_PRS/$n.files" ;;
  # Its branch is $FAKE_PRS/<n>.branch (default pr<n>) and its commit subjects $FAKE_PRS/<n>.subjects, one per line,
  # each cut as GitHub cuts a long one (seen on PR #1406, 2026-11-24): the headline's first 69 characters and "…", the
  # rest after a "…" on the body's first line.
  "pr view") if [ -e "$FAKE_PRS/$3.changed" ]; then c=$(cat "$FAKE_PRS/$3.changed"); else c=$(grep -cs . "$FAKE_PRS/$3.files"); fi
    b=$(cat "$FAKE_PRS/$3.branch" 2>/dev/null || echo "pr$3")
    subjects=$(python3 -c 'import json,sys
cut = lambda l: {"messageHeadline": l[:69] + "\u2026", "messageBody": "\u2026" + l[69:]} if len(l) > 72 else {"messageHeadline": l}
print(json.dumps([cut(l.rstrip("\n")) for l in sys.stdin]))' <"$FAKE_PRS/$3.subjects" 2>/dev/null || echo '[]')
    printf '{"headRefOid": "head%s", "changedFiles": %s, "headRefName": "%s", "commits": %s}\n' "$3" "${c:-0}" "$b" "$subjects" ;;
  "api -H") n=$(sed -n 's|.*?ref=head||p' <<<"$4"); f=$(sed -n 's|.*/contents/\([^?]*\)?.*|\1|p' <<<"$4")
    cat "$FAKE_PRS/$n.head.$(basename "$f")" ;;
  *) exit 2 ;;
esac
F
chmod +x "$tmp/gh"
now=1800000000
machine() { [ -d "$tmp/m-$1" ] || g init -q "$tmp/m-$1"; }
remote() { [ -d "$tmp/$1.git" ] || g init -q --bare "$tmp/$1.git"; }
seed() {  # seed <ledger> <json>: the shared ledger as another machine left it
  remote "$1"
  local b t c
  b=$(printf '%s' "$2" | git --git-dir="$tmp/$1.git" hash-object -w --stdin)
  t=$(printf '100644 blob %s\tledger.json\n' "$b" | git --git-dir="$tmp/$1.git" mktree)
  c=$(g --git-dir="$tmp/$1.git" commit-tree "$t" -m seed)
  git --git-dir="$tmp/$1.git" update-ref refs/story-ids/ledger "$c"
}
held() {  # held <ledger>: the IDs the shared ledger holds, in its order
  git --git-dir="$tmp/$1.git" show refs/story-ids/ledger:ledger.json |
    python3 -c 'import json,sys; print(" ".join(str(r["id"]) for r in json.load(sys.stdin)["reservations"]))'
}
reserve() {  # [dir=<stories>] [main=<main>] [on=<machine>] reserve <ledger> <args>...: stdout only, the IDs
  local ledger=$1 m=${on:-mac}
  shift
  remote "$ledger"
  machine "$m"
  FAKE_PRS=$tmp/prs STORY_IDS_GH=$tmp/gh STORY_IDS_MAIN=${main:-$tmp/main} STORY_IDS_REPO=$tmp/m-$m \
    STORY_IDS_REMOTE=$tmp/$ledger.git STORY_IDS_LOCK=$tmp/m-$m.lock STORY_IDS_NOW=$now STORY_IDS_BRANCH=b \
    scripts/native/story-ids.py reserve "$@" --dir "${dir:-$tmp/res}" 2>"$tmp/reserve${err:-}.err"
}
check() {  # check <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got $(tr '\n' ' ' <<<"$2"), want $(tr '\n' ' ' <<<"$3")"; sed 's/^/     /' "$tmp/reserve.err"; fail=1; fi
}
tree res
story res 01-a.md 1 2
story res 02-b.md 10
mkdir -p "$tmp/main"
cp "$tmp/res/README.md" "$tmp/main/"
story main 01-a.md 3 7
printf 'diff --git a/docs/stories/01-a.md b/docs/stories/01-a.md\n+### User Story 4:\n ### User Story 11:\n-### User Story 12:\n' >"$tmp/prs/41.diff"
json="{\"reservations\": [{\"id\": 5, \"journey\": \"01-a.md\", \"branch\": \"x\", \"at\": $((now - 100))},
 {\"id\": 6, \"journey\": \"01-a.md\", \"branch\": \"x\", \"at\": $((now - 2 * 86400))},
 {\"id\": 7, \"journey\": \"01-a.md\", \"branch\": \"x\", \"at\": $((now - 100))}]}"
seed ledger "$json"
check "reserve skips the branch's stories, main's, an open PR's and a live reservation; takes an expired one's" \
  "$(reserve ledger 01-a.md 3)" "6
8
9"
check "the shared ledger drops a reservation past 24 h and one whose ID is on main, and keeps the new ones" \
  "$(held ledger)" "5 6 8 9"
seed xledger "$json"
on=linux reserve xledger 01-a.md 3 >/dev/null
check "a reservation one machine made is skipped by the next machine's, before either branch is pushed" \
  "$(on=mac reserve xledger 01-a.md)" "20"
check "a journey named by a word from its row" "$(reserve ledger2 second)" "11"
check "an open PR's unchanged and removed story lines take no ID" "$(reserve ledger2 second 2)" "12
13"
out=$(reserve ledger 01-a.md 2)
check "a journey with too few free IDs hands out none and says to add a block" "$out|$?|$(grep -c 'next unused block, 100–199' "$tmp/reserve.err")" "|1|1"
check "a full journey's message names the journey as its row does (bead context-grabber-0e04)" \
  "$(grep -c "the journey 'A' (01-a.md) has 1 free ID(s) of the 2 asked for in its IDs (1–9, 20)" "$tmp/reserve.err")" "1"
check "a full journey's message gives every journey's free IDs" "$(grep -c 'Free IDs per journey: A 1, B 9$' "$tmp/reserve.err")" "1"
printf 'diff --git a/docs/stories/02-b.md b/docs/stories/02-b.md\n+### User Story 250:\n' >"$tmp/prs/42.diff"
out=$(reserve ledger 01-a.md 2)
check "a full journey's next block starts above an ID an open PR adds past every row" "$(grep -c 'next unused block, 300–399' "$tmp/reserve.err")" "1"
sed -i.bak 's/| 010–019 |/| 010–019, 500–599 |/' "$tmp/main/README.md"
out=$(reserve ledger 01-a.md 2)
check "a full journey's next block starts above a block main's table holds that the branch's doesn't" "$(grep -c 'next unused block, 600–699' "$tmp/reserve.err")" "1"
mv -f "$tmp/main/README.md.bak" "$tmp/main/README.md"
rm -f "$tmp/prs/42.diff"
out=$(reserve ledger3 the)
check "a word that names two journeys fails" "$out|$?|$(grep -c 'names 2 journeys' "$tmp/reserve.err")" "|1|1"
out=$(FAKE_GH_FAIL=1 reserve ledger3 second)
check "with the open PRs unreadable it hands out nothing" "$out|$?|$(git --git-dir="$tmp/ledger3.git" rev-parse -q --verify refs/story-ids/ledger || echo untouched)" "|1|untouched"
remote gone && rm -rf "$tmp/gone.git" && mkdir -p "$tmp/gone.git"
out=$(reserve gone second)
check "with the shared ledger unreachable it hands out nothing and says so" "$out|$?|$(grep -c 'FAIL reserve: .*shared ledger' "$tmp/reserve.err")" "|1|1"
# A PR whose diff gh refuses as too large is read from its file list (bead context-grabber-1338): a story file's
# patch gives the IDs it adds; a story file with no patch (too large itself) gives every heading on the PR's head.
echo TOOLARGE >"$tmp/prs/43.diff"
cat >"$tmp/prs/43.files" <<'J'
{"f":"native/App/Big.swift","p":"+### User Story 17:"}
{"f":"docs/stories/01-a.md","p":"@@ -1 +1 @@\n+### User Story 11:\n ### User Story 16:"}
{"f":"docs/stories/02-b.md","p":null}
J
printf '### User Story 10:\n### User Story 12:\n' >"$tmp/prs/43.head.02-b.md"
check "a too-large PR's story patches and its patchless story file's headings take their IDs; other files don't" \
  "$(reserve ledger4 second 2)" "13
14"
check "a too-large PR read from its file list warns about nothing" "$(grep -c WARN "$tmp/reserve.err")" "0"
echo TOOLARGE >"$tmp/prs/44.diff"
out=$(reserve ledger5 second)
check "a PR that can be read neither way is named in a warning and doesn't block the reservation" \
  "$out|$?|$(grep -c 'WARN reserve: open PR #44 could not be read' "$tmp/reserve.err")" "13|0|1"
echo 3001 >"$tmp/prs/43.changed"
out=$(reserve ledger6 second)
check "a too-large PR whose file list is cut short of its changed files is named in a warning" \
  "$out|$?|$(grep -c 'WARN reserve: open PR #43 could not be read.*gives 3 of its 3001 changed files' "$tmp/reserve.err")" "11|0|1"
rm -f "$tmp/prs"/43.* "$tmp/prs"/44.*
remote race && remote race2 && machine mac && machine linux
for k in 1 2 3 4 5 6; do STORY_IDS_HOLD=0.3 err=.race$k reserve race 02-b.md >"$tmp/race.$k" & done
wait
check "six reservations at once on one machine, each holding the ledger a while, get six different IDs" "$(cat "$tmp"/race.? | sort -n | tr '\n' ' ')" "11 12 13 14 15 16 "
for k in 1 2 3; do
  STORY_IDS_HOLD=0.3 on=mac err=.mrace$k reserve race2 02-b.md >"$tmp/mrace.mac$k" &
  STORY_IDS_HOLD=0.3 on=linux err=.lrace$k reserve race2 02-b.md >"$tmp/mrace.linux$k" &
done
wait
check "three reservations at once on each of two machines, each holding the ledger a while, get six different IDs" \
  "$(cat "$tmp"/mrace.* | sort -n | tr '\n' ' ')" "11 12 13 14 15 16 "
check "the shared ledger after the two machines' race holds all six" "$(held race2 | tr ' ' '\n' | sort -n | tr '\n' ' ')" "11 12 13 14 15 16 "

# The shared remote is picked by its URL, not its name: on the Linux lane origin is a fork (Larry, 2026-11-24).
pick() {
  python3 -c 'import importlib.util as u, sys
s = u.spec_from_file_location("story_ids", sys.argv[1]); m = u.module_from_spec(s); s.loader.exec_module(m)
try: print(m.shared_remote(sys.argv[2]))
except RuntimeError as e: print(e)' scripts/native/story-ids.py "$tmp/m-$1"
}
machine fork
g -C "$tmp/m-fork" remote add origin https://github.com/idvorkin-ai-tools/context-grabber.git
g -C "$tmp/m-fork" remote add upstream git@github.com:idvorkin/context-grabber.git
check "the shared remote is the one at idvorkin/context-grabber, even when origin is a fork" "$(pick fork)" "upstream"
machine nofork
g -C "$tmp/m-nofork" remote add origin https://github.com/idvorkin/context-grabber-old.git
check "with no remote at idvorkin/context-grabber it names the remote to add" \
  "$(pick nofork | grep -c 'git remote add upstream https://github.com/idvorkin/context-grabber.git')" "1"

# --- bead context-grabber-py4h: with the shared ledger, 1620–1639 are ordinary IDs (the Linux lane's interim range is gone).
tree linux
story linux 01-a.md 1
story linux 02-b.md 10 1620
expect "a story numbered in the old Linux range outside its journey's IDs fails like any other" linux 1 "FAIL 02-b.md:7: story 1620 is outside its journey's IDs (10–19)"
mkdir -p "$tmp/lres" "$tmp/lmain"
cat >"$tmp/lres/README.md" <<'F'
| Journey | What it covers | IDs |
|---|---|---|
| [A](01-a.md) | the first | 001–009 |
| [C](03-c.md) | wide | 1610–1650 |
F
cp "$tmp/lres/README.md" "$tmp/lmain/"
check "reserve hands out 1620–1639 like any other IDs" \
  "$(dir=$tmp/lres main=$tmp/lmain reserve lledger 03-c.md 12 | tr '\n' ' ')" "1610 1611 1612 1613 1614 1615 1616 1617 1618 1619 1620 1621 "

# --- claimed (story 1515, bead context-grabber-6p52): the pipeline's lint step fails a branch that adds a story ID another
# open PR adds; the branch's own PR (sharing a commit subject with its commits over main) doesn't count.
entry() { printf '### User Story %s:\n\n- **Summary:** s%s\n\n---\n\n' "$1" "$1"; }
cl=$tmp/cl
g init -q "$cl"
tree clmain
story clmain 01-a.md 1
mkdir -p "$cl/docs" && cp -R "$tmp/clmain" "$cl/docs/stories"
(cd "$cl" && g add -A && g commit -qm base && g branch -q base && g checkout -q -b mine && entry 3 >>docs/stories/01-a.md \
  && g commit -qam "Story 3: the new thing" && g commit -q --allow-empty -m "no-mistakes(review): split story 3") >/dev/null 2>&1
mkdir -p "$tmp/clprs"
claimed() {  # claimed: the check on $cl's branch against the PRs in $tmp/clprs; stdout and stderr together
  FAKE_PRS=$tmp/clprs STORY_IDS_GH=$tmp/gh STORY_IDS_MAIN=$tmp/clmain STORY_IDS_BASE=base STORY_IDS_REPO=$cl \
    scripts/native/story-ids.py claimed --dir "$cl/docs/stories" 2>&1
}
out=$(claimed)
check "claimed passes a branch whose new ID no open PR adds" "$?|$(grep -c '^ok   claimed: 1 new story ID (3)' <<<"$out")" "0|1"
printf 'diff --git a/docs/stories/01-a.md b/docs/stories/01-a.md\n+### User Story 3:\n' >"$tmp/clprs/52.diff"
printf 'Story 3: the new thing\n' >"$tmp/clprs/52.subjects"
echo mine >"$tmp/clprs/52.branch"
out=$(claimed)
check "claimed passes when the only open PR adding the ID is the branch's own, found by a shared commit subject" \
  "$?|$(grep -c '^ok   claimed' <<<"$out")" "0|1"
printf 'diff --git a/docs/stories/01-a.md b/docs/stories/01-a.md\n+### User Story 3:\n+### User Story 4:\n' >"$tmp/clprs/51.diff"
printf 'Story 3: something else\n' >"$tmp/clprs/51.subjects"
echo other >"$tmp/clprs/51.branch"
out=$(claimed)
check "claimed fails a branch that adds an ID another open PR adds, naming the ID, the PR and its branch" \
  "$?|$(grep -c '^FAIL claimed: story 3 is also added by open PR #51 (branch other); take a new ID with scripts/native/story-ids.py reserve' <<<"$out")" "1|1"
(cd "$cl" && g checkout -q -b side base && g commit -q --allow-empty -m "side work" && g checkout -q mine \
  && g merge -q --no-ff -m "Merge remote-tracking branch 'origin/main' into HEAD" side) >/dev/null 2>&1
printf "Story 3: something else\nMerge remote-tracking branch 'origin/main' into HEAD\n" >"$tmp/clprs/51.subjects"
out=$(claimed)
check "claimed still fails when the other PR shares only a merge commit's subject with the branch" \
  "$?|$(grep -c '^FAIL claimed: story 3 is also added by open PR #51' <<<"$out")" "1|1"
long="Story 3: a subject long enough that GitHub cuts its headline short and carries the rest in the body"
(cd "$cl" && g commit -q --allow-empty -m "$long") >/dev/null 2>&1
printf '%s\n' "$long" >"$tmp/clprs/51.subjects"
out=$(claimed)
check "claimed finds the branch's own PR by a long commit subject that GitHub's headline cuts short" \
  "$?|$(grep -c '^ok   claimed' <<<"$out")" "0|1"
out=$(FAKE_GH_FAIL=1 claimed)
check "claimed fails rather than guess when the open PRs can't be listed" "$?|$(grep -c '^FAIL claimed: ' <<<"$out")" "1|1"

# --- pre-merge (story 793): two branches that each pass alone but add the same ID fail once merged with main.
repo=$tmp/repo
entry() { printf '### User Story %s:\n\n- **Summary:** s%s\n\n---\n\n' "$1" "$1"; }
g init -q --bare "$tmp/origin.git"
g clone -q "$tmp/origin.git" "$repo" 2>/dev/null
split pm
story pm 01-a.md 1
story pm 01-a-more.md 3
story pm 02-b.md 10
mkdir -p "$repo/docs" && cp -R "$tmp/pm" "$repo/docs/stories"
(cd "$repo" && g checkout -q -b main && g add -A && g commit -qm base && g push -q origin main
 g checkout -q -b dup && entry 2 >>docs/stories/01-a-more.md && g commit -qam "story 2" && g push -q origin dup
 g checkout -q main && g checkout -q -b fine && entry 4 >>docs/stories/01-a-more.md && g commit -qam "story 4" && g push -q origin fine
 g checkout -q main && entry 2 >>docs/stories/01-a.md && g commit -qam "main: story 2" && g push -q origin main
 g checkout -q -b clash origin/main~1 && sed -i.bak 's/s1$/one/' docs/stories/01-a.md && rm -f docs/stories/01-a.md.bak && g commit -qam clash
 g checkout -q fine && g checkout -q -b behind && entry 2 >>docs/stories/01-a-more.md && g commit -qam "pipeline: story 2" && g push -q origin behind && g reset -q --hard HEAD~1
 g checkout -q main && sed -i.bak 's/s1$/uno/' docs/stories/01-a.md && rm -f docs/stories/01-a.md.bak && g commit -qam uno && g push -q origin main) >/dev/null 2>&1
premerge() { (cd "$repo" && g checkout -q "$1" && "$OLDPWD/scripts/native/pre-merge.sh"); }
out=$(premerge dup 2>&1)
check "pre-merge fails a branch that collides with main once merged, naming both places" \
  "$?|$(grep '^FAIL story' <<<"$out")" "1|FAIL story 2 is used 2 times: 01-a-more.md:7, 01-a.md:7"
out=$(premerge fine 2>&1)
check "pre-merge passes a branch whose IDs are still free on main" "$?|$(grep -c '^ok   pre-merge' <<<"$out")" "0|1"
out=$(premerge behind 2>&1)
check "pre-merge judges the branch as pushed when the checkout is behind it" \
  "$?|$(grep -c '^note pre-merge: checking origin/behind' <<<"$out")|$(grep -c '^FAIL story 2 is used 2 times' <<<"$out")" "1|1|1"
out=$(premerge clash 2>&1)
check "pre-merge fails a branch that conflicts with main" "$?|$(grep -c 'conflicts with origin/main' <<<"$out")" "1|1"
# Bead context-grabber-9g0j: a detached HEAD (a temp worktree, a pipeline head) judges the one pushed branch at it, and
# fails, naming what to pass, when no pushed branch is there.
out=$(premerge origin/fine 2>&1)
check "pre-merge on a detached HEAD judges the one pushed branch at it" \
  "$?|$(grep -c '^note pre-merge: detached HEAD at .* judging origin/fine' <<<"$out")|$(grep -c '^ok   pre-merge: origin/fine' <<<"$out")" "0|1|1"
out=$(premerge "$(cd "$repo" && git rev-parse clash)" 2>&1)
check "pre-merge on a detached HEAD no pushed branch is at fails, naming the branch to pass" \
  "$?|$(grep -c '^FAIL pre-merge: detached HEAD at .* no branch on origin points at it; name the PR.s branch: just pre-merge <branch>' <<<"$out")" "1|1"

if out=$(scripts/native/story-ids.py docs/stories); then
  echo "ok   docs/stories: ${out#ok   story-ids: }"
else
  echo "FAIL docs/stories"
  sed 's/^/     /' <<<"$out"
  fail=1
fi
exit $fail
