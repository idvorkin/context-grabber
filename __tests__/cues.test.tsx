import { createAudioPlayer } from "expo-audio";
import { loadCues, playCue } from "../lib/gym/cues";

// The jest.setup mock hands out a fresh player per createAudioPlayer call.
const made = createAudioPlayer as jest.Mock;

describe("the timer's cues, as files", () => {
  it("makes one player per cue, once, and plays a cue from its start", () => {
    made.mockClear();
    loadCues();
    loadCues();
    expect(made).toHaveBeenCalledTimes(4); // go, rest, tick, done — under jest every file is the same stub
    expect(made.mock.calls.every((c) => c[1]?.keepAudioSessionActive === true)).toBe(true);

    const tickPlayer = made.mock.results[2].value; // the third cue made is the tick
    playCue("tick");
    playCue("tick");
    expect(tickPlayer.seekTo).toHaveBeenCalledWith(0);
    expect(tickPlayer.play).toHaveBeenCalledTimes(2);
    expect(made).toHaveBeenCalledTimes(4); // no new player for a repeat
  });
});
