# The store walk on the Mac

## Summary

Igor asked for the store to be walked (2026-11-24): every story the repo calls implemented gets the check its
Status line names run again, and the walk says, story by story, whether the feature still works. The method is the
walk-the-store skill (chop-conventions); this is the Mac's half of it. The Linux VM already walks what it can climb
(the Linux rung, the wasm, the board replay); the Mac adds what only it can run: ContextCore's host tests on macOS,
the lint, the script checks, the Mac build and every UI test class on the iPad simulator.

## Goals

- One command walks the store on the Mac and writes the skill's report: green, red, skipped and untestable per story,
  and what changed since the last walk.
- Every rung runs once, never story by story; one red UI class does not stop the rest from running.
- A check that only another machine runs is reported as skipped with the reason, never as red.
- A story that cites a test, recipe or script that no longer exists reads red: its proof is gone.
- A case that fails and then passes its one retry counts as flaky, not red, so load never files a bug.

## Non-goals

- Installing anything on Igor's devices. A walk never deploys; device checks stay skipped.
- Writing tests a story lacks. A story with no named check is listed as untestable, as the skill says.
- Running the wasm or the Linux rung here: they belong to the Linux VM.

## What Igor sees

`just walk` takes an hour or more and ends with a line of counts and the path of the report. The report lists the
new reds first, then the still-red, the flaky, the skipped with why, and the untestable. The newest walk is kept as
the one the next walk compares against.

## Acceptance criteria

- A walk on main writes a report whose verdicts add up to the implemented stories.
- A UI class that fails does not stop the classes after it from running.
- A story naming a deleted test reads red with "no class … in the tree" or "has no …".
- A recipe that only the VM or Igor runs (wasm, uploads, installs) reads skipped with its reason.
- A failed case that passes its retry reads flaky and the story stays green.
