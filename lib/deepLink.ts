/**
 * Deep link URL parser.
 *
 * Accepts both registered schemes:
 *   com.idvorkin.contextgrabber://<path>?<query>   (bundle-ID form; used by Live Activity)
 *   grabber://<path>?<query>                        (short alias, added by Phase 2)
 *
 * Routes:
 *   (empty) | main                 → main dashboard
 *   grab                           → main, auto-trigger Grab Context
 *   timer                          → Gym Timer, rounds mode
 *   timer?preset=<id>              → Gym Timer with preset selected
 *   timer?preset=<id>&autostart=1  → Gym Timer with preset AND auto-start
 *   timer/stopwatch                → Gym Timer, stopwatch mode
 *   timer/sets                     → Gym Timer, sets mode
 *
 * Unknown URLs return { kind: "unknown" } — callers should treat as "open main".
 */

export type TimerMode = "rounds" | "stopwatch" | "sets";

export type DeepLinkRoute =
  | { kind: "main"; autoGrab: boolean }
  | { kind: "timer"; mode: TimerMode; preset: string | null; autostart: boolean }
  | { kind: "counter"; action: "inc" }
  | { kind: "unknown" };

const KNOWN_PRESETS = new Set(["30sec", "1min", "5-1"]);
const KNOWN_SCHEMES = ["com.idvorkin.contextgrabber://", "grabber://"];

/**
 * Parse a deep-link URL into a structured route.
 * Defensive against null/undefined/malformed input — returns { kind: "unknown" } rather than throwing.
 */
export function parseDeepLink(url: string | null | undefined): DeepLinkRoute {
  if (!url) return { kind: "unknown" };

  // Strip whichever scheme matched.
  let rest: string | null = null;
  for (const scheme of KNOWN_SCHEMES) {
    if (url.startsWith(scheme)) {
      rest = url.slice(scheme.length);
      break;
    }
  }
  if (rest === null) return { kind: "unknown" };

  // Split path from query.
  const queryIdx = rest.indexOf("?");
  const pathPart = queryIdx >= 0 ? rest.slice(0, queryIdx) : rest;
  const queryPart = queryIdx >= 0 ? rest.slice(queryIdx + 1) : "";

  const params = parseQuery(queryPart);
  const segments = pathPart.split("/").filter((s) => s.length > 0);

  // Empty path or explicit "main".
  if (segments.length === 0 || segments[0] === "main") {
    return { kind: "main", autoGrab: false };
  }

  if (segments[0] === "grab") {
    return { kind: "main", autoGrab: true };
  }

  if (segments[0] === "counter" && segments[1] === "inc") {
    return { kind: "counter", action: "inc" };
  }

  if (segments[0] === "timer") {
    const subMode = segments[1];
    const mode: TimerMode =
      subMode === "stopwatch" ? "stopwatch" : subMode === "sets" ? "sets" : "rounds";
    const rawPreset = params.get("preset");
    const preset = rawPreset && KNOWN_PRESETS.has(rawPreset) ? rawPreset : null;
    const autostart = params.get("autostart") === "1";
    return { kind: "timer", mode, preset, autostart };
  }

  return { kind: "unknown" };
}

function parseQuery(q: string): Map<string, string> {
  const out = new Map<string, string>();
  if (!q) return out;
  for (const pair of q.split("&")) {
    if (!pair) continue;
    const eq = pair.indexOf("=");
    if (eq < 0) {
      out.set(decodeURIComponent(pair), "");
    } else {
      out.set(decodeURIComponent(pair.slice(0, eq)), decodeURIComponent(pair.slice(eq + 1)));
    }
  }
  return out;
}
