# Deep Links + Home-Screen Widget — Implementation Plan

Engineering plan for the feature described in [`2026-04-23-deep-links-and-home-widget-design.md`](../specs/2026-04-23-deep-links-and-home-widget-design.md). This doc holds file paths, type shapes, and rollout order; the spec holds the behavior contract.

## Phase split

The work breaks cleanly into two ship-worthy phases. Each phase is independently valuable and has its own commit + deploy cycle.

| Phase | Scope | Delivery |
|---|---|---|
| **P1** | Deep-link routing in JS + `GymTimerScreen` prop-driven preset/autostart + existing Live Activity taps start routing correctly. | **OTA-able** — no native changes in this phase (existing scheme already registered). |
| **P2** | `grabber://` scheme alias (plist edit) + home-screen widget Swift code + App Group + app-side snapshot writer. | **Native deploy** — requires `just deploy` + Apple Developer portal App Group registration. |

Ship P1 first, validate deep links via `xcrun simctl openurl`, then do P2.

## Phase 1 — Deep link routing (OTA-able)

### Files touched

- `lib/deepLink.ts` — **new** — pure URL parser.
- `__tests__/deepLink.test.ts` — **new** — table-driven tests for the parser.
- `App.tsx` — wire `Linking.addEventListener` + `Linking.getInitialURL`, route to state.
- `components/GymTimerScreen.tsx` — accept optional `initialPreset`, `initialMode`, `autostart` props; thread `autostart` into `RoundsMode`.

No `app.json`, no plist, no Pods.

### Parser shape

```ts
// lib/deepLink.ts

export type DeepLinkRoute =
  | { kind: "main"; autoGrab: boolean }
  | { kind: "timer"; mode: "rounds" | "stopwatch" | "sets"; preset: string | null; autostart: boolean }
  | { kind: "unknown" };

export function parseDeepLink(url: string | null | undefined): DeepLinkRoute;
```

The parser accepts both schemes (`com.idvorkin.contextgrabber://` and `grabber://`) by stripping the scheme and parsing the remainder as path + query. Unknown paths return `{ kind: "unknown" }`, which callers treat as "open main without auto-grab."

Preset validation is a whitelist: accept only `"30sec" | "1min" | "5-1"`. Any other value falls back to `null` (preset unchanged).

### App.tsx wiring

Add a single handler function:

```ts
function handleDeepLink(url: string | null) {
  const route = parseDeepLink(url);
  switch (route.kind) {
    case "main":
      setGymTimerVisible(false);
      if (route.autoGrab) void grabContext();
      return;
    case "timer":
      setTimerIntent({ mode: route.mode, preset: route.preset, autostart: route.autostart });
      setGymTimerVisible(true);
      return;
    // unknown → no-op (already on main)
  }
}
```

Two new pieces of state:

```ts
const [timerIntent, setTimerIntent] = useState<{
  mode: "rounds" | "stopwatch" | "sets";
  preset: string | null;
  autostart: boolean;
} | null>(null);
```

Register listeners once in a `useEffect`:

```ts
useEffect(() => {
  Linking.getInitialURL().then(handleDeepLink);
  const sub = Linking.addEventListener("url", (ev) => handleDeepLink(ev.url));
  return () => sub.remove();
}, []);
```

Pass `timerIntent` through to `GymTimerScreen`. Consume-once: `GymTimerScreen` reads it on mount (and on `key` change from a new intent) and clears the parent's state so repeated foreground URLs keep re-firing.

### GymTimerScreen props

```ts
type GymTimerScreenProps = {
  onExit: () => void;
  initialMode?: "rounds" | "stopwatch" | "sets";
  initialPreset?: string;    // preset ID; ignored if not in PRESETS
  autostart?: boolean;
};
```

`RoundsMode` accepts `autostart`: if true, fires a single `toggle()` in a `useEffect` with the mount-deps pattern (ref-guarded so it can only fire once per mount even under StrictMode double-invocation in dev).

### Live Activity routing — drop-in

No Swift change needed. The existing `deepLinkUrl` flow produces a URL like `com.idvorkin.contextgrabber://timer` when the Live Activity is created — once JS handles that scheme, the tap routes. Verify by checking the `useLiveActivity` hook's `start()` call site; if the URL string isn't already set, set it to `"timer"` there (that appex adds the scheme + `://`).

### Tests

`__tests__/deepLink.test.ts` — pure function, zero mocks:

- Valid URLs for each row of the spec's route table → exact expected `DeepLinkRoute`.
- Both schemes (`com.idvorkin.contextgrabber://` and `grabber://`) produce identical routes.
- Unknown preset ID drops to `preset: null`.
- Malformed URL returns `{ kind: "unknown" }`.
- Query param on a path-typed route (e.g. `?autostart=1` on `/main`) is silently ignored.

Integration test for `App.tsx` is not necessary — the parser is the only logic worth covering; the routing switch is trivial.

### Ship P1

1. Spec committed, bead claimed.
2. Parser + tests.
3. App.tsx wiring + GymTimerScreen props.
4. `npx jest --no-coverage` green, `npx tsc --noEmit` green.
5. `git push` to `main`.
6. `just ota "deep link routing"`.
7. Verify on device: `xcrun simctl openurl booted grabber://timer?preset=1min&autostart=1` (use `com.idvorkin.contextgrabber://…` form for the actual device since `grabber://` isn't registered yet until P2). On real device, trigger via Safari or by letting the Live Activity tap do it.

## Phase 2 — Home Screen widget + scheme alias (native deploy)

### Files touched

- `ios/ContextGrabber/Info.plist` — add `grabber` to `CFBundleURLSchemes`.
- `ios/ContextGrabber/ContextGrabber.entitlements` — add App Group capability.
- `ios/LiveActivity/LiveActivity.entitlements` — add same App Group.
- `ios/LiveActivity/TodayWidget.swift` — **new** — SwiftUI widget for Design B.
- `ios/LiveActivity/TodayWidgetEntry.swift` — **new** — timeline entry + provider.
- `ios/LiveActivity/LiveActivityWidgetBundle.swift` — add `TodayWidget()` to bundle body.
- `lib/widgetSnapshot.ts` — **new** — JS-side helper that writes `{ steps, sleepHours, exerciseMinutes, grabbedAt }` to shared UserDefaults.
- `App.tsx` — call `writeWidgetSnapshot(...)` at the end of `grabContext()` after `setSnapshot(...)`.
- Possibly a bridging module — if `expo-live-activity` doesn't already expose a shared-UserDefaults write, we need a thin native module OR use `@react-native-async-storage/async-storage` with an App Group config (preferred if available).

### App Group

Identifier: `group.com.idvorkin.contextgrabber`.

Setup steps (one-time, some require Apple Developer portal access):

1. Apple Developer portal → Identifiers → create App Group `group.com.idvorkin.contextgrabber`.
2. Enable the App Group on both bundle IDs (main app + LiveActivity appex).
3. Regenerate provisioning profiles (Xcode can do this automatically once the capability is toggled).
4. Add `com.apple.security.application-groups` with the group string to both `.entitlements` files.
5. In Swift (widget): `UserDefaults(suiteName: "group.com.idvorkin.contextgrabber")`.
6. In JS: write via a native module that wraps the same suite.

This is the fiddly bit — User action needed at step 1 (portal login) and step 3 (Xcode signing). Everything else is code.

### Widget Swift sketch

```swift
// ios/LiveActivity/TodayWidget.swift
import WidgetKit
import SwiftUI

struct TodayEntry: TimelineEntry {
  let date: Date
  let steps: Int?
  let sleepHours: Double?
  let exerciseMinutes: Int?
  let grabbedAt: Date?
}

struct TodayProvider: TimelineProvider {
  func placeholder(in: Context) -> TodayEntry { .empty }
  func getSnapshot(in: Context, completion: @escaping (TodayEntry) -> Void) {
    completion(loadFromAppGroup())
  }
  func getTimeline(in: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
    let entry = loadFromAppGroup()
    // Reload on next Grab via WidgetCenter; in the meantime, refresh every 30 min as a safety net.
    let next = Date().addingTimeInterval(30 * 60)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

struct TodayWidget: Widget {
  let kind = "TodayWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
      TodayWidgetView(entry: entry)
    }
    .configurationDisplayName("Today")
    .description("Today's snapshot + quick-start timer")
    .supportedFamilies([.systemMedium])
  }
}
```

`TodayWidgetView` composes the two-row layout from the spec. Each tap zone is a SwiftUI `Link(destination: URL(string: "grabber://…")!)` wrapping the visual region.

On the JS side, `writeWidgetSnapshot` calls `WidgetCenter.shared.reloadAllTimelines()` through a native bridge so the widget picks up the new data immediately rather than waiting for its 30-min safety-net refresh.

### Rollout

1. Portal + Xcode setup (user click-through, 10 min).
2. Entitlements + plist edits committed.
3. Swift widget files committed (doesn't break the build even before JS is wired).
4. `lib/widgetSnapshot.ts` + `App.tsx` grabContext hook.
5. `just deploy` to device.
6. Long-press home screen → Add Widget → pick "Context Grabber → Today". Verify all three tap zones.

## Risks

- **App Group provisioning is the most likely sticking point.** If `expo-live-activity` already uses an App Group, we inherit it. Check before creating a new one. If not, the Developer portal step blocks progress until user is available.
- **iOS widget refresh throttling.** Even with `reloadAllTimelines()`, iOS can defer. If the user reports "widget shows yesterday's steps," the fix is to add a longer staleness window check in the Swift side (display a subtle `•` marker when `grabbedAt` is more than 24h old — deferred to v2).
- **Scheme collision.** `grabber://` is short enough that a third-party app could have claimed it. If so, iOS resolves to whichever app was installed most recently, which is unpredictable. Mitigation: the bundle-ID form (`com.idvorkin.contextgrabber://`) is collision-proof and remains registered.

## Not in this plan

- Android widget.
- Configurable widget (choosing which metrics to show).
- Live countdown in the widget while a timer runs (would require coordinating with Live Activity — out of scope).
- Universal links / Safari smart banners.
