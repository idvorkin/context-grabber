import type * as SQLite from "expo-sqlite";
import type { RoleId } from "./roles";

export type Intention = {
  id: string;
  roleId: RoleId;
  /** YYYY-MM-DD of the Monday of the target week. */
  weekStartDate: string;
  text: string;
  createdAt: number;
};

function newId(): string {
  return `i-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

/** Local-time YYYY-MM-DD of the Monday that contains `now`. */
export function mondayKey(now: Date = new Date()): string {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  const dow = d.getDay(); // 0 = Sun, 1 = Mon, ..., 6 = Sat
  const offset = dow === 0 ? -6 : 1 - dow;
  d.setDate(d.getDate() + offset);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/** Upsert one intention per (role, week). */
export async function setIntention(
  db: SQLite.SQLiteDatabase,
  roleId: RoleId,
  text: string,
  weekStart: string = mondayKey(),
): Promise<void> {
  const id = newId();
  await db.runAsync(
    `INSERT INTO role_intentions (id, role_id, week_start_date, text, created_at, sync_state)
       VALUES (?, ?, ?, ?, ?, 'pending')
     ON CONFLICT(role_id, week_start_date) DO UPDATE SET
       text = excluded.text,
       sync_state = 'pending'`,
    [id, roleId, weekStart, text, Date.now()],
  );
}

export async function getIntentionsForWeek(
  db: SQLite.SQLiteDatabase,
  weekStart: string,
): Promise<Intention[]> {
  const rows = await db.getAllAsync<{
    id: string;
    role_id: RoleId;
    week_start_date: string;
    text: string;
    created_at: number;
  }>(
    `SELECT id, role_id, week_start_date, text, created_at
       FROM role_intentions
      WHERE week_start_date = ?
      ORDER BY created_at ASC`,
    [weekStart],
  );
  return rows.map((r) => ({
    id: r.id,
    roleId: r.role_id,
    weekStartDate: r.week_start_date,
    text: r.text,
    createdAt: r.created_at,
  }));
}

export async function getCurrentWeekIntentions(
  db: SQLite.SQLiteDatabase,
): Promise<Intention[]> {
  return getIntentionsForWeek(db, mondayKey());
}
