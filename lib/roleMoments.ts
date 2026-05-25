import type * as SQLite from "expo-sqlite";
import type { RoleId } from "./roles";

export type RoleMomentSource =
  | "manual"
  | "auto-workout"
  | "auto-mindful"
  | "auto-grateful"
  | "auto-journal"
  | "auto-place";

export type RoleMoment = {
  id: string;
  roleId: RoleId;
  /** Unix ms. */
  timestamp: number;
  /** One-line caption. */
  what: string;
  /** Optional sub-tag ("gym", "photo", "date"). */
  tag: string | null;
  source: RoleMomentSource;
  /** Reference into another entity (workout id, journal entry id, etc.). */
  sourceRef: string | null;
};

function newId(): string {
  return `m-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

export async function insertMoment(
  db: SQLite.SQLiteDatabase,
  m: Omit<RoleMoment, "id">,
): Promise<string> {
  const id = newId();
  await db.runAsync(
    `INSERT INTO role_moments (id, role_id, timestamp, what, tag, source, source_ref, sync_state)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      m.roleId,
      m.timestamp,
      m.what,
      m.tag,
      m.source,
      m.sourceRef,
      m.source === "manual" ? "pending" : "synced",
    ],
  );
  return id;
}

export async function getMomentsInRange(
  db: SQLite.SQLiteDatabase,
  from: number,
  to: number,
): Promise<RoleMoment[]> {
  const rows = await db.getAllAsync<{
    id: string;
    role_id: RoleId;
    timestamp: number;
    what: string;
    tag: string | null;
    source: RoleMomentSource;
    source_ref: string | null;
  }>(
    `SELECT id, role_id, timestamp, what, tag, source, source_ref
       FROM role_moments
      WHERE timestamp >= ? AND timestamp < ?
      ORDER BY timestamp DESC`,
    [from, to],
  );
  return rows.map((r) => ({
    id: r.id,
    roleId: r.role_id,
    timestamp: r.timestamp,
    what: r.what,
    tag: r.tag,
    source: r.source,
    sourceRef: r.source_ref,
  }));
}

export async function getMomentsForRole(
  db: SQLite.SQLiteDatabase,
  roleId: RoleId,
  limit: number,
): Promise<RoleMoment[]> {
  const rows = await db.getAllAsync<{
    id: string;
    role_id: RoleId;
    timestamp: number;
    what: string;
    tag: string | null;
    source: RoleMomentSource;
    source_ref: string | null;
  }>(
    `SELECT id, role_id, timestamp, what, tag, source, source_ref
       FROM role_moments
      WHERE role_id = ?
      ORDER BY timestamp DESC
      LIMIT ?`,
    [roleId, limit],
  );
  return rows.map((r) => ({
    id: r.id,
    roleId: r.role_id,
    timestamp: r.timestamp,
    what: r.what,
    tag: r.tag,
    source: r.source,
    sourceRef: r.source_ref,
  }));
}

export async function deleteMoment(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<void> {
  await db.runAsync("DELETE FROM role_moments WHERE id = ?", [id]);
}
