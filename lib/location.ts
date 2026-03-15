/**
 * Pure functions for location tracking logic.
 */

/**
 * Calculate the pruning threshold timestamp.
 * Returns a UTC unix milliseconds timestamp; any location with a timestamp
 * before this value should be pruned.
 *
 * @param retentionDays Number of days to retain. 0 means prune everything.
 * @param now Current time as UTC unix milliseconds.
 * @returns Cutoff timestamp in UTC unix milliseconds.
 */
export function pruneThreshold(retentionDays: number, now: number): number {
  const safeDays = Math.max(0, retentionDays);
  return now - safeDays * 86400000;
}
