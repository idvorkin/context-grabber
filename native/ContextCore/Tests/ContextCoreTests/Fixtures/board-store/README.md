# Board-store goldens

Shared with the Cockpit (cockpit-8kh). `clash/*.json` are `{name, story, why, input, expect}`: `input` is one
`bw_store_clash` request and `expect` the answer both the app's rule and the Cockpit's store must give. `encode/*.json`
have the same shape for `bw_store_encode`: `input` a board before and after, `expect` its ops, which must also land
whole as one batch under the clash rule. `stroke-record.json` is the one stroke record both sides read, every field of
the web's and the iPad's strokes plus one neither knows, carried unchanged through a move. The Cockpit keeps a copy
pinned by `SHA256SUMS` and runs it through the wasm; here `StoreClashGoldenTests` runs it on the host.

A deliberate rule change: `GOLDEN_WRITE=1` on `StoreClashGoldenTests` rewrites `expect`, read the diff, then
`scripts/native/board-store-goldens.py --write` and tell Larry the new sums.
