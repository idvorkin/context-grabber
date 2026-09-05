# Diagnostics gist upload — implementation plan

Spec: `../specs/2026-09-05-diagnostics-gist-upload-design.md`.

- `expo-secure-store` (new pod → `just deploy`, commit `ios/Podfile.lock`). `lib/gistToken.ts` wraps get/set/clear with `keychainAccessible: AFTER_FIRST_UNLOCK`; returns `null` on a binary without the module.
- `lib/gistUpload.ts` (pure, tested): `callHadTrouble(lines)` regex over the current call's lines; `renderDiagnosticsGist({build, at, why, header, lines})` → `{description, files}` with the delete-me note; `parseGistResponse(status, json)`; `uploadGist(token, body, fetch)` / `deleteGist(token, id, fetch)`; `pruneUploads(list, keep=10)`.
- Settings keys: `gist_auto_upload` ("true"/"false"), `gist_uploads` (JSON `[{id, url, at}]`, newest first).
- App: on session `ended`, if token && auto && `callHadTrouble(log.current)` → upload, log the line, clipboard, record. `CallScreen` gets `onUpload?: () => Promise<string>` and `lastUploadUrl?`; the Upload button lives beside Copy diagnostics.
- `SettingsModal`: token field (secureTextEntry), saved state, switch, last URL + copy, delete-all with the "deleted N of M" result.
- jest: mock `expo-secure-store` in `jest.setup.js`; `fetch` injected everywhere.
