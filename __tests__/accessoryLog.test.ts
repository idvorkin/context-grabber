/**
 * Unit tests for lib/gym/accessoryLog.ts.
 *
 * Uses a small STATEFUL mock SQLite db that actually stores inserted rows
 * and returns them from getAllAsync, so save → read-back is a genuine
 * round-trip through the store's param mapping + row mapping (not just a
 * SQL-shape assertion). expo-sqlite itself is a type-only import in the
 * module under test, so nothing native is loaded.
 */

import {
  ACCESSORY_ITEMS,
  accessoryDateKey,
  initAccessoryLogTable,
  logAccessoryItems,
  getAccessoryLog,
} from "../lib/gym/accessoryLog";

type Row = {
  id: number;
  item_id: string;
  item_name: string;
  logged_at: number;
  date_key: string;
};

/** In-memory fake that understands exactly the SQL accessoryLog issues. */
function makeStatefulDb() {
  const rows: Row[] = [];
  let nextId = 1;
  const db = {
    execAsync: jest.fn(async () => undefined),
    runAsync: jest.fn(async (sql: string, params: unknown[] = []) => {
      if (/INSERT\s+INTO\s+accessory_log/i.test(sql)) {
        const [item_id, item_name, logged_at, date_key] = params as [
          string,
          string,
          number,
          string,
        ];
        rows.push({ id: nextId++, item_id, item_name, logged_at, date_key });
      }
      return { changes: 1, lastInsertRowId: nextId - 1 };
    }),
    getAllAsync: jest.fn(async (sql: string, params: unknown[] = []) => {
      let out = [...rows];
      if (/WHERE\s+logged_at\s*>=\s*\?/i.test(sql)) {
        const since = params[0] as number;
        out = out.filter((r) => r.logged_at >= since);
      }
      // Query orders by logged_at DESC.
      out.sort((a, b) => b.logged_at - a.logged_at);
      return out;
    }),
    getFirstAsync: jest.fn(),
  };
  return { db, rows };
}

describe("accessoryDateKey", () => {
  it("returns YYYY-MM-DD in local time", () => {
    expect(accessoryDateKey(new Date(2026, 8, 12, 10, 30))).toBe("2026-09-12");
  });
  it("zero-pads single-digit month and day", () => {
    expect(accessoryDateKey(new Date(2026, 0, 3))).toBe("2026-01-03");
  });
});

describe("ACCESSORY_ITEMS", () => {
  it("contains exactly the four accessory items with stable ids", () => {
    expect(ACCESSORY_ITEMS.map((i) => i.label)).toEqual([
      "Half Lotus",
      "McGill Big 3",
      "Pigeon Stretch",
      "Dead Hangs",
    ]);
    expect(ACCESSORY_ITEMS.map((i) => i.id)).toEqual([
      "half_lotus",
      "mcgill_big_3",
      "pigeon_stretch",
      "dead_hangs",
    ]);
  });
});

describe("initAccessoryLogTable", () => {
  it("issues a single CREATE TABLE/INDEX exec", async () => {
    const { db } = makeStatefulDb();
    await initAccessoryLogTable(db as any);
    expect(db.execAsync).toHaveBeenCalledTimes(1);
    const sql = (db.execAsync as jest.Mock).mock.calls[0][0] as string;
    expect(sql).toMatch(/CREATE TABLE IF NOT EXISTS accessory_log/);
    expect(sql).toMatch(/idx_accessory_log_time/);
  });
});

describe("logAccessoryItems + getAccessoryLog round-trip", () => {
  it("saves checked items and reads them back with timestamps", async () => {
    const { db } = makeStatefulDb();
    const at = Date.UTC(2026, 8, 12, 17, 5, 0); // fixed instant
    await logAccessoryItems(db as any, ["half_lotus", "dead_hangs"], at);

    const entries = await getAccessoryLog(db as any);
    expect(entries).toHaveLength(2);
    // Both share the same logged_at and derived local date_key.
    for (const e of entries) {
      expect(e.loggedAt).toBe(at);
      expect(e.dateKey).toBe(accessoryDateKey(new Date(at)));
      expect(typeof e.id).toBe("number");
    }
    // Names resolved from the config, not the raw ids.
    expect(entries.map((e) => e.itemName).sort()).toEqual([
      "Dead Hangs",
      "Half Lotus",
    ]);
    expect(entries.map((e) => e.itemId).sort()).toEqual([
      "dead_hangs",
      "half_lotus",
    ]);
  });

  it("records ONLY the checked items (subset persists, others do not)", async () => {
    const { db } = makeStatefulDb();
    // User checked 2 of 4 items; the UI hands the store exactly those ids.
    await logAccessoryItems(db as any, ["half_lotus", "pigeon_stretch"]);

    const names = (await getAccessoryLog(db as any)).map((e) => e.itemName);
    expect(names).toContain("Half Lotus");
    expect(names).toContain("Pigeon Stretch");
    expect(names).not.toContain("McGill Big 3");
    expect(names).not.toContain("Dead Hangs");
  });

  it("skips unknown item ids rather than persisting junk", async () => {
    const { db } = makeStatefulDb();
    await logAccessoryItems(db as any, ["half_lotus", "bogus_item"]);

    const entries = await getAccessoryLog(db as any);
    expect(entries).toHaveLength(1);
    expect(entries[0].itemId).toBe("half_lotus");
  });

  it("is a no-op for an empty checklist", async () => {
    const { db } = makeStatefulDb();
    await logAccessoryItems(db as any, []);
    expect(db.runAsync).not.toHaveBeenCalled();
    expect(await getAccessoryLog(db as any)).toEqual([]);
  });

  it("filters by sinceMs when provided", async () => {
    const { db } = makeStatefulDb();
    const old = Date.UTC(2026, 8, 1, 12, 0, 0);
    const recent = Date.UTC(2026, 8, 12, 12, 0, 0);
    await logAccessoryItems(db as any, ["half_lotus"], old);
    await logAccessoryItems(db as any, ["dead_hangs"], recent);

    const cutoff = Date.UTC(2026, 8, 10, 0, 0, 0);
    const entries = await getAccessoryLog(db as any, cutoff);
    expect(entries).toHaveLength(1);
    expect(entries[0].itemName).toBe("Dead Hangs");
    expect(entries[0].loggedAt).toBe(recent);
  });

  it("returns entries newest-first", async () => {
    const { db } = makeStatefulDb();
    const t1 = Date.UTC(2026, 8, 12, 8, 0, 0);
    const t2 = Date.UTC(2026, 8, 12, 9, 0, 0);
    await logAccessoryItems(db as any, ["half_lotus"], t1);
    await logAccessoryItems(db as any, ["dead_hangs"], t2);

    const entries = await getAccessoryLog(db as any);
    expect(entries.map((e) => e.loggedAt)).toEqual([t2, t1]);
  });
});
