#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["websockets>=13"]
# ///
"""A fake voice bridge for the native app's simulator smoke run (docs/TESTING.md).

It speaks just enough of the real bridge's wire format (`handle_browser` in the Cockpit repo's voice_bridge.py)
to walk a call through every boundary: it answers `start` with `ready` at 16 kHz, acknowledges each `mic_probe`,
and once a few mic frames have arrived it plays the recognizer and Tony — a partial, a final, Tony's sentence
and one second of PCM down — then a turn end. `stop` is answered with `closed`. Every connection's summary is
appended as one JSON line to the report file, which the smoke script reads beside the app's session log.

Usage: scripts/native/fake-bridge.py <port> <report.jsonl>
"""

import asyncio
import json
import math
import struct
import sys

import websockets

OUT_RATE = 16000


def tone(seconds: float, hz: float = 330) -> bytes:
    n = int(OUT_RATE * seconds)
    return b"".join(struct.pack("<h", int(8000 * math.sin(2 * math.pi * hz * i / OUT_RATE))) for i in range(n))


async def handle(ws, report_path: str) -> None:
    summary = {"start": None, "texts": [], "binary_frames": 0, "binary_bytes": 0, "stopped": False, "diagnostics_bytes": 0}
    spoke = False
    try:
        async for message in ws:
            if isinstance(message, bytes):
                summary["binary_frames"] += 1
                summary["binary_bytes"] += len(message)
                if summary["binary_frames"] == 5 and not spoke:
                    spoke = True
                    await ws.send(json.dumps({"type": "stt_partial", "text": "hello"}))
                    await ws.send(json.dumps({"type": "stt_final", "text": "hello Larry"}))
                    await ws.send(json.dumps({"type": "transcript", "who": "larry", "text": "Hi Igor, this is the fake bridge."}))
                    pcm = tone(1.0)
                    frame = OUT_RATE // 20 * 2  # 50 ms
                    for i in range(0, len(pcm), frame):
                        await ws.send(pcm[i : i + frame])
                    await ws.send(json.dumps({"type": "turn_end"}))
                continue
            m = json.loads(message)
            kind = m.get("type")
            summary["texts"].append(kind)
            if kind == "start":
                summary["start"] = m
                await ws.send(json.dumps({"type": "ready", "out_rate": OUT_RATE, "backend": m.get("backend"), "session": "fake"}))
            elif kind == "mic_probe":
                await ws.send(json.dumps({"type": "mic_ack", "token": m.get("token")}))
            elif kind == "diagnostics":
                summary["diagnostics_bytes"] = len(m.get("text", ""))
            elif kind == "stop":
                summary["stopped"] = True
                await ws.send(json.dumps({"type": "closed", "reason": "stopped"}))
                await ws.close()
    except websockets.ConnectionClosed:
        pass
    finally:
        with open(report_path, "a") as f:
            f.write(json.dumps(summary) + "\n")


async def main() -> None:
    port, report_path = int(sys.argv[1]), sys.argv[2]
    async with websockets.serve(lambda ws: handle(ws, report_path), "localhost", port, max_size=None):
        print(f"fake bridge on ws://localhost:{port}", flush=True)
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
