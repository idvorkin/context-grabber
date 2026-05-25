import React from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";

export function RolesScreen() {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Roles</Text>
      </View>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.placeholder}>Coming soon</Text>
        <Text style={styles.sub}>
          The 11 eulogy roles as a living dashboard. Constellation, year
          heatmap, role detail with eulogy passages.
        </Text>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#111828" },
  header: { paddingHorizontal: 20, paddingTop: 60, paddingBottom: 16 },
  title: { fontSize: 28, fontWeight: "700", color: "#e0e0e0" },
  content: { flexGrow: 1, justifyContent: "center", alignItems: "center", padding: 20 },
  placeholder: { fontSize: 18, fontWeight: "600", color: "#888", marginBottom: 8 },
  sub: { fontSize: 13, color: "#666", textAlign: "center" },
});
