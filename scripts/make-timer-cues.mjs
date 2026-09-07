#!/usr/bin/env node
/**
 * Render the Gym Timer's cues to WAV files — the same tones the timer used to
 * synthesise live, pre-rendered so they play as files through the ordinary
 * media path. Deterministic: run it again and the bytes are identical.
 *
 *   node scripts/make-timer-cues.mjs        → assets/audio/timer/*.wav
 *
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RATE = 44_100;
const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "assets", "audio", "timer");

/** One sine note: frequency, length, level, start offset — as playTone took them. */
const note = (hz, seconds, level, at = 0) => ({ hz, seconds, level, at });

const CUES = {
  // "GO!" — three rising notes.
  go: [note(800, 0.15, 0.8, 0), note(1000, 0.15, 0.8, 0.1), note(1200, 0.25, 0.9, 0.2)],
  // Rest — two falling notes.
  rest: [note(800, 0.2, 0.7, 0), note(600, 0.3, 0.7, 0.2)],
  // The 3-2-1 tick.
  tick: [note(660, 0.08, 0.6, 0)],
  // All done — C E G high C.
  done: [note(523, 0.2, 0.8, 0), note(659, 0.2, 0.8, 0.15), note(784, 0.2, 0.8, 0.3), note(1047, 0.4, 0.9, 0.45)],
};

/** A short fade at each end of a note keeps it from clicking. */
const FADE = 0.004;

function render(notes) {
  const length = Math.ceil(Math.max(...notes.map((n) => n.at + n.seconds)) * RATE) + Math.round(0.02 * RATE);
  const out = new Float64Array(length);
  for (const { hz, seconds, level, at } of notes) {
    const start = Math.round(at * RATE);
    const count = Math.round(seconds * RATE);
    const fade = Math.round(FADE * RATE);
    for (let i = 0; i < count; i++) {
      const env = Math.min(1, i / fade, (count - i) / fade);
      out[start + i] += level * env * Math.sin((2 * Math.PI * hz * i) / RATE);
    }
  }
  return out;
}

/**
 * A second of very-low-level noise for the keepalive loop: -66 dB, inaudible,
 * but real samples, which iOS counts as live audio output (digital silence
 * it may not). Deterministic: a fixed-seed generator, not Math.random.
 */
function keepaliveNoise(seconds) {
  const out = new Float64Array(Math.round(seconds * RATE));
  let x = 0x2545f491;
  for (let i = 0; i < out.length; i++) {
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    out[i] = ((x >>> 0) / 0xffffffff - 0.5) * 0.001;
  }
  return out;
}

function wav(samples) {
  const pcm = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    pcm.writeInt16LE(Math.round(v * 32767), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + pcm.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16); // PCM chunk size
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28); // byte rate
  header.writeUInt16LE(2, 32); // block align
  header.writeUInt16LE(16, 34); // bits
  header.write("data", 36);
  header.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([header, pcm]);
}

mkdirSync(OUT, { recursive: true });
for (const [name, notes] of Object.entries(CUES)) {
  const file = join(OUT, `${name}.wav`);
  writeFileSync(file, wav(render(notes)));
  console.log(`${name}.wav`);
}
writeFileSync(join(OUT, "keepalive.wav"), wav(keepaliveNoise(1)));
console.log("keepalive.wav");
