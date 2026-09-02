/**
 * The call's own log: a short ring of timestamped lines that the session,
 * the audio layer and the screen all write to, and that the Diagnostics
 * fold shows and copies. Native NSLog output never reaches Igor's phone
 * screen; this does.
 *
 * Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md,
 * "Diagnostics".
 */

/** Room for six to ten calls: a silent call's evidence must outlive its retry and a few more (#92, #95). */
export const CALL_LOG_LINES = 900;

/** Between calls. The calls before must survive their retries (#92). */
export const CALL_SEPARATOR = "──────── previous call above ────────";

type LogListener = (lines: readonly string[]) => void;

/** Where the log is mirrored as it grows (#106): a file, so a freeze loses nothing. */
type LogSink = (text: string) => void;

/** Above the lines recovered from the previous run of the app. */
export const RECOVERED_HEADER = "──────── previous run, recovered from disk ────────";

export class CallLog {
  private lines: string[] = [];
  private listeners = new Set<LogListener>();
  private readonly now: () => number;
  private t0: number;
  private sink: LogSink | null = null;
  private sinkDelayMs = 500;
  private sinkTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(now: () => number = () => Date.now()) {
    this.now = now;
    this.t0 = now();
  }

  /**
   * Mirror the whole log to `sink` shortly after every change (#106). Igor,
   * 2026-08-30: "I had a freeze when I switched microphones — hopefully the
   * app was actually storing everything." Write-through, debounced, whole
   * text each time: the log is a few hundred lines and a partial append is
   * worse than a late full copy.
   */
  attachSink(sink: LogSink, delayMs = 500): void {
    this.sink = sink;
    this.sinkDelayMs = delayMs;
    this.scheduleSink();
  }

  /** The previous run's lines, from disk, ahead of everything: the call that froze is in there. */
  preload(lines: readonly string[]): void {
    const kept = lines.filter((l) => l.length > 0);
    if (!kept.length) return;
    this.lines = [RECOVERED_HEADER, ...kept, CALL_SEPARATOR, ...this.lines];
    this.cap();
    this.touch();
  }

  private cap(): void {
    if (this.lines.length > CALL_LOG_LINES) this.lines.splice(0, this.lines.length - CALL_LOG_LINES);
  }

  private touch(): void {
    for (const l of this.listeners) l(this.lines);
    this.scheduleSink();
  }

  private scheduleSink(): void {
    if (!this.sink) return;
    if (this.sinkTimer) clearTimeout(this.sinkTimer);
    this.sinkTimer = setTimeout(() => {
      this.sinkTimer = null;
      try {
        this.sink?.(this.lines.join("\n"));
      } catch {
        // the mirror is best-effort; the lines are still on screen
      }
    }, this.sinkDelayMs);
  }

  /** Seconds since the log (re)started, e.g. `+12.3s`. */
  private stamp(): string {
    return `+${((this.now() - this.t0) / 1000).toFixed(1)}s`;
  }

  add(line: string): void {
    this.lines.push(`${this.stamp()} ${line}`);
    this.cap();
    this.touch();
  }

  /**
   * A new call: keep everything so far behind a separator (the line cap
   * drops the oldest), restart the clock. One call back was not enough —
   * a silent call's lines were gone after its retry and one more (#95).
   */
  reset(): void {
    if (this.lines.length && this.lines[this.lines.length - 1] !== CALL_SEPARATOR) {
      this.lines.push(CALL_SEPARATOR);
    }
    this.cap();
    this.t0 = this.now();
    this.touch();
  }

  /** The current call's lines only (after the last separator). */
  get current(): readonly string[] {
    const cut = this.lines.lastIndexOf(CALL_SEPARATOR);
    return cut >= 0 ? this.lines.slice(cut + 1) : this.lines;
  }

  get all(): readonly string[] {
    return this.lines;
  }

  subscribe(listener: LogListener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Everything on the clipboard: header lines first, then the log. */
  render(header: Record<string, string | number | null | undefined>): string {
    const head = Object.entries(header)
      .filter(([, v]) => v !== undefined && v !== null && v !== "")
      .map(([k, v]) => `${k}: ${v}`);
    return [...head, "---", ...this.lines].join("\n");
  }
}

/** A log that goes nowhere — for tests and for callers that have none. */
export const NO_LOG: Pick<CallLog, "add"> = { add: () => {} };
