/**
 * Seven-segment glyphs for the Gym Timer's LED display.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-led-display-design.md
 *
 * Segments are named the classic way:
 *
 *      a
 *    f   b
 *      g
 *    e   c
 *      d
 *
 * A glyph is the set of lit segments. Letters are the seven-segment
 * spellings a gym clock would use (rESt, rEAdY, donE, GO); anything not in
 * the table is blank. `:` and `.` are not glyphs — the display draws them
 * as dots — but they are recognised so a caller can lay a string out.
 */
import type { Phase } from "./timerDerive";

export type Segment = "a" | "b" | "c" | "d" | "e" | "f" | "g";
export const SEGMENTS: readonly Segment[] = ["a", "b", "c", "d", "e", "f", "g"];

const LIT: Record<string, string> = {
  "0": "abcdef",
  "1": "bc",
  "2": "abdeg",
  "3": "abcdg",
  "4": "bcfg",
  "5": "acdfg",
  "6": "acdefg",
  "7": "abc",
  "8": "abcdefg",
  "9": "abcdfg",
  A: "abcefg",
  b: "cdefg",
  C: "adef",
  c: "deg",
  d: "bcdeg",
  E: "adefg",
  F: "aefg",
  G: "acdef",
  H: "bcefg",
  h: "cefg",
  I: "bc",
  J: "bcd",
  L: "def",
  n: "ceg",
  O: "abcdef",
  o: "cdeg",
  P: "abefg",
  r: "eg",
  S: "acdfg",
  t: "defg",
  U: "bcdef",
  u: "cde",
  Y: "bcdfg",
  "-": "g",
  " ": "",
};

// Built once: the display asks for these on every frame.
const GLYPHS: ReadonlyMap<string, ReadonlySet<Segment>> = new Map(
  Object.entries(LIT).map(([ch, lit]) => [ch, new Set(lit.split("") as Segment[])]),
);
const BLANK: ReadonlySet<Segment> = new Set();

/** The lit segments for one character; blank for anything the display cannot spell. */
export function segmentsFor(ch: string): ReadonlySet<Segment> {
  return GLYPHS.get(ch) ?? BLANK;
}

/** True for the characters drawn as dots between digits rather than as segments. */
export function isSeparator(ch: string): boolean {
  return ch === ":" || ch === ".";
}

/** What a seven-segment display makes of a phase. */
export function ledPhaseWord(phase: Phase): string {
  switch (phase) {
    case "prep":
      return "rEAdY";
    case "work":
      return "GO";
    case "rest":
      return "rESt";
    case "done":
      return "donE";
    default:
      return "";
  }
}
