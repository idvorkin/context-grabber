/**
 * Auto-detection of role moments from existing app events. Each helper
 * inserts a row into `role_moments` so the moment shows up in the Roles
 * tab + Larry export without the user having to tag manually.
 *
 * Helpers are idempotent where the upstream event can re-fire — workouts
 * are dedup'd by `source_ref = "workout:<startTime>"`, journal/grateful
 * use the entry id.
 */

import type * as SQLite from "expo-sqlite";
import { insertMoment } from "./roleMoments";
import type { JournalEntry, JournalContext } from "./journal";
import type { WorkoutEntry } from "./health";

async function alreadyRecorded(
  db: SQLite.SQLiteDatabase,
  sourceRef: string,
): Promise<boolean> {
  const row = await db.getFirstAsync<{ id: string }>(
    "SELECT id FROM role_moments WHERE source_ref = ? LIMIT 1",
    [sourceRef],
  );
  return row != null;
}

function whatForJournal(c: JournalContext): string {
  switch (c) {
    case "grateful":
      return "Gratitude";
    case "opportunity":
      return "Morning intention";
    case "didit":
      return "Evening reflection";
  }
}

function sourceForJournal(
  c: JournalContext,
): "auto-grateful" | "auto-journal" {
  return c === "grateful" ? "auto-grateful" : "auto-journal";
}

/**
 * Called after a journal/affirmation/grateful entry is saved. Records an
 * `emo` moment so the role gets credit for the reflection event.
 */
export async function recordJournalMoment(
  db: SQLite.SQLiteDatabase,
  entry: JournalEntry,
): Promise<void> {
  const ref = `journal:${entry.id}`;
  if (await alreadyRecorded(db, ref)) return;
  await insertMoment(db, {
    roleId: "emo",
    timestamp: entry.createdAt,
    what: whatForJournal(entry.context),
    tag: entry.context,
    source: sourceForJournal(entry.context),
    sourceRef: ref,
  });
}

/**
 * Called after grabContext fetches HealthKit workouts. Idempotent — each
 * workout is keyed by its startTime, so re-grabs across the same day
 * don't double-count.
 */
export async function recordWorkoutMoments(
  db: SQLite.SQLiteDatabase,
  workouts: WorkoutEntry[],
): Promise<number> {
  let inserted = 0;
  for (const w of workouts) {
    if (!w.startTime) continue;
    const ref = `workout:${w.startTime}`;
    if (await alreadyRecorded(db, ref)) continue;
    await insertMoment(db, {
      roleId: "fit",
      timestamp: new Date(w.startTime).getTime(),
      what: `${w.activityType} · ${w.durationMinutes}m`,
      tag: w.activityType,
      source: "auto-workout",
      sourceRef: ref,
    });
    inserted += 1;
  }
  return inserted;
}

/**
 * Idempotency key for a HealthKit mindful session — startTime is unique
 * enough for individual sessions. Caller iterates session list.
 */
export async function recordMindfulMoment(
  db: SQLite.SQLiteDatabase,
  args: { startTimeIso: string; minutes: number },
): Promise<void> {
  const ref = `mindful:${args.startTimeIso}`;
  if (await alreadyRecorded(db, ref)) return;
  await insertMoment(db, {
    roleId: "emo",
    timestamp: new Date(args.startTimeIso).getTime(),
    what: `Mindful ${args.minutes}m`,
    tag: "mindful",
    source: "auto-mindful",
    sourceRef: ref,
  });
}
