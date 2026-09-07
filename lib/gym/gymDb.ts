/**
 * The database handle the gym timer's persistence shares (the set count,
 * the custom preset). App.tsx hands it in once it has opened the database.
 */
import type { SQLiteDatabase } from "expo-sqlite";

let _db: SQLiteDatabase | null = null;

export function setGymDb(db: SQLiteDatabase): void {
  _db = db;
}

export function getGymDb(): SQLiteDatabase | null {
  return _db;
}
