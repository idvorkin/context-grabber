/**
 * The GitHub token for diagnostics uploads, in the iOS Keychain.
 *
 * A classic token with only the `gist` scope. It goes where iOS keeps
 * credentials — readable by this app only, after the phone's first unlock
 * so an upload at the end of a locked-screen call still works. A binary
 * built before the Keychain module was added simply has no token.
 *
 * Spec: docs/superpowers/specs/2026-09-05-diagnostics-gist-upload-design.md
 */

const KEY = "gist_token";

type Store = {
  getItemAsync(key: string, options?: object): Promise<string | null>;
  setItemAsync(key: string, value: string, options?: object): Promise<void>;
  deleteItemAsync(key: string, options?: object): Promise<void>;
  AFTER_FIRST_UNLOCK?: number;
};

function store(): Store | null {
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const m = require("expo-secure-store") as Store;
    return typeof m.getItemAsync === "function" ? m : null;
  } catch {
    return null; // not linked in this binary
  }
}

function options(s: Store): object {
  return s.AFTER_FIRST_UNLOCK !== undefined ? { keychainAccessible: s.AFTER_FIRST_UNLOCK } : {};
}

export async function getGistToken(): Promise<string | null> {
  const s = store();
  if (!s) return null;
  try {
    const v = await s.getItemAsync(KEY, options(s));
    return v && v.trim() ? v.trim() : null;
  } catch {
    return null;
  }
}

/** Empty or whitespace forgets the token. */
export async function setGistToken(token: string): Promise<void> {
  const s = store();
  if (!s) throw new Error("the Keychain module is not in this build — install a device build");
  const v = token.trim();
  if (!v) {
    await s.deleteItemAsync(KEY, options(s));
    return;
  }
  await s.setItemAsync(KEY, v, options(s));
}
