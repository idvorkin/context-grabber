import React, { useMemo, useRef, useState } from "react";
import { PanResponder, Pressable, StyleSheet, Text, View, type LayoutChangeEvent } from "react-native";

/**
 * A slider drawn by the app — a track, a thumb, − and + at the ends — that
 * snaps to a step. No native slider package, so it and every tweak to it
 * ship over the air. Drag the thumb, tap the track, or step with the ends.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-custom-preset-design.md
 */

type Props = {
  label: string;
  value: number;
  min: number;
  max: number;
  step: number;
  onChange: (value: number) => void;
  /** How the value reads beside the label. */
  format?: (value: number) => string;
  disabled?: boolean;
  testID?: string;
};

export function snapToStep(value: number, min: number, max: number, step: number): number {
  const clamped = Math.min(max, Math.max(min, value));
  return min + Math.round((clamped - min) / step) * step;
}

export function StepSlider({ label, value, min, max, step, onChange, format = String, disabled = false, testID }: Props) {
  const [trackWidth, setTrackWidth] = useState(0);
  // The latest of everything the pan needs, without re-creating the responder.
  const live = useRef({ value, min, max, step, disabled, trackWidth, onChange });
  live.current = { value, min, max, step, disabled, trackWidth, onChange };

  const valueAt = (x: number) => {
    const { min: lo, max: hi, step: st, trackWidth: w } = live.current;
    if (w <= 0) return live.current.value;
    return snapToStep(lo + (Math.min(w, Math.max(0, x)) / w) * (hi - lo), lo, hi, st);
  };
  const emit = (next: number) => {
    if (next !== live.current.value) live.current.onChange(next);
  };

  const pan = useMemo(
    () =>
      PanResponder.create({
        onStartShouldSetPanResponder: () => !live.current.disabled,
        onMoveShouldSetPanResponder: () => !live.current.disabled,
        onPanResponderGrant: (e) => emit(valueAt(e.nativeEvent.locationX)),
        onPanResponderMove: (e) => emit(valueAt(e.nativeEvent.locationX)),
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [],
  );

  const fraction = max > min ? (value - min) / (max - min) : 0;
  const stepBy = (n: number) => {
    if (disabled) return;
    emit(snapToStep(value + n * step, min, max, step));
  };

  return (
    <View style={[styles.row, disabled && styles.disabled]} testID={testID}>
      <View style={styles.labels}>
        <Text style={styles.label}>{label}</Text>
        <Text style={styles.value} testID={testID ? `${testID}-value` : undefined}>
          {format(value)}
        </Text>
      </View>
      <View style={styles.controls}>
        <Pressable
          onPress={() => stepBy(-1)}
          disabled={disabled}
          hitSlop={8}
          style={styles.stepBtn}
          testID={testID ? `${testID}-minus` : undefined}
          accessibilityRole="button"
          accessibilityLabel={`${label} less`}
        >
          <Text style={styles.stepText}>−</Text>
        </Pressable>
        <View
          style={styles.track}
          onLayout={(e: LayoutChangeEvent) => setTrackWidth(e.nativeEvent.layout.width)}
          testID={testID ? `${testID}-track` : undefined}
          accessibilityRole="adjustable"
          accessibilityLabel={label}
          accessibilityValue={{ min, max, now: value, text: format(value) }}
          accessibilityActions={[{ name: "increment" }, { name: "decrement" }]}
          onAccessibilityAction={(e) => stepBy(e.nativeEvent.actionName === "increment" ? 1 : -1)}
          {...pan.panHandlers}
        >
          <View style={styles.rail} />
          <View style={[styles.fill, { width: `${fraction * 100}%` }]} />
          <View style={[styles.thumb, { left: `${fraction * 100}%` }]} />
        </View>
        <Pressable
          onPress={() => stepBy(1)}
          disabled={disabled}
          hitSlop={8}
          style={styles.stepBtn}
          testID={testID ? `${testID}-plus` : undefined}
          accessibilityRole="button"
          accessibilityLabel={`${label} more`}
        >
          <Text style={styles.stepText}>+</Text>
        </Pressable>
      </View>
    </View>
  );
}

const THUMB = 22;

const styles = StyleSheet.create({
  row: { paddingHorizontal: 20, paddingVertical: 4 },
  disabled: { opacity: 0.35 },
  labels: { flexDirection: "row", justifyContent: "space-between", marginBottom: 2 },
  label: { color: "#888", fontSize: 12, fontWeight: "600", textTransform: "uppercase", letterSpacing: 1 },
  value: { color: "#e0e0e0", fontSize: 14, fontWeight: "700", fontVariant: ["tabular-nums"] },
  controls: { flexDirection: "row", alignItems: "center", gap: 10 },
  stepBtn: { width: 32, height: 32, borderRadius: 16, backgroundColor: "#16213e", alignItems: "center", justifyContent: "center" },
  stepText: { color: "#e0e0e0", fontSize: 18, fontWeight: "700", lineHeight: 20 },
  track: { flex: 1, height: 32, justifyContent: "center" },
  rail: { height: 4, borderRadius: 2, backgroundColor: "#16213e" },
  fill: { position: "absolute", left: 0, height: 4, borderRadius: 2, backgroundColor: "#4361ee" },
  thumb: {
    position: "absolute",
    width: THUMB,
    height: THUMB,
    borderRadius: THUMB / 2,
    marginLeft: -THUMB / 2,
    backgroundColor: "#e0e0e0",
    borderWidth: 2,
    borderColor: "#4361ee",
  },
});
