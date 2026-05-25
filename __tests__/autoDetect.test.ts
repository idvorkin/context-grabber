/**
 * Tests for lib/autoDetect.ts — moment-recording helpers + idempotency.
 */

import {
  recordJournalMoment,
  recordWorkoutMoments,
  recordMindfulMoment,
} from "../lib/autoDetect";
import type { JournalEntry } from "../lib/journal";
import type { WorkoutEntry } from "../lib/health";

type SqlCall = { sql: string; params: unknown[] };

function makeMockDb(opts: { existingRefs?: string[] } = {}) {
  const existing = new Set(opts.existingRefs ?? []);
  const calls: SqlCall[] = [];
  const db = {
    runAsync: jest.fn(async (sql: string, params: unknown[] = []) => {
      calls.push({ sql, params });
      // INSERT row records its source_ref so a follow-up alreadyRecorded check
      // finds it.
      if (/INSERT INTO role_moments/.test(sql)) {
        const ref = params[6]; // source_ref column position
        if (typeof ref === "string") existing.add(ref);
      }
      return { changes: 1, lastInsertRowId: 0 };
    }),
    getFirstAsync: jest.fn(async (sql: string, params: unknown[] = []) => {
      calls.push({ sql, params });
      if (/SELECT id FROM role_moments WHERE source_ref/.test(sql)) {
        const ref = params[0];
        return existing.has(String(ref)) ? { id: "stub" } : null;
      }
      return null;
    }),
    getAllAsync: jest.fn(async () => []),
    execAsync: jest.fn(),
  } as any;
  return { db, calls };
}

describe("recordJournalMoment", () => {
  it("inserts an emo moment with source 'auto-grateful' for grateful entries", async () => {
    const { db, calls } = makeMockDb();
    const entry: JournalEntry = {
      id: "j1",
      date: Date.now(),
      context: "grateful",
      affirmationTitle: "",
      text: "thankful for the sun",
      audioRecordingId: null,
      createdAt: Date.now(),
      syncState: "pending",
    } as any;
    await recordJournalMoment(db, entry);
    const insert = calls.find((c) => c.sql.includes("INSERT INTO role_moments"));
    expect(insert).toBeTruthy();
    expect(insert!.params[1]).toBe("emo"); // role_id
    expect(insert!.params[5]).toBe("auto-grateful"); // source
    expect(insert!.params[6]).toBe("journal:j1"); // source_ref
  });

  it("uses 'auto-journal' for non-grateful contexts", async () => {
    const { db, calls } = makeMockDb();
    const entry: JournalEntry = {
      id: "j2",
      date: Date.now(),
      context: "opportunity",
      affirmationTitle: "Be present",
      text: "today I will…",
      audioRecordingId: null,
      createdAt: Date.now(),
      syncState: "pending",
    } as any;
    await recordJournalMoment(db, entry);
    const insert = calls.find((c) => c.sql.includes("INSERT INTO role_moments"));
    expect(insert!.params[5]).toBe("auto-journal");
  });

  it("skips re-recording when the source_ref already exists", async () => {
    const { db, calls } = makeMockDb({ existingRefs: ["journal:dup"] });
    await recordJournalMoment(db, {
      id: "dup",
      date: Date.now(),
      context: "didit",
      affirmationTitle: "",
      text: "x",
      audioRecordingId: null,
      createdAt: Date.now(),
      syncState: "pending",
    } as any);
    const inserts = calls.filter((c) => c.sql.includes("INSERT INTO role_moments"));
    expect(inserts.length).toBe(0);
  });
});

describe("recordWorkoutMoments", () => {
  it("inserts one fit moment per workout, with idempotent source_ref", async () => {
    const { db, calls } = makeMockDb();
    const workouts: WorkoutEntry[] = [
      { activityType: "Running", durationMinutes: 30, energyBurned: 250, distanceKm: 5, startTime: "2026-05-25T07:00:00Z", endTime: "2026-05-25T07:30:00Z" },
      { activityType: "HIIT", durationMinutes: 20, energyBurned: 180, distanceKm: null, startTime: "2026-05-25T18:00:00Z", endTime: "2026-05-25T18:20:00Z" },
    ];
    const inserted = await recordWorkoutMoments(db, workouts);
    expect(inserted).toBe(2);
    const insertCalls = calls.filter((c) => c.sql.includes("INSERT INTO role_moments"));
    expect(insertCalls.length).toBe(2);
    expect(insertCalls[0].params[1]).toBe("fit");
    expect(insertCalls[0].params[5]).toBe("auto-workout");
    expect(insertCalls[0].params[6]).toBe("workout:2026-05-25T07:00:00Z");
  });

  it("skips workouts without a startTime", async () => {
    const { db, calls } = makeMockDb();
    const inserted = await recordWorkoutMoments(db, [
      { activityType: "Walking", durationMinutes: 15, energyBurned: 50, distanceKm: 1.2 },
    ]);
    expect(inserted).toBe(0);
    expect(calls.filter((c) => c.sql.includes("INSERT INTO role_moments")).length).toBe(0);
  });

  it("does not re-insert a workout that was already recorded", async () => {
    const { db } = makeMockDb({ existingRefs: ["workout:2026-05-25T07:00:00Z"] });
    const inserted = await recordWorkoutMoments(db, [
      { activityType: "Running", durationMinutes: 30, energyBurned: 250, distanceKm: 5, startTime: "2026-05-25T07:00:00Z" },
    ]);
    expect(inserted).toBe(0);
  });
});

describe("recordMindfulMoment", () => {
  it("inserts an emo moment with auto-mindful source + idempotent key", async () => {
    const { db, calls } = makeMockDb();
    await recordMindfulMoment(db, {
      startTimeIso: "2026-05-25T08:30:00Z",
      minutes: 12,
    });
    const insert = calls.find((c) => c.sql.includes("INSERT INTO role_moments"));
    expect(insert!.params[1]).toBe("emo");
    expect(insert!.params[5]).toBe("auto-mindful");
    expect(insert!.params[6]).toBe("mindful:2026-05-25T08:30:00Z");
  });
});
