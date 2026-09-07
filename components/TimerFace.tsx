import React from "react";
import { Pressable, StyleSheet, Text, View, useWindowDimensions } from "react-native";
import { LedDisplay, ledHeightToFit } from "./LedDisplay";
import { rotationFor, type Turn } from "../lib/gym/deviceTurn";
import type { Phase } from "../lib/gym/timerDerive";

/**
 * The Gym Timer's face: a green LED phase word over the LED time, with the
 * round line under it — and the same face turned sideways to fill the
 * screen when the phone is on its side.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-led-display-design.md
 */

/** The LED palette: what a gym clock is. */
export const LED = {
  red: "#ff3b30",
  green: "#34c759",
  amber: "#ffcc00",
  white: "#e6e6e6",
} as const;

/** Red working, green resting, amber getting ready, red and steady on done; white before the first start. */
export function ledColorFor(phase: Phase): string {
  switch (phase) {
    case "work":
    case "done":
      return LED.red;
    case "rest":
      return LED.green;
    case "prep":
      return LED.amber;
    default:
      return LED.white;
  }
}

type FaceProps = {
  /** The seven-segment phase word (GO, rESt, …); nothing for none. */
  word?: string;
  time: string;
  /** Smaller digits after the time — the stopwatch's hundredths. */
  fraction?: string;
  color: string;
  /** Ordinary small type under the time — "Round 2 of 5". */
  sub?: string;
  /** The width to fill and the height not to exceed. */
  width: number;
  maxHeight: number;
  testID?: string;
};

export function TimerFace({ word, time, fraction, color, sub, width, maxHeight, testID }: FaceProps) {
  // The fraction rides at half height; sizing the pair as if full-size keeps it inside `width`.
  const mainH = ledHeightToFit(time + (fraction ?? ""), width, maxHeight);
  const wordH = word ? Math.round(mainH * 0.32) : 0;
  return (
    <View style={styles.face} testID={testID}>
      {word ? <LedDisplay text={word} color={LED.green} height={wordH} style={styles.word} testID="timer-word" /> : null}
      <View style={styles.timeRow}>
        <LedDisplay text={time} color={color} height={mainH} testID="timer-time" />
        {fraction ? (
          <LedDisplay text={fraction} color={color} height={Math.round(mainH * 0.5)} style={styles.fraction} testID="timer-fraction" />
        ) : null}
      </View>
      {sub ? <Text style={styles.sub}>{sub}</Text> : null}
    </View>
  );
}

type TurnedProps = Omit<FaceProps, "width" | "maxHeight" | "testID"> & {
  turn: Turn;
  /** The one control while turned: a tap anywhere. */
  onTap: () => void;
  /** "tap to start" / "tap to stop" / "tap to count". */
  hint: string;
};

/**
 * The face drawn sideways inside the portrait window, filling the long edge.
 * The box is laid out at the screen's long × short size and rotated; the
 * window itself never turns.
 */
export function TurnedTimer({ turn, onTap, hint, ...face }: TurnedProps) {
  const { width, height } = useWindowDimensions();
  const long = Math.max(width, height);
  const short = Math.min(width, height);
  return (
    <Pressable onPress={onTap} style={styles.turned} testID="timer-turned" accessibilityRole="button" accessibilityLabel={hint}>
      <View
        style={[styles.turnedBox, { width: long, height: short, transform: [{ rotate: `${rotationFor(turn)}deg` }] }]}
        testID="timer-turned-box"
      >
        <TimerFace {...face} width={long * 0.9} maxHeight={short * 0.6} />
        <Text style={styles.hint}>{hint}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  face: { alignItems: "center" },
  word: { marginBottom: 6 },
  timeRow: { flexDirection: "row", alignItems: "flex-end" },
  fraction: { marginLeft: 6 },
  sub: { color: "#888", fontSize: 16, marginTop: 10 },
  turned: { ...StyleSheet.absoluteFillObject, backgroundColor: "#000", alignItems: "center", justifyContent: "center" },
  turnedBox: { alignItems: "center", justifyContent: "center" },
  hint: { color: "#555", fontSize: 13, letterSpacing: 2, textTransform: "uppercase", marginTop: 18 },
});
