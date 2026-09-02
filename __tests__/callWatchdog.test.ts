import {
  AUDIO_ABSENT_MS,
  MIC_STALL_MS,
  OUTPUT_STALL_MS,
  audioAbsent,
  describePlayback,
  micVerdict,
  outputVerdict,
} from "../lib/callWatchdog";

describe("micVerdict (#95)", () => {
  const base = { now: 10_000, armed: true, paused: false, armedAt: 5_000, lastBufferAt: 9_900 };

  it("a buffer within the window is ok; none for the window is stalled", () => {
    expect(micVerdict(base)).toBe("ok");
    expect(micVerdict({ ...base, lastBufferAt: 10_000 - MIC_STALL_MS })).toBe("stalled");
    expect(micVerdict({ ...base, lastBufferAt: 10_000 - MIC_STALL_MS + 1 })).toBe("ok");
  });

  it("a fresh tap gets the full grace from arming, not from a buffer that never came", () => {
    expect(micVerdict({ ...base, armedAt: 9_000, lastBufferAt: 0 })).toBe("ok");
    expect(micVerdict({ ...base, armedAt: 10_000 - MIC_STALL_MS, lastBufferAt: 0 })).toBe("stalled");
  });

  it("not armed, or interrupted, is idle — silence is expected", () => {
    expect(micVerdict({ ...base, armed: false, lastBufferAt: 0 })).toBe("idle");
    expect(micVerdict({ ...base, paused: true, lastBufferAt: 0 })).toBe("idle");
  });
});

describe("outputVerdict (#95)", () => {
  const base = {
    now: 20_000,
    currentTime: 3.0,
    previousTime: 3.0,
    previousCheckAt: 20_000 - OUTPUT_STALL_MS,
    playhead: 4.5,
    lastScheduledAt: 19_800,
  };

  it("audio due, recently scheduled, clock frozen for the window: stalled", () => {
    expect(outputVerdict(base)).toBe("stalled");
  });

  it("a moving clock is ok, and a clock frozen for less than the window is still ok", () => {
    expect(outputVerdict({ ...base, currentTime: 3.2 })).toBe("ok");
    expect(outputVerdict({ ...base, previousCheckAt: 20_000 - OUTPUT_STALL_MS + 1 })).toBe("ok");
  });

  it("nothing due, or nothing scheduled lately, is idle — a quiet line is not a stall", () => {
    expect(outputVerdict({ ...base, playhead: 3.0 })).toBe("idle");
    expect(outputVerdict({ ...base, lastScheduledAt: 17_000 })).toBe("idle");
  });
});

describe("audioAbsent (#105)", () => {
  it("text arriving with no audio for the window is absent; audio within the window is not", () => {
    const now = 60_000;
    expect(audioAbsent({ now, lastTextAt: now - 1000, lastAudioAt: now - AUDIO_ABSENT_MS - 1 })).toBe(true);
    expect(audioAbsent({ now, lastTextAt: now - 1000, lastAudioAt: 0 })).toBe(true);
    expect(audioAbsent({ now, lastTextAt: now - 1000, lastAudioAt: now - 2000 })).toBe(false);
  });

  it("no recent text means nothing is expected — not absent", () => {
    const now = 60_000;
    expect(audioAbsent({ now, lastTextAt: 0, lastAudioAt: 0 })).toBe(false);
    expect(audioAbsent({ now, lastTextAt: now - AUDIO_ABSENT_MS - 1, lastAudioAt: 0 })).toBe(false);
  });
});

describe("describePlayback (#106)", () => {
  it("says played of scheduled, and flags a clock that is not running", () => {
    expect(describePlayback(null)).toBe("no playback");
    expect(describePlayback({ scheduledS: 12.34, playedS: 10, clockRunning: true })).toBe("played 10.0s of 12.3s");
    expect(describePlayback({ scheduledS: 2, playedS: 0, clockRunning: false })).toBe(
      "played 0.0s of 2.0s (clock not running)",
    );
  });
});
