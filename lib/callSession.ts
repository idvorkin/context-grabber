/**
 * A Larry call, native: the socket, the microphone, the speaker, and the
 * captions — with no React and no platform in it, so the whole thing runs
 * under a fake socket and a fake audio engine in tests.
 *
 *   idle ─start→ connecting ─ready→ live ─(stop | closed | drop)→ ended ─start→ …
 *
 * The bridge decides everything about the conversation. This class decides
 * only: when the mic opens (on `ready`, not before), what leaves the phone
 * (nothing while muted), when playback is cut (on `interrupted`), and how
 * the call is reported to have ended.
 *
 * Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md
 * Plan: docs/superpowers/plans/2026-08-28-native-call-screen-plan.md
 */

import {
  CONNECTION_LOST,
  STOPPED,
  micFrame,
  micProbeFrame,
  parseBridgeMessage,
  startFrame,
  sttStartFrame,
  sttStopFrame,
  stopFrame,
  type BridgeMessage,
  type CallBackend,
} from "./callProtocol";
import { encodeMicFrame } from "./pcm";

export type CallState = "idle" | "connecting" | "live" | "ended";

export type CaptionWho = "igor" | "larry" | "tool" | "note";

export type CaptionRow = {
  id: number;
  who: CaptionWho;
  text: string;
  /** Igor's words as the recognizer still hears them — not yet settled. */
  pending: boolean;
};

export type CallSnapshot = {
  state: CallState;
  backend: CallBackend | null;
  /** Wall-clock ms when the bridge said `ready`; the timer counts from here. */
  startedAt: number | null;
  /** The bridge's reason (or CONNECTION_LOST), raw — see `endingText`. */
  endedReason: string | null;
  /** True when the ending was a failure rather than a hang-up. */
  endedBadly: boolean;
  captions: CaptionRow[];
  muted: boolean;
  /** A problem that did not end the call — mic not reaching Larry, a bridge error. */
  problem: string | null;
};

/**
 * The subset of WebSocket the session uses; RN's built-in one satisfies it.
 * Handler parameters are `any` on purpose: these are properties, so their
 * parameters check contravariantly, and `unknown` would reject the real
 * socket's `Event`-typed handlers.
 */
export type BridgeSocket = {
  binaryType: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  onopen: ((ev: any) => void) | null;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  onmessage: ((ev: any) => void) | null;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  onerror: ((ev: any) => void) | null;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  onclose: ((ev: any) => void) | null;
  send(data: string | ArrayBuffer): void;
  close(): void;
};

/** The audio half: microphone in, speaker out. One implementation is native; tests fake it. */
export type CallAudio = {
  /** Session category, permission. Called before the socket opens so the prompt comes first. */
  prepare(): Promise<void>;
  /** Open the mic; every buffer arrives with the engine's actual rate. */
  startMic(onBuffer: (samples: Float32Array, sampleRate: number) => void): Promise<void>;
  /** Close and reopen the mic — the one automatic re-arm when the probe goes unanswered. */
  restartMic(): Promise<void>;
  /** Playback at the rate the bridge named. */
  openPlayback(outRate: number): void;
  /** One binary frame from the bridge, PCM16 LE at `outRate`. */
  play(pcm: ArrayBuffer): void;
  /** Barge-in: drop everything scheduled and not yet heard. */
  flush(): void;
  /** Mic, playback, session — all of it. Idempotent. */
  stop(): Promise<void>;
};

export type CallSessionDeps = {
  connect: (url: string) => BridgeSocket;
  audio: CallAudio;
  now?: () => number;
};

/** How long the bridge gets to acknowledge the first mic frame. Mirrors the page. */
export const MIC_ACK_MS = 5000;

export const MIC_NOT_REACHING = "the microphone is not reaching Larry";

type Listener = (snapshot: CallSnapshot) => void;

export class CallSession {
  private readonly deps: Required<CallSessionDeps>;
  private readonly url: string;
  private listeners = new Set<Listener>();
  private socket: BridgeSocket | null = null;
  private snap: CallSnapshot = CallSession.idle();
  private nextRowId = 1;
  /** Igor's settled-but-not-promoted words; partials are shown after them. */
  private igorFinal = "";
  private igorRowId: number | null = null;
  private larryRowId: number | null = null;
  private toolRowId: number | null = null;
  private probeToken = 0;
  private probeSent = false;
  private rearmed = false;
  private probeTimer: ReturnType<typeof setTimeout> | null = null;
  /** Set when WE closed the socket, so the close event is not "connection lost". */
  private closing = false;

  constructor(deps: CallSessionDeps, url: string) {
    this.deps = { now: () => Date.now(), ...deps };
    this.url = url;
  }

  static idle(): CallSnapshot {
    return {
      state: "idle",
      backend: null,
      startedAt: null,
      endedReason: null,
      endedBadly: false,
      captions: [],
      muted: false,
      problem: null,
    };
  }

  get snapshot(): CallSnapshot {
    return this.snap;
  }

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /* ---------- controls ---------- */

  /** No-op while a call is connecting or live: the link that finds a live call joins it. */
  async start(backend: CallBackend): Promise<void> {
    if (this.snap.state === "connecting" || this.snap.state === "live") return;
    this.resetForCall(backend);
    this.emit();
    try {
      await this.deps.audio.prepare();
    } catch (e) {
      this.finish(`microphone unavailable: ${describe(e)}`, true);
      return;
    }
    // A stop() during prepare() lands here.
    if (this.snapshot.state !== "connecting") return;
    let socket: BridgeSocket;
    try {
      socket = this.deps.connect(this.url);
    } catch (e) {
      this.finish(`${CONNECTION_LOST}: ${describe(e)}`, true);
      return;
    }
    this.socket = socket;
    socket.binaryType = "arraybuffer";
    socket.onopen = () => this.safeSend(startFrame(backend));
    socket.onmessage = (ev: { data: unknown }) => this.onSocketData(ev.data);
    socket.onerror = () => this.onSocketGone();
    socket.onclose = () => this.onSocketGone();
  }

  /** Hang up. The bridge is told first — `stt_stop` flushes Deepgram's tail, then `stop`. */
  stop(): void {
    if (this.snap.state !== "connecting" && this.snap.state !== "live") return;
    if (this.socket) {
      this.safeSend(sttStopFrame());
      this.safeSend(stopFrame());
    }
    this.finish(STOPPED, false);
  }

  setMuted(muted: boolean): void {
    if (this.snap.muted === muted) return;
    this.update({ muted });
    if (this.snap.state === "live") this.safeSend(micFrame(muted));
  }

  /* ---------- socket ---------- */

  private onSocketData(data: unknown): void {
    if (this.snap.state !== "connecting" && this.snap.state !== "live") return;
    if (typeof data === "string") {
      const m = parseBridgeMessage(data);
      if (m) this.onMessage(m);
      return;
    }
    if (isArrayBuffer(data)) {
      if (this.snap.state === "live") this.deps.audio.play(data);
      return;
    }
    // A Blob from a socket that ignored binaryType. Not ours to guess.
  }

  private onSocketGone(): void {
    if (this.closing) return;
    if (this.snap.state === "connecting" || this.snap.state === "live") {
      this.finish(CONNECTION_LOST, true);
    }
  }

  private safeSend(data: string | ArrayBuffer): void {
    try {
      this.socket?.send(data);
    } catch {
      // A socket that is already closing; its close event handles the rest.
    }
  }

  /* ---------- messages ---------- */

  private onMessage(m: BridgeMessage): void {
    switch (m.type) {
      case "ready":
        this.onReady(m.outRate);
        return;
      case "mic_ack":
        this.clearProbe();
        return;
      case "transcript":
        if (m.who === "igor") {
          // The vendor's transcript of the utterance Deepgram is previewing —
          // one lump on Gemini, one utterance on ElevenLabs, fragments on
          // native-audio. It replaces the recognizer's; the turn settles it.
          if (m.source !== "typed" && m.text) this.setIgor(m.text, "");
        } else if (m.who === "larry") {
          // Larry answering means the vendor decided Igor's turn was over.
          this.promoteIgor();
          this.appendLarry(m.text);
        }
        return;
      case "stt_partial":
        this.setIgor(this.igorFinal, m.text);
        return;
      case "stt_final":
        this.setIgor(joinWords(this.igorFinal, m.text), "");
        return;
      case "interrupted":
        this.deps.audio.flush();
        this.larryRowId = null;
        return;
      case "turn_end":
        this.larryRowId = null;
        this.promoteIgor();
        return;
      case "tool_call":
        this.promoteIgor();
        this.larryRowId = null;
        this.toolRowId = this.addRow("tool", m.question ? `asking Larry: ${m.question} …` : "asking Larry …");
        return;
      case "consult_progress":
        if (m.text) this.setTool(m.text);
        return;
      case "tool_result":
        this.setTool(m.ok ? m.answer || "answered" : "no answer");
        this.toolRowId = null;
        return;
      case "injected":
        this.larryRowId = null;
        this.addRow("note", `Larry added context: ${m.text}`);
        return;
      case "warning":
        this.larryRowId = null;
        this.addRow("note", m.message);
        return;
      case "error":
        this.update({ problem: m.message });
        return;
      case "vendor_closed":
        this.finish(m.message || (m.kind === "quota" ? "vendor quota exhausted" : "vendor hung up"), true);
        return;
      case "closed":
        this.finish(m.reason, false);
        return;
    }
  }

  private onReady(outRate: number): void {
    if (this.snap.state !== "connecting") return;
    this.update({ state: "live", startedAt: this.deps.now() });
    this.deps.audio.openPlayback(outRate);
    this.safeSend(sttStartFrame());
    void this.deps.audio.startMic(this.onMicBuffer).catch((e) => {
      // The call goes on — Larry can still be heard — but say so.
      this.update({ problem: `microphone failed: ${describe(e)}` });
    });
  }

  private onMicBuffer = (samples: Float32Array, sampleRate: number): void => {
    if (this.snap.state !== "live" || this.snap.muted) return;
    this.safeSend(encodeMicFrame(samples, sampleRate));
    if (!this.probeSent) {
      this.probeSent = true;
      this.probeToken += 1;
      this.safeSend(micProbeFrame(this.probeToken));
      this.probeTimer = setTimeout(() => this.onProbeMissed(), MIC_ACK_MS);
    }
  };

  private onProbeMissed(): void {
    this.probeTimer = null;
    if (this.snap.state !== "live") return;
    if (!this.rearmed) {
      // Once. Two silent capture graphs in a row is a fact, not a hiccup.
      this.rearmed = true;
      this.probeSent = false;
      void this.deps.audio.restartMic().catch((e) => {
        this.update({ problem: `microphone failed: ${describe(e)}` });
      });
      return;
    }
    this.update({ problem: MIC_NOT_REACHING });
  }

  private clearProbe(): void {
    if (this.probeTimer) clearTimeout(this.probeTimer);
    this.probeTimer = null;
    if (this.snap.problem === MIC_NOT_REACHING) this.update({ problem: null });
  }

  /* ---------- captions ---------- */

  private addRow(who: CaptionWho, text: string, pending = false): number {
    const id = this.nextRowId++;
    this.update({ captions: [...this.snap.captions, { id, who, text, pending }] });
    return id;
  }

  private setRow(id: number, patch: Partial<Omit<CaptionRow, "id">>): void {
    this.update({
      captions: this.snap.captions.map((r) => (r.id === id ? { ...r, ...patch } : r)),
    });
  }

  private setIgor(final: string, partial: string): void {
    this.igorFinal = final;
    const text = joinWords(final, partial);
    if (!text) {
      if (this.igorRowId !== null) this.setRow(this.igorRowId, { text: "" });
      return;
    }
    if (this.igorRowId === null) this.igorRowId = this.addRow("igor", text, true);
    else this.setRow(this.igorRowId, { text, pending: true });
  }

  /** Igor's pending row becomes a settled one; an empty pending row is dropped. */
  private promoteIgor(): void {
    const id = this.igorRowId;
    this.igorRowId = null;
    this.igorFinal = "";
    if (id === null) return;
    const row = this.snap.captions.find((r) => r.id === id);
    if (!row) return;
    if (!row.text) {
      this.update({ captions: this.snap.captions.filter((r) => r.id !== id) });
      return;
    }
    this.setRow(id, { pending: false });
  }

  private appendLarry(text: string): void {
    if (!text) return;
    if (this.larryRowId === null) {
      this.larryRowId = this.addRow("larry", text);
      return;
    }
    const row = this.snap.captions.find((r) => r.id === this.larryRowId);
    if (!row) {
      this.larryRowId = this.addRow("larry", text);
      return;
    }
    this.setRow(row.id, { text: joinWords(row.text, text) });
  }

  private setTool(text: string): void {
    if (this.toolRowId === null) this.toolRowId = this.addRow("tool", text);
    else this.setRow(this.toolRowId, { text });
  }

  /* ---------- lifecycle ---------- */

  private resetForCall(backend: CallBackend): void {
    this.snap = { ...CallSession.idle(), state: "connecting", backend, muted: this.snap.muted };
    this.igorFinal = "";
    this.igorRowId = null;
    this.larryRowId = null;
    this.toolRowId = null;
    this.probeSent = false;
    this.rearmed = false;
    this.closing = false;
  }

  private finish(reason: string, badly: boolean): void {
    if (this.snap.state === "ended" || this.snap.state === "idle") return;
    this.clearProbe();
    this.closing = true;
    const socket = this.socket;
    this.socket = null;
    if (socket) {
      socket.onopen = null;
      socket.onmessage = null;
      socket.onerror = null;
      socket.onclose = null;
      try {
        socket.close();
      } catch {
        // already gone
      }
    }
    this.promoteIgor();
    this.update({ state: "ended", endedReason: reason, endedBadly: badly });
    void this.deps.audio.stop().catch(() => {});
  }

  private update(patch: Partial<CallSnapshot>): void {
    this.snap = { ...this.snap, ...patch };
    this.emit();
  }

  private emit(): void {
    for (const l of this.listeners) l(this.snap);
  }
}

/** Shape, not instanceof — an ArrayBuffer can come from another realm (RN's socket, Jest's VM). */
function isArrayBuffer(v: unknown): v is ArrayBuffer {
  return (
    typeof v === "object" &&
    v !== null &&
    typeof (v as ArrayBuffer).byteLength === "number" &&
    !ArrayBuffer.isView(v)
  );
}

function joinWords(a: string, b: string): string {
  if (!a) return b;
  if (!b) return a;
  return `${a} ${b}`;
}

function describe(e: unknown): string {
  if (e instanceof Error) return e.message;
  return String(e);
}
