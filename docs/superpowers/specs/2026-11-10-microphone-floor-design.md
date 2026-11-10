# One microphone, one holder

Audit of 2026-11-10, finding 4 (the follow-up to [#802](https://github.com/idvorkin/context-grabber/issues/802), which
put who gives way to whom over the audio session in one table): four things in the app record from the microphone,
and the rules between them were written one pair at a time. A call refused chat's dictation and the report's, and
chat's recording refused the report's (#559: two recognizers at once kill the first), but nothing said what happens
between the board's mic and either dictation. On an iPad, Chat and a board sit side by side.

## Summary

The microphone has one holder or nobody. Anything that wants to record asks first, and is either let in or told who
has it. A call beats everyone; anyone else waits for whoever got there first.

## Who records

- **A call with Larry**, from the moment it starts to its end.
- **Chat's dictation**: the mic in a thread's bar, from its tap until the words settle.
- **The report's dictation**: the mic in the shake-to-report dialog, while the dialog is up.
- **The board's mic**: the whiteboard's microphone, from its tap until it closes.

## Who wins

| Asking ↓ / holding → | a call | chat's dictation | the report's dictation | the board's mic |
|---|---|---|---|---|
| **a call** | carries on | takes it: the recording stops, the words so far stay in the bar | takes it | takes it: the mic closes, its last words still go |
| **chat's dictation** | refused: *"A call with Larry is using the microphone. End it to speak a message."* | carries on | refused, with a line saying another recording has it | refused (see *Not yet*) |
| **the report's dictation** | refused (#239) | refused (#559) | carries on | refused (see *Not yet*) |
| **the board's mic** | refused: *"A call with Larry is using the microphone. End it to talk to the board."* | refused (see *Not yet*) | refused (see *Not yet*) | carries on |

- **A call takes the microphone from anyone.** Starting a call (or a call going live) stops whoever was recording, as
  each one's own stop would: chat's words so far stay in its bar with a line saying the call took the mic, the
  board's last words still go.
- **Otherwise the first one keeps it.** A second recorder asking while another records does not start, and says
  why; it never stops the one that was there first.
- **The holder lets go when it stops**: chat's recording settling, the report dialog closing, the call ending, the
  board's mic closing. A recorder that never got going (a permission refused, a recognizer that would not start)
  holds nothing.
- Playback (the timer's cues, the breathing's, the eulogy song, the card's voice) is not recording, and keeps its own
  rules: a call refuses or pauses each as before.

## Not yet: the board's mic

The board's mic still checks only the call for itself. Until its screen asks the same question as the others (its
rewrite is in flight, #821), the floor cannot see the board recording: chat's dictation or the report's started
while the board's mic is on is not refused, and the board's mic started while either dictation records is not
refused either. The rows above are what it will do.

## Acceptance criteria

- With chat's dictation recording, starting a call stops the recording, keeps the words so far in the bar and says
  the call took the mic; the call's own mic works.
- During a call, chat's mic and the report's mic each refuse with a line naming the call; neither records.
- With chat's dictation recording, the report dialog's mic refuses to start, and chat keeps recording.
- After chat's recording settles, or the report dialog closes, the next recorder to ask gets the mic.
- (After #821) on an iPad, with chat's dictation recording beside a board, the board's mic refuses to start, and
  the other way round.
