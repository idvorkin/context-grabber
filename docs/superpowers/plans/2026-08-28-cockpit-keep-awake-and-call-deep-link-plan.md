# Plan: Cockpit keep-awake (#72) + call deep link (#75 phase 1)

Specs: `../specs/2026-08-28-cockpit-keep-awake-design.md`,
`../specs/2026-08-28-cockpit-call-deep-link-design.md`.
Both ship as one OTA from `context-grabber` + one page PR in `igor2`.

## context-grabber (JS only — no native build)

### Keep awake — `screens/CockpitScreen.tsx`
- `expo-keep-awake` 55.0.6 is already a dep and `ExpoKeepAwake` is in the
  shipped Podfile.lock (GymTimerScreen uses `useKeepAwake`).
- CockpitScreen stays mounted while hidden, so `useKeepAwake()` would hold the
  screen on every tab. Use an effect keyed on `visible`:
  `activateKeepAwakeAsync("cockpit")` when visible, `deactivateKeepAwake("cockpit")`
  on hide/unmount. Tagged so it cannot collide with the Gym Timer's default
  tag. Wrap in try/catch (expo-keep-awake throws in jest without the mock).
- jest.setup.js: mock `expo-keep-awake` (activate/deactivate as jest.fn) and
  assert in `__tests__/CockpitScreen.test.tsx`: activate on visible, deactivate
  on hide, deactivate on unmount, never activated while hidden.

### Call deep link
- `lib/deepLink.ts`: new route `{ kind: "call"; via: CallBackend | null }` for
  path `call`, `via` ∈ {eleven, gemini, openai, drill} else null. Update the
  header comment. Tests in `__tests__/deepLink.test.ts` (both schemes, each
  via, unknown via → null, `call/anything` → still call).
- `App.tsx` deep-link handler: `route.kind === "call"` → close overlays
  (gym timer etc.), `setCockpitMounted(true)`, `setActiveTab("cockpit")`,
  `setCallIntent({ via, nonce: Date.now() })`.
- `screens/CockpitScreen.tsx` new prop `callIntent?: { via: string | null; nonce: number } | null`.
  Delivery, in `lib/audioBridge.ts` next to the existing bridge helpers:
  - `callIntentInstallScript(intent)` — injected before content on a fresh
    load: `window.CockpitCallIntent = { type: "call.start", via, nonce }`.
    Implemented by feeding `injectedJavaScriptBeforeContentLoaded` the bridge
    install script concatenated with this when an intent is pending at
    mount/reload time.
  - `callIntentEmitScript(intent)` — for an already-loaded page:
    `window.CockpitCallIntent = …; window.dispatchEvent(new CustomEvent("cockpit-call", { detail }))`.
  - Rules: an intent is delivered at most once (track delivered nonce in a
    ref); delivered on `onLoadEnd` if the page loaded after the intent
    arrived; **dropped** (nonce marked delivered) on `onError`/`onHttpError`
    so a later retry never starts a stale call (spec: "consumed by a failed
    load"). `onContentProcessDidTerminate` reload does NOT re-deliver.
- Tests: `__tests__/CockpitScreen.test.tsx` — intent while loaded → inject
  once; intent before load → delivered on load end, not before; error → not
  delivered on the next load; same nonce twice → once. `__tests__/App.test.tsx`
  — `grabber://call` switches to Cockpit tab.
- `docs/cockpit-audio-bridge.md`: new section "call.start" documenting
  `window.CockpitCallIntent` + `cockpit-call` event (app → page only; no
  version bump — additive).

## igor2 (page) — `decision_queue/index.html`
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
