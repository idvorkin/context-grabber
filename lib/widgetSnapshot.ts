/**
 * Write today's health snapshot to the shared App Group UserDefaults suite that
 * the iOS home-screen widget (TodayWidget) reads. Bridged through the native
 * WidgetBridge module added in ios/ContextGrabber/WidgetBridge.{swift,m}.
 *
 * Silent on failure — the widget degrades to em-dashes, which is not worth
 * surfacing in the UI. Android is a no-op (no widget).
 */
import { NativeModules, Platform } from "react-native";

type WidgetBridgeModule = {
  writeSnapshot: (payload: {
    steps?: number;
    sleepHours?: number;
    exerciseMinutes?: number;
    grabbedAt: number; // unix ms
  }) => Promise<void>;
};

type SnapshotInput = {
  steps: number | null;
  sleepHours: number | null;
  exerciseMinutes: number | null;
};

export async function writeWidgetSnapshot(input: SnapshotInput): Promise<void> {
  if (Platform.OS !== "ios") return;
  const bridge = (NativeModules as { WidgetBridge?: WidgetBridgeModule }).WidgetBridge;
  if (!bridge) return; // Module missing at runtime (e.g. old binary without P2).
  const payload: Parameters<WidgetBridgeModule["writeSnapshot"]>[0] = {
    grabbedAt: Date.now(),
  };
  if (input.steps != null) payload.steps = input.steps;
  if (input.sleepHours != null) payload.sleepHours = input.sleepHours;
  if (input.exerciseMinutes != null) payload.exerciseMinutes = input.exerciseMinutes;
  try {
    await bridge.writeSnapshot(payload);
  } catch {
    // Widget refresh is best-effort; never break grabContext over it.
  }
}
