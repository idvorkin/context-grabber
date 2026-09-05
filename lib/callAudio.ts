/**
 * The native audio half of a Larry call: the phone's microphone in, its
 * speaker (or AirPods, or whatever iOS routes to) out, and the audio
 * session that keeps the app alive when the screen locks.
 *
 * Built on `react-native-audio-api`, which the Gym Timer already ships for
 * its tones, plus the `audio-route` module the Cockpit's device pickers use.
 * Nothing here is testable without a device; everything decision-shaped
 * lives in `callSession.ts` behind the `CallAudio` interface this file
 * implements, and the liveness rules in `callWatchdog.ts`.
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
import { describeInputState } from "./callDevices";
import type { CallAudio } from "./callSession";
import {
  AUDIO_NOT_PLAYING,
  CLOCK_START_MS,
  MIC_STOPPED,
  micVerdict,
  outputVerdict,
  type PlaybackStats,
} from "./callWatchdog";
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
 * After the session is (re)configured, iOS brings the input route up a
 * beat later. Arming the voice-processing unit before that captures a
 * not-yet-routed input — exact zeros for the whole call (#88). Wait for an
 * input to be on the route, briefly.
 */
const INPUT_ROUTE_WAIT_MS = 1500;
const INPUT_ROUTE_POLL_MS = 50;

/**
 * Larry (#95): a working call shows eight categoryChange notifications in
 * its first 400 ms; a recorder armed between two of them lands on a graph
 * the next change tears down — nothing ever arrives. So: quiet first.
 */
const ROUTE_QUIET_MS = 250;
let lastRouteChangeAt = 0;
let routeQuietSub: { remove(): void } | null = null;

function observeRouteQuiet(): void {
  if (routeQuietSub) return;
  routeQuietSub = AudioManager.addSystemEventListener("routeChange", () => {
    lastRouteChangeAt = Date.now();
  });
}

async function waitForInputRoute(log: Pick<CallLog, "add">): Promise<void> {
  if (!AudioRoute) return;
  const deadline = Date.now() + INPUT_ROUTE_WAIT_MS;
  let waited = 0;
  for (;;) {
    let input: { name: string } | null = null;
    try {
      input = AudioRoute.getDevices().current.input;
    } catch {
      // session not ready yet — keep waiting
    }
    const sinceRoute = Date.now() - lastRouteChangeAt;
    if (input && sinceRoute >= ROUTE_QUIET_MS) {
      log.add(`input route ready: ${input.name}${waited ? ` (after ${waited} ms)` : ""}, route quiet ${Math.min(sinceRoute, 9999)} ms`);
      return;
    }
    if (Date.now() >= deadline) {
      log.add(`no input on the route after ${INPUT_ROUTE_WAIT_MS} ms — arming anyway`);
      return;
    }
    await new Promise((r) => setTimeout(r, INPUT_ROUTE_POLL_MS));
    waited += INPUT_ROUTE_POLL_MS;
  }
}

/**
 * A route change fires several notifications in a burst, and the audio
 * library restarts its engine ON THE MAIN THREAD for each one. Wait for all
 * of that to finish before touching the engine from the JS thread — doing
 * both at once froze the app when Igor switched devices quickly.
 */
const ROUTE_SETTLE_MS = 1000;

/** How often the liveness watchdog looks at both directions. */
const WATCHDOG_MS = 500;

/** How often the output clock is polled while waiting for it to start. */
const CLOCK_POLL_MS = 50;

/** Larry held back while the output clock starts: ten seconds is more than any greeting. */
const PENDING_MAX_S = 10;

/** A stalled clock is reopened at most this often. */
const REOPEN_MIN_GAP_MS = 5000;

/** Re-arm a stalled tap this many times before saying the microphone is gone. */
const MIC_STALLS_BEFORE_GIVING_UP = 3;

type MicListener = (samples: Float32Array, sampleRate: number) => void;

/**
 * The one thing a route change can break for certain: the hardware sample
 * rate. AirPods over HFP run at 16 or 24 kHz where the built-in mic runs at
 * 48; the engine rebuilds itself on that change, but the recorder's
 * sample-rate converter stays prepared for the old rate. Everything else a
 * route change might break — a tap that goes quiet, a clock that stops — is
 * the watchdog's, which looks at what is actually arriving.
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

  /* ---------- liveness (#95) ---------- */
  let armedAt = 0;
  let lastBufferAt = 0;
  let paused = false;
  let micStalls = 0;
  let watchdog: ReturnType<typeof setInterval> | null = null;
  let health: string | null = null;

  /* ---------- the output clock ---------- */
  let clockLive = false;
  let clockPoll: ReturnType<typeof setInterval> | null = null;
  let pending: Float32Array[] = [];
  let pendingS = 0;
  let scheduledS = 0;
  let lastScheduledAt = 0;
  let clockPrev = 0;
  let clockAdvancedAt = 0;
  let reopenedAtOpen = false;
  let lastReopenAt = 0;

  const self: CallAudio = {
    onHealth: undefined,

    async prepare() {
      observeRouteQuiet();
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
          paused = true;
          recorder?.pause();
          return;
        }
        // A phone call, Siri, another app: the session comes back with its
        // settings gone. Re-assert, then resume the mic. The socket was
        // never touched, so if the bridge has not hung up on the silence the
        // call simply carries on.
        void configureSession()
          .then(() => {
            recorder?.resume();
            paused = false;
            armedAt = Date.now();
          })
          .catch((e) => console.warn("[call] resume after interruption:", e));
      });
      startWatchdog();
    },

    async startMic(onBuffer) {
      listener = onBuffer;
      micStalls = 0;
      disarmRecorder();
      await waitForInputRoute(log);
      recorder = armRecorder();
      armedRate = hardwareRate();
      routeChange?.remove();
      routeChange = AudioManager.addSystemEventListener("routeChange", onRouteChanged);
      startWatchdog();
    },

    /**
     * The session's re-arm (#88). A plain re-arm did not help: the dead
     * input was the I/O unit itself, not the tap. Do what a second call
     * does — everything down, session re-activated, playback reopened,
     * mic re-armed — because the second call is the one that always works.
     */
    async restartMic() {
      log.add(`mic reset: session down, playback reopened, mic re-armed${pendingS ? ` (${pendingS.toFixed(2)}s of Larry held)` : ""}`);
      disarmRecorder();
      const rate = outRate;
      closePlayback();
      if (Platform.OS === "ios") {
        try {
          await AudioManager.setAudioSessionActivity(false);
        } catch {
          // was not active
        }
      }
      await configureSession();
      openContext(rate);
      await waitForInputRoute(log);
      micStalls = 0;
      recorder = armRecorder();
      armedRate = hardwareRate();
    },

    openPlayback(rate) {
      closePlayback();
      log.add(`playback open @ ${rate} Hz, gain ${PLAYBACK_GAIN}`);
      openContext(rate);
    },

    /**
     * Larry's frames are held until the output clock is running (#95: the
     * greeting on a113ee played into a not-yet-live output). The first frame
     * kicks the engine; the frames wait in `pending` until `currentTime`
     * moves, then all of them are scheduled gaplessly from there.
     */
    play(pcm) {
      const samples = pcm16ToFloat(pcm);
      if (samples.length === 0) return;
      const c = ctx;
      if (c && clockLive) {
        schedule(c, samples);
        return;
      }
      // No context yet (a reset in progress), or a clock that has not
      // started: hold it. Nothing Larry says is dropped for a speaker that
      // is between lives.
      pending.push(samples);
      pendingS += samples.length / outRate;
      while (pendingS > PENDING_MAX_S && pending.length > 1) {
        const dropped = pending.shift()!;
        pendingS -= dropped.length / outRate;
      }
      if (c && !clockPoll) startClock(c);
    },

    flush,

    stats(): PlaybackStats | null {
      const c = ctx;
      if (!c) return null;
      const queued = Math.max(0, playhead - c.currentTime);
      return { scheduledS, playedS: Math.max(0, scheduledS - queued), clockRunning: clockLive, pendingS };
    },

    async stop() {
      listener = null;
      stopWatchdog();
      if (routeTimer) clearTimeout(routeTimer);
      routeTimer = null;
      routeChange?.remove();
      routeChange = null;
      disarmRecorder();
      closePlayback();
      pending = [];
      pendingS = 0;
      interruption?.remove();
      interruption = null;
      paused = false;
      setHealth(null);
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

  function setHealth(problem: string | null): void {
    if (health === problem) return;
    health = problem;
    self.onHealth?.(problem);
  }

  /* ---------- the mic ---------- */

  /**
   * The picker moved the mic, AirPods arrived, a cable came out: if the
   * hardware rate the recorder was sized for is gone, size it again. No
   * session reconfiguration here: the session is already right (audio-route
   * re-asserts the chosen route itself, the library re-applies the
   * category), and calling setActive from the JS thread while the main
   * thread is inside the library's own restart is a deadlock. Debounced
   * past the burst, compared against the rate the mic was armed with, and
   * never overlapping. A tap the change killed without moving the rate is
   * the watchdog's to catch, a second and a half later.
   */
  function onRouteChanged(): void {
    if (routeTimer) clearTimeout(routeTimer);
    routeTimer = setTimeout(() => {
      routeTimer = null;
      if (!listener || rearming) return;
      const rate = hardwareRate();
      if (recorder && rate === armedRate) {
        log.add(`route changed, hardware rate still ${rate} Hz → mic kept (watchdog will say if it went quiet)`);
        return;
      }
      log.add(`route changed, hardware rate ${armedRate} → ${rate} Hz → re-arming mic`);
      rearm();
    }, ROUTE_SETTLE_MS);
  }

  function rearm(): void {
    rearming = true;
    try {
      disarmRecorder();
      recorder = armRecorder();
      armedRate = hardwareRate();
    } catch (e) {
      log.add(`re-arm FAILED: ${e instanceof Error ? e.message : String(e)}`);
      console.warn("[call] re-arm:", e);
    } finally {
      rearming = false;
    }
  }

  /**
   * Larry (#95, ask 4): on a silent first call, say what the mic was up
   * against as it was armed — other audio, the inputs on the route, the
   * session's shape. A binary older than the module's `getInputState`
   * simply has no line.
   */
  function logInputState(): void {
    if (!AudioRoute || typeof AudioRoute.getInputState !== "function") return;
    try {
      log.add(`at arm: ${describeInputState(AudioRoute.getInputState())}`);
    } catch (e) {
      log.add(`at arm: state unreadable (${e instanceof Error ? e.message : String(e)})`);
    }
  }

  function armRecorder(): AudioRecorder {
    log.add(`recorder arming: hardware rate ${hardwareRate()} Hz, asking ${BRIDGE_IN_RATE} Hz mono`);
    logInputState();
    const r = new AudioRecorder();
    r.onAudioReady(
      { sampleRate: BRIDGE_IN_RATE, bufferLength: MIC_BUFFER_FRAMES, channelCount: 1 },
      ({ buffer }) => {
        lastBufferAt = Date.now();
        if (micStalls && health === MIC_STOPPED) setHealth(null);
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
    armedAt = Date.now();
    lastBufferAt = 0;
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

  /* ---------- playback ---------- */

  /**
   * A fresh context. What Larry said while there was none — a reset in
   * progress, a clock that never started — is still in `pending` and goes
   * out as soon as this clock runs.
   */
  function openContext(rate: number): void {
    outRate = rate;
    ctx = new AudioContext({ sampleRate: rate });
    gain = ctx.createGain();
    gain.gain.value = PLAYBACK_GAIN;
    gain.connect(ctx.destination);
    playhead = 0;
    scheduledS = 0;
    lastScheduledAt = 0;
    clockLive = false;
    clockPrev = 0;
    clockAdvancedAt = Date.now();
    if (pending.length) startClock(ctx);
  }

  /** Kick the engine with a sliver of silence and wait for the clock to move. */
  function startClock(c: AudioContext): void {
    const openedAt = Date.now();
    const seen = c.currentTime;
    try {
      const kick = c.createBufferSource();
      kick.buffer = c.createBuffer(1, Math.max(1, Math.round(0.01 * outRate)), outRate);
      kick.connect(gain ?? c.destination);
      kick.start();
    } catch (e) {
      log.add(`output kick failed: ${e instanceof Error ? e.message : String(e)}`);
    }
    void Promise.resolve(c.resume?.()).catch(() => {});
    clockPoll = setInterval(() => {
      if (ctx !== c) {
        stopClockPoll();
        return;
      }
      if (c.currentTime > seen) {
        stopClockPoll();
        clockLive = true;
        clockPrev = c.currentTime;
        clockAdvancedAt = Date.now();
        log.add(`output clock running after ${Date.now() - openedAt} ms (${pendingS.toFixed(2)}s of Larry waiting)`);
        if (health === AUDIO_NOT_PLAYING) setHealth(null);
        drainPending(c);
        return;
      }
      if (Date.now() - openedAt < CLOCK_START_MS) return;
      stopClockPoll();
      if (!reopenedAtOpen) {
        reopenedAtOpen = true;
        log.add(`output clock has not started after ${CLOCK_START_MS} ms → reopening playback`);
        closePlayback();
        openContext(outRate); // pending survives; a waiting queue starts the new clock
        return;
      }
      // Twice is a fact. Schedule anyway so nothing is lost if it does come
      // up, and say so on the screen.
      log.add("output clock still not running after a reopen — scheduling anyway");
      setHealth(AUDIO_NOT_PLAYING);
      clockLive = true;
      drainPending(c);
    }, CLOCK_POLL_MS);
  }

  function stopClockPoll(): void {
    if (clockPoll) clearInterval(clockPoll);
    clockPoll = null;
  }

  function drainPending(c: AudioContext): void {
    const queue = pending;
    pending = [];
    pendingS = 0;
    for (const samples of queue) schedule(c, samples);
  }

  function schedule(c: AudioContext, samples: Float32Array): void {
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
    scheduledS += buffer.duration;
    lastScheduledAt = Date.now();
    scheduled.add(src);
  }

  /** The context goes; what is still held in `pending` does not — the next context plays it. */
  function closePlayback(): void {
    stopClockPoll();
    dropScheduled();
    const c = ctx;
    ctx = null;
    gain = null;
    clockLive = false;
    if (c) void c.close().catch(() => {});
  }

  /** Stop what is scheduled and count only what actually rendered. */
  function dropScheduled(): void {
    const c = ctx;
    if (c) scheduledS = Math.max(0, scheduledS - Math.max(0, playhead - c.currentTime));
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

  /** Barge-in: everything of Larry's not yet heard — scheduled or still held — goes. */
  function flush(): void {
    dropScheduled();
    pending = [];
    pendingS = 0;
  }

  /* ---------- the watchdog (#95) ---------- */

  function startWatchdog(): void {
    if (watchdog) return;
    watchdog = setInterval(tick, WATCHDOG_MS);
  }

  function stopWatchdog(): void {
    if (watchdog) clearInterval(watchdog);
    watchdog = null;
  }

  function tick(): void {
    const now = Date.now();

    // The mic: a tap that went quiet gets re-armed; three times and it is a fact.
    const mic = micVerdict({ now, armed: !!recorder && !!listener, paused, armedAt, lastBufferAt });
    if (mic === "stalled" && !rearming) {
      if (micStalls < MIC_STALLS_BEFORE_GIVING_UP) {
        micStalls += 1;
        const since = now - Math.max(lastBufferAt, armedAt);
        log.add(`mic stalled: no buffer for ${since} ms → re-arming (${micStalls}/${MIC_STALLS_BEFORE_GIVING_UP})`);
        rearm();
      } else if (health !== MIC_STOPPED) {
        log.add("mic still stalled after re-arms — giving up; the session's reset may still save it");
        setHealth(MIC_STOPPED);
      }
    }

    // The output: audio due, a frame scheduled recently, and a clock that is not moving.
    const c = ctx;
    if (c && clockLive) {
      const t = c.currentTime;
      const verdict = outputVerdict({
        now,
        currentTime: t,
        previousTime: clockPrev,
        previousCheckAt: clockAdvancedAt,
        playhead,
        lastScheduledAt,
      });
      if (t > clockPrev) {
        clockPrev = t;
        clockAdvancedAt = now;
        if (health === AUDIO_NOT_PLAYING) setHealth(null);
      }
      if (verdict === "stalled" && now - lastReopenAt >= REOPEN_MIN_GAP_MS) {
        lastReopenAt = now;
        log.add(`output clock stalled at ${t.toFixed(2)}s with ${(playhead - t).toFixed(1)}s due → reopening playback`);
        setHealth(AUDIO_NOT_PLAYING);
        const rate = outRate;
        closePlayback();
        openContext(rate);
      }
    }
  }

  return self;
}
