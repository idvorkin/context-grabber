/**
 * Pure functions extracted from App.tsx for health data processing.
 * These are side-effect-free and testable without HealthKit or device access.
 */

export type HealthData = {
  steps: number | null;
  heartRate: number | null;
  sleepHours: number | null;
  activeEnergy: number | null;
  walkingDistance: number | null;
};

export type SleepSample = {
  startDate: string | Date;
  endDate: string | Date;
};

/**
 * Calculate total sleep hours from an array of sleep category samples.
 * Each sample has a startDate and endDate; we sum the durations and convert to hours.
 * Returns null if samples is empty or undefined.
 */
export function calculateSleepHours(samples: SleepSample[] | undefined): number | null {
  if (!samples || samples.length === 0) {
    return null;
  }
  const totalMs = samples.reduce((acc, sample) => {
    const start = new Date(sample.startDate).getTime();
    const end = new Date(sample.endDate).getTime();
    return acc + (end - start);
  }, 0);
  return Math.round((totalMs / (1000 * 60 * 60)) * 10) / 10;
}

/**
 * Represents the shape of Promise.allSettled results from HealthKit queries.
 * Index 0: steps (sumQuantity), 1: heartRate (quantity), 2: activeEnergy (sumQuantity),
 * 3: walkingDistance (sumQuantity), 4: sleep (category samples array).
 */
export type HealthQueryResults = [
  PromiseSettledResult<{ sumQuantity?: { quantity: number } | null }>,
  PromiseSettledResult<{ quantity: number } | null>,
  PromiseSettledResult<{ sumQuantity?: { quantity: number } | null }>,
  PromiseSettledResult<{ sumQuantity?: { quantity: number } | null }>,
  PromiseSettledResult<SleepSample[]>,
];

/**
 * Build a HealthData object from Promise.allSettled results.
 * Rejected promises produce null for that metric — never throws.
 */
export function buildHealthData(results: HealthQueryResults): HealthData {
  const [steps, heartRate, activeEnergy, walkingDistance, sleep] = results;

  const sleepHours =
    sleep.status === "fulfilled"
      ? calculateSleepHours(sleep.value)
      : null;

  return {
    steps:
      steps.status === "fulfilled"
        ? Math.round(steps.value.sumQuantity?.quantity ?? 0)
        : null,
    heartRate:
      heartRate.status === "fulfilled" && heartRate.value
        ? Math.round(heartRate.value.quantity)
        : null,
    activeEnergy:
      activeEnergy.status === "fulfilled"
        ? Math.round(activeEnergy.value.sumQuantity?.quantity ?? 0)
        : null,
    walkingDistance:
      walkingDistance.status === "fulfilled"
        ? Math.round(
            (walkingDistance.value.sumQuantity?.quantity ?? 0) * 100
          ) / 100
        : null,
    sleepHours,
  };
}
