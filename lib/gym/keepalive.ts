import { AudioManager } from "react-native-audio-api";
import { Platform } from "react-native";
import { getAudioContext } from "./audioContext";

type Osc = ReturnType<InstanceType<typeof import("react-native-audio-api").AudioContext>["createOscillator"]>;
type Gain = ReturnType<InstanceType<typeof import("react-native-audio-api").AudioContext>["createGain"]>;

let silentOsc: Osc | null = null;
let silentGain: Gain | null = null;
let active = false;

/**
 * Starts a silent continuous oscillator and configures the iOS audio session
 * for `playback` category with the session active. Combined with the `audio`
 * UIBackgroundMode entry in Info.plist, this keeps the JS thread alive while
 * the app is backgrounded so timer ticks (and Live Activity updates) keep
 * firing.
 *
 * Idempotent — repeat calls while active are a no-op.
 */
export async function startTimerKeepalive(): Promise<void> {
  if (active) return;
  active = true;

  if (Platform.OS === "ios") {
    try {
      AudioManager.setAudioSessionOptions({
        iosCategory: "playback",
        iosOptions: ["mixWithOthers"],
      });
      await AudioManager.setAudioSessionActivity(true);
    } catch {
      // Session config can fail on simulator; silent fallback.
    }
  }

  try {
    const ctx = getAudioContext();
    silentOsc = ctx.createOscillator();
    silentGain = ctx.createGain();
    silentGain.gain.value = 0.00001;
    silentOsc.frequency.value = 20;
    silentOsc.type = "sine";
    silentOsc.connect(silentGain);
    silentGain.connect(ctx.destination);
    silentOsc.start();
  } catch {
    // No audio backend available; silent fallback.
  }
}

export function stopTimerKeepalive(): void {
  if (!active) return;
  active = false;
  try {
    if (silentOsc) {
      silentOsc.stop();
      silentOsc.disconnect();
    }
    if (silentGain) {
      silentGain.disconnect();
    }
  } catch {
    // ignore teardown errors
  }
  silentOsc = null;
  silentGain = null;

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
