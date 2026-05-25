import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

export type WeekStripDay = {
  /** Short label, e.g. "M", "T", "Wed". WeekStrip doesn't compute this — caller decides. */
  label: string;
  /** Full date key (YYYY-MM-DD) for the day this cell represents. */
  dateKey: string;
  /** Today gets highlighted. */
  isToday: boolean;
  /** Future days are dimmed and non-interactive. */
  isFuture: boolean;
  /** Optional per-day signal dot (e.g. "this day had a workout"). */
  hasDot?: boolean;
  /** Optional dot color when hasDot is true. */
  dotColor?: string;
};

type Props = {
  days: WeekStripDay[];
  /** Currently-selected day's dateKey (matches a WeekStripDay.dateKey). */
  selectedKey?: string | null;
  onDayPress?: (day: WeekStripDay) => void;
};

export function WeekStrip({ days, selectedKey, onDayPress }: Props) {
  return (
    <View style={styles.row} testID="week-strip">
      {days.map((d) => {
        const isSelected = selectedKey === d.dateKey;
        return (
          <Pressable
            key={d.dateKey}
            disabled={d.isFuture || !onDayPress}
            onPress={() => onDayPress?.(d)}
            style={[
              styles.cell,
              d.isToday && styles.cellToday,
              isSelected && styles.cellSelected,
            ]}
            testID={`week-strip-day-${d.dateKey}`}
            accessibilityRole="button"
            accessibilityLabel={d.dateKey}
            accessibilityState={{ selected: isSelected, disabled: d.isFuture }}
          >
            <Text
              style={[
                styles.label,
                d.isToday && styles.labelToday,
                d.isFuture && styles.labelFuture,
                isSelected && styles.labelSelected,
              ]}
            >
              {d.label}
            </Text>
            <View style={styles.dotSlot}>
              {d.hasDot && (
                <View
                  style={[
                    styles.dot,
                    d.dotColor ? { backgroundColor: d.dotColor } : null,
                  ]}
                />
              )}
            </View>
          </Pressable>
        );
      })}
    </View>
  );
}

/**
 * Build 7 days ending today (so today is the rightmost cell).
 * Labels are single-char day-of-week (S M T W T F S).
 */
export function buildWeekStripDays(
  now: Date,
  formatDateKey: (d: Date) => string,
  dotForDate?: (dateKey: string) => { hasDot: boolean; color?: string } | undefined,
): WeekStripDay[] {
  const dayLabels = ["S", "M", "T", "W", "T", "F", "S"];
  const todayKey = formatDateKey(now);
  const out: WeekStripDay[] = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    const key = formatDateKey(d);
    const dot = dotForDate?.(key);
    out.push({
      label: dayLabels[d.getDay()],
      dateKey: key,
      isToday: key === todayKey,
      isFuture: false,
      hasDot: dot?.hasDot ?? false,
      dotColor: dot?.color,
    });
  }
  return out;
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    paddingHorizontal: 12,
    paddingVertical: 8,
    gap: 4,
  },
  cell: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 6,
    borderRadius: 8,
    backgroundColor: "transparent",
  },
  cellToday: {
    backgroundColor: "rgba(76, 201, 240, 0.12)",
  },
  cellSelected: {
    backgroundColor: "rgba(76, 201, 240, 0.28)",
  },
  label: {
    fontSize: 13,
    fontWeight: "600",
    color: "#888",
  },
  labelToday: {
    color: "#4cc9f0",
  },
  labelSelected: {
    color: "#4cc9f0",
  },
  labelFuture: {
    color: "#444",
  },
  dotSlot: {
    height: 6,
    marginTop: 4,
    alignItems: "center",
    justifyContent: "center",
  },
  dot: {
    width: 5,
    height: 5,
    borderRadius: 2.5,
    backgroundColor: "#4cc9f0",
  },
});
