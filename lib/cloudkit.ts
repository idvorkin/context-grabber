import {
  configure,
  getAccountStatus,
  saveRecords,
  fetchRecord,
  createZone,
  fetchRecordZoneChanges,
  deleteRecords,
  downloadAsset,
  type AccountStatus,
  type RecordToSave,
} from "expo-cloudkit";
import * as SQLite from "expo-sqlite";
import type { AudioRecording, JournalEntry } from "./journal";
import { isJournalContext } from "./journal";
import {
  deleteEntry as deleteEntryRow,
  getAudio,
  getPendingAudio,
  getPendingEntries,
  insertAudio,
  markAudioSynced,
  markEntryFailed,
  markEntrySynced,
  upsertSyncedEntry,
} from "./journalDb";
import {
  deleteMomentByCloudKitName,
  getPendingMoments,
  markMomentFailed,
  markMomentSynced,
  upsertSyncedMoment,
  type RoleMoment,
  type RoleMomentSource,
} from "./roleMoments";
import type { RoleId } from "./roles";
import { voiceFilePath } from "./voiceFiles";

const CONTAINER_ID = "iCloud.com.idvorkin.contextgrabber";
const JOURNAL_ZONE = "JournalZone";
const JOURNAL_ENTRY_RECORD_TYPE = "JournalEntry";
const AUDIO_RECORDING_RECORD_TYPE = "AudioRecording";
const ROLE_MOMENTS_ZONE = "RoleMomentsZone";
const ROLE_MOMENT_RECORD_TYPE = "RoleMoment";

const VALID_ROLE_IDS: ReadonlySet<RoleId> = new Set([
  "smiles", "carfree", "habits", "fit", "emo", "tech",
  "pro", "family", "tori", "amelia", "zach",
]);
const VALID_MOMENT_SOURCES: ReadonlySet<RoleMomentSource> = new Set([
  "manual", "auto-workout", "auto-mindful",
  "auto-grateful", "auto-journal", "auto-place",
]);

let configured = false;
let zoneEnsured = false;
let momentZoneEnsured = false;

export function configureCloudKit(): void {
  if (configured) return;
  configure(CONTAINER_ID);
  configured = true;
}

export async function cloudKitAccountStatus(): Promise<AccountStatus> {
  configureCloudKit();
  return getAccountStatus();
}

export type PingResult = {
  ok: true;
  recordName: string;
  echoedTimestamp: number;
  roundTripMs: number;
} | {
  ok: false;
  error: string;
};

/**
 * P0 spike: save a SpikeRecord with `now`, fetch it back, confirm round-trip.
 * Used by the About screen "Ping CloudKit" button.
 */
export async function pingCloudKit(): Promise<PingResult> {
  try {
    configureCloudKit();
    const status = await getAccountStatus();
    if (status !== "available") {
      return { ok: false, error: `account status: ${status}` };
    }

    const now = Date.now();
    const start = now;
    const [saved] = await saveRecords([
      {
        recordType: "SpikeRecord",
        zoneName: "_defaultZone",
        fields: { now: { type: "number", value: now } },
      },
    ]);

    const fetched = await fetchRecord(
      "SpikeRecord",
      saved.recordName,
      "_defaultZone",
    );
    const echoed = fetched.fields.now?.value as number | undefined;
    if (typeof echoed !== "number" || echoed !== now) {
      return { ok: false, error: `echo mismatch: got ${echoed}, expected ${now}` };
    }

    return {
      ok: true,
      recordName: saved.recordName,
      echoedTimestamp: echoed,
      roundTripMs: Date.now() - start,
    };
  } catch (e: any) {
    return { ok: false, error: e?.message ?? String(e) };
  }
}

// ─── Journal sync ──────────────────────────────────────────────────────────
// Source of truth: CloudKit (private DB, JournalZone). SQLite is the local
// mirror + outbound write queue. Sync runs on (a) app foreground and
// (b) after every local write — pull then push so callers see their own
// writes echoed back as `synced`. P1 is text-only; audio (CKAsset) lands
// in P2.

/** Idempotent: create JournalZone the first time, then no-op. */
async function ensureJournalZone(): Promise<void> {
  if (zoneEnsured) return;
  configureCloudKit();
  try {
    await createZone(JOURNAL_ZONE);
  } catch (e: any) {
    // Zone already exists is fine; expo-cloudkit returns a CKError with a
    // recognizable message. Anything else we re-throw.
    const msg = String(e?.message ?? e);
    if (!/already exists/i.test(msg) && !/duplicate/i.test(msg)) {
      throw e;
    }
  }
  zoneEnsured = true;
}

function entryToRecord(entry: JournalEntry): RecordToSave {
  return {
    recordType: JOURNAL_ENTRY_RECORD_TYPE,
    recordName: entry.id,
    zoneName: JOURNAL_ZONE,
    fields: {
      entryId: { type: "string", value: entry.id },
      date: { type: "number", value: entry.date },
      context: { type: "string", value: entry.context },
      affirmationTitle: { type: "string", value: entry.affirmationTitle },
      text: { type: "string", value: entry.text },
      audioRecordId: entry.audioRecordingId
        ? { type: "string", value: entry.audioRecordingId }
        : { type: "string", value: "" },
      createdAtMs: { type: "number", value: entry.createdAt },
    },
  };
}

function recordToEntry(record: {
  recordName: string;
  fields: Record<string, { value: unknown } | undefined>;
}): JournalEntry | null {
  const f = record.fields;
  const id = (f.entryId?.value as string) ?? record.recordName;
  const date = f.date?.value;
  const context = f.context?.value;
  const affirmationTitle = f.affirmationTitle?.value;
  const text = (f.text?.value as string) ?? "";
  const audioId = (f.audioRecordId?.value as string) ?? "";
  const createdAt = f.createdAtMs?.value ?? f.date?.value;

  if (
    typeof date !== "number" ||
    typeof context !== "string" ||
    !isJournalContext(context) ||
    typeof affirmationTitle !== "string" ||
    typeof createdAt !== "number"
  ) {
    return null;
  }
  return {
    id,
    date,
    context,
    affirmationTitle,
    text,
    audioRecordingId: audioId || null,
    createdAt,
  };
}

export type SyncResult = {
  ok: true;
  pulled: number;
  pushed: number;
  deleted: number;
  durationMs: number;
} | {
  ok: false;
  error: string;
  durationMs: number;
};

/**
 * Pull → push for the journal zone. Pull first so that any
 * server-authoritative changes land before we attempt to push our
 * pending mutations on top.
 */
export async function syncJournal(
  db: SQLite.SQLiteDatabase,
): Promise<SyncResult> {
  const start = Date.now();
  try {
    configureCloudKit();
    const status = await getAccountStatus();
    if (status !== "available") {
      return {
        ok: false,
        error: `account status: ${status}`,
        durationMs: Date.now() - start,
      };
    }
    await ensureJournalZone();

    const { upserts, deletes } = await pullJournal(db);
    const { pushed } = await pushJournal(db);
    const { uploaded } = await pushAudio(db);

    return {
      ok: true,
      pulled: upserts,
      pushed: pushed + uploaded,
      deleted: deletes,
      durationMs: Date.now() - start,
    };
  } catch (e: any) {
    return {
      ok: false,
      error: e?.message ?? String(e),
      durationMs: Date.now() - start,
    };
  }
}

async function pullJournal(
  db: SQLite.SQLiteDatabase,
): Promise<{ upserts: number; deletes: number }> {
  // expo-cloudkit persists the per-zone change token natively across calls,
  // so we just call fetchRecordZoneChanges and process the delta. May
  // return moreComing=true; we loop until the server says we're current.
  let upserts = 0;
  let deletes = 0;

  while (true) {
    const result = await fetchRecordZoneChanges([JOURNAL_ZONE]);

    for (const record of result.changedRecords ?? []) {
      if (record.recordType === JOURNAL_ENTRY_RECORD_TYPE) {
        const entry = recordToEntry(record as any);
        if (!entry) continue;
        await upsertSyncedEntry(
          db,
          entry,
          record.recordName,
          (record as any).changeTag ?? null,
        );
        upserts += 1;
      } else if (record.recordType === AUDIO_RECORDING_RECORD_TYPE) {
        // Persist metadata only — the asset itself downloads lazily
        // when the user plays the clip (see ensureAudioLocal).
        const f = (record as any).fields ?? {};
        const id = (f.recordingId?.value as string) ?? record.recordName;
        const durationMs = (f.durationMs?.value as number) ?? 0;
        const createdAt =
          (f.createdAtMs?.value as number) ?? Date.now();
        await insertAudio(db, {
          id,
          filePath: voiceFilePath(id),
          durationMs,
          createdAt,
        });
        // insertAudio leaves sync_state='pending' which would re-upload;
        // mark synced since this came from server.
        await markAudioSynced(
          db,
          id,
          record.recordName,
          (record as any).changeTag ?? null,
        );
        upserts += 1;
      }
    }

    for (const deletedName of result.deletedRecordNames ?? []) {
      await deleteEntryRow(db, deletedName);
      deletes += 1;
    }

    if (!result.moreComing) break;
  }

  return { upserts, deletes };
}

async function pushJournal(
  db: SQLite.SQLiteDatabase,
): Promise<{ pushed: number }> {
  const pending = await getPendingEntries(db);
  if (pending.length === 0) return { pushed: 0 };

  const records = pending.map(entryToRecord);
  let pushed = 0;
  try {
    const saved = await saveRecords(records);
    for (const r of saved) {
      await markEntrySynced(
        db,
        r.recordName,
        r.recordName,
        (r as any).changeTag ?? null,
      );
      pushed += 1;
    }
  } catch (e) {
    // Best-effort: mark whatever didn't make it as failed so the next
    // sync retries them. Re-throw so caller sees the error.
    for (const entry of pending) {
      const saved = await getEntryByRecordName(db, entry.id);
      if (!saved) await markEntryFailed(db, entry.id);
    }
    throw e;
  }

  return { pushed };
}

async function getEntryByRecordName(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<{ sync_state: string } | null> {
  return db.getFirstAsync<{ sync_state: string }>(
    `SELECT sync_state FROM journal_entries WHERE id = ? AND sync_state = 'synced'`,
    [id],
  );
}

// ── Audio (CKAsset) push/pull ───────────────────────────────────────────────

function audioToRecord(audio: AudioRecording): RecordToSave {
  // Asset field uses the AssetField shape ({type: 'asset', fileURL}) per
  // the README; expo-cloudkit's TypeScript only types RecordField, so we
  // cast at the boundary. Confirmed against expo-cloudkit 0.20.8.
  return {
    recordType: AUDIO_RECORDING_RECORD_TYPE,
    recordName: audio.id,
    zoneName: JOURNAL_ZONE,
    fields: {
      recordingId: { type: "string", value: audio.id },
      asset: { type: "asset", fileURL: audio.filePath } as any,
      durationMs: { type: "number", value: audio.durationMs },
      createdAtMs: { type: "number", value: audio.createdAt },
    },
  };
}

async function pushAudio(
  db: SQLite.SQLiteDatabase,
): Promise<{ uploaded: number }> {
  const pending = await getPendingAudio(db);
  if (pending.length === 0) return { uploaded: 0 };

  let uploaded = 0;
  for (const audio of pending) {
    try {
      const [saved] = await saveRecords([audioToRecord(audio)]);
      await markAudioSynced(
        db,
        audio.id,
        saved.recordName,
        (saved as any).changeTag ?? null,
      );
      uploaded += 1;
    } catch (e) {
      // Soft fail per-row so one bad upload doesn't block others. The
      // next sync retries pending rows.
      console.warn("[cloudkit] audio upload failed:", audio.id, e);
    }
  }
  return { uploaded };
}

/**
 * Lazy fetch: download a voice clip from CloudKit on first playback.
 * Returns the local path the file now lives at.
 */
export async function ensureAudioLocal(
  db: SQLite.SQLiteDatabase,
  recordingId: string,
): Promise<string> {
  configureCloudKit();
  const localPath = voiceFilePath(recordingId);

  // Local audio_recordings row may not exist yet if this came from a
  // remote-side entry; query for existence first.
  const row = await getAudio(db, recordingId);

  // Already on disk → fast path.
  const FileSystem = await import("expo-file-system/legacy");
  const info = await FileSystem.getInfoAsync(localPath);
  if (info.exists) return localPath;

  await ensureJournalZone();
  const downloaded = await downloadAsset(
    AUDIO_RECORDING_RECORD_TYPE,
    recordingId,
    "asset",
    localPath,
    JOURNAL_ZONE,
  );

  // Backfill SQLite if this is the first time we've seen it locally.
  if (!row) {
    await insertAudio(db, {
      id: recordingId,
      filePath: localPath,
      durationMs: 0,
      createdAt: Date.now(),
    });
  }

  return downloaded;
}

/** Delete an entry locally and from CloudKit. Used by the Journal screen. */
export async function deleteJournalEntry(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<void> {
  // D1: deleting an entry cascades to its linked role moments, so a role
  // never shows a moment whose underlying reflection is gone.
  await deleteMomentsForEntry(db, id);
  await deleteEntryRow(db, id);
  configureCloudKit();
  const status = await getAccountStatus();
  if (status !== "available") return; // local-only delete is fine; sync later

  await ensureJournalZone();
  try {
    await deleteRecords([{ recordName: id, zoneName: JOURNAL_ZONE }]);
  } catch {
    // If the record never made it to CloudKit, deleteRecords throws —
    // that's fine, the local delete already happened.
  }
}

// ─── Role moments sync ─────────────────────────────────────────────────────
// Same shape as journal sync: CloudKit is the source of truth, SQLite is
// the local mirror + outbound queue. Manual moments push (sync_state =
// pending on insert); auto-* moments insert as already 'synced' since
// they're derived from device-specific signals and shouldn't propagate
// duplicates across devices.

async function ensureRoleMomentsZone(): Promise<void> {
  if (momentZoneEnsured) return;
  configureCloudKit();
  try {
    await createZone(ROLE_MOMENTS_ZONE);
  } catch (e: any) {
    const msg = String(e?.message ?? e);
    if (!/already exists/i.test(msg) && !/duplicate/i.test(msg)) throw e;
  }
  momentZoneEnsured = true;
}

function momentToRecord(m: RoleMoment): RecordToSave {
  return {
    recordType: ROLE_MOMENT_RECORD_TYPE,
    recordName: m.id,
    zoneName: ROLE_MOMENTS_ZONE,
    fields: {
      momentId: { type: "string", value: m.id },
      roleId: { type: "string", value: m.roleId },
      timestamp: { type: "number", value: m.timestamp },
      what: { type: "string", value: m.what },
      tag: { type: "string", value: m.tag ?? "" },
      source: { type: "string", value: m.source },
      sourceRef: { type: "string", value: m.sourceRef ?? "" },
    },
  };
}

function recordToMoment(record: {
  recordName: string;
  fields: Record<string, { value: unknown } | undefined>;
}): RoleMoment | null {
  const f = record.fields;
  const id = (f.momentId?.value as string) ?? record.recordName;
  const roleId = f.roleId?.value;
  const timestamp = f.timestamp?.value;
  const what = (f.what?.value as string) ?? "";
  const tag = (f.tag?.value as string) ?? "";
  const source = f.source?.value;
  const sourceRef = (f.sourceRef?.value as string) ?? "";

  if (
    typeof roleId !== "string" ||
    !VALID_ROLE_IDS.has(roleId as RoleId) ||
    typeof timestamp !== "number" ||
    typeof source !== "string" ||
    !VALID_MOMENT_SOURCES.has(source as RoleMomentSource)
  ) {
    return null;
  }
  return {
    id,
    roleId: roleId as RoleId,
    timestamp,
    what,
    tag: tag || null,
    source: source as RoleMomentSource,
    sourceRef: sourceRef || null,
  };
}

/** Pull → push for the role-moments zone. Mirrors syncJournal. */
export async function syncMoments(
  db: SQLite.SQLiteDatabase,
): Promise<SyncResult> {
  const start = Date.now();
  try {
    configureCloudKit();
    const status = await getAccountStatus();
    if (status !== "available") {
      return {
        ok: false,
        error: `account status: ${status}`,
        durationMs: Date.now() - start,
      };
    }
    await ensureRoleMomentsZone();

    const { upserts, deletes } = await pullMoments(db);
    const { pushed } = await pushMoments(db);

    return {
      ok: true,
      pulled: upserts,
      pushed,
      deleted: deletes,
      durationMs: Date.now() - start,
    };
  } catch (e: any) {
    return {
      ok: false,
      error: e?.message ?? String(e),
      durationMs: Date.now() - start,
    };
  }
}

async function pullMoments(
  db: SQLite.SQLiteDatabase,
): Promise<{ upserts: number; deletes: number }> {
  let upserts = 0;
  let deletes = 0;

  while (true) {
    const result = await fetchRecordZoneChanges([ROLE_MOMENTS_ZONE]);

    for (const record of result.changedRecords ?? []) {
      if (record.recordType !== ROLE_MOMENT_RECORD_TYPE) continue;
      const moment = recordToMoment(record as any);
      if (!moment) continue;
      await upsertSyncedMoment(
        db,
        moment,
        record.recordName,
        (record as any).changeTag ?? null,
      );
      upserts += 1;
    }

    for (const deletedName of result.deletedRecordNames ?? []) {
      await deleteMomentByCloudKitName(db, deletedName);
      deletes += 1;
    }

    if (!result.moreComing) break;
  }

  return { upserts, deletes };
}

async function pushMoments(
  db: SQLite.SQLiteDatabase,
): Promise<{ pushed: number }> {
  const pending = await getPendingMoments(db);
  if (pending.length === 0) return { pushed: 0 };

  const records = pending.map(momentToRecord);
  let pushed = 0;
  try {
    const saved = await saveRecords(records);
    for (const r of saved) {
      await markMomentSynced(
        db,
        r.recordName,
        r.recordName,
        (r as any).changeTag ?? null,
      );
      pushed += 1;
    }
  } catch (e) {
    // Mark anything still pending as failed so the next pass retries.
    for (const m of pending) {
      await markMomentFailed(db, m.id);
    }
    throw e;
  }

  return { pushed };
}

/**
 * Delete all role moments tied to a journal entry (both source_ref forms:
 * the raw entry id from card tagging and `journal:<id>` from auto-emo).
 * Each is removed sync-aware via deleteMomentRecord so CloudKit tombstones
 * too. Used by deleteJournalEntry for the D1 cascade.
 */
export async function deleteMomentsForEntry(
  db: SQLite.SQLiteDatabase,
  entryId: string,
): Promise<void> {
  const rows = await db.getAllAsync<{ id: string }>(
    `SELECT id FROM role_moments WHERE source_ref = ? OR source_ref = ?`,
    [entryId, `journal:${entryId}`],
  );
  for (const r of rows) {
    await deleteMomentRecord(db, r.id);
  }
}

/**
 * Remove a single role's link to a journal entry (both source_ref forms:
 * the raw entry id from card/inline tagging and `journal:<id>` from
 * auto-emo). Sync-aware via deleteMomentRecord so CloudKit tombstones too.
 * Used by the Journal's inline role editor when a role is toggled off.
 */
export async function removeRoleTagFromEntry(
  db: SQLite.SQLiteDatabase,
  entryId: string,
  roleId: RoleId,
): Promise<void> {
  const rows = await db.getAllAsync<{ id: string }>(
    `SELECT id FROM role_moments
      WHERE role_id = ? AND (source_ref = ? OR source_ref = ?)`,
    [roleId, entryId, `journal:${entryId}`],
  );
  for (const r of rows) {
    await deleteMomentRecord(db, r.id);
  }
}

/** Delete a moment locally and from CloudKit. */
export async function deleteMomentRecord(
  db: SQLite.SQLiteDatabase,
  id: string,
): Promise<void> {
  await db.runAsync("DELETE FROM role_moments WHERE id = ?", [id]);
  configureCloudKit();
  const status = await getAccountStatus();
  if (status !== "available") return;

  await ensureRoleMomentsZone();
  try {
    await deleteRecords([{ recordName: id, zoneName: ROLE_MOMENTS_ZONE }]);
  } catch {
    // Record may never have been pushed; local delete already happened.
  }
}
