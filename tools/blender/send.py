# Sends Python to the running Blender and prints what it says back.
#
# ⚠⚠ **This exists because TWO MCP servers fight over port 9876** (found 2026-08-26). Blender 5.1 ships
# an official MCP extension (`lab_blender_org/mcp`) that listens on 9876, and the community
# `blender-mcp` add-on wants the same port. They do NOT speak the same protocol:
#
#   · official  — one JSON object terminated by a NULL byte: {"type":"execute","code":...,
#                 "strict_json":bool}\0 , and the reply is JSON terminated by a NULL byte
#   · community — a bare JSON object with no terminator: {"type":"get_scene_info","params":{}}
#
# ⇒ **The community client hangs forever against the official server.** It connects, sends, and the
# server sits waiting for a terminator that never comes. Nothing in the error output says so — the
# call just never returns, which is what cost an afternoon.
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
    # ⚠ The NULL byte is the whole protocol. Without it the server never starts reading.
    s.sendall((json.dumps({"type": "execute", "code": code, "strict_json": False}) + "\0").encode("utf-8"))
    buf = b""
    while b"\0" not in buf:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
    s.close()
    return json.loads(buf.split(b"\0")[0].decode("utf-8"))


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
    if out.get("status") != "ok":
        sys.stderr.write(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
