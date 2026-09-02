/**
 * The Cockpit audio bridge — protocol only, no React and no native calls, so
 * every rule in it is testable on a Linux box with no phone attached.
 *
 * Why the bridge exists at all: WebKit (which is every browser engine on iOS,
 * this app's `WKWebView` included) enumerates one nameless audio input and
 * zero audio outputs, and implements no `setSinkId`. The Cockpit's device
 * pickers therefore hide themselves inside the app — correctly, since a
 * `<select>` with one nameless option is a control that cannot do anything.
 * The real roster lives in `AVAudioSession`; this is the wire format for
 * getting it to the page and getting the page's choice back.
 *
 * Full protocol: `docs/cockpit-audio-bridge.md`.
 */


import { isCallBackend, type CallBackend } from "./callProtocol";
import type {
  AudioRouteChange,
  AudioRouteSnapshot,
} from "../modules/audio-route";

/** Bumped only for a breaking change. New message types do not bump it. */
export const BRIDGE_VERSION = 1;

/** The `CustomEvent` type the app dispatches on `window`. */
export const BRIDGE_EVENT = "cockpit-audio";

/** The global the page feature-detects on. */
export const BRIDGE_GLOBAL = "CockpitAudioBridge";

export type BridgeRequest =
  | { type: "audio.listDevices"; requestId?: string }
  | { type: "audio.getRoute"; requestId?: string }
  | { type: "audio.setInput"; requestId?: string; id: string | null }
  | { type: "audio.setOutput"; requestId?: string; port: string };

export type BridgeReadyPayload = {
  type: "audio.ready";
  version: number;
  platform: string;
  available: boolean;
};

export type BridgeDevicesPayload = AudioRouteSnapshot & {
  type: "audio.devices";
  requestId?: string;
};

export type BridgeRouteChangedPayload = AudioRouteChange & {
  type: "audio.routeChanged";
};

export type BridgeErrorPayload = {
  type: "audio.error";
  op: string;
  message: string;
  requestId?: string;
};

export type BridgePayload =
  | BridgeReadyPayload
  | BridgeDevicesPayload
  | BridgeRouteChangedPayload
  | BridgeErrorPayload;

const REQUEST_TYPES = [
  "audio.listDevices",
  "audio.getRoute",
  "audio.setInput",
  "audio.setOutput",
] as const;

function asString(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

/**
 * Parse one `onMessage` payload.
 *
 * Returns `null` for anything that is not a well-formed bridge request —
 * malformed JSON, a bare string, some other feature's message. The page owns
 * `postMessage` and may well be using it for something else; swallowing
 * traffic that is not ours would be a bug, so non-bridge messages fall
 * through untouched.
 */
export function parseBridgeRequest(raw: unknown): BridgeRequest | null {
  const text = asString(raw);
  if (!text) return null;

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;

  const msg = parsed as Record<string, unknown>;
  const type = asString(msg.type);
  if (!type || !(REQUEST_TYPES as readonly string[]).includes(type)) return null;

  const requestId = asString(msg.requestId);
  const base = requestId ? { requestId } : {};

  if (type === "audio.setInput") {
    // Absent, null, and "" all mean the same thing: hand the choice back to
    // iOS. A pick is a pick; the absence of one is the system default.
    const id = asString(msg.id);
    return { type, ...base, id: id && id.length > 0 ? id : null };
  }

  if (type === "audio.setOutput") {
    // `id` is accepted as an alias of `port` so a page written against an
    // early sketch of this protocol still works.
    const port = asString(msg.port) ?? asString(msg.id);
    if (port === undefined) return null;
    return { type, ...base, port };
  }

  return { type: type as "audio.listDevices" | "audio.getRoute", ...base };
}

export function readyPayload(available: boolean, platform = "ios"): BridgeReadyPayload {
  return { type: "audio.ready", version: BRIDGE_VERSION, platform, available };
}

export function devicesPayload(
  snapshot: AudioRouteSnapshot,
  requestId?: string,
): BridgeDevicesPayload {
  return { type: "audio.devices", ...snapshot, ...(requestId ? { requestId } : {}) };
}

export function routeChangedPayload(change: AudioRouteChange): BridgeRouteChangedPayload {
  return { type: "audio.routeChanged", ...change };
}

export function errorPayload(
  op: string,
  message: string,
  requestId?: string,
): BridgeErrorPayload {
  return { type: "audio.error", op, message, ...(requestId ? { requestId } : {}) };
}

/**
 * The least-bad string for an unknown throw. Native module rejections arrive
 * as `Error`s; a `code` prefix from Expo is more noise than signal for a page
 * that is going to show this to a human.
 */
export function describeError(error: unknown): string {
  if (error instanceof Error && error.message) return error.message;
  if (typeof error === "string" && error) return error;
  return "Unknown audio error";
}

/**
 * Embed a value as a JS expression that is safe to hand to `injectJavaScript`.
 *
 * Double-encoding and parsing back, rather than splicing the object literal
 * in: a device name is user-controlled text (a Bluetooth headset is named by
 * whoever paired it) and it lands inside a script we evaluate. U+2028/U+2029
 * are escaped explicitly because they are string-literal line terminators on
 * older engines.
 */
function jsonLiteral(value: unknown): string {
  return JSON.stringify(JSON.stringify(value))
    .replace(/\u2028/g, "\\u2028")
    .replace(/\u2029/g, "\\u2029");
}

/**
 * Installed via `injectedJavaScriptBeforeContentLoaded`, so the page can
 * feature-detect the bridge on its very first line of script rather than
 * racing a load event.
 *
 * Trailing `true;` is required: on iOS an injected script whose last
 * expression is not a primitive logs a warning on every injection.
 */
export function bridgeInstallScript(platform = "ios"): string {
  return `(function () {
  if (window.${BRIDGE_GLOBAL} && window.${BRIDGE_GLOBAL}.version >= ${BRIDGE_VERSION}) return;
  function post(msg) {
    try { window.ReactNativeWebView.postMessage(JSON.stringify(msg)); } catch (e) {}
  }
  window.${BRIDGE_GLOBAL} = {
    version: ${BRIDGE_VERSION},
    platform: ${JSON.stringify(platform)},
    last: null,
    post: post,
    listDevices: function (requestId) { post({ type: "audio.listDevices", requestId: requestId }); },
    getRoute: function (requestId) { post({ type: "audio.getRoute", requestId: requestId }); },
    setInput: function (id, requestId) { post({ type: "audio.setInput", id: id, requestId: requestId }); },
    setOutput: function (port, requestId) { post({ type: "audio.setOutput", port: port, requestId: requestId }); }
  };
})();
true;`;
}

/**
 * Deliver one payload to the page.
 *
 * A `CustomEvent` on its own type rather than a `MessageEvent` on `window`
 * (which is what `webViewRef.postMessage` produces): the Cockpit has its own
 * `message` consumers and audio traffic has no business landing in them.
 *
 * `last` is written before the event is dispatched so a page that attaches
 * its listener late can still read the most recent snapshot synchronously.
 */
export function bridgeEmitScript(payload: BridgePayload): string {
  return `(function () {
  var detail = JSON.parse(${jsonLiteral(payload)});
  if (window.${BRIDGE_GLOBAL}) { window.${BRIDGE_GLOBAL}.last = detail; }
  try {
    window.dispatchEvent(new CustomEvent(${JSON.stringify(BRIDGE_EVENT)}, { detail: detail }));
  } catch (e) {}
})();
true;`;
}

/* ---------- call state (page → app) ----------
   Only the page knows when a call is connecting, live, or over — it owns the
   socket. It says so through the same channel as the audio requests, and the
   app holds the screen awake for exactly that long.
   Spec: docs/superpowers/specs/2026-08-28-cockpit-keep-awake-design.md. */

export type CallStateMessage = { type: "call.state"; live: boolean };

/** `null` for anything that is not a well-formed call.state — left for other consumers. */
export function parseCallState(raw: unknown): CallStateMessage | null {
  const text = typeof raw === "string" ? raw : "";
  if (!text) return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
  const m = parsed as { type?: unknown; live?: unknown };
  if (m.type !== "call.state" || typeof m.live !== "boolean") return null;
  return { type: "call.state", live: m.live };
}

/* ---------- the page asks for the app's call (#99) ----------
   With the app's native call live, the page's masthead ☎︎ does not dial: it
   asks the app to focus the call. `call.start` is the same ask from a page
   that would otherwise dial — while a native call is live it is a focus;
   idle, it is a dial on the named backend.
   Spec: docs/superpowers/specs/2026-08-29-open-cockpit-and-page-handoff-design.md. */

export type CallControlMessage =
  | { type: "call.focus" }
  | { type: "call.start"; via: CallBackend | null };

/** `null` for anything that is not a well-formed call.focus / call.start. */
export function parseCallControl(raw: unknown): CallControlMessage | null {
  const text = typeof raw === "string" ? raw : "";
  if (!text) return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
  const m = parsed as { type?: unknown; via?: unknown; backend?: unknown };
  if (m.type === "call.focus") return { type: "call.focus" };
  if (m.type === "call.start") {
    const via = m.via ?? m.backend;
    return { type: "call.start", via: isCallBackend(via) ? via : null };
  }
  return null;
}
