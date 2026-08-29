/**
 * The voice bridge's wire format, as the native Call tab speaks it.
 *
 * One WebSocket. Up: one `start` frame, then binary PCM16 @ 16 kHz mic
 * frames and a few small JSON notices. Down: binary PCM16 at the rate the
 * `ready` frame names, and JSON events. Everything that makes the call a
 * conversation — turn-taking, barge-in, "hang up" meaning hang up, the idle
 * rule, Larry's persona and tools — is the bridge's. This file only knows
 * how to say things to it and how to read what it says back.
 *
 * Source of truth: `handle_browser`'s docstring in the Cockpit repo's
 * `voice_bridge.py`. Page reference: `talkStart` and friends in `index.html`.
 * Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md.
 */

import type { CallBackend } from "./deepLink";

export type { CallBackend };

export const BACKENDS: ReadonlyArray<{ id: CallBackend; label: string }> = [
  { id: "gemini", label: "Gemini" },
  { id: "eleven", label: "ElevenLabs" },
  { id: "openai", label: "OpenAI" },
  { id: "drill", label: "Drill" },
];

export const DEFAULT_BACKEND: CallBackend = "gemini";

export function isCallBackend(value: unknown): value is CallBackend {
  return BACKENDS.some((b) => b.id === value);
}

/**
 * Where the bridge is, given where the Cockpit page is. Over https Tailscale
 * Serve mounts the bridge at `/bridge`; on plain http it is its own port.
 * Mirrors the page's `talkBridgeUrl`.
 */
export function bridgeUrl(cockpitUrl: string): string {
  const u = new URL(cockpitUrl);
  if (u.protocol === "https:") return `wss://${u.host}/bridge`;
  return `ws://${u.hostname}:8780`;
}

/* ---------- outbound ---------- */

export function startFrame(backend: CallBackend): string {
  // Empty model / voice = the vendor's default, which is what a page older
  // than the pickers sends. Phase 2 fills these in.
  return JSON.stringify({ type: "start", backend, model: "", voice: "" });
}

export function sttStartFrame(): string {
  return JSON.stringify({ type: "stt_start", rate: 16000 });
}

export function sttStopFrame(): string {
  return JSON.stringify({ type: "stt_stop" });
}

export function stopFrame(): string {
  return JSON.stringify({ type: "stop" });
}

/** A notice, not a control: the client already stopped sending audio. */
export function micFrame(muted: boolean): string {
  return JSON.stringify({ type: "mic", muted });
}

export function micProbeFrame(token: number): string {
  return JSON.stringify({ type: "mic_probe", token });
}

/* ---------- inbound ---------- */

export type BridgeMessage =
  | { type: "ready"; outRate: number; backend: string; session: string }
  | { type: "mic_ack"; token: number }
  | { type: "transcript"; who: string; text: string; source: string | null }
  | { type: "stt_partial"; text: string }
  | { type: "stt_final"; text: string }
  | { type: "interrupted" }
  | { type: "turn_end" }
  | { type: "tool_call"; question: string }
  | { type: "tool_result"; ok: boolean; answer: string }
  | { type: "consult_progress"; stage: string; text: string }
  | { type: "injected"; text: string }
  | { type: "warning"; message: string }
  | { type: "error"; message: string }
  | { type: "vendor_closed"; kind: string; message: string }
  | { type: "closed"; reason: string };

/** The rate the page assumes when a bridge is too old to say. */
const DEFAULT_OUT_RATE = 24000;

const str = (v: unknown): string => (typeof v === "string" ? v : "");

/**
 * `null` for junk and for every event the screen does not render
 * (`turn_metrics`, `stt_ready`, the control-path replies…). Ignoring is the
 * contract: the bridge adds event types faster than any client renders them.
 */
export function parseBridgeMessage(raw: unknown): BridgeMessage | null {
  if (typeof raw !== "string" || !raw) return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
  const m = parsed as Record<string, unknown>;
  switch (m.type) {
    case "ready":
      return {
        type: "ready",
        outRate: typeof m.out_rate === "number" && m.out_rate > 0 ? m.out_rate : DEFAULT_OUT_RATE,
        backend: str(m.backend),
        session: str(m.session),
      };
    case "mic_ack":
      return { type: "mic_ack", token: Number(m.token) };
    case "transcript":
      return {
        type: "transcript",
        who: str(m.who),
        text: str(m.text),
        source: typeof m.source === "string" ? m.source : null,
      };
    case "stt_partial":
      return { type: "stt_partial", text: str(m.text) };
    case "stt_final":
      return { type: "stt_final", text: str(m.text) };
    case "interrupted":
      return { type: "interrupted" };
    case "turn_end":
      return { type: "turn_end" };
    case "tool_call":
      return { type: "tool_call", question: str(m.question) };
    case "tool_result":
      return { type: "tool_result", ok: m.ok !== false, answer: str(m.answer) };
    case "consult_progress":
      return { type: "consult_progress", stage: str(m.stage), text: str(m.text) };
    case "injected":
      return { type: "injected", text: str(m.text) };
    case "warning":
      return { type: "warning", message: str(m.message) };
    case "error":
      return { type: "error", message: str(m.message) };
    case "vendor_closed":
      return { type: "vendor_closed", kind: str(m.kind), message: str(m.message) };
    case "closed":
      return { type: "closed", reason: str(m.reason) };
    default:
      return null;
  }
}

/* ---------- endings ---------- */

/** The client's own reason for a socket that dropped without a `closed`. */
export const CONNECTION_LOST = "connection lost";

/** The bridge's reason for a tap on Hang up. */
export const STOPPED = "stopped";

/**
 * The bridge's reason → what the screen says. Mirrors the page's
 * `TALK_ENDINGS`; an unrecognised reason is printed verbatim, because giving
 * a failure a cause it did not state is worse than an unfamiliar sentence.
 */
export function endingText(reason: string | null | undefined): string {
  switch (reason) {
    case "idle timeout":
      return "idle 2 min";
    case "hangup intent":
      return "hang-up intent";
    case "":
    case null:
    case undefined:
      return "session ended";
    default:
      return reason;
  }
}
