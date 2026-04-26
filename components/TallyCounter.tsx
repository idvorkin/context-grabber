/**
 * Compact tally-mark counter for the dashboard counter card.
 *
 * Renders 5-stroke groups (4 vertical bars + diagonal slash for the 5th) plus
 * a remainder of 0–4 trailing bars, alongside the numeric value in a handwritten
 * font. Tap forwards to onIncrement; the optional onReset slot is for the
 * adjacent reset button (rendered by the parent so this component stays focused).
 *
 * Spec: docs/superpowers/specs/2026-04-25-tap-counter-design.md
 */

import React from "react";
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Platform,
} from "react-native";

type Props = {
  value: number;
  onPress: () => void;
  /** Color of marks + number. Defaults to a soft cyan that matches METRIC_CONFIG.steps. */
  color?: string;
  testID?: string;
};

const HANDWRITTEN_FONT = Platform.select({
  ios: "Marker Felt",
  default: undefined,
});

export default function TallyCounter({
  value,
  onPress,
  color = "#4cc9f0",
  testID,
}: Props) {
  const safe = Math.max(0, Math.floor(value));
  const fullGroups = Math.floor(safe / 5);
  const remainder = safe % 5;

  return (
    <TouchableOpacity
      activeOpacity={0.6}
      onPress={onPress}
      testID={testID}
      style={styles.row}
      accessibilityLabel={`Counter: ${safe}. Tap to add one.`}
    >
      <View style={styles.tallyContainer}>
        {Array.from({ length: fullGroups }).map((_, gi) => (
          <View key={`g${gi}`} style={styles.tallyGroup}>
            {Array.from({ length: 4 }).map((_, mi) => (
              <View
                key={mi}
                style={[styles.tallyMark, { backgroundColor: color }]}
              />
            ))}
            <View style={[styles.tallyStrike, { backgroundColor: color }]} />
          </View>
        ))}
        {remainder > 0 && (
          <View style={styles.tallyGroup}>
            {Array.from({ length: remainder }).map((_, mi) => (
              <View
                key={`r${mi}`}
                style={[styles.tallyMark, { backgroundColor: color }]}
              />
            ))}
          </View>
        )}
      </View>
      <Text
        style={[
          styles.number,
          { color, fontFamily: HANDWRITTEN_FONT },
        ]}
        testID={testID ? `${testID}-value` : undefined}
      >
        {safe}
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    flexWrap: "wrap",
  },
  tallyContainer: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
    alignItems: "center",
  },
  tallyGroup: {
    flexDirection: "row",
    gap: 3,
    alignItems: "center",
    position: "relative",
  },
  tallyMark: {
    width: 3,
    height: 24,
    borderRadius: 1.5,
  },
  tallyStrike: {
    position: "absolute",
    width: "120%",
    height: 2,
    top: "45%",
    left: "-10%",
    transform: [{ rotate: "-30deg" }],
  },
  number: {
    fontSize: 28,
    fontWeight: "600",
    minWidth: 32,
    textAlign: "right",
  },
});
