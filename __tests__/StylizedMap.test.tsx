import React from "react";
import { render, fireEvent } from "@testing-library/react-native";
import { StylizedMap, type PathPoint } from "../components/StylizedMap";

describe("StylizedMap", () => {
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

  it("renders pins without a path prop", () => {
    const result = render(<StylizedMap {...baseProps} />);
    expect(result.getByTestId("stylized-map")).toBeTruthy();
    expect(result.getByTestId("map-pin-current")).toBeTruthy();
    expect(result.getByTestId("map-pin-p-1")).toBeTruthy();
    expect(result.queryByTestId("map-path-polyline")).toBeNull();
  });

  it("renders no polyline when path has < 2 points", () => {
    const path: PathPoint[] = [{ lat: 47.6, lon: -122.33 }];
    const result = render(<StylizedMap {...baseProps} path={path} />);
    expect(result.queryByTestId("map-path-polyline")).toBeNull();
  });

  it("renders polyline with all coordinates for a 3-point path", () => {
    const path: PathPoint[] = [
      { lat: 47.6419, lon: -122.3045, timestamp: 1 },
      { lat: 47.6289, lon: -122.3432, timestamp: 2 },
      { lat: 47.6762, lon: -122.3187, timestamp: 3 },
    ];
    const result = render(<StylizedMap {...baseProps} path={path} />);

    const polyline = result.getByTestId("map-path-polyline");
    expect(polyline.props.coordinates).toHaveLength(3);
    expect(polyline.props.coordinates[0]).toEqual({
      latitude: 47.6419,
      longitude: -122.3045,
    });

    expect(result.getByTestId("map-pin-current")).toBeTruthy();
    expect(result.getByTestId("map-pin-p-1")).toBeTruthy();
  });

  it("filters non-finite path points out of the polyline", () => {
    const path: PathPoint[] = [
      { lat: 47.6419, lon: -122.3045 },
      { lat: NaN, lon: -122.32 },
      { lat: 47.6289, lon: -122.3432 },
    ];
    const result = render(<StylizedMap {...baseProps} path={path} />);
    const polyline = result.getByTestId("map-path-polyline");
    expect(polyline.props.coordinates).toHaveLength(2);
  });

  it("renders empty state when there are no pins and no path", () => {
    const result = render(
      <StylizedMap currentLocation={null} knownPlaces={[]} />,
    );
    expect(result.getByTestId("stylized-map")).toBeTruthy();
    expect(
      result.getByText(
        /No location yet — grab context or add a known place\./,
      ),
    ).toBeTruthy();
  });

  it("shows find-me and fullscreen controls when a location is present", () => {
    const result = render(<StylizedMap {...baseProps} />);
    expect(result.getByTestId("map-find-me")).toBeTruthy();
    expect(result.getByTestId("map-fullscreen")).toBeTruthy();
  });

  it("keeps find-me and copy visible without a current location (no You pin)", () => {
    // Places give a region so the map still renders. The controls stay put
    // so they don't vanish; tapping them shows a "waiting for a lock" hint.
    const result = render(
      <StylizedMap currentLocation={null} knownPlaces={baseProps.knownPlaces} />,
    );
    expect(result.getByTestId("stylized-map")).toBeTruthy();
    expect(result.queryByTestId("map-pin-current")).toBeNull();
    expect(result.getByTestId("map-find-me")).toBeTruthy();
    expect(result.getByTestId("map-copy-coords")).toBeTruthy();
    expect(result.getByTestId("map-fullscreen")).toBeTruthy();
  });

  it("shows the waiting-for-lock hint when find-me is tapped with no location", () => {
    const result = render(
      <StylizedMap currentLocation={null} knownPlaces={baseProps.knownPlaces} />,
    );
    expect(result.queryByTestId("map-hint")).toBeNull();
    fireEvent.press(result.getByTestId("map-find-me"));
    expect(result.getByTestId("map-hint")).toBeTruthy();
    expect(result.getByText(/Waiting for a live GPS lock/)).toBeTruthy();
  });

  it("shows the hint when copy is tapped with no location", () => {
    const result = render(
      <StylizedMap currentLocation={null} knownPlaces={baseProps.knownPlaces} />,
    );
    fireEvent.press(result.getByTestId("map-copy-coords"));
    expect(result.getByTestId("map-hint")).toBeTruthy();
  });

  it("opens a fullscreen surface when the fullscreen control is tapped", () => {
    const result = render(<StylizedMap {...baseProps} />);
    expect(result.queryByTestId("stylized-map-fullscreen")).toBeNull();
    fireEvent.press(result.getByTestId("map-fullscreen"));
    expect(result.getByTestId("stylized-map-fullscreen")).toBeTruthy();
    // The fullscreen instance carries its own close + find-me controls.
    expect(result.getByTestId("map-fs-fullscreen")).toBeTruthy();
    expect(result.getByTestId("map-fs-find-me")).toBeTruthy();
  });

  it("recenter tap does not throw with a current location", () => {
    const result = render(<StylizedMap {...baseProps} />);
    expect(() => fireEvent.press(result.getByTestId("map-find-me"))).not.toThrow();
  });
});
