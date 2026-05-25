import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import type * as SQLite from "expo-sqlite";
import {
  ROLES,
  computeWeekActivity,
  type RoleWeekActivity,
  type RoleId,
  type WeeklyCacheLike,
} from "../lib/roles";
import { getMomentsInRange, type RoleMoment } from "../lib/roleMoments";
import { RoleAvatar } from "../components/RoleAvatar";
import { TagMomentSheet } from "../components/TagMomentSheet";

type Props = {
  db: SQLite.SQLiteDatabase | null;
  weeklyCache: WeeklyCacheLike;
};

export function RolesScreen({ db, weeklyCache }: Props) {
  const [moments, setMoments] = useState<RoleMoment[]>([]);
  const [tagSheetVisible, setTagSheetVisible] = useState(false);
  const [tagInitialRole, setTagInitialRole] = useState<RoleId | undefined>(
    undefined,
  );

  const reload = useCallback(() => {
    if (!db) return;
    const now = Date.now();
    const sevenDaysAgo = now - 7 * 24 * 3600 * 1000;
    void (async () => {
      try {
        const rows = await getMomentsInRange(db, sevenDaysAgo, now);
        setMoments(rows);
      } catch {
        // Tolerate missing table on devices that haven't migrated yet.
      }
    })();
  }, [db]);

  useEffect(() => {
    reload();
  }, [reload]);

  const openTagSheet = useCallback((roleId?: RoleId) => {
    setTagInitialRole(roleId);
    setTagSheetVisible(true);
  }, []);

  const activities = useMemo(() => {
    const now = new Date();
    const out: Record<RoleId, RoleWeekActivity> = {} as any;
    for (const def of ROLES) {
      out[def.id] = computeWeekActivity(def.id, {
        health: weeklyCache,
        moments,
        now,
      });
    }
    return out;
  }, [weeklyCache, moments]);

  const attention = useMemo(
    () => ROLES.filter((r) => activities[r.id].attention.flagged),
    [activities],
  );

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <Text style={styles.title}>Roles</Text>
          <Text style={styles.subtitle}>Living my eulogy</Text>
        </View>
        <TouchableOpacity
          style={styles.tagBtn}
          onPress={() => openTagSheet()}
          testID="roles-add-moment"
        >
          <Text style={styles.tagBtnText}>+ Tag moment</Text>
        </TouchableOpacity>
      </View>
      <ScrollView contentContainerStyle={styles.scroll}>
        {attention.length > 0 && (
          <View style={styles.attentionCard}>
            <Text style={styles.attentionHeading}>Needs attention</Text>
            {attention.slice(0, 3).map((r) => {
              const a = activities[r.id];
              return (
                <Pressable
                  key={r.id}
                  style={styles.attentionRow}
                  onLongPress={() => openTagSheet(r.id)}
                  testID={`attention-row-${r.id}`}
                >
                  <RoleAvatar roleId={r.id} size={28} ringColor={r.color} />
                  <View style={{ flex: 1, marginLeft: 10 }}>
                    <Text style={styles.attentionName}>{r.name}</Text>
                    <Text style={styles.attentionReason}>
                      {a.attention.reason}
                    </Text>
                  </View>
                </Pressable>
              );
            })}
          </View>
        )}

        <Text style={styles.sectionHeading}>All 11 · this week</Text>
        {ROLES.map((r) => {
          const a = activities[r.id];
          return (
            <Pressable
              key={r.id}
              style={styles.roleRow}
              onLongPress={() => openTagSheet(r.id)}
              testID={`role-row-${r.id}`}
              accessibilityHint="Long-press to tag a moment"
            >
              <RoleAvatar roleId={r.id} size={32} ringColor={r.color} />
              <View style={{ flex: 1, marginLeft: 12 }}>
                <Text style={styles.roleName}>{r.short}</Text>
                <Text style={styles.roleActivity}>{a.activityLine}</Text>
              </View>
              <View style={styles.scorePill}>
                <Text
                  style={[
                    styles.scoreText,
                    a.score < 25 && styles.scoreTextDim,
                  ]}
                >
                  {a.score}
                </Text>
              </View>
            </Pressable>
          );
        })}

        <View style={styles.footnote}>
          <Text style={styles.footnoteText}>
            Each role's score is a 0–100 blend of HealthKit signals and
            tagged moments from the last 7 days. Long-press a role to tag a
            moment manually; attention rules fire when a role is quiet
            past its threshold (3–7 days).
          </Text>
        </View>
      </ScrollView>
      <TagMomentSheet
        visible={tagSheetVisible}
        onClose={() => setTagSheetVisible(false)}
        db={db}
        initialRoleId={tagInitialRole}
        onSaved={reload}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  header: {
    paddingTop: 60,
    paddingHorizontal: 20,
    paddingBottom: 12,
    flexDirection: "row",
    alignItems: "flex-end",
  },
  title: { fontSize: 28, fontWeight: "bold", color: "#e0e0e0" },
  subtitle: { color: "#888", fontSize: 13, marginTop: 2 },
  tagBtn: {
    backgroundColor: "rgba(76, 201, 240, 0.18)",
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 10,
  },
  tagBtnText: { color: "#4cc9f0", fontSize: 13, fontWeight: "600" },
  scroll: { paddingHorizontal: 20, paddingBottom: 24 },
  attentionCard: {
    backgroundColor: "#2a2010",
    borderRadius: 12,
    padding: 14,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: "rgba(232, 168, 124, 0.3)",
  },
  attentionHeading: {
    color: "#e8a87c",
    fontSize: 12,
    fontWeight: "700",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginBottom: 8,
  },
  attentionRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 8,
  },
  attentionName: { color: "#e0e0e0", fontSize: 14, fontWeight: "600" },
  attentionReason: { color: "#bbb", fontSize: 12, marginTop: 2 },
  sectionHeading: {
    color: "#4cc9f0",
    fontSize: 13,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginBottom: 8,
  },
  roleRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#16213e",
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginBottom: 6,
  },
  dot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: 12,
  },
  roleName: { color: "#e0e0e0", fontSize: 15, fontWeight: "600" },
  roleActivity: { color: "#888", fontSize: 12, marginTop: 2 },
  scorePill: {
    width: 38,
    height: 26,
    borderRadius: 13,
    backgroundColor: "#1a1a2e",
    alignItems: "center",
    justifyContent: "center",
  },
  scoreText: {
    color: "#4cc9f0",
    fontSize: 12,
    fontWeight: "700",
    fontVariant: ["tabular-nums"],
  },
  scoreTextDim: { color: "#666" },
  footnote: {
    marginTop: 16,
    padding: 12,
    backgroundColor: "rgba(255,255,255,0.02)",
    borderRadius: 8,
  },
  footnoteText: { color: "#666", fontSize: 11, lineHeight: 16 },
});
