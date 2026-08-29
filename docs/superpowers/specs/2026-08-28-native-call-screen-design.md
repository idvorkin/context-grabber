# A Call That Survives the Lock — Native Call Screen Design Spec

**Status:** Implemented (phase 1) — on-device acceptance pending
**Date:** 2026-08-28
**Owner:** Igor
**Issue:** [#74](https://github.com/idvorkin/context-grabber/issues/74) (this) · subsumes [#73](https://github.com/idvorkin/context-grabber/issues/73) · bead `context-grabber-e19`
**Depends on:** [Cockpit Tab](2026-08-27-cockpit-tab-design.md), [Cockpit Audio Bridge](2026-08-28-cockpit-audio-bridge-design.md)
**Changes:** [Call deep link](2026-08-28-cockpit-call-deep-link-design.md) — `grabber://call` now lands here, not on the Cockpit page
**Amended:** 2026-08-29, [#90](https://github.com/idvorkin/context-grabber/issues/90) — a calling treatment while the bridge answers; mute folds into the voice indicator; a round red hang-up

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
button, a row of backends to choose from — *ElevenLabs*, *Gemini*, *OpenAI*,
*Drill* — with the last choice remembered (ElevenLabs, Tony's voice, until
Igor picks otherwise — "Let's default to the 11 labs Tony call", 2026-08-29),
and one **devices line**.

### The devices line

Igor, 2026-08-29: *"Instead of wasting all of that mic output/input, I want
to be able to collapse that down, maybe under a folder, so I have more
space."* And: *"I want to see mic input volume, that little strip that goes
up and down."*

One line, always visible: the current microphone and output by name —
*iPhone Microphone · Speaker* — and a disclosure chevron. Tap the line and
the two pickers unfold beneath it (the same roster and names the audio
bridge gives the page: *iPhone Microphone*, *AirPods Pro*, *Speaker*); tap
again and they fold away. Folded is the default; the captions get the space.

The "little strip that goes up and down" started life on this line. Since
[#90](https://github.com/idvorkin/context-grabber/issues/90) it is the
**voice control** at the bottom of the screen — the thing you look at while
talking, and the mute — described under *During a call*. It is live
whenever the microphone is open, and gone with the call.

**A USB microphone wins — for the microphone only.** *"If a mic is over
USB, let's take that as a default."* When a USB audio device with a
microphone is attached — at the start of a call, or plugged in during one —
the call uses it without a tap, and the devices line says so. Igor's own
pick still wins: once he has chosen a microphone by hand during a call, the
app stops second-guessing him until the next call. **The output does not
move.** iOS likes to send playback to a USB device that was just chosen as
the microphone; a wireless-mic receiver has no speaker, and the first time
this rule ran Larry's voice went into the dongle and Igor heard nothing
(2026-08-29). The output stays where it was, and a USB device is offered in
the output picker only while iOS is actually playing through it.

### Diagnostics

*"Do you have logging output on this?"* Under the devices line, a
**Diagnostics** fold. Open, it shows the call's log — a timestamped line
for everything that matters and nothing that does not: the call starting
and on which backend and bridge, the audio session configured, the
recorder opening and at what hardware rate, the first mic frame and every
few seconds of frames after, the probe and its ack, mute, interruptions,
route changes with the full roster (every mic and output by name and
type), the bridge's `ready`, warnings, errors, and the ending. A **Copy
diagnostics** button puts the whole log plus the build, the state, and the
current roster on the clipboard, so a bad call can be pasted into a chat
without a cable. Folded by default; the log is kept whether or not it is
open, across the call and until the next one starts.

Beside *Copy diagnostics*, while no call is live, a **Prime audio**
control (Igor, 2026-08-29 09:16, still chasing the silent first call: *"Do
we need to do something like a dummy call that opens, closes, reopens?
Maybe give me a button to do that so I can test."*). It brings the call's
audio up and down once without dialling — session on, microphone open for
half a second to nowhere, everything off — and logs each step. It exists
for the experiment: prime, then call; if the first call then carries
audio, the cause is the first activation of the input unit and priming
becomes automatic; if not, something else owns the microphone. The log's
first line of every call also says whether the Cockpit tab is loaded and
whether its page reports a call of its own.

### Starting a call

Igor, 2026-08-29, on a call from this tab: *"Can you make the UI just a
little bit nicer too? While it's calling, instead of saying 'Connecting the
bridge', have like a calling thing; and mute and hang up are pretty ugly
buttons. Maybe the mute button merges with the little voice dial-y thing.
Make it prettier."*

Tap **Call Larry**. The screen *calls*, the way the Phone app does: in the
middle of the screen a ring pulses slowly outward around a handset, under it
*Calling Larry…* and the backend's name, and the status line at the top
says *calling Larry…* and the backend. Nothing about bridges or connecting
is on screen. The round red hang-up is already at the bottom, so a call that
is taking too long can be abandoned with the same tap that ends a live one.
With the phone's Reduce Motion on, the ring is still; the words are the
same. The five or six seconds this takes are the first impression of every
call.

When the bridge answers, the calling treatment gives way to the captions,
the status says *live*, a timer starts, and the microphone opens — not
before. (Opening the microphone before the far end is ready is the page's
rule too; it stops Igor talking into nothing.)

**The first call after launch works like every other call.** Igor,
2026-08-29 08:40: *"I think there's something wrong when it's a first
call."* The bridge's recordings agreed ([#88](https://github.com/idvorkin/context-grabber/issues/88)):
the first call of a burst sent exact silence for its whole length and the
retry carried audio. The first attempt at this (waiting for the input
route) did not fix it: the route was up. What differed was order — on a
first call, echo cancellation was switched on *after* playback had already
started the audio engine; on every later call it was already on before.
Now it is switched on the moment the call's audio session is configured,
before anything starts. And if the mic nonetheless delivers a second of
exact zeros, the call's audio is torn down and brought back up the way a
second call would (a short gap in Larry's voice), with a line in
Diagnostics saying so. Only if it is still silent after that does the
screen say *the microphone is delivering silence*.

**The bridge knows it is the app.** The call introduces itself —
`client: context-grabber` and the build — so the bridge's records can tell
an app call from a browser call ([#78](https://github.com/idvorkin/context-grabber/issues/78),
the call half).

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
- **The voice control — which is the mute.** At the bottom, left of the
  hang-up, one round control that *is* the microphone: a disc inside it
  swells with Igor's voice and shrinks in silence, so "is my mic working"
  is answered by glancing at it. Tapping it mutes. Muted, the control dims,
  a red slash crosses the microphone, the disc stops moving — frozen where
  it was — and the word under it reads *Muted*; nothing Igor says leaves
  the phone, and the bridge is told so it does not hang up on the silence.
  Tap again: the slash goes, the disc moves again. There is no separate
  mute button; the level and the mute are one thing, with a label under it
  so the first tap is not a guess.
- **Hang up.** A round red button with a handset on it, bottom-centre, big
  enough for a thumb without looking — not a text button. Tapping it ends
  the call with reason *stopped*. It is there from the moment the call
  starts calling until the call ends, and then **Call Larry** takes its
  place.
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

1. **Call Larry** on a fresh install (nothing remembered): the call is on
   ElevenLabs — within 5 s the screen says *live*, the timer runs, and
   saying "hello Larry" produces a reply in Tony's voice, with both
   captions on screen.
2. Repeat for Gemini, OpenAI, and Drill. The remembered backend survives
   an app restart.
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
15. Trigger a Siri interruption mid-call: after Siri dismisses, the call's
    audio is back within 2 s without a tap.
16. The live screen contains no turn numbers and no speaker label wider
    than five characters; a consult row is clamped and expandable, and
    expanding it does not touch the call.
17. The bridge's call record for a native call (`data/voice-live/<session>.jsonl`,
    the feedback marker on teardown) matches a page call's in every way
    except the client tag on the start frame, which names the app and
    build.
18. Tap **☎ Call** on the home-screen widget (medium, then large): the app
    opens on the Call tab and the call is *live* on the remembered backend
    without another tap. With a call already live: the app comes to the
    Call tab; the timer did not reset.
19. **Echo.** Gemini backend, phone on speaker, no headphones, held at
    arm's length: let Larry say two full sentences. No *Igor* caption
    appears containing Larry's words, and Larry does not interrupt or
    restart himself. Then switch to the Today tab and back mid-call and
    repeat: still clean (re-activating the session must not drop it).

20. **Pickers mid-call.** With AirPods paired, on a live call: pick
    *AirPods Pro* as the microphone — within 2 s the chip moves, the call
    continues, and the next sentence Igor says is captioned (the mic
    survived the change of hardware rate). Pick *Speaker* as the output:
    Larry moves to the speaker; pick *AirPods Pro*: he moves back. Repeat
    the mic pick with the phone locked mid-way: still captioned after
    unlock.
21. **Level.** On a live call, speak: the disc in the voice control swells
    with the voice and shrinks in silence. Mute: it freezes and dims. Hang
    up: the control is gone with the call.
22. **Folded pickers.** Open the Call tab: one devices line (*iPhone
    Microphone · Speaker*, chevron); no level strip on it, no chips. Tap
    it: the mic and output pickers appear; tap again: gone. Picking a
    device updates the line's names whether folded or not.
23. **USB default.** Plug a USB-C microphone in, then start a call: the
    devices line names the USB mic and Larry hears it. Start a call on the
    built-in mic, then plug the USB mic in: the call moves to it within
    2 s. Pick *iPhone Microphone* by hand, then re-plug the USB mic: the
    call stays on the built-in mic for the rest of that call.
24. **USB does not steal the output.** With a wireless-mic USB receiver
    plugged in, start a call on speaker: the mic is the receiver, the
    output is still *Speaker*, Larry is audible, and the receiver is not
    listed under *Out*.
25. **Diagnostics.** After any call, open *Diagnostics*: the log shows the
    start, `ready` with the output rate, the recorder's rate, the first mic
    frame, `mic_ack`, every route change with the roster, and the ending.
    *Copy diagnostics* → paste: the same, plus build sha, state, and the
    current roster.
26. **Calling.** Tap **Call Larry**: until the bridge answers, the middle of
    the screen shows a ring pulsing outward around a handset, *Calling
    Larry…*, and the backend's name; the status line reads *calling Larry…*
    with the backend; the words "connecting" and "bridge" appear nowhere.
    The round red hang-up is already tappable and ends it with *stopped*.
    When the bridge answers, the treatment is gone and the captions area
    says *Say hello.* Turn on Reduce Motion (Settings → Accessibility →
    Motion) and call again: the ring does not pulse; everything else is the
    same.
27. **The voice control is the mute.** On a live call, the round control
    left of the hang-up swells as Igor speaks. Tap it: it dims, a red slash
    crosses the microphone, the disc stops moving, the word under it says
    *Muted*; say something — no *Igor* caption, Larry does not react. Tap
    again: the slash goes, the disc moves, and the next sentence is
    captioned. There is no other mute control on the screen.
28. **Hang-up.** While calling and while live, a round red handset button
    sits bottom-centre, at least 64 pt across; tapping it ends the call with
    *stopped*. Idle and ended, it is gone and **Call Larry** is back. The
    *Diagnostics* fold opens in every state, calling and live included.
29. **First call after launch.** Force-quit the app. Launch, Call tab,
    **Call Larry**, say a sentence as soon as Tony has greeted: the voice
    control swells as you speak and your sentence is captioned. Diagnostics
    shows `input route ready: iPhone Microphone` before `recorder
    started`, and no `zeros` line. Repeat five times (force-quit between):
    five for five. If a `mic delivering zeros → re-arming` line appears,
    the call still works (the watchdog caught it) — report it.

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
  Larry and barges in on himself — the first native calls did exactly that
  ([#80](https://github.com/idvorkin/context-grabber/issues/80): Gemini
  transcribed its own sentences as Igor and restarted them six times). The
  session mode alone does not cancel echo; the audio engine has to run its
  I/O through iOS's voice-processing unit, the same one the web view and
  every VoIP app use. The native screen does, so speakerphone works without
  headphones; headphones remain the quieter option.
- *Two clients, one bridge.* The bridge supports several sessions, but the
  app polices only its own side (the one-call rule above).
- *Vendor limits are unchanged.* Gemini's ~15 minutes, ElevenLabs's cut at
  ~10 minutes observed; a native client that survives the lock will hit
  them more often than a page that dies first.
