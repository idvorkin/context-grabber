/**
 * The call's liveness rules, with no platform in them (#95).
 *
 * Igor's dumps of 2026-08-30 showed the AVAudioSession coming up with one
 * direction dead, either way round: a mic tap that delivered one buffer and
 * then nothing after the app's own route-change notifications; a socket that
 * delivered 15 frames of Larry in 63 s; a greeting that played into an
 * output whose clock had not started. Each of these has a plain signal —
 * "no buffer for a while", "the clock is not advancing", "text is arriving
 * but audio is not" — and each has a plain cure. The rules live here so
 * they can be tested; `callAudio.ts` and `callSession.ts` apply them.
 */

/** A mic buffer is 100 ms; fifteen missing in a row is a dead tap, not a hiccup. */
export const MIC_STALL_MS = 1500;

/** How long the output clock may sit still with audio due before playback is reopened. */
export const OUTPUT_STALL_MS = 1000;

/** How long to wait for the output clock to start before reopening playback once. */
export const CLOCK_START_MS = 2000;

/** Tony's words are arriving as text but no audio has for this long: the socket or the vendor, not the speaker. */
export const AUDIO_ABSENT_MS = 5000;

export type MicState = {
  now: number;
  /** A recorder is supposed to be delivering. */
  armed: boolean;
  /** Interrupted (Siri, a phone call): silence is expected. */
  paused: boolean;
  /** When the recorder was armed; a fresh tap gets the full grace. */
  armedAt: number;
  /** The last buffer's arrival, or 0 for none since arming. */
  lastBufferAt: number;
};

/** "stalled" when an armed, unpaused recorder has gone quiet for MIC_STALL_MS. */
export function micVerdict(s: MicState): "ok" | "stalled" | "idle" {
  if (!s.armed || s.paused) return "idle";
  const since = s.now - Math.max(s.lastBufferAt, s.armedAt);
  return since >= MIC_STALL_MS ? "stalled" : "ok";
}

export type OutputState = {
  now: number;
  /** The context's clock at this check and at the previous one. */
  currentTime: number;
  previousTime: number;
  previousCheckAt: number;
  /** Where the next frame would start; audio is due while it is ahead of the clock. */
  playhead: number;
  /** When a frame was last scheduled; a silent line is not a stall. */
  lastScheduledAt: number;
};

/**
 * "stalled" when audio is due, a frame was scheduled recently, and the clock
 * has not moved since the previous check at least OUTPUT_STALL_MS ago.
 */
export function outputVerdict(s: OutputState): "ok" | "stalled" | "idle" {
  const due = s.playhead > s.currentTime + 0.05;
  const recent = s.now - s.lastScheduledAt < 2000;
  if (!due || !recent) return "idle";
  const stillFor = s.now - s.previousCheckAt;
  if (s.currentTime > s.previousTime) return "ok";
  return stillFor >= OUTPUT_STALL_MS ? "stalled" : "ok";
}

export type AudioArrivalState = {
  now: number;
  /** Tony's latest transcript fragment. 0 for none. */
  lastTextAt: number;
  /** The latest binary frame from the bridge. 0 for none. */
  lastAudioAt: number;
};

/**
 * Tony is talking (text keeps arriving) but nothing has come down the
 * audio channel for AUDIO_ABSENT_MS: the bridge or the socket, not the phone.
 */
export function audioAbsent(s: AudioArrivalState): boolean {
  if (!s.lastTextAt || s.now - s.lastTextAt > AUDIO_ABSENT_MS) return false;
  return s.now - Math.max(s.lastAudioAt, 0) > AUDIO_ABSENT_MS;
}

export const MIC_STOPPED = "the microphone stopped delivering";
export const AUDIO_NOT_ARRIVING = "Tony's audio is not arriving from the bridge";
export const AUDIO_NOT_PLAYING = "Tony's audio is arriving but not playing";

export type PlaybackStats = {
  /** Seconds of Larry scheduled so far. */
  scheduledS: number;
  /** Seconds the clock has rendered of that. */
  playedS: number;
  clockRunning: boolean;
};

/** The output side in one clause for the periodic log line. */
export function describePlayback(s: PlaybackStats | null): string {
  if (!s) return "no playback";
  return `played ${s.playedS.toFixed(1)}s of ${s.scheduledS.toFixed(1)}s${s.clockRunning ? "" : " (clock not running)"}`;
}
