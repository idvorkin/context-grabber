/**
 * The memdeck card, from the app: the same deal the widgets make, bridged
 * through the native WidgetBridge module (ios/ContextGrabber/WidgetBridge.swift,
 * which compiles the widgets' PlayingCard.swift into the app).
 * Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
 *
 * A binary older than the feature has no `dealCard`; `available` says so and
 * the card screen shows a note instead of a card. Android: never available.
 */
import { NativeModules, Platform } from "react-native";

export type DealtCard = {
  /** "7♣" */
  label: string;
  rank: string;
  suit: string;
  isRed: boolean;
};

export type CardBridge = {
  readonly available: boolean;
  /** The card the widgets show right now. */
  currentCard(): Promise<DealtCard>;
  /** Deal a new card and hand it back. Does not redraw the widgets. */
  dealCard(): Promise<DealtCard>;
  /** Bring the widgets in line with the last deal. */
  syncCardWidgets(): Promise<void>;
};

export const NEEDS_NEWER_BUILD = "The card needs the build from 2026-09-07 or later; this one is older.";

type NativeCardMethods = {
  currentCard?: () => Promise<DealtCard>;
  dealCard?: () => Promise<DealtCard>;
  syncCardWidgets?: () => Promise<void>;
};

function native(): NativeCardMethods | undefined {
  if (Platform.OS !== "ios") return undefined;
  return (NativeModules as { WidgetBridge?: NativeCardMethods }).WidgetBridge;
}

export const cardBridge: CardBridge = {
  get available() {
    return typeof native()?.dealCard === "function";
  },
  async currentCard() {
    const n = native();
    if (!n?.currentCard) throw new Error(NEEDS_NEWER_BUILD);
    return n.currentCard();
  },
  async dealCard() {
    const n = native();
    if (!n?.dealCard) throw new Error(NEEDS_NEWER_BUILD);
    return n.dealCard();
  },
  async syncCardWidgets() {
    const n = native();
    if (!n?.syncCardWidgets) return;
    await n.syncCardWidgets();
  },
};
