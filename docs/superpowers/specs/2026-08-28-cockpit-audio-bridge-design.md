# Cockpit Audio Bridge — Design Spec

**Status:** implemented (native side); Cockpit page consumes it in a follow-up
**Bead:** `igor2-88g.168`
**Depends on:** [Cockpit Tab](2026-08-27-cockpit-tab-design.md)

## Summary

The Cockpit tab renders Igor's decision dashboard in a web view. The
dashboard's Call tab has a microphone picker and an output picker — on a
laptop they work, and they are how he keeps the call in his headphones
while the mic stays on the laptop. Inside the app both pickers are simply
**not on screen**, and Igor noticed on the first call he took through it:

> "I don't see the switchers… I don't quite want just the webview because
> I want to have the better audio controls for mic and system default.
> Can I do some kind of bridge for that?"

They are absent because the web platform on iOS cannot answer the
questions those pickers ask. Every browser engine on iOS is WebKit, and
WebKit:

- enumerates exactly **one** audio input, unnamed, no matter how many
  microphones are actually attached;
- enumerates **zero** audio outputs, ever;
- implements no `setSinkId` on either an element or an `AudioContext`.

The dashboard already handles that honestly — a picker with one nameless
option is a control that cannot do anything, so it hides itself. Nothing
is broken. There is just nothing on the web side to build a picker out of.

The device roster and the routing controls do exist one layer down, in
iOS's own audio session. This spec adds a **bridge**: the app reads the
real roster natively, hands it to the page, and applies the page's choice
natively. The Cockpit's pickers then work inside the app for the same
reason they work on the laptop — because something underneath can finally
answer them.

## Goals

- Inside the app, the Cockpit's Call tab can list every microphone iOS
  can actually see — built-in, wired, Bluetooth headset — by name.
- It can list the output destinations iOS can actually be steered to, and
  switching between them takes effect mid-call.
- It can show what is **really** carrying the call right now, read off the
  live audio route rather than off the dropdown. The dashboard already
  calls this "the confirmer"; this gives it a truthful source on iOS.
- A device that appears or disappears mid-call (AirPods connecting, a
  headset battery dying) updates the page without a reload.
- The existing web microphone path keeps working untouched. With the
  bridge absent — Safari on the laptop, the same page on a phone browser —
  the Cockpit behaves exactly as it does today.

## Non-goals

- **Capturing audio natively and piping samples to the page.** The web
  view's own `getUserMedia` keeps doing the capture. This bridge only
  steers where that capture comes from and where playback goes.
- **Android.** Context Grabber is iOS-only.
- **Changing the Cockpit page.** The page lives in another repository and
  consumes the protocol in a follow-up change. Shipping this side first is
  deliberate: the bridge is inert until a page asks it for something.
- **A visible UI in the app.** No native picker, no new setting screen.
  The controls the user sees stay the dashboard's own.
- **Arbitrary output selection.** iOS does not offer "route to this
  particular speaker" the way desktop browsers do. What it offers is
  described under *Choosing an output*, and this spec promises no more
  than that.

## User-visible behavior

### The pickers appear

On the Cockpit tab, in the Call tab's audio controls, Igor sees a
microphone dropdown and an output dropdown listing the real hardware
attached to the phone — "iPhone Microphone", "AirPods Pro", "Speaker" —
each by the name iOS gives it. This is the same pair of controls he
already has on the laptop, in the same place, behaving the same way.

Outside the app nothing changes: the same page in mobile Safari continues
to show no pickers, because there is still nothing underneath to answer.

### Choosing a microphone

Picking a microphone takes effect on the next capture and, where iOS
allows it, on a capture already open. The choice is the page's to
remember; the app does not persist it.

If the chosen microphone is not connected when a call starts, the call
still happens on whatever iOS picks rather than failing, and the page is
told which device is really live so it can say so. A pick is never
silently erased because a headset's battery was flat.

### Choosing an output

iOS does not let an app point audio at an arbitrary output the way a
desktop browser does. It offers three moves, and the picker offers exactly
those:

- **Automatic** — iOS decides. Headphones or a connected headset if there
  is one, the earpiece otherwise. This is the default.
- **Speaker** — force the built-in speaker, even with headphones attached.
- **A named Bluetooth or wired headset** — steer the route to that device.

Anything the phone cannot currently reach is not listed. Switching takes
effect immediately, mid-call.

### Knowing what is really live

The page can ask what the current route is and gets back the input and
output actually in use — not what was requested. When they differ, that
difference is visible, which is the entire point of the dashboard's
confirmer line.

### Devices coming and going

Connecting AirPods mid-call, unplugging a cable, or a headset dropping off
updates the page's device list and its confirmer within a moment, without
a reload and without losing the call.

### When a request cannot be honored

A microphone that vanished between the page listing it and the page
choosing it, an output the session refuses — each comes back to the page
as a failure naming what failed, not as a silent no-op. The page decides
how to show it; the app never renders its own error over the Cockpit for
an audio problem.

### When the bridge is absent

If the app is older than this change, or the page is open in a real
browser, none of the above exists and the page falls back to what it does
today. Nothing in the Cockpit tab depends on the bridge being there — the
tab, the reload control, the web microphone, and the reconnect panel all
behave exactly as they did.

## Acceptance criteria

1. Opening the Cockpit tab with a Bluetooth headset connected, the Call
   tab's microphone dropdown lists at least the built-in microphone and
   the headset, each named.
2. The output dropdown lists Automatic, Speaker, and any connected
   headset.
3. Selecting a microphone and then starting a call, the confirmer names
   the selected microphone.
4. Selecting **Speaker** during a call with AirPods connected moves audio
   to the phone's speaker within a second, and the call continues.
5. Connecting AirPods while the Cockpit tab is open adds them to both
   dropdowns without a reload.
6. Disconnecting them removes them, the confirmer updates to whatever
   took over, and the call continues.
7. With no bridge present (the page in Safari), the Cockpit page's
   behavior is byte-for-byte what it is today.
8. With the bridge present but the page not using it — i.e. today's
   Cockpit page in the new build — the tab behaves exactly as it does
   now, including the web microphone.
9. Every request the page makes gets exactly one answer: a result or a
   failure. Nothing is left hanging.
10. Backgrounding the app during a call and returning does not leave the
    page's device list stale.

## Rationale and risks

**Why a message protocol rather than a native picker.** The controls
belong next to the call, and the call is in the page. A native picker
floating above a web view would be a second place to change the same
setting, and the two would drift. The app supplies facts and applies
choices; the dashboard stays the only thing with an opinion about layout.

**Why the app does not persist the choice.** The page already persists
it, per origin, and it is the same choice on the laptop. Two stores would
disagree the first time one of them was written and the other was not.

**Risk: WebKit reconfigures the audio session under us.** The web view's
own microphone capture configures the app's audio session when it starts.
A route steered before capture begins can therefore be overridden by the
capture itself. The bridge re-asserts the requested route whenever the
route changes underneath it, which should cover this, but it is the part
of this change that most needs verifying on a real call with real
headphones — it cannot be reproduced without the device.

**Risk: Bluetooth profile flip.** Opening a microphone on a Bluetooth
headset drops it from A2DP to the hands-free profile, and the call
audibly degrades. That is the operating system's behavior on every
platform, not something this bridge introduces — and it is precisely why
the picker matters: the workaround is to keep the laptop or phone
microphone as the input and the headset as the output, which is only
expressible if both ends are separately choosable. Which is what this
adds.
