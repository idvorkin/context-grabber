# Development builds over the air: `just ota` and the build after each merge batch

Bead `context-grabber-omes`. Igor, 2026-11-22 (via Larry): he is staying on development builds, and wants the build
loop written down and made faster. Until now a development build reached the iPad over the cable or the network
(`just native-run-device`, BugKit's `deploy-all.sh`), or through a script in an agent's scratch folder that copied a
development-signed package to the Cockpit's `/builds` page, from where the iPad installs it over the air.

## Goals

- One command on the Mac builds main as a development-signed package the iPad can install over the air, and puts it
  on the Cockpit's `/builds` page.
- It says what it built: the version, the build number, the commit and the package's checksum, and how long each
  step took.
- It refuses to publish a package the iPad could not install: one whose profile does not list the iPad.
- A watcher builds main by itself after each batch of merges, and tells Igor in his Cockpit thread what the new
  build holds.
- One document explains every way a build reaches a device, signing and its renewal, adding a device, and what
  would make the loop faster.

## Non-goals

- Replacing the cable or network install, or TestFlight. They stay as they are.
- A login item or a daemon: the watcher runs in the foreground, kept running by whoever started it.
- Building branches: what `just ota` builds is always main. (A build installed on a device, from whatever commit, is
  also copied to the page as it is: see "Every install lands on /builds".)
- Making the loop faster in this change. The document lists the options with their estimated savings; each is its own
  change.

## `just ota`

- Switches the Mac's checkout to main and brings it up to date, then archives it as `just testflight --export-only`
  does (the same build stamps, the same build number, the same signing lock and screen-lock guard), and exports the
  archive signed for development, for the devices in the team's profile.
- Checks that every embedded profile can be read and lists the iPad. The id comes from the local file git ignores
  and is never printed whole. A failed check stops publication and explains what needs attention.
- Publishes the package to the Cockpit's builds folder as `grabber-<commit>.ipa` after the transfer completes. A
  failed transfer leaves any existing build available. The host and folder can be named in the environment.
- Ends with one line naming the version, the build number, the commit, the first characters of the package's SHA-256
  and where it went, and a line with each step's seconds (also kept in a local timing log).
- Says when each profile expires.
- `--dry-run` says what it would build and where it would go, and checks that the iPad's id is known, without
  switching branches, building, signing or copying.
- Only one runs at a time on the Mac: a second one, by hand or from the watcher, stops at once and says another is
  running.
- A Mac that stays locked, a lost Xcode account and a missing iPad end it with distinct exit codes, so the watcher can
  tell "try again later" from "a person must act".

## `just ota-watch`

- Polls main on GitHub every minute.
- A batch is one or more merges into main followed by ten minutes with no further merge. When a batch ends, the
  watcher builds the commit it checked. If main has advanced when OTA selects the build, the watcher polls again.
  After publishing the checked commit, it posts to Cockpit thread `igor2-88g.1620`: *New build on /builds:
  <version> (<build>) <commit>, with: <the pull requests merged since the last build>*.
- It remembers the last commit it built in a file outside the repository, so a restart neither rebuilds nor skips a
  batch. On its first run, with no such file, it starts from main as it is and builds nothing until the next batch.
- If a published build's announcement fails, the watcher remembers the pending announcement and retries it on
  the next poll, including after a restart. It finishes that announcement before starting another build.
- The batch is judged on when the merges happened, not when the watcher saw them, so a watcher started after a batch
  builds it on its first poll.
- A build that could not start because the Mac was locked or another build was running is tried again at the next
  poll. Other build failures stop the watcher with diagnostics in its local output.
- Only one watcher runs at a time.

## Every install lands on /builds

Igor, 2026-11-25: "Why new builds not uploaded" — the page had one build from the morning while newer ones had gone
straight to his devices. He wants the page never behind the devices, for every app.

- Every install on a device, the network install to every device and the cable install to one, also puts the very
  build it installed on the page as `grabber-<commit>.ipa`. Nothing is built or signed a second time.
- It happens in the background after the install. The install and the launch don't wait for it, and a copy that
  fails never fails the install; the outcome is one line in a local log.
- When the page already has that commit's build, nothing is copied: the file is touched, so it shows as the newest.
- A build from uncommitted changes goes up as `grabber-<commit>-dirty.ipa`, never under the clean commit's name.
- The installed build is the Debug build the devices run; `just ota`'s is Release. Both are development-signed.

## The deploy document

One document covers: the cable and network install to named devices and what *unavailable* means; waiting for a
device to come back before deploying; the over-the-air build and the watcher; signing (automatic signing, the one
signing build at a time, the screen-lock guard, a locked Mac); renewing the development profile (it expires after a
year); adding a device; the development and production iCloud environments; and what would make the loop faster,
each with an estimated saving.

## Acceptance criteria

- `just ota` on a clean main produces a development-signed package whose profile lists the iPad, copies it to the
  Cockpit's builds folder named by its commit, and prints the version, build, commit and checksum.
- With no iPad id, or a profile without the iPad, nothing is copied and the reason is printed; the full id never is.
- `just ota --dry-run` builds and changes nothing and prints the plan.
- Two ota runs at once: the second stops at once.
- With merges on main ten minutes old and none newer, the watcher builds and posts the build's version, build, commit
  and the merged pull requests' titles; with a merge newer than that, it waits; with nothing new, it does nothing.
- A watcher restarted between batches neither rebuilds the last build nor misses the next batch.
- The deploy document is linked from the agent instructions and the testing guide.
- After `just deploy` or `just native-run-device` installs a commit, the page lists `grabber-<that commit>.ipa` within
  the copy's time, the install having finished without waiting for it; a second install of that commit copies
  nothing; with the Cockpit unreachable, the install still succeeds and the log says the copy failed.
