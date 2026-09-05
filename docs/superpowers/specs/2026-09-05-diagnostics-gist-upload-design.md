# Diagnostics That Reach Larry — Gist Upload Design Spec

**Status:** Drafted 2026-09-05
**Owner:** Igor
**Issue:** [#92](https://github.com/idvorkin/context-grabber/issues/92) (the gist path), [#95](https://github.com/idvorkin/context-grabber/issues/95) (why it matters)
**Extends:** [Native Call Screen](2026-08-28-native-call-screen-design.md) — *Diagnostics*

## Summary

Igor, 2026-09-05: *"Do we have a continuous log that we can upload if we
have problems? Like send to gist, and we should store a private gist
key … and maybe have some direction in there to be like go erase the gist
once you've processed it."*

The call keeps a continuous log on the phone — every call it has room
for, written to disk as it happens, recovered across launches — and sends
it to the bridge at every hang-up. But the bridge does not file it (the
bridge half of #92 was never built), so a bad call still ends with Igor
copying a dump into a chat. This spec gives the log a way out that needs
nothing on the bridge: **a private GitHub gist**, created by the phone,
one per upload, with the URL on the clipboard and a note at the top
telling whoever reads it to delete it when they are done.

## Goals

- After a call that went wrong, the evidence is somewhere Larry can read
  without Igor pasting anything: a URL, on the clipboard, seconds later.
- A tap uploads at any time, whether or not the call looked wrong.
- Nothing accumulates: every gist says "delete me when processed", and
  the app can delete what it uploaded.
- The token lives in the phone's Keychain, not in a table.

## Non-goals

- Replacing the bridge path. The hang-up dump to the bridge stays; when the
  bridge learns to file it, the gist is the fallback, not the default.
- A rolling, always-current gist at a stable URL. That would be a
  permanently live copy of Igor's call transcripts; per-upload gists that
  get deleted are the deliberate choice.
- Uploading anything but the call log. Health and location exports have
  their own share sheet.
- Retrying a failed upload on its own. A failure is shown; the next tap
  or the next troubled call tries again.

## User-visible behavior

### The token, once

Settings gains a **Diagnostics uploads** section with one field, *GitHub
token*, masked. It takes a classic personal access token with only the
`gist` scope — the section says so, and says that fine-grained tokens
cannot create gists. Once a token is saved the section shows *token
saved* (never the token), an **Upload after a troubled call** switch (on
by default once a token exists), the last upload's link with a copy
button, and **Delete uploaded diagnostics (N)**. With no token, the rest of
the section is folded away behind the field, and nothing anywhere else in
the app mentions uploading.

The token is stored in the iOS Keychain, readable by this app only,
available after the phone's first unlock so an upload at the end of a
locked-screen call still works. Clearing the field forgets it.

### Uploading

**On demand.** Beside *Copy diagnostics* in the Call tab's Diagnostics
fold, an **Upload** button (only when a token is saved). Tap: the whole
log — every call it holds, the same text *Copy diagnostics* copies, with
the same build/state/route header — becomes a **secret gist** on Igor's
account, the button reads *Uploaded* for a moment, the gist's URL is on
the clipboard, and a line in the log says so (*uploaded →
https://gist.github.com/…*). The URL is also shown under the buttons,
copyable, until the next upload replaces it.

**After a troubled call.** With the switch on, when a call ends and its
log shows trouble — the audio healed itself (a re-arm, a reset, a
redial, a reopened output), a problem was on screen (mic not reaching
Larry, audio not arriving, not playing, delivering silence), or the
ending was bad (connection lost, vendor closed) — the app uploads on its
own, without a tap, and puts the URL on the clipboard so the next paste
into Telegram is the link. A clean call uploads nothing. The trigger is
what the log *says*, so anything new the log learns to say is covered.

**What the gist holds.** One file, `call-log.txt`, described as *Context
Grabber call diagnostics · <date time> · <why>* where *why* is the
reason (*troubled call*, *upload requested*). The file opens with a
short note for the reader:

> This is Igor's phone's call log, uploaded by Context Grabber. It
> contains call transcripts and device details. **Delete this gist once
> you have processed it** — `gh gist delete <id>`. It is one of several;
> the app can also delete everything it uploaded from Settings.

then the header (build, state, ended, problem, route, upload reason) and
the log.

**When it cannot upload.** No network, a rejected token, GitHub down:
the button reads *Upload failed*, the reason is a copyable error under
the buttons (*GitHub said 401: Bad credentials*), the log has the line,
and nothing else changes. An automatic upload that fails is a line in
the log and nothing on screen — the call is over; the next troubled
call tries again.

### Cleaning up

The app remembers what it uploaded. **Delete uploaded diagnostics (N)**
in Settings deletes every gist it created, one request each, and
reports *deleted N* (or *deleted 3 of 5 — 2 already gone*, which is fine:
a gist the reader deleted first is the intended outcome). On every
upload the app also deletes its oldest gists beyond the ten most recent,
so a bad week cannot pile up a hundred. Deleting is only ever of gists
this app created; it never lists or touches anything else on the
account.

## Acceptance criteria

1. **Token.** Settings → *Diagnostics uploads*: paste a classic token with
   the `gist` scope, leave the field: the section shows *token saved*,
   the switch (on), no last upload, *Delete uploaded diagnostics (0)*.
   Kill and relaunch the app: still saved. Clear the field: everything
   but the field folds away; the Call tab's Diagnostics fold shows no
   *Upload* button.
2. **Upload on demand.** With a token, after any call, Diagnostics →
   **Upload**: within a few seconds the button reads *Uploaded*, the URL
   is on the clipboard, a *uploaded → …* line is in the log, and the URL
   shows under the buttons. Open it on a laptop: a secret gist, one file,
   the note at the top, then the same text *Copy diagnostics* gives.
3. **Auto after trouble.** Switch on. Force a troubled call (kill the
   bridge mid-call → *connection lost*): as the call ends the app
   uploads on its own; the clipboard holds the URL; Settings shows it as
   the last upload. Then a clean call (say hello, hang up): no new gist.
4. **Auto off.** Switch off: a troubled call uploads nothing; the
   *Upload* button still works.
5. **Failure.** Wi-Fi off, Upload: *Upload failed* and a copyable reason
   naming the network; nothing on the clipboard. Wrong token: *GitHub
   said 401 …*.
6. **Delete.** After three uploads, delete one of them on the laptop, then
   Settings → *Delete uploaded diagnostics (3)*: *deleted 2 of 3 — 1
   already gone*; the count reads 0; the two are gone from GitHub.
7. **Cap.** After twelve uploads without deleting, GitHub holds ten from
   the app, the newest ten.
8. **Nothing leaks.** The token never appears in the log, in the gist, in
   a copied error, or in Settings after it is saved. The log's dump to
   the bridge is unchanged.

## Rationale and risks

**Why a gist and not the bridge.** The bridge path is the right one and
it is not there; a gist needs nothing but a token and GitHub, which
Igor already has. When the bridge learns to file the hang-up dump the
gist stays useful for the day the bridge itself is what is broken.

**Why per-upload, deleted after.** A single rolling gist at a stable URL
would be convenient for Larry and a permanently live copy of every call
Igor has made. Secret gists are unlisted, not private: anyone with the
URL can read them. Short-lived, deleted-when-read is the honest shape,
and the app keeping its own list means nothing depends on the reader
remembering.

**Why the Keychain.** A gist-only classic token can create, edit, and
delete every gist on Igor's account and read his secret ones. That is
small, but it is a GitHub credential; it goes where iOS keeps
credentials, not in the settings table beside the retention days.
Adding the Keychain module is a native change: this ships with a device
build, not over the air.

**Risks.** A token with more than the `gist` scope pasted by mistake
would give the phone more than it needs — the section says which scope
and nothing checks it. Automatic uploads put a URL on the clipboard
without a tap; Igor asked for exactly that, and the switch turns it off.
