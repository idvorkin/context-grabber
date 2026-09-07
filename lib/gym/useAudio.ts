/**
 * The timer's cue hook — the interface igor-timer's useAudio had, over the
 * file-backed cues in ./cues.
 */
import { useCallback, useEffect } from "react";
import { loadCues, playCue } from "./cues";

export function useAudio() {
  useEffect(loadCues, []);
  // "GO!" — three rising notes.
  const playStartBeep = useCallback(() => playCue("go"), []);
  // Rest starting — two falling notes.
  const playEndBeep = useCallback(() => playCue("rest"), []);
  // The short tick at 3, 2, 1.
  const playCountdownBeep = useCallback(() => playCue("tick"), []);
  // All done — the fanfare.
  const playFinishBeep = useCallback(() => playCue("done"), []);
  return { playStartBeep, playEndBeep, playCountdownBeep, playFinishBeep };
}
