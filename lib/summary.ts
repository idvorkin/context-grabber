import type { HealthData } from "./health";

/**
 * Format ISO timestamp to short time in **UTC**: "2026-03-15T23:00:00Z" -> "11pm".
 * Used by the share export so the output is deterministic regardless of where
 * the user (or a downstream LLM) reads it.
 */
export function formatTime(isoString: string): string {
  const date = new Date(isoString);
  return formatClock(date.getUTCHours(), date.getUTCMinutes());
}

/**
 * Format ISO timestamp to short time in the **device's local timezone**:
 * "2026-04-24T05:30:00Z" -> "10:30pm" in PDT.
 * Used for in-app UI where the user reads times against their wall clock.
 */
export function formatLocalTime(isoString: string): string {
  const date = new Date(isoString);
  return formatClock(date.getHours(), date.getMinutes());
}

function formatClock(hours: number, minutes: number): string {
  const period = hours >= 12 ? "pm" : "am";
  let displayHour = hours % 12;
  if (displayHour === 0) displayHour = 12;

  if (minutes === 0) return `${displayHour}${period}`;
  const paddedMinutes = minutes.toString().padStart(2, "0");
  return `${displayHour}:${paddedMinutes}${period}`;
}

/**
 * Format number with commas: 8241 -> "8,241"
 */
export function formatNumber(n: number): string {
  return n.toLocaleString("en-US");
}

/**
 * Build a one-line summary string from health data and location count.
 * Omit sections where data is null.
 */
export function buildSummary(health: HealthData, locationCount: number): string {
  const parts: string[] = [];

  if (health.steps != null) {
    parts.push(`${formatNumber(health.steps)} steps`);
  }

  if (health.sleepHours != null) {
    let sleepPart = `Slept ${health.sleepHours}hrs`;
    if (health.bedtime && health.wakeTime) {
      sleepPart += ` (${formatTime(health.bedtime)}\u2013${formatTime(health.wakeTime)})`;
    }
    parts.push(sleepPart);
  }

  if (health.heartRate != null) {
    parts.push(`${health.heartRate} bpm`);
  }

  if (health.activeEnergy != null) {
    parts.push(`${formatNumber(health.activeEnergy)} kcal`);
  }

  if (health.walkingDistance != null) {
    parts.push(`${health.walkingDistance} km`);
  }

  if (health.weight != null) {
    parts.push(`${Math.round(health.weight * 2.20462)} lbs`);
  }

  if (health.workouts && health.workouts.length > 0) {
    const workoutParts = health.workouts.map(w => {
      let s = `${w.activityType} ${w.durationMinutes}min`;
      if (w.energyBurned) s += ` ${w.energyBurned}kcal`;
      if (w.distanceKm) s += ` ${w.distanceKm}km`;
      return s;
    });
    parts.push(workoutParts.join(", "));
  } else if (health.exerciseMinutes != null) {
    parts.push(`${health.exerciseMinutes} min exercise`);
  }

  if (health.meditationMinutes != null) {
    parts.push(`${health.meditationMinutes} min meditation`);
  }

  if (locationCount > 0) {
    parts.push(`${formatNumber(locationCount)} locations`);
  }

  return parts.join(" | ");
}
