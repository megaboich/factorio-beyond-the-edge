#!/usr/bin/env python3
"""Extracts the item, fluid, and technology icons each mod README references into <mod>/docs/icons/.

READMEs reference item and fluid icons as `docs/icons/<prototype-name>.png` and technology icons
as `docs/icons/technology/<prototype-name>.png`. This script finds every such reference, loads the
resolved prototypes from a --dump-data run of every mod together (so mod prototypes resolve with
their runtime tints and layers), and composites each icon as the game's GUI draws it: every
layer scaled, shifted, and tinted, and the whole stack fitted to the square. Items are written
at 64 px and technologies at 128 px. Icons no README references any more are removed.

    python3 tools/readme-icons.py [--dump data-raw-dump.json] [mod ...]

Without --dump it runs Factorio in temporary mod and write-data directories, like
tests/run-prototype-tests.sh. FACTORIO_BIN and FACTORIO_DATA override the default install.
Uses only the standard library: PNG decoding is limited to 8-bit RGB(A), grey(-alpha), and
palette images, which covers Factorio's icons.
"""
import argparse
import json
import math
import os
import re
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FACTORIO_BIN = os.environ.get("FACTORIO_BIN", "/Applications/factorio.app/Contents/MacOS/factorio")
FACTORIO_DATA = Path(os.environ.get("FACTORIO_DATA", "/Applications/factorio.app/Contents/data"))
MODS = ["spacelab", "warp-drive"]
REFERENCE = re.compile(r"docs/icons/((?:technology/)?[a-z0-9-]+)\.png")
# kind: (expected_icon_size, output size)
SIZES = {"item": (64, 64), "technology": (256, 128)}


def read_png(path):
    """Returns (width, height, rows of RGBA bytes) for an 8-bit, non-interlaced PNG."""
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, palette, alpha = 8, b"", None, b""
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or interlace:
                raise ValueError(f"{path}: unsupported PNG (depth {depth}, interlace {interlace})")
        elif kind == b"PLTE":
            palette = body
        elif kind == b"tRNS":
            alpha = body
        elif kind == b"IDAT":
            idat += body
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color]
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, previous = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        for i in range(stride):
            left = line[i - channels] if i >= channels else 0
            up = previous[i]
            corner = previous[i - channels] if i >= channels else 0
            if kind == 1:
                line[i] = (line[i] + left) & 255
            elif kind == 2:
                line[i] = (line[i] + up) & 255
            elif kind == 3:
                line[i] = (line[i] + (left + up) // 2) & 255
            elif kind == 4:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                line[i] = (line[i] + (left if pa <= pb and pa <= pc else up if pb <= pc else corner)) & 255
        previous = line
        rgba = bytearray()
        for x in range(width):
            px = line[x * channels:(x + 1) * channels]
            if color == 6:
                rgba += px
            elif color == 2:
                rgba += px + b"\xff"
            elif color == 4:
                rgba += bytes([px[0]] * 3) + px[1:2]
            elif color == 0:
                rgba += bytes([px[0]] * 3) + b"\xff"
            else:
                i = px[0]
                rgba += palette[i * 3:i * 3 + 3] + bytes([alpha[i] if i < len(alpha) else 255])
        rows.append(rgba)
    return width, height, rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", len(rows[0]) // 4, len(rows), 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def resolve(filename):
    match = re.fullmatch(r"__([a-z0-9_-]+)__/(.+)", filename)
    root = match.group(1)
    for mod in MODS:
        if json.loads((REPO / mod / "info.json").read_text())["name"] == root:
            return REPO / mod / match.group(2)
    return FACTORIO_DATA / root / match.group(2)


def icon(prototype, kind, cache={}):
    """The prototype's icon as rows of RGBA bytes.

    Follows IconData: a layer is drawn icon_size * scale units wide (scale defaulting to
    (expected_icon_size / 2) / icon_size) on a canvas of expected_icon_size / 2 units, offset by
    its shift, and the GUI fits all layers into the slot. Tints multiply every channel.
    """
    expected, out = SIZES[kind]
    layers = prototype.get("icons") or [{"icon": prototype["icon"], "icon_size": prototype.get("icon_size", 64)}]
    placed = []
    for layer in layers:
        size = layer.get("icon_size") or prototype.get("icon_size") or 64
        half = size * (layer.get("scale") or (expected / 2) / size) / 2
        shift = layer.get("shift") or [0, 0]
        if isinstance(shift, dict):
            shift = [shift["x"], shift["y"]]
        tint = layer.get("tint") or {}
        if isinstance(tint, list):
            tint = dict(zip("rgba", tint))
        factors = [tint.get(k, 1) for k in "rgba"]
        if max(factors) > 1:
            factors = [f / 255 for f in factors]
        path = resolve(layer["icon"])
        if path not in cache:
            cache[path] = read_png(path)[2]
        placed.append((cache[path], size, shift[0] - half, shift[1] - half, 2 * half, factors))
    left, top = min(p[2] for p in placed), min(p[3] for p in placed)
    right, bottom = max(p[2] + p[4] for p in placed), max(p[3] + p[4] for p in placed)
    side = max(right - left, bottom - top)
    x0, y0 = (left + right - side) / 2, (top + bottom - side) / 2
    unit = side / out
    canvas = [[0.0] * (out * 4) for _ in range(out)]  # premultiplied RGBA, 0-1
    for rows, size, lx, ly, width, factors in placed:
        # Enough samples per output pixel to cover the source pixels it spans.
        n = max(1, math.ceil(size * unit / width))
        for oy in range(out):
            for ox in range(out):
                acc = [0.0] * 4
                for j in range(n):
                    v = ((y0 + (oy + (j + 0.5) / n) * unit) - ly) / width
                    if not 0 <= v < 1:
                        continue
                    for i in range(n):
                        u = ((x0 + (ox + (i + 0.5) / n) * unit) - lx) / width
                        if not 0 <= u < 1:
                            continue
                        # Bilinear, premultiplied, like the game's linear filtering of enlarged layers.
                        fx, fy = min(max(u * size - 0.5, 0), size - 1), min(max(v * size - 0.5, 0), size - 1)
                        ix, iy = min(int(fx), size - 2), min(int(fy), size - 2)
                        tx, ty = fx - ix, fy - iy
                        for dy, wy in ((0, 1 - ty), (1, ty)):
                            row = rows[iy + dy]
                            for dx, wx in ((0, 1 - tx), (1, tx)):
                                k = (ix + dx) * 4
                                a = row[k + 3] / 255 * factors[3] * wx * wy
                                for c in range(3):
                                    acc[c] += row[k + c] / 255 * factors[c] * a
                                acc[3] += a
                if acc[3] == 0:
                    continue
                pixel = canvas[oy]
                keep = 1 - acc[3] / (n * n)
                for c in range(4):
                    pixel[ox * 4 + c] = acc[c] / (n * n) + pixel[ox * 4 + c] * keep
    result = []
    for row in canvas:
        line = bytearray()
        for x in range(out):
            a = row[x * 4 + 3]
            line += bytes([min(255, round(row[x * 4 + c] / a * 255)) if a else 0 for c in range(3)] + [min(255, round(a * 255))])
        result.append(line)
    return result


def dump_data():
    with tempfile.TemporaryDirectory() as work:
        mods, write = Path(work, "mods"), Path(work, "write")
        mods.mkdir()
        write.mkdir()
        subprocess.run([str(REPO / "make.sh"), *MODS], check=True, stdout=subprocess.DEVNULL,
                       env={**os.environ, "FACTORIO_MODS_DIR": str(mods)})
        config = Path(work, "config.ini")
        config.write_text(f"[path]\nread-data=__PATH__system-read-data__\nwrite-data={write}\n")
        subprocess.run([FACTORIO_BIN, "--config", str(config), "--mod-directory", str(mods), "--dump-data"],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return json.loads((write / "script-output" / "data-raw-dump.json").read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--dump", type=Path)
    parser.add_argument("mods", nargs="*", default=MODS)
    args = parser.parse_args()
    raw = json.loads(args.dump.read_text()) if args.dump else dump_data()
    # Items of every item-like type (capsules, tools, ...) carry a stack size; fluids are separate.
    prototypes = {f"technology/{name}": p for name, p in raw.get("technology", {}).items()}
    for kind, entries in raw.items():
        for name, prototype in entries.items():
            if "stack_size" in prototype or kind == "fluid":
                prototypes.setdefault(name, prototype)
    for mod in args.mods:
        names = sorted(set(REFERENCE.findall((REPO / mod / "README.md").read_text())))
        target = REPO / mod / "docs" / "icons"
        (target / "technology").mkdir(parents=True, exist_ok=True)
        missing = [n for n in names if n not in prototypes]
        if missing:
            sys.exit(f"{mod}: no item, fluid, or technology named {', '.join(missing)}")
        for name in names:
            write_png(target / f"{name}.png", icon(prototypes[name], "technology" if name.startswith("technology/") else "item"))
        for stale in target.glob("**/*.png"):
            if stale.relative_to(target).with_suffix("").as_posix() not in names:
                stale.unlink()
        print(f"{mod}: {len(names)} icons in {target.relative_to(REPO)}")


if __name__ == "__main__":
    main()
