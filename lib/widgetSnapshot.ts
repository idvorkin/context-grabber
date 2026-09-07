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
    counter?: number;
    counterDate?: string; // local YYYY-MM-DD
    reflectOpportunity?: number;
    reflectDidIt?: number;
    reflectGrateful?: number;
    reflectDate?: string; // local YYYY-MM-DD
    grabbedAt: number; // unix ms
  }) => Promise<void>;
  readSnapshot: () => Promise<{
    counter: number | null;
    counterDate: string | null;
  }>;
  /** The memdeck card (lib/cardBridge.ts); absent on a binary older than 2026-09-07. */
  dealCard?: () => Promise<{ label: string; rank: string; suit: string; isRed: boolean }>;
  syncCardWidgets?: () => Promise<void>;
};

/** The native module, or nothing off iOS / on a binary without it. */
export function widgetBridge(): WidgetBridgeModule | undefined {
  if (Platform.OS !== "ios") return undefined;
  return (NativeModules as { WidgetBridge?: WidgetBridgeModule }).WidgetBridge;
}

/**
 * Read whatever the App Group currently holds. Used to reconcile widget-side
 * counter increments (via the iOS 17 App Intent) with the app's SQLite source
 * of truth on foreground / launch. Returns nulls on Android or when the
 * native module isn't loaded yet (e.g. old binary).
 */
export async function readWidgetSnapshot(): Promise<{
  counter: number | null;
  counterDate: string | null;
}> {
  const bridge = widgetBridge();
  if (!bridge?.readSnapshot) return { counter: null, counterDate: null };
  try {
    return await bridge.readSnapshot();
  } catch {
    return { counter: null, counterDate: null };
  }
}

type SnapshotInput = {
  steps: number | null;
  sleepHours: number | null;
  exerciseMinutes: number | null;
  /** Today's counter value. Always pushed when present so the widget stays in sync. */
  counter?: number | null;
  /** Today's Reflect tally. When provided, all three are pushed together
   *  with today's date so the widget can stale-guard on midnight rollover. */
  reflect?: { opportunity: number; didIt: number; grateful: number } | null;
};

/**
 * Write just the Reflect tally to the App Group, without touching the
 * health/counter fields. Cheap path used after any journal mutation so
 * the widget catches up between full health grabs.
 */
export async function writeReflectToWidget(opp: number, didIt: number, grateful: number): Promise<void> {
  const bridge = widgetBridge();
  if (!bridge) return;
  try {
    await bridge.writeSnapshot({
      grabbedAt: Date.now(),
      reflectOpportunity: opp,
      reflectDidIt: didIt,
      reflectGrateful: grateful,
      reflectDate: todayLocalDateKey(),
    });
  } catch {
    // Widget refresh is best-effort.
  }
}

function todayLocalDateKey(): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export async function writeWidgetSnapshot(input: SnapshotInput): Promise<void> {
  const bridge = widgetBridge();
  if (!bridge) return; // Module missing at runtime (e.g. old binary without P2).
  const payload: Parameters<WidgetBridgeModule["writeSnapshot"]>[0] = {
    grabbedAt: Date.now(),
  };
  if (input.steps != null) payload.steps = input.steps;
  if (input.sleepHours != null) payload.sleepHours = input.sleepHours;
  if (input.exerciseMinutes != null) payload.exerciseMinutes = input.exerciseMinutes;
  if (input.counter != null) {
    payload.counter = input.counter;
    payload.counterDate = todayLocalDateKey();
  }
  if (input.reflect) {
    payload.reflectOpportunity = input.reflect.opportunity;
    payload.reflectDidIt = input.reflect.didIt;
    payload.reflectGrateful = input.reflect.grateful;
    payload.reflectDate = todayLocalDateKey();
  }
  try {
    await bridge.writeSnapshot(payload);
  } catch {
    // Widget refresh is best-effort; never break grabContext over it.
  }
}
