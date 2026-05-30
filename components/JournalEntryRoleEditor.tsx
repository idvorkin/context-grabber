import React, { useEffect, useRef, useState } from "react";
import {
  Modal,
  Pressable,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import type * as SQLite from "expo-sqlite";
import { momentMetaForEntry, type JournalEntry } from "../lib/journal";
import { insertMoment } from "../lib/roleMoments";
import { removeRoleTagFromEntry, syncMoments } from "../lib/cloudkit";
import { type RoleId } from "../lib/roles";
import { RolePickerChips } from "./RolePickerChips";
import { CopyableError } from "./CopyableError";

type Props = {
  visible: boolean;
  entry: JournalEntry | null;
  /** Roles the entry is currently tied to. */
  currentRoles: ReadonlySet<RoleId>;
  db: SQLite.SQLiteDatabase | null;
  onClose: () => void;
  /** Called after any persisted change so the parent can refresh. */
  onChanged: () => void;
};

/**
 * Compact modal to add/remove an existing entry's role tags (D1: each
 * toggle persists immediately; D2: modal sheet). Direct-manipulation:
 * the picker reflects exactly the entry's current role links and toggles
 * that set — adding never strips the auto-emo link, removing all leaves
 * the entry untagged.
 */
export function JournalEntryRoleEditor({
  visible,
  entry,
  currentRoles,
  db,
  onClose,
  onChanged,
}: Props) {
  const [selected, setSelected] = useState<Set<RoleId>>(new Set(currentRoles));
  const [error, setError] = useState<string | null>(null);
  // Roles with an in-flight write — guards against a rapid double-tap
  // firing two inserts/deletes for the same role before the first resolves.
  const inFlight = useRef<Set<RoleId>>(new Set());

  useEffect(() => {
    if (visible) {
      setSelected(new Set(currentRoles));
      setError(null);
      inFlight.current = new Set();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, entry?.id]);

  async function toggle(roleId: RoleId) {
    if (!db || !entry) return;
    if (inFlight.current.has(roleId)) return;
    inFlight.current.add(roleId);
    const isOn = selected.has(roleId);
    // Optimistic UI; revert on failure.
    setSelected((prev) => {
      const next = new Set(prev);
      if (isOn) next.delete(roleId);
      else next.add(roleId);
      return next;
    });
    try {
      if (isOn) {
        await removeRoleTagFromEntry(db, entry.id, roleId);
      } else {
        const meta = momentMetaForEntry(entry);
        await insertMoment(db, {
          roleId,
          timestamp: entry.date,
          what: meta.what,
          tag: meta.tag,
          source: "manual",
          sourceRef: entry.id,
        });
      }
      void syncMoments(db);
      onChanged();
    } catch (e: any) {
      setError(e?.message ?? String(e));
      // Revert optimistic toggle.
      setSelected((prev) => {
        const next = new Set(prev);
        if (isOn) next.add(roleId);
        else next.delete(roleId);
        return next;
      });
    } finally {
      inFlight.current.delete(roleId);
    }
  }

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} />
        <View style={styles.sheet}>
          <View style={styles.handle} />
          <View style={styles.header}>
            <Text style={styles.heading}>Tag roles</Text>
            <TouchableOpacity onPress={onClose} testID="entry-roles-done">
              <Text style={styles.done}>Done</Text>
            </TouchableOpacity>
          </View>
          {entry && (
            <Text style={styles.preview} numberOfLines={2}>
              {entry.text || "voice entry"}
            </Text>
          )}
          <RolePickerChips
            selected={selected}
            onToggle={toggle}
            heading={null}
            testIDPrefix="entry-role"
          />
          {error && (
            <CopyableError
              message={error}
              context="JournalEntryRoleEditor.toggle"
              extra={{ entryId: entry?.id ?? "none" }}
              style={{ marginTop: 10 }}
            />
          )}
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.6)",
    justifyContent: "flex-end",
  },
  sheet: {
    backgroundColor: "#111828",
    borderTopLeftRadius: 18,
    borderTopRightRadius: 18,
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 32,
  },
  handle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: "#444",
    alignSelf: "center",
    marginBottom: 8,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 4,
  },
  heading: { color: "#e0e0e0", fontSize: 18, fontWeight: "700" },
  done: { color: "#4a9eff", fontSize: 16, fontWeight: "600" },
  preview: { color: "#9aa3b2", fontSize: 13, marginBottom: 4 },
});
