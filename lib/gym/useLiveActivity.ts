/**
 * Hook to manage iOS Live Activity for the gym timer.
 * Shows countdown in Dynamic Island and Lock Screen.
 */
import { useRef, useCallback } from "react";
import { Platform } from "react-native";
import * as LiveActivity from "expo-live-activity";

const CONFIG: LiveActivity.LiveActivityConfig = {
  backgroundColor: "1a1a2e",
  titleColor: "e0e0e0",
  subtitleColor: "888888",
  progressViewTint: "4361ee",
  progressViewLabelColor: "ffffff",
  timerType: "digital",
  padding: 12,
};

export function useLiveActivity() {
  const activityIdRef = useRef<string | null>(null);
  const isAvailable = Platform.OS === "ios";

  const stop = useCallback((title = "Done", subtitle = "") => {
    if (!isAvailable || !activityIdRef.current) return;
    try {
      LiveActivity.stopActivity(activityIdRef.current, {
        title,
        subtitle,
        progressBar: { progress: 1 },
      });
    } catch {
      // fail silently
    }
    activityIdRef.current = null;
  }, [isAvailable]);

  const start = useCallback((title: string, subtitle: string, endTimeMs: number) => {
    if (!isAvailable) return;
    // Stop any existing activity before starting a new one
    if (activityIdRef.current) stop();
    try {
      const id = LiveActivity.startActivity(
        { title, subtitle, progressBar: { date: endTimeMs } },
        CONFIG,
      );
      if (id) activityIdRef.current = id;
    } catch {
      // Live Activity not supported on this device
    }
  }, [isAvailable, stop]);

  const update = useCallback((title: string, subtitle: string, endTimeMs?: number, progress?: number) => {
    if (!isAvailable || !activityIdRef.current) return;
    try {
      const state: LiveActivity.LiveActivityState = { title, subtitle };
      if (endTimeMs != null) {
        state.progressBar = { date: endTimeMs };
      } else if (progress != null) {
        state.progressBar = { progress };
      }
      LiveActivity.updateActivity(activityIdRef.current, state);
    } catch {
      // fail silently
    }
  }, [isAvailable]);

  return { start, update, stop, isAvailable };
}
