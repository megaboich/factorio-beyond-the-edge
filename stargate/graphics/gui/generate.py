#!/usr/bin/env python3
"""Draw the station-mode diagrams shown under the gate window's station drop-down (scripts/gui.lua).

A top-down view of the gate: the ring across the top, the tracks running into it from the gate's
south edge, and arrows for which way trains run on each track. Lanes sit at the offsets of
scripts/railway.lua's LAYOUTS (2 tiles either side of the centre), at SCALE pixels a tile. The
station is left out: it is invisible in game. Standard library only, drawn with supersampling, so a
rerun over unchanged code writes identical files.

  station-single  one central track, arrows both ways
  station-right   departures (up, into the ring) on the right, arrivals (down) on the left
  station-left    the mirror image
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

OUTPUT_DIRECTORY = Path(__file__).resolve().parent

SCALE = 8  # pixels a tile
WIDTH, HEIGHT = 112, 112
SUPERSAMPLE = 4
CENTER_X = WIDTH / 2

GROUND = (52, 50, 46, 255)
RING = (150, 156, 168, 255)
RING_SHADE = (92, 96, 108, 255)
VEIL = (96, 170, 255, 255)
SLEEPER = (96, 80, 62, 255)
RAIL = (190, 190, 186, 255)
DEPART = (96, 220, 96, 255)
ARRIVE = (255, 176, 48, 255)

LAYOUTS = {
    "single": {"depart": 0, "arrive": 0},
    "right": {"depart": 2, "arrive": -2},
    "left": {"depart": -2, "arrive": 2},
}

RING_TOP, RING_BOTTOM = 10, 20
TRACK_TOP, TRACK_BOTTOM = RING_BOTTOM, HEIGHT - 4


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def arrow(x, y_tail, y_head, half_width=3.0, head=7.0):
    """An arrow along a lane, as a polygon, pointing from y_tail to y_head."""
    sign = 1 if y_head > y_tail else -1
    neck = y_head - sign * head
    return [
        (x - half_width, y_tail), (x + half_width, y_tail), (x + half_width, neck),
        (x + half_width * 2.4, neck), (x, y_head), (x - half_width * 2.4, neck), (x - half_width, neck),
    ]


def inside(polygon, px, py):
    result = False
    j = len(polygon) - 1
    for i, (xi, yi) in enumerate(polygon):
        xj, yj = polygon[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
            result = not result
        j = i
    return result


def track(x):
    shapes = []
    for y in range(TRACK_TOP + 3, TRACK_BOTTOM, 6):
        shapes.append((rect(x - 7, y, x + 7, y + 3), SLEEPER))
    for side in (-4.5, 3.5):
        shapes.append((rect(x + side, TRACK_TOP, x + side + 1, TRACK_BOTTOM), RAIL))
    return shapes


def diagram(mode):
    layout = LAYOUTS[mode]
    depart_x = CENTER_X + layout["depart"] * SCALE
    arrive_x = CENTER_X + layout["arrive"] * SCALE
    shapes = [(rect(0, 0, WIDTH, HEIGHT), GROUND)]
    lanes = {depart_x, arrive_x}
    for x in sorted(lanes):
        shapes += track(x)
    # The ring seen from above, edge on: a band across the gate with the veil showing inside it.
    shapes.append((rect(6, RING_TOP, WIDTH - 6, RING_BOTTOM), RING_SHADE))
    shapes.append((rect(8, RING_TOP + 2, WIDTH - 8, RING_BOTTOM - 2), RING))
    shapes.append((rect(20, RING_TOP + 4, WIDTH - 20, RING_BOTTOM - 4), VEIL))
    if mode == "single":
        shapes.append((arrow(depart_x - 5, HEIGHT - 16, RING_BOTTOM + 14, half_width=2.2, head=6), DEPART))
        shapes.append((arrow(depart_x + 5, RING_BOTTOM + 14, HEIGHT - 16, half_width=2.2, head=6), ARRIVE))
    else:
        shapes.append((arrow(depart_x, HEIGHT - 14, RING_BOTTOM + 14), DEPART))
        shapes.append((arrow(arrive_x, RING_BOTTOM + 14, HEIGHT - 14), ARRIVE))

    boxes = []
    for polygon, color in shapes:
        xs = [p[0] for p in polygon]
        ys = [p[1] for p in polygon]
        boxes.append((polygon, color, min(xs), max(xs), min(ys), max(ys)))

    rows = []
    n = SUPERSAMPLE
    for y in range(HEIGHT):
        row = bytearray([0])
        for x in range(WIDTH):
            total = [0, 0, 0, 0]
            for sy in range(n):
                py = y + (sy + 0.5) / n
                for sx in range(n):
                    px = x + (sx + 0.5) / n
                    color = (0, 0, 0, 0)
                    for polygon, fill, x0, x1, y0, y1 in boxes:
                        if x0 <= px <= x1 and y0 <= py <= y1 and inside(polygon, px, py):
                            color = fill
                    for c in range(4):
                        total[c] += color[c]
            row += bytes(round(v / (n * n)) for v in total)
        rows.append(bytes(row))
    return b"".join(rows)


def png(pixels):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(pixels, 9)) + chunk(b"IEND", b""))


def main():
    for mode in LAYOUTS:
        path = OUTPUT_DIRECTORY / f"station-{mode}.png"
        path.write_bytes(png(diagram(mode)))
        print(path)


if __name__ == "__main__":
    main()
