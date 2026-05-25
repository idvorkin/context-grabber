import React from "react";
import {
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";

export type TabId = "today" | "body" | "move" | "mind" | "places" | "roles";

type TabDef = { id: TabId; label: string; icon: string };

export const TABS: ReadonlyArray<TabDef> = [
  { id: "today", label: "Today", icon: "•" },
  { id: "body", label: "Body", icon: "♡" },
  { id: "move", label: "Move", icon: "▶" },
  { id: "mind", label: "Mind", icon: "○" },
  { id: "places", label: "Places", icon: "◆" },
  { id: "roles", label: "Roles", icon: "★" },
];

type Props = {
  active: TabId;
  onChange: (id: TabId) => void;
};

export function TabBar({ active, onChange }: Props) {
  return (
    <View style={styles.bar} testID="tab-bar">
      {TABS.map((t) => {
        const isActive = t.id === active;
        return (
          <Pressable
            key={t.id}
            onPress={() => onChange(t.id)}
            style={styles.tab}
            testID={`tab-${t.id}`}
            accessibilityRole="tab"
            accessibilityState={{ selected: isActive }}
            accessibilityLabel={t.label}
          >
            <Text style={[styles.icon, isActive && styles.iconActive]}>
              {t.icon}
            </Text>
            <Text style={[styles.label, isActive && styles.labelActive]}>
              {t.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    flexDirection: "row",
    backgroundColor: "#0c121f",
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: "#222",
    paddingTop: 6,
    paddingBottom: Platform.OS === "ios" ? 24 : 8,
  },
  tab: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 4,
  },
  icon: {
    fontSize: 18,
    color: "#666",
    marginBottom: 2,
    lineHeight: 22,
  },
  iconActive: { color: "#4cc9f0" },
  label: { fontSize: 11, color: "#888", fontWeight: "500" },
  labelActive: { color: "#4cc9f0", fontWeight: "600" },
});
