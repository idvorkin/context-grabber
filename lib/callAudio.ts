/**
 * The native audio half of a Larry call: the phone's microphone in, its
 * speaker (or AirPods, or whatever iOS routes to) out, and the audio
 * session that keeps the app alive when the screen locks.
 *
 * Built on `react-native-audio-api`, which the Gym Timer already ships for
 * its tones, plus the `audio-route` module the Cockpit's device pickers use.
 * Nothing here is testable without a device; everything decision-shaped
 * lives in `callSession.ts` behind the `CallAudio` interface this file
 * implements.
 *
 * Plan: docs/superpowers/plans/2026-08-28-native-call-screen-plan.md,
 * "Audio pipeline" and "Audio session ownership".
 */

import { Platform } from "react-native";
import {
  AudioContext,
  AudioManager,
  AudioRecorder,
  type AudioBufferSourceNode,
  type GainNode,
} from "react-native-audio-api";
import AudioRoute from "../modules/audio-route";
import type { CallAudio } from "./callSession";
import { NO_LOG, type CallLog } from "./callLog";
import { BRIDGE_IN_RATE, pcm16ToFloat } from "./pcm";

/** Scheduling lead on the first frame after silence — the page's 80 ms. */
const LEAD_S = 0.08;

/** 100 ms of mic per buffer at 16 kHz: small enough for barge-in, few enough calls across the bridge. */
const MIC_BUFFER_FRAMES = 1600;

/**
 * Larry a notch under full scale. Voice processing cancels what it knows it
 * played, but a speaker driven to clipping leaks harmonics it never played —
 * Igor heard "a little bit of clipping" and an echo that was "better, not
 * perfect" on the first VPIO build.
 */
const PLAYBACK_GAIN = 0.8;

/**
 * A route change fires several notifications in a burst, and the audio
 * library restarts its engine ON THE MAIN THREAD for each one. Wait for all
 * of that to finish before touching the engine from the JS thread — doing
 * both at once froze the app when Igor switched devices quickly.
 */
const ROUTE_SETTLE_MS = 1000;

type MicListener = (samples: Float32Array, sampleRate: number) => void;

/**
 * The one thing a route change can break: the hardware sample rate. AirPods
 * over HFP run at 16 or 24 kHz where the built-in mic runs at 48; the engine
 * rebuilds itself on that change, but the recorder's sample-rate converter
 * stays prepared for the old rate. A different built-in mic, or an output
 * change alone, keeps the rate — and needs nothing from us.
 */
function hardwareRate(): number {
  try {
    return AudioManager.getDevicePreferredSampleRate();
  } catch {
    return 0; // simulator
  }
}

/**
 * Two things touch the audio session. `audio-route.activate()` puts it in
 * `.playAndRecord` with Bluetooth allowed (the roster, the output override)
 * and mode `.default`; the options here re-state the category and set the
 * mode to `.voiceChat`, which is what turns on iOS's echo cancellation and
 * speech-tuned gain. Same category, last writer wins the mode. Re-asserted
 * after every interruption because a session that was taken away comes back
 * with whatever the taker left.
 */
async function configureSession(): Promise<void> {
  if (Platform.OS !== "ios") return;
  if (AudioRoute) await AudioRoute.activate();
  AudioManager.setAudioSessionOptions({
    iosCategory: "playAndRecord",
    iosMode: "voiceChat",
    iosOptions: ["allowBluetoothHFP", "allowBluetoothA2DP", "defaultToSpeaker"],
  });
  await AudioManager.setAudioSessionActivity(true);
}

export function createNativeCallAudio(log: Pick<CallLog, "add"> = NO_LOG): CallAudio {
  let recorder: AudioRecorder | null = null;
  let listener: MicListener | null = null;
  let ctx: AudioContext | null = null;
  let gain: GainNode | null = null;
  let outRate = 24000;
  let playhead = 0;
  const scheduled = new Set<AudioBufferSourceNode>();
  let interruption: { remove(): void } | null = null;
  let routeChange: { remove(): void } | null = null;
  let routeTimer: ReturnType<typeof setTimeout> | null = null;
  let armedRate = 0;
  let rearming = false;

  /**
   * The picker moved the mic, AirPods arrived, a cable came out: if the
   * hardware rate the recorder was sized for is gone, size it again — and
   * nothing else. No session reconfiguration here: the session is already
   * right (audio-route re-asserts the chosen route itself, the library
   * re-applies the category), and calling setActive from the JS thread while
   * the main thread is inside the library's own restart is a deadlock.
   * Debounced past the burst, compared against the rate the mic was armed
   * with, and never overlapping.
   */
  function onRouteChanged(): void {
    if (routeTimer) clearTimeout(routeTimer);
    routeTimer = setTimeout(() => {
      routeTimer = null;
      if (!recorder || rearming) return;
      const rate = hardwareRate();
      if (rate === armedRate) {
        log.add(`route changed, hardware rate still ${rate} Hz → mic kept`);
        return;
      }
      log.add(`route changed, hardware rate ${armedRate} → ${rate} Hz → re-arming mic`);
      rearming = true;
      try {
        disarmRecorder();
        recorder = armRecorder();
        armedRate = hardwareRate();
      } catch (e) {
        console.warn("[call] re-arm after route change:", e);
      } finally {
        rearming = false;
      }
    }, ROUTE_SETTLE_MS);
  }

  function armRecorder(): AudioRecorder {
    log.add(`recorder arming: hardware rate ${hardwareRate()} Hz, asking ${BRIDGE_IN_RATE} Hz mono`);
    const r = new AudioRecorder();
    r.onAudioReady(
      { sampleRate: BRIDGE_IN_RATE, bufferLength: MIC_BUFFER_FRAMES, channelCount: 1 },
      ({ buffer }) => {
        // The engine may deliver at a rate other than the one asked for;
        // the buffer says which, and the session resamples.
        listener?.(buffer.getChannelData(0), buffer.sampleRate);
      },
    );
    r.onError((e) => {
      log.add(`recorder ERROR: ${e.message}`);
      console.warn("[call] recorder:", e.message);
    });
    const result = r.start();
    if (result.status === "error") {
      log.add(`recorder start FAILED: ${result.message}`);
      throw new Error(result.message || "recorder failed to start");
    }
    log.add("recorder started");
    return r;
  }

  function disarmRecorder(): void {
    const r = recorder;
    recorder = null;
    if (!r) return;
    try {
      r.clearOnAudioReady();
      r.clearOnError();
      r.stop();
    } catch {
      // already stopped
    }
  }

  function closePlayback(): void {
    flush();
    const c = ctx;
    ctx = null;
    gain = null;
    if (c) void c.close().catch(() => {});
  }

  function flush(): void {
    for (const src of scheduled) {
      try {
        src.stop();
      } catch {
        // never started, or already done
      }
    }
    scheduled.clear();
    playhead = 0;
  }

  return {
    async prepare() {
      const permission = await AudioManager.requestRecordingPermissions();
      log.add(`mic permission: ${permission}`);
      if (permission !== "Granted") throw new Error(`microphone permission ${permission}`);
      await configureSession();
      log.add("session: playAndRecord / voiceChat / bluetooth+speaker, active");
      AudioManager.observeAudioInterruptions(true);
      interruption?.remove();
      interruption = AudioManager.addSystemEventListener("interruption", (ev) => {
        log.add(`interruption ${ev.type}${ev.type === "ended" ? ` (shouldResume=${ev.shouldResume})` : ""}`);
        if (ev.type === "began") {
          recorder?.pause();
          return;
        }
        // A phone call, Siri, another app: the session comes back with its
        // settings gone. Re-assert, then resume the mic. The socket was
        // never touched, so if the bridge has not hung up on the silence the
        // call simply carries on.
        void configureSession()
          .then(() => recorder?.resume())
          .catch((e) => console.warn("[call] resume after interruption:", e));
      });
    },

    async startMic(onBuffer) {
      listener = onBuffer;
      disarmRecorder();
      recorder = armRecorder();
      armedRate = hardwareRate();
      routeChange?.remove();
      routeChange = AudioManager.addSystemEventListener("routeChange", onRouteChanged);
    },

    async restartMic() {
      disarmRecorder();
      recorder = armRecorder();
      armedRate = hardwareRate();
    },

    openPlayback(rate) {
      closePlayback();
      log.add(`playback open @ ${rate} Hz, gain ${PLAYBACK_GAIN}`);
      outRate = rate;
      ctx = new AudioContext({ sampleRate: rate });
      gain = ctx.createGain();
      gain.gain.value = PLAYBACK_GAIN;
      gain.connect(ctx.destination);
      playhead = 0;
    },

    play(pcm) {
      const c = ctx;
      if (!c) return;
      const samples = pcm16ToFloat(pcm);
      if (samples.length === 0) return;
      const buffer = c.createBuffer(1, samples.length, outRate);
      buffer.copyToChannel(samples, 0);
      const src = c.createBufferSource();
      src.buffer = buffer;
      src.connect(gain ?? c.destination);
      // Gapless: each frame starts where the last one ends, never in the past.
      const when = Math.max(c.currentTime + LEAD_S, playhead);
      src.onEnded = () => {
        scheduled.delete(src);
      };
      src.start(when);
      playhead = when + buffer.duration;
      scheduled.add(src);
    },

    flush,

    async stop() {
      listener = null;
      if (routeTimer) clearTimeout(routeTimer);
      routeTimer = null;
      routeChange?.remove();
      routeChange = null;
      disarmRecorder();
      closePlayback();
      interruption?.remove();
      interruption = null;
      if (Platform.OS === "ios") {
        try {
          AudioManager.observeAudioInterruptions(false);
          await AudioManager.setAudioSessionActivity(false);
        } catch {
          // nothing to release
        }
      }
    },
  };
}
