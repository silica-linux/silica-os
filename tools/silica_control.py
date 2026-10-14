#!/usr/bin/env python3
"""A minimal client of Ossido's control channel, for the boot test (standard library only).

The protocol is silica-desktop's (crates/control): one JSON object per line,
{"id", "command", "params"} → {"id", "ok", "result" | "error"}.

    silica_control.py ADDRESS call COMMAND [JSON]   print the result
    silica_control.py ADDRESS ping                  exit 0 if Ossido answers (perf.frames)
    silica_control.py ADDRESS screenshot PATH       save ui.screenshot as PNG
    silica_control.py - nonblack PATH               print the share of non-black pixels (0–1)
"""

import base64
import json
import socket
import struct
import sys
import zlib


def call(address, command, params=None, timeout=30.0):
    host, _, port = address.rpartition(":")
    with socket.create_connection((host or "127.0.0.1", int(port)), timeout=timeout) as sock:
        request = {"id": 1, "command": command, "params": params or {}}
        sock.sendall(json.dumps(request).encode() + b"\n")
        data = b""
        while not data.endswith(b"\n"):
            chunk = sock.recv(1 << 20)
            if not chunk:
                raise ConnectionError("connection closed by the server")
            data += chunk
    response = json.loads(data)
    if not response.get("ok"):
        raise RuntimeError(f"{command}: {response.get('error')}")
    return response.get("result")


def png_pixels(png):
    """Decodes an 8-bit, non-interlaced RGB or RGBA PNG: (width, height, channels, rows)."""
    if png[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, header = 8, b"", None
    while pos < len(png):
        (length,) = struct.unpack(">I", png[pos : pos + 4])
        kind = png[pos + 4 : pos + 8]
        body = png[pos + 8 : pos + 8 + length]
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    if header is None:
        raise ValueError("PNG without IHDR")
    width, height, depth, color, _, _, interlace = header
    channels = {2: 3, 6: 4}.get(color)
    if depth != 8 or channels is None or interlace:
        raise ValueError(f"unsupported PNG (depth {depth}, color {color}, interlace {interlace})")
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, previous = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1 : start + 1 + stride])
        for x in range(stride):
            a = line[x - channels] if x >= channels else 0
            b = previous[x]
            c = previous[x - channels] if x >= channels else 0
            if kind == 1:
                line[x] = (line[x] + a) & 0xFF
            elif kind == 2:
                line[x] = (line[x] + b) & 0xFF
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 0xFF
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pred) & 0xFF
        rows.append(line)
        previous = line
    return width, height, channels, rows


def nonblack(png):
    width, height, channels, rows = png_pixels(png)
    lit = 0
    for line in rows:
        for x in range(0, width * channels, channels):
            if line[x] > 8 or line[x + 1] > 8 or line[x + 2] > 8:
                lit += 1
    return lit / (width * height) if width and height else 0.0


def main(argv):
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    address, action = argv[1], argv[2]
    if action == "call":
        params = json.loads(argv[4]) if len(argv) > 4 else {}
        print(json.dumps(call(address, argv[3], params), indent=2))
    elif action == "ping":
        try:
            call(address, "perf.frames", timeout=10.0)
        except (OSError, ValueError, RuntimeError):
            return 1
    elif action == "screenshot":
        result = call(address, "ui.screenshot", timeout=60.0)
        with open(argv[3], "wb") as out:
            out.write(base64.b64decode(result["png_base64"]))
    elif action == "nonblack":
        with open(argv[3], "rb") as png:
            print(f"{nonblack(png.read()):.4f}")
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
