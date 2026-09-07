import { useEffect, useRef, useState } from "react";
import { classifyTurn, type Turn } from "./deviceTurn";

/**
 * Which way the phone is turned, a few times a second, from the
 * accelerometer — while the app's window stays portrait. No accelerometer
 * (a simulator, or a binary built before the sensor package was added, which
 * an over-the-air bundle can still land on): "upright" for good, and the
 * display never turns. No permission is involved.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-led-display-design.md
 */

type AccelerometerModule = {
  isAvailableAsync(): Promise<boolean>;
  setUpdateInterval(ms: number): void;
  addListener(cb: (reading: { x: number; y: number; z: number }) => void): { remove(): void };
};

/** The sensor package, or nothing on a binary that does not carry it. */
function accelerometer(): AccelerometerModule | null {
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const m = (require("expo-sensors") as { Accelerometer?: AccelerometerModule }).Accelerometer;
    return m && typeof m.addListener === "function" ? m : null;
  } catch {
    return null; // not linked in this binary
  }
}

export function useDeviceTurn(): Turn {
  const [turn, setTurn] = useState<Turn>("upright");
  const turnRef = useRef<Turn>("upright");

  useEffect(() => {
    const sensor = accelerometer();
    if (!sensor) return;
    let cancelled = false;
    let sub: { remove(): void } | null = null;
    void (async () => {
      try {
        if (!(await sensor.isAvailableAsync()) || cancelled) return;
        sensor.setUpdateInterval(200);
        sub = sensor.addListener(({ x, y }) => {
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
  }, []);

  return turn;
}
