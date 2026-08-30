import {
  DEFAULT_VOICE,
  VOICES,
  hasVoicePick,
  isCallVoice,
  voiceFrameFields,
  voiceLabel,
} from "../lib/callVoices";

describe("the two voices (#98)", () => {
  it("offers Tony and Igor, Tony first and by default", () => {
    expect(VOICES.map((v) => v.id)).toEqual(["tony", "igor"]);
    expect(DEFAULT_VOICE).toBe("tony");
    expect(voiceLabel("tony")).toBe("Tony");
    expect(voiceLabel("igor")).toBe("Igor");
  });

  it("isCallVoice accepts only the two", () => {
    expect(isCallVoice("tony")).toBe(true);
    expect(isCallVoice("igor")).toBe(true);
    expect(isCallVoice("IKne3meq5aSn9XLyUdCD")).toBe(false);
    expect(isCallVoice("")).toBe(false);
    expect(isCallVoice(null)).toBe(false);
  });

  it("only ElevenLabs and the drill have a voice to pick", () => {
    expect(hasVoicePick("eleven")).toBe(true);
    expect(hasVoicePick("drill")).toBe(true);
    expect(hasVoicePick("gemini")).toBe(false);
    expect(hasVoicePick("openai")).toBe(false);
    expect(hasVoicePick(null)).toBe(false);
  });

  it("Tony is the bridge's default; Igor is the clone on v3 conversational", () => {
    expect(voiceFrameFields("eleven", "tony")).toEqual({ voice: "", model: "" });
    expect(voiceFrameFields("eleven", "igor")).toEqual({
      voice: "Nvd5I2HGnOWHNU0ijNEy",
      model: "eleven_v3_conversational",
    });
    expect(voiceFrameFields("drill", "igor").voice).toBe("Nvd5I2HGnOWHNU0ijNEy");
  });

  it("on a backend without a voice pick, nothing rides the frame whatever was picked", () => {
    expect(voiceFrameFields("gemini", "igor")).toEqual({ voice: "", model: "" });
    expect(voiceFrameFields("openai", "igor")).toEqual({ voice: "", model: "" });
  });

  it("the ids have the shape the bridge checks (16–40 of [A-Za-z0-9_-])", () => {
    for (const v of VOICES) {
      if (v.voiceId) expect(v.voiceId).toMatch(/^[A-Za-z0-9_-]{16,40}$/);
    }
  });
});
