# Cockpit Audio Bridge — protocol

How the Cockpit web page asks Context Grabber for the phone's real audio
devices, and how it tells the app which ones to use.

Functional spec: [`superpowers/specs/2026-08-28-cockpit-audio-bridge-design.md`](superpowers/specs/2026-08-28-cockpit-audio-bridge-design.md).
Bead: `igor2-88g.168`.

Implemented on the app side by:

| piece | file |
| --- | --- |
| protocol (pure, tested) | `lib/audioBridge.ts` |
| web view wiring | `screens/CockpitScreen.tsx` |
| native audio session | `modules/audio-route/` (local Expo module, iOS-only) |

The page consuming it lives in another repository
(`igor2/decision_queue/index.html`) and is a **follow-up** — nothing here
requires it. With no page using the bridge, the app behaves exactly as it
did before.

## Why this exists

Every browser engine on iOS is WebKit, and WebKit exposes:

- exactly **one** `audioinput` from `enumerateDevices()`, unnamed, however
  many microphones are attached;
- **zero** `audiooutput` entries, ever;
- no `setSinkId` — not on media elements, not on `AudioContext`.

So the Cockpit's device pickers hide themselves inside the app, correctly:
a `<select>` with one nameless option is a control that cannot do
anything. The roster and the routing controls only exist one layer down,
in `AVAudioSession`. This protocol is the pipe to that layer.

## Transport

Two directions, two mechanisms, both standard `react-native-webview`.

**Page → app** — `window.ReactNativeWebView.postMessage(JSON.stringify(msg))`,
received by the web view's `onMessage`. Messages that don't parse as JSON,
or whose `type` isn't one of the four below, are ignored and left for any
other consumer on the page.

**App → page** — the app runs `injectJavaScript` with a snippet that
dispatches a `CustomEvent`:

```js
window.dispatchEvent(new CustomEvent("cockpit-audio", { detail: <payload> }));
```

Listen with:

```js
window.addEventListener("cockpit-audio", (e) => handle(e.detail));
```

A `CustomEvent` on a named type rather than `MessageEvent` on `window`
(which is what `webViewRef.postMessage` produces): the page has its own
`message` consumers, and audio traffic has no business landing in them.

Every payload is also written to `window.CockpitAudioBridge.last` **before**
the event is dispatched, so a page that attaches its listener late can read
the most recent snapshot synchronously instead of waiting for the next one.

## Detecting the bridge

The app injects this before any page content loads, so it is present on
the very first line of page script:

```js
window.CockpitAudioBridge = {
  version: 1,
  platform: "ios",
  post(msg),          // raw escape hatch
  listDevices(requestId?),
  setInput(id, requestId?),
  setOutput(port, requestId?),
  getRoute(requestId?),
  last,               // most recent payload, or null
};
```

Feature-detect on the object, not on the user agent:

```js
const bridge = window.CockpitAudioBridge;
if (bridge && bridge.version >= 1) { /* native pickers */ }
else { /* today's enumerateDevices path, unchanged */ }
```

`version` is bumped only for a breaking change. New message types and new
optional fields do not bump it — a page must tolerate payload keys it does
not recognize.

## Page → app messages

| `type` | fields | meaning |
| --- | --- | --- |
| `audio.listDevices` | `requestId?` | send the current roster |
| `audio.setInput` | `id`, `requestId?` | use this microphone |
| `audio.setOutput` | `port`, `requestId?` | send playback here |
| `audio.getRoute` | `requestId?` | just what is live right now |

`requestId` is an opaque string the app echoes back on the answer. Supply
one to correlate; omit it for fire-and-forget.

**`audio.setInput`** — `id` is an `id` from `inputs[]`. `""` or `null`
means "system default": the app clears its preferred input and lets iOS
choose.

**`audio.setOutput`** — `port` is an `id` from `outputs[]`:

| `port` | effect |
| --- | --- |
| `"auto"` | no override; iOS picks (headset if connected, else the phone's speaker) |
| `"speaker"` | force the built-in speaker even with headphones attached |
| a port UID | steer the route to that connected headset |

`"default"`, `"receiver"`, and `"none"` are accepted as aliases of
`"auto"`. `id` is accepted as an alias of `port`. Both aliases exist so a
page written against an early sketch of this protocol still works.

## App → page messages

Every payload has a `type`. Payloads carry a `requestId` when they answer
a request that supplied one.

### `audio.ready`

Sent once per page load, after the page finishes loading.

```json
{ "type": "audio.ready", "version": 1, "platform": "ios", "available": true }
```

`available: false` means the app is running without the native module —
treat it exactly like no bridge at all.

### `audio.devices`

The answer to `audio.listDevices`, and **also** the receipt for a
successful `audio.setInput` / `audio.setOutput`: a fresh roster plus the
route that actually resulted.

```json
{
  "type": "audio.devices",
  "requestId": "abc",
  "inputs": [
    { "id": "BuiltInMic",       "name": "iPhone Microphone", "type": "MicrophoneBuiltIn" },
    { "id": "AC:12:…:0B-tacl",  "name": "AirPods Pro",       "type": "BluetoothHFP" }
  ],
  "outputs": [
    { "id": "auto",             "name": "Automatic",         "type": "auto" },
    { "id": "speaker",          "name": "Speaker",           "type": "BuiltInSpeaker" },
    { "id": "AC:12:…:0B-tacl",  "name": "AirPods Pro",       "type": "BluetoothHFP" }
  ],
  "current": {
    "input":  { "id": "BuiltInMic",      "name": "iPhone Microphone", "type": "MicrophoneBuiltIn" },
    "output": { "id": "AC:12:…:0B-tacl", "name": "AirPods Pro",       "type": "BluetoothHFP" }
  },
  "capabilities": { "selectInput": true, "selectOutput": true, "forceSpeaker": true }
}
```

- `inputs[]` — every port `AVAudioSession.availableInputs` reports. `id`
  is the port UID, stable across a connection.
- `outputs[]` — always `auto`; `speaker` whenever forcing it is possible;
  plus one entry per connected steerable destination (Bluetooth, wired,
  USB). Nothing the phone cannot currently reach is listed.
- `current` — read off `AVAudioSession.currentRoute`, i.e. what is
  **actually** carrying audio, not what was requested. Either side is
  `null` when the route has none. This is the honest source for the
  dashboard's confirmer line.
- `capabilities` — what this build can do at all, so a page can hide a
  control rather than offer one that will fail.

`current.output.id` is a port UID, or `"speaker"` when the built-in
speaker is what is live. It is never `"auto"` — `auto` is a request, not a
route.

### `audio.routeChanged`

Pushed, unsolicited, whenever iOS reports a route change — AirPods
connecting, a cable pulled, a headset battery dying, or another part of
the system reconfiguring the session.

```json
{ "type": "audio.routeChanged", "reason": "newDeviceAvailable",
  "inputs": [...], "outputs": [...], "current": {...},
  "capabilities": {...} }
```

Same shape as `audio.devices` plus `reason`, one of iOS's own:
`unknown`, `newDeviceAvailable`, `oldDeviceUnavailable`, `categoryChange`,
`override`, `wakeFromSleep`, `noSuitableRouteForCategory`,
`routeConfigurationChange`.

Treat it as a full refresh; there is no delta form.

### `audio.error`

```json
{ "type": "audio.error", "requestId": "abc", "op": "audio.setInput",
  "message": "Input not available: AC:12:…:0B-tacl" }
```

Sent instead of `audio.devices` when a request cannot be honored. Every
request with a `requestId` gets exactly one of the two — the page never
has to time out.

The app does **not** render its own error UI for these. Audio failures are
the page's to show; the app's error panel is for "can't reach the Cockpit"
and nothing else.

## Sticky routing

The requested input and output are remembered by the app for the life of
the tab and **re-asserted whenever the route changes underneath them**.

This is not belt-and-braces. The web view's own `getUserMedia`
reconfigures the app's audio session when capture starts, which can undo a
route set before the call began. Re-asserting on `categoryChange` is what
makes "pick the headset, then start the call" work rather than
mysteriously not.

Re-assertion is skipped when the live route already matches the request,
so it cannot loop. A request the session refuses twice in a row is
dropped and reported once as `audio.error`.

## Call intent (app → page)

A deep link — `grabber://call` or `grabber://call?via=eleven`, from a Siri
Shortcut, the Action Button, a widget — brings the app to the Cockpit tab and
asks the page to start a call. The app never starts it: the call is the
page's, and every rule the page's handset enforces (never a second call, no
call without a microphone, the device picks above) must hold for a link.
Spec: `superpowers/specs/2026-08-28-cockpit-call-deep-link-design.md`.

Delivered once per link, after the page has finished loading, as **both**:

```js
window.CockpitCallIntent = { type: "call.start", via: "eleven", nonce: 1756400000000 };
window.dispatchEvent(new CustomEvent("cockpit-call", { detail: <same object> }));
```

| field | meaning |
| --- | --- |
| `via` | `"eleven"`, `"gemini"`, `"openai"`, `"drill"`, or `null` for the page's current backend |
| `nonce` | distinguishes two links from one link seen twice; a page that has acted on a nonce ignores it again |

Read `window.CockpitCallIntent` at bootstrap (a listener attached late still
sees the most recent one; clear it once acted on) and listen for
`cockpit-call` for anything that arrives while the page is up. There is no
page → app half: the page answers with its own state line, and a call already
live is navigated to, not restarted.

Not part of the `version` — additive.

## Call state (page → app)

Only the page knows when a call is connecting, live, or over — it owns the
socket. It says so on the same channel as the audio requests, and the app
keeps the screen awake for exactly that long, whichever tab is showing.
Spec: `superpowers/specs/2026-08-28-cockpit-keep-awake-design.md`.

```js
window.CockpitAudioBridge.post({ type: "call.state", live: true });   // talkStart, as it begins connecting
window.CockpitAudioBridge.post({ type: "call.state", live: false });  // talkTeardown, however it ended
```

No `requestId`, no answer. A page that goes away — reload, load failure, a
content-process kill — is treated as a call that ended, whether or not it
managed to say so.

## What this does not do

- **No native capture.** The page's own `getUserMedia` still does the
  recording. This only steers where it comes from and where playback goes.
  The web view's media props (`mediaCapturePermissionGrantType`,
  `allowsInlineMediaPlayback`, `mediaPlaybackRequiresUserAction={false}`)
  are unchanged and load-bearing.
- **No persistence.** The app stores nothing across launches; the page
  already persists the choice per origin.
- **No Android.** iOS only.
- **No arbitrary output routing.** iOS offers `auto`, force-speaker, and
  steering to a connected port. That is the whole menu, and `outputs[]`
  never offers more than it.

## Worked example

```js
const bridge = window.CockpitAudioBridge;
if (bridge?.version >= 1) {
  window.addEventListener("cockpit-audio", (e) => {
    const m = e.detail;
    if (m.type === "audio.devices" || m.type === "audio.routeChanged") {
      renderPickers(m.inputs, m.outputs, m.current);
    } else if (m.type === "audio.error") {
      showAudioProblem(m.message);
    }
  });

  bridge.listDevices();

  micSelect.onchange = () => bridge.setInput(micSelect.value);
  outSelect.onchange = () => bridge.setOutput(outSelect.value);
}
```
