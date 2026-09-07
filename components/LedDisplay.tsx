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
 * 0.11 × height thick. The stopwatch redraws this a hundred times a second,
 * so the geometry and the bar styles are computed once per height (and per
 * colour) and reused; a render only maps the bars.
 */

const GHOST = "#242424";
const DIGIT_W = 0.55;
const BAR = 0.11;
const GAP = 0.13;
const SEP_W = 0.18;

function charWidth(ch: string, h: number): number {
  return (isSeparator(ch) ? SEP_W : DIGIT_W) * h;
}

function ledWidth(text: string, height: number): number {
  const chars = [...text];
  if (chars.length === 0) return 0;
  const glyphs = chars.reduce((w, ch) => w + charWidth(ch, height), 0);
  return glyphs + (chars.length - 1) * GAP * height;
}

/** The tallest height at which the string fits in `width`, never above `maxHeight`. */
export function ledHeightToFit(text: string, width: number, maxHeight: number): number {
  const atOne = ledWidth(text, 1);
  return atOne > 0 ? Math.floor(Math.min(maxHeight, width / atOne)) : 0;
}

type Props = {
  text: string;
  color: string;
  height: number;
  style?: StyleProp<ViewStyle>;
  testID?: string;
};

export function LedDisplay({ text, color, height, style, testID }: Props) {
  const geometry = geometryFor(height);
  const ink = inkFor(color, height);
  return (
    <View style={[styles.row, { height, gap: GAP * height }, style]} testID={testID} accessibilityLabel={text}>
      {[...text].map((ch, i) =>
        isSeparator(ch) ? (
          <Separator key={i} kind={ch === ":" ? "colon" : "dot"} geometry={geometry} ink={ink} />
        ) : (
          <Glyph key={i} ch={ch} geometry={geometry} ink={ink} />
        ),
      )}
    </View>
  );
}

// MARK: - geometry and ink, once per height and colour

type Geometry = {
  height: number;
  digitWidth: number;
  sepWidth: number;
  bar: number;
  /** Where each bar sits inside a digit. */
  frames: Record<Segment, ViewStyle>;
  /** The colon's two dots and the point's one, as `top` offsets. */
  colonTops: [number, number];
  dotTop: number;
};

const geometries = new Map<number, Geometry>();

function geometryFor(h: number): Geometry {
  const cached = geometries.get(h);
  if (cached) return cached;
  const w = DIGIT_W * h;
  const t = BAR * h;
  const r = t / 2;
  const inset = t * 0.55; // bars stop short of the corners so they read as separate LEDs
  const horiz = { left: inset, width: w - 2 * inset, height: t, borderRadius: r };
  const vert = { width: t, height: h / 2 - inset - t / 2, borderRadius: r };
  const g: Geometry = {
    height: h,
    digitWidth: w,
    sepWidth: SEP_W * h,
    bar: t,
    frames: {
      a: { ...horiz, top: 0 },
      g: { ...horiz, top: (h - t) / 2 },
      d: { ...horiz, top: h - t },
      f: { ...vert, left: 0, top: inset + t / 2 },
      b: { ...vert, left: w - t, top: inset + t / 2 },
      e: { ...vert, left: 0, top: h / 2 + t / 2 },
      c: { ...vert, left: w - t, top: h / 2 + t / 2 },
    },
    colonTops: [h * 0.3 - t / 2, h * 0.7 - t / 2],
    dotTop: h - t,
  };
  geometries.set(h, g);
  return g;
}

type Ink = { lit: ViewStyle; ghost: ViewStyle };

const inks = new Map<string, Ink>();

function inkFor(color: string, h: number): Ink {
  const key = `${color}/${h}`;
  const cached = inks.get(key);
  if (cached) return cached;
  const ink: Ink = {
    lit: { backgroundColor: color, shadowColor: color, shadowOpacity: 0.85, shadowRadius: BAR * h * 0.7 },
    ghost: { backgroundColor: GHOST },
  };
  inks.set(key, ink);
  return ink;
}

// MARK: - the pieces

function Glyph({ ch, geometry, ink }: { ch: string; geometry: Geometry; ink: Ink }) {
  const lit = segmentsFor(ch);
  return (
    <View style={{ width: geometry.digitWidth, height: geometry.height }} testID={`led-glyph-${ch}`}>
      {SEGMENTS.map((seg) => (
        <View key={seg} style={[styles.bar, geometry.frames[seg], lit.has(seg) ? ink.lit : ink.ghost]} />
      ))}
    </View>
  );
}

function Separator({ kind, geometry, ink }: { kind: "colon" | "dot"; geometry: Geometry; ink: Ink }) {
  const dot = { width: geometry.bar, height: geometry.bar, borderRadius: geometry.bar / 2 };
  return (
    <View style={{ width: geometry.sepWidth, height: geometry.height, alignItems: "center" }} testID={`led-${kind}`}>
      {kind === "colon" ? (
        <>
          <View style={[styles.bar, dot, ink.lit, { top: geometry.colonTops[0] }]} />
          <View style={[styles.bar, dot, ink.lit, { top: geometry.colonTops[1] }]} />
        </>
      ) : (
        <View style={[styles.bar, dot, ink.lit, { top: geometry.dotTop }]} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "flex-start" },
  bar: { position: "absolute", shadowOffset: { width: 0, height: 0 } },
});
