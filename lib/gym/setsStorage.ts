/**
 * Sets persistence for React Native.
 * Drop-in replacement for igor-timer's IndexedDB setsStorage.
 * Uses our existing SQLite settings table.
 */
import { getSetting, setSetting } from "../db";
import type { SQLiteDatabase } from "expo-sqlite";
import { getGymDb, setGymDb } from "./gymDb";

/** The gym's one database handle (gymDb.ts); kept under its old name for App.tsx. */
export function setSetsDb(db: SQLiteDatabase) {
  setGymDb(db);
}

export async function loadSetsCount(): Promise<number> {
  const db = getGymDb();
  if (!db) return 0;
  const val = await getSetting(db, "gym_sets_count", "0");
  return parseInt(val, 10);
}

export async function saveSetsCount(count: number): Promise<void> {
  const db = getGymDb();
  if (!db) return;
  await setSetting(db, "gym_sets_count", String(count));
}

export async function clearSetsCount(): Promise<void> {
  const db = getGymDb();
  if (!db) return;
  await setSetting(db, "gym_sets_count", "0");
}
