import * as SQLite from "expo-sqlite";
import { pruneThreshold } from "./location";
import { initCacheTables } from "./healthCache";
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
    INSERT OR IGNORE INTO settings (key, value) VALUES ('schema_version', '1');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('tracking_enabled', 'false');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('retention_days', '30');
  `);
  await initCacheTables(db);
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
