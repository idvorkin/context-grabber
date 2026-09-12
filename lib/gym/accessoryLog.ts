/**
 * Accessory / mobility work log, backed by SQLite.
 *
 * Records the small accessory pieces done around a gym-timer workout
 * (half lotus, McGill Big 3, pigeon stretch, dead hangs) so the coaching
 * export can see which mobility work actually happened. One row per logged
 * item; a single "Save" tap writes all checked items with the same timestamp.
 *
 * Storage conventions (see CLAUDE.md):
 *   • `logged_at` is UTC unix milliseconds.
 *   • `date_key` is the LOCAL calendar day (YYYY-MM-DD) of the save.
 *   • Export converts `logged_at` → ISO-8601 UTC (in lib/share.ts).
 */

import type { SQLiteDatabase } from "expo-sqlite";

export type AccessoryItemDef = {
  /** Stable storage key — append-only. Renaming an id orphans historical rows. */
  id: string;
  /** Human-readable label shown in the checklist and used in the export. */
  label: string;
};

/**
 * The accessory items offered in the post-workout checklist.
 *
 * Single source of truth — edit this list to add or rename items. The `id`
 * is the persisted key and must stay stable; only the `label` is safe to
 * change freely.
 */
export const ACCESSORY_ITEMS: readonly AccessoryItemDef[] = [
  { id: "half_lotus", label: "Half Lotus" },
  { id: "mcgill_big_3", label: "McGill Big 3" },
  { id: "pigeon_stretch", label: "Pigeon Stretch" },
  { id: "dead_hangs", label: "Dead Hangs" },
];

const ITEM_BY_ID: Map<string, AccessoryItemDef> = new Map(
  ACCESSORY_ITEMS.map((it) => [it.id, it]),
);

export type AccessoryLogEntry = {
  id: number;
  itemId: string;
  itemName: string;
  /** UTC unix milliseconds. */
  loggedAt: number;
  /** Local calendar day, "YYYY-MM-DD". */
  dateKey: string;
};

/**
 * Create the accessory_log table. Idempotent — safe to call on every boot.
 * Schema is additive-only by policy; never drop or rename columns here.
 */
export async function initAccessoryLogTable(
  db: SQLiteDatabase,
): Promise<void> {
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS accessory_log (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id   TEXT NOT NULL,
      item_name TEXT NOT NULL,
      logged_at INTEGER NOT NULL,
      date_key  TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_accessory_log_time ON accessory_log(logged_at);
  `);
}

/** Local calendar day (YYYY-MM-DD) for a given instant. */
export function accessoryDateKey(now: Date = new Date()): string {
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * Record the checked accessory items as a single session.
 *
 * Every checked item that maps to a known {@link ACCESSORY_ITEMS} entry is
 * written as its own row, all sharing the one `loggedAt` timestamp and its
 * derived local `date_key`. Unknown ids are skipped. An empty list is a no-op.
 */
export async function logAccessoryItems(
  db: SQLiteDatabase,
  itemIds: string[],
  loggedAt: number = Date.now(),
): Promise<void> {
  const dateKey = accessoryDateKey(new Date(loggedAt));
  for (const itemId of itemIds) {
    const def = ITEM_BY_ID.get(itemId);
    if (!def) continue; // ignore unknown ids rather than persist junk
    await db.runAsync(
      `INSERT INTO accessory_log (item_id, item_name, logged_at, date_key)
       VALUES (?, ?, ?, ?)`,
      [def.id, def.label, loggedAt, dateKey],
    );
  }
}

type AccessoryRow = {
  id: number;
  item_id: string;
  item_name: string;
  logged_at: number;
  date_key: string;
};

function rowToEntry(r: AccessoryRow): AccessoryLogEntry {
  return {
    id: r.id,
    itemId: r.item_id,
    itemName: r.item_name,
    loggedAt: r.logged_at,
    dateKey: r.date_key,
  };
}

/**
 * Read logged accessory items, newest first. Pass `sinceMs` to limit to
 * entries logged at or after that instant (e.g. the last 7 days for export).
 */
export async function getAccessoryLog(
  db: SQLiteDatabase,
  sinceMs?: number,
): Promise<AccessoryLogEntry[]> {
  if (sinceMs != null) {
    const rows = await db.getAllAsync<AccessoryRow>(
      `SELECT id, item_id, item_name, logged_at, date_key
         FROM accessory_log
        WHERE logged_at >= ?
        ORDER BY logged_at DESC`,
      [sinceMs],
    );
    return rows.map(rowToEntry);
  }
  const rows = await db.getAllAsync<AccessoryRow>(
    `SELECT id, item_id, item_name, logged_at, date_key
       FROM accessory_log
      ORDER BY logged_at DESC`,
  );
  return rows.map(rowToEntry);
}
