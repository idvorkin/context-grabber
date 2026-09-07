/**
 * The Gym Timer's diagnostics log — what the audio session and the duck
 * window did, with times, so a "music stopped" report can be answered from
 * the phone. A ring of the last few hundred lines, kept for the app's life;
 * "Copy log" on the timer screen puts it on the clipboard behind a build
 * header. Platform-free.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md
 */

export const TIMER_LOG_LINES = 300;

export class TimerLog {
  private lines: string[] = [];
  private startedAt = Date.now();

  constructor(private readonly now: () => number = Date.now) {
    this.startedAt = this.now();
  }

  /** One line, stamped with seconds since the log began. */
  add(message: string): void {
    const t = ((this.now() - this.startedAt) / 1000).toFixed(1);
    this.lines.push(`+${t}s ${message}`);
    if (this.lines.length > TIMER_LOG_LINES) this.lines.splice(0, this.lines.length - TIMER_LOG_LINES);
  }

  get length(): number {
    return this.lines.length;
  }

  /** The lines, oldest first, under a header the caller supplies (build, state). */
  render(header: Record<string, string | number | null | undefined> = {}): string {
    const head = Object.entries(header)
      .filter(([, v]) => v !== undefined && v !== null)
      .map(([k, v]) => `${k}: ${v}`);
    return [...head, head.length ? "" : null, ...(this.lines.length ? this.lines : ["(nothing logged yet)"])]
      .filter((l): l is string => l !== null)
      .join("\n");
  }

  clear(): void {
    this.lines = [];
    this.startedAt = this.now();
  }
}

/** The one log the timer writes to. */
export const timerLog = new TimerLog();
