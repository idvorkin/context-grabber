/**
 * The duck window: other audio turned down (music) or paused (podcasts)
 * around the Gym Timer's cues, and back a moment after the last one.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md
 *
 * The unit is a window, not a cue: the 3-2-1 ticks are 80 ms a second apart,
 * and ducking each would make the music pump. Each tick or cue *holds* the
 * window; it closes itself when nothing has held it for a while. Closing
 * means letting go of the session — a paused podcast resumes only when the
 * session that paused it deactivates — which is the `DuckSession`'s job;
 * this class only decides *when*. Platform-free, so the timing is tested.
 */

/** After a tick: long enough to reach the next tick or the cue. */
export const TICK_HOLD_MS = 1600;
/** After a phase cue (the GO / rest tones, ~0.5 s): a beat, then back. */
export const CUE_HOLD_MS = 1500;
/** After the finish (rest cue + fanfare, ~1.3 s). */
export const FINISH_HOLD_MS = 2400;
/** Opened a silent second before the 3 tick: reach the tick with room to spare. */
export const OPEN_EARLY_HOLD_MS = 2600;
/** START's GO: opened before the session comes up; long enough for activation plus the tones. */
export const START_HOLD_MS = 2500;

export type DuckSession = {
  /** Put the window's options on the session (`true`) or the base ones (`false`). */
  setDucking(on: boolean): void;
  /** Let go: deactivate (telling others they may resume), reactivate, restart what was playing. */
  release(): Promise<void>;
};

export class DuckWindow {
  private closeTimer: ReturnType<typeof setTimeout> | null = null;
  private open = false;

  constructor(
    private readonly session: DuckSession,
    /** A line for the diagnostics log, if anyone is keeping one. */
    private readonly log: (message: string) => void = () => {},
  ) {}

  get isOpen(): boolean {
    return this.open;
  }

  /** Open the window (if it is not), and keep it open `holdMs` from now. */
  hold(holdMs: number = TICK_HOLD_MS): void {
    if (!this.open) {
      this.open = true;
      this.log(`duck window open (hold ${holdMs} ms)`);
      this.session.setDucking(true);
    } else {
      this.log(`duck window held (${holdMs} ms)`);
    }
    if (this.closeTimer) clearTimeout(this.closeTimer);
    this.closeTimer = setTimeout(() => {
      this.closeTimer = null;
      void this.close();
    }, holdMs);
  }

  /** Close now: base options, then let go of the session. */
  async close(): Promise<void> {
    if (this.closeTimer) {
      clearTimeout(this.closeTimer);
      this.closeTimer = null;
    }
    if (!this.open) return;
    this.open = false;
    this.log("duck window close → base options, letting go of the session");
    this.session.setDucking(false);
    await this.session.release();
    this.log("duck window released");
  }

  /**
   * The timer is letting go of the session itself (reset, done, leaving):
   * drop the window without a release of our own — the timer's deactivation
   * carries the resume for others — but put the base options back.
   */
  forget(): void {
    if (this.closeTimer) {
      clearTimeout(this.closeTimer);
      this.closeTimer = null;
    }
    if (!this.open) return;
    this.open = false;
    this.log("duck window forgotten (the timer is letting go itself)");
    this.session.setDucking(false);
  }
}
