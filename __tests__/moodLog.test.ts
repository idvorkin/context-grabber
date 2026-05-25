/**
 * Unit tests for lib/moodLog.ts. Uses a hand-rolled mock SQLite db that
 * records each runAsync/getFirstAsync/getAllAsync call so we can assert on
 * SQL shape + params without depending on expo-sqlite at runtime.
 */

import {
  logMood,
  getMoodForDate,
  getMoodRange,
  getPendingMoods,
  markMoodSynced,
  upsertSyncedMood,
  markMoodFailed,
  todayDateKey,
  type MoodEntry,
} from "../lib/moodLog";

type SqlCall = { sql: string; params: unknown[] };

function makeMockDb(opts: {
  firstRow?: unknown;
  allRows?: unknown[];
} = {}) {
  const calls: SqlCall[] = [];
  const db = {
    runAsync: jest.fn(async (sql: string, params: unknown[] = []) => {
      calls.push({ sql, params });
      return { changes: 1, lastInsertRowId: 0 };
    }),
    getFirstAsync: jest.fn(async (sql: string, params: unknown[] = []) => {
      calls.push({ sql, params });
      return opts.firstRow ?? null;
    }),
    getAllAsync: jest.fn(async (sql: string, params: unknown[] = []) => {
      calls.push({ sql, params });
      return opts.allRows ?? [];
    }),
    execAsync: jest.fn(async () => undefined),
  } as any;
  return { db, calls };
}

describe("todayDateKey", () => {
  it("returns YYYY-MM-DD for the given date in local time", () => {
    const d = new Date(2026, 4, 25); // May 25, 2026 (month is 0-indexed)
    expect(todayDateKey(d)).toBe("2026-05-25");
  });

  it("pads single-digit months and days with leading zeros", () => {
    const d = new Date(2026, 0, 3); // Jan 3
    expect(todayDateKey(d)).toBe("2026-01-03");
  });
});

describe("logMood", () => {
  it("issues an INSERT ON CONFLICT upsert with sync_state=pending", async () => {
    const { db, calls } = makeMockDb();
    const entry: MoodEntry = {
      date: "2026-05-25",
      mood: 4,
      energy: 3,
      note: "good day",
    };
    await logMood(db, entry);

    expect(calls.length).toBe(1);
    expect(calls[0].sql).toMatch(/INSERT INTO mood_log/);
    expect(calls[0].sql).toMatch(/ON CONFLICT\(date\) DO UPDATE/);
    expect(calls[0].sql).toMatch(/sync_state = 'pending'/);
    expect(calls[0].params).toEqual(["2026-05-25", 3, 4, "good day"]);
  });

  it("persists null note when no text provided", async () => {
    const { db, calls } = makeMockDb();
    await logMood(db, {
      date: "2026-05-25",
      mood: 5,
      energy: 5,
      note: null,
    });
    expect(calls[0].params).toEqual(["2026-05-25", 5, 5, null]);
  });
});

describe("getMoodForDate", () => {
  it("returns the row when present", async () => {
    const row: MoodEntry = {
      date: "2026-05-25",
      mood: 4,
      energy: 3,
      note: null,
    };
    const { db, calls } = makeMockDb({ firstRow: row });
    const out = await getMoodForDate(db, "2026-05-25");
    expect(out).toEqual(row);
    expect(calls[0].sql).toMatch(/SELECT date, energy, mood, note/);
    expect(calls[0].params).toEqual(["2026-05-25"]);
  });

  it("returns null when no row exists", async () => {
    const { db } = makeMockDb({ firstRow: null });
    const out = await getMoodForDate(db, "1999-01-01");
    expect(out).toBeNull();
  });
});

describe("getMoodRange", () => {
  it("queries ordered DESC and limits to the requested count", async () => {
    const rows: MoodEntry[] = [
      { date: "2026-05-25", mood: 4, energy: 3, note: null },
      { date: "2026-05-24", mood: 3, energy: 3, note: null },
    ];
    const { db, calls } = makeMockDb({ allRows: rows });
    const out = await getMoodRange(db, 7);
    expect(out).toEqual(rows);
    expect(calls[0].sql).toMatch(/ORDER BY date DESC/);
    expect(calls[0].params).toEqual([7]);
  });
});

describe("getPendingMoods", () => {
  it("returns mapped pending rows (camelCase sync fields)", async () => {
    const dbRows = [
      {
        date: "2026-05-25",
        energy: 3,
        mood: 4,
        note: "x",
        ck_record_name: null,
        ck_change_tag: null,
        sync_state: "pending",
      },
    ];
    const { db, calls } = makeMockDb({ allRows: dbRows });
    const out = await getPendingMoods(db);
    expect(out).toEqual([
      {
        date: "2026-05-25",
        energy: 3,
        mood: 4,
        note: "x",
        ckRecordName: null,
        ckChangeTag: null,
        syncState: "pending",
      },
    ]);
    expect(calls[0].sql).toMatch(/sync_state IN \('pending', 'failed'\)/);
  });
});

describe("markMoodSynced", () => {
  it("flips sync_state to synced and stores CK metadata", async () => {
    const { db, calls } = makeMockDb();
    await markMoodSynced(db, "2026-05-25", "ck-record-1", "ct-1");
    expect(calls[0].sql).toMatch(/SET ck_record_name = \?, ck_change_tag = \?, sync_state = 'synced'/);
    expect(calls[0].params).toEqual(["ck-record-1", "ct-1", "2026-05-25"]);
  });
});

describe("upsertSyncedMood", () => {
  it("upserts and sets sync_state to 'synced'", async () => {
    const { db, calls } = makeMockDb();
    await upsertSyncedMood(
      db,
      { date: "2026-05-25", mood: 4, energy: 3, note: "n" },
      "ck-record-1",
      "ct-1",
    );
    expect(calls[0].sql).toMatch(/INSERT INTO mood_log/);
    expect(calls[0].sql).toMatch(/sync_state = 'synced'/);
    expect(calls[0].params).toEqual([
      "2026-05-25",
      3,
      4,
      "n",
      "ck-record-1",
      "ct-1",
    ]);
  });
});

describe("markMoodFailed", () => {
  it("sets sync_state to 'failed' for the row", async () => {
    const { db, calls } = makeMockDb();
    await markMoodFailed(db, "2026-05-25");
    expect(calls[0].sql).toMatch(/SET sync_state = 'failed'/);
    expect(calls[0].params).toEqual(["2026-05-25"]);
  });
});
