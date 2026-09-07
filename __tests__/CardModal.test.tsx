import React from "react";
import { act, fireEvent, render } from "@testing-library/react-native";
import { AUTO_DEAL_MS, CardModal } from "../components/CardModal";
import { NEEDS_NEWER_BUILD, type CardBridge, type DealtCard } from "../lib/cardBridge";

// A fake deal: a fixed sequence, so the test can say which card is showing.
function fakeBridge(available = true) {
  const deck: DealtCard[] = [
    { label: "7♣", rank: "7", suit: "♣", isRed: false },
    { label: "Q♥", rank: "Q", suit: "♥", isRed: true },
    { label: "A♠", rank: "A", suit: "♠", isRed: false },
    { label: "10♦", rank: "10", suit: "♦", isRed: true },
  ];
  let i = 0;
  const deals: string[] = [];
  const bridge: CardBridge & { deals: string[]; syncs: number } = {
    available,
    deals,
    syncs: 0,
    async currentCard() {
      return deck[(i - 1 + deck.length) % deck.length];
    },
    async dealCard() {
      if (!available) throw new Error(NEEDS_NEWER_BUILD);
      const card = deck[i % deck.length];
      i += 1;
      deals.push(card.label);
      return card;
    },
    async syncCardWidgets() {
      bridge.syncs += 1;
    },
  };
  return bridge;
}

const settle = () => act(async () => {});

describe("CardModal — the memdeck card screen", () => {
  it("arrives on a fresh card, deals another on a tap, and syncs the widgets once on close", async () => {
    const bridge = fakeBridge();
    const onClose = jest.fn();
    const r = render(<CardModal visible bridge={bridge} onClose={onClose} />);
    await settle();
    expect(bridge.deals).toEqual(["7♣"]);
    expect(r.getByTestId("card-label").props.children).toBe("♣");

    fireEvent.press(r.getByTestId("card-face"));
    await settle();
    expect(bridge.deals).toEqual(["7♣", "Q♥"]);
    expect(r.getByTestId("card-label").props.children).toBe("♥");
    expect(bridge.syncs).toBe(0); // not on every deal

    fireEvent.press(r.getByTestId("card-done"));
    expect(onClose).toHaveBeenCalledTimes(1);
    r.rerender(<CardModal visible={false} bridge={bridge} onClose={onClose} />);
    await settle();
    expect(bridge.syncs).toBe(1);
  });

  it("Every 10 s keeps dealing until Stop, and stops when the screen closes", async () => {
    jest.useFakeTimers();
    try {
      const bridge = fakeBridge();
      const r = render(<CardModal visible bridge={bridge} onClose={() => {}} />);
      await settle();
      expect(bridge.deals).toHaveLength(1);

      fireEvent.press(r.getByTestId("card-auto"));
      expect(r.getByText("Stop")).toBeTruthy();
      await act(async () => {
        jest.advanceTimersByTime(AUTO_DEAL_MS);
      });
      await settle();
      expect(bridge.deals).toHaveLength(2);
      await act(async () => {
        jest.advanceTimersByTime(AUTO_DEAL_MS * 2);
      });
      await settle();
      expect(bridge.deals).toHaveLength(4);

      fireEvent.press(r.getByTestId("card-auto"));
      expect(r.getByText("Every 10 s")).toBeTruthy();
      await act(async () => {
        jest.advanceTimersByTime(AUTO_DEAL_MS * 3);
      });
      await settle();
      expect(bridge.deals).toHaveLength(4); // stopped

      fireEvent.press(r.getByTestId("card-auto"));
      r.rerender(<CardModal visible={false} bridge={bridge} onClose={() => {}} />);
      await act(async () => {
        jest.advanceTimersByTime(AUTO_DEAL_MS * 3);
      });
      await settle();
      expect(bridge.deals).toHaveLength(4); // closing stops it too
    } finally {
      jest.useRealTimers();
    }
  });

  it("on a binary without the deal, says so — copyable, not blank", async () => {
    const bridge = fakeBridge(false);
    const r = render(<CardModal visible bridge={bridge} onClose={() => {}} />);
    await settle();
    expect(r.queryByTestId("card-face")).toBeNull();
    expect(r.getByText(NEEDS_NEWER_BUILD)).toBeTruthy();
    expect(r.getByText(/Copy error/i)).toBeTruthy();
  });
});
