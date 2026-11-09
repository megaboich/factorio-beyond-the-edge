#!/usr/bin/env python3
"""Pointer step (optional variant): draws Factorio's mouse pointer over master-1440p.mp4 so
each building window looks clicked open, and writes master-1440p-pointer.mp4.
The director puts the chosen building 23 tiles at zoom 1 = 736 px left of centre at 1080p,
whatever the zoom, so the click target is fixed: (960 - 736, 540) * 4/3 in the 1440p master."""
import os, re, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "video-demo-output", "spacelab")
os.makedirs(OUT, exist_ok=True)
FF = "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg"
CURSOR = os.path.expanduser("~/Library/Application Support/Steam/steamapps/common/Factorio/"
                            "factorio.app/Contents/data/core/graphics/mouse-cursor.png")
SCALE = 4 / 3
TARGET = ((960 - 736) * SCALE, 540 * SCALE)
REST = (2560 * 0.78, 1440 * 0.80)
ARRIVE, LEAVE = 0.9, 0.8   # glide times in seconds
EARLY = 0.15               # arrive this long before the window opens

lua = open(os.path.join(HERE, "director", "scenes.lua")).read()
opens = [int(t) / 60 for t in re.findall(r'\{(\d+), "open"\}', lua)]
closes = [int(t) / 60 for t in re.findall(r'\{(\d+), "close"\}', lua)]

# Keyframes (time, x, y); between two keyframes the pointer eases (smoothstep).
keys = [(0.0, *REST)]
for o, c in zip(opens, closes):
    keys += [(o - EARLY - ARRIVE, *REST), (o - EARLY, *TARGET), (c, *TARGET), (c + LEAVE, *REST)]

def expr(i):
    parts = f"{keys[-1][i]:.1f}"
    for (a, *pa), (b, *pb) in reversed(list(zip(keys, keys[1:]))):
        f = f"((t-{a:.3f})/{b - a:.3f})"
        ease = f"({f}*{f}*(3-2*{f}))"
        seg = f"({pa[i - 1]:.1f}+({pb[i - 1] - pa[i - 1]:.1f})*{ease})"
        parts = f"if(lt(t,{b:.3f}),{seg},{parts})"
    return f"if(lt(t,{keys[0][0]:.3f}),{keys[0][i]:.1f},{parts})"

w, h = round(30 * SCALE), round(45 * SCALE)
subprocess.run([FF, "-y", "-loglevel", "error", "-i", os.path.join(OUT, "master-1440p.mp4"), "-loop", "1", "-i", CURSOR,
                "-filter_complex", f"[1]scale={w}:{h}:flags=lanczos,format=rgba[c];"
                f"[0][c]overlay=x='{expr(1)}':y='{expr(2)}':eval=frame:shortest=1,format=yuv420p",
                "-an", "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "14",
                "-g", "30", "-bf", "2", "-movflags", "+faststart",
                os.path.join(OUT, "master-1440p-pointer.mp4")], check=True)
print(f"{len(opens)} clicks -> master-1440p-pointer.mp4")
