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
  diagnosticsFrame,
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
import { encodeMicFrame, isExactSilence, micLevel } from "./pcm";
import { DEFAULT_VOICE, voiceFrameFields, voiceLabel, type CallVoice } from "./callVoices";
import { NO_LOG, type CallLog } from "./callLog";

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
  /** The voice the call was placed in — Tony or Igor (#98). */
  voice: CallVoice;
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
  /** Where the call narrates itself. The Diagnostics fold reads it. */
  log?: Pick<CallLog, "add"> & Partial<Pick<CallLog, "reset" | "all">>;
  /** The build, for the bridge's records (#78). */
  build?: string;
};

/**
 * Mic buffers that are exactly zero before the mic is re-armed. A dead
 * capture graph is zero to the sample; a quiet room never is (#88). Ten
 * buffers ≈ one second.
 */
export const ZERO_BUFFERS_BEFORE_REARM = 10;

export const MIC_SILENT = "the microphone is delivering silence";

/** How long the priming mic stays open. */
export const PRIME_MS = 400;

/**
 * A recorder that starts and never delivers (#88: the bridge saw no frames
 * at all on silent calls). Three seconds without a buffer → reset the
 * audio; still nothing → redial once.
 */
export const FIRST_FRAME_MS = 3000;

/** Log a frame-count line this often. */
const FRAME_LOG_EVERY = 50;

/** How long the bridge gets to acknowledge the first mic frame. Mirrors the page. */
export const MIC_ACK_MS = 5000;

export const MIC_NOT_REACHING = "the microphone is not reaching Larry";

type Listener = (snapshot: CallSnapshot) => void;
type LevelListener = (level: number) => void;

export class CallSession {
  private readonly deps: Required<Omit<CallSessionDeps, "log" | "build">> & Pick<CallSessionDeps, "log" | "build">;
  private framesSent = 0;
  private framesPlayed = 0;
  private zeroRun = 0;
  private zeroRearmed = false;
  private firstFrameTimer: ReturnType<typeof setTimeout> | null = null;
  private audioReset = false;
  /** One automatic redial per burst; cleared by a call that delivers audio. */
  private redialed = false;
  private micBuffers = 0;
  private readonly url: string;
  private listeners = new Set<Listener>();
  /** The mic level rides its own channel: ten updates a second must not re-render the captions. */
  private levelListeners = new Set<LevelListener>();
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

  private log(line: string): void {
    (this.deps.log ?? NO_LOG).add(line);
  }

  /** The dump to the bridge, over the call's own socket, before anything closes (#92). */
  private sendDiagnostics(why: string): void {
    const lines = this.deps.log?.all;
    if (!lines || !this.socket) return;
    this.log(`diagnostics → bridge (${why})`);
    this.safeSend(diagnosticsFrame(this.deps.build ?? "", lines.join("\n")));
  }

  static idle(): CallSnapshot {
    return {
      state: "idle",
      backend: null,
      voice: DEFAULT_VOICE,
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

  /** 0..1 per mic buffer while the mic is open — muted included; 0 once when it closes. */
  subscribeLevel(listener: LevelListener): () => void {
    this.levelListeners.add(listener);
    return () => {
      this.levelListeners.delete(listener);
    };
  }

  /* ---------- controls ---------- */

  /** A line from the screen into the call's log (context the session cannot see). */
  note(line: string): void {
    this.log(line);
  }

  /**
   * The experiment for #88: bring the audio up and down once without
   * dialling — session on, mic open to nowhere for a beat, everything off.
   * Only between calls.
   */
  async prime(): Promise<void> {
    if (this.snap.state === "connecting" || this.snap.state === "live") {
      this.log("prime ignored: a call is up");
      return;
    }
    this.log("prime: session up");
    let buffers = 0;
    let firstNonZero = -1;
    try {
      await this.deps.audio.prepare();
      this.log("prime: mic open");
      await this.deps.audio.startMic((samples) => {
        buffers += 1;
        if (firstNonZero < 0 && !isExactSilence(samples)) firstNonZero = buffers;
      });
      await new Promise((r) => setTimeout(r, PRIME_MS));
      this.log(
        `prime: mic closed, session down — ${buffers} buffers, ${
          firstNonZero < 0 ? "none non-zero" : `first non-zero at #${firstNonZero}`
        }`,
      );
    } catch (e) {
      this.log(`prime FAILED: ${describe(e)}`);
    } finally {
      await this.deps.audio.stop().catch(() => {});
    }
  }

  /**
   * No-op while a call is connecting or live: the link that finds a live
   * call joins it. `voice` only reaches the frame on a backend whose voice
   * is an ElevenLabs one; elsewhere the vendor's default rides it.
   */
  async start(backend: CallBackend, voice: CallVoice = DEFAULT_VOICE): Promise<void> {
    if (this.snap.state === "connecting" || this.snap.state === "live") {
      this.log(`start(${backend}) ignored: already ${this.snap.state}`);
      return;
    }
    this.resetForCall(backend, voice);
    this.deps.log?.reset?.();
    const fields = voiceFrameFields(backend, voice);
    this.log(
      `start backend=${backend} voice=${voiceLabel(voice)}${fields.voice ? ` (${fields.voice}, ${fields.model || "default model"})` : ""} build=${this.deps.build ?? "?"} bridge=${this.url}`,
    );
    this.emit();
    try {
      await this.deps.audio.prepare();
      this.log("audio prepared (permission, session)");
    } catch (e) {
      this.log(`audio prepare FAILED: ${describe(e)}`);
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
    socket.onopen = () => {
      this.log("socket open → start frame");
      this.safeSend(startFrame(backend, this.deps.build ?? "", fields.voice, fields.model));
    };
    socket.onmessage = (ev: { data: unknown }) => this.onSocketData(ev.data);
    socket.onerror = () => this.onSocketGone();
    socket.onclose = () => this.onSocketGone();
  }

  /** Hang up. The bridge is told first — `stt_stop` flushes Deepgram's tail, then `stop`. */
  stop(): void {
    if (this.snap.state !== "connecting" && this.snap.state !== "live") return;
    this.log("hang up");
    if (this.socket) {
      this.sendDiagnostics("hang up");
      this.safeSend(sttStopFrame());
      this.safeSend(stopFrame());
    }
    this.finish(STOPPED, false);
  }

  /**
   * Restart (#93): hang up and dial again on the same backend, one tap.
   * The same path the no-frames self-heal takes; the ended call's
   * diagnostics go to the bridge and stay in the log.
   */
  restart(): void {
    if (this.snap.state !== "connecting" && this.snap.state !== "live") return;
    const { backend, voice } = this.snap;
    this.log("restart: hang up + redial");
    this.stop();
    if (backend) void this.start(backend, voice);
  }

  setMuted(muted: boolean): void {
    if (this.snap.muted === muted) return;
    this.log(muted ? "muted" : "unmuted");
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
      if (this.snap.state === "live") {
        this.deps.audio.play(data);
        this.framesPlayed += 1;
        if (this.framesPlayed === 1) this.log(`first audio from Larry: ${data.byteLength} bytes`);
        else if (this.framesPlayed % FRAME_LOG_EVERY === 0) this.log(`${this.framesPlayed} frames played`);
      }
      return;
    }
    // A Blob from a socket that ignored binaryType. Not ours to guess.
  }

  private onSocketGone(): void {
    if (this.closing) return;
    if (this.snap.state === "connecting" || this.snap.state === "live") {
      this.log("socket closed by the far end / network");
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
        // Only the probe that is actually waiting. A late ack for an earlier
        // probe, arriving after a re-arm, must not vouch for the new graph.
        this.log(`mic_ack token=${m.token}${m.token === this.probeToken ? "" : " (stale, ignored)"}`);
        if (m.token === this.probeToken) this.clearProbe();
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
        this.log("interrupted (barge-in) → playback flushed");
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
        this.addRow("note", `added context: ${m.text}`);
        return;
      case "warning":
        this.log(`bridge warning: ${m.message}`);
        this.larryRowId = null;
        this.addRow("note", `warning: ${m.message}`);
        return;
      case "error":
        this.log(`bridge error: ${m.message}`);
        this.update({ problem: m.message });
        return;
      case "vendor_closed":
        this.log(`vendor closed: kind=${m.kind} ${m.message}`);
        this.finish(m.message || (m.kind === "quota" ? "vendor quota exhausted" : "vendor hung up"), true);
        return;
      case "closed":
        this.log(`bridge closed: reason=${JSON.stringify(m.reason)}`);
        this.finish(m.reason, false);
        return;
    }
  }

  private onReady(outRate: number): void {
    if (this.snap.state !== "connecting") return;
    this.log(`ready: out_rate=${outRate} → live; playback open, stt_start, mic opening`);
    this.update({ state: "live", startedAt: this.deps.now() });
    this.deps.audio.openPlayback(outRate);
    this.safeSend(sttStartFrame());
    void this.deps.audio
      .startMic(this.onMicBuffer)
      .then(() => this.armFirstFrameWatch())
      .catch((e) => {
        // The call goes on — Larry can still be heard — but say so.
        this.log(`mic FAILED to open: ${describe(e)}`);
        this.update({ problem: `microphone failed: ${describe(e)}` });
      });
  }

  private armFirstFrameWatch(): void {
    if (this.snap.state !== "live") return;
    if (this.firstFrameTimer) clearTimeout(this.firstFrameTimer);
    this.firstFrameTimer = setTimeout(() => this.onNoFirstFrame(), FIRST_FRAME_MS);
  }

  private onNoFirstFrame(): void {
    this.firstFrameTimer = null;
    if (this.snap.state !== "live" || this.micBuffers > 0) return;
    if (!this.audioReset) {
      this.audioReset = true;
      this.log(`no mic buffer within ${FIRST_FRAME_MS / 1000}s of recorder start (0 frames sent) → resetting audio`);
      void this.deps.audio
        .restartMic()
        .then(() => this.armFirstFrameWatch())
        .catch((e) => this.log(`audio reset FAILED: ${describe(e)}`));
      return;
    }
    if (!this.redialed) {
      this.redialed = true;
      const { backend, voice } = this.snap;
      this.log("still no mic buffer after reset → redialing once");
      this.sendDiagnostics("redial");
      this.stop();
      if (backend) void this.start(backend, voice);
      return;
    }
    this.log("still no mic buffer after redial — giving up on self-heal");
    this.update({ problem: MIC_SILENT });
  }

  private onMicBuffer = (samples: Float32Array, sampleRate: number): void => {
    if (this.snap.state !== "live") return;
    this.micBuffers += 1;
    if (this.micBuffers === 1) {
      if (this.firstFrameTimer) clearTimeout(this.firstFrameTimer);
      this.firstFrameTimer = null;
      this.redialed = false; // this burst delivered; the next dead call may redial again
    }
    // Heard even while muted: "is my mic working" and "am I muted" are
    // different questions, and the strip answers both.
    this.emitLevel(micLevel(samples));
    this.watchForZeros(samples);
    if (this.snap.muted) return;
    this.safeSend(encodeMicFrame(samples, sampleRate));
    this.framesSent += 1;
    if (this.framesSent === 1) {
      this.log(`first mic frame: ${samples.length} samples @ ${sampleRate} Hz → 16 kHz PCM16`);
    } else if (this.framesSent % FRAME_LOG_EVERY === 0) {
      this.log(`${this.framesSent} mic frames sent`);
    }
    if (!this.probeSent) {
      this.probeSent = true;
      this.probeToken += 1;
      this.log(`mic_probe token=${this.probeToken} (ack expected within ${MIC_ACK_MS / 1000}s)`);
      this.safeSend(micProbeFrame(this.probeToken));
      this.probeTimer = setTimeout(() => this.onProbeMissed(), MIC_ACK_MS);
    }
  };

  /**
   * The first call after launch used to send exact silence for its whole
   * length (#88): the mic was armed before iOS had the input route up. If
   * the first second is zero to the sample, close and reopen the mic once;
   * if it is still zero after that, say so.
   */
  private watchForZeros(samples: Float32Array): void {
    if (!isExactSilence(samples)) {
      if (this.zeroRun >= ZERO_BUFFERS_BEFORE_REARM) this.log("mic audio present again");
      this.zeroRun = 0;
      if (this.snap.problem === MIC_SILENT) this.update({ problem: null });
      return;
    }
    this.zeroRun += 1;
    if (this.zeroRun !== ZERO_BUFFERS_BEFORE_REARM) return;
    if (!this.zeroRearmed) {
      this.zeroRearmed = true;
      this.zeroRun = 0;
      this.log(`mic delivering zeros (${ZERO_BUFFERS_BEFORE_REARM} buffers) → re-arming the mic once`);
      void this.deps.audio.restartMic().catch((e) => {
        this.log(`re-arm after zeros FAILED: ${describe(e)}`);
        this.update({ problem: `microphone failed: ${describe(e)}` });
      });
      return;
    }
    this.log("mic still delivering zeros after re-arm");
    this.update({ problem: MIC_SILENT });
  }

  private onProbeMissed(): void {
    this.probeTimer = null;
    if (this.snap.state !== "live") return;
    this.log(
      `mic_ack missed (${this.framesSent} frames sent, ${this.micBuffers} buffers) → ${
        this.rearmed ? "mic is not reaching Larry" : "re-arming the mic once"
      }`,
    );
    if (this.rearmed) this.sendDiagnostics("mic_ack timeout");
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

  private resetForCall(backend: CallBackend, voice: CallVoice): void {
    this.snap = { ...CallSession.idle(), state: "connecting", backend, voice, muted: this.snap.muted };
    this.igorFinal = "";
    this.igorRowId = null;
    this.larryRowId = null;
    this.toolRowId = null;
    this.probeSent = false;
    this.rearmed = false;
    this.closing = false;
    this.framesSent = 0;
    this.framesPlayed = 0;
    this.zeroRun = 0;
    this.zeroRearmed = false;
    this.micBuffers = 0;
    this.audioReset = false;
    if (this.firstFrameTimer) clearTimeout(this.firstFrameTimer);
    this.firstFrameTimer = null;
  }

  private finish(reason: string, badly: boolean): void {
    if (this.snap.state === "ended" || this.snap.state === "idle") return;
    this.log(`ended${badly ? " BADLY" : ""}: ${reason} (${this.framesSent} mic frames sent, ${this.framesPlayed} played)`);
    this.clearProbe();
    if (this.firstFrameTimer) clearTimeout(this.firstFrameTimer);
    this.firstFrameTimer = null;
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
    this.emitLevel(0);
  }

  private emitLevel(level: number): void {
    for (const l of this.levelListeners) l(level);
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
