/**
 * The Gym Timer's diagnostics log — what the audio session and the duck
 * window did, with times, so a "music stopped" report can be answered from
 * the phone. The same ring the Call tab keeps, sized for the timer; "Log"
 * on the timer screen puts it on the clipboard behind a build header.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-audio-ducking-design.md
 */
import { CallLog } from "../callLog";

export const TIMER_LOG_LINES = 300;

/** The one log the timer writes to. */
export const timerLog = new CallLog(undefined, TIMER_LOG_LINES);
