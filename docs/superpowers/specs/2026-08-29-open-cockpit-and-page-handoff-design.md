# Open Cockpit From a Link, and the Page's Call Button Calls Natively — Design Spec

**Status:** Proposed
**Date:** 2026-08-29
**Owner:** Igor
**Issue:** [#85](https://github.com/idvorkin/context-grabber/issues/85) · bead `context-grabber-7i0`
**Depends on:** [Native call screen](2026-08-28-native-call-screen-design.md), ["Call Larry" in Shortcuts](2026-08-29-call-larry-shortcut-design.md), [Cockpit Tab](2026-08-27-cockpit-tab-design.md)

## Summary

Igor, 2026-08-29 07:58, in a Cockpit note: *"Give me the ability to make a
shortcut that takes me to Cockpit, not just call in Context Grabber, and if
I'm in Context Grabber and I hit the call button from the Cockpit, make it
start a call in the Cockpit, not using the Cockpit API."*

Two small doors, one on each side of the same wall.

**Into the Cockpit.** Today a link can start a call, but nothing can take
Igor to the dashboard itself — the decisions, the PRs, the history. One more
link, `grabber://cockpit`, and one more Shortcut, **Open Cockpit**, beside
**Call Larry**.

**Out of the page.** The Cockpit page has its own call button. Inside the
app that button still runs the *page's* call — the one that dies when the
screen locks. The page is being taught (Cockpit side, `igor2-88g.268`) to
hand off instead: inside the app, its call button opens
`grabber://call?via=<backend>`. This spec is the app's half of the
handshake: a link opened from inside the web view lands on the native Call
tab exactly as a link from a Shortcut does — no detour through iOS, no
"open in Context Grabber?" prompt, no second microphone.

## Goals

- `grabber://cockpit` opens the app on the Cockpit tab, from anywhere a URL
  can be opened.
- **Open Cockpit** is listed in the Shortcuts app under Context Grabber,
  with a ready-made App Shortcut and Siri phrases, like **Call Larry**.
- A `grabber://call` (or `grabber://cockpit`, or any app link) opened by the
  Cockpit page inside the web view is handled by the app directly, in the
  same code path as a Shortcut's link.

## Non-goals

- **Changing the page.** The page's hand-off is Cockpit-side work; this
  spec makes the app ready for it and nothing more.
- **Other Shortcuts.** Grab, timer, reflect stay links.
- **Deep-linking into a Cockpit route** (`grabber://cockpit/calls/…`). One
  link, one tab.

## User-visible behavior

### The link

| Link | Effect |
| --- | --- |
| `grabber://cockpit` | The app opens on the Cockpit tab, mounting the page if this session never opened it |

`com.idvorkin.contextgrabber://cockpit` works identically. Sub-paths and
query strings are ignored. Any card or screen sitting over the tabs (Gym
Timer, a Reflect card, the Journal) is closed first, as every link does.

### The Shortcut

- Shortcuts app → Context Grabber → **Open Cockpit**. No parameters.
- Running it brings the app to the front on the Cockpit tab.
- A pre-built **Open Cockpit** App Shortcut exists beside **Call Larry**;
  Siri: "Open Cockpit in Context Grabber", "Open the Cockpit in Context
  Grabber".

### The page's call button, inside the app

- On the Cockpit tab, tap the page's own call control (once the page's
  hand-off ships): the app switches to the **Call** tab and the call starts
  on the backend the page named — *connecting…* → *live* — with no prompt
  and no visible detour. The web view does not navigate anywhere; the
  Cockpit is exactly where Igor left it when he comes back to the tab.
- If a call is already live natively, the tab switches and the call
  continues; no second call.
- The rule that refuses a native call while the *page* has one live is
  unchanged — a page that hands off never starts its own, so it never
  trips it.
- Any other app link the page opens (`grabber://cockpit`,
  `grabber://timer?…`) is handled the same way: in the app, on the spot.
  Links to other hosts still go to Safari, as today.

**The page's ☎︎ while the app's own call is live**
([#99](https://github.com/idvorkin/context-grabber/issues/99)). Igor,
2026-08-29 11:48: *"If I'm in Context Grabber and I hit call, that should
probably jump me to the Call tab. If I'm in an active call and I'm in the
Cockpit, that should take me to the Call tab. 100%."* The Cockpit's
masthead ☎︎ knows when a call is live elsewhere; inside the app, when that
call is the app's native one, tapping it does not dial — the page tells
the app *focus the call*, and the app switches to the **Call** tab, timer
still running, exactly as if the tab had been tapped. A page that instead
says *start a call* while the native call is live gets the same: the Call
tab, no second dial. When no call is live, *start a call* dials on the
backend the page names (or the remembered one), the same as the
`grabber://call` link.

## Acceptance criteria

1. `grabber://cockpit` from a Shortcut with the app closed: the app opens
   on the Cockpit tab with the page loading. From another tab with the app
   open: switches to Cockpit. With the Gym Timer showing: the timer closes,
   Cockpit shows.
2. Shortcuts app → search "Open Cockpit" → listed under Context Grabber; a
   shortcut of that one action opens the app on the Cockpit tab.
3. The pre-built **Open Cockpit** App Shortcut appears in Context Grabber's
   section next to **Call Larry**; "Hey Siri, Open Cockpit in Context
   Grabber" runs it.
4. In the Cockpit web view, a page element that opens
   `grabber://call?via=eleven`: the app switches to the Call tab and the
   call is *connecting… ElevenLabs* → *live*; no iOS prompt; returning to
   the Cockpit tab finds the page unchanged (not navigated, not reloaded).
5. Same with a native call already live: Call tab, timer not reset, one
   `start` on the bridge.
6. In the web view, a link to `https://github.com/…` still opens Safari.
7. **Call Larry** and every existing link are unchanged.
8. With a native call live, switch to the Cockpit tab and tap the page's
   ☎︎: the app is on the Call tab within a beat, the timer has not reset,
   and the bridge saw no second `start`. The page did not navigate.
9. With no call live, the page's *start a call* (naming ElevenLabs) puts
   the app on the Call tab *calling Larry… · ElevenLabs* → *live*; naming
   nothing dials on the remembered backend.

## Rationale and risks

The web view already intercepts every navigation to keep the tab pinned to
the Cockpit host; anything else is handed to the system. Handing the app's
*own* links to the system would work — iOS reopens the app and delivers the
URL — but it is a visible round trip, and on some iOS versions a confirmation
sheet. Routing them in-process is one branch in the interceptor and reuses
the deep-link handler as is, so a link from the page and a link from a
Shortcut can never drift apart.

Risk: the page must open the link as a *navigation* (`location.href`, an
`<a href>`), which the interceptor sees; `window.open` from a page can be
swallowed with multiple windows disabled. The Cockpit-side change should
use a plain navigation; criterion 4 is the check.
