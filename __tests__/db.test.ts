/**
 * Tests for lib/db.ts helpers.
 *
 * Uses a simple hand-rolled mock of SQLiteDatabase that records runAsync
 * calls. expo-sqlite itself is mocked to avoid pulling in native modules
 * in the node test environment.
 */

// Mock expo-sqlite before importing anything that transitively loads it.
jest.mock("expo-sqlite", () => ({
  openDatabaseAsync: jest.fn(),
}));

import { updateKnownPlace } from "../lib/db";

type RunCall = { sql: string; params: unknown[] };

function makeMockDb() {
  const calls: RunCall[] = [];
  const db = {
    runAsync: jest.fn(async (sql: string, params: unknown[] = []) => {
      calls.push({ sql, params });
      return { changes: 0, lastInsertRowId: 0 };
    }),
    // Unused by updateKnownPlace but keeps the shape plausible.
    getFirstAsync: jest.fn(),
    getAllAsync: jest.fn(),
    execAsync: jest.fn(),
  };
  // Cast to unknown→SQLiteDatabase at call sites.
  return { db, calls };
}

describe("updateKnownPlace", () => {
  it("updates only radiusMeters with a single-column UPDATE", async () => {
    const { db, calls } = makeMockDb();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await updateKnownPlace(db as any, 42, { radiusMeters: 175 });

    expect(calls).toHaveLength(1);
    expect(calls[0].sql).toBe(
      "UPDATE known_places SET radius_meters = ? WHERE id = ?",
    );
    expect(calls[0].params).toEqual([175, 42]);
  });

  it("updates only name", async () => {
    const { db, calls } = makeMockDb();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await updateKnownPlace(db as any, 7, { name: "Home" });

    expect(calls).toHaveLength(1);
    expect(calls[0].sql).toBe(
      "UPDATE known_places SET name = ? WHERE id = ?",
    );
    expect(calls[0].params).toEqual(["Home", 7]);
  });

  it("updates multiple fields in a single statement", async () => {
    const { db, calls } = makeMockDb();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await updateKnownPlace(db as any, 3, {
      name: "Office",
      latitude: 47.6205,
      longitude: -122.3493,
      radiusMeters: 150,
    });

    expect(calls).toHaveLength(1);
    expect(calls[0].sql).toBe(
      "UPDATE known_places SET name = ?, latitude = ?, longitude = ?, radius_meters = ? WHERE id = ?",
    );
    expect(calls[0].params).toEqual([
      "Office",
      47.6205,
      -122.3493,
      150,
      3,
    ]);
  });

  it("updates lat/lng without touching name or radius", async () => {
    const { db, calls } = makeMockDb();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await updateKnownPlace(db as any, 9, {
      latitude: 47.61,
      longitude: -122.33,
    });

    expect(calls).toHaveLength(1);
    expect(calls[0].sql).toBe(
      "UPDATE known_places SET latitude = ?, longitude = ? WHERE id = ?",
    );
    expect(calls[0].params).toEqual([47.61, -122.33, 9]);
  });

  it("is a no-op when fields is empty", async () => {
    const { db, calls } = makeMockDb();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await updateKnownPlace(db as any, 1, {});

    expect(calls).toHaveLength(0);
    expect(db.runAsync).not.toHaveBeenCalled();
  });

  it("does not throw for a non-existent id (0 rows affected is fine)", async () => {
    const { db, calls } = makeMockDb();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await expect(
      updateKnownPlace(db as any, 99999, { radiusMeters: 200 }),
    ).resolves.toBeUndefined();

    expect(calls).toHaveLength(1);
    expect(calls[0].params).toEqual([200, 99999]);
  });
});
