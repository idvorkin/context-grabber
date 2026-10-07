# Native Eulogy, its song, and Recent — Design Spec

Issue [#177](https://github.com/idvorkin/context-grabber/issues/177). Igor, 2026-10-06: *"grab my eulogy song from
my blog and have a link to play it. Maybe definitely have a eulogy link and a browser link to recent. Those are
probably things I do every day."* Story [137](../../stories/07-widgets-and-links.md#user-story-137). Part of the
[Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

Three daily things from Igor's blog become launchers on the home screen: **Eulogy song** plays the song embedded
in his eulogy post, **Eulogy** opens the post, **Recent** opens the blog's recent changes.

## Goals

- One tap from the home screen to each.
- The song is whatever the eulogy post embeds today: change the post and the app follows, with no new build.

## Non-goals

- Playing the song inside the app. Suno does not hand its audio to other apps (the song page says the audio is
  forbidden), so the app opens the song on Suno — the Suno app when it is installed, the browser otherwise — where
  one more tap plays it.
- Reading the blog inside the app; a feed of recent posts.

## What Igor sees

- **Eulogy song** (a music note). The app reads the eulogy post (idvork.in/eulogy), finds the Suno song it embeds
  and opens it. Off the network, it opens the song it found last time; if it has never found one, it opens the
  eulogy post itself and says the song could not be found. If the post no longer embeds a Suno song, the same.
- **Eulogy** (a book) opens idvork.in/eulogy in the browser.
- **Recent** (a clock) opens idvork.in/recent in the browser.
- All three are launchers like the others: they can be hidden and moved from the cog. In a phone that already has
  its own order, they show at the end of it until moved.

## Explaining itself

Each tap is in the session log, and for the song: which song it opened and whether it came from the post just now,
from last time, or fell back to the post.

## Acceptance criteria

- The three launchers appear on the home screen and open what they name.
- Changing the song embedded in the eulogy post changes what Eulogy song opens, without a new build.
- Offline, Eulogy song opens the last song found; never having found one, it opens the post and says so.
