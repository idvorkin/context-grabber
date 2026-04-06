/**
 * React Native audio hook for gym timer sounds.
 * Same interface as igor-timer's useAudio.
 * Uses react-native-audio-api (Web Audio API polyfill) for dynamic tone generation.
 */
import { useCallback, useRef } from "react";
import { AudioContext } from "react-native-audio-api";

let _ctx: InstanceType<typeof AudioContext> | null = null;

function getCtx(): InstanceType<typeof AudioContext> {
  if (!_ctx) _ctx = new AudioContext();
  return _ctx;
}

function playTone(frequency: number, duration: number, volume = 0.7, delay = 0): void {
  try {
    const ctx = getCtx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.frequency.value = frequency;
    osc.type = "sine";
    gain.gain.value = volume;
    osc.connect(gain);
    gain.connect(ctx.destination);
    const startTime = ctx.currentTime + delay;
    osc.start(startTime);
    osc.stop(startTime + duration);
  } catch {
    // Audio not available — fail silently
  }
}

export function useAudio() {
  // "GO!" sound - ascending tone when work starts
  const playStartBeep = useCallback(() => {
    playTone(800, 0.15, 0.8, 0);
    playTone(1000, 0.15, 0.8, 0.1);
    playTone(1200, 0.25, 0.9, 0.2);
  }, []);

  // Rest starting - descending double beep
  const playEndBeep = useCallback(() => {
    playTone(800, 0.2, 0.7, 0);
    playTone(600, 0.3, 0.7, 0.2);
  }, []);

  // Countdown beeps - short tick at 3, 2, 1
  const playCountdownBeep = useCallback(() => {
    playTone(660, 0.08, 0.6);
  }, []);

  // All done - victory fanfare (C-E-G-HighC)
  const playFinishBeep = useCallback(() => {
    playTone(523, 0.2, 0.8, 0);       // C
    playTone(659, 0.2, 0.8, 0.15);    // E
    playTone(784, 0.2, 0.8, 0.3);     // G
    playTone(1047, 0.4, 0.9, 0.45);   // High C
  }, []);

  return { playStartBeep, playEndBeep, playCountdownBeep, playFinishBeep };
}
