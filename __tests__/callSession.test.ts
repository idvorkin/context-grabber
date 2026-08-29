import {
  CallSession,
  MIC_ACK_MS,
  MIC_NOT_REACHING,
  MIC_SILENT,
  ZERO_BUFFERS_BEFORE_REARM,
  type BridgeSocket,
  type CallAudio,
  type CallSnapshot,
} from "../lib/callSession";
import { CONNECTION_LOST, STOPPED } from "../lib/callProtocol";

/** A socket that records what was sent and lets the test play the bridge. */
class FakeSocket implements BridgeSocket {
  binaryType = "blob";
  onopen: ((ev: unknown) => void) | null = null;
  onmessage: ((ev: { data: unknown }) => void) | null = null;
  onerror: ((ev: unknown) => void) | null = null;
  onclose: ((ev: unknown) => void) | null = null;
  sent: (string | ArrayBuffer)[] = [];
  closed = false;
  send(data: string | ArrayBuffer) {
    if (this.closed) throw new Error("closed");
    this.sent.push(data);
  }
  close() {
    this.closed = true;
  }
  // --- the bridge's side ---
  open() {
    this.onopen?.({});
  }
  say(m: Record<string, unknown>) {
    this.onmessage?.({ data: JSON.stringify(m) });
  }
  speak(bytes = 480) {
    this.onmessage?.({ data: new ArrayBuffer(bytes) });
  }
  drop() {
    this.onclose?.({});
  }
  /** Text frames sent, parsed. */
  get frames(): Record<string, unknown>[] {
    return this.sent.filter((s): s is string => typeof s === "string").map((s) => JSON.parse(s));
  }
  get binaryFrames(): ArrayBuffer[] {
    // Not instanceof: a typed array's .buffer comes from another realm under Jest.
    return this.sent.filter((s): s is ArrayBuffer => typeof s !== "string");
  }
}

function fakeAudio() {
  let onBuffer: ((samples: Float32Array, rate: number) => void) | null = null;
  const audio = {
    prepare: jest.fn(async () => {}),
    startMic: jest.fn(async (cb: (samples: Float32Array, rate: number) => void) => {
      onBuffer = cb;
    }),
    restartMic: jest.fn(async () => {}),
    openPlayback: jest.fn(),
    play: jest.fn(),
    flush: jest.fn(),
    stop: jest.fn(async () => {}),
    /** The engine delivering one buffer. */
    mic(samples = 480, rate = 48000) {
      onBuffer?.(new Float32Array(samples), rate);
    },
  };
  return audio as typeof audio & CallAudio;
}

function setup(opts: { connect?: (url: string) => BridgeSocket } = {}) {
  const socket = new FakeSocket();
  const audio = fakeAudio();
  const connect = jest.fn(opts.connect ?? (() => socket));
  let now = 1_000_000;
  const session = new CallSession({ connect, audio, now: () => now }, "wss://h/bridge");
  const states: CallSnapshot[] = [];
  session.subscribe((s) => states.push(s));
  return { socket, audio, connect, session, states, tick: (ms: number) => (now += ms) };
}

/** Settle the async mic start — microtasks only, so this works under fake timers too. */
const flush = async () => {
  for (let i = 0; i < 5; i++) await Promise.resolve();
};

/** Start, open, ready — the point every live-call test begins at. */
async function goLive(t: ReturnType<typeof setup>, backend: "gemini" | "eleven" = "gemini") {
  await t.session.start(backend);
  t.socket.open();
  t.socket.say({ type: "ready", out_rate: 24000, backend, session: "s1" });
  await flush();
}

describe("CallSession — connecting", () => {
  it("prepares audio before it opens the socket, then sends exactly one start frame on open", async () => {
    const t = setup();
    const order: string[] = [];
    t.audio.prepare.mockImplementation(async () => {
      order.push("prepare");
    });
    t.connect.mockImplementation(() => {
      order.push("connect");
      return t.socket;
    });
    await t.session.start("eleven");
    expect(order).toEqual(["prepare", "connect"]);
    expect(t.connect).toHaveBeenCalledWith("wss://h/bridge");
    expect(t.socket.binaryType).toBe("arraybuffer");
    expect(t.session.snapshot.state).toBe("connecting");
    expect(t.socket.sent).toHaveLength(0);
    t.socket.open();
    expect(t.socket.frames).toEqual([
      { type: "start", backend: "eleven", model: "", voice: "", client: "context-grabber", build: "" },
    ]);
  });

  it("introduces itself to the bridge with the build when it has one (#78)", async () => {
    const socket = new FakeSocket();
    const session = new CallSession({ connect: () => socket, audio: fakeAudio(), build: "abc1234" }, "wss://h/bridge");
    await session.start("gemini");
    socket.open();
    expect(socket.frames[0]).toMatchObject({ client: "context-grabber", build: "abc1234" });
  });

  it("does not open the mic before ready", async () => {
    const t = setup();
    await t.session.start("gemini");
    t.socket.open();
    expect(t.audio.startMic).not.toHaveBeenCalled();
    expect(t.audio.openPlayback).not.toHaveBeenCalled();
  });

  it("a second start while connecting or live is a no-op", async () => {
    const t = setup();
    await t.session.start("gemini");
    await t.session.start("eleven");
    expect(t.connect).toHaveBeenCalledTimes(1);
    expect(t.session.snapshot.backend).toBe("gemini");
  });

  it("an audio session that cannot be prepared ends the call before any socket", async () => {
    const t = setup();
    t.audio.prepare.mockRejectedValue(new Error("mic denied"));
    await t.session.start("gemini");
    expect(t.connect).not.toHaveBeenCalled();
    expect(t.session.snapshot).toMatchObject({
      state: "ended",
      endedBadly: true,
      endedReason: "microphone unavailable: mic denied",
    });
  });

  it("a socket that cannot be constructed is a connection lost", async () => {
    const t = setup({
      connect: () => {
        throw new Error("no route");
      },
    });
    await t.session.start("gemini");
    expect(t.session.snapshot.endedReason).toBe(`${CONNECTION_LOST}: no route`);
    expect(t.session.snapshot.endedBadly).toBe(true);
  });

  it("a socket that drops while connecting is a connection lost", async () => {
    const t = setup();
    await t.session.start("gemini");
    t.socket.drop();
    expect(t.session.snapshot).toMatchObject({ state: "ended", endedReason: CONNECTION_LOST, endedBadly: true });
    expect(t.audio.stop).toHaveBeenCalled();
  });
});

describe("CallSession — ready and the microphone", () => {
  it("ready → live: playback at the named rate, stt_start, then the mic", async () => {
    const t = setup();
    await goLive(t, "eleven");
    expect(t.session.snapshot.state).toBe("live");
    expect(t.session.snapshot.startedAt).toBe(1_000_000);
    expect(t.audio.openPlayback).toHaveBeenCalledWith(24000);
    expect(t.socket.frames.at(-1)).toEqual({ type: "stt_start", rate: 16000 });
    expect(t.audio.startMic).toHaveBeenCalledTimes(1);
  });

  it("a mic buffer becomes a 16 kHz PCM16 frame, followed once by a probe", async () => {
    const t = setup();
    await goLive(t);
    t.audio.mic(4800, 48000);
    t.audio.mic(4800, 48000);
    expect(t.socket.binaryFrames).toHaveLength(2);
    expect(t.socket.binaryFrames[0].byteLength).toBe(1600 * 2);
    const probes = t.socket.frames.filter((f) => f.type === "mic_probe");
    expect(probes).toEqual([{ type: "mic_probe", token: 1 }]);
    // The bridge's own order: binary first, then the probe that names it.
    const firstBinary = t.socket.sent.findIndex((s) => s instanceof ArrayBuffer);
    const probeIdx = t.socket.sent.findIndex((s) => typeof s === "string" && s.includes("mic_probe"));
    expect(firstBinary).toBeLessThan(probeIdx);
  });

  it("an unanswered probe re-arms the mic once, then says the mic is not reaching Larry", async () => {
    jest.useFakeTimers();
    try {
      const t = setup();
      await goLive(t);
      t.audio.mic();
      jest.advanceTimersByTime(MIC_ACK_MS);
      expect(t.audio.restartMic).toHaveBeenCalledTimes(1);
      expect(t.session.snapshot.problem).toBeNull();
      // The re-armed graph sends again and probes again…
      t.audio.mic();
      expect(t.socket.frames.filter((f) => f.type === "mic_probe")).toHaveLength(2);
      jest.advanceTimersByTime(MIC_ACK_MS);
      expect(t.audio.restartMic).toHaveBeenCalledTimes(1);
      expect(t.session.snapshot.problem).toBe(MIC_NOT_REACHING);
      // …and a late ack clears it.
      t.socket.say({ type: "mic_ack", token: 2 });
      expect(t.session.snapshot.problem).toBeNull();
    } finally {
      jest.useRealTimers();
    }
  });

  it("an ack for an earlier probe does not vouch for the re-armed mic", async () => {
    jest.useFakeTimers();
    try {
      const t = setup();
      await goLive(t);
      t.audio.mic();
      jest.advanceTimersByTime(MIC_ACK_MS);
      expect(t.audio.restartMic).toHaveBeenCalledTimes(1);
      t.audio.mic(); // probe 2 is now waiting
      t.socket.say({ type: "mic_ack", token: 1 }); // stale
      jest.advanceTimersByTime(MIC_ACK_MS);
      expect(t.session.snapshot.problem).toBe(MIC_NOT_REACHING);
    } finally {
      jest.useRealTimers();
    }
  });

  it("an ack in time means no re-arm", async () => {
    jest.useFakeTimers();
    try {
      const t = setup();
      await goLive(t);
      t.audio.mic();
      t.socket.say({ type: "mic_ack", token: 1 });
      jest.advanceTimersByTime(MIC_ACK_MS * 2);
      expect(t.audio.restartMic).not.toHaveBeenCalled();
      expect(t.session.snapshot.problem).toBeNull();
    } finally {
      jest.useRealTimers();
    }
  });

  it("a mic that fails to start leaves the call live and reports the problem", async () => {
    const t = setup();
    t.audio.startMic.mockRejectedValue(new Error("no input"));
    await goLive(t);
    expect(t.session.snapshot.state).toBe("live");
    expect(t.session.snapshot.problem).toBe("microphone failed: no input");
  });
});

describe("CallSession — a mic that delivers exact zeros (#88)", () => {
  const zeros = (t: ReturnType<typeof setup>, n: number) => {
    for (let i = 0; i < n; i++) t.audio.mic(480, 48000);
  };
  const voice = (t: ReturnType<typeof setup>) => {
    const feed = t.audio.startMic.mock.calls[0][0] as (s: Float32Array, r: number) => void;
    feed(new Float32Array(480).fill(0.2), 48000);
  };

  it("re-arms the mic once after a second of zeros, and says so", async () => {
    const t = setup();
    await goLive(t);
    zeros(t, ZERO_BUFFERS_BEFORE_REARM - 1);
    expect(t.audio.restartMic).not.toHaveBeenCalled();
    zeros(t, 1);
    expect(t.audio.restartMic).toHaveBeenCalledTimes(1);
    expect(t.session.snapshot.problem).toBeNull();
    // the re-armed mic works: no problem, and a note that audio is back
    voice(t);
    expect(t.session.snapshot.problem).toBeNull();
  });

  it("reports silence if zeros continue after the re-arm, and clears when audio returns", async () => {
    const t = setup();
    await goLive(t);
    zeros(t, ZERO_BUFFERS_BEFORE_REARM);
    zeros(t, ZERO_BUFFERS_BEFORE_REARM);
    expect(t.audio.restartMic).toHaveBeenCalledTimes(1);
    expect(t.session.snapshot.problem).toBe(MIC_SILENT);
    voice(t);
    expect(t.session.snapshot.problem).toBeNull();
  });

  it("a quiet room is not zeros: no re-arm", async () => {
    const t = setup();
    await goLive(t);
    const feed = t.audio.startMic.mock.calls[0][0] as (s: Float32Array, r: number) => void;
    for (let i = 0; i < ZERO_BUFFERS_BEFORE_REARM * 2; i++) feed(new Float32Array(480).fill(1e-6), 48000);
    expect(t.audio.restartMic).not.toHaveBeenCalled();
  });

  it("still sends the zero frames meanwhile (the bridge's recording shows the gap honestly)", async () => {
    const t = setup();
    await goLive(t);
    zeros(t, 3);
    expect(t.socket.binaryFrames).toHaveLength(3);
  });
});

describe("CallSession — mute", () => {
  it("muted: nothing leaves the phone, and the bridge is told", async () => {
    const t = setup();
    await goLive(t);
    t.session.setMuted(true);
    t.audio.mic();
    t.audio.mic();
    expect(t.socket.binaryFrames).toHaveLength(0);
    expect(t.socket.frames.at(-1)).toEqual({ type: "mic", muted: true });
    t.session.setMuted(false);
    t.audio.mic();
    expect(t.socket.binaryFrames).toHaveLength(1);
    expect(t.socket.frames.filter((f) => f.type === "mic")).toEqual([
      { type: "mic", muted: true },
      { type: "mic", muted: false },
    ]);
  });

  it("mute is remembered across calls but not re-announced while idle", async () => {
    const t = setup();
    t.session.setMuted(true);
    expect(t.session.snapshot.muted).toBe(true);
    await goLive(t);
    expect(t.socket.frames.filter((f) => f.type === "mic")).toHaveLength(0);
    expect(t.session.snapshot.muted).toBe(true);
  });
});

describe("CallSession — mic level", () => {
  it("reports a level per buffer, muted included, and 0 at the end", async () => {
    const t = setup();
    const levels: number[] = [];
    t.session.subscribeLevel((l) => levels.push(l));
    await goLive(t);
    t.audio.mic(); // silence
    t.session.setMuted(true);
    const loud = new Float32Array(480).fill(0.5);
    // reach the listener the engine would call
    (t.audio.startMic.mock.calls[0][0] as (s: Float32Array, r: number) => void)(loud, 48000);
    t.socket.say({ type: "closed", reason: "stopped" });
    expect(levels[0]).toBe(0);
    expect(levels[1]).toBeGreaterThan(0.8);
    expect(levels.at(-1)).toBe(0);
    // muted: the level was reported, the audio was not sent
    expect(t.socket.binaryFrames).toHaveLength(1);
  });
});

describe("CallSession — playback", () => {
  it("binary frames play while live and are dropped before ready", async () => {
    const t = setup();
    await t.session.start("gemini");
    t.socket.open();
    t.socket.speak();
    expect(t.audio.play).not.toHaveBeenCalled();
    t.socket.say({ type: "ready", out_rate: 24000 });
    t.socket.speak(960);
    expect(t.audio.play).toHaveBeenCalledTimes(1);
    expect((t.audio.play.mock.calls[0][0] as ArrayBuffer).byteLength).toBe(960);
  });

  it("interrupted flushes playback", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "interrupted" });
    expect(t.audio.flush).toHaveBeenCalledTimes(1);
  });
});

describe("CallSession — captions", () => {
  const texts = (t: ReturnType<typeof setup>) =>
    t.session.snapshot.captions.map((c) => `${c.who}${c.pending ? "?" : ""}:${c.text}`);

  it("Igor's words are pending until Larry answers; Larry's fragments join one row", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "stt_partial", text: "hello" });
    expect(texts(t)).toEqual(["igor?:hello"]);
    t.socket.say({ type: "stt_partial", text: "hello lar" });
    t.socket.say({ type: "stt_final", text: "hello Larry" });
    expect(texts(t)).toEqual(["igor?:hello Larry"]);
    t.socket.say({ type: "stt_final", text: "how are you" });
    expect(texts(t)).toEqual(["igor?:hello Larry how are you"]);
    t.socket.say({ type: "transcript", who: "larry", text: "Hi Igor." });
    t.socket.say({ type: "transcript", who: "larry", text: "I'm well." });
    expect(texts(t)).toEqual(["igor:hello Larry how are you", "larry:Hi Igor. I'm well."]);
    t.socket.say({ type: "turn_end" });
    t.socket.say({ type: "transcript", who: "larry", text: "And you?" });
    expect(texts(t)).toEqual([
      "igor:hello Larry how are you",
      "larry:Hi Igor. I'm well.",
      "larry:And you?",
    ]);
  });

  it("the vendor's transcript of Igor replaces the recognizer's; a typed one is ignored", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "stt_final", text: "helo lary" });
    t.socket.say({ type: "transcript", who: "igor", text: "Hello Larry." });
    expect(texts(t)).toEqual(["igor?:Hello Larry."]);
    t.socket.say({ type: "transcript", who: "igor", text: "typed", source: "typed" });
    expect(texts(t)).toEqual(["igor?:Hello Larry."]);
  });

  it("a turn end with nothing said leaves no empty row", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "stt_partial", text: "um" });
    t.socket.say({ type: "stt_partial", text: "" });
    t.socket.say({ type: "turn_end" });
    expect(texts(t)).toEqual([]);
  });

  it("a consult is one row that updates in place", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "tool_call", id: "t1", name: "talk_to_larry", question: "what's next?" });
    expect(texts(t)).toEqual(["tool:asking Larry: what's next? …"]);
    t.socket.say({ type: "consult_progress", stage: "note", text: "reading the plan" });
    expect(texts(t)).toEqual(["tool:reading the plan"]);
    t.socket.say({ type: "tool_result", ok: true, answer: "Ship it.", duration_s: 12 });
    expect(texts(t)).toEqual(["tool:Ship it."]);
    t.socket.say({ type: "transcript", who: "larry", text: "Larry says ship it." });
    expect(texts(t)).toEqual(["tool:Ship it.", "larry:Larry says ship it."]);
  });

  it("injected context and warnings are notes; a bridge error is a problem, not an ending", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "injected", text: "the PR merged" });
    t.socket.say({ type: "warning", message: "Gemini goAway in 60s" });
    t.socket.say({ type: "error", message: "vendor 500" });
    expect(texts(t)).toEqual(["note:Larry added context: the PR merged", "note:Gemini goAway in 60s"]);
    expect(t.session.snapshot).toMatchObject({ state: "live", problem: "vendor 500" });
  });
});

describe("CallSession — endings", () => {
  it("stop sends stt_stop then stop, closes, and ends as stopped", async () => {
    const t = setup();
    await goLive(t);
    t.session.stop();
    expect(t.socket.frames.slice(-2)).toEqual([{ type: "stt_stop" }, { type: "stop" }]);
    expect(t.socket.closed).toBe(true);
    expect(t.session.snapshot).toMatchObject({ state: "ended", endedReason: STOPPED, endedBadly: false });
    expect(t.audio.stop).toHaveBeenCalledTimes(1);
    // The bridge answering our stop with its own closed changes nothing.
    t.socket.say({ type: "closed", reason: "stopped" });
    t.socket.drop();
    expect(t.session.snapshot.endedReason).toBe(STOPPED);
  });

  it("the bridge's closed carries its reason", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "closed", reason: "hangup intent" });
    expect(t.session.snapshot).toMatchObject({ state: "ended", endedReason: "hangup intent", endedBadly: false });
    expect(t.audio.stop).toHaveBeenCalledTimes(1);
  });

  it("a vendor close is a bad ending in the vendor's words", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "vendor_closed", kind: "quota", message: "ElevenLabs quota exceeded" });
    expect(t.session.snapshot).toMatchObject({ endedReason: "ElevenLabs quota exceeded", endedBadly: true });
  });

  it("a dropped socket mid-call is a connection lost", async () => {
    const t = setup();
    await goLive(t);
    t.socket.drop();
    expect(t.session.snapshot).toMatchObject({ endedReason: CONNECTION_LOST, endedBadly: true });
  });

  it("ending promotes Igor's pending words and keeps the captions", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "stt_final", text: "bye Larry" });
    t.socket.say({ type: "closed", reason: "hangup intent" });
    expect(t.session.snapshot.captions).toEqual([{ id: 1, who: "igor", text: "bye Larry", pending: false }]);
  });

  it("a new call after an ending starts clean, on a fresh socket", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "transcript", who: "larry", text: "old" });
    t.socket.say({ type: "closed", reason: "stopped" });
    const second = new FakeSocket();
    t.connect.mockImplementation(() => second);
    await t.session.start("drill");
    expect(t.session.snapshot).toMatchObject({ state: "connecting", backend: "drill", captions: [], endedReason: null });
    second.open();
    expect(second.frames[0]).toMatchObject({ type: "start", backend: "drill" });
  });

  it("mic buffers after the end go nowhere", async () => {
    const t = setup();
    await goLive(t);
    t.session.stop();
    const before = t.socket.sent.length;
    t.audio.mic();
    expect(t.socket.sent).toHaveLength(before);
  });
});
