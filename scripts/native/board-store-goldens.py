#!/usr/bin/env python3
"""The shared board-store goldens' sums (cockpit-8kh): the Cockpit keeps a sha-pinned copy of
native/ContextCore/Tests/ContextCoreTests/Fixtures/board-store/, so SHA256SUMS there must name every golden.
Usage: board-store-goldens.py [--write] [dir]   (default: check, failing on a stale, missing or extra sum)"""
import hashlib
import pathlib
import sys

args = [a for a in sys.argv[1:] if a != "--write"]
root = pathlib.Path(args[0] if args else pathlib.Path(__file__).resolve().parents[2]
                    / "native/ContextCore/Tests/ContextCoreTests/Fixtures/board-store")
sums = root / "SHA256SUMS"
want = "".join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(root).as_posix()}\n"
               for p in sorted(root.rglob("*.json")))
if "--write" in sys.argv:
    sums.write_text(want)
    print(f"wrote {sums}")
    sys.exit(0)
have = sums.read_text() if sums.exists() else ""
if have != want:
    print(f"FAIL {sums} is stale: run scripts/native/board-store-goldens.py --write and tell Larry the new sums")
    sys.exit(1)
print(f"ok   board-store goldens: {want.count(chr(10))} files match SHA256SUMS")
