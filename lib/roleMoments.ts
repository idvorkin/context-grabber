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

/**
 * Resolve the journal entry id a moment points at, or null if the moment
 * isn't backed by a journal entry. Two source_ref formats exist in the
 * wild: card-tagged moments store the raw entry id, while auto-emo moments
 * store `journal:<id>`. Non-journal moments use `workout:`/`mindful:`/
 * `place:` prefixes (or null) and resolve to null here.
 */
export function journalEntryIdFromMoment(m: RoleMoment): string | null {
  const ref = m.sourceRef;
  if (!ref) return null;
  if (ref.startsWith("journal:")) return ref.slice("journal:".length);
  if (
    ref.startsWith("workout:") ||
    ref.startsWith("mindful:") ||
    ref.startsWith("place:")
  ) {
    return null;
  }
  // Defensive: auto-detected sources never carry a raw journal id, so a
  // bare ref only ever comes from card tagging.
  if (
    m.source === "auto-workout" ||
    m.source === "auto-mindful" ||
    m.source === "auto-place"
  ) {
    return null;
  }
  return ref;
}

/**
 * Journal entry ids tied to a role, for the Journal's role filter. Walks
 * the role's moments and normalizes every source_ref to an entry id.
 */
export async function getEntryIdsForRole(
  db: SQLite.SQLiteDatabase,
  roleId: RoleId,
): Promise<Set<string>> {
  const rows = await db.getAllAsync<{
    source: RoleMomentSource;
    source_ref: string | null;
  }>(
    `SELECT source, source_ref FROM role_moments WHERE role_id = ?`,
    [roleId],
  );
  const ids = new Set<string>();
  for (const r of rows) {
    const entryId = journalEntryIdFromMoment({
      id: "",
      roleId,
      timestamp: 0,
      what: "",
      tag: null,
      source: r.source,
      sourceRef: r.source_ref,
    });
    if (entryId) ids.add(entryId);
  }
  return ids;
}

/**
 * Map every journal-backed role moment to its entry id, grouping the role
 * ids that point at each entry. Pure — the DB read lives in
 * getRolesByEntry. Powers the Journal's per-row role avatars and the
 * group-by-role view. Moments not backed by a journal entry are skipped.
 */
export function rolesByEntry(
  moments: Pick<RoleMoment, "roleId" | "source" | "sourceRef">[],
): Map<string, Set<RoleId>> {
  const map = new Map<string, Set<RoleId>>();
  for (const m of moments) {
    const entryId = journalEntryIdFromMoment({
      id: "",
      roleId: m.roleId,
      timestamp: 0,
      what: "",
      tag: null,
      source: m.source,
      sourceRef: m.sourceRef,
    });
    if (!entryId) continue;
    let set = map.get(entryId);
    if (!set) {
      set = new Set<RoleId>();
      map.set(entryId, set);
    }
    set.add(m.roleId);
  }
  return map;
}

/**
 * Load the entry-id → role-set map for every journal-backed moment.
 * Thin DB wrapper around rolesByEntry; tolerant callers should catch a
 * missing table the same way the rest of the journal reads do.
 */
export async function getRolesByEntry(
  db: SQLite.SQLiteDatabase,
): Promise<Map<string, Set<RoleId>>> {
  const rows = await db.getAllAsync<{
    role_id: RoleId;
    source: RoleMomentSource;
    source_ref: string | null;
  }>(`SELECT role_id, source, source_ref FROM role_moments`);
  return rolesByEntry(
    rows.map((r) => ({
      roleId: r.role_id,
      source: r.source,
      sourceRef: r.source_ref,
    })),
  );
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

// ─── CloudKit sync helpers ───────────────────────────────────────────────────
// Mirror the journal-sync pattern in lib/cloudkit.ts. The schema already
// carries ck_record_name / ck_change_tag / sync_state from db.ts, so we
// just need the per-row state-machine operations.

export async function getPendingMoments(
  db: SQLite.SQLiteDatabase,
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
      WHERE sync_state = 'pending'
      ORDER BY timestamp ASC`,
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

export async function upsertSyncedMoment(
  db: SQLite.SQLiteDatabase,
  m: RoleMoment,
  ckRecordName: string,
  ckChangeTag: string | null,
): Promise<void> {
  // Server-authoritative insert/update. INSERT OR REPLACE keeps the row's
  // PK stable across devices since id is the CloudKit recordName too.
  await db.runAsync(
    `INSERT OR REPLACE INTO role_moments
       (id, role_id, timestamp, what, tag, source, source_ref,
        ck_record_name, ck_change_tag, sync_state)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced')`,
    [
      m.id,
      m.roleId,
      m.timestamp,
      m.what,
      m.tag,
      m.source,
      m.sourceRef,
      ckRecordName,
      ckChangeTag,
    ],
  );
}

export async function markMomentSynced(
  db: SQLite.SQLiteDatabase,
  id: string,
  ckRecordName: string,
  ckChangeTag: string | null,
): Promise<void> {
  await db.runAsync(
    `UPDATE role_moments
        SET ck_record_name = ?,
            ck_change_tag = ?,
            sync_state = 'synced'
      WHERE id = ?`,
    [ckRecordName, ckChangeTag, id],
  );
}

export async function markMomentFailed(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<void> {
  await db.runAsync(
    `UPDATE role_moments SET sync_state = 'failed' WHERE id = ?`,
    [id],
  );
}

export async function deleteMomentByCloudKitName(
  db: SQLite.SQLiteDatabase,
  ckRecordName: string,
): Promise<void> {
  // Server told us this row is gone — drop it locally too. We match on
  // both columns since freshly-pushed rows use id == recordName, while
  // older rows might only have id set.
  await db.runAsync(
    `DELETE FROM role_moments
      WHERE ck_record_name = ? OR id = ?`,
    [ckRecordName, ckRecordName],
  );
}
