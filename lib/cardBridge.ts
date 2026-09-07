/**
 * The memdeck card, from the app: the same deal the widgets make, over the
 * native WidgetBridge module (ios/ContextGrabber/WidgetBridge.swift, which
 * compiles the widgets' PlayingCard.swift into the app).
 * Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
 *
 * A binary older than the feature has no `dealCard`; `available` says so and
 * the Card tab shows a note instead of a card. Android: never available.
 */
import { widgetBridge } from "./widgetSnapshot";

export type DealtCard = {
  /** "7♣" */
  label: string;
  rank: string;
  suit: string;
  isRed: boolean;
};

export type CardBridge = {
  readonly available: boolean;
  /** Deal a new card and hand it back. Does not redraw the widgets. */
  dealCard(): Promise<DealtCard>;
  /** Bring the widgets in line with the last deal. */
  syncCardWidgets(): Promise<void>;
};

export const NEEDS_NEWER_BUILD = "The card needs the build from 2026-09-07 or later; this one is older.";

export const cardBridge: CardBridge = {
  get available() {
    return typeof widgetBridge()?.dealCard === "function";
  },
  async dealCard() {
    const n = widgetBridge();
    if (!n?.dealCard) throw new Error(NEEDS_NEWER_BUILD);
    return n.dealCard();
  },
  async syncCardWidgets() {
    await widgetBridge()?.syncCardWidgets?.();
  },
};
