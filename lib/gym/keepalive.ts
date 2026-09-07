import { AudioManager } from "react-native-audio-api";
import { Platform } from "react-native";
import { getAudioContext } from "./audioContext";
import { DuckWindow, type DuckSession } from "./duck";
import { timerLog } from "./timerLog";

type AudioBufferSourceNode = ReturnType<
  InstanceType<typeof import("react-native-audio-api").AudioContext>["createBufferSource"]
>;

let bufferSource: AudioBufferSourceNode | null = null;
let active = false;
let sessionConfigured = false;

/** Music and podcasts play on, untouched, while the timer runs. */
const BASE_OPTIONS = ["mixWithOthers"] as const;
/** Around a cue: music turned down, spoken audio paused (and resumed when the window lets go). */
const DUCK_OPTIONS = ["mixWithOthers", "duckOthers", "interruptSpokenAudioAndMixWithOthers"] as const;

function applySessionOptions(ducking: boolean): void {
  if (Platform.OS !== "ios") return;
  const options = [...(ducking ? DUCK_OPTIONS : BASE_OPTIONS)];
  try {
    AudioManager.setAudioSessionOptions({
      iosCategory: "playback",
      iosOptions: options,
    });
    timerLog.add(`session options: playback [${options.join(", ")}]`);
  } catch (e) {
    // simulator / unsupported — silent fallback.
    timerLog.add(`session options FAILED: ${e instanceof Error ? e.message : String(e)}`);
  }
}

/**
 * Configure the iOS audio session for `playback` so the app is eligible to
 * keep running in the background under `UIBackgroundModes: audio`. Mixed
 * with others: a workout no longer pauses the music (spec: audio ducking,
 * 2026-09-07). Idempotent. Safe to call before any AudioContext is created —
 * applies session-wide.
 */
export function configureAudioSessionForBackground(): void {
  if (sessionConfigured) return;
  sessionConfigured = true;
  applySessionOptions(false);
}

/**
 * The timer's side of the duck window (lib/gym/duck.ts): the options on the
 * live session, and — because a paused podcast resumes only when the session
 * that paused it lets go — a deactivate-and-reactivate with the keepalive
 * loop restarted after it. Nothing to let go of when the keepalive is not
 * running: the final deactivation in `stopTimerKeepalive` carries the flag.
 */
const timerDuckSession: DuckSession = {
  setDucking: applySessionOptions,
  async release() {
    if (!active) {
      timerLog.add("release: keepalive not running, nothing to let go of");
      return;
    }
    stopTimerKeepalive();
    await startTimerKeepalive();
  },
};

/** Hold it open around each cue; it closes itself a moment after the last one. */
export const duckWindow = new DuckWindow(timerDuckSession, (m) => timerLog.add(m));

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
      timerLog.add("session active");
    } catch (e) {
      // simulator / unsupported — silent fallback.
      timerLog.add(`session activate FAILED: ${e instanceof Error ? e.message : String(e)}`);
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
    timerLog.add("keepalive loop started");
  } catch (e) {
    // No audio backend available; silent fallback.
    timerLog.add(`keepalive loop FAILED: ${e instanceof Error ? e.message : String(e)}`);
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
  timerLog.add("keepalive loop stopped");

  if (Platform.OS === "ios") {
    try {
      void AudioManager.setAudioSessionActivity(false)
        .then(() => timerLog.add("session inactive (others told they may resume)"))
        .catch((e: unknown) => timerLog.add(`session deactivate FAILED: ${e instanceof Error ? e.message : String(e)}`));
    } catch {
      // ignore
    }
  }
}

export function isKeepaliveActive(): boolean {
  return active;
}
