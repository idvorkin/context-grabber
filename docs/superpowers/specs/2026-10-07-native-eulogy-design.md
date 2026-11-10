# Native Eulogy, its song, and Recent — Design Spec

Issue [#177](https://github.com/idvorkin/context-grabber/issues/177). Igor, 2026-10-06: *"grab my eulogy song from
my blog and have a link to play it. Maybe definitely have a eulogy link and a browser link to recent. Those are
probably things I do every day."* Story [137](../../stories/07-widgets-and-links.md#user-story-137). Part of the
[Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

Three daily things from Igor's blog become launchers on the home screen: **Eulogy song** plays his eulogy song
inside the app, **Eulogy** opens the post, **Recent** opens the blog's recent changes.

Igor, 2026-10-07: *"I want you to download and inline it in the app."* The song (*How Igor wants to live*, 2:14)
ships inside the app, so it plays offline, the moment it is tapped, and keeps going with the phone locked.

## Goals

- One tap from the home screen to each.
- The song plays inside the app, offline included, and keeps playing when Igor leaves the screen or locks the phone.
- The song on Suno, whatever the post embeds today, is still one tap away.

## Non-goals

- Following a new song in the post without a new build. Suno does not hand its audio to other apps, so the song
  in the app is a copy Igor downloaded; a new song is a new copy and a new build.
- A playlist or speed controls.
- Reading the blog inside the app; a feed of recent posts.

## What Igor sees

- **Eulogy song** (a music note) opens a small sheet titled *How Igor wants to live* and starts the song. The
  sheet shows a play/pause button and how far through it is (elapsed and total). Closing the sheet leaves the song
  playing; tapping *Eulogy song* again brings the sheet back where the song is, without starting over. When it
  ends, the button offers to play it again from the start.
- **Scrub and restart** ([#195](https://github.com/idvorkin/context-grabber/issues/195), Igor: *"Player needs a
  scrubber and restart"*). The sheet's progress bar is a scrubber: drag it to any point and the song carries on
  from there (playing if it was playing, paused if it was paused), the time following the finger. A restart button
  beside play/pause goes back to the start and plays. The lock screen's scrubber moves the song too.
- **The small player** (Igor: *"when it's playing, it's in a little bottom corner window"*). While the song is
  playing, or paused partway, and its sheet is closed, the home screen shows a small player in the bottom-left
  corner (the cog has the bottom-right): a music note, how far through it is, and play/pause. Tapping it opens the
  sheet; its ✕ stops the song, back to the start, and the small player goes away. It goes away by itself when the
  song ends.
- The song plays like music: it pauses whatever else was playing, keeps going when the phone locks or Igor goes
  to another app, and the lock screen shows it with play and pause. A phone call or Siri pauses it; Igor resumes it.
- **It plays at its own speed on any output** ([#370](https://github.com/idvorkin/context-grabber/issues/370)). In
  the car, with the phone on the car's hands-free line and the Cockpit just open, the song ran about three times too
  fast: its clock read 0:41 after 14 seconds. Whatever audio route or call-style session was there before, the song
  sounds as recorded, takes its 2:14, and its clock keeps time with the wall clock.
- **A Larry call comes first** ([#197](https://github.com/idvorkin/context-grabber/issues/197)). Starting a call
  pauses the song where it is. While a call is live the song does not start, from the sheet, the small player or
  the lock screen; the sheet says it waits for the call to end, and once the call is over play works again.
- **Open on Suno**, under the player, does what the launcher used to: the app reads the eulogy post
  (idvork.in/eulogy), finds the Suno song it embeds and opens it. Off the network it opens the song it found last
  time; if it has never found one, it opens the post itself and says the song could not be found.
- **Eulogy** (a book) opens idvork.in/eulogy in the browser.
- **Recent** (a clock) opens idvork.in/recent in the browser.
- **Random** (dice), [#259](https://github.com/idvorkin/context-grabber/issues/259), Igor 2026-10-10: *"Add random
  page"*, a random page of the blog. It opens idvork.in/random in the browser, and the blog picks the page, so
  every tap lands somewhere different. It needs the network like the other two links; off the network the browser
  says so, as it does for Eulogy and Recent. Holding it offers a topic
  ([#392](https://github.com/idvorkin/context-grabber/issues/392); the
  [popovers spec](2026-10-18-press-and-hold-popovers-design.md) has the choices); the tap stays random from everything.
- All four are launchers like the others: they can be hidden and moved from the cog. In a phone that already has
  its own order, they show at the end of it until moved.

## Who wins the audio

The rules as they stand, for the song meeting anything else that sounds:

- **The song takes the audio like music** when it starts: whatever else was playing pauses. It lets the audio go,
  telling the others they may resume, when it is stopped with the ✕, when it ends, and when it cannot load or start.
  A pause, from anywhere, keeps the audio: resuming needs nothing back.
- **A Larry call wins.** Starting a call pauses a playing song where it is. While a call holds the audio, a play from
  the sheet, the small player or the lock screen is refused with the sheet's *waits until the call ends*, and the
  song never lets go of the audio either, because the call's audio is the call's. The first play after the call
  clears the line.
- **The card's spoken ask wins too:** the card speaking pauses a playing song.
- **The song's own player beats a Gym Timer workout:** opening it pauses a running workout (the timer's spec has its
  side). A song opened on Suno is someone else's music and plays alongside.
- **A play that is refused is tried twice more** before it is a failure: the same player made ready again at the
  same place, then a fresh player at that place. Only when all three refuse does the sheet show *The song would not
  start.*, and the audio is let go.

## Explaining itself

Each tap is in the session log: playing, pausing, scrubbing (from where to where), restarting, stopping, finishing and interruptions with where the song was, and if the
song cannot play, why. Loading and playing also say what the audio was going out through and at what sample rate,
and if the song's clock runs away from the wall clock while it plays, the log says by how much (#370). A song that cannot load or start says so in its sheet with *Copy error*, which copies the
message, the build, where the song was, the audio session's state and the underlying error
([#201](https://github.com/idvorkin/context-grabber/issues/201)), and lets the audio go, so whatever it paused plays
again (a live call keeps its audio). For *Open on Suno*: which song it opened and whether it came from the post just now, from
last time, or fell back to the post.

## Acceptance criteria

- The four launchers appear on the home screen and open what they name; two taps on Random usually land on two
  different pages.
- Eulogy song plays the song inside the app, offline included; it keeps playing with the sheet closed and the
  phone locked, and the lock screen can pause it.
- Pause, close, reopen: the sheet shows the same place and resumes from it.
- With a call live, the song will not play and says why; starting a call pauses a playing song.
- Dragging the scrubber moves the song there; restart plays it from the start.
- Played right after the car's hands-free line or the Cockpit held the audio, the song plays at its own speed and
  its clock keeps time with the wall clock.
- With the sheet closed, the small player shows while the song plays or is paused partway; its play/pause works
  in place, a tap opens the sheet, its ✕ stops the song and hides it.
- Open on Suno opens the song the post embeds today; offline, the last one found; never found, the post, and says so.
