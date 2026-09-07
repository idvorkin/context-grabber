import React from "react";
import { fireEvent, render } from "@testing-library/react-native";
import { StepSlider, snapToStep } from "../components/StepSlider";

describe("StepSlider — a slider drawn by the app", () => {
  it("snaps to its step inside its range", () => {
    expect(snapToStep(64, 10, 600, 10)).toBe(60);
    expect(snapToStep(66, 10, 600, 10)).toBe(70);
    expect(snapToStep(-100, 10, 600, 10)).toBe(10);
    expect(snapToStep(9000, 10, 600, 10)).toBe(600);
    expect(snapToStep(3.4, 1, 20, 1)).toBe(3);
  });

  it("steps with − and +, reads its value, and does nothing while disabled", () => {
    const onChange = jest.fn();
    const r = render(
      <StepSlider label="Work" value={60} min={10} max={600} step={10} onChange={onChange} format={(v) => `${v}s`} testID="work" />,
    );
    expect(r.getByTestId("work-value").props.children).toBe("60s");
    fireEvent.press(r.getByTestId("work-plus"));
    expect(onChange).toHaveBeenLastCalledWith(70);
    fireEvent.press(r.getByTestId("work-minus"));
    expect(onChange).toHaveBeenLastCalledWith(50);

    onChange.mockClear();
    r.rerender(
      <StepSlider label="Work" value={60} min={10} max={600} step={10} onChange={onChange} disabled testID="work" />,
    );
    fireEvent.press(r.getByTestId("work-plus"));
    expect(onChange).not.toHaveBeenCalled();
  });

  it("a tap on the track lands on the nearest step for that position", () => {
    const onChange = jest.fn();
    const r = render(<StepSlider label="Work" value={60} min={0} max={100} step={10} onChange={onChange} testID="work" />);
    const track = r.getByTestId("work-track");
    fireEvent(track, "layout", { nativeEvent: { layout: { width: 200, height: 32 } } });
    // The pan responder's grant handler is what a touch-down calls.
    fireEvent(track, "responderGrant", { nativeEvent: { locationX: 150 }, touchHistory: { touchBank: [] } });
    expect(onChange).toHaveBeenLastCalledWith(80); // 150/200 of 0..100 → 75 → snapped to 80
  });

  it("is adjustable for VoiceOver: increment and decrement actions step it", () => {
    const onChange = jest.fn();
    const r = render(<StepSlider label="Rounds" value={5} min={1} max={20} step={1} onChange={onChange} testID="rounds" />);
    const track = r.getByTestId("rounds-track");
    expect(track.props.accessibilityValue).toEqual({ min: 1, max: 20, now: 5, text: "5" });
    fireEvent(track, "accessibilityAction", { nativeEvent: { actionName: "increment" } });
    expect(onChange).toHaveBeenLastCalledWith(6);
    fireEvent(track, "accessibilityAction", { nativeEvent: { actionName: "decrement" } });
    expect(onChange).toHaveBeenLastCalledWith(4);
  });
});
