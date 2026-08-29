/**
 * PCM plumbing for the native Larry call.
 *
 * The voice bridge speaks raw PCM16 little-endian mono: 16 kHz up (the mic),
 * and whatever rate its `ready` frame names down (24 kHz for Gemini and
 * OpenAI, 16 kHz for ElevenLabs). The audio engine on the phone works in
 * Float32 at whatever rate the hardware prefers, so every frame crosses this
 * file once in each direction.
 *
 * The resampler is linear interpolation — the same shape as the page's
 * `downsampleTo16k` and the bridge's `resample_pcm16`, which means a native
 * call and a page call sound the same to Deepgram and to the vendor.
 */

/** The only mic rate the bridge accepts. */
export const BRIDGE_IN_RATE = 16000;

/** Linear-interpolation resample. Returns the input untouched when the rates match. */
export function resampleLinear(
  input: Float32Array,
  fromRate: number,
  toRate: number,
): Float32Array {
  if (fromRate === toRate || input.length === 0) return input;
  const outLength = Math.max(1, Math.round((input.length * toRate) / fromRate));
  const out = new Float32Array(outLength);
  const step = fromRate / toRate;
  const last = input.length - 1;
  for (let i = 0; i < outLength; i++) {
    const pos = i * step;
    const i0 = Math.min(Math.floor(pos), last);
    const i1 = Math.min(i0 + 1, last);
    const t = pos - i0;
    out[i] = input[i0] + (input[i1] - input[i0]) * t;
  }
  return out;
}

/** Float32 [-1, 1] → Int16, clipped. */
export function floatToPcm16(input: Float32Array): Int16Array {
  const out = new Int16Array(input.length);
  for (let i = 0; i < input.length; i++) {
    const s = Math.max(-1, Math.min(1, input[i]));
    out[i] = s < 0 ? Math.round(s * 0x8000) : Math.round(s * 0x7fff);
  }
  return out;
}

/** Int16 little-endian bytes → Float32 [-1, 1]. A trailing odd byte is ignored. */
export function pcm16ToFloat(data: ArrayBuffer): Float32Array {
  const view = new DataView(data);
  const count = Math.floor(data.byteLength / 2);
  const out = new Float32Array(count);
  for (let i = 0; i < count; i++) {
    const v = view.getInt16(i * 2, true);
    out[i] = v < 0 ? v / 0x8000 : v / 0x7fff;
  }
  return out;
}

/** True when every sample is exactly zero — a dead capture graph, never a quiet room. */
export function isExactSilence(samples: Float32Array): boolean {
  for (let i = 0; i < samples.length; i++) if (samples[i] !== 0) return false;
  return samples.length > 0;
}

/** Quietest level the strip still shows; below this it sits at zero. */
const LEVEL_FLOOR_DB = -50;

/**
 * How loud a mic buffer is, 0..1, on a decibel scale so speech at a normal
 * distance sits mid-strip rather than pinned near zero the way linear peak
 * would put it. -50 dBFS → 0, 0 dBFS → 1.
 */
export function micLevel(samples: Float32Array): number {
  let peak = 0;
  for (let i = 0; i < samples.length; i++) {
    const a = Math.abs(samples[i]);
    if (a > peak) peak = a;
  }
  if (peak <= 0) return 0;
  const db = 20 * Math.log10(Math.min(1, peak));
  return Math.max(0, Math.min(1, 1 - db / LEVEL_FLOOR_DB));
}

/**
 * One mic buffer from the engine → one binary frame for the bridge:
 * resampled to 16 kHz and packed as Int16 LE.
 */
export function encodeMicFrame(samples: Float32Array, sampleRate: number): ArrayBuffer {
  const pcm = floatToPcm16(resampleLinear(samples, sampleRate, BRIDGE_IN_RATE));
  // A fresh Int16Array owns its whole buffer, so this is exactly the frame.
  return pcm.buffer as ArrayBuffer;
}
