/**
 * How the Cockpit web view tells the page it is inside Context Grabber (#78).
 *
 * The page can *infer* it (it finds `window.ReactNativeWebView`, the audio
 * bridge), but nothing after the page knows: the bridge's session rows
 * record backend and model only, so Larry cannot tell an app call from a
 * browser call. So the app says so, in the one place every page load sees
 * first — the URL: `?client=context-grabber&v=<build>`. The native Call tab
 * says the same thing on its start frame (`client` / `build`); this is the
 * web view's half. Page half: cockpit bead igor2-88g.248.
 *
 * Spec: docs/superpowers/specs/2026-08-27-cockpit-tab-design.md, "The page
 * knows it is in the app".
 */

import { CLIENT_NAME } from "./callProtocol";

/**
 * The URL with the client tag on its query, before any `#route`. Written by
 * hand rather than through `URL.searchParams`, which React Native's URL
 * polyfill does not implement.
 */
export function clientTaggedUrl(url: string, build: string): string {
  const hashAt = url.indexOf("#");
  const base = hashAt >= 0 ? url.slice(0, hashAt) : url;
  const hash = hashAt >= 0 ? url.slice(hashAt) : "";
  const sep = base.includes("?") ? "&" : "?";
  const tag = `client=${CLIENT_NAME}${build ? `&v=${encodeURIComponent(build)}` : ""}`;
  return `${base}${sep}${tag}${hash}`;
}
