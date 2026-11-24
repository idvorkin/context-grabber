# The call as a shared component (design proposal, #1393)

Status: proposal for Igor's choice. No code until he picks an option.

## Summary

Igor, 2026-11-24: "this call thing can be a library that other apps can use… if I'm using a whiteboard, then I'd use
it in exercise analyzer… a library of shared components that I can use and test independently… each of them has a
sample app I can build and test on."

Today the call (talk to Larry or Tony over the voice bridge) lives inside Context Grabber. This proposal makes it a
component any of Igor's apps can embed: Grabber's Call tab, the board's talk button, and Exercise Analyzer's
mid-workout call. It ships with a tiny sample app that makes a call and nothing else.

## Goals

- One call experience everywhere: the same echo cancellation, mic choice, route handling, hang-up behaviour,
  call log and copyable errors, whichever app places the call.
- Fixes land once: a call bug fixed for Grabber is fixed for Exercise Analyzer on its next bump.
- The call is testable alone: host tests for the call's rules, and a sample app for the parts only a phone shows.
- Each host app adds what only it knows (live context: workout mode, the board being drawn, location).

## Non-goals

- No change to what a call sounds or looks like today.
- No new server: the Cockpit's voice bridge and its protocol stay as they are.
- Not the web twin: the Cockpit's browser call stays its own; this is the Apple-platform side only.
- Not the chat, the board or dictation (BugKit already owns dictation).

## What the component owns, and what stays in each app

| The call component | Each host app |
|---|---|
| Connecting to the voice bridge, the wire format, reconnect and the hang-up drain | Where the Cockpit is and its key (from shared pairing, bug-kit #144) |
| The audio engine: echo cancellation on, mic and speaker routing, route changes, playback limits | Its own other audio (gym timer, dictation, music), and telling the call when it starts or stops |
| Call state: connecting, live, held, ended, with reasons | The screen around the call: where the call button sits, how the call is shown |
| The call log, metadata (device, route, network) and copyable errors | Live context it adds to the start of a call (workout set, board picture, place) |
| A default call screen a host may use as is | Whether to use the default screen or draw its own from the call state |

## Who owns the audio session

The hardest part. Only one audio configuration is live on a device at a time, and today Grabber's timer, dictation
and call each assume they set it.

- While a call is live, the call owns the session. A host must not change it; it asks the call ("duck for a cue",
  "play this sound") and the call does it within its own configuration (voice chat, echo cancellation kept on).
- Before and after a call, the host owns it. The call restores what the host had when it ends.
- The gym timer's cues during a call: the timer asks the call to play its cue mixed into the call, instead of
  switching the session. Dictation during a call is refused with a clear message (it would fight the call's mic).
- The rule lives in one place (the component) and each host follows it; today's AGENTS rules on echo cancellation
  and voice chat move into the component's own guide.

## Where it lives: options

| | A. Its own package and repo (`talk-kit`), sample app inside | B. Inside bug-kit, beside the report dialog | C. Stay in this repo's package, other apps depend on it |
|---|---|---|---|
| Others embed it | Yes, by version tag, like BugKit | Yes, but every BugKit user gets the call too | Awkward: Exercise Analyzer depends on Grabber's repo |
| Tested alone, sample app | Natural: the repo is the call and its sample | Mixed with the bug tools; slower to test | The sample app sits in a big repo; tests run with everything |
| Release and versioning | Its own tags; each app bumps when ready | Tied to BugKit's releases | No real releases; consumers track a commit |
| Cost to move | Highest: new repo, CI, pipeline, signing for the sample | Medium | Lowest: a new library target in the existing package |
| Fits "library of shared components, each with a sample app" | Best | Partly (BugKit becomes a grab bag) | Least |

## Recommendation

**A, in two steps.** First carve the call into its own library inside this repo's package (option C's move, low risk,
Grabber keeps working and tests stay green), with the audio-session rule above and the call screen split from the
call state. Once that boundary has held for a week of real calls, lift it into its own repo with the sample app and
version tags, and have Exercise Analyzer adopt it first (its mid-workout call, exercise-analyzer #376's live
context), then the board.

## How it's tested

- Host: the call's rules (wire format, hold, watchdog, hang-up drain, playback limits, metadata) already run as host
  tests; they move with it unchanged.
- Sample app: one screen, "Call Larry", that shows route, levels and the log, built and run on the phone. It is
  where echo cancellation, route changes and the locked-phone call are checked, before any host app takes a bump.
- Each host keeps one test that its call button starts a call and the call screen appears.

## Migration steps

1. Draw the boundary inside Grabber: the call depends on nothing app-specific (settings, location and live context
   come in from the host). No behaviour change; Grabber's call stories stay green.
2. Move the audio-session ownership rule into the call and route the gym timer's cues through it.
3. Split the call screen (default, optional) from call state.
4. New repo with the sample app; Grabber switches to the tagged version.
5. Exercise Analyzer adopts it; then the board's talk button.

## Open questions for Igor

1. Option A (own repo), B (inside bug-kit) or C (stay here)? Recommended: A, reached through C.
2. Should Exercise Analyzer's watch be able to place a call too, or only its phone?
3. Is refusing dictation during a call right, or should dictation pause the call's mic instead?
