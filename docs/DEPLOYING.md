# Deploying: how a build reaches the phone and the iPad

Igor stays on development builds (2026-11-22). This is the whole loop in one place: the cable or network install,
the over-the-air build and the watcher that makes one after each merge batch, signing and its renewal, adding a
device, and what would make it faster. The test ladder that comes before any of this is [TESTING.md](TESTING.md);
TestFlight, the lane beside these, is its "TestFlight" section. Device ids never go in the repository (it is public):
they live in the gitignored `scripts/native/phone-udid.local` and `scripts/native/ipad-udid.local`, or `DEVICE` / `IPAD`
in the environment for the cable install and `pull-logs` (`just ota` reads only the file).

While the whiteboard work is in progress (Igor, 2026-11-22), nothing is deployed to the iPhone: the iPad only.

| Path | Command | Build | Gets there | Logs back with `just pull-logs` |
|---|---|---|---|---|
| Cable or network, one device | `just native-run-device` (`DEVICE=<udid>` for the iPad) | Debug, development-signed | about a minute after the build; the device unlocked, on the cable or the same network | yes |
| Cable or network, every device | `just deploy --only <device>` (BugKit's `deploy-all.sh`) | Debug, development-signed, built once | the same | yes |
| Over the air | `just ota`, or `just ota-watch` after each merge batch | Release, development-signed | the iPad installs it from the Cockpit's /builds page, anywhere | yes (a development build) |
| TestFlight | `just testflight` | Release, App Store-signed | the TestFlight app, 5-30 minutes after the upload | no |

## The cable and network install

`just native-run-device` builds under the signing lock, installs and launches on the phone, or on the device named
by `DEVICE`, and records the install in the deploys ledger ([TESTING.md](TESTING.md) "The phone").

`just deploy` runs BugKit's `deploy-all.sh`, which builds once and installs on every paired iPhone and iPad (bug-kit
`docs/ops/deploying.md`), records each device that took the build in the deploys ledger, and then checks the build the
device reports (below). **Install through `just deploy`, not by calling `deploy-all.sh` directly:** an install the
ledger doesn't hold is how, on 2026-11-22, an agent told Larry the iPad was on b3e9de18 when it ran 5569178f (story 1511).

```sh
just deploy --only ipad              # the iPad (ipad and phone stand for their model folders)
just deploy --only ipad-air-11-inch-m3   # one device, by its model folder
just deploy --dry-run                # what it would build and install
```

- **`--only`** takes `ipad`, `phone`, or the folder names the listener uses, the device's model slugged
  (`ipad-air-11-inch-m3`, `iphone-17-pro`), comma separated. Without it every paired iPhone and iPad gets the build,
  the iPhone included.
- **It installs the commit BugKit's config names for the app** (`~/.config/bug-kit/apps.json`'s `repo`, the main
  checkout), whichever checkout runs it, and says so when that isn't this one.
- **A deploy restarts the app.** It installs over the running app and relaunches it. Check that Igor isn't using the
  device (the iPad's newest session log, or his thread) and say in the thread when a deploy will restart it.
- **`unavailable`** in `xcrun devicectl list devices`' State column (`connectionProperties.tunnelState` in its JSON) means
  the device is paired but the Mac can't reach it now: asleep, off the Mac's network, Wi-Fi off, or away. It is not a
  signing problem and rebuilding doesn't help. A build aimed at it waits and fails with *destination not found*; an
  install fails. Wake it (unlock it, on the same network or the cable) and deploy again.
- deploy-all's own exit codes: 78 the Xcode account is gone (stop, tell Igor, never retry), 79 the build's
  destination device is locked, 80 the Mac stayed locked; a launch refused while the device is locked (10002) is
  installed and opens when unlocked.

### Waiting for a device to come back

When the device is `unavailable` and a fix should land as soon as it is back, poll the state and deploy once it
changes, instead of retrying the build. The pattern, by the device's name (no id):

```bash
until xcrun devicectl list devices 2>/dev/null | grep -F "iPad Air 11-inch (M3)" | grep -qv unavailable; do sleep 60; done
just deploy --only ipad
```

Run it as a background task the lead can see and stop, not with `nohup`. The deploy still restarts the app when it
lands, so the "is Igor using it" check applies when the device comes back, not when the watcher was started.

### Which build is on the device: `just device-build-check`

Story 1511 ([spec](superpowers/specs/2026-11-22-device-build-check-design.md)). Every install is in the deploys ledger
(`~/tmp/agent/notes/lead-times/deploys.jsonl`): `cable` from `just native-run-device`, `network` from `just deploy`,
and `ota_posted` from `just ota` (an offer: the iPad installs it when Igor taps it). `just device-build-check [ipad|phone]`
reads each device's newest pulled session log (`just pull-logs` first) and compares the build it names with the last
install:

- **MATCH**: the device runs the build last installed, or a build posted over the air after it.
- **MISMATCH**: it runs another build; both are named with their times, and the check exits 1. Find who installed it
  before telling anyone what's on the device.
- **NO SESSION YET**: no session has started since the install (the app hasn't opened).
- **UNKNOWN**: no install recorded, or no logs pulled for the device.

`just deploy` runs it itself after an install, pulling the logs until the session its launch starts shows up (up to
`DEPLOY_CHECK_WAIT`, 120 s; a mismatch is polled through too, since an older session can be pulled first), and exits 1
if it still mismatches at the deadline. **Before telling Igor or Larry which build a device is on,
run it** rather than relying on memory.

## Over the air: `just ota`

`just ota` ([spec](superpowers/specs/2026-11-22-ota-builds-design.md), stories 1027-1029) builds **main** for the
iPad to install over the air, from anywhere:

1. Switches the checkout it runs in to main and pulls (run it from the main checkout; a pool slot can't check out
   main while the main checkout has it). When the watcher starts OTA, it defers if main has advanced since the poll.
2. Archives main as `just testflight --export-only` does: Release, the build stamps, the build number from the commit
   count, under the signing lock and BugKit's guard (`native/Build/logs/ota-testflight.log`).
3. Exports the archive development-signed (method `debugging`, automatic signing, the team from `project.yml`) to
   `native/Build/Export/<stamp>-dev`, again under the lock and the guard (`native/Build/logs/ota-export.log`).
4. Checks that every profile in the package (the app, the widgets, the share extension) can be read and lists the
   iPad in `scripts/native/ipad-udid.local`, and says when the profiles expire. A failed check stops publication
   (exit 78).
5. Publishes the fully transferred package as `developer@c-5004:gits/igor2/cockpit-data/builds/grabber-<sha>.ipa`
   (`OTA_HOST` and `OTA_DIR` name another destination). A failed transfer leaves any existing copy in place.
6. Prints the version, build, commit and the first 16 characters of the package's SHA-256, and each step's seconds,
   also kept in `~/tmp/agent/notes/ota-timings.log`.

`just ota --dry-run` prints the plan and changes nothing. `just ota --check-ipa <ipa>` checks any package's profiles for
the iPad (the id shown only as its first and last four characters). Only one ota runs at a time: a second one exits
75 at once. Exit 78 means a person must act (no iPad id, the iPad not in the profile, the Xcode account lost), 80
that the Mac stayed locked.

On the iPad: open the Cockpit's /builds page and install the newest `grabber-<sha>.ipa`. How the page offers the
install is the Cockpit's side (igor2), not this repo's. *Unverified here: the install from the page.*

## Every install lands on /builds

Stories 1634–1637 and 1639 ([spec](superpowers/specs/2026-11-22-ota-builds-design.md), "Every install lands on /builds"). After
`just deploy` (BugKit's `deploy-all.sh`) or `just native-run-device` installs a build, BugKit's `ota-upload.sh` copies
that very bundle to the Cockpit's builds folder as `grabber-<sha8>.ipa`, in the background: the install and the launch
don't wait, and a failed copy never fails them. It reads the commit from the bundle (`-dirty` when built from
uncommitted changes), touches rather than copies a commit already there, and logs each outcome to
`~/tmp/agent/notes/ota-uploads.log`. The destination is `"ota"` in `~/.config/bug-kit/apps.json` (the app's
`ota_name`, `grabber`, names the file); `OTA_UPLOAD=0` turns it off. It is BugKit's (bug-kit bead `bug-a5y`, docs/ops/deploying.md
"Over the air"), so it does nothing until `~/gits/bug-kit` has the script. This copy is the Debug build the devices
run; `just ota`'s is Release.

## After each merge batch: `just ota-watch`

`just ota-watch` (story 1029) polls origin/main every minute. When main has merges since the last build and then ten
minutes pass with no newer merge (a batch), it runs `just ota` and posts to Igor's Cockpit thread
(`larry post --thread igor2-88g.1620 --id cc-ota-<sha>`):

> New build on /builds: 2.0.0 (2990) 1a2b3c4d, with: #1232 feat(native): …; #1231 fix(native): …

- It runs in the foreground; the lead keeps it running as a background task. There is no LaunchAgent.
- The last commit built is in `~/tmp/agent/ota-last-sha`, so a restart neither rebuilds nor skips a batch. With no
  such file it starts from main as it is and builds from the next batch. If the post fails, the watcher retries the
  saved announcement at the next poll, even after a restart.
- The batch is judged on the merges' commit times, so a watcher started after a batch builds it on its first poll.
- OTA busy, main advanced before build selection, or the Mac locked (75, 80): tried again at the next poll.
  Other build failures stop the watcher and report the reason in its local output.

## Signing

- **Automatic signing, no API key.** `project.yml` sets the team and `CODE_SIGN_STYLE: Automatic`. The only credential is
  the Apple ID signed into Xcode (Settings, Accounts). Profiles are cached in
  `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`; a build whose cached profiles already cover the device
  and the entitlements signs offline.
- **One signing build at a time** on the Mac, across every app and agent: `~/tmp/agent/locks/xcode-signing.lock`, taken
  by `native-build-device`, `testflight`, `ota`'s export and `deploy-all.sh`. Don't wrap a recipe in a second `lockf` on it.
- **Never sign while the Mac is locked.** A provisioning build on a locked Mac is what made Xcode drop the account
  (bug-kit#53). BugKit's `signing-guard.sh`, inside the lock, waits up to two minutes for an unlock, then exits 80 with
  nothing built; it holds the display awake during the build. It turns *No Accounts* or *Failed to load credentials*
  into exit 78: stop, tell Igor, never retry. He signs in again at Xcode, Settings, Accounts, and the next signing
  build runs first and alone.

## Renewing the profile

Development provisioning profiles, and the Apple Development certificate that signs them, last a year. The current
profiles expire on 2027-11-20 (`just ota --check-ipa` on a recent package, or `just ota`'s output, says the date).
A build already installed stops launching once its profile expires.

What to do, before the date: with the Mac unlocked and Xcode's account signed in, run one signing build first and
alone (`just ota` or `just native-build-device`). Its `-allowProvisioningUpdates` lets Xcode fetch a new profile (and a
new certificate if that has expired too). Then build and install again on each device, since an installed app keeps
the profile it was built with. Check with `just ota --check-ipa` that the new expiry is a year out. If the build fails
with *No Accounts*, sign in at Xcode, Settings, Accounts first. Don't delete the cached profiles while the account is
unreliable. *Unverified here: a renewal itself; the first one is due 2027-11.*

## Adding a device

1. Find it in `xcrun devicectl list devices` (on the cable, trusted, Developer Mode on). Put its UDID in the gitignored
   `scripts/native/ipad-udid.local` or `phone-udid.local`; never in a committed file, a PR or a post.
2. Register it with the team: one build with it as the destination and the account signed in
   (`~/gits/bug-kit/scripts/deploy-all.sh context-grabber --register <device folder>`, or `just native-run-device` with
   `DEVICE=<udid>`, which passes `-allowProvisioningDeviceRegistration`), or add it by hand in the developer account
   (Certificates, Identifiers & Profiles, Devices).
3. Rebuild so the profile picks it up: the next signing build regenerates the team profile with the device in it.
   An over-the-air package made before the registration doesn't list it; `just ota` refuses one that lacks the iPad,
   and `just ota --check-ipa` shows which profiles list it.

## iCloud: development and production

A development-signed build (the cable, deploy-all and the over-the-air package) uses the **development** iCloud
environment: the `9ec60f90` over-the-air package's entitlements say `com.apple.developer.icloud-container-environment =
Development` (read with `codesign -d --entitlements`). So its boards sync with the cable builds, and its shake reports
and crashes reach the Mac's BugKit listener, which reads the development database. A TestFlight or App Store build
uses **production**: its reports don't reach the Mac until BugKit's schema is deployed to production and the Mac has a
production reader, and its boards don't sync with development builds ([TestFlight spec](superpowers/specs/2026-11-20-testflight-lane-design.md),
"One-time setup"). Staying on development builds keeps one database.

## Making it faster

Measured on 2026-11-22 (`9ec60f90`, the logs' times): the App Store export about 29 s, the development export about 25 s.
The archive itself was not timed; `just ota` now records every step in `~/tmp/agent/notes/ota-timings.log`, so the next
runs give the numbers. None of these is done; each would be its own change.

| Change | Saves (estimate) | Cost or risk |
|---|---|---|
| Skip the App Store export in `ota`: archive directly (testflight's archive step without its export) | about 30 s per build (measured) | `ota` no longer doubles as a check that distribution signing works |
| Skip the archive when `native/Build/Archives/<stamp>.xcarchive` for this commit already exists (a rerun after a failed copy, or after `just testflight`) | the whole archive, minutes, on a rerun | must be sure the archive is complete (it is removed before each archive starts) |
| Reuse the over-the-air build for the cable: unzip the package's `Payload/GrabberNative.app` and `devicectl device install app` it, instead of a second Debug build | one whole device build, minutes, when both paths run | the cable then gets a Release build; *unverified that devicectl installs it* |
| Give the *Bundle the stack and voice* build phase its inputs and outputs (Xcode says it runs on every build) | seconds on every build, archives included (unmeasured) | its outputs must be listed completely or a stale bundle ships |
| Archive in Debug for over the air (no optimisation) | perhaps a third of the compile (unmeasured) | not the build TestFlight ships; slower app |
| Incremental archives: keep one derived-data folder for over-the-air builds and never clean it (it is the main checkout's `native/Build` already; confirm in the timing log that a second archive is faster than the first) | most of the compile on a small change (unmeasured) | none, if it holds |
