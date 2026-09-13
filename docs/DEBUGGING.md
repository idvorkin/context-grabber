# Debugging and logging

The app explains itself through its logs and its copyable errors; a symptom that is not in a log gets a log line
before it gets a theory. This file says what the logs hold, how to get them off the phone, and how a bug goes from
Igor's phone to a closed issue. The test rungs are in [TESTING.md](TESTING.md); the spec is the
[user stories](stories/README.md).

## The logs

| Log | What it holds | How it reaches the Mac |
|---|---|---|
| **The call log** (`lib/callLog.ts`) | ~900 timestamped lines written by the call session, the audio layer and the Call screen: the socket, the mic as it is armed (other audio, route inputs, session shape), playback, heals and resets, captions, the ending; a separator between calls; the previous run recovered from disk under its own header, so a freeze loses nothing | The Call tab's **Diagnostics** fold: *Copy diagnostics* puts the whole log on the clipboard under a header (build, state, route); *Upload* makes a **private gist** and puts its URL on the clipboard and under the buttons. After a troubled call the upload is automatic when the switch in Settings → Diagnostics uploads is on. The app keeps the last 10 gists and retires older ones; every gist opens with a note to delete it once processed. The token (classic, `gist` scope) lives in the Keychain. Spec: `superpowers/specs/2026-09-05-diagnostics-gist-upload-design.md` |
| **The timer log** (`lib/gym/timerLog.ts`) | 300 lines: the audio session's options and activation, the keepalive loop, each duck window, every cue (loaded, requested, failed), phase transitions with the round | The **Log** button in the Gym Timer's header copies it with a build / mode / preset header |
| **Copyable errors** (`components/CopyableError.tsx`) | every user-visible error, with *Copy error*: `where:` the screen and operation, `error:`, `build:` sha and branch, then any `extra` fields the caller passed (the state at the time) | the clipboard |
| **About** | the running build: git sha, branch and commit message baked at build time; the OTA update id, channel and time; *Check for updates* | the eye; the commit message is the same one `git log` shows |

Native `NSLog` never reaches Igor's phone screen; a native module that has something to say pushes it through the
JavaScript log (the audio-route module's route-change events do).

```bash
gh gist view <id> --raw | less          # an uploaded call log (Igor's account)
gh gist list --limit 10                  # the uploads still standing
grep -n -E 'heal|reset|redial|FAILED|lost' call.log
```

Header lines say which build the evidence came from; match them against `git log` before reading anything else — a
log from a build before the fix proves nothing about the fix.

## Adding a line

`log.add("...")` inside the call (the session, the audio layer and the screen share one `CallLog`);
`timerLog.add("...")` in the timer. Put the deciding numbers in the line, not in prose (`mic armed: inputs=2
route=BuiltInMic other_audio=1`); log a failure once per spell, not once per retry; log the boundary (armed, healed,
ended), not every tick. A screen-level failure is a `CopyableError` with the relevant state in `extra` rather than a
log line — Igor copies it without opening a fold.

## Instrument before theorizing

For any phone-only symptom: add the line that would settle it, ship it (`just ota` for JavaScript, `just deploy` for
native), reproduce, copy or upload, read the numbers, then fix. Never ship a second guessed fix. Examples that paid
off: the mic-arm log of other audio, route inputs and session shape that turned the silent first call from a guess
into #95's evidence (#102); the log mirrored to disk so a freeze while switching microphones lost nothing (#106);
the timer log showing every cue requested and none heard while music was mixed in, which is why the cues are sound
files and not synthesis (2026-09-07).

## Bug reports: from the phone to a closed issue

1. **On the phone**: Igor hits it. He copies the error, copies or uploads the log, or says it in the session. The
   copied payload carries the build line, so nothing needs retyping.
2. **File it**: one GitHub issue per report (`gh issue create`), with the note, the payload or the gist link, the
   build line, and what he was doing. A report that arrives by voice gets an issue too, filed by hand with the same
   evidence, so the trail is complete. Track the work in `bd` when it spans sessions; the issue is where the
   evidence lives and what the commit closes.
3. **Before fixing**: find or write the story in [stories/](stories/README.md) that the report belongs to — a bug gets
   an `Issues:` line, a request becomes a story, no story means the spec has a hole — and, when the behaviour will
   change, re-open the feature's design spec first (spec-first, [AGENTS.md](../AGENTS.md)). Then read the log at
   the moment of the report and put that evidence on the issue as a comment.
4. **Fix on the cheapest rung** that can see it ([TESTING.md](TESTING.md)): a host test that fails first when the
   logic is in `lib/`; a line in the log when it is the phone's. One PR per issue, referencing it.
5. **Ship and close**: `just ota` for JavaScript, `just deploy` for native. Close the issue once the build is on the
   phone (`Fixes #N` in the PR when the verifying rung already ran, otherwise by hand after the OTA landed) with a
   comment saying what was verified where and what Igor should feel; Igor reopens if it is not fixed. Never leave a
   fixed bug open.

## Device tooling

- `just deploy` builds with the committed `DEVELOPMENT_TEAM` and installs over `devicectl`; the CoreDevice UUID is in
  the justfile. A locked phone fails the launch step only; the install is done. If Xcode lost the Apple ID after an
  update, re-add it in Xcode → Settings → Accounts.
- `just ota` leaves the app on the old bundle until the second open; About says which commit is running.
- `.native-build-sha` (gitignored) is the last native build from this Mac; `just ota` diffs the native surface
  against it. No marker means no native build from this machine yet, and the OTA trusts you.
- The gist token is in the Keychain (`expo-secure-store`); a binary built before that module has no upload button.
