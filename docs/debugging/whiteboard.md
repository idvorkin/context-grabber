# Debugging the whiteboard: its session-log events

The whiteboard's rows of the session-log table in [DEBUGGING.md](../DEBUGGING.md), one event family or action per
line, so that two changes adding events to the board touch different lines. The logs, how to pull them and how a line
is added are in [DEBUGGING.md](../DEBUGGING.md); this file only says what each whiteboard event holds (key fields).

**Adding a line here**: a new event or action is a new bullet under its area (or a new area), and a new field is added
to that event's own bullet; never join two events on one line.

## Whiteboard playback (stories 948, 954, 956–958, bead context-grabber-3tdv)

- `whiteboard` action:
  - playback_start with board, strokes, timed (strokes drawn over time: their points have time offsets), shared (strokes that share one moment and appear together), real_s (first stroke's start to the last one's end, as drawn), plays_s (the playback's length) and ms (building the timeline): Play tapped. Timed far below strokes says a board's timestamps didn't survive. Also (#1169) rules (none, grid, ruled), pages, ghost (the faint whole board drawn) and ghost_ms (its cost), opened_page (the page showing when Play was tapped) and first_page (the first stroke's page): opened_page past first_page is a playback that starts off the screen
  - playback_offscreen with board, where (above, below, on_screen), page (the stroke's), visible_page, stroke and at_s: story 948's label appearing, changing or going
  - playback_go with board, stroke and page: the label tapped, the board moved to the stroke
  - playback_seek with board, how (tap, scrub, back, forward, voiceover), from_s, to_s and stroke (a tap's or VoiceOver's stroke, its place in the drawing)
  - playback_tap with board, hit: false and showing: a tap in playback that found no stroke near
  - playback_speed with board and speed
  - playback_end with board, watched_s, reached_end, seeks, at_s, frames (new drawings set), slowest_draw_ms (the slowest of them, a big board's cost) and offscreen_shown (how often story 948's label showed): Done, or the board closing

## Whiteboard (stories 340–345, 347–369, 370–429, 663–665, 825, 228, 960, 962, 963, 1063, 1064, 1106)

- `ui` (action: open_whiteboard with from: home / hook / a link's source, such as chat or shortcut; close_whiteboard)
- `whiteboard` (action:
  - unknown_ink with ink: the kind as the ink spells it, or none, where: strokes / tool / hide / fold and points: the stroke's point count, 0 off a stroke — a stroke of an ink the app has no name for, logged once per kind per launch (story 1063, #1083)
  - unknown_ink_saved with board, kinds (each unknown kind the saved board holds), unreadable (those a saved board can't be read back with) and as_pen (the strokes saved as the pen in their own colour so the board opens again), on every save that holds one (story 1092, bead context-grabber-3b02)
  - tool_changed with board, picker_tool (what the tool picker shows selected: an ink's kind, colour and width, eraser, lasso, or the item's identifier), tool and tool_ink (what the board's drawingTool says): each pick in the tool picker, which can log it twice, and once as the board opens, and paper_touch carries picker_tool too, as drawingTool was seen to say a black pen while Igor erased or drew blue (story 1064, #1078)
  - ink_moved with board, strokes, moved, dx, dy, top_moved_y and zoom: strokes changed place with none added or removed, #624
  - list with boards, own — the ones this device draws —, migrated: the single board from before the list became its first row, and new_board: false on an iPhone, which offers no New board (story 746)
  - new with board and on_paper: always true since 2026-11-07
  - open with board, strokes, editable — false for a board another device draws or one drawn on the old canvas, which opens to look at only, and for every board on an iPhone —, old_canvas (story 658) and look_only: the bar's reason, null on a board that draws (story 746)
  - close with board, strokes and saved — false when that last write failed, which also puts the problem on the list — logged only when leaving had unsaved strokes to write
  - send with board, strokes, bytes, pixels and frame: the picture's rect on the board, x, y, w, h — the pages on screen
  - rename with board
  - paper with board and paper: the board's colour chosen
  - lettering with board and lettering: single / font, the Board menu's Real font switch (#950)
  - delete with board, own — false for a board another device drew — and why: asked, or empty — a new board closed without a stroke, and keys: how many of this device's whiteboard_*_<id> keys it forgot (story 1106)
  - meaning_migrated with boards: each board whose meaning moved from this device's keys into its own file at launch, with its counts — rev, handled, texts, headers, cards, labels, theirs — once, the launch it moves (story 1106; labels and theirs, the kept labels and Larry's ink, move from their own keys, story 1099)
  - meaning_behind with board, meaning_ink_bytes and ink_bytes: as a board opens, its meaning was saved with a drawing of another size, so a save was cut off between the drawing and the meaning and a batch of Larry's in that drawing may come again (story 1106; a board of this device's own fetched back from iCloud can show it too)
  - ghosts_on, ghosts_off with board
  - grid_on, grid_off with board (stories 407, 408)
  - ghosts with board, count and larry: the ghosts on the board changed
  - keep with board, who: claude or larry, and strokes — a mark made ink by its Keep (a tap, before story 825); since #883 also kind (text, rect, line, …), width (the pen in board points, never under the thinnest the iPad draws), letters (a label's letter height in points), color (#rrggbb as in light mode), zoom, and in_view (whether the ink landed inside what's on screen); since #949 pen_in_hand (the width of the pen Igor last held, in board points, which a label with no pen of its own takes; absent before the canvas has said)
  - mark_chosen with board, who, kind and within: how many marks the tap was within reach of, the nearest taking it (#941) — a tap on a mark showed its Keep and Dismiss, nothing changed yet (story 825, #883)
  - mark_choice with board and choice: keep (who; the `keep` line follows), dismiss (who, kind, and left: the marks still showing; only that mark of Larry's stays gone on the next open, #883) or away (why: tap_off — a tap off the marks, which dismisses nothing — or drew: the Pencil or a drawing finger went down)
  - ghosts_dismissed with board, count and larrys is in logs from before story 825 only, when a tap off the marks dismissed them (#823)
  - paste with board, characters, of — how many there were — and strokes: 0 when nothing could be drawn, and lettering: single / font, the board's (#950)
  - vad with board, ms, cue (rhythm, mid-line, +quick, question) and median: the pause after a stroke, learned from his rhythm, 1.5–5 s (story 892), or with cue (new line, hand away) and left_ms: a cue cut it short (story 893)
  - keep_all with board, marks, strokes and moved: Larry's marks kept at once, how many moved off ink (story 895)
  - keep_group with board, marks, strokes and group: Keep group kept the chosen mark's reply where it showed, under the one group `reply-<row id>` (story 995, #942)
  - tidy with board, labels — the kept labels and pastes it knew — and moved, then paper_move with strokes and pages when one moved (story 896)
  - scratch with board, fired, reversals, speed, why and strokes: a zigzag with three or more turns, whether it scratched out and what it took (stories 890, 891)
    - one that fired also carries undid_zigzag (the take-back of PaperKit's own step took the zigzag), base (taken_back — PaperKit's step for the zigzag undone; redone — the take-back undid some other step, put straight back with Redo, the zigzag's own step left beneath; untouched — nothing of PaperKit's to take back), wanted (the strokes the board set), held (the strokes PaperKit holds after the set), held_gone (of those, the scratched ones and the zigzag: anything but 0 is ink PaperKit kept, #999) and board_strokes (the board's own count), and scratch_held with board, held, held_gone and board_strokes says it again a second later
    - a scratch-out over a fold (story 905) logs `board_outline` erase_fold, then scratch_fold with board, base (as above), wanted, held, held_gone and board_strokes as above (held_gone above 0: PaperKit kept the folded section, #1015), and scratch_held with fold: true a second later
    - a zigzag that found nothing to erase (why no ink or beside ink, #1000, stories 1051, 1052) carries nothing (taken_away — it went and the board said *Nothing under the scribble to erase*; kept — PaperKit's step for it couldn't be taken back, so it stays ink) and could_undo
  - scratch_flash with board, strokes (the struck ink flashed, the zigzag's own stroke counted) and reduce_motion (stories 1050, 1043)
  - turn_cancelled with board and why: pen_down — the Pencil went down while Claude's turn was out, and its `whiteboard_turn` line says cancelled: pen_down (story 894)
  - responder_read with board, ok, responder or reason and status, set — whether the board's responder was ever set, an answer without it counted as set — ticked: what the Board menu shows after the read (story 659), and defaulting_to: larry when a board nobody set is given to Larry on opening (story 962)
  - responder with board and responder: a pick in the Board menu, or with why: default the write that gives a never-set board to Larry (story 962); its failure an `error` whiteboard_responder
  - larry_turn_over with board, why: reply, timeout or done_no_reply (Larry marked the picture done and wrote nothing after it, #913; with picture and looking_s), and next: send — one fresh picture, with said_chars — or none, story 662; a timeout also carries what its copyable *Larry didn't answer* says, story 669: problem — WhiteboardView.larryTimeout — sent_at, waited_s, ink_waiting, words_waiting, cockpit_answering and mark — where the picture was, the same reading the note's state and the 20-second controls use: received (the Cockpit had it, Larry hadn't picked it up: *Sent*), seen, done, none (the Cockpit never took it, on a thread whose other pictures carry marks) or unknown (a Cockpit that marks nothing, the thread not read yet, or a *Send to Larry*), story 773
  - problem_dismissed with board and context — *Larry didn't answer* dismissed, by a tap or the `GRABBER_WHITEBOARD_LARRY_TIMEOUT` hook, story 761
  - larry_already_has with board, from: button (*Larry's turn*) or send (*Send to Larry*), and looking_s — a tap that sent nothing because Larry is looking at the board as it is with no words waiting and the same part of the board on screen, story 765; the note says *Larry already has this* for two seconds
  - conversation with board, open: the note's panel opened or closed by a tap on its line, remembered for the next board, and messages: how many of the thread's last ten it holds, story 768
  - conversation_chat with board, thread and found: on an iPhone, which has no panel, the tap opened the board's thread in Chat. found: this_device (the thread this device keeps for the board) or none (this device keeps no thread for the board, thread empty: a `chat_lookup` from: note follows, story 949)
  - chat_lookup with board and from (list — the boards list's chat bubble, story 1097, or the `GRABBER_WHITEBOARD_LIST_CHAT` hook — or note — the note's tap on an iPhone, story 949; #1163): a board's thread looked for among Larry's chats. Found, it carries thread and source: device (the thread this device keeps for the board), remembered (found among the chats earlier this launch) or chats (a thread titled with the board's name, one of whose messages came from this board; with threads — the chats read — candidates — those titled with the board's name — checked and ms), and Chat opens. Not found, it carries outcome: no_address (no Cockpit set), list_failed (the chats couldn't be read, with status), none (no chat is the board's, with threads, candidates and checked: the list shows *No chat with Larry for this board yet*, the note says where the conversation is, on the device that drew the board, or not yet, #1161) or failed (the Cockpit out of reach, with reason), each with ms, and a copyable problem that files no report)
- `whiteboard` action:
  - mic_on / mic_off (why: tap / closed / background / call / report / ghosts_off, #824, or switch_mic — another microphone picked with the mic open, its mic_on with picked: whether the pick took, story 1103; a mic_off with opening: true closed an opening still on its way, so it never opened; a mic that ends by itself is BugKit's `dictation_stop`)
  - mic_refused (why: call_live, or ghosts_off: the words would reach no one, #824; with opening: true, found while the microphones were read or the mic switched, story 1103)
  - mic_inputs with board, count — the microphones connected at an opening — and automatic: no microphone picked (story 1103)
  - mic_hears with board, input — the route's input, the system's pick under Automatic, none when there is none — why: listening (the mic opened) or route_change (a microphone plugged in, paired or pulled while open) and automatic (story 1103)
  - mic_picked with board, automatic — Automatic picked — and mic_open: whether the mic was open, so it closes and reopens on the pick (story 1103)
  - spoke (chars — a count, never the words; went: now, held — for the next turn, or ghosts_off — dropped)
- `whiteboard_turn` (who: claude — ghosts after a pause or words; board, ms — the whole answer, bytes of the picture, pause_ms (a pause's turn only), render_ms, encode_ms and upload_ms — the iPad's half, story 661, the first three also sent to the Cockpit; responder — who the Cockpit said answered, story 659; larry: hand — a Larry board's turn handed to his thread — held — he is still looking at the last one, story 662 — or why not (stale, first_send_waiting); said_chars: how much speech the turn carried, kept for the next turn when ok is false, stale: Igor sent the turn away first — a dismissal or Ghosts off — so the answer isn't shown; streamed: true when the Cockpit answered line by line, false for one JSON; broken: what cut the reading short — a dropped connection, the 10 s, the Cockpit's own error line, no last line — when it was; ok with shapes and first_shape_ms — how long until the first mark, the same as ms for one JSON; or ok: false with reason — too_soon: a ghost turn the Cockpit answered 429, skipped — and, for a refusal, status
  - who: larry — the picture handed to his thread, not his answer; board, ms, bytes, pixels — the picture's width x height — picture, new_thread, from: button, responder — a Larry board's pause — reply, timeout or done_no_reply — the one picture after his answer, 3 minutes without one, or his done mark with nothing written after it, story 662 — and said_chars; when the connection was lost under it (#1136, stories 908, 909): lost_step — upload or message — lost_code (-1005), lost_retried — the one quiet second try was made — lost_retry_ok, lost_app and retry_app — the app's state (active, inactive, background) when it was lost and when it went again
  - what became of the strokes: strokes_ok: true with strokes, strokes_new and strokes_erased, or strokes_ok: false with strokes_reason and, for a refusal, strokes_status; ok with thread, or ok: false with reason and, for a refusal, status)
- `whiteboard_log` (#883, story 771: the boards' log lines since the last the archive took, after each picture for Larry — why: larry_turn or send; board, records, launch, and ok with inserted and duplicate, or ok: false with reason and, for a refusal, status; lines not taken go with the next picture; on the box they are the `whiteboard.log` stream of cockpit-data's archive.sqlite3, one record a line with guid `<launch>:<seq>`, launch, seq, t and line, after a header record, guid `<launch>:000000`, with the build: app, sha, branch, system, device)
- `whiteboard_marks` (action:
  - shown with board, row, shapes and picture — a row of Larry's marks now on the board
  - unplaced with board and row — a row of marks with no usable frame, not drawn
  - back with board and after — the thread answering again after that many failed looks
  - thread_gone with board and thread — the Cockpit answered 404, so the board's next picture starts a new thread)
- `whiteboard_sync` (why: open / foreground / pull / board_closed / rename / paper / delete / find_board — a *Jump to board* or a board link asking iCloud first, only for another device's board or one not here (`whiteboard` action: find says which, #1137) / again — a sync asked for while one ran; ok with boards, fetched — other devices' boards new or changed — dropped — deleted on another device — tombstones, the boards iCloud says were deleted, and resend, true when a delete took a board changed since the version it saw, so it goes up again
  - or ok: false with skipped: not_entitled / account_<CKAccountStatus> — no iCloud, the boards stay on this device — or message: the CloudKit error, retried on the next sync, with board when it was that one board's download
  - otherwise, since #1002, with step — zone, delete, upload, list or download: the call that threw —, code, pending — boards waiting to go up when the sync began —, first_of_launch, board for a delete or an upload and strokes for an upload, save_error and delete_error — each record's own result of the write, code, server: CloudKit's server message, text, and domain when not CloudKit's, so an upload's 22/2024 *Atomic failure* names the sibling that failed —, partial — a partial failure's per-record errors by record name — and retry_after, CloudKit's seconds to wait
  - either result carries zone_error when making the boards' zone failed and the sync went on
  - a board that came down without a picture it could keep logs its own line with board, picture: drawn_here and message, the list's picture drawn on this device (story 1061, #1043))
- `error` (where:
  - whiteboard_index / whiteboard_migrate / whiteboard_meaning with board, operation: migrate / migrate_ink (story 1099) / open / save, and message — a board's meaning file couldn't be moved, read or written; a failed migrate keeps its keys and tries again next launch (story 1106)
  - whiteboard_load with board, message — why the drawing couldn't be read — set_aside, kept_at — the name it was moved aside to, null when it wasn't — and move_error: set_aside false with the move's error means the board was held, its original left in place and the board opened look only (story 1060, #1042)
  - whiteboard_save / whiteboard_send / whiteboard_responder with board, responder and message — a pick the Cockpit didn't take
  - whiteboard_turn with who, board and message, once when turns start failing, again only after one has succeeded
  - whiteboard_marks with board, thread and message, once when looking at the thread starts failing, again only after a look has succeeded)
- **save_timing** (#1044), one per save of a board drawn on: board, trigger (debounce: the moment after a stroke; close; background; fixture: a launch hook's board), strokes, revision (the board's `updated` once the list was told), encode_ms, write_ms, picture_ms, index_ms and total_ms to a tenth of a millisecond, and failed naming the stage that threw; never the drawing

## Pen paths (stories 1104, 1105; spec 2026-11-01-whiteboard-design.md, *A pen touch's path is in the log*)

- `board_touch` (action: path with board, touch_type (pencil, or finger while fingers draw), picker_tool (what the tool picker showed as the touch went down, as `tool_changed` says it), phase (ended, or cancelled: the system called it off), points, ms (down to lift) and path: the touch's points in board points with each one's time since it went down, `x,y,ms;dx,dy,dms;...` in tenths of a point and whole ms, thinned to 600 points), one per drawing touch at its lift; not a `whiteboard` type, so never sent to the Cockpit
- The stroke each gesture judged, in the same form, as a `path` field on `whiteboard` scratch (the zigzag), shape_snap and shape_snap_none (the held stroke) and `board_margin` hold_stroke
- `just touch-fixture <log>` turns a pulled log's gestures into host cases (docs/TESTING.md)

## Question cards on a whiteboard (stories 880–886, spec 2026-11-16-whiteboard-question-cards-design.md)

- `whiteboard_questions` action:
  - landed (board, from: asks — open asks naming the board's thread, put near the top-left of the view — or larry — a question mark in Larry's reply, put where it says —, cards: how many new cards)
  - answers (board, asked: the cards whose ask is no longer open, found: how many the Cockpit's GET /ink/answers returned, filled: how many cards took an answer)
  - open (board, ask, answered: whether it opens read-only)
  - expand and collapse (board, ask: an answered card folded to its chip or opened out)
  - answered (board, ask, verb: what the card's decision did, after Chat's own decision_answer or decision_menu line with from: board)
  - erased (board, asks: the answered cards the eraser took, story 886)
- `error` with where:
  - whiteboard_questions_asks (board, why: what asked for the read, message: the HTTP status or network error — the open asks could not be read, once until a read succeeds)
  - whiteboard_questions_answers (board, message: the answers could not be read, once until a read succeeds)
- the cards keep what they showed

## A board on paper (stories 590–626, 666, #636)

- `whiteboard` with `action`:
  - **paper_touch**, one per touch, with board: `touch_type` (pencil / finger: pencil when any touch in it was the Pencil, #825), `touch_types` (how many touches of each kind it held), `finger_radius` (the largest finger contact, in points, to tell a resting palm from a finger), `gesture`, `outcome`, `travel`, `fingers`, `seconds`, `scroll_dx`, `scroll_dy`, `zoom_from`, `zoom_to`, `selected`, `selection_changes`, `ink_added`, `ink_moved`, `ink_removed`, `began_drawing`, `page_added_during`, `tool`, `tool_ink` (the pen's kind, `#rrggbb` and width as the touch began: Igor's own colour, context-grabber-a3w), `touch_mode`, `auto_draws`, `pages` and `page`, which is how to settle what a finger does
  - **paper_ink**, one per change, with board: strokes, pages, `wanted` (the pages the ink now calls for), `added`, `added_box` (the added ink's box in board points, empty with none), `moved`, `removed`, `can_undo`, `can_redo`, `ms`, `in_touch` (whether the touch watcher heard a touch going), `selected` (PaperKit's selection then), `undoing` (an Undo or Redo made it), `came_back` (after a scratch-out, how many of its strokes came back with no Undo or Redo; absent with none, #999)
    - a change no touch was heard making, not an Undo, also carries the **watch state** (#945): `watcher_state`, `watcher_down` (touches it thinks are down), `watcher_on`, `touches_down`, `in_window`, `hit` (the view on top at the change's centre and three of its parents, by class) and `hit_on_board` (false when something over the board took the spot)
  - **paper_selection** (#945), every selection PaperKit reports: `selected`, `strokes` (of those, the ink), `box` (their box in board points), `put_back` (a tap's selection taken straight back), `in_touch`, `touch_mode`, and the watch state when no touch was heard
  - **selection_label** (story 1095, #1045), each new label on the selection: `board`, `kind` (ink, text, part_text, group, part_group, connector, arrow, things, mixed), `label` (its words), `strokes` (how many are selected)
  - **paper_open**, with board: strokes, pages, `width` (wider than 820 for an old-canvas board's wider ink), `ink` (the ink's box as shown, after an old-canvas board's move onto pages), `editable` (false on a look-only board, story 658), `ms`
  - **paper_not_ink**, with board, `elements` and strokes: something on the board that isn't a stroke and so wouldn't be saved
- `paper_probe` lines are in logs from before 2026-11-07 only: the trial on paper that wrote them is gone

## Ghosts on paper (stories 613–636, #636)

- `whiteboard` with `action`:
  - **paper_ghosts**, when the ghosts on show change: `count`, `kinds` (how many of each kind show, such as `rect` and `text`, #941), `past_side` (a mark past the column's sides or above it, which paper can't show yet), `pages`, `visible`, `sheet`, `screen_scale`
  - **paper_tap**, a finger tap with ghosts showing: `at` in board points, `ghosts_before`, `ghosts_after`, `chosen` (a mark's Keep and Dismiss show after it, story 825), `selected_at_tap`, `selection_box` (the selected ink's box, board points), `on_selection` (the tap was within a fingertip of that box and reached no mark, so the selection was kept for its menu, story 1101), `touch_mode` and `auto_draws` (what a finger was set to do as it tapped)
  - **paper_tap_dot**, the dot PaperKit draws where a finger tapped while marks show, a few tenths of a second after the lift and with a finger set not to draw, taken back by its own undo so the board never counts it (stories 616, 825): `at`, `dot` (its box, board points), `ms` (after the tap), `could_undo`, `gone` (the undo took back that dot and nothing else; false is a dot left on the board and counted as ink, any other step the undo took redone), `strokes`
  - **group_tap**, a finger tap on a stroke of a group (a kept reply, one of Larry's groups) with no marks showing, which selects the whole group ready to drag (story 947, #947): `at` (board points), `group` (its name), `strokes` (selected), `touch_mode`, `fingers_draw`, `selected` (what PaperKit holds after). **group_tap_put_back**, the group selected again: `why` (`selection`: PaperKit made its own selection for the same tap within a second; `tap_dot`: taking back the tap's dot left nothing selected), `had`, `to`. **group_tap_held**, 1.2 s after the tap: `held` (the group still the whole selection), `selected`, `strokes`, `touched_since` (a touch came first, so nothing was put back). A tap that selected one stroke, or nothing, on a group shows here as `held: false`.
  - **mark_buttons**, Keep and Dismiss placed or put away: `chosen`, `frame` (the mark's box in the view's points, empty when they go), `view`
  - **paper_keep**: `name` (the step's name on Undo, such as *Keep group*, #966), `undo_name` (the name on top of the stack after the keep; another is a step that went on above it), `strokes`, `total`, `pages_before`, `pages`, `same_ids` (the names Larry knows the mark by are the same before and after PaperKit; false is a bug), `ids_made` and `ids_back` (how many ids went in and came out), `drift` (how far PaperKit moved it, in board points), `in_view` (the ink is inside the visible frame), `screen_scale` (the zoom), `width_back` (the pen PaperKit holds the kept mark at, beside the keep's `width`; #883), `tool_before`, `tool_after` and `tool_restored` (the pen in hand around the keep, kind, `#rrggbb` and width; a keep that changed it puts it back, context-grabber-a3w), `could_undo` and `could_redo` (before the keep), `can_undo`, `can_redo`, `undo_on_window` (the undo stack is the window's, which other boards share), `ms`; or only `no_markup`: true, when the board isn't laid out yet and its load brings the mark in
  - **paper_step**, a kept mark undone or redone: `strokes`, `pages`, `can_undo`, `can_redo`
  - **paper_undo** and **paper_redo** (#966), every Undo and Redo on the board's stack but the board's own take-backs: `name` (the step's), `strokes_before`, `strokes`, `can_undo`, `can_redo`, `undo_name` (what Undo would take next)
  - **paper_undo_button** (#965), a press of the bar's own Undo or Redo (or of `GRABBER_WHITEBOARD_BAR_UNDO`), before its step runs: `redo` (false for Undo), `can` (the stack had a step for it; false is a press that did nothing), `name` (the step's, such as *Keep group*; empty for his own stroke), `strokes`
  - **paper_undo_left_ours** (#966), a take-back of PaperKit's step (a tap's dot, a zigzag, a drop) that found one of the board's own steps on top and put it straight back with Redo: `why` (which take-back), `name` (the board's step left on the stack, such as *Keep group*), `undo_name`, `can_undo`, `can_redo`, `strokes`
  - **paper_undo_closed**, a board that kept a mark closing, its steps taken off the stack: `can_undo` and `can_redo` (true says steps of PaperKit's own are still on it)
  - **paper_press_hook**, a press by `GRABBER_WHITEBOARD_AFTER_KEEP`: `press`, `strokes`, `pages`, `can_undo`, `can_redo`
  - **paper_page_hook**, the view sent to a page by `GRABBER_WHITEBOARD_PAGE_AFTER_INK`: `page`, `pages`, `visible`
  - **paper_touch** adds `ghosts`, `ghost_slip` (the worst distance, in screen points, over that touch, between where the sheet has a ghost and where the visible frame says it should be) and `ghost_checks` (how many looks that took: 0 or few on a long scroll says PaperKit's delegate didn't report it)
  - `touch_mode` is `selection` while ghosts show
- The turns themselves are `whiteboard_turn` and `whiteboard_marks`, as on any board

## Lines and colour on paper (stories 652–657, #635, #608)

- `whiteboard` with `action`:
  - **grid_on**, **grid_off**, **ruled_on**, **ruled_off**
  - **paper_ink_look** with `why`: **open**, a second after a board with ink opens (#845), **sheet**, a second after a colour or lines changed under ink, **kept** after ink is added
  - **paper_responder**, three seconds after a choice in the Board menu: `times_lost` (how often the canvas had to take its first responder back), `has_it`
  - **board_cover** (#1140, story 1102), looked at once a second while a board is on screen, a line whenever what sits over it changes: `covers` (the class of each controller presented over the window, outermost first: the board's own full-screen screen is the first on the iPad, so a cover over the board is the second), `style` (the top one's presentation style), `presentation` (its presentation controller's class), `frame` (its view on the screen), `source` and `source_rect` (what a popover points at), `remote` (another process draws it, so touches on it never reach the app's log), `edit_menu` (the frame of a *Paste · Select All* style menu showing, or empty), `responder` (what would answer a Paste), and `was_ms` (how long the state before it stayed)
  - **keyboard_shown**, whenever the on-screen keyboard rises over a board (#850): `height`, `paper_has_it`, `taking_back` (whether the menu's three seconds were running)

## Paste on paper (stories 637–650, #636)

- `whiteboard` with `action`:
  - **paper_paste**, each ⌘V: `how` (key or hook), `has_text`, `has_image`, `types` (what the clipboard held), `strokes_before`, and `went`: **ink** (text), **paperkit** (PaperKit took copied strokes itself), **landed_here** (it didn't, so they went in the middle of the view), **refused_picture**, **nobody**
  - The bar's button logs only **paste**, as on any board
  - **paste_strokes**: `strokes`
  - **paper_copy_hook**, a copy by `GRABBER_WHITEBOARD_AFTER_INK`: `took` (something took the system's Copy), `selected`, `types`
  - A paste then shows as **paper_keep**, with `ink`, `visible`, `sheet` and `markup` saying where it landed, and **paper_step** for its undo
  - **paper_ink_look**, a second after any kept or pasted ink, a change under ink, or a board with ink opening: `why`, `ink`, `spot` (where it is in the view), `in_view`, `strokes`, `visible`, `shown_px` (pixels unlike the paper in the view's own picture at the spot; 0 with `in_view` true is ink saved and counted but missing from the screen, story 650; -1 when none of the spot is in the view or the picture couldn't be read), `attempt` (0 for the first look, 1 or 2 for a look after a heal)
  - **paper_kept_ink** (context-grabber-ikya), a second after a mark is kept (a ghost's Keep, Keep group, Keep all, a keep that makes room), and again after each heal it asks for: `why` (**keep**, or the room's **keep_text**, **keep_late**, **keep_group**), `strokes`, `inks_made` (each ink kind and `#rrggbb` among the kept strokes as made, with how many: `com.apple.ink.pen #ba39e6 x13`), `inks_held` (the same strokes as PaperKit held them right after the keep) and `inks_held_later` (a second on; empty once an undo took them back), `ink`, `spot`, `in_view`, the view's own picture at the spot sorted by colour: `ink_px` (near the kept ink's colour), `dark_px` (near black), `other_px` (the rest, edges among them; -1s when none of the spot is in the view), `dark_before` (dark pixels at the spot just before the keep: Igor's ink already there), `ink_span` (how wide and tall the ink's colour spans, in view points), `expected_px` and `expected_span` (the same strokes drawn alone on this paper: their colour's pixels and how far any of them spans; 0 when they're gone or can't be drawn), `attempt` (0, then 1 or 2 after a heal), and `missing`: empty when it looks whole, else **cut** (in view, the ink's colour spans under three quarters of what the strokes span drawn alone: a tile left empty or drawn in another colour) or **dark** (dark pixels the keep added, `dark_px` over `dark_before`, with ink that isn't dark), which asks for a **paper_ink_heal** with `why` **kept_cut** or **kept_dark** and `how`: **readd** (the mark taken out of the markup and put back 0.1 s later, ids kept) on the first try, **scroll** (the view a screen away and back) on the second, then looks again. His purple in all three `inks_` with `missing` set is PaperKit's drawing; black in `inks_held` would be the markup itself changed
  - **paper_ink_heal** (#906), when a look finds the ink missing from the screen while in view (`shown_px` 0) and the board redraws and looks again, twice at most: `why` (the look's), `attempt` (1 or 2), `step` (how far a centred view moves down and back, 8 then 32 points); the next `paper_ink_look` says whether it drew
  - **paper_redraw_nudge**, once the view comes to rest after ink lands (the small zoom that makes PaperKit redraw it, story 650), with board: `zoom`, `to`, `range_lo`, `range_hi`, `visible`, and `how`: **zoom** (the phone's small zoom and back), or **frame** when the page is centred (`visible` starts left of 0, narrower than the screen, as on an iPad), where a zoom recursed inside PaperKit until the app crashed (#829), so the view moves `step` points down and back instead (1 after ink lands, 8 or 32 for a heal) and `to` is not applied (#833)

## Larry's wait on a board (stories 773, 775–777, bead context-grabber-stl)

- `whiteboard` with `action`:
  - **larry_wait**, each change of what the board offers twenty seconds into Larry's turn: `wait` (none / waiting / stuck — mark none: *Larry hasn't got the picture* with Retry and Dismiss, its copy carrying `mark` too / working — mark received, seen or unknown: Interrupt), `was`, `mark` (none / unknown / received / seen / done, as in larry_turn_over; a picture whose sending the Cockpit answered is received, never none), `picture`, `sending` (the hand-off still on its way), `cockpit_answering`, `looking_s`
  - **larry_retry** (`picture`, `sending`, `receipt`), then a `whiteboard_turn` with from: retry under the same picture id, and an earlier hand-off that Retry, Dismiss or Interrupt replaced, if it then fails, carries `superseded: true` and frees nothing (one a newer picture replaced logs its failure as any other)
  - **larry_dismiss** (`picture`, `sending`)
  - **larry_interrupt** (`picture`, `mark`, `sending`: its hand-off was still on its way and is let go of, `looking_s`)
- `GRABBER_WHITEBOARD_LARRY_WAIT` taps Retry, Dismiss or Interrupt by itself on the simulator (docs/TESTING.md)

## Larry's board ops (stories 814–819, 840–877, 961, 964, 965, 969, 970–979, spec 2026-11-16-whiteboard-board-ops-design.md)

- `board_ops`, one per batch of Larry's changes, with board, label, source, key, ops, base_rev, rev and the count of each op kind:
  - action **ignored** with why and for_board
  - **refused** with reason (stale, a cap, an unknown op, not_applied, board_closed), canvas when the canvas itself refused it (unavailable: no canvas laid out yet, or failed:<why>, e.g. failed:paper_ops_failed when PaperKit refused the moves; #1040) and, for a batch from an older look that names what Igor moved, erased or dissolved since, conflict_ids (story 964)
  - **late** when the canvas answered for a batch no longer being applied (a repeated answer, or one after the board closed), which records nothing (#1040)
  - **held** while the Pencil is down, with pen_down and replaced
  - **applied** with held, rev, moved, strokes_moved, dy_min, dy_max, pages_before, pages, erased, drawn, metas, hidden, shown, selected, overlays, texts, inked (his texts with notes, lettered at once as kept text, #937), dismissed (ghosts of his text his change took away by name, #939), missing_ids, changed and ms, and rebased_from: the older rev a batch was made on when it applied to a newer one (story 961)
  - **undone** with label
  - **dissolved** with ids and erased (a group or kept text Igor erased part of).
- `board_events`:
  - **overlay_tap** with overlay
  - **sent** or **held** (with reason) when events go to the Cockpit at once, with why, events and ms.
- `board_outline`:
  - **margin_tap** with y, did and changed
  - **changed** with label, moved, hidden, shown, headers, folded, pages and ms
  - **hold_menu** with y and items
  - **hold_chose** with item
  - **erase_fold** (stories 902–905) with board, via (eraser, scratch, or eraser_cancelled: what a called-off stroke still took), folds, headers, strokes, path, took, can_undo and undo_name
  - **erase_fold_cancelled** (stories 906, 907, context-grabber-0m2d), an eraser stroke that crossed a fold and was called off before it lifted, with board, folds (crossed), taken (those whose header's ink was gone from the board anyway, so they went too; 0 means the fold stayed), path and markup (false: the board had no markup to read, so nothing went)
  - **header_tint** (stories 1040, 1041, 1065), a header newly made by an outline change or taken a level deeper by a #, with board, header, y (its row's middle), level (1, 2 or 3: its #s) and baseline (where its ▾ stands, -1 when there is none)
  - **ink_header** (stories 1030–1036, 1065), the stroke just drawn read as a header's, with board, header and by: underline or hash (a new header, with y and mark: the mark's strokes), grew (it joined a header's row, with joined: its strokes) or deeper (a # beside a # header's #s took it to ## or ###, with level, y and mark)
  - **ink_header_gone** and **ink_header_back** with board and header when a header's underline or # goes away (an Undo, the eraser) and comes back.
- `board_margin`, every try at a hold in the margin (stories 930–933):
  - **hold_began** with tool (finger or pencil), x, y and drawing_tool
  - **hold_ended** with tool, y, ms, travel (screen points), cancelled and verdict (a finger's: hold, moved, too_short, or not_seen when the hold recogniser never had it; a Pencil's: stroke)
  - **hold_stroke** for a Pencil stroke that began in the margin, with verdict (hold, moved, too_short), y, ms, points, and dy or moved_after_ms and moved_by
  - A Pencil's hold_ended with no hold_stroke after it means PaperKit drew nothing for it.
- `board_blocked`, the chip for a refused change of Larry's (stories 970–972, 976–978):
  - **shown** with board, label and reason
  - **laid** with board and frame ([x, y, w, h] in window points, once per place the chip takes in each showing)
  - **retry** or **dismissed** with board and label
  - **cleared** with board and why: applied (a later change of his applied)
- `whiteboard` action **paper_drop**, every lasso drag by hand (stories 969, 973–975, 979): board, strokes, at (where it landed), from (where it was lifted), room: false (nothing else moved), or room: true with cut, dy, moved, undid_drag (PaperKit's own drag step was taken back), pages, or failed: true.
- `board_room` (room by hand) with why and y:
  - **room** with cut, dy, moved and pages, or **nothing** / **nothing_below**
  - **keep_text** when a kept text of Larry's opened room below it (#938), **keep_late** when a kept mark of his did for ink Igor made after its picture and **keep_group** when a Keep group did (#894, stories 1004–1006, 1037), each with cut, dy, moved, pages_before and pages
  - **band_shown** when the room handle's band came up (#1000, stories 1044, 1038, 1039, 1042), with tool and y, and **band_hidden** when it went, with tool, why (lifted or cancelled), kind (opening, closing, nothing_to_close) and lines
- `board_word` (the Pencil held on a word): **picked_up** or **moved** with strokes, dx, dy, path_points and held_ms.
- `whiteboard` with:
  - action **paper_ops** (label, moved, erased, drawn, elements, pages_before, pages, can_undo, undo_name, ms)
  - **paper_ops_failed** (label, elements_before, elements)
  - **paper_paste_landed** (strokes, at, view, clear, cut, dy, moved, pages_before, pages, selected, ms)
  - **paper_paste_deleted** (strokes)
  - a keep carries text_id for Larry's text, and room_cut, room_dy and landed_dy when it made room (#938)
  - a keep of his marks and **keep_group** carry picture_t (when the picture his reply answers was taken, unix ms, or null when this device doesn't know it) with covered_newer (how many things made after it the marks sat on) and late_cut and late_dy when they made room (#894)
  - `whiteboard_marks` **shown** carries picture_known
- `whiteboard_turn` adds rev, events, op_result and folds

## Connectors (stories 910–916, spec 2026-11-16-whiteboard-board-ops-design.md, *Step 5*)

- `board_connectors`:
  - action **connected** when Igor taps Connect, with board, id, from, to, elbow (the route bends), erased (his arrow's strokes) and rerouted, ms
  - **followed** after a change of Igor's own moved a connector's end, with board, rerouted (redrawn) and loosened (an end gone, now plain ink), ms
  - **select_newest_hook** when `GRABBER_WHITEBOARD_SELECT_NEWEST` selected the newest stroke, with board and strokes
  - **connect_pressed** when Connect is tapped, with board, keys (the lassoed strokes it holds) and selected
  - **connect_refused** when there was nothing to connect, with board and keys
  - Larry's connector marks (stories 917–919):
    - **mark_names_nothing** when a reply's connector marks name nothing on the board (they show nothing and settle), with board and marks (their ids)
    - **mark_kept** when Igor keeps one, with board, mark, id, joins, from and to
    - **kept_nothing** when a kept mark's end names nothing now, with board, mark and missing
- A plan of Larry's, a paste, a room or a fold follows inside its own plan and logs under that plan's event

## To text and shape snap (stories 920–925, spec 2026-11-16-whiteboard-to-text-and-snap-design.md)

- `whiteboard` with `action`:
  - **to_text**, a tap on *To text*: `board`, `strokes`, `png_bytes`, `crop`
  - **to_text_done**, the answer: `board`, `ms`, and `outcome`: **text** (with `text_id`, `chars`, `lines`, `glyphs`), **no_writing**, **too_long**, **ink_gone** (the lassoed ink went while it was read), **no_letters** (the words made no strokes)
  - **to_text_failed**: `board`, `ms`, `reason`, `status` (the HTTP status, absent on a network error), with an `error` (where: whiteboard_to_text, `message`, `status`, `board`) beside it
    - an `error` with message *no picture* when the ink's picture couldn't be drawn
  - **paper_select_hook**, `GRABBER_WHITEBOARD_AFTER_INK=select`: `board`, `selected`
  - **shape_snap**, a held stroke swapped for its clean shape: `board`, `kind` (line, rectangle, ellipse), `err`, `points`, `clean_points`, `width`
  - **shape_snap_none**, a held stroke that is no shape and stays ink: `board`, `points`

## The board's ? and Feedback (stories 950–953)

- `whiteboard` with `action`:
  - **help**, a tap on ? (opens *How this board works*): `board`
  - **feedback**, a tap on Feedback (opens BugKit's *Report a problem* with the screenshot and the log): `board`

## Rewording a kept text, and the snap seen before the lift (stories 940–944, spec 2026-11-17-whiteboard-reword-and-live-snap-design.md)

- `whiteboard` with `action`:
  - **reword_open**, a finger tap on a kept text opened its field: `board`, `text_id`, `chars`, `glyphs`, `box`, `width` (the wrap width)
  - **reword**, done: `board`, `text_id`, `why` (return, tap_off, focus) and `outcome`: **reworded** (with `chars`, `rows`, `glyphs`), **deleted**, **unchanged**, **text_gone** (its glyphs went while the field was open), **no_letters**
  - Larry's `strokes_changed` for a reword carries `reworded: [text id]`
  - **shape_snap_preview**, the clean shape shown with the Pencil still down: `board`, `kind`, `err`, `points`
  - **shape_snap_preview_off**, the Pencil moved on and the raw stroke came back: `board`, `kind`
