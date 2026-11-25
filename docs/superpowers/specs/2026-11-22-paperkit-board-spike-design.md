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
    opens is the **fountain pen**.
  - The picker also has an eraser, a lasso and a ruler.
  - **Shapes**, from the tool picker's **+**: rectangle, rounded rectangle, ellipse, line, speech bubble (the callout,
    with a tail you can aim), polygon, star and block arrow. Fill, outline and opacity can each be changed.
  - **Lines and arrows:** a plain line, an arrow, or a line with arrowheads at both ends. Lines can bend.
  - **Text boxes**, and text typed inside a shape.
  - **Images, stickers, a magnifier (loupe) and links.**
- **The tool picker and its +** show the moment the page opens, with nothing tapped first, and a **finger draws** on it
  as well as the Pencil, so the shapes are reachable without one. (Igor, 2026-11-22 23:09, on build 5569178f: "Nothing
  there?" The page had opened with no picker; a finger tap drew nothing. Bead context-grabber-wvpv.)
- Closing the scratch page discards its contents. Reopening starts with a blank page.
- See [PaperKit board events](../../debugging/whiteboard.md#the-paperkit-board) for the session log fields.

## Only ink is kept on a real board (bead context-grabber-lyr4)

A real board keeps Igor's ink and its meaning, nothing else. A shape, callout, text box, image, link or magnifier isn't
saved, and would vanish when the board reopens. So a real board offers none of them:

- A real board's tool picker has no **+** and no way to insert a shape, a text box or an image. The pens, eraser, lasso
  and ruler are the whole picker. Only the scratch page above, which keeps nothing, offers the **+**.
- If anything that isn't ink turns up on a real board anyway, by any route, the session log names it by kind (shape,
  image, link, magnifier) as it appears, and again when the board saves without it, so a loss is never silent. The same
  check says when two strokes share one id, which the board's tally of strokes would count once.
- Bringing shapes and text to real boards is one switch: the set of PaperKit features a real board allows. It stays at
  ink alone until a board keeps the other kinds when it saves (the Cockpit board store, cockpit-8kh, or the iCloud save).

The iPad's logs show four boards that each held one element more than their tally of strokes, none saved
(`paper_not_ink`). A real board never had the **+**, so what that element was isn't known yet. The census above names
its kind the next time.

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

- On the iPad, Settings → *About and diagnostics* → **PaperKit board** opens a blank page whose pen is the fountain pen.
- The tool picker shows as soon as the page opens, without a tap, and a finger stroke draws.
- The tool picker offers all eight pens. Its **+** offers every shape (the speech bubble among them), a text box, and
  lines with and without arrowheads.
- A shape or arrow drawn there can be selected, moved, resized and restyled.
- Closing the page leaves no trace on any board.
- On the iPhone and the Mac the row isn't there.
- A real board's tool picker offers no **+**, no shapes and no text box.
- Anything on a real board that isn't ink is logged by kind as it appears and when the board saves without it; two
  strokes sharing one id are logged the same way.
