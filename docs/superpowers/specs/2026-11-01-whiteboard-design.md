# Whiteboard with Claude

Igor, 2026-11-01: "can we do an ipad whiteboard app (on phone it should be viewable), and I want the interface with
draw with the pen (and eraser) … minimum you take input … but I think you extend my drawing like we both draw
together and maybe you get voice input, and need a back link to larry too while doing this." The brainstorm ran on a
Lavish page with a working board: four rounds of drawing, and Igor's answers to the open questions. Stories: the whiteboard journey's files, listed in the
[journey table](../../stories/README.md), from [the board and the list](../../stories/10-whiteboard-boards.md).

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
- A **swipe left** on a row offers *Delete*, as Chat's rows offer their actions, and *Rename* on a board drawn on this
  device; a **long press** offers both too. (Igor, 2026-11-02, #613: "I need to be able to delete boards", from the
  iPhone, where a long press on an iPad board only opened it.)
- **Rename** (Igor, 2026-11-16, #916: "Rename boards"; the long press alone wasn't found). The row's swipe offers
  *Rename* beside *Delete*, and its long press offers it too, on a board drawn on this device. A box asks for the name,
  filled with the current one. The new name shows at once in the list and in the board's bar, is the name the board's
  chat thread takes from the next *Send to Larry* or turn, and reaches the other devices when they next sync. A blank
  name, or *Cancel*, leaves the name as it was. A renamed board counts as changed: it moves to the top of the list and
  isn't dropped as an empty new board. A board drawn on another device offers no *Rename*.
- **Rename from the board's own bar** (Igor, 2026-11-22, context-grabber-5chm: he looked for rename inside a board and
  couldn't find it). A tap on the board's name in the middle of its top bar opens the same box as the row's *Rename*,
  filled with the current name, with the same *Rename* and *Cancel*. The new name shows at once in the bar (and in the
  list behind it), saves and reaches the other devices as the row's rename does, and is the name the next picture,
  *Send to Larry*, turn or Claude's look carries. Only a board that draws here offers it: on a look-only board (another
  device's, one that couldn't be read, and every board on an iPhone, its own included) the name is
  plain text and a tap on it does nothing; an iPhone renames its own boards from the list. The name is a plain tap
  target, not a menu: a menu on the name (2026-11-16) made the iPad's Board menu open as a full-height list that stayed
  up after a pick. Renaming doesn't cost a stroke, close the board, or change what the Board menu does: after the box
  closes, the next stroke draws and the Board menu opens and closes as before. A long name is cut short in the bar
  rather than pushing its buttons away.
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
- **A board that fails to come down keeps the one that did** (#1043). If a newer version of another device's board
  can't be brought down (the network drops partway, the copy fails, or what arrives can't be read), this device keeps
  showing the version it had, offline too, the list says boards aren't syncing, and the next sync asks again until the
  new version arrives. A board coming down for the first time that fails isn't shown blank or half-written: it waits
  for the next sync like a board not yet down, out of the list until its drawing has arrived, so it can't be opened
  empty (and on the iPad that drew it, back after a reinstall, nothing is drawn over a blank copy and sent up over
  iCloud's). A link to it says its drawing hasn't come down. A board that already arrived once stays in the list
  while a newer version fails, and opens to the version it has. A version that arrives without its picture, or whose
  picture can't be kept, still arrives: the list's picture is drawn on this device from the drawing. A broken copy of another
  device's board, one that can't be read or moved aside, is repaired by the next good sync: iCloud holds the original.
  A board of this device's that can't be read or moved aside is never replaced from iCloud.
- **A board's meaning goes through iCloud with its ink** (proposed, bead context-grabber-cc75 step 2; not built,
  waiting on Igor's yes; Igor decided on 2026-11-24 to move boards off iCloud into the Cockpit, ink and meaning
  together: [boards in the Cockpit](2026-11-22-boards-in-the-cockpit-design.md)). Besides the strokes, a board holds what the strokes mean: Larry's kept texts, his notes and
  groups, the headers and their folds, the question cards, the names moved strokes keep, and the count Larry's changes
  are checked against. Today that stays on the iPad that drew the board; with this it goes up with the drawing.
  - On the iPhone, the Mac, and the iPad back after a reinstall, a board opens with the folds, headers, question cards
    and Larry's groups the drawing iPad has, and Larry's texts and moved strokes keep the names he knows them by.
  - **The drawing device's copy wins.** Only the device that drew a board sends its meaning up. Every other device
    takes what arrives in place of its own, so a question card Larry left on a board on the iPhone, or a change of his
    the iPhone refused, is replaced by the iPad's on the next sync.
  - **Ink and meaning arrive together.** A device takes a version's meaning only with that version's drawing: if the
    drawing fails to come down, the meaning isn't taken either, and the device keeps the pair it had (as above).
    A meaning that arrives and can't be read is not taken; the device keeps what it had, and the next sync asks again.
  - **A device that couldn't read its own copy never sends an empty one.** If the drawing device's meaning was
    unreadable and set aside, its next uploads carry the ink without a meaning, so iCloud's copy stays, until that
    device has taken iCloud's copy back down. A change on the board in the meantime (a fold opened, a card answered)
    doesn't end that: it stays on the device and is replaced when iCloud's copy arrives. If iCloud has no meaning for
    the board, the device's own becomes the one it sends.
  - A board last sent up by a build from before this has no meaning in iCloud: other devices open it with its ink, as
    today.
  - A change to the meaning alone (a fold opened, a card answered, a batch of Larry's handled) counts as a change: it
    goes up on the next sync like new ink.
  - A delete takes the board's meaning from iCloud with the board.
  - **TestFlight builds need one step from Igor first.** Builds from the cable save to iCloud's development side,
    where CloudKit adds a new field the first time a record carries it. TestFlight builds save to the production side,
    which accepts only the fields deployed to it: a board record carrying a field production doesn't have is refused
    whole, ink included. So before the first TestFlight build with this ships: run a cable build that sends one board
    up, then in the CloudKit Console (the app's container, Schema) deploy the development schema to production. Until
    then, a TestFlight build must not be shipped with this, or its boards stop reaching the other devices.
- **Read-only elsewhere:** a board opens for drawing only on the device that made it. On any other device it opens
  to look at: pan and pinch, no tool picker, and a note in the bar saying where it's drawn.
- **On an iPhone every board is look-only**, its own included (Igor, 2026-11-10). The list has no *+ New board*;
  every board opens to pan and pinch, with no tool picker, no Board menu and no ghosts, and the bar says *Look only on
  iPhone: draw on the iPad*. *Send to Larry* stays, as on every look-only board (*Which
  look-only boards can be sent*, below, story 1200): a board can still be talked about
  from the phone (Igor: "Maybe we can do chat"). Delete and, on the iPhone's own boards, Rename stay in the list. A board the iPhone drew
  before this keeps its ink and opens look-only like the rest.
- **Which look-only boards can be sent** (story 1200, bead context-grabber-xg3). A look-only board's bar says why it is
  look-only, in this order of precedence, and every one has *Send to Larry*:
  - a board that could not be read: *Couldn't be read: look only*; Send is there and dimmed, with nothing read to send;
  - on an iPhone, any board: *Look only on iPhone: draw on the iPad*; Send is there;
  - another device's board: *Drawn on <that device>: look only*; Send is there.
  A look-only board can still be talked about; its reply shows only in Chat, as the board takes no turn and doesn't
  look.
- **Without iCloud** (signed out, or no network), the list shows what this device already has and says that boards
  aren't syncing. Drawing still works, and the board goes up the next time it can.
- **A sync iCloud turns down tries again by itself** (#1002: on the iPad, the first sync after the app was closed with
  ink not yet sent was sometimes refused as *Batch Request Failed / Atomic failure*, and the board then waited for the
  next time the list opened or the app came forward). The board stays on the device as drawn and the list says boards
  aren't syncing; the sync tries again on its own after a short wait, longer each time it fails again (a few minutes at
  most, or longer if iCloud asks for that), and the note goes once one gets through. A failure that keeps coming back
  stops retrying on its own after eight tries in a row, about twenty minutes, and waits for the next time the list
  opens or the app comes forward. Clearing what an earlier delete left in
  iCloud is its own step after the board is saved, so it can't take the board's upload down with it. Signed out or
  without iCloud, nothing is retried: the next time it can, as above.
- **The board drawn before the list existed** becomes the first board in the list, and nothing on it is lost.
- **A reinstall** gives the device a new identity, so its old boards come back read-only there. Taking a board
  over on a new device is a later step.

### One board
- The **tool picker** sits along the edge: pen, marker, pencil, eraser, lasso, ruler, undo and redo, and colors.
  This is the system's own picker, so the Pencil's double tap or squeeze switches to the eraser, as it does in
  Notes.
- **Undo and Redo on the board's own bar** (#965; Igor, 2026-11-19, drawn on board 302d5345: "an Undo button on the
  board itself"). A board drawn on here has *Undo* and *Redo* at the start of its top bar, after the way back, where a
  finger or the Pencil reaches them whatever the tool picker is doing.
  - Each is at least 44 points wide and as tall as the bar's own buttons (36 points on the iPad, the system's glass
    item: the bar hosts every button at its own height, whatever the button asks for). Each is dimmed when there is nothing to undo or redo, and taps then do nothing.
  - Each is the same step as the tool picker's Undo and Redo and a keyboard's ⌘Z and ⇧⌘Z: one press takes back one
    step, whether it was his stroke, a keep, a paste, a scratch-out or a batch of Larry's, and Redo brings it back.
  - VoiceOver reads what the press will do: *Undo Keep all*, *Redo Paste*, or plain *Undo* and *Redo* for a step with
    no name (his own stroke). Dimmed, it says so.
  - A press doesn't cost a stroke: the next stroke after it draws, as after the Board menu.
  - A board only looked at (another device's, or any on an iPhone) has neither, as it has no tool picker.
- **The top bar's groups and labels** (#1005; Igor's design critique of the iPad board, 2026-11-20: "Nothing says what
  the sparkle and hand icons do. There is a large empty gap between the palette and the mic in the right-hand group").
  - **Three groups.** The way back and *Undo*/*Redo* on the left; on the right the board's own things, the **Board**
    menu and **Paste**, in a group of their own like *Undo* and *Redo*; then the three that talk to Claude and Larry:
    **Talk**, **Ask at my pauses** and **Send**, evenly spaced, with no hole among them (*Larry's turn* became *Send*,
    story 1176).
  - **Paste shows only while the clipboard holds text.** The gap was the system's paste button with nothing to paste:
    iOS dims it to near nothing, so it read as an empty space. Looking whether the clipboard holds text never asks
    *Allow Paste?*. When it does, Paste appears beside the Board menu and the three on the far right don't move.
    It appears within about a second of text being copied, also from an app beside the board.
  - **A long press names the button.** A long press on Talk, Ask at my pauses or Send shows a small menu headed
    by the button's name (*Talk*, *Ask at my pauses*, *Send*) with one row saying what a tap does (*Talk to
    Claude*, *Stop asking Larry at my pauses* (substitute the board's responder by name, or use
    *Ask … at my pauses* while the switch is off), *Send the board to Larry*); that row does it,
    and a tap anywhere else closes the menu. A plain tap does what it always did. The Board menu opens on a tap and
    is headed by its sections. Talk's menu also picks the microphone, under its one row, whether the mic is open or
    closed ([Which microphone, and what it hears](2026-11-01-whiteboard-shapes-design.md), story 926).
  - On a width as narrow as an iPhone's the Board menu stays at the bottom of the screen (below), and Paste with it in
    the top bar's right group.
  - **The board's name** sits in the middle of the bar. On a board that draws here a tap on it renames the board
    (*Rename from the board's own bar*, above); on a look-only board it is only the name.
- **Who draws:**
  - With a Pencil paired, only the Pencil draws, and a finger moves the board. A palm resting on the glass never
    leaves a mark.
  - **Writing never zooms the board** (Igor, 2026-11-24: "it zooms while I write"). Only a deliberate pinch of two
    fingertips zooms. While the Pencil is on the glass, or a palm rests on it, the board holds its zoom: a palm shifting
    under the writing hand, or a palm and a fingertip together, never pinches. A palm is a contact far wider than a
    fingertip (on Igor's iPad a fingertip reads about 30–50 points in radius, a resting palm 60 or more). The Pencil
    never counts as a pinch's finger, and fingers that land within 400 ms of the Pencil lifting don't zoom either, the
    hand still settling after a word (the same number as the web board, cockpit-kp5). Once everything lifts, the next two
    fingertips pinch as before. Panning is unchanged.
  - Without a Pencil (an iPad with none paired), a finger draws and two fingers move the board.
  - This follows the system's "Only Draw with Apple Pencil" setting, and on paper also the Pencil itself: once it has
    touched a board, a finger only pans, selects and taps until the app is next launched (context-grabber-2eml; the
    rules for a finger while marks show are in [Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md)).
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
  - **Boards from before pages** (drawn on the old canvas) are dropped: see *Paper is the only canvas* below.
  - **A mark past the page edge** widens that board, by the same rule as wide ink. Nothing is clipped.
- **Grid lines** (Igor, 2026-11-02: "Let's give me the ability to enable grid lines"; #608). *Grid lines*, in the **Board**
  menu with the colours, turns faint lines on and off, on the device that draws the board.
  - **Ruled paper** (#635; Igor, 2026-11-03: "I still want Lines" meant paper lines). The same menu also offers *Ruled
    lines*: faint horizontal lines like notebook paper. A board has a grid, ruled lines or neither. Everything below about
    the grid holds for ruled lines too. Every page is ruled the same: the first line sits one line down from the page's
    top, and the lines are as far apart as the grid's squares (40 points; provisional until Igor has seen them), so
    they restart at each page and a line never lands on the page's end.
  - **A new board opens with the grid on** (Igor, 2026-11-16, #915: "default new boards have grid lines"; until then a
    new board started without one). It's remembered per board on this device: a board opened with its grid on, or off,
    or with ruled lines, opens that way again. A board made before the change keeps what it had, so one never given a
    grid stays without. The grid comes on only where the board is drawn: another device looking at it shows its own
    choice, off until asked.
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
  the board's name: the first send on a board starts the thread, and later ones go to it, so marks he
  draws in answer come back to the board. On a board drawn here it is Larry's turn, the one button that hands him
  the board ([One Send](2026-11-01-whiteboard-shapes-design.md), story 1176): his clock shows, his marks arrive, and once
  he has the picture the button is dimmed until the next stroke (story 765).
  - On a board only looked at, the bar says *Sent to Larry: his reply shows in Chat*. One send makes one message: the
    button stays disabled until other pages are on screen, so a second tap never sends the same picture twice.
  - With no network, the board waits in the Inbox outbox like any other message and goes when the network is back;
    on a board drawn here the note says *Waiting to send* until it goes, and the button is dimmed meanwhile.
  - An empty board can't be sent; the button is disabled.
  - **The picture shows the page or pages on screen** (#636; Igor, 2026-11-03), so what he's looking at is what Larry
    reads, with his writing at a size Larry can see. Scroll to another page and send again to show Larry that one. An
    empty page on screen is left out of the picture; if everything on screen is empty,
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
  - **Ghosts stay visible on all of them.** No colour is orange or a strong purple, and a faint orange or purple (Larry's) ghost on
    any colour is at least nine-tenths as visible as it is on Plain; his kept purple ink reads at 3:1 or more on every one.
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
pages (until 2026-11-22, below), strokes that never scale, and Larry seeing the pages on screen.

**Paper is the only canvas** (Igor, 2026-11-07: "get rid of old canvas, only use new paper code. Old canvas can be erased").
Every board is drawn on paper. The old canvas, its switch and the trial are gone.

- **Boards drawn on the old canvas are dropped** (Igor, 2026-11-22: "drop the old canvas"; no conversion). From
  2026-11-07 they opened look-only, their ink moved onto the first page (story 658, now retired). Now they are left out
  of the boards list on every device, and a link or *Jump to board* to one shows the copyable problem *This board was
  drawn on the old canvas, which is gone: it can't be opened*. Their files are not deleted: nothing is erased from the
  device or iCloud, they just aren't shown.
- **A board on paper from another device** stays look-only on this one, as every board is, now shown on paper.

**The app needs iOS 27 from here on.** Reading ink back out of PaperKit starts there, and Igor's iPhone and iPad both run
it. Nothing else about the app changes with this, and a device on an older system would stop getting new builds.

**What's saved doesn't change.** Boards keep saving strokes in today's file format, so older builds open every board and
nothing has to migrate. The cost, from the same proposal: anything PaperKit could add, such as shapes or text boxes, wouldn't
stay an editable object once saved. That fits the non-goals above.

**What differs on paper.** Page lines, ruled lines and the grid lie under the ink, not over it. Everything else about pages, lines and
pictures reads as written above. The trial's small cross on each page and its ring are there only to test with, and never
appear on a real board.

**What a finger does on paper.** PaperKit has no mode where a finger only pans; set to select rather than draw, a finger
drag pans the board and a tap selects, while the Pencil still draws (the iPad's log, 2026-11-22). So where a finger would
draw, it is set to select while marks show, until a tap off them; and once the Pencil has touched a board, always
(context-grabber-2eml; the rules are in [Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md)).

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
- **On another device** it opens look-only, on paper, with the same ink.
- **If a save fails,** the board shows the copyable problem and keeps drawing. If the failure comes as he leaves the board,
  the problem shows on the boards list instead of going with it, whichever canvas the board is on, until that board next
  saves.
- **Always light, for now.** While a board on paper is on screen, the whole screen is in light mode, even with the device in
  dark mode: its colour's pale shade, and dark ink. The boards list goes back to the device's mode. On the simulator, PaperKit in dark mode drew new black ink black, so it couldn't be
  seen. This differs from *Each colour has a pale shade and a deep one* above until PaperKit's ink follows the mode, and it's
  Igor's to overrule. What's saved is the same either way.
- **Grid and ruled lines.** The **Board** menu offers *Grid lines* and *Ruled lines*, as *Grid lines* above describes: a grid,
  ruled lines or neither, choosing one takes away the other, the grid on for a new board, and remembered per board on this device. They lie
  under the ink and the ghosts, on every page. The grid's squares run on unbroken from page to page; ruled lines start again at
  each page's top. Pinching out thins them, so a phone showing a whole page's width shows every
  second line. Neither is ink: they can't be erased, lassoed or undone, and they're not in the saved drawing, the card or any
  picture.
- **Colour on paper.** A board on paper has the five colours, kept and shared as *The board's colour* says, in their pale shade
  for the reason under *Always light*. Page lines, the grid, ruled lines and ghosts all show on each of them.
- **Changing the colour or the lines leaves the ink alone.** Ink already on screen stays on screen, where it was, the view
  doesn't move, nothing is added to undo, and the board's stroke count doesn't change.
- **The Board menu never costs a stroke.** The first stroke after the menu closes draws, whether something was chosen or not.
- **A pick in the open Board menu always takes.** The menu holds still while it is open, whatever the board does behind
  it: Larry's thread being looked at every few seconds, a save, a ghost coming or going. A row tapped at any moment is
  chosen and the menu closes, never a tap lost because the menu was put up again under the finger. Only a change to
  what the menu itself shows (its colour, lines, font or responder) may redraw it.
- **What a board on paper can't do yet.** *Send to Larry*, ghosts, the mic and paste work: see
  *Ghosts and Larry on paper* and *Paste on paper*. The picture is still the whole drawing.
- **Undo and a new page.** Adding a page can count as a step of undo: one press may take back the page and not a stroke.
  The next stroke brings the page back. Whether this matters on the iPad is still to be seen.

The log says which touches were the Pencil's and which a finger's, what each did, and each time a finger starts or stops
drawing and why.

### Ghosts and Larry on paper

(#636. The board's ghosts, Larry's turn and the mic, as *Whiteboard: Claude and Larry draw back* describes them, on a board on
paper. That description is the requirement, and this lists only where paper needs saying.)

- **The same bar and turns.** See *The top bar's groups and labels*, *Paste on paper* and
  [Whiteboard: Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md).
- **A ghost sits on the paper.** It moves and zooms with the board exactly as the ink does, because it lies on the same sheet:
  it can't drift off the ink or trail behind a scroll or a pinch.
- **A ghost lies under the ink, as the page lines do.** Where one crosses ink, the ink is on top. That's what keeps it from
  ever lagging. It's Igor's to overrule.
- **A ghost is never ink until it's kept.** It isn't in the drawing, the saved file, any picture or the strokes Larry gets.
  Leaving the board with a ghost showing saves nothing of it.
- **A finger tap keeps or dismisses:** on a ghost it keeps that one, off them it dismisses Claude's;
  Larry's go only to a tap off them once Claude's are gone (#823).
  While ghosts show, a finger doesn't draw, wherever a finger would, so a tap leaves no dot and selects nothing; its drag
  pans. A tap off them gives a finger with no Pencil in use its pen back, and with none left it goes back to what it
  did (context-grabber-2eml).
- **A kept ghost is ink like his own.** It's in its author's colour, the eraser and lasso treat it like his, and it saves a moment
  later.
- **Ink the app adds is on the screen.** A kept ghost, a paste, an undo or a redo of one shows within half a second, where it
  belongs, with the view staying where it is. Ink that's saved and counted but not shown is a bug, however rarely it happens.
  If the board ever finds such ink missing from the screen a second later, it draws it again on its own, within a few
  seconds, with no visible jump. Ink taken away in that second (an undo, a delete, a clear) isn't missing: the board
  neither redraws nor moves for it. Part of a kept mark missing counts too, and so does part of it drawn in a colour that
  isn't its own: a kept text of Larry's whose first letter showed in his purple and the rest blank or black is drawn
  again on its own a second later (context-grabber-ikya), by moving the view a screen away and straight back once, always
  ending where it was. Its strokes are never taken out and put back: doing that left the next Undo of a stroke Igor drew
  taking nothing back (context-grabber-pmv6). A mark drawn
  whole is never taken for one drawn in part: a small label of thin letters, its colour as far across and as tall as the
  same strokes drawn alone show it, is left as it is, with no move (context-grabber-qko5).
- **Ink an Undo or Redo leaves in place is on the screen too** (context-grabber-9bll; seen only on the simulator so far).
  An Undo or Redo that moves, adds or takes away ink redraws the board around what changed, and a second later the
  board checks every stroke near the change, piece by piece across the screen, for a piece that should show and
  doesn't. Ink the step never touched counts: on the iPad simulator, after a group dropped just above Igor's line was
  undone, the line stayed drawn only up to one edge and was blank past it. A piece found missing is drawn again by
  moving the view a screen away and back once, ending where it was. The strokes are never taken out and put back after
  an Undo or Redo, nor a kept mark's: doing that left the next Undo of a stroke Igor drew taking nothing back
  (context-grabber-pmv6). Undo and Redo stay one step each, every step still takes back what it would have, and the step
  Redo would take is still there afterwards.
- **One undo takes a kept ghost back, whole.** A kept mark that needs a new page brings the page with it, in the same step.
- **Every keep is a step of Undo of its own, and keeps it** (#966). *Keep*, *Keep all* and *Tidy overlaps*
  are each one step, named for what was done (with a keyboard, the menu's *Undo Keep all*). Nothing the board does on its
  own just after (taking back the dot a tap left, a zigzag's scratch-out, the room a dropped selection opens) ever takes
  that step in place of its own: however soon after the keep it comes, the keep stays on the stack, and one Undo still
  takes it back whole. The log says each time an Undo or Redo ran and what it was named, and each time the board's own
  take-back found a keep on top and left it there.
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
- **It lands wherever he is.** However far down the board he has gone, the text is in the middle of the view, as paper has no
  edge below.
- **A paste brings its pages.** Text running past the last page's end, or ending on it, brings the pages it needs, with the blank
  one below as for any ink.
- **One undo takes the whole paste back,** with any pages it brought, and one redo brings them back. His strokes before it stay.
- **What Larry and Claude see.** The letters are ink: they're in the picture, dark on white, and in the strokes Larry gets,
  each with the same name every time they're sent.
- **Strokes he copied.** With a hardware keyboard, when the clipboard holds copied strokes and no text, ⌘V pastes them, and
  they're ink like any other: one undo, the pages they need, Claude's pause. PaperKit places them if it will; if it won't, they land
  with their middle in the middle of the paper on screen, at their own size, and on the page's width. Text on the clipboard wins.
- **A picture on the clipboard isn't pasted,** as on any board: pasting images isn't something boards do, and only strokes are
  saved, so one on the board would vanish on leaving. The board doesn't change.

The log says what each ⌘V found on the clipboard and who took it, so the iPad can show what the simulator can't.

### Scratch out (stories 890, 891, 898, 1185; Igor, 2026-11-16: "match Larry's web board")

As in Goodnotes and Notability, and as the Cockpit's web board (*/ink*) does it: a fast zigzag drawn over ink deletes the
ink it covers, without picking up the eraser.

- **What counts as a scratch-out.** One stroke that turns back on itself at least **three times** along its main direction,
  each sweep crossing most of the zigzag's length; no wider across than it is long; at least 30 points long; drawn fast (at
  least half a board point per millisecond, or less for a small one, below); and lying mostly over the ink it touches (at least 60% of that ink's points
  inside the zigzag's box). Handwriting never qualifies: an *mmm* or *www* marches along instead of turning back, and a slow
  zigzag stays as ink. A zigzag on bare paper, or one beside a word rather than over it, takes nothing and is
  taken away with a word (*Every pen gesture shows what it did*, below).
- **A scribble that wanders along the word counts too** (context-grabber-4kj; Igor, 2026-11-21: "why isn't scribble
  working"). A hand scratching out a word drifts along it as it goes, so no sweep spans the whole scribble: his three
  that day swept 63% to 75% of their length on average and all stayed ink. A scribble that turns back at least **five
  times**, its sweeps crossing at least half its length on average, is a scratch-out when it lies over ink. Shading and
  hatching look the same, so a wandering scribble over bare paper, or beside ink rather than over it, stays as ink,
  without a word; a short wiggle of three or four turns still needs sweeps across most of its length.
- **A scribble that drifts a long way counts too** (context-grabber-4kj, 2026-11-22). A scribble across a long word or a
  phrase can drift further than its sweeps are long: on 2026-11-21, after the fix above, a fast scribble 458 points along
  and 113 across swept back and forth eight times, each sweep 87 to 245 points, and stayed ink, as its turns were
  counted against its whole length and the shorter early sweeps didn't count. Its turns are now also counted against its
  own sweeps: a scribble that turns back at least **five times** that way, its typical sweep at least **40 points**, and
  no wider across than it is long, and its pen going at least twice as far along it as across, is a wandering
  scribble, under the same rule as above (it acts only over ink). Handwriting's back-and-forth is a letter wide, well
  under 40 points, and is slow; a row of big loops (*ooo*) goes as far across as along, so it stays ink.
- **What goes.** Every stroke the zigzag touches goes whole, as the stroke eraser takes it, and so does the zigzag. Strokes
  it doesn't touch stay, however close. One exception: a small mark wholly inside the struck ink, the dot of an *i*, a *t*'s
  crossbar, a squiggle a sweep passed over, goes too (stories 1282, 1266). What went stays gone as he writes on: only Undo brings it back (#999).
- **A mark inside the struck word goes with it** (cockpit-9g1, story 1282; Igor, 2026-11-23). A zigzag sweeps across a
  word, and a small mark that sits between two sweeps, or inside the word just past where the sweeps turned, can be
  missed by every sweep. On 2026-11-23 a scratch-out over ten fresh strokes left one, an 18 by 9 point mark the sweeps
  passed either side of, and the web board's *t* crossbar did the same. Ink that lies wholly within the outline of the
  zigzag together with the ink it touched (the outline a rubber band around them makes, grown by the same reach a
  sweep has) and within the zigzag's own frame (the zone the ink it takes must mostly lie in, grown by that reach too)
  goes too. Ink partly
  outside either stays, as does ink beside the word: a long stroke the zigzag touched, an arrow running down from the
  word, never stretches the outline over the line below (story 1266).
- **A small zigzag may be slower** (cockpit-9g1, story 1283). A short zigzag can't reach a long one's speed: the retry
  over that left-behind mark, a zigzag 37 points long, went at 0.35 points per millisecond and was refused as slow. The
  speed floor scales with the zigzag's length up to 60 points (half a point per millisecond at 60 and above, a quarter
  at 30). Igor's slow writing that looked like a zigzag in his iPad logs (37 points at 0.23, 45 at 0.30) still stays
  ink (story 1268).
- **Only the ink he can see is touched** (context-grabber-p5hy). Where the pixel eraser rubbed part of a stroke away, the
  gap is bare paper: a zigzag over it takes nothing of that stroke, and the rubbed-out part doesn't count toward lying
  over the ink. A zigzag over a part that is still there takes the stroke as before, the rest of what is left of it
  included; a stroke rubbed out entirely is never taken.
- **Nothing else changes.** Ink he moved with the lasso, wrote or erased just before the zigzag stays as he left it:
  a scratch-out never takes back his last other change, a move included (#966, story 1059).
- **One undo brings it all back**: the ink it removed, without the zigzag. One redo removes it again.
- It's a change like any erase: the board saves, and Larry's next picture and strokes no longer have that ink. It doesn't
  ask Claude about the board, as nothing new was written.
- A look-only board can't be scratched out, as it can't be drawn on.
- **Only the pen scratches out** (#1121, story 1108). With the eraser in hand a fast back-and-forth is the eraser at work:
  it rubs out what it crosses, as the eraser does, and nothing of the scratch-out happens (no flash, no word, no
  *Nothing under the scribble to erase*). On the iPad the eraser's sweep was read as a zigzag and the app crashed taking
  it back.
- **Folded ink is never scratched** (story 898): ink hidden under a folded header stays, even where the lines below it
  now sit on top of it, and it doesn't count toward whether the zigzag lies over ink.
- **A zigzag over a folded header takes the whole fold** (story 905): over its "▸ N lines folded", where there is no ink,
  or over the folded header's own line, the header and everything folded under it go with whatever else the zigzag
  covered, and the ink below closes up to where the header was. One undo brings it all back, the section still folded.
- The log says, for every zigzag with three or more turns, whether it fired, its turns and speed, why it didn't (*slow*,
  *no ink*, *beside ink*, *marches along*, *short sweeps*, and for a wandering scribble *wanders, no ink* or *wanders,
  beside ink*) and how many strokes went, so the iPad can show how it feels;
  and how much of what went the board still holds, then and a second later, and whether any of it comes back without an
  Undo (#999).

### Every pen gesture shows what it did (#1000; stories 1038, 1039, 1042–1044, 1050–1052)

Igor on the iPad, 2026-11-20: *Need visual feedback when creating or adding space, like with transparent arrows, so
it's clear I'm in that mode.* The design critique the same day widened it: every pen gesture shows what it did. A
gesture that changes the board without a sign, or does nothing without a word, leaves him guessing whether it fired.

**Making room.** From the moment a hold in the margin becomes the room handle (*Press and hold (#918)* in
[Larry edits the board](2026-11-16-whiteboard-board-ops-design.md): a finger the board sees held, or the Pencil held
still there for half a second) until the finger or the Pencil lifts:

- **A see-through band lies across the page** at the clear line the room would open at, as tall as the room a lift
  right now would open, in whole lines. It grows and shrinks a line at a time as the drag goes on. Before the drag
  reaches half a line it is a thin line across the page, so the mode shows the moment the hold fires.
- **Up and down arrows** sit at the band's left, in the margin, and a **Making room** chip sits beside them.
- **Dragged up**, the band covers the blank paper that would close, and the chip says **Closing room**. Dragged up
  where there is no blank paper to close, the band stays a line and the chip says **No blank paper to close**.
- The ink below doesn't move until the lift, as before; the band says where it will go. When the finger or the
  Pencil lifts, the band goes and the room opens (or closes) as the band showed.
- A hold that becomes the menu instead (lifted without a drag), or a hold on a header's mark (the outline menu),
  shows no band once the menu is up.
- The band is in no picture, takes no touches, and never moves the paper.

**Scratching out.**

- **A scratch-out that works flashes and fades the struck ink**: the strokes it took, and the zigzag, show where they
  were in a bright tint for a moment and fade out over about half a second. The board has already changed underneath:
  Undo, the save and Larry's picture are as before.
- **A zigzag that finds nothing to erase says so**: one that is a scratch-out in shape and speed but has no ink under
  it (*no ink*), or only ink beside it rather than under it (*beside ink*), is taken away, and **Nothing under the
  scribble to erase** shows beside where it was for a few seconds. It is taken away as an Undo would take it, so
  Redo brings it back as ink, for the time a zigzag was meant as a drawing.
- Writing that only looks like a zigzag (*slow*, *marches along*, *short sweeps*) stays ink, with no word, as before.
- The flash and the message are in no picture and take no touches.

**Reduced motion.** With *Reduce Motion* on, the band jumps between lines instead of easing, and the struck ink
doesn't flash: it shows plainly and fades. Nothing else changes.

The log says when the band showed, for which tool, and what it showed when it went (*opening*, *closing*,
*nothing to close*, and the lines), and, for each zigzag that found nothing, that it was taken away with the message.

### Larry can read what the board did (#883)

Igor, 2026-11-14, after kept marks vanished: *make sure you have the logging to debug, and be able to request [logs]*.
The board's log stayed on the iPad until it was pulled to the Mac, so Larry couldn't see what a tap or a turn did.

- **Each picture that goes to Larry takes the board's log with it**: his turn, a pause on a Larry board, the picture
  after his answer, and *Send to Larry*. What goes is everything the boards logged since the last that reached the
  Cockpit (taps, keeps, ghosts, turns, errors), never the words said or written, only counts and places.
- **It goes to the Cockpit's archive**, beside the call logs, where Larry reads it on his own machine. Igor exports
  nothing and nothing changes on the board.
- **A log that doesn't arrive goes with the next picture.** Sending it never holds up or fails the picture.
- **A simulator or the Mac sends no log** unless it's pointed at an archive on purpose, as with every other archive
  stream.

### How this board works, and Feedback (stories 950–953; Larry, 2026-11-17: "surface them, since that's how he reports bugs to us")

On Larry's web board (*/ink*) the cheat sheet (**?**) and **Feedback** are each one tap, at the board's lower right. The
board's gestures had no list anywhere on the iPad, and the only way to report from a board was to shake the iPad. Both
are now one tap on the board, as on */ink*, at the board's top right instead: on the iPad the Pencil's tool palette
docks along the bottom and takes every tap there.

- **Two small buttons float at the board's top right corner**, just under the page number, over the paper and clear of
  the left margin and of the tool palette: **?** and **Feedback**, each a single small icon (a question mark, a
  ladybug) with no word beside it, so they cover as little of the page as they can; VoiceOver still names them *How
  this board works* and *Feedback* (Igor, 2026-11-22, #1162: "Just a bug buttons enough I don't need to say
  feedback"). An open conversation lies over them, as over the paper. They stay put while the board scrolls, are in no picture, and never move the
  paper. They are not in the top bar, which keeps its buttons (the Board menu included) where they are on every width.
- **?** opens *How this board works*, a short list of the board's gestures as they are now:
  - *In the left margin:* a tap beside a line makes it a header (▾); a tap on the ▾ folds its section (▸ and the number
    of lines) and another unfolds it; a faint H marks a line that looks like a header, which a margin tap makes one.
    A finger, or the Pencil held still for half a second, held and dragged makes room in whole lines (dragged up, it
    closes blank paper). Held still without dragging, the menu: *Make room here*, *Paste*, *Make header*. Held on a
    header's mark: *Fold all*, *1*, *2*, *3*, *Unfold all*.
  - *On the page:* a finger held still brings the same menu. The Pencil held still on a word picks it up: drag and lift
    to move it, or lift without moving to select it. A line underlined, or started with a #, becomes a header (## and
    ### make a level-2 and a level-3 header, whose sections nest), and Undo takes the mark and the header; a rule drawn across the page ends a section. A fast zigzag over ink scratches it out. A finger held on writing, then *To text*,
    turns handwriting into typed text. The Pencil held still at a stroke's end snaps it to a straight line, a rectangle
    or an ellipse.
  - *Larry's marks:* *Keep all* beside the count of marks keeps every one as ink where it showed, each reply as one group; *Tidy overlaps* in the Board
    menu moves kept labels off writing.
  - *In the bar:* *Ask at my pauses* (the sparkles) explains
    [what the switch does](2026-11-01-whiteboard-shapes-design.md).
  - *Feedback (the ladybug):* a note, a picture of the screen and the recent log; shaking the iPad does the same.
  It closes with *Done*, or a tap outside it on the iPad. A look-only board (an iPhone, or another device drawing it)
  shows no **?**: its gestures don't apply there.
- **Feedback** (the ladybug) opens the app's own *Report a problem* sheet at once, with the board as it was as its picture and the
  session log, exactly as a shake does. Nothing about the sheet changes; it is the same report the Mac's listener files.
- **When the report is saved, the board says so**: *Feedback logged ✓* beside the buttons for a few seconds. *Logged*,
  not *Sent*: the report is saved on the device and queued for iCloud, and the app is not told when it arrives. If the
  report could only be noted in the log, the board says that instead. It shows to the left of the buttons.
- A tap on **?** or **Feedback** is in the session log.

### Ink the app doesn't know never crashes the board (story 1063, #1083; Igor, 2026-11-21: "I think I'm crashing")

On 2026-11-21 the iPad's board closed three times in two minutes, each time just after Igor wrote: a stroke had come in
whose kind of ink (pen, pencil, marker and so on) the app had no name for, and asking it for that name stopped the app.
Where that ink came from isn't known yet; the log is what will say.

- **Any stroke on the board is ink like any other**, whatever its kind: it draws, saves, is sent to Larry, can be moved,
  erased, scratched out, hidden under a fold and shown again. Nothing a stroke carries ever closes the app.
- **Larry gets its kind as the ink says it**, the last word of its name (*pen*, *marker*, or a word he hasn't seen before),
  as for every stroke; a stroke whose ink has no kind at all goes to him as *pen*.
- **Hidden and shown again, it keeps its colour.** Where the board has to redraw it with another strength (a fold, Larry's
  marks waiting to be kept), an ink with no name it knows comes back as the pen in that colour.
- **The log names it**: the first stroke of each unknown kind in a session logs that kind, as the ink spells it, where it
  was met, and how many points the stroke has, so the next time it happens the log says what it was.
- **The board it is on always opens again** (story 1092, bead context-grabber-3b02). A saved board with an ink this
  build can't read back would not open, and would be held to look at only. So before a board is saved, each unknown
  kind is tried: one that reads back is saved as it is; one that doesn't is saved as the pen in its own colour and
  strength (a hidden stroke stays hidden), its shape and place unchanged. On the screen it stays as drawn until the
  board is opened again, when it is a pen stroke, and goes to Larry as *pen* from then on. Each save that holds an
  unknown ink logs its kinds, whether they read back, and how many strokes were saved as the pen.

### The log says what covers the board (story 1102, #1140; Igor, 2026-11-22: "I can't click on menus, whatever I click on I get the pop-up menu Paste")

On the iPad the board went deaf: every tap, on the paper or the bar's buttons, brought up *Paste · Select All* and
nothing else. The report shows something of the system's own, drawn by another process and invisible in the screenshot,
sitting over the whole screen, and the log heard no touch at all for the twenty seconds before the shake. What put it
there, when, and what the menu belonged to, the log can't say. Before anything changes, it has to.

- **Whatever comes over an open board is a line in the log**, as it comes and as it goes: what it is, how it was shown
  (a popover, a sheet, a menu), where it sits on the screen and what it points at, whether another process draws it, any
  *Paste · Select All* style menu showing and where, and what on the board would answer a Paste.
- **Its going says how long it stayed**, so a cover that stayed up while Igor tapped shows as one long stay.
- Nothing Igor sees changes: this is the evidence for the fix, not the fix.

### A tap brings up no system menu (stories 1276, 1306, #1385; Igor, 2026-11-24: "Every time I tap I get paste and select all")

The log settled what the cover was: a finger tap on the paper brings up the system's own *Paste · Select All* edit menu,
which the paper answers. Igor: "better would be using my long hold paste". So a plain tap is quiet.

- **No tap brings up *Paste* or *Select All***: a finger or the Pencil, on blank paper, on ink, in the margin, with
  something on the clipboard or not.
- **Paste lives in the board's own hold menu** (*Press and hold*, Larry edits the board), and ⌘V with a hardware
  keyboard pastes as before.
- **A selection's own menu stays without them**: tapped, a selection still offers what acts on it (Copy, Delete and the
  rest), never *Paste* or *Select All*.
- A menu that would hold nothing else doesn't come up at all.

### What a tap selects (#1386; Igor, 2026-11-24: "what gets selected when I tap in the box is a bit confusing")

Principle 3 of the vision: one touch, one meaning; a tap picks up one thing, and he can tell beforehand what. Decided
(Igor, 05:19): **To text only in the hold menu**, never beside a selection (stories 1309, 1310); with *A tap brings up
no system menu*, nothing pops up on a plain tap. A hold on his selection acts on all of it.

Still open, for Igor: what a single finger tap selects. Today it depends on what is under it: a group of Larry's whole
(story 947), one thing of Larry's (story 1140), a kept text (story 1197), inside his selection the selection (story
1196), and on his own plain writing whatever PaperKit's own tap picks, which is the surprise.

- **A (recommended): a tap picks up the thing the hold menu would name, and shows it first.** The thing under the finger
  is the same one *Select* in the hold menu takes (a word of his, a group, a kept text, a header's row, one thing of
  Larry's), outlined faintly the moment the finger lands, and selected when it lifts. Inside his selection, the
  selection. On blank paper, nothing.
- **B: a tap never selects.** Selecting is the lasso or the hold menu's *Select*; a tap only clears a selection. The
  most predictable, but a group of Larry's no longer comes up whole on a tap (story 947).
- **C: as today, with only the outline added.** The least change; his own writing still selects what PaperKit picks.

### The log says what a moving touch held and what moved (story 1143, bead context-grabber-eg7v)

On the iPad a one-finger drag moved 54 strokes at once: a text of Larry's he had just kept and two of Igor's strokes
written under it, with nothing selected, a moment after a Larry turn came back. The log could say the ink moved and that
a touch was down, but not what the touch started on, what was selected when it went down, whose ink moved, or whether
the board's own changes or Larry's answer arrived while the finger was down. The log that came before it does show
something of the system's: after a finger tap on that text, a popover from PaperKit's handwriting tools appeared over
exactly those 54 strokes, and the drag began on that tool's own view rather than on the paper. Before anything changes,
the log has to settle that.

- **Every touch says what it began on and what was selected**: the kind of view the first finger or the Pencil landed on,
  how many strokes were selected as it went down, and whether a handwriting tool of PaperKit's (its reflow or a popover
  over handwriting) was showing then and when the touch ended.
- **Every touch says what the board changed under it**: how many times the board put its own change on the ink while the
  touch was down, each by name (a kept mark, Larry's edits, a move, an undo step), and how many Larry or Claude turns came
  back meanwhile.
- **Every change that moves ink says what moved against what was held**: how many of the moved strokes were selected when
  the touch began and how many weren't, how many are Larry's or Claude's and how many Igor's, the moved ink's box, and how
  far the strokes went, least and most, so one drag (everything moved the same way) reads apart from writing rewrapped
  (each word moved its own way). A selection made during the touch counts as not held.
- Nothing Igor sees changes: this is the evidence for the fix, not the fix.

### The log says what held the board up while Igor wrote (story 1168, bead context-grabber-uktm)

On the iPad, writing on a board of about a thousand strokes, the board stopped answering for one to one and a half
seconds at a time, a few times in a session: the main-thread watch logged each stall, and the board's line for the
stroke that had just landed said the board's own handling of it took 963, 1,475 and 1,348 ms, where the strokes either
side took about 50. Nothing in the log says which part of that handling took the time, and a fourth stall of the same
size came in the middle of a stroke, outside it. Before anything changes, the log has to settle where the time goes.

- **A slow change to the ink names its slow parts.** When the board's handling of one change to the ink takes a
  quarter of a second or more, the log gets one line saying how long the whole of it took and how long each part took,
  by name, with the stroke count, what the change was, and how long it had been since the ink last changed.
- **A quick change logs nothing more**, so the usual line for each stroke stays as it was.
- **The two parts that grow with the board name their own parts** (#1527). Igor's logs since then show the time per
  stroke growing with the board, from under 10 ms on a new board to about 85 on one of 600 or more, and the slow
  strokes' time almost all in two parts: the board taking the new drawing (up to a second) and his stroke fading the
  marks it writes over (up to five seconds on a board of 770). When either of those takes a twentieth of a second or
  more, the log gets a line naming its own steps by time, with the stroke and mark counts, so the fix goes at the step
  that grows.
- **Drawing on a full board stays as quick as on a new one** (#1527, story 1359). The board reads its ink as Larry
  names it for the marks rule, the outline and the plans, and it read the whole board that way afresh, several times,
  on every stroke of a board with Larry's marks. A stroke is now read once and kept by what it is: the same stroke,
  unmoved, uncut and in the same ink, is never read twice, and one that moves, is cut by an erase or changes ink is
  read again. What Larry gets and how the marks behave are unchanged; only the time per stroke stops growing with the
  board.
- Nothing Igor sees changes: this is the evidence for the fix, not the fix.
- **Time away is never a stall** (story 1221, bead context-grabber-55vm). The iPad logged the app's time asleep in the
  background, minutes at a time, as the main thread stuck, which would hide a real hang. If the watch was still running
  when the app was suspended, the first look, reply, or stop to see a gap of at least five seconds since the last look
  records how long the watch was away and clears any pending stall. A normal stop before suspension and the next start
  appear as `stopped` and `watching`. Each names the app's and its windows' states. A real stall while the watch keeps
  looking is logged when it begins and ends.

### The log says what PaperKit's handwriting reflow was doing before it crashed (story 1188, #1256, #1255)

On the iPad, 2026-11-22, the app crashed on a board a moment after a finger drag: Igor had tapped one of Larry's kept
groups over and over while the system's handwriting popover kept coming up over it, then dragged on the paper, and the
next touch began on PaperKit's handwriting reflow view. The crash is inside PaperKit itself: its reflow animation, the
one that moves handwritten words around when a selection is resized or moved, gave one of its word pictures a position
that is not a number, and the system stops the app for that. Nothing the board draws was involved, and the simulator
never shows the reflow. What put the reflow into that state, the log can't say. Before anything changes, it has to.

- **PaperKit's reflow showing on a board is a line in the log**, as it comes, changes and goes: what kind of view it is,
  where it sits on the paper, what it sits in, how many pictures it holds, and how many of them have a place or size that
  is not a number, endless or empty.
- **The line says what was going on around it**: how many strokes were selected, whether the system's handwriting popover
  was over the paper, how long since a touch began and what that touch began on.
- **A touch that begins on the reflow is a line at once**, with the same look, so a crash a moment after the touch still
  leaves the reflow's state behind it. That line says every reflow view, the empty one PaperKit keeps over every board
  included, since the reflow may not yet hold a picture when the touch goes down.
- **The log stays quiet otherwise**: a reflow that hasn't changed writes nothing more, and a board with no reflow showing
  writes nothing.
- Nothing Igor sees changes: this is the evidence for the fix, not the fix.

### The log says which tool Igor picked (story 1064, #1078; Igor, 2026-11-21: "Switched to eraser still drew normally")

Igor picked the eraser and the Pencil went on drawing. The log couldn't say why: every touch it has ever written names a
black pen, including touches that erased ink and touches that drew in blue, so what the board believes it holds is not
what Igor picked. Before anything changes how the tools behave, the log has to say both.

- **Every pen touch names two tools**: the one the tool picker shows selected (its kind, colour and width for an ink; the
  eraser; the lasso; or the picker's own name for anything else), beside the one the board says it is drawing with.
- **Picking a tool is a line of its own**: each time the picker's tool changes, the log says what the picker now shows
  and what the board now holds.
- Nothing Igor sees changes: this is the evidence for the fix, not the fix.

### The board acts on the tool Igor picked (story 1091, #1078)

What the board does around PaperKit's own ink, it decides from the tool the picker shows selected when the touch went
down, never from the tool the board says it holds (the log above shows those two disagree on the iPad):

- **The eraser** across a fold takes the fold, and across an answered question card takes the card, when the picker
  shows the eraser.
- **A pen** in the picker is what makes a stroke a candidate for a shape snap (the preview in that pen's colour and
  width), a hold in the margin (the room band and its menu), a word pickup, or an ink header; and its width is the
  width Larry's labels take.
- **One touch, one tool**: a pick made while the Pencil is down changes nothing about that touch; the next touch takes
  it.
- **A kept mark never changes the pen**: when Larry's ink lands and the board's tool changes under it, the tool goes
  back to the one Igor picked, not to one the picker no longer shows.
- PaperKit's own drawing and erasing are not changed here: if the board still draws with the eraser picked, the log
  says so, with both tools on the touch.
- The log goes on naming both tools on every touch and every pick, so the iPad shows whether they agree.

### A board opens drawing with the tool the picker shows (story 1098, #1078)

The tool picker remembers the last tool picked, on another board or before the app last closed, and opens with it
selected. The board used to start on a black pen whatever the picker showed, until the next pick: with the eraser
showing, the first strokes drew ink (seen on the iPad simulator; on the iPad it followed a crash that closed the app
with the eraser picked).

- **The first stroke uses the tool the picker shows**: the eraser erases, the lasso selects, and a pen draws in its own
  kind, colour and width, from the first touch on a board just opened, with no pick needed first.
- **Every pick after that** changes the tool as it always did.
- **The eraser draws no ink**, whether it was picked a moment ago, before BugKit's report sheet opened and closed, or
  in an earlier launch.

### A pen touch's path is in the log, and a pulled log replays on the Mac (stories 1104, 1105; bead context-grabber-y544)

A gesture bug on the iPad (a scratch-out that stayed ink, a shape that didn't snap, a margin hold that drew) has so far
been argued from tallies: how far a touch went and how many turns a zigzag made, never the stroke itself. So each
tuning round was a guess, checked only by Igor drawing again. The log now keeps what each decision read, so the same
stroke can be judged again on the Mac.

- **Every pen touch's path is in the session log**: each Pencil touch, and each finger touch while fingers draw, gives
  one line when it lifts with its points in board points, each point's time since it went down, whether it ended or the
  system called it off, and the tool the picker showed when it went down. A long touch is thinned to a few hundred
  points, its first and last kept.
- **Each gesture's verdict carries the stroke it judged**: a scratch-out's line (a zigzag with three or more turns), a
  margin hold's line and a shape snap's line each carry the stroke's own points and times beside the verdict.
- **Every touch's path stays with the session log**: on the device and on the Mac it is pulled to, never in a report's
  GitHub issue, and not in the board's log that goes to the Cockpit with each picture, which would grow with every
  stroke (the Cockpit has the board's strokes already). A gesture's line, a few a day, goes there with its stroke as
  before. A pen path is Igor's handwriting, so a fixture takes only gestures unless asked.
- **A pulled log becomes a fixture**: one command reads a pulled log and writes a fixture of its gesture touches
  (scratch-outs, held lifts, margin tries), each with what the iPad decided and what the Mac decides for the same
  points, and says where the two differ. Every touch, writing included, only when asked for. A fixture in the host
  tests holds each case to its expected verdict, so a gesture bug is fixed against Igor's real stroke on the Mac.
- Nothing Igor sees changes.

## Playing a board back, as Notability does (bead context-grabber-3tdv; stories 954–959; the ink alone decided and built, the words and the sound still to choose)

Igor, 2026-11-22 (#1139, on the iPad): *"where is my replay button so I can rewatch it the way you do in Notability?
Go do some research on Notability to see this."* Called **playback** here, so it isn't confused with the replays that
already exist for agents (a pulled log's touches, Larry's marks on a copy of the board).

**What Notability does** (researched 2026-11-22). From Notability's own help article (*Recording and Playing Audio*):
a record button in the note's toolbar records while he writes, with a level meter and a timer; *Play* enters playback;
with the hand tool, a tap on a word, a sketch or a photo plays what was said at that moment; a handle drags through the
recording, buttons skip 10 s either way, and the speed is 0.7×, 1×, 1.25×, 1.5× or 2×; what is written during playback
is tied to the recording too; a note keeps a list of its recordings, each can be trimmed, split, merged or deleted, and
it advises a new recording after an hour. Exporting a note can take the audio with it. From guides by others, which
disagree with each other on handwriting: with *Note Replay* on, the ink being written at that moment is highlighted, or
drawn again, as the sound plays; paid plans add a time-stamped transcript, where a tap on a paragraph shows the
handwriting from then. Recording is a paid feature there.

**What the board keeps today.**

- **When each stroke was drawn, and how fast.** Every stroke Igor draws keeps the moment it began and, for each of its
  points, how far into the stroke it was. The order and the pace of his drawing are already in every board, on every
  device, the old boards too.
- **Not every stroke has a moment of its own.** A text of Larry's that he kept shares one time across its letters;
  pasted ink and a snapped shape take the time they were made, not the time of the hand that drew them.
- **Nothing that was taken away.** Erased, scratched-out and undone ink is gone from the board, so playback can't show
  it being drawn and taken away.
- **No sound and no words.** Apple's dictation hears the mic and lets the sound go; the words go to the Cockpit with
  the next picture and are not kept on the board ([Whiteboard shapes](2026-11-01-whiteboard-shapes-design.md), *Talking while drawing*: "Words aren't kept for later"), and the
  board's log carries counts and places, never the words said or written.

**Three ways to go**, each adding to the one before:

| | Plays back | New on the board | Size | Privacy |
|---|---|---|---|---|
| 1. The ink alone | the board drawn again, in order, at his pace | nothing | none | as today |
| 2. And the words | the ink, with what he said shown as he said it | the words heard while the mic was open, with when | kilobytes an hour | his words kept on the board, and in iCloud if the board's meaning goes there |
| 3. And the sound | the ink with the sound of the room, as Notability does | a recording of each time he records | megabytes an hour | the room's sound kept, other voices in it too |

**Decided, 2026-11-22.** Igor asked for the replay button ("where is my replay button"), so the ink alone (option 1) is
built; the words and the sound (options 2 and 3) wait for his choice below.

**What Igor sees, for each.**

- **Play** is a button beside *?* and *Feedback*, under the page number, on the iPad, the iPhone and the Mac, on any
  board with ink, a board only looked at too. (Not on the board's menu as first proposed: that menu has room for no
  more rows, #848, and a look-only board has no menu.) It opens playback over the board where it was showing, on the board's own paper with the whole
  board already there faint, a ghost of the finished page, and draws it again over that ghost, stroke by stroke in the order they were drawn, each at the pace his hand drew it. A pause between
  strokes longer than two seconds plays as half a second, so an evening's board doesn't take an evening. Strokes that
  share one moment (a kept text, a paste) appear together. An open mic stops when playback opens.
- A bar along the bottom shows how far it is (the time played of the whole, and which stroke of how many), with play
  and pause, 10 s back and 10 s on, a handle to drag to any moment, and the speeds Notability has: one button steps
  through 0.7×, 1×, 1.25×, 1.5× and 2×, starting at 1×. At the end it stops with the whole board shown; *Play* again
  starts from the beginning. While playback shows, the board's own bar and tool picker are gone, so nothing can be
  drawn, undone, pasted or sent; a finger still pans and pinches the board.
- **Tap a stroke while playing** (one already drawn again, at the moment playback is at) and playback jumps to the
  moment it was drawn: the board as it was then, that stroke next, playing or paused as it was. A tap on faint ink not
  drawn yet jumps on to the moment it was drawn the same way. A tap on bare paper does nothing. Leaving playback (*Done*, or closing the board) shows the board as it is, with nothing changed: no save, no
  undo step, nothing sent to Larry.
- **The paper and the ghost** (Igor, 2026-11-22, #1169 on the iPad: *"when doing playback I need to start with a
  pre-written ghost on the page and I also need to have whatever the default background is and maybe some indicator that
  I'm writing above or below on a separate page"*). Playback shows the board's paper as the board has it: its colour, its
  grid or ruled lines or neither, and the faint line where each page ends. Under the ink being drawn again, the whole
  finished board shows faint from the first moment, so he sees the page he is heading to and where each stroke will land;
  a stroke drawn again shows at full strength over its own ghost. (Taken as the finished board shown faint. The other
  reading, Larry's ghosts on the page during playback, is not built: Larry's ghosts have no moment of their own, and
  waits for Igor to ask.)
- **Writing above or below.** When the stroke being drawn again is off the screen, above or below what shows, a small
  label at that edge of the board says so and on which page: *Writing above, page 1* at the top, *Writing below, page 3*
  at the bottom. A tap on it moves the board to that stroke. It goes as soon as the stroke being drawn is on the screen
  again. Playback never moves the board by itself: a finger pans it, and the label shows where to go.
- **With the words (option 2):** while the mic is open, the words it heard are kept with the board, each line with the
  moment it was said. In playback the line being said shows above the bar as the ink of that moment draws, and a tap on
  a stroke shows what he was saying as he drew it. The mic is still the one the board has today: open only with *Ask at my pauses*
  on, stopped by a call with Larry or a shake report, so words are kept only while it is open.
- **With the sound (option 3):** a record button of its own, beside the mic, records the room while he draws, whether
  *Ask at my pauses* is on or not, with the time recorded showing while it runs. Playback plays the sound with the ink, and a tap on
  a stroke plays what was said as he drew it. A call with Larry, or a shake report, stops the recording as it stops the
  mic, and he taps it again to go on. A board keeps a list of its recordings, each one deletable; deleting the board
  deletes them.
- **Nothing in playback goes to Larry.** The words and the sound stay out of the pictures, the board's log and the
  Cockpit unless a later change decides otherwise.
- A board whose ink can't be read, or a board with no ink, has no *Play*.

**The choices that are Igor's** (the plan beside this spec has the arithmetic):

1. Build the ink alone now? It needs nothing from him and changes nothing about what is kept. **Decided: yes**
   (2026-11-22, his replay button).
2. Then the words or the sound? The words are small, readable and searchable later, but they're Apple's dictation, not
   what he said; the sound is what Notability has, and it is the room, other people's voices included, which they may
   need to agree to.
3. If the sound: kept on the device that recorded it, or sent through iCloud with the board? Through iCloud, the iPhone
   plays back what the iPad heard, at the cost of his iCloud storage and the upload; on the device, a reinstall loses it.

## Trial on paper (removed 2026-11-07)

The trial (#635, #636) settled what it was for: Igor made paper the default on 2026-11-03 and the only canvas on 2026-11-07.
*Try on paper* is gone with the old canvas, and boards drawn on the old canvas are dropped (2026-11-22).

## Later steps (not in this build)

Ghosts, Larry's turn and the board's open mic are built, and specified in
[Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md). The Lavish prototype showed that a mark that
could mean two things is best answered with both readings as ghosts, and that Claude can't read cursive, so words come
from Igor's voice.

1. **Voice.** "Your turn" said out loud gets a full drawing turn. (The open mic's level meter and microphone picker are
   built: [Which microphone, and what it hears](2026-11-01-whiteboard-shapes-design.md), #1139.)
2. **Larry.** A call with the board as Larry's context while Igor keeps drawing.

Claude's side runs through the Cockpit on the Mac (Igor's pick), so no model key goes on the device. The cost is
that ghosts need the tailnet.

## Acceptance

- Picking the eraser, the lasso or another pen in the tool picker logs what the picker shows and what the board holds, and every pen touch after it names both (story 1064, #1078).
- (Proposed, cc75 step 2, story 1109.) A board drawn on the iPad with a fold, a header, a question card and a kept
  text of Larry's opens on the iPhone with all four; a card left on the iPhone is gone after the next sync; an iPad
  whose meaning file was unreadable sends up no meaning over iCloud's, even after a fold is opened, until it has taken
  iCloud's back; a newer version whose drawing fails to come down is not taken, and neither is one whose meaning
  can't be read: the device keeps the pair it had and asks again on the next sync; a TestFlight build that sends the
  meaning up isn't shipped until the CloudKit schema is deployed to production.
- (Proposed, bead context-grabber-3tdv, stories 956–959.) *Play* on a board with ink clears it and draws it again in
  the order it was drawn; a tap on a stroke jumps to the moment it was drawn; *Done* shows the board as it was, with no
  save, no undo step and nothing sent. With the words or the sound chosen, a tap on a stroke shows or plays what was being
  said as it was drawn.
- On the iPad, the Pencil draws, a finger pans, and the eraser removes strokes.
- A stroke whose ink is of a kind the app has no name for draws, saves and goes to Larry like any other, and the board
  stays open; the log names that kind once (#1083).
- Close the board, kill the app, reopen it: the drawing is there, at the place he left it.
- A new board is one page wide and scrolls only up and down. Draw to the bottom of a page and keep scrolling: a blank
  page is always there. The ink keeps Notes' feel past 4,000 and past 9,600 points down the column.
- Pinching out stops at the page's width. The page number reads right while scrolling, and isn't in any picture.
- Writing a page with the hand resting on the glass leaves the zoom where it was; so does a palm and a fingertip landing
  together. Two fingertips, with nothing else down, still pinch in and out.
- Lifting the Pencil and putting two fingers down at once (within 400 ms) doesn't zoom; a moment later the same two
  fingers pinch.
- A board drawn on the old canvas is not in the boards list, and a link to one shows the copyable problem that says why.
- There is no *New boards on paper* switch and no *Try on paper*: every new board is on paper.
- A new board made after the default ships is on paper, shows no test cross or ring, and an older build still opens it.
- A save that fails on a board on paper shows a problem that can be copied, on the board or, when leaving it, on the list.
- A new board reads *Page 1 of 1*. Ink on it makes that *of 2*; ink crossing onto page 2 makes it *of 3*.
- With three pages drawn and page 2 on screen, Send to Larry shows page 2 at a size he can read.
- Ruled lines from the Board menu show like notebook paper, the same on every page, are in no picture, and are remembered
  like the grid.
- On a board on paper, the grid and ruled lines lie under the ink. Choosing one takes the other away, each is remembered by that
  board on this device, and a new board starts with the grid.
- On each colour of a board on paper, page lines, grid and ghosts show; changing colour or lines leaves the ink on screen, the
  stroke count the same and no new undo step.
- Send to Larry with a drawing: the board's thread appears in Chat with the picture, its ink dark on white even when the
  iPad is in dark mode.
- The tile opens the boards, newest first. + New board opens an empty board; closing it without a stroke leaves no
  row behind.
- Draw on the iPad and close the board: within a minute, the iPhone's list shows it with the same picture. Opening
  it there shows the drawing with no tool picker, and a finger only pans.
- Rename and delete a board on the iPad: the iPhone follows on its next refresh.
- Open a board the iPad drew and tap its name in the bar: the rename box, filled with the name. Rename it: the bar
  shows the new name at once, the next stroke draws, the Board menu still opens and closes, and back in the list the
  row has the new name. On another device's board the name in the bar does nothing.
- On the iPad, swipe left on a board's row: Rename is there beside Delete. Rename it: the row shows the new name at the
  top of the list, and opening the board, its bar does too.
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
  them and leaves the ink as it was. Closing and reopening that board keeps the choice; a new board opens with the grid
  on, and a board made before that change opens as it did.
- Pinched all the way out and all the way in, the lines stay faint and evenly spaced, never a grey wash.
- Send to Larry and a ghost turn with the grid on: the picture has no lines.
