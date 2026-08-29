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

/** A route change fires several notifications in a burst; act once, after it settles. */
const ROUTE_SETTLE_MS = 350;

type MicListener = (samples: Float32Array, sampleRate: number) => void;

/**
 * What the mic is actually attached to, as a string that changes when the
 * recorder must be re-armed: the input port, the output port, and the
 * hardware rate. AirPods (HFP) run at 16 or 24 kHz where the built-in mic
 * runs at 48; the engine rebuilds itself on that change, but the recorder's
 * sample-rate converter stays prepared for the old rate.
 */
function routeSignature(): string {
  let input = "?";
  let output = "?";
  try {
    const snap = AudioRoute?.getDevices();
    input = snap?.current.input?.id ?? "?";
    output = snap?.current.output?.id ?? "?";
  } catch {
    // module missing or session not ready — the rate alone still discriminates
  }
  let rate = 0;
  try {
    rate = AudioManager.getDevicePreferredSampleRate();
  } catch {
    // simulator
  }
  return `${input}|${output}|${rate}`;
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

export function createNativeCallAudio(): CallAudio {
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
  let armedRoute = "";

  /**
   * The picker moved the mic, AirPods arrived, a cable came out: if the
   * hardware the recorder was sized for is gone, size it again. Debounced,
   * and compared against what it was armed with, so the engine restart our
   * own re-arm causes does not re-arm it again.
   */
  function onRouteChanged(): void {
    if (routeTimer) clearTimeout(routeTimer);
    routeTimer = setTimeout(() => {
      routeTimer = null;
      if (!recorder) return;
      const now = routeSignature();
      if (now === armedRoute) return;
      armedRoute = now;
      void configureSession()
        .catch((e) => console.warn("[call] session after route change:", e))
        .then(() => {
          if (!recorder) return;
          disarmRecorder();
          recorder = armRecorder();
        });
    }, ROUTE_SETTLE_MS);
  }

  function armRecorder(): AudioRecorder {
    const r = new AudioRecorder();
    r.onAudioReady(
      { sampleRate: BRIDGE_IN_RATE, bufferLength: MIC_BUFFER_FRAMES, channelCount: 1 },
      ({ buffer }) => {
        // The engine may deliver at a rate other than the one asked for;
        // the buffer says which, and the session resamples.
        listener?.(buffer.getChannelData(0), buffer.sampleRate);
      },
    );
    r.onError((e) => console.warn("[call] recorder:", e.message));
    const result = r.start();
    if (result.status === "error") throw new Error(result.message || "recorder failed to start");
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
      if (permission !== "Granted") throw new Error(`microphone permission ${permission}`);
      await configureSession();
      AudioManager.observeAudioInterruptions(true);
      interruption?.remove();
      interruption = AudioManager.addSystemEventListener("interruption", (ev) => {
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
      armedRoute = routeSignature();
      routeChange?.remove();
      routeChange = AudioManager.addSystemEventListener("routeChange", onRouteChanged);
    },

    async restartMic() {
      disarmRecorder();
      recorder = armRecorder();
      armedRoute = routeSignature();
    },

    openPlayback(rate) {
      closePlayback();
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
