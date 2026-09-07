import React, { useCallback, useEffect, useState } from "react";
import { AppState, Pressable, StyleSheet, Text, View } from "react-native";
import { cardBridge, type CardBridge, type DealtCard } from "../lib/cardBridge";
import { CopyableError } from "../components/CopyableError";

/**
 * The Card tab — where a tap on a lock-screen widget lands (grabber://card).
 * One big card, dealt fresh every time the tab opens; tap it for another.
 * "Think of a card": the card goes face down, a count runs from ten, and a
 * new card is face up ten seconds later — the one they thought of. The
 * widgets are brought in line once, when the tab is left or the phone locks
 * on it — not on every deal.
 * Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
 */

export const THINK_MS = 10_000;

type Props = {
  /** Tests hand in a fake; the app uses the native bridge. */
  bridge?: CardBridge;
};

export function CardScreen({ bridge = cardBridge }: Props) {
  const [card, setCard] = useState<DealtCard | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [thinking, setThinking] = useState(false);
  const [left, setLeft] = useState(THINK_MS / 1000);

  const deal = useCallback(async () => {
    try {
      setCard(await bridge.dealCard());
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }, [bridge]);

  // Arrive on a fresh card; leave with the widgets in line.
  useEffect(() => {
    void deal();
    return () => {
      void bridge.syncCardWidgets();
    };
  }, [deal, bridge]);

  // The phone locking (or the app leaving) on this tab counts as leaving it.
  useEffect(() => {
    const sub = AppState.addEventListener("change", (state) => {
      if (state !== "active") void bridge.syncCardWidgets();
    });
    return () => sub.remove();
  }, [bridge]);

  // Think of a card: face down, a count from ten, then the new card face up.
  useEffect(() => {
    if (!thinking) return;
    setLeft(THINK_MS / 1000);
    const tick = setInterval(() => setLeft((n) => Math.max(0, n - 1)), 1000);
    const reveal = setTimeout(() => {
      setThinking(false);
      void deal();
    }, THINK_MS);
    return () => {
      clearInterval(tick);
      clearTimeout(reveal);
    };
  }, [thinking, deal]);

  const ink = card?.isRed ? styles.red : styles.black;

  return (
    <View style={styles.screen} testID="card-screen">
      {error ? (
        <CopyableError
          message={error}
          context="CardScreen.deal"
          extra={{ available: bridge.available ? "yes" : "no", thinking: thinking ? "yes" : "no" }}
          style={styles.error}
        />
      ) : thinking ? (
        <View style={styles.back} testID="card-back" accessibilityLabel={`Think of a card; ${left} seconds`}>
          <View style={styles.backInner}>
            <Text style={styles.backCount} testID="card-count">
              {left}
            </Text>
            <Text style={styles.backWords}>think of a card…</Text>
          </View>
        </View>
      ) : (
        <Pressable
          onPress={() => void deal()}
          style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}
          testID="card-face"
          accessibilityRole="button"
          accessibilityLabel={card ? `Memdeck card ${card.label}; tap for another` : "Dealing"}
        >
          {card && (
            <>
              <Text style={[styles.corner, styles.cornerTop, ink]}>
                {card.rank}
                {"\n"}
                {card.suit}
              </Text>
              <Text style={[styles.pip, ink]} testID="card-label">
                {card.suit}
              </Text>
              <Text style={[styles.corner, styles.cornerBottom, ink]}>
                {card.rank}
                {"\n"}
                {card.suit}
              </Text>
            </>
          )}
        </Pressable>
      )}

      <Text style={styles.hint}>{error ? "" : thinking ? "shuffle…" : "tap the card for another"}</Text>

      <Pressable
        onPress={() => setThinking((t) => !t)}
        disabled={!!error}
        style={[styles.button, thinking ? styles.buttonStop : styles.buttonThink, error && styles.buttonDisabled]}
        testID="card-think"
        accessibilityRole="button"
        accessibilityState={{ selected: thinking }}
      >
        <Text style={[styles.buttonText, thinking ? styles.buttonStopText : styles.buttonThinkText]}>
          {thinking ? "Never mind" : "Think of a card"}
        </Text>
      </Pressable>
    </View>
  );
}

const CARD_W = 240;
const CARD_H = 336;

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: "#0f172a", alignItems: "center", justifyContent: "center", padding: 24 },
  card: {
    width: CARD_W,
    height: CARD_H,
    backgroundColor: "#ffffff",
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "rgba(0,0,0,0.25)",
    alignItems: "center",
    justifyContent: "center",
  },
  cardPressed: { opacity: 0.85 },
  corner: { position: "absolute", fontSize: 28, fontWeight: "800", lineHeight: 30, textAlign: "center" },
  cornerTop: { top: 12, left: 14 },
  cornerBottom: { bottom: 12, right: 14, transform: [{ rotate: "180deg" }] },
  pip: { fontSize: 128, fontWeight: "700", lineHeight: 140 },
  red: { color: "#cc1722" },
  black: { color: "#141414" },
  // The back: a plain blue card with a white frame, as a deck has.
  back: {
    width: CARD_W,
    height: CARD_H,
    backgroundColor: "#ffffff",
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "rgba(0,0,0,0.25)",
    padding: 12,
  },
  backInner: {
    flex: 1,
    borderRadius: 10,
    backgroundColor: "#1e3a8a",
    borderWidth: 2,
    borderColor: "#93c5fd",
    alignItems: "center",
    justifyContent: "center",
  },
  backCount: { color: "#ffffff", fontSize: 96, fontWeight: "800", lineHeight: 104 },
  backWords: { color: "#bfdbfe", fontSize: 16, marginTop: 8 },
  hint: { color: "#64748b", fontSize: 14, marginTop: 18, height: 20 },
  button: { marginTop: 28, paddingHorizontal: 26, paddingVertical: 14, borderRadius: 12, minWidth: 200, alignItems: "center" },
  buttonThink: { backgroundColor: "rgba(59,130,246,0.18)" },
  buttonStop: { backgroundColor: "rgba(239,68,68,0.2)" },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { fontSize: 17, fontWeight: "700" },
  buttonThinkText: { color: "#60a5fa" },
  buttonStopText: { color: "#f87171" },
  error: { maxWidth: 340 },
});
