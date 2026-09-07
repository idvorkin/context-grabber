# Gym Timer and other audio: ducking — an explainer and the options

> **Status:** Written 2026-09-07 for Igor: *"Can we do audio ducking? How
> does that work with the count time? Explain ducking in an explainer and
> give me design options."* An explainer and five options with a
> recommendation. Nothing built; when an option is picked, this becomes the
> spec.

## The explainer

**One audio session per app.** iOS gives every app a single *audio
session* — a declaration of how the app's sound relates to everyone
else's. An app sets its session's *category* (playback, ambient, record,
play-and-record…) and a few *options*, then *activates* the session when
it wants to make sound and *deactivates* it when done. What happens to
Music, Spotify, a podcast, Larry's call, is decided by those options.

**Three ways to share the speaker.** With a playback-type session active:

- **Interrupt** (no mixing option): your sound is exclusive. The moment
  you activate, everything else *pauses*. When you deactivate, the others
  get to resume — but only if you deactivate with the *notify others*
  flag; otherwise they stay paused.
- **Mix** (`mixWithOthers`): your sound plays on top of theirs at full
  volume. Nothing pauses, nothing dips. Good for taps and clicks; a beep
  under loud music is lost.
- **Duck** (`duckOthers`): your sound plays on top, and *theirs is turned
  down* while your session is active — iOS lowers other apps' volume by a
  fixed amount it chooses (roughly to a quarter), with a fade of a fraction
  of a second down and up. When your session deactivates, their volume
  fades back. This is what navigation apps do for turn instructions.

Two refinements: **spoken-audio aware** (`interruptSpokenAudioAndMixWithOthers`)
tells iOS to *pause* podcasts and audiobooks while you sound — because
ducked speech is unintelligible, so pausing is kinder — while music is
merely ducked; and **notify on deactivation** is the flag that makes the
paused podcast pick up where it stopped.

**The catch: ducking lasts as long as the session is active.** A duck is
not per sound; it is per *session activation*. An app that keeps its
session active for an hour ducks everyone for an hour.

**What the Gym Timer does today.** Its session is plain `playback` with no
mixing option — deliberately, because it is the category iOS most reliably
keeps alive in the background (the keepalive spec of 2026-04-26). So
today, starting a workout **pauses** whatever is playing, and — because the
library deactivates the session without the notify flag — the music does
**not** come back when the workout ends or you leave the timer. That is the
current behaviour, and half of any option below is fixing the second part.

**How the timer makes its sounds.** They are generated tones, not files,
through the app's Web-Audio engine: the start cue (three rising notes,
0.45 s), the rest cue (two falling notes, 0.5 s), the countdown ticks at
3, 2, 1 (80 ms each, one per second), and the finish fanfare (four notes,
0.85 s). All short; the ticks very short.

**The keepalive complication.** To keep running in the background the
timer plays a near-silent loop through that same session for the whole
workout, so the session is *active the whole time*. A naive "add
`duckOthers`" would duck your music for the whole workout. Ducking only
around the cues means changing the session's options while it stays
active. The audio library re-applies the category and options to the live
session whenever they change, so the mechanism exists; **whether iOS
un-ducks when the option is removed without a deactivation** is the one
thing that has to be verified on the phone. If it does not, the fallback is
a brief deactivate/reactivate around the cue, which costs a sub-second gap
in the keepalive — fine in the foreground, and in the background short
enough that iOS will not suspend the app.

## How ducking meets the countdown

The 3-2-1 ticks are 80 ms, one second apart. Ducking per tick would mean
three quick dips and rises inside three seconds — music "pumping" at one
beat per second, which is worse than either no duck or a steady one. So
the sensible unit is a **window**: the duck opens at the 3 tick and closes
about a second after the phase cue that follows (*GO* or the rest cue),
roughly four seconds of quieter music per boundary, once per phase change.
The fanfare at the end gets its own short window. Boundaries the timer
reaches while the phone is locked play their cues today; they would duck
the same way.

For the stopwatch and the set counter there are no cues, so nothing ducks.

## The options

| | Behaviour with music playing | Effort | Risk |
|---|---|---|---|
| **A. Today, but the music comes back** | Starting a workout pauses the music (as now); it resumes when the workout ends or you leave the timer. | Small: the notify-on-deactivate flag, a one-line patch to the audio library's deactivate. | None new. |
| **B. Mix, no duck** | Music never pauses or dips; cues play on top at full volume. | Small: one session option. | Cues lost under loud music. The keepalive spec chose exclusive `playback` for background reliability; mixing must be re-verified in the background. |
| **C. Duck around the cues** *(recommended)* | Music keeps playing; it dips for about four seconds around each countdown-and-cue, and for the fanfare, then comes back. Nothing pauses. | Medium: B plus a duck window opened by the countdown and closed after the cue; verify un-duck-while-active, with the deactivate fallback. | The verification above. iOS picks the dip depth; it is not adjustable. |
| **C′. C, podcast-aware** | As C for music; a podcast or audiobook *pauses* for the window and resumes after, instead of being ducked into mush. | C plus one option and the notify flag from A. | Same as C. |
| **D. Duck for the whole workout** | Music at a quarter volume from START to the end. | Smallest of the duck options. | The worst experience: a quiet workout. Here for completeness. |
| **E. Spoken cues** | "Three, two, one — rest." spoken over ducked music, replacing or joining the tones. | Larger: speech synthesis, phrasing, a setting. | New feature, not a fix; worth its own spec if wanted. |

**Recommendation: C′** — duck around the cues, with podcasts paused rather
than ducked, and the notify flag so they resume. It is what a running app
does, it keeps the countdown intact, and the whole-workout duck (D) and the
pause (A) are its two failure modes, both worse. B is the fallback if the
un-duck-while-active check fails *and* the deactivate fallback proves to
suspend the app in the background.

## Open questions for Igor

1. **Music or podcasts in the gym?** C′ only matters for spoken audio; if
   it is always music, C is enough.
2. **Should the dip be a setting?** *Proposed: no.* One behaviour; the
   timer has no settings today and the cues are the point of the timer.
3. **Spoken cues (E)** — wanted at all, later, or never?
4. **The stopwatch's silence is fine?** Nothing ducks in Stopwatch and Sets
   because nothing sounds; confirm that is right.

## What C′ would look like, in the user's terms

- Start a workout with music playing: the music keeps playing at full
  volume through the ready phase and the work phase.
- At three seconds left the music fades down; the ticks and the *rest* cue
  are clear over it; about a second after the cue the music fades back up.
  Same at the end of rest into the next round, with the *GO* cue.
- The finish fanfare plays over a dip; the music is back within a couple of
  seconds of it ending.
- With a podcast playing instead: it pauses at the three-second mark and
  resumes where it stopped after the cue.
- Leave the timer or reset: the music (or podcast) is exactly as it was.
- Phone locked during the workout: identical behaviour; the cues and dips
  still happen on time.
- Larry's Call tab is untouched: its session (play-and-record, voice chat)
  is its own, and the timer's session options never apply to a call.

## Facts checked in the code (for whoever builds it)

- Session config: `playback`, no options, in the keepalive module; the
  keepalive loop keeps the session active for the whole workout.
- The audio library exposes the iOS options `mixWithOthers`, `duckOthers`,
  and `interruptSpokenAudioAndMixWithOthers`, and re-applies category and
  options to an active session when they change.
- Its deactivation calls the plain `setActive:false` — no notify-others
  flag. The repo already carries a patch for this library (echo
  cancellation), so a second small patch is the established path.
- Cues: four generated tones as listed above; the countdown tick fires at
  3, 2, 1 seconds left in the timer's tick logic, so the "duck window" has
  a natural opener.
