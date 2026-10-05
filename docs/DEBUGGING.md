# Debugging and logging

The app explains itself through its logs and its copyable errors; a symptom that is not in a log gets a log line
before it gets a theory. This file says what the logs hold, how to get them off the phone, and how a bug goes from
Igor's phone to a closed issue. The test rungs are in [TESTING.md](TESTING.md); the spec is the
[user stories](stories/README.md).

## The logs

| Log | What it holds | How it reaches the Mac |
|---|---|---|
| **The call log** (`lib/callLog.ts`) | ~900 timestamped lines written by the call session, the audio layer and the Call screen: the socket, the mic as it is armed (other audio, route inputs, session shape), playback, heals and resets, captions, the ending; a separator between calls; the previous run recovered from disk under its own header, so a freeze loses nothing | The Call tab's **Diagnostics** fold: *Copy diagnostics* puts the whole log on the clipboard under a header (build, state, route); *Upload* makes a **private gist** and puts its URL on the clipboard and under the buttons. After a troubled call the upload is automatic when the switch in Settings → Diagnostics uploads is on. The app keeps the last 10 gists and retires older ones; every gist opens with a note to delete it once processed. The token (classic, `gist` scope) lives in the Keychain. Spec: `superpowers/specs/2026-09-05-diagnostics-gist-upload-design.md` |
| **The timer log** (`lib/gym/timerLog.ts`) | 300 lines: the audio session's options and activation, the keepalive loop, each duck window, every cue (loaded, requested, failed), phase transitions with the round | The **Log** button in the Gym Timer's header copies it with a build / mode / preset header |
| **Copyable errors** (`components/CopyableError.tsx`) | every user-visible error, with *Copy error*: `where:` the screen and operation, `error:`, `build:` sha and branch, then any `extra` fields the caller passed (the state at the time) | the clipboard |
| **About** | the running build: git sha, branch and commit message baked at build time; the OTA update id, channel and time; *Check for updates* | the eye; the commit message is the same one `git log` shows |

Native `NSLog` never reaches Igor's phone screen; a native module that has something to say pushes it through the
JavaScript log (the audio-route module's route-change events do).

```bash
gh gist view <id> --raw | less          # an uploaded call log (Igor's account)
gh gist list --limit 10                  # the uploads still standing
grep -n -E 'heal|reset|redial|FAILED|lost' call.log
```

Header lines say which build the evidence came from; match them against `git log` before reading anything else — a
log from a build before the fix proves nothing about the fix.

## The native app: one session log, a shake, and issues

Grabber Native (`native/`, built beside this app; [design spec](superpowers/specs/2026-10-04-swift-native-app-design.md),
stories [140–145](stories/08-reporting-problems.md)) replaces the logs above with Exercise Analyzer's scheme. As a
journey is ported its log moves into the session log and its row above goes.

- **One file per launch**: `Documents/logs/grabber-<yyyyMMdd-HHmmss>.jsonl` in the app container, visible in the
  Files app. JSON Lines, one event per line: `{"type": "<event>", "t": <ms since launch>, ...fields}`. Numbers stay
  numbers. Writer: `native/App/SessionLog.swift`; what a line can carry: `SessionLogLine` in `ContextCore`.
- **Logs older than 30 days** are deleted at launch, except a file a report in `bugs.jsonl` names.
- **Crashes**: MetricKit payloads land in `Documents/crashes/<stamp>.json`; the app's own `signal-<epoch>.txt` and
  `exception-<epoch>.txt` cover the days MetricKit takes on a development build. Each is announced once as
  `crash_report`. A log that simply stops, with no crash file, is a kill from outside (memory).

```bash
just pull-logs                  # phone → ~/tmp/agent/grabber-logs/ (logs/, bugs.jsonl, bugs/<stamp>/, crashes/); the phone's id: DEVICE=<udid> or scripts/native/phone-udid.local
just pull-logs-sim              # simulator → ~/tmp/agent/grabber-logs/sim/
just log-summary <file.jsonl>
jq -c 'select(.t > 57000 and .t < 60000)' <file>     # around a moment (a report's session_t_ms)
just symbolicate ~/tmp/agent/grabber-logs/crashes/<stamp>.json
```

| Area | Events (key fields) |
|---|---|
| Launch | `session_start` (device, system, app, sha, branch, started), `logs_pruned` (count, bytes, kept_for_reports; logged even when zero) |
| Reports | `ui` (action: report_problem, from: shake / button, screen), `bug_report` (note, screen, build, log, screenshot) |
| Gym Timer | `ui` (action: open_timer with from: home / hook and autostart; close_timer), `keep_awake` (on, reason: gym_timer), `timer_start` (preset, work, rest, rounds, prep, resumed), `timer_pause` (phase, round, time_left), `timer_reset` (RESET, or a preset chosen after the finish), `timer_phase` (from, to, round: logged at the boundary's true second; work to work is a new round with no rest), `timer_cue` (cue: three / two / one / go / rest / done; ok: false with a message when no player could be made), `timer_finished` (rounds), `timer_catchup` (phase, round, time_left: the app came back to the front mid-run and the state moved without replaying cues), `timer_turn` (turn: upright / left / right), `stopwatch` (running, elapsed_ms), `accessory_saved` (count, items) |
| Gym Timer audio | `timer_session` (action: options with the option names, active with other_audio: whether music was playing, inactive: let go with notify-others; ok, and message when it failed), `timer_keepalive` (action: start / stop, ok), `timer_duck` (action: open / held / close / released, hold_ms: the window that turns music down around the cues; `released` is the request, the `timer_session` inactive → active pair after it is the session doing it), `timer_interruption` (kind: began / ended, wanted: whether the timer still needed the session; a phone call) |
| Links out | `ui` (action: open_context_grabber, what: card, ok: false when Context Grabber is not installed) |
| Box breathing | `ui` (action: open_breathe with from: home / hook and autostart; close_breathe; breath_cue_choice with cue), `breathe_style` (style: line / glow / beads / tide, when Igor picks one), `keep_awake` (on, reason: breathe), `breath_start` (breath, cycles, total: seconds; cue; lead_in_ms: the quiet before the first inhale), `breath_phase` (phase: inhale / holdFull / exhale / holdEmpty; cycle; late_ms: how long after its true time the step was noticed), `breath_cue` (kind: voice / tone; name: the file or tone; ok; fallback: true when the phone's own voice spoke because the file was missing), `breath_pause` (reason: circle / hook; phase, cycle, time_left; leaving the app no longer pauses), `breath_resume` (time_left), `breath_finished` (cycles, total, late_ms), `breath_exit` (elapsed_ms, paused: the back chevron), `breath_session` (action: active with other_audio, inactive; ok, message), `breath_keepalive` (action: start / stop, ok, message: the near-silent loop that keeps a session running with the phone locked, on from Begin or resume until pause, the finish or Back) |
| Live Activity | `live_activity` (action: start (with id) / update / end / dismiss / unavailable; kind: gymTimer / breathe; title, subtitle, seconds: what the card says and the still time left in the step; reason on end and dismiss: finished (shown a few more minutes) / reset (RESET, a preset after the finish) / back / leave (the screen closed) / replaced (the other screen started one) / restart (a new start took down a finished card) / leftover (a card from a killed launch, ended at launch); ok: false on update when the card was swiped away or ended by iOS, with message; unavailable: Live Activities are off for the app, said once). One start, one update per step, pause and resume, one end: never one a second |
| Places | `ui` (action: open_places with from: home / hook / file; close_places; tracking_switch with on, from; retention with days; name_place with place, offer: expand / name; copy_daily_summary; copy_coordinates; find_me; map_expand / map_collapse; open_url), `places_open` (reason: open / foreground / import / retention / expand / add_place…; points, known, stays, days, today_points, read_ms, ms), `location_permission` (action: request with level when_in_use / always; changed with from, to), `tracking` (on; reason: switch / hook / launch / permission / refused / permission_lost; permission; was_on), `location_point` (count since the last line, launch_total, since_ms, background: the first batch after recording starts, then one line per quarter hour, never one per point), `location_fix` (action: request with reason / fix with accuracy, age_s, ms / failed with message), `location_error` (code, message; once per spell), `prune` (reason: launch / foreground / lowered / import; retention_days, removed, ms; logged even when zero), `import` (from: file / picker / hook; ok; file; points_added, points_already, places_added, places_already, shift_days, ms; message when refused), `export` (from; ok; bytes, points, ms, path; message), `known_place` (action: add / delete / expand / import_json; name, radius, radius_from / radius_to / shift_m) |
| Failures | `error` (where: log (a field JSON could not carry, with its type under `event`) / bug_images / bug_report (bugs.jsonl could not be written; the report is still in this log) / logs_prune / database (the SQLite file did not open: nothing is remembered this launch) / settings (key) / timer_audio (a cue file missing from the bundle or unreadable) / accessory_save (items) / accessory_history / location_store (count: points that could not be written) / tracking_setting / retention_setting / places_read / prune / add_place / delete_place / expand, message), `crash_report` (kind: crash / hang / signal / exception, file; `top`: the file's first lines for the app's own files) |
| Box breathing | `ui` (action: open_breathe with from: home / hook and autostart; close_breathe; breath_cue_choice with cue), `keep_awake` (on, reason: breathe), `breath_start` (breath, cycles, total: seconds; cue; lead_in_ms: the quiet before the first inhale), `breath_phase` (phase: inhale / holdFull / exhale / holdEmpty; cycle; late_ms: how long after its true time the step was noticed), `breath_cue` (kind: voice / tone; name: the file or tone; ok; fallback: true when the phone's own voice spoke because the file was missing), `breath_pause` (reason: circle / hook; phase, cycle, time_left; leaving the app no longer pauses), `breath_resume` (time_left), `breath_finished` (cycles, total, late_ms), `breath_exit` (elapsed_ms, paused: the back chevron), `breath_session` (action: active with other_audio, inactive; ok, message), `breath_keepalive` (action: start / stop, ok, message: the near-silent loop that keeps a session running with the phone locked, on from Begin or resume until pause, the finish or Back), `breath_interruption` (kind: began / ended, wanted: whether a session still needed the keepalive, which starts again after it; a phone call or Siri) |
| Live Activity | `live_activity` (action: sweep (at launch, with count: cards left up) / start (with id) / update / end / dismiss / unavailable; ms on sweep, start and unavailable: how long ActivityKit took, off the main actor; kind: gymTimer / breathe; title, subtitle, seconds: what the card says and the still time left in the step; reason on end and dismiss: finished (shown a few more minutes) / reset (RESET, a preset after the finish) / back / leave (the screen closed) / replaced (the other screen started one) / restart (a new start took down a finished card) / leftover (a card from a killed launch, ended at launch); ok: false on update when the card was swiped away or ended by iOS, with message; unavailable: Live Activities are off for the app, said once per session). A refused start is an `error` with where: live_activity (and kind, title, message, ms), said once per session: that screen asks again only at its next session. One start, one update per step, pause and resume, one end: never one a second |
| Think of a card | `ui` (action: open_think_a_card, from: home, ok: false when Think a Card is not installed) |
| Cockpit | `ui` (action: open_cockpit with from: home / hook and first: whether this launch had opened it; close_cockpit; cockpit_retry; cockpit_pull_refresh), `cockpit_load` (url as loaded, with the client tag; ok; ms from the navigation's start; error: the reason, with its domain and code, or `HTTP <status> — <text>`; a web-content crash is ok: false with action: reload), `cockpit_bridge` (dir: in / out; kind: the message type, `unrecognized` for page traffic that is not the bridge's; request_id; inputs: how many microphones an answer carried; reason on audio.routeChanged; message on audio.error; live on call.state; via and handled: false on call.start — the hand-off goes to Context Grabber until the call moves), `audio_route` (action: activate / the request it answered / changed / reassert_input / reassert_output; inputs as `name [type]`, outputs by id, input and output actually live, chosen_input / chosen_output: what the page asked for, `unset` before it asked; category; reason on changed; ok, failures and message when the session refused), `keep_awake` (on, reason: cockpit_call, why: page / load / load_failed / process_terminated), `cockpit_link` (url, kind: app / external / new_window — handed to iOS), `cockpit_media` (origin, type, granted: the microphone without a prompt for the Cockpit's own origin) |
| Failures | `error` (where: log (a field JSON could not carry, with its type under `event`) / bug_images / bug_report (bugs.jsonl could not be written; the report is still in this log) / logs_prune / database (the SQLite file did not open: nothing is remembered this launch) / settings (key) / timer_audio (a cue file missing from the bundle or unreadable) / accessory_save (items) / accessory_history, message), `crash_report` (kind: crash / hang / signal / exception, file; `top`: the file's first lines for the app's own files) |
| Gym Timer | `ui` (action: open_timer with from: home / hook and autostart; close_timer), `keep_awake` (on, reason: gym_timer), `timer_start` (preset, work, rest, rounds, prep, resumed), `timer_pause` (phase, round, time_left), `timer_reset` (RESET, or a preset chosen after the finish), `timer_phase` (from, to, round: logged at the boundary's true second; work to work is a new round with no rest), `timer_cue` (cue: three / two / one / go / rest / done; voice: adam / igor / aussie, the count voice that said it; ok: false with a message when no player could be made), `ui` (action: timer_settings with from: button / hook and the voice then chosen; action: count_voice with voice and from: settings / hook — a hook's voice is not remembered), `timer_voice_sample` (voice, ok: the chosen voice's *go* played as a sample from the sheet), `timer_finished` (rounds), `timer_catchup` (phase, round, time_left: the app came back to the front mid-run and the state moved without replaying cues), `timer_turn` (turn: upright / left / right), `stopwatch` (running, elapsed_ms), `accessory_saved` (count, items) |
| Gym Timer audio | `timer_session` (action: options with the option names, active with other_audio: whether music was playing, inactive: let go with notify-others; ok, and message when it failed), `timer_keepalive` (action: start / stop, ok), `timer_duck` (action: open / held / close / released, hold_ms: the window that turns music down around the cues; `released` is the request, the `timer_session` inactive → active pair after it is the session doing it), `timer_interruption` (kind: began / ended, wanted: whether the timer still needed the session; a phone call); `timer_session` with for: sample (the sheet's sample borrowing the session while no workout holds it; logged only when that failed) |
| Failures | `error` (where: log (a field JSON could not carry, with its type under `event`) / bug_images / bug_report (bugs.jsonl could not be written; the report is still in this log) / logs_prune / database (the SQLite file did not open: nothing is remembered this launch) / settings (key) / timer_audio (a cue file missing from the bundle or unreadable; names the file, e.g. aussie-go.wav) / accessory_save (items) / accessory_history, message), `crash_report` (kind: crash / hang / signal / exception, file; `top`: the file's first lines for the app's own files) |
| Call | `ui` (action: open_call / close_call with from: home / hook / shortcut and state; call with backend, voice; hang_up; restart_call; copy_diagnostics; gist_token with saved), `call_start` (backend, voice, voice_id, model, build, bridge), `call_prepare` (ok, message), `call_socket` (action: open / connect / lost, message: why the far end or the network went), `call_sent` (frame: start / stt_start / mic_probe with token / mic with muted / location / diagnostics with why and bytes / stt_stop / stop), `call_ready` (out_rate, backend, session), `call_ack` (token, stale), `call_mic` (action: open with ok / first_frame with samples and rate / muted / unmuted / zeros / audio_back), `call_rx` (action: first_audio, bytes), `call_stats` (every 5 s while live: rx_kb, rx_frames, mic_frames, played_s, scheduled_s, pending_s, clock_running, playback), `call_caption` (who: igor / larry, text: a settled row), `call_bridge` (kind: interrupted / tool_call / tool_result / injected / warning / error / vendor_closed / closed, with the bridge's words), `call_problem` (problem: what the screen says, "" when it clears), `call_heal` (action: reset_audio / redial / give_up / rearm_mic / mic_not_reaching / rearm_tap with attempt of 3 / give_up_tap / reopen_playback, why), `call_hangup`, `call_restart`, `call_ignored` (action, state), `call_ended` (reason, text: what the screen says, badly, mic_frames, rx_frames, rx_kb, played_s, scheduled_s), `call_gist` (action: upload with why and bytes / uploaded with url / delete with deleted, gone, failed; ok, message — never the token). A troubled call — any `call_heal`, a non-empty `call_problem`, `call_ended` badly, or a `call_*` with ok: false — uploads on its own when a token is saved and the switch is on |
| Call audio | `call_audio` (action: session with category, mode, other_audio, input_available, rate, io_buffer_ms, route / voice_processing with ok, enabled: echo cancellation / permission ok: false / engine_start with why / playback_open with out_rate / mic_arm with rate, channels, other_audio, route / mic_first_buffer with after_ms / clock_running with after_ms: the greeting waits on it / route_change with reason and route / configuration_change (running, rebuilt) / rebuild with why / interruption with kind began / ended / resumed / restart / inactive; ok, message; synthetic: true under `GRABBER_CALL_AUDIO=synthetic`) |
| Failures | `error` (where: log (a field JSON could not carry, with its type under `event`) / bug_images / bug_report (bugs.jsonl could not be written; the report is still in this log) / logs_prune / database (the SQLite file did not open: nothing is remembered this launch) / settings (key) / timer_audio (a cue file missing from the bundle or unreadable) / accessory_save (items) / accessory_history, message; the call's failures are `call_*` events with ok: false), `crash_report` (kind: crash / hang / signal / exception, file; `top`: the file's first lines for the app's own files) |
| Mirror (Today) | `ui` (action: open_today with from: home / hook; open_metric with metric, from; sleep_source; sleep_night with night, open; share with kind; sleep_target with hours), `mirror_grab` (reason: open / foreground / timer / pull / hook, source: healthkit / fixture), `health_auth` (ok, message), `health_query_failed` (query: steps / heart_rate / sleep / weight_range / hrv_day / … , message: what Health said; that metric reads "—"), `mirror_grabbed` (ms, steps, sleep_hours, heart_rate, workouts, series: how many of the ten weekly series came back, days_with_steps, failed_queries), `export` (kind: summary / raw, bytes, grabbed: the snapshot's time; the text is in `Documents/exports/<kind>.json`), `mirror_fixture_step` (step: authorize / delete_earlier / save with objects / read_back — the last one logged names a hang), `mirror_fixture_saved` (samples, source, dropped: kinds Health will not let an app write), `mirror_fixture_done` (mode: fixture / healthkit, now, time_zone) |
| Failures | `error` (where: log (a field JSON could not carry, with its type under `event`) / bug_images / bug_report (bugs.jsonl could not be written; the report is still in this log) / logs_prune / database (the SQLite file did not open: nothing is remembered this launch) / settings (key) / timer_audio (a cue file missing from the bundle or unreadable) / accessory_save (items) / accessory_history / export_file (kind) / mirror_fixture / mirror_fixture_save / mirror_fixture_file, message), `crash_report` (kind: crash / hang / signal / exception, file; `top`: the file's first lines for the app's own files) |

Adding one: `log.event("snake_case_type", ["field": value])`, and a row here in the same change. The rules under
*Adding a line* hold: numbers in fields, a failure once per spell, boundaries rather than ticks.

**From a shake to an issue.** A shake (or *Report a problem* on Diagnostics) captures the window, and *Log it*
writes a `bug_report` event, a line in `Documents/bugs.jsonl` (note, screen, build, `log`, `session_t_ms`,
`screenshot`) and the picture under `Documents/bugs/<stamp>/`. While Igor is on the phone, arm

```
Monitor(command: "scripts/native/bugs-monitor.sh", description: "new shake reports on the phone", persistent: true)
```

which polls `bugs.jsonl` every minute and prints one line per report that is not yet an issue (`just bugs-check`
is the same look, once; "phone not reachable" is not a failure). On a line: `just pull-logs && just file-bugs` —
one issue per report, carrying the note, the screen, the build and the log's name. The repo is public, so the
screenshot is never uploaded: the issue names its path under `~/tmp/agent/grabber-logs/` on the Mac. The marker `<!-- bug:<reported_at> -->` makes filing
idempotent. Then steps 3–5 of *Bug reports* below, reading the log at the report's `session_t_ms`.

## Adding a line

`log.add("...")` inside the call (the session, the audio layer and the screen share one `CallLog`);
`timerLog.add("...")` in the timer. Put the deciding numbers in the line, not in prose (`mic armed: inputs=2
route=BuiltInMic other_audio=1`); log a failure once per spell, not once per retry; log the boundary (armed, healed,
ended), not every tick. A screen-level failure is a `CopyableError` with the relevant state in `extra` rather than a
log line — Igor copies it without opening a fold.

## Instrument before theorizing

For any phone-only symptom: add the line that would settle it, ship it (`just ota` for JavaScript, `just deploy` for
native), reproduce, copy or upload, read the numbers, then fix. Never ship a second guessed fix. Examples that paid
off: the mic-arm log of other audio, route inputs and session shape that turned the silent first call from a guess
into #95's evidence (#102); the log mirrored to disk so a freeze while switching microphones lost nothing (#106);
the timer log showing every cue requested and none heard while music was mixed in, which is why the cues are sound
files and not synthesis (2026-09-07).

## Bug reports: from the phone to a closed issue

1. **On the phone**: Igor hits it. He copies the error, copies or uploads the log, or says it in the session. The
   copied payload carries the build line, so nothing needs retyping.
2. **File it**: one GitHub issue per report (`gh issue create`), with the note, the payload or the gist link, the
   build line, and what he was doing. A report that arrives by voice gets an issue too, filed by hand with the same
   evidence, so the trail is complete. Track the work in `bd` when it spans sessions; the issue is where the
   evidence lives and what the commit closes.
3. **Before fixing**: find or write the story in [stories/](stories/README.md) that the report belongs to — a bug gets
   an `Issues:` line, a request becomes a story, no story means the spec has a hole — and, when the behaviour will
   change, re-open the feature's design spec first (spec-first, [AGENTS.md](../AGENTS.md)). Then read the log at
   the moment of the report and put that evidence on the issue as a comment.
4. **Fix on the cheapest rung** that can see it ([TESTING.md](TESTING.md)): a host test that fails first when the
   logic is in `lib/`; a line in the log when it is the phone's. One PR per issue, referencing it.
5. **Ship and close**: `just ota` for JavaScript, `just deploy` for native. Close the issue once the build is on the
   phone (`Fixes #N` in the PR when the verifying rung already ran, otherwise by hand after the OTA landed) with a
   comment saying what was verified where and what Igor should feel; Igor reopens if it is not fixed. Never leave a
   fixed bug open.

## Device tooling

- `just deploy` builds with the committed `DEVELOPMENT_TEAM` and installs over `devicectl`; the CoreDevice UUID is in
  the justfile. A locked phone fails the launch step only; the install is done. If Xcode lost the Apple ID after an
  update, re-add it in Xcode → Settings → Accounts.
- `just ota` leaves the app on the old bundle until the second open; About says which commit is running.
- `.native-build-sha` (gitignored) is the last native build from this Mac; `just ota` diffs the native surface
  against it. No marker means no native build from this machine yet, and the OTA trusts you.
- The gist token is in the Keychain (`expo-secure-store`); a binary built before that module has no upload button.
