# Cockpit Tab — Design Spec

**Status:** Proposed
**Date:** 2026-08-27
**Owner:** Igor

---

## Summary

Add a seventh tab, **Cockpit**, that puts Igor's decision dashboard inside Context
Grabber. The Cockpit is a web app that already runs on Igor's tailnet — open PRs,
active work, and the decision queue where Larry asks Igor questions and Igor
answers them. Today the only way to reach it on the phone is to remember the URL
and open Safari. As a tab it sits one thumb-tap away, next to the health and
roles surfaces it belongs with.

The tab renders the Cockpit itself, not a re-implementation of it. Everything the
Cockpit gains on the server side shows up in the app the next time the tab is
opened, with no app release. That includes the Cockpit's voice input — talking to
Larry from the Cockpit works inside the tab the same way it works in Safari.

## Goals

- **One tap to the decision queue.** Igor opens Context Grabber, taps Cockpit,
  and answers whatever Larry is waiting on — without leaving the app or typing
  a URL.
- **The whole Cockpit, not a summary.** Every surface the web app has is
  available: decisions, open PRs, active work, refresh.
- **Voice works.** Pressing the Cockpit's microphone control asks for the
  microphone through iOS's own permission prompt and then records. No separate
  in-app recorder, no custom permission screen.
- **Ships without app releases.** Cockpit changes are server-side; the tab
  picks them up on the next load.
- **Fails legibly.** Off the tailnet, the tab explains what's wrong and how to
  fix it. It never shows a blank white rectangle.

## Non-goals

- **No login, no tokens, no in-app auth.** Reaching the Cockpit at all requires
  being on Igor's tailnet; that is the authentication story. The app adds nothing.
- **No offline mode and no caching.** With no connectivity the tab shows the
  reconnect message. It does not stash a stale copy of the dashboard.
- **No native re-implementation.** Nothing about the Cockpit's contents is
  modelled in the app — no decision list, no PR rows, no local database.
- **No general-purpose browser.** The tab shows the Cockpit. Links that lead off
  it (a GitHub PR, say) hand off to the phone's browser rather than turning this
  tab into a browsing session.
- **No change to the other six tabs.** Today, Body, Move, Mind, Places, and Roles
  behave exactly as before, and the app still opens on Today.

---

## User-visible behavior

### The tab

A seventh entry appears in the tab bar, labelled **Cockpit**, in last position
after Roles. It looks and behaves like the other tabs: tap to switch, the icon and
label light up when active.

### Loading

Tapping Cockpit for the first time in a session shows a brief loading state — a
spinner over the app's dark background with the word "Cockpit" — and then the
dashboard fills the screen above the tab bar. Subsequent taps return to the
dashboard exactly as it was left: same scroll position, same expanded rows, no
reload flash, and any recording or playback in progress keeps going. Leaving the
tab does not throw the page away.

### Interacting

The dashboard is fully interactive: scrolling, tapping, expanding rows, typing
into its fields, answering a decision. Swiping from the left edge goes back
within the Cockpit's own history, the way it does in Safari.

### Refreshing

One way, native:

- **Pull down** at the top of the dashboard to reload it.

There is no header bar. Igor, 2026-08-29: *"When I'm on the cockpit page, I
don't need a header. Just the footer is fine."* The tab bar says where you
are; the dashboard gets the whole height above it, clear of the status bar.
(A reload control with a "Cockpit" title used to sit at the top — removed.)

Reloading re-fetches the page from the server; it does not clear any app state.

### Voice

The Cockpit's own microphone control works. The first time it is used, iOS shows
its standard microphone permission alert for Context Grabber; if Igor has already
granted the microphone (for the app's affirmation and gratitude voice notes), no
new prompt appears. After that, the Cockpit records and plays back inline — audio
plays in place, without iOS taking over the screen with a full-screen player, and
without requiring an extra tap to start playback.

The microphone is granted only to the Cockpit itself. If some page on another
host ever asks for the microphone or camera inside this tab, iOS prompts rather
than silently granting.

### Links that leave the Cockpit

Tapping a link that points somewhere other than the Cockpit — a GitHub pull
request, an external article — opens it in the phone's default browser. The
Cockpit tab stays where it was, so coming back to the app returns to the
dashboard rather than to a stranded page.

### When it can't connect

If the Cockpit can't be reached — Tailscale is off, the phone has no internet, the
machine serving the Cockpit is down — the tab shows a plain, friendly panel
instead of the dashboard:

- A short headline naming the likely cause ("Can't reach the Cockpit").
- One line of guidance: check that Tailscale is connected and the machine serving
  the Cockpit is awake.
- The address it tried.
- A **Try again** button that retries the load.
- The underlying error, rendered through the app's standard copyable-error
  control so it can be pasted into a chat with Larry.

The same panel appears for a server error response, not just a network failure.

If the web content crashes out from under the tab (iOS reclaiming memory in the
background is the usual cause), the tab reloads itself rather than leaving an
empty rectangle behind.

---

## Acceptance criteria

1. The tab bar shows seven tabs, with **Cockpit** last, and the app still opens
   on **Today**.
2. Tapping Cockpit loads the dashboard; the other six tabs are unchanged.
3. Switching away from Cockpit and back does not reload the page — scroll
   position and expanded state survive.
4. Pull-to-refresh reloads the dashboard. There is no header bar above the
   page; the page starts below the status bar and runs to the tab bar.
5. Using the Cockpit's microphone control triggers iOS's own microphone prompt
   (once, app-wide) and then records; no in-app permission UI is involved.
6. Audio inside the Cockpit plays inline and starts without an extra tap.
7. Tapping an off-Cockpit link opens the system browser and leaves the tab in
   place.
8. With Tailscale disabled, the tab shows the reconnect panel — never a blank
   view — and **Try again** succeeds once Tailscale is back on, without
   restarting the app.
9. No credentials, tokens, or cookies are stored by the app for the Cockpit.

## Rationale and risks

**Why a web view rather than a native port.** The Cockpit is a fast-moving
personal dashboard; it changes several times a week. Porting it natively would
mean an app release per change and two implementations to keep honest. Embedding
it means the app is only responsible for the frame — the tab, the reload, the
microphone handoff, and the failure message.

**Why the microphone is handled by iOS.** The system already owns this decision
and already has an answer for Context Grabber, which records voice notes today.
Adding a second, app-drawn permission flow would be a worse experience and a
second thing to get wrong.

**Why no offline story.** The Cockpit is only reachable on the tailnet in the
first place, so a cached copy would be stale by construction and would invite
Igor to act on a decision list that no longer exists. Showing the reconnect
message is the honest failure.

**New native dependency.** Rendering web content requires a native module the app
does not have today, so the first build carrying this tab has to be a full
install — an over-the-air update cannot deliver it. Later Cockpit changes need no
build at all, which is the point.
