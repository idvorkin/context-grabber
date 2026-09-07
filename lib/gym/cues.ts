/**
 * The Gym Timer's cues — GO, rest, the 3-2-1 tick, the finish — as sound
 * files played through the ordinary media player, not synthesised. The
 * Web-Audio engine went silent as soon as the session mixed with other
 * audio (the log of 2026-09-07 showed every cue requested and none heard);
 * a file player does not depend on that engine at all.
 *
 * The files are rendered by scripts/make-timer-cues.mjs from the same note
 * recipes the synthesis used, so the cues sound as they always have.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md
 */
import { createAudioPlayer, type AudioPlayer } from "expo-audio";
import { timerLog } from "./timerLog";

export type Cue = "go" | "rest" | "tick" | "done";

const SOURCES: Record<Cue, number> = {
  go: require("../../assets/audio/timer/go.wav"),
  rest: require("../../assets/audio/timer/rest.wav"),
  tick: require("../../assets/audio/timer/tick.wav"),
  done: require("../../assets/audio/timer/done.wav"),
};

const players = new Map<Cue, AudioPlayer>();

function player(cue: Cue): AudioPlayer {
  let p = players.get(cue);
  if (!p) {
    // The session is the timer's to keep active (keepalive.ts); a finished cue
    // must not let the player library deactivate it.
    p = createAudioPlayer(SOURCES[cue], { keepAudioSessionActive: true });
    players.set(cue, p);
  }
  return p;
}

/** Make every cue's player ahead of time, so the first tick is not the first load. */
export function loadCues(): void {
  for (const cue of Object.keys(SOURCES) as Cue[]) player(cue);
}

/** Play a cue from its start, now. */
export function playCue(cue: Cue): void {
  try {
    const p = player(cue);
    void p.seekTo(0);
    p.play();
    timerLog.add(`cue ${cue}${p.isLoaded ? "" : " (not yet loaded)"}`);
  } catch (e) {
    timerLog.add(`cue ${cue} FAILED: ${e instanceof Error ? e.message : String(e)}`);
  }
}
