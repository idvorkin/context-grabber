/**
 * Tap counter — single, daily-resetting, label-free.
 * Source of truth lives in the SQLite settings table so the value survives
 * app restarts. The native side mirrors `(value, dateKey)` to App Group
 * UserDefaults via WidgetBridge so the iOS widget can read/increment it.
 *
 * No "label" or "reset policy" — v1 is one counter, daily reset at local
 * midnight, no configurability. See
 * docs/superpowers/specs/2026-04-25-tap-counter-design.md.
 */

import type { SQLiteDatabase } from "expo-sqlite";
import { getSetting, setSetting } from "./db";

const KEY_VALUE = "counter_value";
const KEY_RESET_DATE = "counter_reset_date";

/** Returns local date as "YYYY-MM-DD" — same shape as `formatDateKey` in lib/weekly. */
export function todayLocalDateKey(d: Date = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export type CounterState = { value: number; dateKey: string };

/**
 * Read the counter, applying a daily reset on the fly if the stored reset
 * date is older than today. Always writes back when a reset fires so the
 * state is durable across reads.
 */
export async function getCounter(db: SQLiteDatabase): Promise<CounterState> {
  const today = todayLocalDateKey();
  const valueStr = await getSetting(db, KEY_VALUE, "0");
  const dateKey = await getSetting(db, KEY_RESET_DATE, today);
  const value = parseInt(valueStr, 10) || 0;

  if (dateKey !== today) {
    // Stale — reset and persist.
    await setSetting(db, KEY_VALUE, "0");
    await setSetting(db, KEY_RESET_DATE, today);
    return { value: 0, dateKey: today };
  }
  return { value, dateKey };
}

/** Increment by 1 and persist. Returns the new state. */
export async function incrementCounter(db: SQLiteDatabase): Promise<CounterState> {
  const current = await getCounter(db);
  const next = current.value + 1;
  await setSetting(db, KEY_VALUE, String(next));
  return { value: next, dateKey: current.dateKey };
}

/** Manual reset. Sets value to 0 with today's date. */
export async function resetCounter(db: SQLiteDatabase): Promise<CounterState> {
  const today = todayLocalDateKey();
  await setSetting(db, KEY_VALUE, "0");
  await setSetting(db, KEY_RESET_DATE, today);
  return { value: 0, dateKey: today };
}
