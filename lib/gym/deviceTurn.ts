/**
 * Which way the phone is turned, from its accelerometer — so the Gym Timer's
 * display can turn with it while the app's window stays portrait.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-led-display-design.md
 *
 * Device axes (Apple's, which Expo passes through on iOS): +x out of the
 * right edge, +y out of the top edge, +z out of the screen. Readings are in
 * g. Held upright, gravity reads y ≈ -1; turned so the top points left, the
 * right edge is up and gravity reads x ≈ -1; top to the right, x ≈ +1.
 *
 * Pure: the same readings and the same previous state give the same answer,
 * so the margins are tested rather than tuned on the phone.
 */

export type Turn = "upright" | "left" | "right";

/**
 * Degrees to rotate a portrait-laid-out display so it reads upright. The
 * phone turned counter-clockwise (top to the left) needs the display turned
 * *clockwise* relative to the phone — +90 in React Native's clockwise-positive
 * `rotate` — to undo it.
 */
export function rotationFor(turn: Turn): 0 | 90 | -90 {
  switch (turn) {
    case "left":
      return 90;
    case "right":
      return -90;
    default:
      return 0;
  }
}

/** Past this (in g) an axis is "down". Below `RELEASE` it is no longer; the gap is the margin against flicker near 45°. */
export const ENGAGE = 0.6;
export const RELEASE = 0.4;

/**
 * Classify one reading given the previous answer. Near-flat (neither axis
 * pulling) keeps the previous answer: a phone laid on a table stays as it
 * was last held.
 */
export function classifyTurn(x: number, y: number, previous: Turn): Turn {
  const ax = Math.abs(x);
  const ay = Math.abs(y);
  switch (previous) {
    case "upright":
      // Only a clear sideways pull turns the display.
      if (ax >= ENGAGE && ax > ay) return x < 0 ? "left" : "right";
      return "upright";
    case "left":
    case "right": {
      // Stay turned — following the side — until gravity clearly leaves the x axis…
      if (ax >= RELEASE) return x < 0 ? "left" : "right";
      // …then upright only once y clearly pulls (a flat phone keeps its turn).
      if (ay >= ENGAGE) return "upright";
      return previous;
    }
  }
}
