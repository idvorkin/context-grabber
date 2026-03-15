import { buildHealthData, type HealthQueryResults } from "../lib/health";

/**
 * Tests for the context snapshot shape.
 * Validates that assembled snapshots have the correct structure
 * regardless of which health metrics succeed or fail.
 */

type LocationData = {
  latitude: number;
  longitude: number;
  timestamp: number;
} | null;

type ContextSnapshot = {
  timestamp: string;
  health: ReturnType<typeof buildHealthData>;
  location: LocationData;
};

function buildSnapshot(
  healthResults: HealthQueryResults,
  location: LocationData,
): ContextSnapshot {
  return {
    timestamp: new Date().toISOString(),
    health: buildHealthData(healthResults),
    location,
  };
}

function fulfilled<T>(value: T): PromiseFulfilledResult<T> {
  return { status: "fulfilled", value };
}

function rejected(reason = "error"): PromiseRejectedResult {
  return { status: "rejected", reason };
}

describe("ContextSnapshot shape", () => {
  it("has all required top-level keys", () => {
    const snapshot = buildSnapshot(
      [rejected(), rejected(), rejected(), rejected(), rejected()],
      null,
    );
    expect(snapshot).toHaveProperty("timestamp");
    expect(snapshot).toHaveProperty("health");
    expect(snapshot).toHaveProperty("location");
  });

  it("timestamp is a valid ISO 8601 string", () => {
    const snapshot = buildSnapshot(
      [rejected(), rejected(), rejected(), rejected(), rejected()],
      null,
    );
    const parsed = new Date(snapshot.timestamp);
    expect(parsed.toISOString()).toBe(snapshot.timestamp);
  });

  it("health object has all five metric keys", () => {
    const snapshot = buildSnapshot(
      [rejected(), rejected(), rejected(), rejected(), rejected()],
      null,
    );
    const keys = Object.keys(snapshot.health).sort();
    expect(keys).toEqual([
      "activeEnergy",
      "heartRate",
      "sleepHours",
      "steps",
      "walkingDistance",
    ]);
  });

  it("location is null when unavailable", () => {
    const snapshot = buildSnapshot(
      [rejected(), rejected(), rejected(), rejected(), rejected()],
      null,
    );
    expect(snapshot.location).toBeNull();
  });

  it("location has lat/lng/timestamp when available", () => {
    const location = {
      latitude: 47.6062,
      longitude: -122.3321,
      timestamp: Date.now(),
    };
    const snapshot = buildSnapshot(
      [rejected(), rejected(), rejected(), rejected(), rejected()],
      location,
    );
    expect(snapshot.location).toEqual(location);
    expect(typeof snapshot.location!.latitude).toBe("number");
    expect(typeof snapshot.location!.longitude).toBe("number");
    expect(typeof snapshot.location!.timestamp).toBe("number");
  });

  it("full snapshot with all data populated has correct shape", () => {
    const healthResults: HealthQueryResults = [
      fulfilled({ sumQuantity: { quantity: 10000 } }),
      fulfilled({ quantity: 65 }),
      fulfilled({ sumQuantity: { quantity: 450 } }),
      fulfilled({ sumQuantity: { quantity: 8.25 } }),
      fulfilled([
        {
          startDate: "2026-03-14T23:00:00.000Z",
          endDate: "2026-03-15T07:00:00.000Z",
        },
      ]),
    ];
    const location = {
      latitude: 47.6062,
      longitude: -122.3321,
      timestamp: 1710460800000,
    };
    const snapshot = buildSnapshot(healthResults, location);

    expect(snapshot.health.steps).toBe(10000);
    expect(snapshot.health.heartRate).toBe(65);
    expect(snapshot.health.activeEnergy).toBe(450);
    expect(snapshot.health.walkingDistance).toBe(8.25);
    expect(snapshot.health.sleepHours).toBe(8);
    expect(snapshot.location).toEqual(location);
    expect(typeof snapshot.timestamp).toBe("string");
  });

  it("snapshot with all-null health still serializes to valid JSON", () => {
    const snapshot = buildSnapshot(
      [rejected(), rejected(), rejected(), rejected(), rejected()],
      null,
    );
    const json = JSON.stringify(snapshot);
    const parsed = JSON.parse(json);
    expect(parsed.health.steps).toBeNull();
    expect(parsed.health.heartRate).toBeNull();
    expect(parsed.health.sleepHours).toBeNull();
    expect(parsed.health.activeEnergy).toBeNull();
    expect(parsed.health.walkingDistance).toBeNull();
    expect(parsed.location).toBeNull();
  });
});
