import React from "react";
import { Image, StyleSheet, View } from "react-native";
import type { RoleId } from "../lib/roles";

/**
 * Static require-map. React Native's Metro bundler statically analyzes
 * `require()` calls — a dynamic key won't resolve, so each role's image
 * must be referenced literally here.
 */
const IMAGES: Record<RoleId, number> = {
  smiles: require("../assets/raccoons/smiles.webp"),
  carfree: require("../assets/raccoons/carfree.webp"),
  habits: require("../assets/raccoons/habits.webp"),
  fit: require("../assets/raccoons/fit.webp"),
  emo: require("../assets/raccoons/emo.webp"),
  tech: require("../assets/raccoons/tech.webp"),
  pro: require("../assets/raccoons/pro.webp"),
  family: require("../assets/raccoons/family.webp"),
  tori: require("../assets/raccoons/tori.webp"),
  amelia: require("../assets/raccoons/amelia.webp"),
  zach: require("../assets/raccoons/zach.webp"),
};

type Props = {
  roleId: RoleId;
  size?: number;
  /** Border ring color — usually the role's hex. */
  ringColor?: string;
};

export function RoleAvatar({ roleId, size = 32, ringColor }: Props) {
  return (
    <View
      style={[
        styles.frame,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          borderColor: ringColor ?? "transparent",
          borderWidth: ringColor ? 1.5 : 0,
        },
      ]}
      testID={`role-avatar-${roleId}`}
    >
      <Image
        source={IMAGES[roleId]}
        style={{
          width: size,
          height: size,
          borderRadius: size / 2,
        }}
        resizeMode="cover"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  frame: {
    overflow: "hidden",
    backgroundColor: "#0c121f",
  },
});
