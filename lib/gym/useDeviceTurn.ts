import { useEffect, useRef, useState } from "react";
import { Accelerometer } from "expo-sensors";
import { classifyTurn, type Turn } from "./deviceTurn";

/**
 * Which way the phone is turned, a few times a second, from the
 * accelerometer — while the app's window stays portrait. No accelerometer
 * (a simulator, an old build): "upright" for good, and the display never
 * turns. No permission is involved.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-led-display-design.md
 */
export function useDeviceTurn(enabled = true): Turn {
  const [turn, setTurn] = useState<Turn>("upright");
  const turnRef = useRef<Turn>("upright");

  useEffect(() => {
    if (!enabled) return;
    let cancelled = false;
    let sub: { remove(): void } | null = null;
    void (async () => {
      try {
        if (!(await Accelerometer.isAvailableAsync()) || cancelled) return;
        Accelerometer.setUpdateInterval(200);
        sub = Accelerometer.addListener(({ x, y }) => {
          const next = classifyTurn(x, y, turnRef.current);
          if (next === turnRef.current) return;
          turnRef.current = next;
          setTurn(next);
        });
      } catch {
        // no accelerometer: the display stays upright
      }
    })();
    return () => {
      cancelled = true;
      sub?.remove();
    };
  }, [enabled]);

  return turn;
}
