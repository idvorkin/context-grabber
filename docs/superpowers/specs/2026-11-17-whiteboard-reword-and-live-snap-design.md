# Rewording a kept text, and a snap you see before you lift

Status: draft for Igor, 2026-11-17 (stories 940–944). The two things the 2026-11-16 spec
([Handwriting to text, and shapes that snap](2026-11-16-whiteboard-to-text-and-snap-design.md)) left for later, as
Larry's web board `/ink` already does them (cockpit FEATURES.md, *Ink*; `rewordText` and the shape cleanup's preview in
cockpit `assets/ink/`). Larry ranked them third and fifth of the board's missing pieces.

## The idea in one line

Tap a kept text twice with a finger and type: its words change where they are. Hold the Pencil still at the end of a line, a
box or a loop: the clean shape shows at once, and lands when you lift.

## Why

- A kept text (one of Larry's he kept, a To text result, or one Igor typed) is fixed today: to change a word he erases
  the whole text and starts again. The web board has an editor for it.
- The snap lands only on lift, so Igor can't tell, while holding, whether the stroke is going to snap, or to what. The web
  board shows the clean shape while the pen is still down; he lifts to keep it or moves on to keep drawing.

## What Igor sees

### Rewording a kept text

- **The first finger tap on any kept text selects it; the second opens it** (context-grabber-awz; Igor, 2026-11-22:
  "a second tap rewords a text"). A finger tap on a kept text (on its letters, or within a finger's width of them) on a
  board drawn on here picks it up: the text alone is selected, ready to drag, and the selection's label says *Text · tap
  to reword*. A second tap on it, while it is still selected, opens it for editing in place: a text field over the text,
  where the text is, its words in it, the keyboard up. The same holds for every kept text: Igor's own typed or To text
  text, a text of Larry's, and one inside a group (which the first tap picks up with its whole group, #1171, #947; the
  shapes spec, *A finger tap on anything of Larry's he kept*), whether or not one of his controls shows (bead
  context-grabber-9d1). A drag after the first tap moves the text where the finger goes, down as well as across, and
  opens nothing. A tap on one of Larry's marks
  still chooses the mark; a tap in the margin is still the margin's; a look-only board opens nothing. A tap on one of
  his controls is the control's, even over a kept text: it neither selects it nor opens its words. Inside a bigger
  selection of his own the tap is the selection's (the shapes spec, *What the tap lands on inside it doesn't matter*).
- **A drag that starts inside a selection moves it, however small it is** (bead context-grabber-vhae). The system's
  corner handles, which stretch a selection, take any touch near them, so on a text of a few letters they cover the
  whole word, and a drag straight down on it stretched it sideways instead of moving it. Now a finger that goes down
  inside the selected thing's box and drags moves it: while the finger is down the word still stretches under it, as
  the system draws it, and on the lift it lands moved by the finger's travel, down and across, at its own size. One
  Undo, named *Move*, puts it back; a drop onto ink below still makes room (story 973). A drag that begins on a corner
  handle's own knob, or outside the box, still stretches it, and a bigger selection, whose middle no handle covers,
  moves and stretches as before.
- A tap on ink that isn't a kept text, or on blank paper, does what it did before. The Pencil writes as ever: a Pencil
  tap on a text is a dot, not an edit.
- He edits the words. Return, or a tap anywhere off the field, is *done*. A Return is done however it arrives: typed on
  its own, or together with other letters at once (fast typing, a paste or dictation that ends in a line, a busy
  device); the letters stay and the new line doesn't. Only a change that ends in a line is done: a paste with a line
  break inside it keeps that break and the field stays open. The text's own line breaks stay.
- Done with new words: the text is drawn again with them, from the same top-left, in its own lettering, letter size and
  colour, wrapped by word to its width. Its width is the wider of how wide it was and the web board's text width (480
  board points), but never past the page's right edge; a word longer than a line is broken. A text keeps its own line
  breaks. At most 500 characters, as for any text.
- It is still the same text to Larry: its id is kept, he gets its new words back under that id, and he hears the change
  as a strokes change naming it as reworded.
- Done with the words emptied: the text is deleted.
- Done with the words unchanged: nothing changes, and there is no undo step.
- One Undo brings the old words (or the deleted text) back; Redo makes the change again.
- If the text went while the field was open (Larry moved it away, an undo), done changes nothing and the board's note
  says *The text went while it was being edited*.
- If the board can't draw the new words (nothing in them has letters, as an emoji alone), the text stays as it was and
  the note says *Nothing in that text can be drawn*.

### A snap you see before you lift

- He draws a stroke that is nearly a line, a rectangle or an ellipse and holds the Pencil still at its end for about half
  a second (it moves less than 5 board points). At once, with the Pencil still down, the stroke shows as the clean shape
  in his pen's colour and width, the wobbly one hidden under it.
- Lifting there keeps the clean shape: it lands as the snap does today (his ink, colour and width, one undo back to the
  raw stroke).
- Moving the Pencil on before lifting puts the raw stroke back, and drawing goes on as usual. Holding still again at
  the new end shows the clean shape again, if the longer stroke is still nearly one; lifting without a new hold leaves
  the raw stroke.
- A stroke that isn't nearly a shape shows nothing while held and stays ink on lift, as today. Writing never snaps.
- The rules and thresholds are the 2026-11-16 spec's, unchanged; only the moment it shows has moved.

## Acceptance criteria

- A first finger tap on a kept text selects it (*Text · tap to reword*, ready to drag); a second opens its words in
  place; Return or a tap off it applies them: re-wrapped at the same
  top-left, same id to Larry, one undo back to the old words. Empty words delete it; unchanged words change nothing.
- A finger drag that starts inside a selection, even a one-word text, lands it moved by the finger's travel down and
  across, at its own size, on the lift (it stretches under the finger until then); one Undo puts it back; its corner
  handles still stretch it from their knobs or from outside the box.
- A held stroke that is nearly a shape shows clean while the Pencil is still down; lifting keeps it, one undo back to
  the raw ink; moving on brings the raw stroke back.

## Not in this step

- Making room below when the new words are taller than the old: the web board slides the ink below down. Here a text
  that grows may overlap ink under it; Tidy overlaps or a margin drag makes room.
- Rewording with the Pencil (Scribble into the field works, as in any text field; a Pencil tap on a text stays a dot).
- Changing a text's lettering, size or colour.
- A small selection that follows the finger while dragged from inside, rather than stretching until the lift (bead
  context-grabber-ppha, for Igor to choose once he has felt the lift's move on the iPad).
