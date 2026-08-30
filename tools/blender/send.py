# Sends Python to the running Blender and prints what it says back.
#
# ⚠ **This is the FALLBACK, not the main path** (2026-08-30). The `mcp__blender__*` tools work —
# measured the same day against Blender 5.1.1 — so reach for them first, and use this when a script is
# long enough that piping a file beats pasting code.
#
# It was written on 2026-08-26 when two MCP servers fought over port 9876: the official Blender 5.1
# extension wanted JSON with a terminator byte, the community add-on wanted bare JSON, and the community
# client hung forever against the official server with no error. **The user fixed that**, and this file
# already speaks the surviving protocol — the same one the tools speak.
#
# Usage:
#   python tools/blender/send.py path/to/script.py
#   echo "import bpy; print(len(bpy.data.objects))" | python tools/blender/send.py -
import io
import json
import socket
import sys

HOST = "127.0.0.1"
PORT = 9876
TIMEOUT_SEC = 180.0


def send(code: str) -> dict:
    s = socket.socket()
    s.settimeout(TIMEOUT_SEC)
    s.connect((HOST, PORT))
    # ⚠⚠ **THE COMMUNITY PROTOCOL — bare JSON, no terminator** (moved here 2026-08-27). The official
    # extension wanted `{"type":"execute","code":...}` plus a NULL byte; this add-on wants
    # `{"type":"execute_code","params":{"code":...}}` and nothing after it, and answers with
    # `{"status":..., "result":{"result": "<the stdout>"}}`.
    s.sendall(json.dumps({"type": "execute_code", "params": {"code": code}}).encode("utf-8"))
    buf = b""
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
        # ⚠ **The reply has no terminator, so completeness is tested by parsing it.** Waiting for the
        # socket to close instead works too but costs the whole read timeout on every single call.
        try:
            json.loads(buf.decode("utf-8"))
            break
        except ValueError:
            continue
    s.close()
    out = json.loads(buf.decode("utf-8"))
    # Flattened to the two keys every caller already reads, so `main` and `bake_island.ps1` are untouched.
    inner = out.get("result", {})
    text = inner.get("result", inner.get("stdout", "")) if isinstance(inner, dict) else str(inner)
    return {"status": out.get("status", "ok"), "stdout": text, "message": out.get("message", "")}


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else "-"
    # ⚠ **Both paths are read as UTF-8.** A bare `sys.stdin.read()` uses the console codepage on
    # Windows, and a heredoc carrying non-ASCII comments arrives as mojibake that Blender then refuses
    # to encode at all — the traceback says "surrogates not allowed" and names no cause.
    code = (io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8").read()
            if src == "-" else io.open(src, encoding="utf-8").read())
    out = send(code)
    if out.get("stdout"):
        sys.stdout.write(out["stdout"])
    # ⚠ **`success` and not `ok`** — the community add-on's word for it. Both are accepted so a swap
    # back does not silently turn every good run into a failure.
    if out.get("status") not in ("ok", "success"):
        sys.stderr.write(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
