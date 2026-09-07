import React from "react";
import { act, fireEvent, render } from "@testing-library/react-native";
import { CardScreen, THINK_MS } from "../screens/CardScreen";
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

describe("CardScreen — the Card tab", () => {
  it("opens on a fresh card, deals another on a tap, and syncs the widgets once on leaving", async () => {
    const bridge = fakeBridge();
    const r = render(<CardScreen bridge={bridge} />);
    await settle();
    expect(bridge.deals).toEqual(["7♣"]);
    expect(r.getByTestId("card-label").props.children).toBe("♣");

    fireEvent.press(r.getByTestId("card-face"));
    await settle();
    expect(bridge.deals).toEqual(["7♣", "Q♥"]);
    expect(r.getByTestId("card-label").props.children).toBe("♥");
    expect(bridge.syncs).toBe(0); // not on every deal

    r.unmount();
    await settle();
    expect(bridge.syncs).toBe(1);
  });

  it("Think of a card: face down, a count from ten, a new card face up ten seconds later", async () => {
    jest.useFakeTimers();
    try {
      const bridge = fakeBridge();
      const r = render(<CardScreen bridge={bridge} />);
      await settle();
      expect(bridge.deals).toHaveLength(1);

      fireEvent.press(r.getByTestId("card-think"));
      expect(r.queryByTestId("card-face")).toBeNull();
      expect(r.getByTestId("card-back")).toBeTruthy();
      expect(r.getByTestId("card-count").props.children).toBe(10);
      expect(r.getByText("Never mind")).toBeTruthy();

      await act(async () => {
        jest.advanceTimersByTime(3000);
      });
      expect(r.getByTestId("card-count").props.children).toBe(7);
      expect(bridge.deals).toHaveLength(1); // nothing dealt yet

      await act(async () => {
        jest.advanceTimersByTime(THINK_MS - 3000);
      });
      await settle();
      expect(bridge.deals).toEqual(["7♣", "Q♥"]);
      expect(r.getByTestId("card-face")).toBeTruthy();
      expect(r.getByTestId("card-label").props.children).toBe("♥");
      expect(r.getByText("Think of a card")).toBeTruthy();
    } finally {
      jest.useRealTimers();
    }
  });

  it("Never mind mid-count: the count stops and the previous card is face up, nothing dealt", async () => {
    jest.useFakeTimers();
    try {
      const bridge = fakeBridge();
      const r = render(<CardScreen bridge={bridge} />);
      await settle();
      fireEvent.press(r.getByTestId("card-think"));
      await act(async () => {
        jest.advanceTimersByTime(4000);
      });
      fireEvent.press(r.getByTestId("card-think"));
      expect(r.getByTestId("card-label").props.children).toBe("♣");
      await act(async () => {
        jest.advanceTimersByTime(THINK_MS);
      });
      await settle();
      expect(bridge.deals).toEqual(["7♣"]);
    } finally {
      jest.useRealTimers();
    }
  });

  it("on a binary without the deal, says so — copyable, not blank", async () => {
    const bridge = fakeBridge(false);
    const r = render(<CardScreen bridge={bridge} />);
    await settle();
    expect(r.queryByTestId("card-face")).toBeNull();
    expect(r.getByText(NEEDS_NEWER_BUILD)).toBeTruthy();
    expect(r.getByText(/Copy error/i)).toBeTruthy();
  });
});
