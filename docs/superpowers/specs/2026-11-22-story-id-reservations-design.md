# Story ID reservations and the pre-merge check

Beads `context-grabber-jg3w` and `context-grabber-py4h` (the ledger shared between machines). Stories 791 to 794 in [Building and testing](../../stories/11-building-and-testing.md).

## Summary

Many agents add user stories at once, each on its own branch. Each took "the next free ID" by reading its own
branch, so each PR passed the story ID check alone, and once two of them merged, main held the same ID twice. That
happened four times on 2026-11-22 (955, 1101, 1155, 1113–1115). The check (story 789) can only see one tree; nothing
saw the other branches.

Two things close the gap: a new story's ID is *reserved* rather than picked, and the check is run once more on the
branch as it would merge, right before merging.

## Goals

- Two agents asking for an ID at the same moment never get the same one, whether they run on this Mac or on two
  machines (this Mac and the Linux lane, bead `context-grabber-py4h`).
- An ID another open PR already added, or that main already has, is never handed out, even when that PR came from
  another machine.
- A collision that slips through (two branches that merged in between) is caught before the second merge, not on
  main.

## Non-goals

- A server. The shared ledger lives in the repository's own remote, beside the code, so any machine that can push a
  branch can reserve an ID.
- Making the merge atomic: a PR that merges in the seconds between the pre-merge check and the merge can still
  collide. The host rung on main and the next pre-merge catch it.
- Renumbering stories that already collide on main.

## Reserving an ID

The story ID tool gets a reserve command that takes a journey (any of its story files, or a word from its row in the
journey table, like `building` or `whiteboard`) and how many IDs are wanted (one by default). It prints the IDs, one
per line and nothing else, lowest first, from that journey's IDs column.

An ID is not handed out when it is:

- a story on main as it is on the remote now (fetched first, not the checkout's possibly stale copy),
- a story in the tree it runs in (the branch's own new stories),
- a story heading added by any open PR,
- reserved by any machine in the last 24 hours and not yet on main.

Reservations are kept in one ledger shared by every machine, held in the repository's remote apart from its branches,
so it never shows up in a checkout or a PR. Each records the ID, its journey, the branch and when (no machine name: the repository is public). A
reservation lapses after 24 hours, or as soon as its ID is on main (the story merged), whichever is first.

Two reservations at once never get the same ID. On one machine they are taken one after the other. Across machines,
a reservation reads the ledger as the remote has it, adds its IDs, and writes it back only if nobody else wrote it in
between; if somebody did, it reads the new ledger and picks again, a few times before giving up. It fails, and hands
out nothing, when it can't read or write the shared ledger (no network, no push access), the same as when it can't
fetch main. The ledger on this Mac from before (bead `context-grabber-jg3w`) is no longer read; its live reservations are
copied into the shared ledger once, when this lands.

One open PR GitHub won't show in full doesn't stop every reservation (bead context-grabber-1338). GitHub refuses the
whole diff of a very large PR. For such a PR the reservation reads each of its story files' changes instead, and for a
story file whose own change is too large to show, every story in that file as the PR has it, which can only take more
IDs than the PR adds, never fewer. GitHub lists at most 3000 of a PR's files; a list shorter than the PR's count of
changed files counts as unread. A PR that can't be read either way is named in a warning, its IDs are not known,
and the reservation goes ahead without them, so whoever reserves checks that PR by hand.

It fails, and hands out nothing, when it can't fetch main or list the open PRs (an ID chosen without them is the bug
this fixes), when the journey names no row or more than one, and when the journey's IDs column has no free ID left
(see below).

When a journey has too few free IDs, the message names the journey as its row does (its name, not only its first
file), its IDs column, and how to extend it: add an unused block to the end of its row's IDs column in the journey
table, the next block above every ID any journey holds in the journey table, on the branch or on main, and above every ID taken on main, in an open PR or reserved (it says which, a hundred wide), then reserve again. It also
lists how many free IDs every journey has left, so a second journey running low is seen at the same time. A journey
that adds stories quickly, like the whiteboard, takes a large block (hundreds) rather than twenty at a time, so it
does not run out again within the week (bead `context-grabber-0e04`: the whiteboard ran out on 2026-11-22 and agents
went back to picking IDs by hand, one of them reusing an ID an open PR already held). The block is added on purpose,
never by an agent or the pipeline's review or document step mid-PR to make room for its own story: they stop and
report the full journey (bead `context-grabber-1vvb`).

Before the shared ledger, the Linux lane numbered its stories 1620–1639 without a row in the journey table, and this
Mac stepped over them. With the shared ledger that exception is gone: 1620–1639 are Building and testing's, where the
Linux lane's stories in that range already sit, and every machine reserves its IDs the same way.

## The pre-merge check

A recipe, run in the branch's checkout immediately before merging its PR: it fetches main and the branch as pushed
(the pipeline adds its own commits to the PR, so the local branch can be behind it), merges the two without touching
the checkout, and runs the story ID check on the stories of the merged result. When the checkout is behind the pushed
branch it says so and checks the pushed one, since that is what merges; a branch not pushed yet is checked as it is
locally. It fails when the merge conflicts or when the merged stories fail the check, naming each problem the way the
host rung does. It passes, and says so, otherwise. Its last line is always `ok   pre-merge: …` or `FAIL pre-merge: …`,
and its exit status is the verdict: the merge runs only when it succeeds (`just pre-merge && gh pr merge …`), never
after its output went through a pipe, which hides a failure (on 2026-11-24 `just pre-merge | tail -2` let #1400 merge
duplicate IDs onto main).

Then, when the branch changes the shared core, the pre-merge check compiles it with the optimizer on, the way an
archive (the over-the-air build, TestFlight) compiles it. Every other rung builds without the optimizer, so a compiler
crash only the optimizer hits otherwise surfaces after the merge, in the next over-the-air build (2026-11-24: Swift
6.4.2 crashed optimizing a board review check). A failing optimized build fails the pre-merge check with a line naming
it. It judges the branch as pushed, not the local checkout: a branch whose pushed commits change the shared core is
built even when the local ones don't, and a checkout that isn't the pushed branch fails the check, telling the agent
to check it out, rather than building stale code. A branch that leaves the shared core as main has it skips the
build; it can be forced. It runs in a host slot and
reuses the checkout's build folder, so it takes about a minute in a slot (about two cold).

Last, when the branch changes the app, the pre-merge check compiles the app on the merged result: main as it is on
the remote now with the branch as pushed merged in, in a scratch copy that never touches the checkout, the branch or
main. Two PRs can each pass every rung alone and still break main once both land: on 2026-11-24 one added a parameter
to a chat view and the other, merged minutes later, called it the old way, and main's debug build failed for every
lane and every device install until a fix landed. The compile is the cheap debug build for the iPhone and iPad
simulator, without booting one, the build every lane and device install depends on. A failing compile fails the
pre-merge check with a line naming the first compile error; a branch that doesn't merge cleanly onto main fails too.
A branch that leaves the app's code as main has it (docs and scripts only) skips the compile; it can be forced. The
scratch copy and its build folder stay in the checkout's build folder between runs, so a slot's next run builds only
what changed.

## The pipeline's own check, before it pushes

Telling the pipeline's review and document steps to reserve (bead `context-grabber-1vvb`) was not enough: on
2026-11-24 they still picked IDs themselves three times (1609/1610, and 1292/1293 twice), and two of those collided
with another open PR, which broke every lane's pre-merge until main was renumbered (bead `context-grabber-6p52`). So
the pipeline checks it mechanically, in its lint step, which runs after review and document and before the push.

The check looks at every story ID the branch adds over main as it is on the shared remote now. It fails, naming the
ID, the other PR and its branch, when another open PR adds the same ID. The branch's own PR is not "another": it is the
open PR that shares a commit subject with the branch's commits over main, which still holds after the pipeline rebases
(the pipeline's worktree is on no branch, so the name can't be used). Each failure says to take a new ID from the
reserve command and renumber. An ID no other open PR adds passes, reserved or not, since what breaks main is two
branches holding one ID. Like reserving, it fails rather than guess when it can't fetch main or list the open PRs.

## Acceptance criteria

- Two reservations started at once for the same journey print different IDs, on one machine or on two (two
  checkouts sharing one remote stand in for two machines).
- A reservation made on one machine is skipped by a reservation made on another, before either branch is pushed.
- When the shared ledger can't be read or written, it fails and prints no ID.
- An ID an open PR adds, an ID on main, an ID in the branch's own stories and an ID reserved earlier are skipped.
- A reservation older than 24 hours, or whose ID has reached main, no longer holds its ID.
- With the open PRs unreadable, it fails and prints no ID.
- An open PR whose whole diff GitHub refuses still has its stories' IDs skipped, from its story files' changes, or for a
  story file too large to show, from every story in that file on the PR; a PR that can't be read either way, or whose
  file list GitHub cuts short of its changed files, is named in a warning, and the other IDs are handed out.
- With too few free IDs, it prints no ID; its message names the journey by its row's name, the next unused block
  above every journey's IDs and the free IDs every journey has left.
- 1620–1639 belong to Building and testing like any other block: no ID is left out of reservations, and a story
  outside its journey's IDs fails the check whatever its number.
- Two branches that each pass the story ID check alone, but add the same ID, fail the pre-merge check; one that
  doesn't collide passes; one whose pushed commits add the colliding ID fails even when the checkout is behind them.
- The agent instructions say: new stories take their IDs from the reserve command, and the pre-merge check runs
  right before every merge, chained so the merge runs only when it passes.
- A branch that changes the shared core is compiled with the optimizer on before it merges; a failing optimized
  build fails the pre-merge check, and a branch that leaves the shared core alone skips it. A checkout behind the
  pushed branch fails the check without building, even when only the pushed commits touch the shared core.
- Two branches that each compile alone but break the app's build together are caught: the second one's pre-merge
  check fails on the merged result with a line naming the compile error. A branch that changes only docs or scripts
  skips the compile, and a branch that doesn't merge cleanly onto main fails.
- The pipeline's lint step fails a branch that adds an ID another open PR adds, naming the ID and that PR, and passes
  when the only other PR adding it is the branch's own (found by a shared commit subject, even after a rebase); with the
  open PRs unreadable it fails.
