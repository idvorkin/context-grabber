/**
 * Tests for lib/counter.ts. Uses an in-memory map as a stand-in for the SQLite
 * settings store; the real `getSetting`/`setSetting` from lib/db are not
 * exercised here — those are thin wrappers tested elsewhere.
 */
import { todayLocalDateKey, getCounter, incrementCounter, resetCounter, reconcileFromWidget } from "../lib/counter";

// Minimal mock of the (key, value) store that lib/counter persists through.
function makeFakeDb() {
  const store = new Map<string, string>();
  return {
    store,
    db: {} as never, // shape doesn't matter; we mock the helpers below
  };
}

// Patch lib/db's getSetting/setSetting via Jest's module mock.
jest.mock("../lib/db", () => {
  const store = new Map<string, string>();
  return {
    __esModule: true,
    __store: store,
    getSetting: jest.fn(async (_db: unknown, key: string, fallback: string) => {
      return store.has(key) ? store.get(key)! : fallback;
    }),
    setSetting: jest.fn(async (_db: unknown, key: string, value: string) => {
      store.set(key, value);
    }),
  };
});

const { __store } = jest.requireMock("../lib/db") as { __store: Map<string, string> };

beforeEach(() => {
  __store.clear();
});

describe("todayLocalDateKey", () => {
  it("formats as YYYY-MM-DD with zero-padding", () => {
    expect(todayLocalDateKey(new Date(2026, 0, 1))).toBe("2026-01-01");
    expect(todayLocalDateKey(new Date(2026, 11, 9))).toBe("2026-12-09");
  });

  it("uses local time, not UTC", () => {
    // Month index 3 = April. This is constructed in local time.
    expect(todayLocalDateKey(new Date(2026, 3, 25, 23, 30))).toBe("2026-04-25");
  });
});

describe("getCounter", () => {
  it("returns 0 with today's date on first read", async () => {
    const result = await getCounter({} as never);
    expect(result.value).toBe(0);
    expect(result.dateKey).toBe(todayLocalDateKey());
  });

  it("returns persisted value when reset date matches today", async () => {
    const today = todayLocalDateKey();
    __store.set("counter_value", "7");
    __store.set("counter_reset_date", today);
    const result = await getCounter({} as never);
    expect(result.value).toBe(7);
    expect(result.dateKey).toBe(today);
  });

  it("auto-resets to 0 when stored date is from yesterday (or older)", async () => {
    __store.set("counter_value", "12");
    __store.set("counter_reset_date", "2025-01-01"); // long ago
    const result = await getCounter({} as never);
    expect(result.value).toBe(0);
    expect(result.dateKey).toBe(todayLocalDateKey());
    // Reset is durable.
    expect(__store.get("counter_value")).toBe("0");
    expect(__store.get("counter_reset_date")).toBe(todayLocalDateKey());
  });
});

describe("incrementCounter", () => {
  it("increments from 0 to 1 on first call of the day", async () => {
    const result = await incrementCounter({} as never);
    expect(result.value).toBe(1);
    expect(__store.get("counter_value")).toBe("1");
  });

  it("increments sequential calls within the same day", async () => {
    const r1 = await incrementCounter({} as never);
    const r2 = await incrementCounter({} as never);
    const r3 = await incrementCounter({} as never);
    expect(r1.value).toBe(1);
    expect(r2.value).toBe(2);
    expect(r3.value).toBe(3);
  });

  it("auto-resets before incrementing when the stored date is stale", async () => {
    __store.set("counter_value", "99");
    __store.set("counter_reset_date", "2025-01-01");
    const result = await incrementCounter({} as never);
    // Started fresh at 0, then +1.
    expect(result.value).toBe(1);
  });
});

describe("resetCounter", () => {
  it("zeroes a non-zero counter with today's date", async () => {
    __store.set("counter_value", "42");
    __store.set("counter_reset_date", todayLocalDateKey());
    const result = await resetCounter({} as never);
    expect(result.value).toBe(0);
    expect(result.dateKey).toBe(todayLocalDateKey());
  });

  it("is idempotent — resetting twice still yields 0", async () => {
    await incrementCounter({} as never);
    await resetCounter({} as never);
    const result = await resetCounter({} as never);
    expect(result.value).toBe(0);
  });
});

describe("reconcileFromWidget", () => {
  it("adopts the widget's higher value when dates match (widget incremented while app was closed)", async () => {
    const today = todayLocalDateKey();
    __store.set("counter_value", "3");
    __store.set("counter_reset_date", today);
    const result = await reconcileFromWidget({} as never, {
      counter: 7,
      counterDate: today,
    });
    expect(result.value).toBe(7);
    expect(__store.get("counter_value")).toBe("7");
  });

  it("keeps SQLite value when widget value is lower (stale widget snapshot)", async () => {
    const today = todayLocalDateKey();
    __store.set("counter_value", "10");
    __store.set("counter_reset_date", today);
    const result = await reconcileFromWidget({} as never, {
      counter: 4,
      counterDate: today,
    });
    expect(result.value).toBe(10);
  });

  it("ignores widget value when counterDate is yesterday or older", async () => {
    const today = todayLocalDateKey();
    __store.set("counter_value", "5");
    __store.set("counter_reset_date", today);
    const result = await reconcileFromWidget({} as never, {
      counter: 99,
      counterDate: "2024-01-01",
    });
    expect(result.value).toBe(5);
  });

  it("ignores widget when its value or date is null (Android / module missing)", async () => {
    const today = todayLocalDateKey();
    __store.set("counter_value", "2");
    __store.set("counter_reset_date", today);
    const a = await reconcileFromWidget({} as never, { counter: null, counterDate: today });
    expect(a.value).toBe(2);
    const b = await reconcileFromWidget({} as never, { counter: 5, counterDate: null });
    expect(b.value).toBe(2);
  });

  it("works when SQLite is empty — adopts widget value as-is", async () => {
    const today = todayLocalDateKey();
    const result = await reconcileFromWidget({} as never, {
      counter: 11,
      counterDate: today,
    });
    expect(result.value).toBe(11);
  });

  it("applies daily reset before reconciling — widget today wins over stale SQLite yesterday", async () => {
    const today = todayLocalDateKey();
    __store.set("counter_value", "20");
    __store.set("counter_reset_date", "2025-01-01"); // stale
    const result = await reconcileFromWidget({} as never, {
      counter: 3,
      counterDate: today,
    });
    // Local was reset to 0 (stale date), then widget's 3 > 0 → adopt 3.
    expect(result.value).toBe(3);
  });
});
