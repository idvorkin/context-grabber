# An error on screen files a report by itself

Status: decided by Igor on 2026-11-14 (idvorkin/bug-kit#119), for #876. Stories 155–157.

## The idea in one line

Every error Grabber Native shows, in the app or in the share sheet, reaches the Mac as an automatic report without
anyone copying it, once per kind of error every 10 minutes.

## Why

Igor, from the iPad (#876): "Failures anywhere should auto log bugs. E.g., if you didn't get this bug from the [share]
sheet that should've auto logged." He had copied the share sheet's dictation error and filed it by hand. Most errors
he sees, he does not have time to report, so they are never fixed.

## What happens

- **An error appears.** Any error on screen with its Copy error button (every user-visible error in the app is one)
  saves an automatic report when it first shows: no dialog, no screenshot, and nothing on screen changes. The report
  says what Copy error would have copied (the message, where it happened, the build and the state), which screen it
  was on, the session log, and what was on screen (its accessibility tree). The Mac's listener files it as an
  *Automatic report: <where it happened>* issue, labelled `auto`, like the call's automatic reports.
- **The same error again.** Each kind of error (where it happened, the context Copy error shows, such as sending a
  chat message) files at most once every 10 minutes, even across a relaunch. A repeat is noted in the session log and files nothing.
- **Errors that are expected file nothing.** They still show, with Copy error, exactly as before:
  - every error shown while the phone has no network: offline, a failed send or load is expected, not a bug;
  - *Health is not available on this device*: the device has no Health, which no fix can change;
  - a chat read that failed because the device's own connection was down (*The Internet connection appears to be
    offline*), even when the app had not yet noticed it was offline (#1268: the iPad waking);
  - a board link that can't open because this build has no iCloud (the Mac's own build): the board lives on the device
    that drew it, which no fix in the app can change (#1254).
- **The Cockpit away for a moment files nothing; away for minutes files once.** A read of the chat list or a thread
  that fails because the Cockpit can't be reached (it answered a server error, any 5xx, most often 502, 503 or 504 from
  the proxy in front of it; or the request timed out, could not connect, or lost its connection midway) shows the
  chat spec's *Cockpit not answering* banner with Copy error, and the app keeps reading again. It files no automatic report unless such failures go on, with no read getting through, for 2 minutes;
  then it files one report for that outage, saying how long it has lasted and how many reads failed, and no more until
  a read gets through. Any read that gets through ends the outage. A pause of over a minute with no read (the thread
  closed, the app in the background) starts the count again. Why: on 2026-11-22 the Cockpit answered 502 to one poll
  in a hundred for hours, each blip healed on the next poll 4 seconds later, and each filed a report (#1245–#1253,
  #1259). Any other failed read (the Cockpit answered 404, or an answer the app can't read) files at once, as before.
  A board's turn that can't reach Larry the same way (a 5xx, a timeout, no connection) is the same blink: the board
  says *Larry couldn't be reached* with Copy error as before and files nothing, unless turns keep failing that way for
  2 minutes, with no turn reaching him and no pause of over a minute between them; then it files one report for the
  outage. Why: on 2026-11-25 one turn got a 502 and the next, 12 seconds later, reached him, and the one blip filed
  #1450. A turn the Cockpit refuses (a 4xx) still files at once.
- **The share sheet.** An error on the share card files too (the first was its mic's, #1135, before the mic was taken
  off the card). The share sheet is its own small
  program with no network of its own, so it keeps the report in the space it shares with the app; the next time the
  app opens or comes to the front, the app takes the report and sends it to the Mac through iCloud like its own. The
  share sheet keeps its own session log there too, so the report carries what the share card did.

## Not in this change

- The share card's two older error lines (what was shared could not be read; the Inbox could not be written) keep
  their own Copy button; they become Copy error problems, and so file themselves, in a change of their own.
- A switch to turn self-filing off. Igor asked for every error.

## Acceptance

- An error on screen in the app saves one automatic report for its kind of error; the session log has
  `bug_report_auto` with that kind as its reason.
- The same kind again within 10 minutes saves nothing; the log has `bug_report_auto_skipped`.
- An error shown while offline, or *Health is not available*, saves nothing; the log has `bug_report_auto_skipped`
  with `auto_file: false`.
- A chat read that fails once with HTTP 502 (or any 5xx, a timeout, a refused or dropped connection) and then reads fine saves
  nothing; a thread that had loaded shows no banner for that one blip (the chat spec's *Cockpit not answering*), and the
  log has `chat` `cockpit_outage` `ended` with `filed: false`.
- Chat reads that keep failing that way for 2 minutes save one automatic report for the outage, and none more until a
  read gets through; the log has `chat` `cockpit_outage` with `filed` and the outage's length and failures, and
  `ended` when a read gets through.
- A chat read that fails because the device's own connection is down saves nothing, however long it lasts.
- A board turn that fails once to reach Larry with HTTP 502 (or any 5xx, a timeout, a refused or dropped connection)
  and whose next turn reaches him saves nothing; the board still showed *Larry couldn't be reached* with Copy error,
  and the log has `whiteboard` `cockpit_outage` `ended` with `filed: false`.
- An error on the share card is saved in the shared space; the app's next launch or foreground takes it into its own
  reports (`bug_report_adopted` in the app's log), and it is queued for iCloud like any report.
