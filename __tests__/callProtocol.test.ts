import {
  BACKENDS,
  CONNECTION_LOST,
  DEFAULT_BACKEND,
  bridgeUrl,
  endingText,
  isCallBackend,
  micFrame,
  micProbeFrame,
  parseBridgeMessage,
  startFrame,
  stopFrame,
  sttStartFrame,
  sttStopFrame,
} from "../lib/callProtocol";

describe("bridgeUrl", () => {
  it("mounts at /bridge over https (Tailscale Serve)", () => {
    expect(bridgeUrl("https://c-5004.squeaker-teeth.ts.net")).toBe(
      "wss://c-5004.squeaker-teeth.ts.net/bridge",
    );
  });

  it("is its own port on plain http", () => {
    expect(bridgeUrl("http://c-5004:8778")).toBe("ws://c-5004:8780");
  });
});

describe("backends", () => {
  it("offers the four the page offers, ElevenLabs first", () => {
    expect(BACKENDS.map((b) => b.id)).toEqual(["eleven", "gemini", "openai", "drill"]);
  });

  it("defaults to ElevenLabs — Tony's voice", () => {
    expect(DEFAULT_BACKEND).toBe("eleven");
  });

  it("isCallBackend rejects anything else", () => {
    expect(isCallBackend("eleven")).toBe(true);
    expect(isCallBackend("siri")).toBe(false);
    expect(isCallBackend(null)).toBe(false);
  });
});

describe("outbound frames", () => {
  it("start names the backend, leaves model/voice to the vendor, and says who is calling", () => {
    expect(JSON.parse(startFrame("eleven", "abc1234"))).toEqual({
      type: "start",
      backend: "eleven",
      model: "",
      voice: "",
      client: "context-grabber",
      build: "abc1234",
    });
    expect(JSON.parse(startFrame("gemini"))).toMatchObject({ client: "context-grabber", build: "" });
  });

  it("the rest match the bridge docstring", () => {
    expect(JSON.parse(sttStartFrame())).toEqual({ type: "stt_start", rate: 16000 });
    expect(JSON.parse(sttStopFrame())).toEqual({ type: "stt_stop" });
    expect(JSON.parse(stopFrame())).toEqual({ type: "stop" });
    expect(JSON.parse(micFrame(true))).toEqual({ type: "mic", muted: true });
    expect(JSON.parse(micProbeFrame(3))).toEqual({ type: "mic_probe", token: 3 });
  });
});

describe("parseBridgeMessage", () => {
  const parse = (m: unknown) => parseBridgeMessage(JSON.stringify(m));

  it("junk is null: not a string, not JSON, not an object, no type", () => {
    expect(parseBridgeMessage(undefined)).toBeNull();
    expect(parseBridgeMessage("")).toBeNull();
    expect(parseBridgeMessage("{nope")).toBeNull();
    expect(parseBridgeMessage("[1]")).toBeNull();
    expect(parse({ text: "hi" })).toBeNull();
  });

  it("events the screen does not render are null, not errors", () => {
    expect(parse({ type: "turn_metrics", user_ms: 12 })).toBeNull();
    expect(parse({ type: "stt_ready" })).toBeNull();
    expect(parse({ type: "sessions", sessions: [] })).toBeNull();
  });

  it("ready carries the output rate, defaulting to 24 k for an old bridge", () => {
    expect(
      parse({ type: "ready", out_rate: 16000, backend: "eleven", session: "abc", tools: [] }),
    ).toEqual({ type: "ready", outRate: 16000, backend: "eleven", session: "abc" });
    expect(parse({ type: "ready" })).toEqual({ type: "ready", outRate: 24000, backend: "", session: "" });
  });

  it("transcript keeps who, text and source", () => {
    expect(parse({ type: "transcript", who: "larry", text: "Hello." })).toEqual({
      type: "transcript",
      who: "larry",
      text: "Hello.",
      source: null,
    });
    expect(parse({ type: "transcript", who: "igor", text: "hi", source: "typed" })).toMatchObject({
      source: "typed",
    });
  });

  it("captions, control and endings", () => {
    expect(parse({ type: "stt_partial", text: "hel" })).toEqual({ type: "stt_partial", text: "hel" });
    expect(parse({ type: "stt_final", text: "hello", speech_final: true })).toEqual({
      type: "stt_final",
      text: "hello",
    });
    expect(parse({ type: "mic_ack", token: "4", frames: 1 })).toEqual({ type: "mic_ack", token: 4 });
    expect(parse({ type: "interrupted" })).toEqual({ type: "interrupted" });
    expect(parse({ type: "turn_end" })).toEqual({ type: "turn_end" });
    expect(parse({ type: "tool_call", id: "t1", name: "talk_to_larry", question: "why?" })).toEqual({
      type: "tool_call",
      question: "why?",
    });
    expect(parse({ type: "tool_result", ok: true, answer: "because", duration_s: 3 })).toEqual({
      type: "tool_result",
      ok: true,
      answer: "because",
    });
    expect(parse({ type: "consult_progress", stage: "note", text: "reading…" })).toEqual({
      type: "consult_progress",
      stage: "note",
      text: "reading…",
    });
    expect(parse({ type: "injected", text: "fact" })).toEqual({ type: "injected", text: "fact" });
    expect(parse({ type: "warning", message: "goAway" })).toEqual({ type: "warning", message: "goAway" });
    expect(parse({ type: "error", message: "boom" })).toEqual({ type: "error", message: "boom" });
    expect(parse({ type: "vendor_closed", kind: "quota", message: "out", help: "…" })).toEqual({
      type: "vendor_closed",
      kind: "quota",
      message: "out",
    });
    expect(parse({ type: "closed", reason: "hangup intent" })).toEqual({
      type: "closed",
      reason: "hangup intent",
    });
  });
});

describe("endingText", () => {
  it("mirrors the page's wording", () => {
    expect(endingText("idle timeout")).toBe("idle 2 min");
    expect(endingText("hangup intent")).toBe("hang-up intent");
    expect(endingText("stopped")).toBe("stopped");
    expect(endingText("Larry hung up")).toBe("Larry hung up");
    expect(endingText("vendor max duration")).toBe("vendor max duration");
    expect(endingText(CONNECTION_LOST)).toBe("connection lost");
  });

  it("an empty reason is a plain ending; an unknown one is printed verbatim", () => {
    expect(endingText("")).toBe("session ended");
    expect(endingText(null)).toBe("session ended");
    expect(endingText("Gemini Live ended the session: 1011")).toBe(
      "Gemini Live ended the session: 1011",
    );
  });
});
