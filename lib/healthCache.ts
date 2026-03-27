/**
 * Two-layer HealthKit cache backed by SQLite.
 *
 * RAW layer  — mapped-but-not-aggregated samples per metric per day.
 *              Survives aggregation logic changes so data can be recomputed.
 * COMPUTED layer — aggregated day buckets (DailyValue / HeartRateDaily).
 *                  What the UI actually renders.
 *
 * Cache rules:
 *   • Past days (before today, local time) are immutable → cached permanently.
 *   • Today → always re-fetched from HealthKit.
 *   • Bumping CACHE_VERSION clears everything.
 */

import type { SQLiteDatabase } from "expo-sqlite";
import { formatDateKey } from "./weekly";

// Bump this to bust the entire cache (e.g. when data shape changes).
const CACHE_VERSION = "2";

// ─── Schema ──────────────────────────────────────────────────────────────────

export async function initCacheTables(db: SQLiteDatabase): Promise<void> {
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS health_raw_cache (
      metric TEXT NOT NULL,
      date_key TEXT NOT NULL,
      data TEXT NOT NULL,
      cached_at INTEGER NOT NULL,
      PRIMARY KEY (metric, date_key)
    );
    CREATE TABLE IF NOT EXISTS health_computed_cache (
      metric TEXT NOT NULL,
      date_key TEXT NOT NULL,
      data TEXT NOT NULL,
      cached_at INTEGER NOT NULL,
      PRIMARY KEY (metric, date_key)
    );
    CREATE TABLE IF NOT EXISTS health_cache_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    INSERT OR IGNORE INTO health_cache_meta (key, value) VALUES ('cache_version', '${CACHE_VERSION}');
  `);

  // Check version — if stale, nuke both caches.
  const row = await db.getFirstAsync<{ value: string }>(
    "SELECT value FROM health_cache_meta WHERE key = 'cache_version'",
  );
  if (row?.value !== CACHE_VERSION) {
    await db.execAsync(`
      DELETE FROM health_raw_cache;
      DELETE FROM health_computed_cache;
      UPDATE health_cache_meta SET value = '${CACHE_VERSION}' WHERE key = 'cache_version';
    `);
  }
}

// ─── Raw cache ───────────────────────────────────────────────────────────────

export async function getRawCached(
  db: SQLiteDatabase,
  metric: string,
  dateKey: string,
): Promise<any[] | null> {
  const row = await db.getFirstAsync<{ data: string }>(
    "SELECT data FROM health_raw_cache WHERE metric = ? AND date_key = ?",
    [metric, dateKey],
  );
  return row ? JSON.parse(row.data) : null;
}

export async function putRawCached(
  db: SQLiteDatabase,
  metric: string,
  dateKey: string,
  data: any[],
): Promise<void> {
  await db.runAsync(
    "INSERT OR REPLACE INTO health_raw_cache (metric, date_key, data, cached_at) VALUES (?, ?, ?, ?)",
    [metric, dateKey, JSON.stringify(data), Date.now()],
  );
}

export async function getRawCachedBatch(
  db: SQLiteDatabase,
  metric: string,
  dateKeys: string[],
): Promise<Map<string, any[]>> {
  const result = new Map<string, any[]>();
  if (dateKeys.length === 0) return result;
  const placeholders = dateKeys.map(() => "?").join(",");
  const rows = await db.getAllAsync<{ date_key: string; data: string }>(
    `SELECT date_key, data FROM health_raw_cache WHERE metric = ? AND date_key IN (${placeholders})`,
    [metric, ...dateKeys],
  );
  for (const row of rows) {
    result.set(row.date_key, JSON.parse(row.data));
  }
  return result;
}

// ─── Computed cache ──────────────────────────────────────────────────────────

export async function getComputedCached(
  db: SQLiteDatabase,
  metric: string,
  dateKey: string,
): Promise<any | null> {
  const row = await db.getFirstAsync<{ data: string }>(
    "SELECT data FROM health_computed_cache WHERE metric = ? AND date_key = ?",
    [metric, dateKey],
  );
  return row ? JSON.parse(row.data) : null;
}

export async function putComputedCached(
  db: SQLiteDatabase,
  metric: string,
  dateKey: string,
  data: any,
): Promise<void> {
  await db.runAsync(
    "INSERT OR REPLACE INTO health_computed_cache (metric, date_key, data, cached_at) VALUES (?, ?, ?, ?)",
    [metric, dateKey, JSON.stringify(data), Date.now()],
  );
}

export async function getComputedCachedBatch(
  db: SQLiteDatabase,
  metric: string,
  dateKeys: string[],
): Promise<Map<string, any>> {
  const result = new Map<string, any>();
  if (dateKeys.length === 0) return result;
  const placeholders = dateKeys.map(() => "?").join(",");
  const rows = await db.getAllAsync<{ date_key: string; data: string }>(
    `SELECT date_key, data FROM health_computed_cache WHERE metric = ? AND date_key IN (${placeholders})`,
    [metric, ...dateKeys],
  );
  for (const row of rows) {
    result.set(row.date_key, JSON.parse(row.data));
  }
  return result;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Build the 7 date keys for a weekly window ending at `endDate`.
 */
export function buildDateKeys(endDate: Date, days = 7): string[] {
  const keys: string[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(endDate);
    d.setDate(d.getDate() - i);
    keys.push(formatDateKey(d));
  }
  return keys;
}

/**
 * Determine which date keys need fetching from HealthKit.
 * Today is always included. Past days only if not in the cached map.
 */
export function partitionDays(
  todayKey: string,
  dateKeys: string[],
  cached: Map<string, any>,
): { cachedDays: Map<string, any>; fetchDays: string[] } {
  const cachedDays = new Map<string, any>();
  const fetchDays: string[] = [];

  for (const key of dateKeys) {
    if (key === todayKey) {
      // Always re-fetch today.
      fetchDays.push(key);
    } else if (cached.has(key)) {
      cachedDays.set(key, cached.get(key));
    } else {
      fetchDays.push(key);
    }
  }
  return { cachedDays, fetchDays };
}
