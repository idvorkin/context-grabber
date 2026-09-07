import React, { useCallback, useEffect, useState } from "react";
import { AppState, Modal, Pressable, StyleSheet, Text, View } from "react-native";
import { cardBridge, type CardBridge, type DealtCard } from "../lib/cardBridge";
import { CopyableError } from "./CopyableError";

/**
 * The memdeck card screen — where a tap on a lock-screen widget lands
 * (grabber://card). One big card, dealt fresh on arrival; tap it for another;
 * "Every 10 s" keeps dealing until "Stop" or the screen closes. The widgets
 * are brought in line once, when the screen closes or the phone locks with
 * it open — not on every tick.
 * Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
 */

export const AUTO_DEAL_MS = 10_000;

type Props = {
  visible: boolean;
  onClose: () => void;
  /** Tests hand in a fake; the app uses the native bridge. */
  bridge?: CardBridge;
};

export function CardModal({ visible, onClose, bridge = cardBridge }: Props) {
  const [card, setCard] = useState<DealtCard | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [auto, setAuto] = useState(false);

  const deal = useCallback(async () => {
    try {
      setCard(await bridge.dealCard());
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }, [bridge]);

  // Arrive on a fresh card. Leave with the drill stopped and the widgets in line.
  useEffect(() => {
    if (!visible) {
      setAuto(false);
      return;
    }
    void deal();
    return () => {
      void bridge.syncCardWidgets();
    };
  }, [visible, deal, bridge]);

  // The phone locking (or the app leaving) with the screen open counts as closing it.
  useEffect(() => {
    if (!visible) return;
    const sub = AppState.addEventListener("change", (state) => {
      if (state !== "active") void bridge.syncCardWidgets();
    });
    return () => sub.remove();
  }, [visible, bridge]);

  // The drill: a new card every ten seconds while "Every 10 s" is on.
  useEffect(() => {
    if (!auto || !visible) return;
    const timer = setInterval(() => {
      void deal();
    }, AUTO_DEAL_MS);
    return () => clearInterval(timer);
  }, [auto, visible, deal]);

  return (
    <Modal visible={visible} animationType="fade" onRequestClose={onClose} testID="card-modal">
      <View style={styles.screen}>
        {error ? (
          <CopyableError
            message={error}
            context="CardModal.deal"
            extra={{ available: bridge.available ? "yes" : "no", auto: auto ? "on" : "off" }}
            style={styles.error}
          />
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
                <Text style={[styles.corner, styles.cornerTop, card.isRed ? styles.red : styles.black]}>
                  {card.rank}
                  {"\n"}
                  {card.suit}
                </Text>
                <Text style={[styles.pip, card.isRed ? styles.red : styles.black]} testID="card-label">
                  {card.suit}
                </Text>
                <Text style={[styles.corner, styles.cornerBottom, card.isRed ? styles.red : styles.black]}>
                  {card.rank}
                  {"\n"}
                  {card.suit}
                </Text>
              </>
            )}
          </Pressable>
        )}

        <Text style={styles.hint}>{error ? "" : "tap the card for another"}</Text>

        <View style={styles.row}>
          <Pressable
            onPress={() => setAuto((a) => !a)}
            disabled={!!error}
            style={[styles.button, auto ? styles.buttonStop : styles.buttonAuto, error && styles.buttonDisabled]}
            testID="card-auto"
            accessibilityRole="button"
            accessibilityState={{ selected: auto }}
          >
            <Text style={[styles.buttonText, auto ? styles.buttonStopText : styles.buttonAutoText]}>
              {auto ? "Stop" : "Every 10 s"}
            </Text>
          </Pressable>
          <Pressable onPress={onClose} style={[styles.button, styles.buttonDone]} testID="card-done" accessibilityRole="button">
            <Text style={[styles.buttonText, styles.buttonDoneText]}>Done</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
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
  hint: { color: "#64748b", fontSize: 14, marginTop: 18, height: 20 },
  row: { flexDirection: "row", gap: 12, marginTop: 28 },
  button: { paddingHorizontal: 22, paddingVertical: 12, borderRadius: 12, minWidth: 120, alignItems: "center" },
  buttonAuto: { backgroundColor: "rgba(59,130,246,0.18)" },
  buttonStop: { backgroundColor: "rgba(239,68,68,0.2)" },
  buttonDone: { backgroundColor: "rgba(148,163,184,0.18)" },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { fontSize: 16, fontWeight: "700" },
  buttonAutoText: { color: "#60a5fa" },
  buttonStopText: { color: "#f87171" },
  buttonDoneText: { color: "#e2e8f0" },
  error: { maxWidth: 340 },
});
