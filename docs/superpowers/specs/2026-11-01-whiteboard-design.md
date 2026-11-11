# Whiteboard with Claude

Igor, 2026-11-01: "can we do an ipad whiteboard app (on phone it should be viewable), and I want the interface with
draw with the pen (and eraser) … minimum you take input … but I think you extend my drawing like we both draw
together and maybe you get voice input, and need a back link to larry too while doing this." The brainstorm ran on a
Lavish page with a working board: four rounds of drawing, and Igor's answers to the open questions. Stories:
[10-whiteboard.md](../../stories/10-whiteboard.md).

## Goals

- **A board on the iPad.** Draw with the Pencil and erase. Drawing should feel as good as Notes, because it's the
  same ink.
- **Room to keep going.** The board doesn't end at the bottom of the screen. It's a column of pages, like Notability,
  and there's always another blank page below the last ink.
- **Larry sees it.** One button sends the board to Larry on the board's chat thread with the picture attached. His
  reply arrives in Chat, like any other thread, and his marks on the board.
- **Then we draw together.** When Igor lifts the pen, faint suggestions appear on the board. A tap keeps one, and
  a tap off them dismisses the rest (Igor's pick: ghost suggestions, "b + c"). Igor's voice steers the suggestions.
  A later step: Larry draws during a call.
- **The phone only looks.** Boards drawn on the iPad can be seen on the phone, and nothing is drawn on a phone (Igor,
  2026-11-10: "too hard to draw on the whiteboard on the iPhone ... we can't do hand drawing"). Talking about a board
  stays: its thread is in Chat on the phone like any other.

## Non-goals

- No shapes palette, layers, text boxes or templates. The Pencil and the tool picker are the whole drawing interface;
  [pasted text](2026-11-02-whiteboard-paste-design.md) lands as ink, not a text box.
- Not a notes app: boards have a name and a picture, with no folders, tags or search.
- No two devices drawing on one board. A board is drawn on the device that made it, and every other device shows it
  read-only, so there's never a conflict to merge.

## What Igor sees (v0: this build)

### The boards (Igor, 2026-11-01: "I should see each whiteboard as a list"; "on iPhone should see what was drawn, probably read only")

- A **Whiteboard** tile on home. It opens **the boards**: a list of rows, newest change first, on the iPad and the iPhone
  alike. Each row shows the board's picture, its name, and when it last changed. A board from another device also says
  where it was drawn ("Drawn on iPad").
- **+ New board** (not on an iPhone, which only looks) opens a fresh, empty board named for the day (*Board, Nov 1*; a second that day is *Board, Nov 1
  (2)*). A new board that's left without a stroke is gone when it closes, so empty boards never pile up.
- A **swipe left** on a row offers *Delete*, as Chat's rows offer their actions; a **long press** offers it too, and
  *Rename* on a board drawn on this device. (Igor, 2026-11-02, #613: "I need to be able to delete boards", from the
  iPhone, where a long press on an iPad board only opened it.)
- **Any device can delete any board.** Delete asks first, there's no undo, and the board leaves every device: this one
  at once, the others the next time they sync, even one that was off when the delete happened. Only the device that
  drew a board can rename it.
- **New ink beats a delete from elsewhere.** If the iPad has drawn on a board that hasn't reached iCloud when it learns
  the iPhone deleted that board, or has that board open, nothing is thrown away: what's unsent goes up and the board
  comes back on every device. A board the iPad has open and leaves without drawing on then goes. A delete covers only
  what the deleting device had seen: ink that reached iCloud after that, even days before a delete made offline gets
  there, keeps the board, and it comes back on every device.
- A chat picture's *Jump to board*, or a link, on a deleted board shows a copyable problem saying so.
- A device that hasn't been told of a delete, or that lost its way to iCloud or changed iCloud account, keeps its own
  boards: only a delete asked for on a device removes a board from the device that drew it.
- **Every device signed into Igor's iCloud sees every board.** A board saved on the iPad appears in the iPhone's
  list the next time the list opens or the app comes forward. It's usually there within a minute, and a pull on the
  list fetches it straight away.
- **Read-only elsewhere:** a board opens for drawing only on the device that made it. On any other device it opens
  to look at: pan and pinch, no tool picker, and a note in the bar saying where it's drawn.
- **On an iPhone every board is look-only**, its own included (Igor, 2026-11-10). The list has no *+ New board*;
  every board opens to pan and pinch, with no tool picker, no Board menu and no ghosts, and the bar says *Look only on
  iPhone: draw on the iPad*. *Send to Larry* stays, as on any look-only board: a board can still be talked about
  from the phone (Igor: "Maybe we can do chat"). Delete and, on the iPhone's own boards, Rename stay in the list. A board the iPhone drew
  before this keeps its ink and opens look-only like the rest.
- **Without iCloud** (signed out, or no network), the list shows what this device already has and says that boards
  aren't syncing. Drawing still works, and the board goes up the next time it can.
- **The board drawn before the list existed** becomes the first board in the list, and nothing on it is lost.
- **A reinstall** gives the device a new identity, so its old boards come back read-only there. Taking a board
  over on a new device is a later step.

### One board
- The **tool picker** sits along the edge: pen, marker, pencil, eraser, lasso, ruler, undo and redo, and colors.
  This is the system's own picker, so the Pencil's double tap or squeeze switches to the eraser, as it does in
  Notes.
- **Who draws:**
  - With a Pencil paired, only the Pencil draws, and a finger moves the board. A palm resting on the glass never
    leaves a mark.
  - Without a Pencil (an iPad with none paired), a finger draws and two fingers move the board.
  - This follows the system's "Only Draw with Apple Pencil" setting.
- **The board is a column of pages** (#636; Igor, 2026-11-03: "the board is way too big maybe do the set up like
  Notability"; he chose page-width over sideways growth).
  - A page is 820 points wide and about 1,060 tall, paper's shape. On an iPad held upright, writing stays the size it is
    today; held sideways, the page fills the width and writing looks bigger.
  - The board scrolls up and down only. There's no pan into empty space sideways.
  - There's always one blank page below the last ink, so he never runs out of room and never has to add a page. A new
    board is that one blank page; the first ink on it brings the next. Ink that stops at a page's end leaves the page
    below blank, and ink past it brings another page. That's about how far ink reaches. Asked which page one place is
    on, a place exactly on the line between two pages is on the lower one.
  - Pinching out stops when the page fits the screen's width; pinching in goes up to 3× for detail, and only then can
    he move sideways, within the page.
  - A faint line marks where each page ends. It isn't ink, like the grid, and ink can cross it: a stroke that crosses
    stays one stroke.
  - **A page number** floats at the corner: *Page 2 of 3*, for the page mostly on screen. It stays put while the board
    scrolls, stays out of the way of drawing, and isn't in any picture.
  - A board opens where he left it on this device, or at its first page if it's new to this device.
  - **Boards from before pages** move onto pages the first time they open once that step ships (see *On paper* below for
    the order). No stroke is scaled or lost and each stays in the same place relative to the others, with a little blank
    paper between the ink and the first page's corner. A board with ink wider than a page keeps its own wider width, and
    can pan sideways to that width. Every page on that board is that width and still about 1,060 tall. Anything Larry or
    Claude drew on it stays on the ink it was drawn beside.
  - **A mark past the page edge** widens that board, by the same rule as wide ink. Nothing is clipped.
- **Grid lines** (Igor, 2026-11-02: "Let's give me the ability to enable grid lines"; #608). *Grid lines*, in the **Board**
  menu with the colours, turns faint lines on and off, on the device that draws the board.
  - **Ruled paper** (#635; Igor, 2026-11-03: "I still want Lines" meant paper lines). The same menu also offers *Ruled
    lines*: faint horizontal lines like notebook paper. A board has a grid, ruled lines or neither. Everything below about
    the grid holds for ruled lines too. Every page is ruled the same: the first line sits one line down from the page's
    top, and the lines are as far apart as the grid's squares (40 points; provisional until Igor has seen them), so
    they restart at each page and a line never lands on the page's end.
  - Off until asked, and remembered per board on this device: a board opened with its grid on opens that way again, and
    a new board starts without one.
  - The lines belong to the board: they pan and pinch with the drawing. They're so faint that ink crossing one reads
    as unbroken, though they lie over the ink, not under it. Pinching out thins them
    to every second line, then every fourth and so on, so they never crowd together; the lines that stay are lines
    that were already there. They stay one hair wide at any zoom, in a grey that shows on a light or a dark background
    without competing with ink.
  - The grid isn't ink. It can't be erased, lassoed or undone, it isn't in the saved drawing or the board's card, and
    another device's board doesn't change for it.
  - **Claude and Larry don't see it.** Their pictures, and Send to Larry's, are the ink alone, so what comes back is
    drawn to the marks and not fitted to the squares.
  - Drawing and panning feel the same with the grid on as with it off, even on a big board.
- **The board is kept.** Leaving, quitting or restarting the app never loses a stroke, and neither does a link that
  opens another screen. The board saves a moment after each stroke, and again on close or when the app goes to the
  background. On paper, VoiceOver hears with the page number whether the latest ink is saved yet: *Page 1 of 2, unsaved*,
  then *saved* (the UI tests wait on it, story 673). If a saved board can't be read, it's kept aside and the screen says so; if it can't even be moved
  aside, it's left untouched, nothing drawn that time is saved over it, and the screen says that too.
- **Send to Larry** (top bar): sends a picture of everything drawn, on white, on the board's chat thread, titled with
  the board's name: the first send or Larry's turn on a board starts the thread, and later ones go to it, so marks he
  draws in answer come back to the board.
  - The bar says *Sent to Larry: his reply shows in Chat*. One send makes one message: the button stays disabled
    until the next stroke, or on paper until other pages are on screen, so a second tap never sends the same
    picture twice.
  - With no network, the board waits in the Inbox outbox like any other message and goes when the network is back.
  - An empty board can't be sent; the button is disabled.
  - **The picture shows the page or pages on screen** (#636; Igor, 2026-11-03), so what he's looking at is what Larry
    reads, with his writing at a size Larry can see. Scroll to another page and send again to show Larry that one. The
    same goes for *Larry's turn*. An empty page on screen is left out of the picture; if everything on screen is empty,
    there's nothing to send and the button says so by staying disabled. Claude's own turns keep looking at what they
    look at today. Larry's marks land by the picture's own place on the board, whichever page that is.
  - **The picture frames its ink at a readable size** (stories 420, 422, 425, 429; Igor, 2026-11-03: "maybe zoom into the pages").
    It spends about four million pixels on whatever shape the drawing is, never finer than the screen and never past
    8,000 pixels on a side, so a tall column of notes keeps its handwriting legible instead of shrinking to a
    248-pixel-wide sliver. The board's strokes go with it (the shapes spec), which is what Larry reads when he can.
- **Back** (top bar) closes the board and returns to the boards, where **Done** leaves the Whiteboard.
- **The board's colour** (Igor, 2026-11-02, #607: "Give me the ability to change background colors"): a
  **Board** menu in the top bar, on the device that draws the board, offers five colours: *Plain*, *Cream*, *Sage*, *Lilac* and
  *Grey*. On a width as narrow as an iPhone's, the menu sits at the bottom of the screen, so the top bar's buttons stay
  in view and don't move under *More*.
  - **Each board keeps its own colour.** It's remembered with the board and goes through iCloud with the drawing, like
    its name. A new board starts on Plain. Choosing a colour moves the board to the top of the list, as a rename does.
    A colour that hasn't reached iCloud beats a delete from elsewhere, as new ink does.
  - **Each colour has a pale shade and a deep one**, so black ink, which turns white in dark mode, stays easy to read
    when the iPad changes mode. Plain is white in light mode and black in dark mode, as every board was before.
  - **Ghosts stay visible on all of them.** No colour is orange or blue, and a faint orange or blue ghost on any colour
    is at least nine-tenths as visible as it is on Plain.
  - **A colour alone doesn't keep an empty board.** A new board left without a stroke still goes when it closes, whatever
    colour was chosen.
  - **Other devices show the same colour**, in the look-only view, shaded for that device's own mode. They can't change
    it. A board already open there shows a new colour the next time it opens, as it does a new drawing.
  - **The row** in the list has the colour's pale shade behind the board's picture, as the picture's ink is always dark.
  - **Claude and Larry always get dark ink on white**, whatever the colour and the mode: the colour is for Igor's eyes,
    and every picture they read stays the same. So a mark of theirs lands the same on any colour.

## On paper: the default

Igor tried the trial on his iPad on 2026-11-03: "Okay, I like that. Let's make it the default." He meant the board on
Apple's PaperKit. His earlier decisions stand: a column of page-width boards with paper lines, old boards moving onto
pages, strokes that never scale, and Larry seeing the pages on screen.

**Paper is the only canvas** (Igor, 2026-11-07: "get rid of old canvas, only use new paper code. Old canvas can be erased").
Every board is drawn on paper. The old canvas, its switch and the trial are gone.

- **A board drawn on the old canvas is look-only** (Igor's choice, 2026-11-07). It opens on paper with every stroke where it
  was and its colour, can be panned and pinched and deleted from the list, as any look-only board can, but not drawn on,
  erased, pasted on, sent or given ghosts. The bar says *Drawn on the old canvas: look only*. Its row in the list doesn't say *On paper*.
  To keep drawing on one, Igor starts a new board.
- **A board on paper from another device** stays look-only on this one, as every board is, now shown on paper.

**The app needs iOS 27 from here on.** Reading ink back out of PaperKit starts there, and Igor's iPhone and iPad both run
it. Nothing else about the app changes with this, and a device on an older system would stop getting new builds.

**What's saved doesn't change.** Boards keep saving strokes in today's file format, so older builds open every board and
nothing has to migrate. The cost, from the same proposal: anything PaperKit could add, such as shapes or text boxes, wouldn't
stay an editable object once saved. That fits the non-goals above.

**What differs on paper.** Page lines, ruled lines and the grid lie under the ink, not over it. Everything else about pages, lines and
pictures reads as written above. The trial's small cross on each page and its ring are there only to test with, and never
appear on a real board.

**What a finger does on paper isn't settled.** *Who draws* above describes the old canvas. PaperKit has no mode where a finger
only pans, and four finger drags aren't enough to go on, so the next try on the iPad has to settle it before a story can
claim anything about fingers.

### A new board on paper, by default

(Igor, 2026-11-03: "Let's make it the default." And 2026-11-04, from the iPad, #671: "Why is Try on paper not the default? Make it
so." New boards are on paper from now on, on every device, though the rest of the rollout above isn't built.)

- **No switch.** A board made with **+** is always on paper. The boards list's *New boards on paper* menu is gone (2026-11-07).
- **What a board on paper is.** The column of pages described under *One board*: 820 wide, about 1,060-tall pages, pinching
  out stopping at the page's width, faint page lines under the ink, *Page 1 of 1* at the corner, and always a blank page
  below the last ink. No test cross and no ring. Its row in the list says *On paper*.
- **It's a real board.** It keeps its name and colour, can be renamed and deleted, saves a moment after each stroke and again
  on leaving or going to the background, goes through iCloud, and leaves no row behind if it closes without a stroke. It
  opens where he left it on this device.
- **On another device** it opens look-only, on paper, with the same ink. Older builds show it on their old canvas.
- **If a save fails,** the board shows the copyable problem and keeps drawing. If the failure comes as he leaves the board,
  the problem shows on the boards list instead of going with it, whichever canvas the board is on, until that board next
  saves.
- **Always light, for now.** While a board on paper is on screen, the whole screen is in light mode, even with the device in
  dark mode: its colour's pale shade, and dark ink. The boards list goes back to the device's mode. On the simulator, PaperKit in dark mode drew new black ink black, so it couldn't be
  seen. This differs from *Each colour has a pale shade and a deep one* above until PaperKit's ink follows the mode, and it's
  Igor's to overrule. What's saved is the same either way.
- **Grid and ruled lines.** The **Board** menu offers *Grid lines* and *Ruled lines*, as *Grid lines* above describes: a grid,
  ruled lines or neither, choosing one takes away the other, off until asked, and remembered per board on this device. They lie
  under the ink and the ghosts, on every page. The grid's squares run on unbroken from page to page; ruled lines start again at
  each page's top. Pinching out thins them as it does on the old canvas, so a phone showing a whole page's width shows every
  second line. Neither is ink: they can't be erased, lassoed or undone, and they're not in the saved drawing, the card or any
  picture.
- **Colour on paper.** A board on paper has the five colours, kept and shared as *The board's colour* says, in their pale shade
  for the reason under *Always light*. Page lines, the grid, ruled lines and ghosts all show on each of them.
- **Changing the colour or the lines leaves the ink alone.** Ink already on screen stays on screen, where it was, the view
  doesn't move, nothing is added to undo, and the board's stroke count doesn't change.
- **The Board menu never costs a stroke.** The first stroke after the menu closes draws, whether something was chosen or not.
- **What a board on paper can't do yet.** *Send to Larry*, *Larry's turn*, ghosts, the mic and paste work: see
  *Ghosts and Larry on paper* and *Paste on paper*. The picture is still the whole drawing.
- **Undo and a new page.** Adding a page can count as a step of undo: one press may take back the page and not a stroke.
  The next stroke brings the page back. Whether this matters on the iPad is still to be seen.

The log says which touches were the Pencil's and which a finger's, and what each did, so the next try on the iPad can settle
what a finger does.

### Ghosts and Larry on paper

(#636. The board's ghosts, Larry's turn and the mic, as *Whiteboard: Claude and Larry draw back* describes them, on a board on
paper. That description is the requirement, and this lists only where paper needs saying.)

- **The same bar.** A board on paper has the Ghosts switch, the mic, *Larry's turn* and *Send to Larry*, as any board does,
  and paste: see *Paste on paper*.
- **The same turns.** A pause after a stroke asks Claude, the Pencil touching down holds that pause until it lifts, words go
  the same way, and Larry's marks arrive on their own, in his colour, where his picture was. Nothing about the Ghosts switch,
  the fading, one turn at a time or the bar's words changes.
- **A ghost sits on the paper.** It moves and zooms with the board exactly as the ink does, because it lies on the same sheet:
  it can't drift off the ink or trail behind a scroll or a pinch.
- **A ghost lies under the ink, as the page lines do.** Where one crosses ink, the ink is on top. On the old canvas it lay over
  the ink. That's the one difference in how it looks, and it's what keeps it from ever lagging. It's Igor's to overrule.
- **A ghost is never ink until it's kept.** It isn't in the drawing, the saved file, any picture or the strokes Larry gets.
  Leaving the board with a ghost showing saves nothing of it.
- **A finger tap keeps or dismisses,** as on the old canvas: on a ghost it keeps that one, off them it dismisses Claude's;
  Larry's go only to a tap off them once Claude's are gone (#823).
  While ghosts show, a finger doesn't draw, wherever a finger would, so a tap leaves no dot and selects nothing. With none left it
  goes back to what it did. What a finger drag does in those seconds is part of what the iPad has yet to settle.
- **A kept ghost is ink like his own.** It's in its author's colour, the eraser and lasso treat it like his, and it saves a moment
  later.
- **Ink the app adds is on the screen.** A kept ghost, a paste, an undo or a redo of one shows within half a second, where it
  belongs, with the view staying where it is. Ink that's saved and counted but not shown is a bug, however rarely it happens.
- **One undo takes a kept ghost back, whole.** A kept mark that needs a new page brings the page with it, in the same step.
- **An undo doesn't outlive its board.** Closing a board takes its kept marks' undo steps with it, on either canvas, so Undo on
  the next board can't reach back and change the one that closed.
- **A kept mark past the last page brings the pages it needs,** with the blank page below as for any ink.
- **Larry knows a kept mark as one stroke.** Each time the board's strokes go to Larry, the same ink has the same name, whether
  it was drawn or kept, and whether the board was just drawn on or has been closed and opened since.
- **A mark past the page's side, for now.** Until a mark past the edge widens the board (a later step), a ghost past the column's
  side shows only as far as the column does, and one kept there is saved and sent like any ink, and is out of reach on paper.
  Nothing is lost, and the log says when it happened. The same goes for a mark above the first page.
- **If a turn fails,** the bar and the copyable problem say so as on any board.

The log says where each ghost sat against the sheet, what each finger tap came to, and what each kept mark did to the undo count
and to the strokes' names, so the iPad can show what the simulator can't.

### Paste on paper

(#636. Pasting text as *Whiteboard: paste text onto the board* describes it, on a board on paper. That description is the
requirement: the button, ⌘V, letters as real ink, the caps, the bar's words and Claude's pause are all as written there. This lists
only where a page needs saying.)

- **Where it lands.** In the middle of the part of the paper on screen. A phone's one page, shorter than the screen, has its
  middle on the paper, not in the margin around it.
- **It stays on the page's width.** A line wider than the part of the page on screen wraps, and nothing lands past a side.
- **It lands wherever he is.** However far down the board he has gone, the text is in the middle of the view: the old canvas's
  edge doesn't apply, as paper has none below.
- **A paste brings its pages.** Text running past the last page's end, or ending on it, brings the pages it needs, with the blank
  one below as for any ink.
- **One undo takes the whole paste back,** with any pages it brought, and one redo brings them back. His strokes before it stay.
- **What Larry and Claude see.** The letters are ink: they're in the picture, dark on white, and in the strokes Larry gets,
  each with the same name every time they're sent.
- **Strokes he copied.** With a hardware keyboard, when the clipboard holds copied strokes and no text, ⌘V pastes them, and
  they're ink like any other: one undo, the pages they need, Claude's pause. PaperKit places them if it will; if it won't, they land
  with their middle in the middle of the paper on screen, at their own size, and on the page's width. Text on the clipboard wins, as
  on the old canvas.
- **A picture on the clipboard isn't pasted,** as on any board: pasting images isn't something boards do, and only strokes are
  saved, so one on the board would vanish on leaving. The board doesn't change.

The log says what each ⌘V found on the clipboard and who took it, so the iPad can show what the simulator can't.

## Trial on paper (removed 2026-11-07)

The trial (#635, #636) settled what it was for: Igor made paper the default on 2026-11-03 and the only canvas on 2026-11-07.
*Try on paper* is gone with the old canvas.

## Later steps (not in this build)

Ghosts, Larry's turn and the board's open mic are built, and specified in
[Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md). The Lavish prototype showed that a mark that
could mean two things is best answered with both readings as ghosts, and that Claude can't read cursive, so words come
from Igor's voice.

1. **Voice.** A level meter on the open mic (the Inbox's mic UI). "Your turn" said out loud gets a full drawing turn.
2. **Larry.** A call with the board as Larry's context while Igor keeps drawing.

Claude's side runs through the Cockpit on the Mac (Igor's pick), so no model key goes on the device. The cost is
that ghosts need the tailnet.

## Acceptance

- On the iPad, the Pencil draws, a finger pans, and the eraser removes strokes.
- Close the board, kill the app, reopen it: the drawing is there, at the place he left it.
- A new board is one page wide and scrolls only up and down. Draw to the bottom of a page and keep scrolling: a blank
  page is always there. The ink keeps Notes' feel past 4,000 and past 9,600 points down the column.
- Pinching out stops at the page's width. The page number reads right while scrolling, and isn't in any picture.
- An old board opens look-only on paper, with every stroke where it was relative to the others, none scaled. One wider
  than a page keeps its width. Nothing draws on it.
- There is no *New boards on paper* switch and no *Try on paper*: every new board is on paper.
- A new board made after the default ships is on paper, shows no test cross or ring, and an older build still opens it.
- A save that fails on a board on paper shows a problem that can be copied, on the board or, when leaving it, on the list.
- A new board reads *Page 1 of 1*. Ink on it makes that *of 2*; ink crossing onto page 2 makes it *of 3*.
- With three pages drawn and page 2 on screen, Send to Larry shows page 2 at a size he can read.
- Ruled lines from the Board menu show like notebook paper, the same on every page, are in no picture, and are remembered
  like the grid.
- On a board on paper, the grid and ruled lines lie under the ink. Choosing one takes the other away, each is remembered by that
  board on this device, and a new board starts with neither.
- On each colour of a board on paper, page lines, grid and ghosts show; changing colour or lines leaves the ink on screen, the
  stroke count the same and no new undo step.
- Send to Larry with a drawing: the board's thread appears in Chat with the picture, its ink dark on white even when the
  iPad is in dark mode.
- The tile opens the boards, newest first. + New board opens an empty board; closing it without a stroke leaves no
  row behind.
- Draw on the iPad and close the board: within a minute, the iPhone's list shows it with the same picture. Opening
  it there shows the drawing with no tool picker, and a finger only pans.
- Rename and delete a board on the iPad: the iPhone follows on its next refresh.
- Choose Cream on a board, draw, close and reopen it: it's still Cream, deep in dark mode and pale in light mode, and the
  ink is readable in both. The iPhone shows it Cream too, and its row in the list is cream on both devices.
- Choose a colour on a new board and close it without a stroke: no row is left behind.
- Send a Cream board to Larry: the picture in Chat is dark ink on white.
- Swipe left on a row on the iPhone, on a board drawn on the iPad: Delete asks first, then the row goes. The board
  doesn't come back on the iPhone, and the iPad's list loses it on its next refresh, with the iPad off at the time of
  the delete too.
- Delete on the iPhone a board the iPad has unsent ink on: the board comes back on both, with that ink.
- Delete a board on the iPhone with no network, draw on it on the iPad and let that reach iCloud, then bring the iPhone
  back: the board comes back on both, with that ink.
- *Jump to board* on a chat picture of a deleted board shows the copyable problem, and the picture stays.
- The single board from before the list is the first row after the update.
- With a drawing on the board, Grid on shows faint lines that pan and pinch with it; Grid off removes
  them and leaves the ink as it was. Closing and reopening that board keeps the choice; a new board has no grid.
- Pinched all the way out and all the way in, the lines stay faint and evenly spaced, never a grey wash.
- Send to Larry and a ghost turn with the grid on: the picture has no lines.
