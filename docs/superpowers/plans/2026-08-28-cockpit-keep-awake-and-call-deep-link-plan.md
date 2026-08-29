# Plan: Cockpit keep-awake (#72) + call deep link (#75 phase 1)

Specs: `../specs/2026-08-28-cockpit-keep-awake-design.md`,
`../specs/2026-08-28-cockpit-call-deep-link-design.md`.
Both ship as one OTA from `context-grabber` + one page PR in `igor2`.

## context-grabber (JS only — no native build)

### Keep awake — a function of the call
- `expo-keep-awake` 55.0.6 is already a dep and `ExpoKeepAwake` is in the
  shipped Podfile.lock (GymTimerScreen uses `useKeepAwake`).
- Page → app: the Cockpit page posts `{type:"call.state", live:true|false}`
  through the bridge's `post` (same `window.ReactNativeWebView.postMessage`
  channel as the audio requests) when a call starts connecting and when it
  is torn down. `lib/audioBridge.ts` parses it alongside the audio requests
  (`parseBridgeRequest` grows a `call.state` case; a message the page can
  send without a `requestId`).
- `screens/CockpitScreen.tsx`: `callLive` state. Effect keyed on `callLive`:
  `activateKeepAwakeAsync("cockpit")` when true, `deactivateKeepAwake("cockpit")`
  when false / on unmount. Independent of `visible` — a call keeps running
  in the hidden tab. Reset `callLive` to false on `onLoadStart` (reload),
  `onError` / `onHttpError`, and `onContentProcessDidTerminate`: a page that
  went away is a call that ended, whether or not it said so.
- jest.setup.js already mocks `activateKeepAwakeAsync` / `deactivateKeepAwake`.
  `__tests__/CockpitScreen.test.tsx`: held on `call.state live:true`,
  released on `live:false`, released on reload/error/unmount, never held for
  the tab alone, still held while hidden.

### Call deep link
- `lib/deepLink.ts`: new route `{ kind: "call"; via: CallBackend | null }` for
  path `call`, `via` ∈ {eleven, gemini, openai, drill} else null. Update the
  header comment. Tests in `__tests__/deepLink.test.ts` (both schemes, each
  via, unknown via → null, `call/anything` → still call).
- `App.tsx` deep-link handler: `route.kind === "call"` → close overlays
  (gym timer etc.), `setCockpitMounted(true)`, `setActiveTab("cockpit")`,
  `setCallIntent({ via, nonce: Date.now() })`.
- `screens/CockpitScreen.tsx` new prop `callIntent?: { via: CallBackend | null; nonce: number } | null`.
  Delivery, in `lib/audioBridge.ts` next to the existing bridge helpers —
  ONE script, `callIntentEmitScript(intent)`, injected after load:
  `window.CockpitCallIntent = …; window.dispatchEvent(new CustomEvent("cockpit-call", { detail }))`.
  (No before-content install script: the page's bootstrap has run by load
  end, and it both reads the global and listens for the event, so a single
  post-load delivery covers a fresh load and an already-loaded page alike.)
  - Rules: an intent is delivered at most once (delivered nonce in a ref);
    the effect is keyed on `loading`, so an intent that arrives mid-load is
    delivered on load end; **consumed** (nonce marked delivered) when an
    error pane is showing, so a later retry never starts a stale call (spec:
    "consumed by a failed load"). `onContentProcessDidTerminate` reload does
    NOT re-deliver.
- Tests: `__tests__/CockpitScreen.test.tsx` — intent while loaded → inject
  once; intent before load → delivered on load end, not before; error → not
  delivered on the next load; same nonce twice → once. `__tests__/App.test.tsx`
  — `grabber://call` switches to Cockpit tab.
- `docs/cockpit-audio-bridge.md`: new section "call.start" documenting
  `window.CockpitCallIntent` + `cockpit-call` event (app → page only; no
  version bump — additive).

## Cockpit page — `index.html` in `idvorkin-ai-tools/cockpit` (branch `extract`; moved out of `igor2/decision_queue` on 2026-08-28 — page-side changes are PRs there, from a spec)
- Bootstrap: `function cockpitCallIntent(m)`; feature-detect
  `window.CockpitCallIntent` at load and `window.addEventListener("cockpit-call", …)`.
  Consume once (clear `window.CockpitCallIntent` after handling).
- Handling: if `m.via` ∈ TALK_LABEL keys and differs → `talkSwitchBackend(via)`;
  then the exact body of `startCallFromMasthead()` (hide takeovers, `setTab("talk", true)`,
  bail if live/starting, bail on `talkMicBlockedReason()`, `talkStart()`).
  Refactor `startCallFromMasthead` into `startCallNow(opts)` shared by both.
- Fallback: if `talkStart()` fails because the engine refused audio outside a
  gesture (catch on AudioContext/`resume` rejection), call `talkState("", "ready · <backend> · tap ☎ to start")`.
- Audit: `audio_device_audit.cjs` (or `route_smoke.cjs`) case: page loaded with
  `window.CockpitCallIntent = {type:"call.start", via:"gemini"}` → tab is
  talk, backend switched, `talkStart` invoked once (stub `TALK` socket);
  second `cockpit-call` while `TALK.starting` → ignored. DESIGN.md P-note +
  README paragraph under the masthead handset section.
- Commit style: `feat(call): a link that starts the call — Shortcuts, Action Button, widgets`.

## Rollout
1. igor2 page PR (page tolerates the intent before the app sends it).
2. context-grabber PR → merge → `just ota`.
3. On-device check of acceptance criterion 1 (cold start, no tap). If WebKit
   refuses audio outside a gesture, the fallback state line is what ships and
   #74 carries the real fix.
