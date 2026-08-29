import {
  BRIDGE_IN_RATE,
  encodeMicFrame,
  floatToPcm16,
  pcm16ToFloat,
  resampleLinear,
} from "../lib/pcm";

describe("floatToPcm16", () => {
  it("maps full scale and clips beyond it", () => {
    const out = floatToPcm16(new Float32Array([0, 1, -1, 2, -2, 0.5]));
    expect(Array.from(out)).toEqual([0, 32767, -32768, 32767, -32768, 16384]);
  });
});

describe("pcm16ToFloat", () => {
  it("reads little-endian Int16 back to [-1, 1]", () => {
    const bytes = new Int16Array([0, 32767, -32768, 16384]).buffer;
    const out = pcm16ToFloat(bytes);
    expect(out[0]).toBe(0);
    expect(out[1]).toBeCloseTo(1, 6);
    expect(out[2]).toBe(-1);
    expect(out[3]).toBeCloseTo(0.5, 3);
  });

  it("ignores a trailing odd byte rather than throwing", () => {
    const buf = new ArrayBuffer(5);
    new DataView(buf).setInt16(0, 1000, true);
    expect(pcm16ToFloat(buf)).toHaveLength(2);
  });

  it("round-trips through floatToPcm16 within one LSB", () => {
    const src = new Float32Array(100).map((_, i) => Math.sin(i / 7));
    const back = pcm16ToFloat(floatToPcm16(src).buffer as ArrayBuffer);
    for (let i = 0; i < src.length; i++) expect(back[i]).toBeCloseTo(src[i], 4);
  });
});

describe("resampleLinear", () => {
  it("returns the input untouched when the rates match", () => {
    const src = new Float32Array([1, 2, 3]);
    expect(resampleLinear(src, 16000, 16000)).toBe(src);
  });

  it("48 k → 16 k keeps one sample in three", () => {
    const src = new Float32Array(4800).map((_, i) => i);
    const out = resampleLinear(src, 48000, 16000);
    expect(out).toHaveLength(1600);
    expect(out[0]).toBe(0);
    expect(out[1]).toBe(3);
    expect(out[1599]).toBe(4797);
  });

  it("interpolates between neighbours on a non-integer ratio", () => {
    const src = new Float32Array([0, 1, 2, 3]);
    const out = resampleLinear(src, 4, 8);
    expect(out).toHaveLength(8);
    expect(out[1]).toBeCloseTo(0.5);
    expect(out[3]).toBeCloseTo(1.5);
  });

  it("a 44.1 k sine resampled to 16 k is still a sine of the same frequency", () => {
    const from = 44100;
    const hz = 440;
    const src = new Float32Array(from).map((_, i) => Math.sin((2 * Math.PI * hz * i) / from));
    const out = resampleLinear(src, from, 16000);
    expect(out).toHaveLength(16000);
    for (let i = 0; i < 16000; i += 97) {
      expect(out[i]).toBeCloseTo(Math.sin((2 * Math.PI * hz * i) / 16000), 1);
    }
  });
});

describe("encodeMicFrame", () => {
  it("produces 2 bytes per 16 kHz sample from a 48 kHz buffer", () => {
    const frame = encodeMicFrame(new Float32Array(4800), 48000);
    expect(frame.byteLength).toBe(1600 * 2);
  });

  it("passes a 16 kHz buffer through unchanged in length", () => {
    const frame = encodeMicFrame(new Float32Array(320), BRIDGE_IN_RATE);
    expect(frame.byteLength).toBe(640);
  });
});
