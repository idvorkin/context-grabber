# A Call That Survives the Lock — Native Call Screen Design Spec

**Status:** Implemented (phase 1) — on-device acceptance pending
**Date:** 2026-08-28
**Owner:** Igor
**Issue:** [#74](https://github.com/idvorkin/context-grabber/issues/74) (this) · subsumes [#73](https://github.com/idvorkin/context-grabber/issues/73) · bead `context-grabber-e19`
**Depends on:** [Cockpit Tab](2026-08-27-cockpit-tab-design.md), [Cockpit Audio Bridge](2026-08-28-cockpit-audio-bridge-design.md)
**Changes:** [Call deep link](2026-08-28-cockpit-call-deep-link-design.md) — `grabber://call` now lands here, not on the Cockpit page

## Summary

Igor, on a call, 2026-08-28 09:40: *"I want to be able to do in Context
Grabber a native UI for calling, so it doesn't have to be in a web view.
Basically, instead of Cockpit, I just have the calling tab, and I want it to
be native so that when my phone locks, the call can keep going."* And later,
on how: *"I'm assuming you just use the backend services, or expose backend
services, and make another UI on top of Cockpit."*

That assumption is right, and it is the whole design. A Larry call is one
socket to the voice bridge: microphone audio goes up, Larry's voice comes
down, and a handful of small messages describe what is happening — captions,
"Larry interrupted", "the call ended because…". Everything that makes it a
*conversation* — who is speaking, when a turn ends, "hang up" meaning hang
up, the two-minute idle rule, Larry's memory and tools — lives on the
server. The Cockpit page contributes exactly three things: it opens the
microphone, it plays the audio without gaps, and it draws the captions.

Today those three things run inside a web view, and iOS suspends a web
view's microphone the moment the screen locks. The call dies mid-sentence.
Keeping the screen awake ([#72](https://github.com/idvorkin/context-grabber/issues/72))
papers over it; a deliberate lock, a pocket, a Siri interruption still kill
the call.

This spec moves those three things into the app itself. A new **Call** tab
does what the Cockpit's Call tab does, against the same bridge, with no web
page in the loop — and because the app owns the audio, iOS treats it like a
phone call: the screen can lock, the phone can go in a pocket, and Larry
keeps talking.

## Goals

- A call keeps going through a screen lock, the app going to the
  background, and the phone being put down — for as long as Igor and Larry
  are still talking.
- Same call as today: same backends, same Larry, same captions, same spoken
  controls, same endings. Nothing about the *conversation* changes.
- The microphone and output pickers that the audio bridge fought for are
  simply there — the native screen has the real roster without a bridge.
- One tap (or one `grabber://call` link) from anywhere to a live call.
- No new backend. The bridge that serves the page serves the app.

## Non-goals

- **Replacing the Cockpit page's Call tab.** The page keeps its call for
  laptops and for anyone not in the app. The two are peers on the same
  bridge.
- **The Cockpit page's other surfaces.** Decisions, PRs, history, the call
  detail pages (`#call/<id>`) stay in the web view. The Call tab is the
  call, live, and nothing else.
- **Lock-screen call controls / CallKit.** Hang-up from the lock screen, the
  green "call in progress" pill, surviving an *incoming phone call* — phase
  2, its own spec. Phase 1 is "the call does not die when the screen goes
  dark".
- **A voice / model picker.** Phase 1 starts the call on the backend's
  default voice and model. Igor's favourite voices (Cockpit PR
  `voice-favorites`) come in phase 2 once the screen exists.
- **Typed turns.** The page offers a text box when there is no microphone.
  The app always has a microphone.
- **Android.**

## User-visible behavior

### The Call tab

A new tab, **Call**, beside Cockpit. Idle, it shows: a large **Call Larry**
button, a row of backends to choose from — *Gemini*, *ElevenLabs*, *OpenAI*,
*Drill* — with the last choice remembered, and the microphone and output
pickers showing what is attached right now (the same roster and names the
audio bridge gives the page: *iPhone Microphone*, *AirPods Pro*, *Speaker*).

### Starting a call

Tap **Call Larry**. The screen says *connecting…* and the backend's name.
When the bridge answers, the screen says *live*, a timer starts, and the
microphone opens — not before. (Opening the microphone before the far end
is ready is the page's rule too; it stops Igor talking into nothing.)

If the bridge cannot be reached — not on the tailnet, the server is down —
the screen says so within a few seconds, with a copyable error, and returns
to idle. Nothing hangs.

### During a call

The screen is the conversation and nothing else (Cockpit DESIGN P23/P24):

- **Captions.** Each thing Igor says and each thing Larry says is a row:
  a short speaker label — *Igor*, *Larry*, never wider than five
  characters — and the words. Larry's spoken text appears as he says it;
  Igor's appears when the recognizer settles on it. No turn numbers, no
  links, no per-turn readouts. Larry's *consults* (asking the other Larry
  something mid-call) show as a short clamped row that expands on tap and
  never touches the call.
- **Mute.** One toggle. Muted, nothing Igor says leaves the phone, and the
  bridge is told so it does not hang up on the silence.
- **Hang up.** One button. The call ends with reason *stopped*.
- **Mic / output pickers.** Change the microphone or the speaker mid-call;
  it takes effect immediately, and if iOS reroutes on its own (AirPods
  connect, headphones unplugged) the pickers follow and the call carries
  on wherever iOS put it.
- **Timer and backend name**, small, at the top.

When Larry is cut off — Igor talks over him — the audio stops within a
beat, exactly as on the page. That decision is the vendor's; the screen
just stops playing.

**Spoken control works unchanged** (DESIGN P25): "Larry, hang up", "end
the call", "bye Larry" end the call; the two-minute idle hang-up and its
thirty-second warning still apply. These are the bridge's, not the
screen's, and they do not care which client is connected.

### The lock — the point of all this

- **Lock the phone mid-call** (side button, or auto-lock): the call
  continues. Larry keeps talking through whatever the output is; Igor
  keeps being heard. The lock screen shows iOS's own "app is using the
  microphone" indicator and nothing else.
- **Background the app mid-call** (home gesture, switch to another app):
  same — the call continues.
- **Switch to another tab mid-call:** same. The Call tab is one tap away
  and the timer is still running when he gets back.
- **Come back** — unlock, reopen: the captions are where he left them, the
  timer is right, nothing reconnects because nothing disconnected.
- **While the Call tab is frontmost during a live call the screen stays
  awake**, as it does on the Cockpit tab today — but the call no longer
  *depends* on it. A deliberate lock is honoured and does not end the
  call.

### Interruptions

- **An incoming phone call, Siri, or another app taking over audio** pauses
  the call's audio. When the interruption ends, the call's audio resumes on
  its own. If the interruption outlasts the bridge's patience (two minutes
  of silence), the bridge hangs up and the screen shows *idle 2 min* when
  Igor returns. Phase 2 (CallKit) makes the phone-call case graceful; phase
  1 only promises "resume if the bridge is still there".
- **Losing the network** (walking out of Wi-Fi with no cell coverage, the
  tailnet dropping): the call ends with a *connection lost* reason. Phase 1
  does not reconnect; a fresh tap starts a fresh call.

### Endings

The call ends and the screen says why, in the same words the page uses:
*stopped*, *idle 2 min*, *hang-up intent*, *Larry hung up*, *vendor ended
the call*, *vendor max duration*, *connection lost*. The captions stay on
screen until the next call starts; the **Call Larry** button is back.

Gemini Live caps a call at roughly fifteen minutes and the bridge warns
before it does; the warning shows as a row.

### The deep link

`grabber://call` and `grabber://call?via=…` now open the **Call** tab and
start the call there — the web view is not loaded for it. `via` names the
backend exactly as before (`gemini`, `eleven`, `openai`, `drill`); an
unknown `via` is ignored and the remembered backend is used. If a call is
already live, the link brings Igor to it and does not start a second one.
The rest of the deep-link spec is unchanged.

### The widget

Igor, 2026-08-29: *"Make sure to add a call button there as well, somewhere."*

The home-screen widget (medium and large) gets a **☎ Call** pill in its
header, beside the date. Tapping it is `grabber://call`: the app opens on
the Call tab and the call starts on the remembered backend — from the home
screen to Larry in one tap, no unlock-and-hunt. The rest of the widget is
unchanged; the pill is the only new tap zone.

### One call at a time

If a call is live on the Cockpit *page* (its own Call tab, in the web
view) and Igor taps **Call Larry**, the tap is refused with a one-line
reason — *a call is live in the Cockpit tab* — rather than opening a
second microphone on the same phone. The reverse is not policed; the page
does not know about the native call.

## Acceptance criteria

1. **Call Larry** on Gemini: within 5 s the screen says *live*, the timer
   runs, and saying "hello Larry" produces a Larry reply, audible, with
   both captions on screen.
2. Repeat for ElevenLabs, OpenAI, and Drill. The remembered backend
   survives an app restart.
3. Mid-call, press the side button. Wait 2 minutes with the screen dark,
   talking to Larry at intervals: Larry answers every time. Unlock: the
   captions include everything said while locked, the timer is continuous.
4. Mid-call, auto-lock fires (auto-lock set to 30 s, phone untouched while
   Larry talks): same as 3.
5. Mid-call, home gesture to another app for 2 minutes, talking: same.
   Return: same.
6. Mid-call, switch to the Today tab for 2 minutes: same.
7. Talk over Larry: his audio stops within ~250 ms.
8. Mute: say something; no Igor caption appears and Larry does not react.
   Unmute: normal. A 3-minute mute does not end the call.
9. Say "Larry, hang up": the call ends with *hang-up intent*. Say nothing
   for 2 minutes: *idle 2 min*, with the warning row at 90 s.
10. Connect AirPods mid-call: audio moves to them, the output picker says
    so, the call continues. Switch the output picker back to Speaker:
    Larry's voice moves to the speaker.
11. Kill the bridge process mid-call: within 30 s the screen shows
    *connection lost* with a copyable error, and **Call Larry** is
    tappable again.
12. Turn Wi-Fi off with no tailnet reachability: tapping **Call Larry**
    fails within 10 s with a copyable error naming the host.
13. `grabber://call?via=eleven` from a Shortcut with the app closed: the
    app opens on the Call tab and the call is *live* on ElevenLabs without
    a tap. With a call already live: the app comes to the Call tab; the
    timer did not reset.
14. Start a call on the Cockpit page's Call tab, then tap **Call Larry**:
    refused with the reason; the page's call is unaffected.
18. Tap **☎ Call** on the home-screen widget (medium, then large): the app
    opens on the Call tab and the call is *live* on the remembered backend
    without another tap. With a call already live: the app comes to the
    Call tab; the timer did not reset.
15. Trigger a Siri interruption mid-call: after Siri dismisses, the call's
    audio is back within 2 s without a tap.
16. The live screen contains no turn numbers and no speaker label wider
    than five characters; a consult row is clamped and expandable, and
    expanding it does not touch the call.
17. The bridge's call record for a native call (`data/voice-live/<session>.jsonl`,
    the feedback marker on teardown) is indistinguishable from a page call.

## Rationale and risks

**Why native rather than fixing the web view.** WebKit on iOS suspends
`getUserMedia` capture when the app leaves the foreground, and `WKWebView`
exposes no way to opt out — Safari got background WebRTC; embedded web
views did not. Holding a native audio session open (#73's proposal) keeps
the *process* alive but not the page's microphone. The keep-awake spec
already records the symptom: "iOS then suspends the web view's audio
capture, and the call dies." The only fix is for the app, not the page, to
own the microphone and the speaker.

**Why this is small.** The bridge was built page-agnostic: one socket,
raw audio both ways, a dozen JSON message types, no auth on the tailnet.
There is no conversation logic to port. The app already ships the audio
engine (`react-native-audio-api`, used for the Gym Timer's tones), the
native route module (the audio bridge), the `audio` background mode (the
Gym Timer), and the deep-link routing. This is a screen and a socket.

**Risks.**

- *Audio under the lock.* The app keeps running while locked only while
  its audio session is active in a recording-capable category. If the
  session ever deactivates mid-call (an interruption not handled, a route
  change mishandled), iOS suspends the app within seconds and the bridge
  hangs up on the silence. Acceptance 3–6 and 15 are the guard.
- *The tailnet under the lock.* Tailscale's iOS VPN stays up in the
  background, but the socket is over it; a phone that drops Wi-Fi for
  cellular will re-home the VPN and may drop the socket. Phase 1 reports
  *connection lost* rather than reconnecting.
- *Echo.* On the speaker with the microphone open, the vendor's VAD hears
  Larry and barges in on himself. The page has the same problem and the
  same advice — headphones — but the native screen's voice-chat session
  mode gives iOS's echo cancellation a real chance the web view never had.
- *Two clients, one bridge.* The bridge supports several sessions, but the
  app polices only its own side (the one-call rule above).
- *Vendor limits are unchanged.* Gemini's ~15 minutes, ElevenLabs's cut at
  ~10 minutes observed; a native client that survives the lock will hit
  them more often than a page that dies first.
