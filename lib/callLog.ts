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

export class CallLog {
  private lines: string[] = [];
  private listeners = new Set<LogListener>();
  private readonly now: () => number;
  private t0: number;

  constructor(now: () => number = () => Date.now()) {
    this.now = now;
    this.t0 = now();
  }

  /** Seconds since the log (re)started, e.g. `+12.3s`. */
  private stamp(): string {
    return `+${((this.now() - this.t0) / 1000).toFixed(1)}s`;
  }

  add(line: string): void {
    this.lines.push(`${this.stamp()} ${line}`);
    if (this.lines.length > CALL_LOG_LINES) this.lines.splice(0, this.lines.length - CALL_LOG_LINES);
    for (const l of this.listeners) l(this.lines);
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
    if (this.lines.length > CALL_LOG_LINES) this.lines.splice(0, this.lines.length - CALL_LOG_LINES);
    this.t0 = this.now();
    for (const l of this.listeners) l(this.lines);
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
