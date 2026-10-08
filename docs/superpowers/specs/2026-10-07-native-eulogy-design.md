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
- A playlist, a scrubber, or speed controls. Play, pause and where it is are enough.
- Reading the blog inside the app; a feed of recent posts.

## What Igor sees

- **Eulogy song** (a music note) opens a small sheet titled *How Igor wants to live* and starts the song. The
  sheet shows a play/pause button and how far through it is (elapsed and total). Closing the sheet leaves the song
  playing; tapping *Eulogy song* again brings the sheet back where the song is, without starting over. When it
  ends, the button offers to play it again from the start.
- The song plays like music: it pauses whatever else was playing, keeps going when the phone locks or Igor goes
  to another app, and the lock screen shows it with play and pause. A phone call or Siri pauses it; Igor resumes it.
- **Open on Suno**, under the player, does what the launcher used to: the app reads the eulogy post
  (idvork.in/eulogy), finds the Suno song it embeds and opens it. Off the network it opens the song it found last
  time; if it has never found one, it opens the post itself and says the song could not be found.
- **Eulogy** (a book) opens idvork.in/eulogy in the browser.
- **Recent** (a clock) opens idvork.in/recent in the browser.
- All three are launchers like the others: they can be hidden and moved from the cog. In a phone that already has
  its own order, they show at the end of it until moved.

## Explaining itself

Each tap is in the session log: playing, pausing, finishing and interruptions with where the song was, and if the
song cannot play, why. For *Open on Suno*: which song it opened and whether it came from the post just now, from
last time, or fell back to the post.

## Acceptance criteria

- The three launchers appear on the home screen and open what they name.
- Eulogy song plays the song inside the app, offline included; it keeps playing with the sheet closed and the
  phone locked, and the lock screen can pause it.
- Pause, close, reopen: the sheet shows the same place and resumes from it.
- Open on Suno opens the song the post embeds today; offline, the last one found; never found, the post, and says so.
