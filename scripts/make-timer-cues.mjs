#!/usr/bin/env node
/**
 * Compose the Gym Timer's cue files from the spoken words that
 * scripts/make-timer-words.sh renders (three, two, one, go, rest, done) and
 * one synthesised flourish — the finish fanfare that follows "done". Also the
 * second of near-silence the background keepalive loops. Deterministic: the
 * same inputs give the same bytes.
 *
 *   node scripts/make-timer-cues.mjs       → assets/audio/timer/*.wav
 *
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md
 */
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RATE = 44_100;
const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "assets", "audio", "timer");
const WORDS = join(ROOT, "words");

/** Spoken words come out of `say` at a modest level; bring their peak up to this so they cut through. */
const WORD_PEAK = 0.9;

/** One sine note: frequency, length, level, start offset. */
const note = (hz, seconds, level, at = 0) => ({ hz, seconds, level, at });

/** All done — C E G high C, after the word. */
const FANFARE = [note(523, 0.2, 0.8, 0), note(659, 0.2, 0.8, 0.15), note(784, 0.2, 0.8, 0.3), note(1047, 0.4, 0.9, 0.45)];

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

/** Read a 16-bit mono 44.1 kHz WAV (what afconvert wrote) as samples in -1..1. */
function readWav(file) {
  const buf = readFileSync(file);
  if (buf.toString("ascii", 0, 4) !== "RIFF" || buf.toString("ascii", 8, 12) !== "WAVE") throw new Error(`${file}: not a WAV`);
  let pos = 12;
  let format = null;
  let data = null;
  while (pos + 8 <= buf.length) {
    const id = buf.toString("ascii", pos, pos + 4);
    const size = buf.readUInt32LE(pos + 4);
    const body = buf.subarray(pos + 8, pos + 8 + size);
    if (id === "fmt ") format = { channels: buf.readUInt16LE(pos + 10), rate: buf.readUInt32LE(pos + 12), bits: buf.readUInt16LE(pos + 22) };
    if (id === "data") data = body;
    pos += 8 + size + (size % 2);
  }
  if (!format || !data) throw new Error(`${file}: no fmt/data`);
  if (format.channels !== 1 || format.rate !== RATE || format.bits !== 16) throw new Error(`${file}: want mono 16-bit ${RATE} Hz, got ${JSON.stringify(format)}`);
  const out = new Float64Array(data.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = data.readInt16LE(i * 2) / 32768;
  return out;
}

/**
 * Cut a word down to the word. A renderer pads it with silence (ElevenLabs:
 * up to half a second either side), and a clone may breathe before it and
 * hum after — both quiet next to the word itself. The start is the first
 * real onset (a tenth of the peak), walked back a little for the consonant's
 * attack; the end is the last sample that is not near-silence, plus a short
 * tail. Samples come in normalised, so the thresholds are absolute.
 */
function trimmed(samples, onset = 0.1, floor = 0.02, attackSeconds = 0.02, tailSeconds = 0.03) {
  let start = 0;
  while (start < samples.length && Math.abs(samples[start]) < onset) start++;
  start = Math.max(0, start - Math.round(attackSeconds * RATE));
  let end = samples.length;
  while (end > start && Math.abs(samples[end - 1]) < floor) end--;
  end = Math.min(samples.length, end + Math.round(tailSeconds * RATE));
  return samples.slice(start, end);
}

function normalized(samples, peak) {
  let max = 0;
  for (const v of samples) max = Math.max(max, Math.abs(v));
  if (max === 0) return samples;
  const g = peak / max;
  return samples.map((v) => v * g);
}

function concat(...parts) {
  const out = new Float64Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
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

/** Of the takes rendered for a word, the shortest once trimmed: a filler always adds length. */
function word(name) {
  const takes = readdirSync(WORDS).filter((f) => f === `${name}.wav` || new RegExp(`^${name}\\.\\d+\\.wav$`).test(f));
  if (takes.length === 0) throw new Error(`no takes for "${name}" in ${WORDS} — run scripts/make-timer-words.sh`);
  const trimmedTakes = takes.map((f) => ({ f, s: trimmed(normalized(readWav(join(WORDS, f)), WORD_PEAK)) }));
  trimmedTakes.sort((a, b) => a.s.length - b.s.length);
  const best = trimmedTakes[0];
  console.log(`${name}: ${best.f} (${(best.s.length / RATE).toFixed(2)}s of ${trimmedTakes.map((t) => (t.s.length / RATE).toFixed(2)).join("/")})`);
  return best.s;
}
const gap = (seconds) => new Float64Array(Math.round(seconds * RATE));

mkdirSync(ROOT, { recursive: true });
const cues = {
  three: word("three"),
  two: word("two"),
  one: word("one"),
  go: word("go"),
  rest: word("rest"),
  done: concat(word("done"), gap(0.08), render(FANFARE)),
  keepalive: keepaliveNoise(1),
};
for (const [name, samples] of Object.entries(cues)) {
  writeFileSync(join(ROOT, `${name}.wav`), wav(samples));
  console.log(`${name}.wav  ${(samples.length / RATE).toFixed(2)}s`);
}
