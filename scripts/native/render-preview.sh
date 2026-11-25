#!/usr/bin/env bash
# Story 1625 (bead context-grabber-7xme): render one SwiftUI #Preview to a PNG from the command line, through Xcode's own
# MCP tool service (`xcrun mcpbridge`, JSON-RPC over stdio), with no MCP client and no Xcode window.
# Usage: render-preview.sh <file.swift> [out.png] [preview-index]
#   <file.swift>  a source file under native/ (or a path relative to it) that holds a #Preview
#   out.png       where to copy the snapshot (default: next to nothing; the path Xcode wrote is printed either way)
#   preview-index which #Preview in the file, counting from 0 (default 0)
# Environment: PREVIEW_DEVICE (default "iPad Pro 11-inch (M5)": no iPhone while the whiteboard rule stands),
#   PREVIEW_TIMEOUT seconds (default 600), PREVIEW_DRY_RUN=1 prints the JSON-RPC requests and stops (the script test).
# Needs, once per Mac (sudo, so Igor types it): headless mode on, `xcrun mcp-server allow-folder` for the checkout's
# folder (~/gits/context-grabber, ~/.treehouse) and `xcrun mcp-server approve <id>` for the caller. The caller Xcode
# sees is /usr/bin/timeout, which this script always puts in front of mcpbridge, so one approval covers every run.
# A cold render builds the app (about 35 s on the M5 Pro); a warm one takes about half a second.
set -euo pipefail

src=${1:?usage: render-preview.sh <file.swift> [out.png] [preview-index]}
out=${2:-}
index=${3:-0}
here=$(cd "$(dirname "$0")/../.." && pwd)
native="$here/native"
project="$native/GrabberNative.xcodeproj"

case "$src" in
  /*) abs=$src ;;
  native/*) abs="$here/$src" ;;
  *) abs="$native/$src" ;;
esac
[ -f "$abs" ] || { echo "render-preview: no such file: $abs" >&2; exit 2; }
case "$abs" in
  "$native"/*) rel=${abs#"$native"/} ;;
  *) echo "render-preview: $abs is not under $native" >&2; exit 2 ;;
esac
[ -d "$project" ] || [ "${PREVIEW_DRY_RUN:-}" = 1 ] || (cd "$native" && xcodegen --quiet --use-cache)

exec python3 -I - "$project" "GrabberNative/$rel" "$index" "$out" "${PREVIEW_DEVICE:-iPad Pro 11-inch (M5)}" \
  "${PREVIEW_TIMEOUT:-600}" "${PREVIEW_DRY_RUN:-0}" <<'PY'
import json, shutil, subprocess, sys, time

project, source, index, out, device, timeout, dry = sys.argv[1:8]
requests = [
    {"jsonrpc": "2.0", "id": 1, "method": "initialize",
     "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "render-preview", "version": "1"}}},
    {"jsonrpc": "2.0", "method": "notifications/initialized"},
    {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "XcodeOpenWorkspace", "arguments": {"path": project}}},
]
render = {"name": "RenderPreview", "arguments": {
    "sourceFilePath": source, "previewDefinitionIndexInFile": int(index), "timeout": int(timeout),
    "preferredRenderDestination": {"deviceModelName": device}}}
if dry == "1":
    for r in requests:
        print(json.dumps(r))
    print(json.dumps({"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": render}))
    sys.exit(0)

# /usr/bin/timeout is the approved caller; keep it the parent of mcpbridge.
bridge = subprocess.Popen(["timeout", str(int(timeout) + 120), "xcrun", "mcpbridge"],
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)

def send(message):
    bridge.stdin.write(json.dumps(message) + "\n")
    bridge.stdin.flush()

def answer(ident):
    while True:
        line = bridge.stdout.readline()
        if not line:
            sys.exit("render-preview: the bridge closed before answering (is headless mode on? `xcrun mcp-server status`)")
        try:
            message = json.loads(line)
        except ValueError:
            continue
        if message.get("id") == ident:
            return message

def text_of(message):
    return " ".join(c.get("text", "") for c in message.get("result", {}).get("content", []))

start = time.time()
for r in requests:
    send(r)
    if "id" in r:
        reply = answer(r["id"])
opened = reply.get("result", {})
if opened.get("isError"):
    sys.exit("render-preview: Xcode would not open the project: " + text_of(reply)
             + "\n(its folder may need `sudo xcrun mcp-server allow-folder`; pending ids: `xcrun mcp-server status`)")
workspace = (opened.get("structuredContent") or {}).get("workspaceIdentifier") or project
render["arguments"]["workspaceIdentifier"] = workspace

ident = 3
while True:
    send({"jsonrpc": "2.0", "id": ident, "method": "tools/call", "params": render})
    reply = answer(ident)
    if "Waiting for packages to load" in text_of(reply) and time.time() - start < int(timeout):
        time.sleep(10)
        ident += 1
        continue
    break
bridge.stdin.close()
bridge.terminate()

result = reply.get("result", {})
snapshot = ((result.get("structuredContent") or {}).get("snapshot") or {}).get("path")
if result.get("isError") or not snapshot:
    sys.exit("render-preview: no picture:\n" + text_of(reply)[:4000])
if out:
    shutil.copyfile(snapshot, out)
    snapshot = out
print(f"render-preview: {snapshot} ({time.time() - start:.1f} s)")
PY
