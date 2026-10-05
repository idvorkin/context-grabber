# The Cockpit in Grabber Native — Design Spec

**Status:** Drafted 2026-10-05
**Owner:** Igor
**Part of:** [Swift-native app](2026-10-04-swift-native-app-design.md), step 7 — *"The Cockpit tab: critical. It is
ported, with real microphones and outputs."*
**Ports:** [Cockpit Tab](2026-08-27-cockpit-tab-design.md), [Cockpit Audio Bridge](2026-08-28-cockpit-audio-bridge-design.md),
[Keep Awake](2026-08-28-cockpit-keep-awake-design.md), [Open Cockpit and the page's hand-off](2026-08-29-open-cockpit-and-page-handoff-design.md)
**Stories:** 096, 097, 098 (native lines), 200 (new)

## Summary

The Cockpit — Igor's tailnet-only decision dashboard — opens inside Grabber Native the way it opens inside Context
Grabber: the page itself, not a re-implementation, with the phone's real microphones and outputs handed to its
pickers. The page needs no change: it finds the same bridge, speaks the same messages, and is told it is in the
app by the same tag on its address.

## What is the same as Context Grabber

Everything the four specs above promise, with the tab replaced by a screen:

- **The page, whole.** Every surface of the Cockpit, scrolling, typing, expanding rows, swiping back through its
  own history. Pull down at the top to reload.
- **Voice.** The page's microphone works. iOS asks once for Grabber Native's microphone (it is a separate app until
  the cutover, so it asks even though Context Grabber already has it). The microphone is granted to the Cockpit
  itself without a second prompt; any other site asking inside the screen gets iOS's prompt. Audio plays inline and
  starts without an extra tap.
- **Real microphones and outputs.** The page's pickers list every microphone iOS can see, by name, and Automatic,
  Speaker and any connected headset as outputs; a choice takes effect mid-call; what is really carrying audio is
  reported; AirPods arriving or leaving update the pickers without a reload; a choice the phone undoes underneath
  (the page's own capture starting is the usual cause) is put back. Every request the page makes gets exactly one
  answer. Wire protocol unchanged: [cockpit-audio-bridge.md](../../cockpit-audio-bridge.md).
- **The page knows it is in the app.** Its address carries `client=context-grabber` and the build. The native app
  says *context-grabber* too: it becomes Context Grabber at the cutover, and the build already tells the two apart
  (a native build is a commit of the native app). The pickers keep their per-app memory for the same reason: the
  page stores the app's picks apart from the laptop browser's, and both apps are "the app".
- **Links that leave the Cockpit** open in the phone's browser; the Cockpit stays where it was.
- **Can't connect** — Tailscale off, no network, the serving machine asleep, or a server error: a panel saying
  *Can't reach the Cockpit*, the hint to check Tailscale and the machine, the address tried, **Try again**, and the
  error itself with a **Copy error** button that carries the error, the address and the build. Never a blank page.
  A web page that crashes in the background is reloaded rather than left empty.
- **The screen stays awake while a call is live in the page** — from the page saying the call is starting until it
  says it ended, or the page goes away (reload, failure, a crash). With no call, the Cockpit locks on the phone's
  normal schedule. A function of the call, not of the screen being open.

## What differs

- **A screen, not a tab.** The native app has a home screen while journeys move over; *Cockpit* is a row on it.
  It opens full screen. There is still no header: a slim footer carries **Done**, which returns home — the native
  app's equivalent of "just the footer is fine".
- **Leaving keeps the page.** *Done* hides the Cockpit; it does not close it. Opening it again in the same launch
  shows the dashboard exactly as it was — scroll, expanded rows, a recording in progress — with no reload, as
  switching tabs did. A new launch loads it fresh.
- **The page's call button, until the call moves.** Inside the app the page's ☎ hands the call to the app. Until
  the native Call screen exists, Grabber Native passes that hand-off to iOS, which opens Context Grabber's Call
  tab — the call that survives the lock. When the native call lands, the hand-off stays in Grabber Native.
- **The audio session.** Opening the Cockpit readies the phone's audio for recording, as the tab's first visit did.
  If the Gym Timer has since set the audio its own way, the next opening readies it again; otherwise opening the
  Cockpit leaves the audio alone.
- **Everything it does is in the session log** — each load and how long it took or why it failed, each bridge
  message both ways, the roster and route each time it is sent — so a shake from the Cockpit attaches the evidence.

## Non-goals

- `grabber://cockpit` and the *Open Cockpit* Shortcut. They wait for the rest of step 7, when links open the native
  app.
- Any change to the Cockpit page or to the bridge protocol.
- A native picker, a native call inside the Cockpit, offline copies of the dashboard, stored credentials.

## Acceptance criteria

1. The home screen has a **Cockpit** row; it opens the dashboard full screen with a footer **Done** and no header.
2. Done, then Cockpit again in the same launch: same scroll position and expanded rows, no loading flash.
3. With AirPods connected, the page's microphone picker lists the iPhone microphone and the AirPods by name, and its
   output picker offers Automatic, Speaker and the AirPods; choosing Speaker mid-call moves the audio within a second.
4. The page's address carries `client=context-grabber&v=<the native build>`.
5. Off the tailnet: the *Can't reach the Cockpit* panel with the address, the error, Copy error and Try again; with
   Tailscale back, Try again loads the page without restarting the app.
6. A live call in the page keeps the screen lit past the auto-lock interval; with no call the screen locks.
7. An off-Cockpit link opens Safari and leaves the dashboard in place.
8. The session log of a launch that opened the Cockpit shows the load (ok and milliseconds, or the error), the
   bridge's `audio.ready`, each request and its answer, and the device roster.
9. On the simulator, a test page speaking the bridge receives a device list with at least one microphone, and its
   address carries the client tag.
