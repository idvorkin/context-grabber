import { ENGAGE, RELEASE, classifyTurn, rotationFor, type Turn } from "../lib/gym/deviceTurn";
import { SEGMENTS, isSeparator, ledPhaseWord, segmentsFor } from "../lib/gym/sevenSegment";

describe("seven-segment glyphs", () => {
  it("spells every digit with the classic bars", () => {
    expect([...segmentsFor("8")].sort()).toEqual([...SEGMENTS].sort());
    expect([...segmentsFor("1")].sort()).toEqual(["b", "c"]);
    expect([...segmentsFor("0")].sort()).toEqual(["a", "b", "c", "d", "e", "f"]);
    expect(segmentsFor("4").has("g")).toBe(true);
    expect(segmentsFor("7").has("f")).toBe(false);
    for (const d of "0123456789") expect(segmentsFor(d).size).toBeGreaterThanOrEqual(2);
  });

  it("spells the phase words the way a gym clock does, and blanks what it cannot", () => {
    expect(ledPhaseWord("work")).toBe("GO");
    expect(ledPhaseWord("rest")).toBe("rESt");
    expect(ledPhaseWord("prep")).toBe("rEAdY");
    expect(ledPhaseWord("done")).toBe("donE");
    expect(ledPhaseWord("idle")).toBe("");
    for (const ch of "GOrEStAdYn") expect(segmentsFor(ch).size).toBeGreaterThan(0);
    expect(segmentsFor("W").size).toBe(0); // no W on seven bars
    expect(segmentsFor(" ").size).toBe(0);
  });

  it("knows the separators are dots, not segments", () => {
    expect(isSeparator(":")).toBe(true);
    expect(isSeparator(".")).toBe(true);
    expect(isSeparator("1")).toBe(false);
    expect(segmentsFor(":").size).toBe(0);
  });
});

describe("which way the phone is turned", () => {
  it("upright until a clear sideways pull; left and right by the sign of x", () => {
    expect(classifyTurn(0, -1, "upright")).toBe("upright");
    expect(classifyTurn(-1, 0, "upright")).toBe("left");
    expect(classifyTurn(1, 0, "upright")).toBe("right");
    expect(classifyTurn(-0.5, -0.85, "upright")).toBe("upright"); // 30° tilt is not a turn
  });

  it("has a margin: engages past 0.6 g, releases only below 0.4 g, so 45° does not flicker", () => {
    expect(ENGAGE).toBeGreaterThan(RELEASE);
    const near45 = { x: -0.7, y: -0.7 };
    let t: Turn = "upright";
    t = classifyTurn(near45.x, near45.y, t);
    expect(t).toBe("upright"); // x is not greater than y
    t = classifyTurn(-0.75, -0.65, t);
    expect(t).toBe("left");
    t = classifyTurn(-0.55, -0.83, t); // came back toward upright, but not clearly
    expect(t).toBe("left");
    t = classifyTurn(-0.2, -0.98, t);
    expect(t).toBe("upright");
  });

  it("a phone laid flat keeps the turn it was last held at", () => {
    expect(classifyTurn(0.05, 0.05, "left")).toBe("left");
    expect(classifyTurn(0.05, 0.05, "right")).toBe("right");
    expect(classifyTurn(0.05, 0.05, "upright")).toBe("upright");
  });

  it("turned one way, a swing straight to the other way follows", () => {
    expect(classifyTurn(1, 0, "left")).toBe("right");
    expect(classifyTurn(-1, 0, "right")).toBe("left");
  });

  it("rotation: the phone turned counter-clockwise (top left) needs the display turned clockwise (+90) to undo it", () => {
    expect(rotationFor("left")).toBe(90);
    expect(rotationFor("right")).toBe(-90);
    expect(rotationFor("upright")).toBe(0);
  });
});
