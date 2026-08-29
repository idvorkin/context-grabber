# Start a Larry Call From a Link — Design Spec

**Status:** Proposed
**Date:** 2026-08-28
**Owner:** Igor
**Issue:** [#75](https://github.com/idvorkin/context-grabber/issues/75) (phase 1) · bead `context-grabber` (call deep link)
**Depends on:** [Cockpit Tab](2026-08-27-cockpit-tab-design.md), [Cockpit Audio Bridge](2026-08-28-cockpit-audio-bridge-design.md)

## Summary

Igor, on a call, 2026-08-28 09:40: *"can I get shortcut actions so that I can
launch shortcuts directly into starting the call?"*

Starting a call with Larry today is: unlock, find Context Grabber, tap
Cockpit, wait for the page, tap Call, tap the handset. Six steps between the
thought and the conversation.

This adds one link that does all of it. Opening
`com.idvorkin.contextgrabber://call` (or `grabber://call`) — from a Siri
Shortcut, the Action Button, a Home Screen shortcut, a widget, anything that
can open a URL — brings the app to the Cockpit tab and the call starts. An
optional `via` names the backend: `grabber://call?via=eleven`.

This is phase 1 of #75. Phase 2 — a proper "Call Larry" App Intent that shows
up in the Shortcuts app by name and takes parameters — is a separate spec.

## Goals

- One action from anywhere on the phone to a live call with Larry.
- The backend can be chosen in the link, so "Call Larry (Gemini)" and "Drill
  me" can be two different shortcuts.
- Works whether the app is closed, in the background, or already on another
  tab — and whether or not the Cockpit page is already loaded.
- Never starts a second call. If one is live, the link brings Igor to it.

## Non-goals

- **An App Intent / Shortcuts action by name.** Phase 2.
- **A native call screen.** The call runs in the Cockpit page exactly as it
  does when started by hand. See #74. *(Superseded 2026-08-28: the
  [native Call tab](2026-08-28-native-call-screen-design.md) now receives
  `grabber://call`; the link's syntax and rules below are unchanged.)*
- **Hanging up from a link.** Ending a call stays a tap on the page.
- **Any other Cockpit route.** `…://call` is the only new link; opening the
  Cockpit tab without a call is not a link, deliberately — the tab is one tap
  away and a link that opens a tab is a link Igor has to remember for nothing.

## User-visible behavior

### The link

| Link | Effect |
| --- | --- |
| `grabber://call` | Cockpit tab, call starts on the page's current backend |
| `grabber://call?via=eleven` | …on ElevenLabs |
| `grabber://call?via=gemini` | …on Gemini Live |
| `grabber://call?via=openai` | …on OpenAI Realtime |
| `grabber://call?via=drill` | …the memdeck Drill |

`com.idvorkin.contextgrabber://` works identically to `grabber://`. A `via`
that names nothing the page offers is ignored: the call still starts, on the
page's current backend.

### What Igor sees

1. He triggers the shortcut. The app comes to the front on the Cockpit tab —
   whichever tab it was on before, whether it was running or not.
2. The Cockpit page shows its Call tab and the call starts, the same way it
   does when he taps the handset in the page's top bar: the state line moves
   from *ready* to *connecting* to *live · listening*, the confirmer names the
   microphone and output in use.
3. He talks.

If the backend in the link differs from the page's current pick, the page
switches to it first, and that becomes the page's pick — the same as choosing
it in the dropdown.

### When the page is not there yet

Cold start, or the Cockpit tab never opened this session: the tab shows its
loading state, then the page, then the call starts — with no further tap. The
link is not lost while the page loads.

### When a call is already live

The app goes to the Cockpit tab and the page goes to the live call. Nothing is
restarted, nothing is hung up, the backend in the link is ignored. Same rule
as tapping the handset mid-call.

### When the call cannot start

- **Off the tailnet / Cockpit unreachable:** the tab shows its existing
  "Can't reach the Cockpit" pane. The link is consumed — a later successful
  reload does not start a call Igor asked for minutes ago.
- **Microphone not granted:** the page lands on the Call tab and shows the
  same explanation it shows for a handset tap without a microphone. No call.
- **The engine refuses to start audio without a tap:** the page lands on the
  Call tab with the backend from the link selected and says what to do —
  one tap on the handset starts it. This is the honest fallback, not the
  design; see *Risks*.

### Repeated links

Triggering the shortcut twice in a row starts one call (the second lands on
the live one). A link opened while the previous one is still connecting is
ignored.

## Acceptance criteria

1. App closed. Run a Shortcut whose only action is *Open URL*
   `grabber://call?via=eleven`. Within a few seconds of the page appearing the
   Call tab reads *live · listening* on ElevenLabs, with no tap on the phone.
2. App open on the Today tab, Cockpit never opened this session. Same link:
   the app switches to Cockpit, loads, and the call starts on its own.
3. App open on the Cockpit tab, page loaded, no call. Same link: the call
   starts on its own.
4. Call already live on Gemini. Link with `via=eleven`: the app shows the
   live Gemini call. It is not restarted and not switched.
5. `grabber://call?via=nonsense`: the call starts on the page's current
   backend.
6. `com.idvorkin.contextgrabber://call` behaves exactly as `grabber://call`.
7. Tailscale off. `grabber://call`: the "Can't reach the Cockpit" pane. Turn
   Tailscale on and tap *Try again*: the page loads and **no** call starts.
8. Every existing link (`timer`, `grab`, `reflect/…`, `counter/inc`) behaves
   exactly as before.
9. In Safari on the laptop the Cockpit page is byte-for-byte what it was:
   nothing in this spec runs outside the app.

## Rationale and risks

**Why a link, not a native button.** A link is what Shortcuts, the Action
Button, widgets and Live Activities already know how to open, and the app
already routes links for the timer and the reflect cards. The same mechanism
carries phase 2: an App Intent is a nicer front door to the same hallway.

**Why the call starts on the page.** The call *is* the page — its socket, its
captions, its backend picker, its confirmer. Starting it from the app means
asking the page to press its own handset, so every rule the handset already
enforces (no second call, no call without a microphone, the audio bridge's
device picks) holds for a link without being re-implemented.

**Risk: the audio engine wants a tap.** In Safari, audio may only start inside
a user gesture, and the page's handset is built around that. The app's web
view is configured to allow playback without a gesture, so a call started by
the app is expected to work — but this is exactly the kind of thing only a
real phone proves. Acceptance criterion 1 is the test; the *engine refuses*
fallback above is what ships if it fails, and #74 (native call screen) is the
real fix.

**Risk: a stale link starting a call later.** A link kept "pending" through a
failed load could start a call an hour later when the page finally comes up.
The rule that the link is consumed by a failed load exists for this.

**Ships as an over-the-air update** plus a Cockpit page change. Nothing native.
