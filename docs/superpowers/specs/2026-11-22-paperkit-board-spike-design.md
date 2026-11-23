# The PaperKit board (a spike)

This spike lets Igor try PaperKit's drawing tools before deciding what belongs on the whiteboard. See
[stories 1217–1219](../../stories/10-whiteboard-boards.md#user-story-1217) for implementation and verification status.

Igor, 2026-11-22 22:02 (via Larry): "Upgrade from PencilKit to PaperKit on the whiteboard app and try to use all the
different pen types and callout types… I want the fountain pen for sure. What are all my pens, all my shapes? Can I do
callouts and arrows and link arrows between things?"

## What's true today

- The board already draws on Apple's PaperKit and already allows every ink, the fountain pen included.
- It turns PaperKit's other content **off**: shapes, callouts, text boxes, images, stickers, magnifiers and links. A box,
  circle or arrow on the board is Igor's ink, snapped clean by the board itself.
- PaperKit's arrows are free lines. A line or arrow doesn't stay attached to a box when the box moves. PaperKit has no
  connectors.

The full inventory, taken from this Mac's iOS 27.2 SDK, is in the bead.

## What Igor sees

- On the iPad, Settings (the Home screen's gear) → *About and diagnostics* has a new row: **PaperKit board**. The
  iPhone, which only looks at boards, doesn't show it, and nor does the Mac, which has no Pencil.
- It opens a blank page with everything PaperKit offers turned on:
  - **Pens:** pen, pencil, marker, monoline, fountain pen, watercolor, crayon and reed. The pen in hand when the page
    opens is the **fountain pen**, thinner than PencilKit's own: 60% of its default width, with the nib held at 45°
    (Igor, 2026-11-22: "a bit thick"). The picker's fountain pen starts at the same width and angle; other widths are
    still one tap away in the picker.
  - The picker also has an eraser, a lasso and a ruler.
  - **Shapes**, from the tool picker's **+**: rectangle, rounded rectangle, ellipse, line, speech bubble (the callout,
    with a tail you can aim), polygon, star and block arrow. Fill, outline and opacity can each be changed.
  - **Lines and arrows:** a plain line, an arrow, or a line with arrowheads at both ends. Lines can bend.
  - **Text boxes**, and text typed inside a shape.
  - **Images, stickers, a magnifier (loupe) and links.**
- Closing the scratch page discards its contents. Reopening starts with a blank page.
- See [PaperKit board events](../../debugging/whiteboard.md#the-paperkit-board) for the session log fields. The opening
  line names the pen in hand: its ink, width, PencilKit's default width for that ink, and the nib angle.

## Non-goals

- The scratch page is separate from the saved whiteboard and Larry's conversation.
- No connectors. PaperKit has none, and faking them on the scratch pad would only tell us about the fake.

## How the board's objects would map onto PaperKit (if the board moved onto its elements)

| Board object | PaperKit element | Fits? |
|---|---|---|
| Igor's ink | PencilKit strokes in the page's element list (iOS 27 stroke ids are stable) | Yes, as today |
| Larry's marks (ghosts), Larry's kept groups | Strokes or shapes, each with per-element locks (move only, read only) | Partly. PaperKit has no "group" or "reply": the board would still keep which elements belong to which reply. |
| Larry's boxes, circles and arrows | Shape elements: a rectangle, an ellipse, a line with an arrow end | Yes. They'd become real shapes, editable as shapes instead of snapped ink. |
| Kept texts (Larry's words written as ink) | A text box, or text inside a shape | Changes the look. Today they're handwriting-like ink, and a text box is typed text. Igor's call. |
| Connectors (an arrow linking two things) | None. A line whose ends are plain points. | No. The board keeps the link and redraws the line when an end moves, as it does today. |
| Headers and folds (the outline) | None. A fold hides a run of rows. | No. It stays the board's own, drawn over the page. |
| Rows (the ruled page and the room between lines) | None. PaperKit has no lines or rows. | No. It stays the board's own paper beneath the page. |
| Question cards | An adornment (a tappable badge, iOS 27) for the marker, the card itself the board's | Partly |
| The callout Igor asked for | The speech bubble shape | Yes |

In short, pens and shapes would move straight over. Groups, connectors, folds and rows are the board's own ideas, and
would stay the board's whatever PaperKit draws.

## Acceptance criteria

- On the iPad, Settings → *About and diagnostics* → **PaperKit board** opens a blank page whose pen is the fountain pen
  at 60% of its default width with the nib at 45°, and the session log says so.
- The tool picker offers all eight pens. Its **+** offers every shape (the speech bubble among them), a text box, and
  lines with and without arrowheads.
- A shape or arrow drawn there can be selected, moved, resized and restyled.
- Closing the page leaves no trace on any board.
- On the iPhone and the Mac the row isn't there.
