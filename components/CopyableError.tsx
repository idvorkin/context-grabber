import React, { useState } from "react";
import { Text, TouchableOpacity, View, type StyleProp, type ViewStyle } from "react-native";
import * as Clipboard from "expo-clipboard";
import { buildLabel } from "../lib/version";

type Props = {
  /** The raw error string. Rendered in red, selectable. */
  message: string;
  /**
   * Short label that goes into the diagnostics payload — typically the
   * screen or operation name (e.g. "AffirmationCard.save", "JournalScreen.delete").
   * Helps map a copied error to a code path.
   */
  context?: string;
  /** Extra key/value pairs to include in the copied payload. */
  extra?: Record<string, string | number | null | undefined>;
  /** Override the default vertical spacing. */
  style?: StyleProp<ViewStyle>;
};

/**
 * Standardized error display + one-tap copy. Project rule: every
 * user-facing error text must be rendered through this component so
 * Igor can paste a useful payload into chat without retyping.
 *
 * The copied payload always carries: error message, context label,
 * git sha + branch, and any extra fields the caller passes.
 */
export function CopyableError({ message, context, extra, style }: Props) {
  const [hint, setHint] = useState<string | null>(null);

  async function handleCopy() {
    const lines: string[] = [
      context ? `where: ${context}` : null,
      `error: ${message}`,
      `build: ${buildLabel()}`,
    ].filter(Boolean) as string[];
    if (extra) {
      for (const [k, v] of Object.entries(extra)) {
        if (v !== undefined && v !== null) lines.push(`${k}: ${v}`);
      }
    }
    await Clipboard.setStringAsync(lines.join("\n"));
    setHint("Copied");
    setTimeout(() => setHint(null), 1500);
  }

  return (
    <View style={[styles.box, style]}>
      <Text style={styles.message} selectable>
        {message}
      </Text>
      <TouchableOpacity onPress={handleCopy} style={styles.copyBtn}>
        <Text style={styles.copyBtnText}>{hint ?? "Copy error"}</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = {
  box: { marginTop: 8 },
  message: {
    color: "#ff8a8a",
    fontSize: 13,
    lineHeight: 18,
  },
  copyBtn: {
    alignSelf: "flex-start" as const,
    marginTop: 6,
    paddingVertical: 6,
    paddingHorizontal: 10,
    backgroundColor: "#2a1a1a",
    borderRadius: 8,
  },
  copyBtnText: {
    color: "#ffb0b0",
    fontSize: 12,
    fontWeight: "600" as const,
  },
};
