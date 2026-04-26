import { AudioManager } from "react-native-audio-api";
import { Platform } from "react-native";
import { getAudioContext } from "./audioContext";

type AudioBufferSourceNode = ReturnType<
  InstanceType<typeof import("react-native-audio-api").AudioContext>["createBufferSource"]
>;

let bufferSource: AudioBufferSourceNode | null = null;
let active = false;
let sessionConfigured = false;

/**
 * Configure the iOS audio session for `playback` so the app is eligible to
 * keep running in the background under `UIBackgroundModes: audio`. Idempotent.
 * Safe to call before any AudioContext is created — applies session-wide.
 */
export function configureAudioSessionForBackground(): void {
  if (sessionConfigured) return;
  sessionConfigured = true;
  if (Platform.OS !== "ios") return;
  try {
    // No `mixWithOthers` — pure `playback` is the most reliably-backgrounded
    // category. We accept that starting a workout interrupts other audio.
    AudioManager.setAudioSessionOptions({
      iosCategory: "playback",
    });
  } catch {
    // simulator / unsupported — silent fallback.
  }
}

/**
 * Start a continuously-playing very-low-amplitude audio buffer to keep iOS
 * believing the app is actively producing audio. With the playback session
 * active and the `audio` UIBackgroundMode entry in Info.plist, this keeps
 * the JS thread alive while the app is backgrounded so timer ticks (and
 * Live Activity updates) keep firing.
 *
 * Why a buffer instead of an oscillator: low-frequency oscillators below the
 * speaker's reproduction range can be treated as effective silence by iOS's
 * "is the app actually outputting audio" heuristic. A buffer of low-level
 * white noise pumps real samples at the configured sample rate, which iOS
 * unambiguously sees as live audio output.
 *
 * Idempotent — repeat calls while active are a no-op.
 */
export async function startTimerKeepalive(): Promise<void> {
  if (active) return;
  active = true;

  configureAudioSessionForBackground();

  if (Platform.OS === "ios") {
    try {
      await AudioManager.setAudioSessionActivity(true);
    } catch {
      // simulator / unsupported — silent fallback.
    }
  }

  try {
    const ctx = getAudioContext();

    // 1 second of very low-amplitude white noise. Amplitude 0.0005 is
    // ~-66dB relative to full-scale: detectable by iOS as live output but
    // imperceptible in any normal listening environment.
    const seconds = 1;
    const sampleRate = ctx.sampleRate;
    const buffer = ctx.createBuffer(1, sampleRate * seconds, sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < data.length; i++) {
      data[i] = (Math.random() - 0.5) * 0.001;
    }

    bufferSource = ctx.createBufferSource();
    bufferSource.buffer = buffer;
    bufferSource.loop = true;
    bufferSource.connect(ctx.destination);
    bufferSource.start();
  } catch {
    // No audio backend available; silent fallback.
  }
}

export function stopTimerKeepalive(): void {
  if (!active) return;
  active = false;
  try {
    if (bufferSource) {
      bufferSource.stop();
      bufferSource.disconnect();
    }
  } catch {
    // ignore teardown errors
  }
  bufferSource = null;

  if (Platform.OS === "ios") {
    try {
      void AudioManager.setAudioSessionActivity(false);
    } catch {
      // ignore
    }
  }
}

export function isKeepaliveActive(): boolean {
  return active;
}
