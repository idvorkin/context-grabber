/**
 * The timer's cue hook — spoken cues over the file-backed players in ./cues:
 * "three, two, one" into every boundary, then "go!", "rest", or "done"
 * (which carries its own fanfare).
 */
import { useCallback, useEffect } from "react";
import { loadCues, playCue, type Cue } from "./cues";

const COUNT: Record<number, Cue> = { 3: "three", 2: "two", 1: "one" };

export function useAudio() {
  useEffect(loadCues, []);
  const playStartBeep = useCallback(() => playCue("go"), []);
  const playEndBeep = useCallback(() => playCue("rest"), []);
  /** The spoken count at 3, 2, 1 seconds left. */
  const playCountdown = useCallback((secondsLeft: number) => {
    const cue = COUNT[secondsLeft];
    if (cue) playCue(cue);
  }, []);
  const playFinishBeep = useCallback(() => playCue("done"), []);
  return { playStartBeep, playEndBeep, playCountdown, playFinishBeep };
}
