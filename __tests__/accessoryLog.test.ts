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
  accessoryDayLabel,
  groupAccessoryLog,
  initAccessoryLogTable,
  logAccessoryItems,
  getAccessoryLog,
  type AccessoryLogEntry,
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

describe("accessoryDayLabel", () => {
  const now = new Date(2026, 8, 12, 15, 0); // Sat Sep 12
  it("today and yesterday by name", () => {
    expect(accessoryDayLabel("2026-09-12", now)).toBe("Today");
    expect(accessoryDayLabel("2026-09-11", now)).toBe("Yesterday");
  });
  it("older days carry the weekday and date", () => {
    expect(accessoryDayLabel("2026-09-08", now)).toBe("Tue Sep 8");
    expect(accessoryDayLabel("2026-08-31", now)).toBe("Mon Aug 31");
  });
  it("yesterday across a month boundary", () => {
    expect(accessoryDayLabel("2026-08-31", new Date(2026, 8, 1, 9, 0))).toBe("Yesterday");
  });
});

describe("groupAccessoryLog", () => {
  const now = new Date(2026, 8, 12, 18, 0);
  const at = (y: number, m: number, d: number, h: number, min: number) => new Date(y, m - 1, d, h, min).getTime();
  const entry = (id: number, itemName: string, loggedAt: number): AccessoryLogEntry => ({
    id,
    itemId: itemName.toLowerCase().replace(/ /g, "_"),
    itemName,
    loggedAt,
    dateKey: accessoryDateKey(new Date(loggedAt)),
  });

  it("empty in, empty out", () => {
    expect(groupAccessoryLog([], now)).toEqual([]);
  });

  it("one save with two items is one line under Today, items in checklist order", () => {
    const t = at(2026, 9, 12, 15, 12);
    const days = groupAccessoryLog([entry(1, "Half Lotus", t), entry(2, "Dead Hangs", t)], now);
    expect(days).toEqual([
      { dateKey: "2026-09-12", label: "Today", sessions: [{ loggedAt: t, time: "3:12pm", items: ["Half Lotus", "Dead Hangs"] }] },
    ]);
  });

  it("days newest first, saves within a day newest first, regardless of input order", () => {
    const morning = at(2026, 9, 12, 7, 30);
    const evening = at(2026, 9, 12, 17, 0);
    const yesterday = at(2026, 9, 11, 8, 0);
    const lastWeek = at(2026, 9, 8, 12, 0);
    const days = groupAccessoryLog(
      [entry(1, "Pigeon Stretch", lastWeek), entry(2, "Half Lotus", morning), entry(3, "McGill Big 3", yesterday), entry(4, "Dead Hangs", evening)],
      now,
    );
    expect(days.map((d) => d.label)).toEqual(["Today", "Yesterday", "Tue Sep 8"]);
    expect(days[0].sessions.map((s) => s.time)).toEqual(["5pm", "7:30am"]);
    expect(days[0].sessions[0].items).toEqual(["Dead Hangs"]);
    expect(days[1].sessions[0].items).toEqual(["McGill Big 3"]);
    expect(days[2].sessions[0].items).toEqual(["Pigeon Stretch"]);
  });

  it("round-trips through the store: what was saved is what is grouped", async () => {
    const { db } = makeStatefulDb();
    const t = at(2026, 9, 12, 15, 12);
    await logAccessoryItems(db as any, ["half_lotus", "dead_hangs"], t);
    const days = groupAccessoryLog(await getAccessoryLog(db as any), now);
    expect(days).toHaveLength(1);
    expect(days[0].sessions[0].items).toEqual(["Half Lotus", "Dead Hangs"]);
  });
});
