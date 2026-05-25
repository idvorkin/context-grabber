import type * as SQLite from "expo-sqlite";

export type MoodScore = 1 | 2 | 3 | 4 | 5;

export type MoodEntry = {
  /** Local-time YYYY-MM-DD. One entry per date. */
  date: string;
  energy: MoodScore;
  mood: MoodScore;
  note: string | null;
};

export type MoodEntryWithSync = MoodEntry & {
  ckRecordName: string | null;
  ckChangeTag: string | null;
  syncState: "pending" | "synced" | "failed";
};

export function todayDateKey(now: Date = new Date()): string {
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/** Upsert one mood entry. Marks sync_state = 'pending' so the next sync pushes it. */
export async function logMood(
  db: SQLite.SQLiteDatabase,
  entry: MoodEntry,
): Promise<void> {
  await db.runAsync(
    `INSERT INTO mood_log (date, energy, mood, note, sync_state)
       VALUES (?, ?, ?, ?, 'pending')
     ON CONFLICT(date) DO UPDATE SET
       energy = excluded.energy,
       mood = excluded.mood,
       note = excluded.note,
       sync_state = 'pending'`,
    [entry.date, entry.energy, entry.mood, entry.note],
  );
}

export async function getMoodForDate(
  db: SQLite.SQLiteDatabase,
  date: string,
): Promise<MoodEntry | null> {
  const row = await db.getFirstAsync<MoodEntry>(
    "SELECT date, energy, mood, note FROM mood_log WHERE date = ?",
    [date],
  );
  return row ?? null;
}

/** Most recent `days` entries, newest first. */
export async function getMoodRange(
  db: SQLite.SQLiteDatabase,
  days: number,
): Promise<MoodEntry[]> {
  const rows = await db.getAllAsync<MoodEntry>(
    "SELECT date, energy, mood, note FROM mood_log ORDER BY date DESC LIMIT ?",
    [days],
  );
  return rows;
}

/** Rows awaiting push to CloudKit. */
export async function getPendingMoods(
  db: SQLite.SQLiteDatabase,
): Promise<MoodEntryWithSync[]> {
  const rows = await db.getAllAsync<{
    date: string;
    energy: MoodScore;
    mood: MoodScore;
    note: string | null;
    ck_record_name: string | null;
    ck_change_tag: string | null;
    sync_state: "pending" | "synced" | "failed";
  }>(
    `SELECT date, energy, mood, note, ck_record_name, ck_change_tag, sync_state
       FROM mood_log
      WHERE sync_state IN ('pending', 'failed')
      ORDER BY date ASC`,
  );
  return rows.map((r) => ({
    date: r.date,
    energy: r.energy,
    mood: r.mood,
    note: r.note,
    ckRecordName: r.ck_record_name,
    ckChangeTag: r.ck_change_tag,
    syncState: r.sync_state,
  }));
}

/** Mark a row as synced after a successful CloudKit push. */
export async function markMoodSynced(
  db: SQLite.SQLiteDatabase,
  date: string,
  ckRecordName: string,
  ckChangeTag: string | null,
): Promise<void> {
  await db.runAsync(
    `UPDATE mood_log
        SET ck_record_name = ?, ck_change_tag = ?, sync_state = 'synced'
      WHERE date = ?`,
    [ckRecordName, ckChangeTag, date],
  );
}

/** Insert/update from a CloudKit pull. Marks sync_state = 'synced'. */
export async function upsertSyncedMood(
  db: SQLite.SQLiteDatabase,
  entry: MoodEntry,
  ckRecordName: string,
  ckChangeTag: string | null,
): Promise<void> {
  await db.runAsync(
    `INSERT INTO mood_log (date, energy, mood, note, ck_record_name, ck_change_tag, sync_state)
       VALUES (?, ?, ?, ?, ?, ?, 'synced')
     ON CONFLICT(date) DO UPDATE SET
       energy = excluded.energy,
       mood = excluded.mood,
       note = excluded.note,
       ck_record_name = excluded.ck_record_name,
       ck_change_tag = excluded.ck_change_tag,
       sync_state = 'synced'`,
    [entry.date, entry.energy, entry.mood, entry.note, ckRecordName, ckChangeTag],
  );
}

/** Mark sync_state = 'failed' on a date so the next push retries it. */
export async function markMoodFailed(
  db: SQLite.SQLiteDatabase,
  date: string,
): Promise<void> {
  await db.runAsync(
    "UPDATE mood_log SET sync_state = 'failed' WHERE date = ?",
    [date],
  );
}
