# Native Call Screen — Implementation Plan

Spec: [`../specs/2026-08-28-native-call-screen-design.md`](../specs/2026-08-28-native-call-screen-design.md) · GH #74 · bead `context-grabber-e19`

Protocol source of truth: `handle_browser`'s docstring in
`~/gits/cockpit/voice_bridge.py` (≈ line 14394). Page reference
implementation: `talkStart` / `talkStartMic` / `talkPlay` / `talkTeardown`
in `~/gits/cockpit/index.html` (≈ 8425–9420). Cockpit `main` as of
`6001e02`.

## Ships OTA — no native build

Everything needed is already in the binary:

| Need | Already there |
| --- | --- |
| PCM mic capture, session config, interruption/route events, gapless playback | `react-native-audio-api` 0.11.7 (`RNAudioAPI` in `ios/Podfile.lock` and `ios/Pods/Manifest.lock`) |
| Device roster + steering | `modules/audio-route` (`activate`, `getDevices`, `setInput`, `setOutput`, route-change events) |
| Keep running when locked | `UIBackgroundModes` has `audio` (`ios/ContextGrabber/Info.plist`) |
| Mic permission string | `NSMicrophoneUsageDescription` (expo-audio plugin) |
| Deep link parsing | `parseCallRoute` path in `App.tsx` (≈ 681) |
| Binary WebSocket | RN's built-in `WebSocket` (`binaryType = "arraybuffer"`) |

Rollout: `just ota "feat(call): native Call tab that survives the lock (#74)"`.
If any Swift turns out to be needed (see *Audio session ownership*), it
becomes `just deploy` and the plan must say so.

## Files

```
lib/callProtocol.ts          pure: message parsing, ending text, ready → outRate, backend ids
lib/pcm.ts                   pure: Float32 → Int16LE (with linear resample to 16 k), Int16LE → Float32
lib/callSession.ts           the state machine: WebSocket + recorder + playback + captions (no React)
screens/CallScreen.tsx       the tab UI; owns one CallSession via a hook
components/TabBar.tsx        add "call" to TabId + tab def
App.tsx                      mount CallScreen; route grabber://call to it; lift cockpitCallLive
__tests__/callProtocol.test.ts
__tests__/pcm.test.ts
__tests__/callSession.test.ts   fake WebSocket + fake recorder/player, drives the machine
```

`lib/audioBridge.ts` keeps `CallIntent` / `parseCallState`; the native
screen reuses both types.

## Wire protocol (what `callSession.ts` speaks)

URL: `wss://c-5004.squeaker-teeth.ts.net/bridge` — derive from the same
Cockpit host setting the web view uses (`https://<host>` → `wss://<host>/bridge`).
No auth. Server pings every 20 s; RN's socket answers pongs natively.

Outbound (client → bridge):

| When | Frame |
| --- | --- |
| `onopen` | `{"type":"start","backend":"gemini"\|"eleven"\|"openai"\|"drill","model":"","voice":""}` |
| on `ready` | `{"type":"stt_start","rate":16000}` then start the recorder |
| every mic buffer | binary: PCM16 LE mono 16 kHz, dropped entirely while muted |
| after the first binary frame | `{"type":"mic_probe","token":<n>}`; expect `mic_ack` within 5 s, else one re-arm of the recorder, else surface "mic is not reaching Larry" |
| mute toggle | `{"type":"mic","muted":bool}` (notice only — the drop is client-side) |
| hang up | `{"type":"stt_stop"}` then `{"type":"stop"}` then close |

Inbound (bridge → client), the subset the screen renders — everything
else is ignored, not errored:

| Frame | Effect |
| --- | --- |
| binary | PCM16 LE mono at `outRate` → enqueue for playback |
| `ready` `{out_rate, backend, session, …}` | state → `live`; `outRate = out_rate`; start timer; send `stt_start`; start recorder |
| `mic_ack` | clear the probe watchdog |
| `transcript` `{who:"igor"\|"larry", text}` | append/replace caption row (labels `Igor` / `Larry`) |
| `stt_partial` / `stt_final` `{text, speech_final?}` | live Igor caption (partial replaces, final commits) |
| `interrupted` | flush playback queue (stop every scheduled source) |
| `turn_end` | start a new caption row on the next text |
| `consult_request` / `consult_progress` / `tool_call` / `tool_result` | one clamped "consult" row, updated in place (label `⟳` with accessibilityLabel) |
| `warning` `{text}` | inline row (e.g. Gemini goAway) |
| `error` `{text}` | `CopyableError` context `CallScreen.bridge` |
| `closed` `{reason}` | state → `ended(reason)`; teardown |
| socket `close`/`error` without `closed` | `ended("connection lost")` |

Ending text map (mirror of the page's `TALK_ENDINGS`): `"idle timeout"`
→ *idle 2 min*, `"hangup intent"` → *hang-up intent*, `"stopped"`,
`"vendor ended the call"`, `"vendor max duration"`, `"Larry hung up"`,
plus the client-only *connection lost*. Unknown reasons render verbatim.

## Audio pipeline

**Capture** — `AudioRecorder` from `react-native-audio-api`:

```ts
recorder.onAudioReady({ sampleRate: 16000, bufferLength: 1600, channelCount: 1 }, ({ buffer }) => …)
```

The delivered rate "may differ depending on hardware", so `pcm.ts`
resamples from `buffer.sampleRate` to 16 k when they differ (linear, same
as the page's `downsampleTo16k`), then converts to Int16 and sends
`ws.send(int16.buffer)`. Muted → return early before conversion.

**Playback** — one `AudioContext({ sampleRate: outRate })` created when
`ready` arrives (the rate is not known before). Each inbound frame →
`ctx.createBuffer(1, n, outRate)` filled from Int16 → `AudioBufferSourceNode`
scheduled at a running `playhead` (`max(ctx.currentTime + 0.08, playhead)`),
`playhead += duration`. Keep the live sources in a set; `interrupted` calls
`stop()` on each and resets `playhead`. This is the page's `talkPlay` /
`talkFlushPlayback`, verbatim in shape.

**Audio session ownership** — two things touch `AVAudioSession`:

1. `modules/audio-route` `activate()` → `.playAndRecord`, mode `.default`,
   `[.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker]`,
   `setActive(true)`. Needed for the roster and for `setOutput`.
2. `AudioManager.setAudioSessionOptions({ iosCategory: "playAndRecord",
   iosMode: "voiceChat", iosOptions: ["allowBluetoothHFP", "defaultToSpeaker"] })`
   from `react-native-audio-api`.

Order on call start: `audioRoute.activate()` first (roster + route
observers), then `setAudioSessionOptions(...)` — same category, last
writer sets the mode to `.voiceChat`, which is what enables iOS's
voice-processing (AEC/AGC). Then create the recorder. `activate()` is
only re-run on an explicit JS call, so the mode sticks. **Phase 2 option:**
add a `mode` argument to `activate()` so one module owns the session;
that is a Swift change and a native build — not needed for phase 1.

`AudioManager.observeAudioInterruptions(true)`; on `interruption`
`{type:"began"}` pause the recorder and leave the socket open; on
`{type:"ended", shouldResume}` resume the recorder and re-assert the
session options (the web view lesson: a route set before an interruption
silently reverts). `routeChange` → refresh pickers from
`audioRoute.getDevices()`; nothing else — audio keeps flowing on the new
route.

**Background survival** relies on: `audio` background mode + an active
`.playAndRecord` session + the recorder running. The recorder is what
keeps the app alive when Larry is silent; never stop it on mute (mute
drops frames in JS).

**Keep-awake**: while `CallScreen` is focused and the session is
`connecting|live`, `activateKeepAwakeAsync("call")`; deactivate on blur
or end. Same pattern as `CockpitScreen`'s tag.

## State machine (`callSession.ts`)

```
idle ─start(backend)→ connecting ─ready→ live ─(stop|closed|socket close)→ ended(reason) ─start→ connecting
                         └─(socket error/close)→ ended("connection lost")
```

Exposed to the screen: `state`, `backend`, `startedAt`, `captions[]`,
`muted`, `lastError`, `warning`; methods `start`, `stop`, `setMuted`.
Plain event emitter, no React, so `callSession.test.ts` can drive it with
a fake `WebSocket` (records sent frames, injects inbound ones) and a
fake recorder/player (function stubs). Inject the WebSocket constructor,
recorder factory, and player factory.

## `App.tsx` changes

- `TabId` gains `"call"`; `TabBar` gets *Call* beside *Cockpit*.
- `parseCallRoute` result → `setActiveTab("call")` + `callSession.start(via ?? remembered)`;
  if `state === "live"|"connecting"` just switch tabs. Remove the hand-off
  of `callIntent` to `CockpitScreen` (the page no longer receives
  `call.start`; `callIntentEmitScript` stays in `audioBridge.ts` unused →
  delete in the same PR to keep YAGNI).
- Lift the page's `call.state` to `App` state (`cockpitCallLive`) — today
  it lives inside `CockpitScreen` for keep-awake. `CallScreen` refuses
  `start` when it is `true`.
- Remembered backend: `settings` table key `call_backend`.

## Tests

- `pcm.test.ts` — Float32→Int16 clipping, 48 k→16 k resample length and
  a sine round-trip, Int16→Float32.
- `callProtocol.test.ts` — each inbound frame shape from the docstring
  parses (and junk → `null`), ending map, `ready` → outRate.
- `callSession.test.ts` — full happy path (start → `start` frame sent on
  open → `ready` → `stt_start` sent → recorder started → mic frame sent
  → `mic_probe` sent → `mic_ack` clears watchdog); mute drops frames and
  sends `mic`; `interrupted` flushes; `closed{reason}` → `ended`; socket
  drop → `connection lost`; `stop` sends `stt_stop` then `stop`; refuses
  start while `cockpitCallLive`.
- `App.test.tsx` — Call tab renders; deep link routes to it.

## On-device verification (the part tests cannot do)

Run the spec's acceptance criteria 1–17 on the phone against c-5004.
Criterion 3 (side-button lock, 2 min, still talking) is the one this
whole feature exists for — do it first, before polishing anything.
Watch the bridge's `data/voice-live/<session>.jsonl` while doing it; a
gap in mic frames while locked means the session dropped and the
*Audio session ownership* section is wrong.

## Rollout

1. PR against `main` in context-grabber (JS only).
2. `just ota` — the tab appears on next app launch.
3. Cockpit repo: **no change required.** Optional follow-up there:
   surface `client: "app"` in the session log if Igor wants native vs page
   calls distinguishable (would be a new key on the `start` frame; the
   bridge ignores unknown keys today).

## Phase 2 candidates (separate specs)

- CallKit: lock-screen hang-up, the green pill, survive an incoming phone
  call, no orange-dot ambiguity.
- Voice / model picker from `GET /voices` (favourites) and the page's
  model list.
- Reconnect on socket drop within the bridge's 2-minute idle window.
- Live Activity for the call (timer + hang-up) — `ios/LiveActivity/` is a
  `WidgetBundle`, add a `Widget` struct, not a target.
- `mode` on `audio-route.activate()` so one module owns the session.
