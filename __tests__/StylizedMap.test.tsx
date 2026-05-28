import React from "react";
import { render, act, fireEvent } from "@testing-library/react-native";
import { StylizedMap, type PathPoint } from "../components/StylizedMap";

// Fire an onLayout event so the component knows the frame's pt size; the
// path-segment renderer skips when frameSize is null.
function layoutMap(testID: string, getByTestId: (id: string) => any) {
  const map = getByTestId(testID);
  act(() => {
    fireEvent(map, "layout", {
      nativeEvent: { layout: { width: 320, height: 180, x: 0, y: 0 } },
    });
  });
}

describe("StylizedMap path overlay", () => {
  const baseProps = {
    currentLocation: {
      latitude: 47.61,
      longitude: -122.33,
      timestamp: Date.now(),
    },
    knownPlaces: [
      {
        id: 1,
        name: "Home",
        latitude: 47.6419,
        longitude: -122.3045,
        radiusMeters: 100,
      },
    ],
  };

  it("renders pins without a path prop (backward compat)", () => {
    const result = render(<StylizedMap {...baseProps} />);
    expect(result.getByTestId("stylized-map")).toBeTruthy();
    expect(result.getByTestId("map-pin-current")).toBeTruthy();
    expect(result.getByTestId("map-pin-p-1")).toBeTruthy();
    // No path → no segments and no path dots.
    expect(result.queryByTestId("seg-1")).toBeNull();
    expect(result.queryByTestId("map-path-dot-0")).toBeNull();
  });

  it("renders no path overlay when path has < 2 points", () => {
    const path: PathPoint[] = [{ lat: 47.6, lon: -122.33 }];
    const result = render(<StylizedMap {...baseProps} path={path} />);
    layoutMap("stylized-map", result.getByTestId);
    expect(result.queryByTestId("seg-1")).toBeNull();
    expect(result.queryByTestId("map-path-dot-0")).toBeNull();
  });

  it("renders polyline segments + dots for a 3-point path", () => {
    const path: PathPoint[] = [
      { lat: 47.6419, lon: -122.3045, timestamp: 1 }, // Home
      { lat: 47.6289, lon: -122.3432, timestamp: 2 }, // Work
      { lat: 47.6762, lon: -122.3187, timestamp: 3 }, // KB gym
    ];
    const result = render(<StylizedMap {...baseProps} path={path} />);
    layoutMap("stylized-map", result.getByTestId);

    // Two segments connect three points.
    expect(result.getByTestId("seg-1")).toBeTruthy();
    expect(result.getByTestId("seg-2")).toBeTruthy();
    expect(result.queryByTestId("seg-3")).toBeNull();

    // One breadcrumb dot per path point.
    expect(result.getByTestId("map-path-dot-0")).toBeTruthy();
    expect(result.getByTestId("map-path-dot-1")).toBeTruthy();
    expect(result.getByTestId("map-path-dot-2")).toBeTruthy();

    // Pins still render on top of the path.
    expect(result.getByTestId("map-pin-current")).toBeTruthy();
    expect(result.getByTestId("map-pin-p-1")).toBeTruthy();
  });

  it("filters non-finite path points", () => {
    const path: PathPoint[] = [
      { lat: 47.6419, lon: -122.3045 },
      { lat: NaN, lon: -122.32 },
      { lat: 47.6289, lon: -122.3432 },
    ];
    const result = render(<StylizedMap {...baseProps} path={path} />);
    layoutMap("stylized-map", result.getByTestId);

    // After filtering, only 2 valid points → 1 segment, 2 dots.
    expect(result.getByTestId("seg-1")).toBeTruthy();
    expect(result.queryByTestId("seg-2")).toBeNull();
    expect(result.getByTestId("map-path-dot-0")).toBeTruthy();
    expect(result.getByTestId("map-path-dot-1")).toBeTruthy();
    expect(result.queryByTestId("map-path-dot-2")).toBeNull();
  });

  it("renders empty state when there are no pins and no path", () => {
    const result = render(
      <StylizedMap currentLocation={null} knownPlaces={[]} />,
    );
    expect(result.getByTestId("stylized-map")).toBeTruthy();
    // Empty hint text from existing behavior.
    expect(
      result.getByText(
        /No location yet — grab context or add a known place\./,
      ),
    ).toBeTruthy();
  });
});
