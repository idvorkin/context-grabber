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
} from "react-native-audio-api";
import AudioRoute from "../modules/audio-route";
import type { CallAudio } from "./callSession";
import { BRIDGE_IN_RATE, pcm16ToFloat } from "./pcm";

/** Scheduling lead on the first frame after silence — the page's 80 ms. */
const LEAD_S = 0.08;

/** 100 ms of mic per buffer at 16 kHz: small enough for barge-in, few enough calls across the bridge. */
const MIC_BUFFER_FRAMES = 1600;

type MicListener = (samples: Float32Array, sampleRate: number) => void;

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
  let outRate = 24000;
  let playhead = 0;
  const scheduled = new Set<AudioBufferSourceNode>();
  let interruption: { remove(): void } | null = null;

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
    },

    async restartMic() {
      disarmRecorder();
      recorder = armRecorder();
    },

    openPlayback(rate) {
      closePlayback();
      outRate = rate;
      ctx = new AudioContext({ sampleRate: rate });
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
      src.connect(c.destination);
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
