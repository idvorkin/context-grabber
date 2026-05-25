import * as SQLite from "expo-sqlite";
import { pruneThreshold } from "./location";
import { initCacheTables } from "./healthCache";
import { initJournalTables } from "./journalDb";
import { type KnownPlace } from "./places";

export const DB_NAME = "context-grabber.db";

export type LocationHistoryItem = {
  latitude: number;
  longitude: number;
  accuracy: number | null;
  timestamp: number;
};

// --- SQLite helpers (module-level for use by background task) ---

export async function openDB(): Promise<SQLite.SQLiteDatabase> {
  return SQLite.openDatabaseAsync(DB_NAME);
}

export async function initDB(db: SQLite.SQLiteDatabase): Promise<void> {
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS locations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      accuracy REAL,
      timestamp INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_locations_timestamp ON locations(timestamp);
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS known_places (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      radius_meters REAL NOT NULL DEFAULT 100
    );
    CREATE TABLE IF NOT EXISTS mood_log (
      date TEXT PRIMARY KEY,
      energy INTEGER NOT NULL,
      mood INTEGER NOT NULL,
      note TEXT,
      ck_record_name TEXT,
      ck_change_tag TEXT,
      sync_state TEXT NOT NULL DEFAULT 'pending'
    );
    CREATE INDEX IF NOT EXISTS idx_mood_log_sync ON mood_log(sync_state);
    CREATE TABLE IF NOT EXISTS role_moments (
      id TEXT PRIMARY KEY,
      role_id TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      what TEXT NOT NULL,
      tag TEXT,
      source TEXT NOT NULL,
      source_ref TEXT,
      ck_record_name TEXT,
      ck_change_tag TEXT,
      sync_state TEXT NOT NULL DEFAULT 'pending'
    );
    CREATE INDEX IF NOT EXISTS idx_role_moments_role_time
      ON role_moments(role_id, timestamp);
    CREATE INDEX IF NOT EXISTS idx_role_moments_time
      ON role_moments(timestamp);
    CREATE INDEX IF NOT EXISTS idx_role_moments_sync
      ON role_moments(sync_state);
    CREATE TABLE IF NOT EXISTS role_intentions (
      id TEXT PRIMARY KEY,
      role_id TEXT NOT NULL,
      week_start_date TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      ck_record_name TEXT,
      ck_change_tag TEXT,
      sync_state TEXT NOT NULL DEFAULT 'pending',
      UNIQUE(role_id, week_start_date)
    );
    CREATE INDEX IF NOT EXISTS idx_intentions_sync
      ON role_intentions(sync_state);
    INSERT OR IGNORE INTO settings (key, value) VALUES ('schema_version', '2');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('tracking_enabled', 'false');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('retention_days', '30');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('sleep_target_hours', '8');
  `);
  await initCacheTables(db);
  await initJournalTables(db);
}

export async function getSetting(
  db: SQLite.SQLiteDatabase,
  key: string,
  defaultValue: string,
): Promise<string> {
  const row = await db.getFirstAsync<{ value: string }>(
    "SELECT value FROM settings WHERE key = ?",
    [key],
  );
  return row?.value ?? defaultValue;
}

export async function setSetting(
  db: SQLite.SQLiteDatabase,
  key: string,
  value: string,
): Promise<void> {
  await db.runAsync(
    "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
    [key, value],
  );
}

// ─── Last snapshot (cold-start hydration) ────────────────────────────────────
// Persists the most recent successful grabContext result so cold launch can
// paint tiles immediately instead of showing em-dashes until the first grab
// resolves. Stored as a single JSON blob in the settings table — small enough
// (~few KB) that key/value is simpler than a dedicated schema.

const LAST_SNAPSHOT_KEY = "last_snapshot";

export async function getLastSnapshot<T>(
  db: SQLite.SQLiteDatabase,
): Promise<T | null> {
  const row = await db.getFirstAsync<{ value: string }>(
    "SELECT value FROM settings WHERE key = ?",
    [LAST_SNAPSHOT_KEY],
  );
  if (!row) return null;
  try {
    return JSON.parse(row.value) as T;
  } catch {
    // Corrupt blob — drop it so the next successful grab can replace it.
    return null;
  }
}

export async function setLastSnapshot(
  db: SQLite.SQLiteDatabase,
  snapshot: unknown,
): Promise<void> {
  await setSetting(db, LAST_SNAPSHOT_KEY, JSON.stringify(snapshot));
}

// ─── Sleep target (hours/night) ──────────────────────────────────────────────

export async function getSleepTarget(db: SQLite.SQLiteDatabase): Promise<number> {
  const raw = await getSetting(db, "sleep_target_hours", "8");
  const n = parseFloat(raw);
  if (!Number.isFinite(n) || n <= 0) return 8;
  return n;
}

export async function setSleepTarget(
  db: SQLite.SQLiteDatabase,
  hours: number,
): Promise<void> {
  const clamped = Math.max(4, Math.min(12, hours));
  await setSetting(db, "sleep_target_hours", String(clamped));
}

export async function insertLocation(
  db: SQLite.SQLiteDatabase,
  latitude: number,
  longitude: number,
  accuracy: number | null,
  timestamp: number,
): Promise<void> {
  await db.runAsync(
    "INSERT INTO locations (latitude, longitude, accuracy, timestamp) VALUES (?, ?, ?, ?)",
    [latitude, longitude, accuracy, timestamp],
  );
}

export async function pruneLocations(
  db: SQLite.SQLiteDatabase,
  retentionDays: number,
): Promise<void> {
  const threshold = pruneThreshold(retentionDays, Date.now());
  await db.runAsync("DELETE FROM locations WHERE timestamp < ?", [threshold]);
}

export async function getLocationCount(db: SQLite.SQLiteDatabase): Promise<number> {
  const row = await db.getFirstAsync<{ count: number }>(
    "SELECT COUNT(*) as count FROM locations",
  );
  return row?.count ?? 0;
}

export async function getLocationStorageBytes(db: SQLite.SQLiteDatabase): Promise<number> {
  const row = await db.getFirstAsync<{ size: number }>(
    "SELECT SUM(LENGTH(latitude) + LENGTH(longitude) + LENGTH(accuracy) + LENGTH(timestamp) + 20) as size FROM locations",
  );
  return row?.size ?? 0;
}

export async function getKnownPlaces(
  db: SQLite.SQLiteDatabase,
): Promise<KnownPlace[]> {
  const rows = await db.getAllAsync<{
    id: number;
    name: string;
    latitude: number;
    longitude: number;
    radius_meters: number;
  }>("SELECT id, name, latitude, longitude, radius_meters FROM known_places ORDER BY name ASC");
  return rows.map((r) => ({
    id: r.id,
    name: r.name,
    latitude: r.latitude,
    longitude: r.longitude,
    radiusMeters: r.radius_meters,
  }));
}

export async function addKnownPlace(
  db: SQLite.SQLiteDatabase,
  name: string,
  latitude: number,
  longitude: number,
  radiusMeters: number,
): Promise<void> {
  await db.runAsync(
    "INSERT INTO known_places (name, latitude, longitude, radius_meters) VALUES (?, ?, ?, ?)",
    [name, latitude, longitude, radiusMeters],
  );
}

export async function deleteKnownPlace(
  db: SQLite.SQLiteDatabase,
  id: number,
): Promise<void> {
  await db.runAsync("DELETE FROM known_places WHERE id = ?", [id]);
}

export async function updateKnownPlace(
  db: SQLite.SQLiteDatabase,
  id: number,
  fields: {
    name?: string;
    latitude?: number;
    longitude?: number;
    radiusMeters?: number;
  },
): Promise<void> {
  const setClauses: string[] = [];
  const params: (string | number)[] = [];

  if (fields.name !== undefined) {
    setClauses.push("name = ?");
    params.push(fields.name);
  }
  if (fields.latitude !== undefined) {
    setClauses.push("latitude = ?");
    params.push(fields.latitude);
  }
  if (fields.longitude !== undefined) {
    setClauses.push("longitude = ?");
    params.push(fields.longitude);
  }
  if (fields.radiusMeters !== undefined) {
    setClauses.push("radius_meters = ?");
    params.push(fields.radiusMeters);
  }

  if (setClauses.length === 0) {
    // No fields to update — silent no-op.
    return;
  }

  params.push(id);
  const sql = `UPDATE known_places SET ${setClauses.join(", ")} WHERE id = ?`;
  await db.runAsync(sql, params);
}

export async function getLocationHistory(
  db: SQLite.SQLiteDatabase,
): Promise<LocationHistoryItem[]> {
  const rows = await db.getAllAsync<LocationHistoryItem>(
    "SELECT latitude, longitude, accuracy, timestamp FROM locations ORDER BY timestamp ASC",
  );
  return rows;
}
