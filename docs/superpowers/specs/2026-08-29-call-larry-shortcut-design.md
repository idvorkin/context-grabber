# "Call Larry" in the Shortcuts App — Design Spec

**Status:** Proposed
**Date:** 2026-08-29
**Owner:** Igor
**Issue:** [#75](https://github.com/idvorkin/context-grabber/issues/75) (phase 2) · bead `context-grabber-e19`
**Depends on:** [Native call screen](2026-08-28-native-call-screen-design.md), [Call deep link](2026-08-28-cockpit-call-deep-link-design.md) (phase 1)

## Summary

Igor, 2026-08-29: *"Calls doesn't show up as a shortcut in the Shortcut app.
Can you fix that as well? … Increment something does."*

Phase 1 gave Igor a link — `grabber://call?via=eleven` — that any Shortcut can
open. But a link is a thing to remember and paste. The Shortcuts app already
lists Context Grabber's *Increment Counter* by name; the call should be
listed the same way, so "Call Larry" is a thing you pick from a menu, put on
the Action Button, say to Siri, or drop into an automation, without ever
typing a URL.

## Goals

- **Call Larry** appears in the Shortcuts app under Context Grabber's
  actions, next to *Increment Counter*.
- It takes one optional parameter, the backend: Gemini, ElevenLabs, OpenAI,
  or Drill. Left blank, the call starts on the remembered backend.
- Running it does exactly what `grabber://call` does: the app comes to the
  front on the Call tab and the call starts.
- A ready-made "Call Larry" shortcut exists without building one — it shows
  in the Shortcuts app's Context Grabber section and answers to "Call Larry
  in Context Grabber" spoken to Siri.

## Non-goals

- **Hanging up from a shortcut.** Ending a call stays a tap or a spoken
  "hang up".
- **Running the call without opening the app.** The call is the app's audio
  session; the app must be in front to start it. (Once started, the lock
  and background rules of the native call screen apply.)
- **Other actions** (grab context, start a timer) as intents. Only the call.

## User-visible behavior

- In the Shortcuts app, **Context Grabber → Call Larry** is an action with
  a *Backend* field (optional; choices *Gemini*, *ElevenLabs*, *OpenAI*,
  *Drill*).
- Running it — from the Shortcuts app, an Action Button assignment, a
  Home Screen shortcut, Siri — opens Context Grabber on the Call tab with
  the call *connecting…* on the chosen (or remembered) backend. Nothing
  else to tap.
- If a call is already live, the app comes to the Call tab and the call
  continues; no second call.
- The Shortcuts app offers a pre-built **Call Larry** under Context
  Grabber's App Shortcuts. Siri: "Call Larry in Context Grabber", "Call
  Larry with Context Grabber".
- `grabber://call` links keep working exactly as before; the intent is a
  second door to the same room.

## Acceptance criteria

1. Shortcuts app → search "Call Larry" → the action is listed under Context
   Grabber with a Backend field offering the four backends.
2. A shortcut of just that action, backend *ElevenLabs*, run from the
   Shortcuts app with Context Grabber closed: the app opens on the Call tab
   and is *connecting… ElevenLabs* → *live* without a tap.
3. Same with the Backend field blank: connects on the remembered backend.
4. Run it while a call is live: the app comes to the Call tab; the timer did
   not reset; no second `start` reaches the bridge.
5. The pre-built **Call Larry** App Shortcut appears in the Shortcuts app's
   Context Grabber section; "Hey Siri, Call Larry in Context Grabber" runs
   it.
6. *Increment Counter* still appears and still works.

## Rationale and risks

An App Intent is the only thing the Shortcuts app lists by name; a URL
scheme is invisible to it. The intent has to live in the app itself, not
the widget extension, because it must bring the app to the front and then
hand the app the same route the link uses — one code path for the link,
the widget pill, and the shortcut.

Risk: the app's own deep-link handler is the JavaScript side's
`Linking` listener. The intent opens the URL after the app is in front, so
the handler is guaranteed to be attached; a cold start goes through
`getInitialURL` exactly as a tapped link does.
