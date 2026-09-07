import React from "react";
import { StyleSheet, View, type StyleProp, type ViewStyle } from "react-native";
import { SEGMENTS, isSeparator, segmentsFor, type Segment } from "../lib/gym/sevenSegment";

/**
 * A seven-segment LED display, drawn — no font. Lit bars glow; unlit bars
 * are faint ghosts, so every digit has an `8` behind it and the display
 * reads as one panel. `:` and `.` are dots.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-led-display-design.md
 *
 * Everything is sized from `height`: a digit is 0.55 × height wide, a bar
 * 0.11 × height thick. `ledWidth` / `ledHeightToFit` let a caller fill a
 * given width.
 */

export const GHOST = "#242424";

const DIGIT_W = 0.55;
const BAR = 0.11;
const GAP = 0.13;
const SEP_W = 0.18;

function charWidth(ch: string, h: number): number {
  return (isSeparator(ch) ? SEP_W : DIGIT_W) * h;
}

/** The width a string takes at a given height. */
export function ledWidth(text: string, height: number): number {
  const chars = [...text];
  if (chars.length === 0) return 0;
  const glyphs = chars.reduce((w, ch) => w + charWidth(ch, height), 0);
  return glyphs + (chars.length - 1) * GAP * height;
}

/** The tallest height at which the string fits in `width`. */
export function ledHeightToFit(text: string, width: number, maxHeight = Infinity): number {
  const atOne = ledWidth(text, 1);
  if (atOne <= 0) return 0;
  return Math.floor(Math.min(maxHeight, width / atOne));
}

type Props = {
  text: string;
  color: string;
  height: number;
  /** Faint unlit bars behind every glyph (default on). */
  ghost?: boolean;
  style?: StyleProp<ViewStyle>;
  testID?: string;
};

export function LedDisplay({ text, color, height, ghost = true, style, testID }: Props) {
  const chars = [...text];
  return (
    <View style={[styles.row, { height, gap: GAP * height }, style]} testID={testID} accessibilityLabel={text}>
      {chars.map((ch, i) =>
        isSeparator(ch) ? (
          <Separator key={i} kind={ch === ":" ? "colon" : "dot"} color={color} height={height} />
        ) : (
          <Glyph key={i} ch={ch} color={color} height={height} ghost={ghost} />
        ),
      )}
    </View>
  );
}

/** Where each bar sits, in fractions of the digit height (x in fractions of the digit width). */
function barFrame(seg: Segment, h: number): ViewStyle {
  const w = DIGIT_W * h;
  const t = BAR * h;
  const r = t / 2;
  const inset = t * 0.55; // bars stop short of the corners so they read as separate LEDs
  const horiz = { left: inset, width: w - 2 * inset, height: t, borderRadius: r };
  const vertH = h / 2 - inset - t / 2;
  const vert = { width: t, height: vertH, borderRadius: r };
  switch (seg) {
    case "a":
      return { ...horiz, top: 0 };
    case "g":
      return { ...horiz, top: (h - t) / 2 };
    case "d":
      return { ...horiz, top: h - t };
    case "f":
      return { ...vert, left: 0, top: inset + t / 2 };
    case "b":
      return { ...vert, left: w - t, top: inset + t / 2 };
    case "e":
      return { ...vert, left: 0, top: h / 2 + t / 2 };
    case "c":
      return { ...vert, left: w - t, top: h / 2 + t / 2 };
  }
}

function Glyph({ ch, color, height, ghost }: { ch: string; color: string; height: number; ghost: boolean }) {
  const lit = segmentsFor(ch);
  const t = BAR * height;
  return (
    <View style={{ width: DIGIT_W * height, height }} testID={`led-glyph-${ch}`}>
      {SEGMENTS.map((seg) => {
        const on = lit.has(seg);
        if (!on && !ghost) return null;
        return (
          <View
            key={seg}
            testID={on ? `led-on-${seg}` : undefined}
            style={[
              styles.bar,
              barFrame(seg, height),
              on
                ? { backgroundColor: color, shadowColor: color, shadowOpacity: 0.85, shadowRadius: t * 0.7 }
                : { backgroundColor: GHOST },
            ]}
          />
        );
      })}
    </View>
  );
}

function Separator({ kind, color, height }: { kind: "colon" | "dot"; color: string; height: number }) {
  const t = BAR * height;
  const dot = {
    width: t,
    height: t,
    borderRadius: t / 2,
    backgroundColor: color,
    shadowColor: color,
    shadowOpacity: 0.85,
    shadowRadius: t * 0.7,
  };
  return (
    <View style={{ width: SEP_W * height, height, alignItems: "center" }} testID={`led-${kind}`}>
      {kind === "colon" ? (
        <>
          <View style={[styles.bar, dot, { top: height * 0.3 - t / 2 }]} />
          <View style={[styles.bar, dot, { top: height * 0.7 - t / 2 }]} />
        </>
      ) : (
        <View style={[styles.bar, dot, { top: height - t }]} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "flex-start" },
  bar: { position: "absolute", shadowOffset: { width: 0, height: 0 } },
});
