import { AudioManager } from "react-native-audio-api";
import { Platform } from "react-native";
import { createAudioPlayer, type AudioPlayer } from "expo-audio";
import { DuckWindow, type DuckSession } from "./duck";
import { timerLog } from "./timerLog";

/**
 * The timer's audio session and its background keepalive.
 *
 * The session — category, the mixing and ducking options, activation and the
 * notify-others deactivation — is steered through react-native-audio-api's
 * AudioManager, which applies option changes to the live session and carries
 * the repo's patch. Nothing audible goes through that library's engine any
 * more: the cues (cues.ts) and the keepalive loop below are files played by
 * expo-audio's player, which the engine's state cannot silence.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md
 */

let loop: AudioPlayer | null = null;
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
 * with others: a workout no longer pauses the music. Idempotent.
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
 * loop restarted after it, the deactivation awaited so the two never cross.
 * Nothing to let go of when the keepalive is not running: the final
 * deactivation in `stopTimerKeepalive` carries the flag.
 */
const timerDuckSession: DuckSession = {
  setDucking: applySessionOptions,
  async release() {
    if (!active) {
      timerLog.add("release: keepalive not running, nothing to let go of");
      return;
    }
    await stopTimerKeepalive();
    await startTimerKeepalive();
  },
};

/** Hold it open around each cue; it closes itself a moment after the last one. */
export const duckWindow = new DuckWindow(timerDuckSession, (m) => timerLog.add(m));

/**
 * Keep the app alive in the background: activate the session and loop a
 * second of -66 dB noise (assets/audio/timer/keepalive.wav — real samples,
 * which iOS counts as live output; digital silence it may not). Idempotent.
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
    if (!loop) {
      loop = createAudioPlayer(require("../../assets/audio/timer/keepalive.wav"), { keepAudioSessionActive: true });
      loop.loop = true;
    }
    void loop.seekTo(0);
    loop.play();
    timerLog.add("keepalive loop started");
  } catch (e) {
    // No audio backend available; silent fallback.
    timerLog.add(`keepalive loop FAILED: ${e instanceof Error ? e.message : String(e)}`);
  }
}

/** Stop the loop and let go of the session; resolves once the session is inactive. */
export async function stopTimerKeepalive(): Promise<void> {
  if (!active) return;
  active = false;
  try {
    loop?.pause();
  } catch {
    // ignore teardown errors
  }
  timerLog.add("keepalive loop stopped");

  if (Platform.OS === "ios") {
    try {
      await AudioManager.setAudioSessionActivity(false);
      timerLog.add("session inactive (others told they may resume)");
    } catch (e) {
      timerLog.add(`session deactivate FAILED: ${e instanceof Error ? e.message : String(e)}`);
    }
  }
}

export function isKeepaliveActive(): boolean {
  return active;
}

/**
 * The timer letting go — reset, done, leaving: the keepalive's own
 * deactivation carries the resume for others, so the window closes after
 * it and its release finds nothing left to let go of.
 */
export function stopTimerAudio(): void {
  void stopTimerKeepalive();
  void duckWindow.close();
}
