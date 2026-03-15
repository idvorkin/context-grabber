import type { HealthData } from "./health";

/**
 * Format ISO timestamp to short time: "2026-03-15T23:00:00Z" -> "11pm"
 */
export function formatTime(isoString: string): string {
  const date = new Date(isoString);
  const hours = date.getUTCHours();
  const minutes = date.getUTCMinutes();

  const period = hours >= 12 ? "pm" : "am";
  let displayHour = hours % 12;
  if (displayHour === 0) displayHour = 12;

  if (minutes === 0) {
    return `${displayHour}${period}`;
  }
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
    parts.push(`${health.weight} kg`);
  }

  if (health.meditationMinutes != null) {
    parts.push(`${health.meditationMinutes} min meditation`);
  }

  if (locationCount > 0) {
    parts.push(`${formatNumber(locationCount)} locations`);
  }

  return parts.join(" | ");
}
