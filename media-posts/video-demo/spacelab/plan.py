#!/usr/bin/env python3
"""Plan step, run before a new recording: speak every narration line, lay scenes out on a
timeline, and write
  voice.wav               narration track (t=0 is the first scene start), in video-demo-output
  spacelab-demo.en.srt    subtitles on the same clock
  director/scenes.lua  camera keyframes and window open/close ticks for the director mod
Run with ~/.cache/narrated-screen-demo/venv/bin/python plan.py [voice]."""
import os, re, sys
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "video-demo-output", "spacelab")
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, HERE)
from scenes import SCENES, START, SURFACE  # noqa: E402

VOICE = sys.argv[1] if len(sys.argv) > 1 else "af_bella"
SPEED = 1.25
MOVE = 2.5        # seconds the camera glides to a scene
LEAD = 0.4        # narration starts this long after the scene starts
GAP = 0.35        # pause between lines of one scene
TAIL = 0.9        # hold after the last line
MIN_SCENE = 4.0
MIN_OPEN = 6.5     # scenes that show a building window hold long enough to read it
SPOKEN = [("…", ","), ("\n", " ")]
M = os.path.expanduser("~/.cache/narrated-screen-demo/models")
k = Kokoro(f"{M}/kokoro-v1.0.onnx", f"{M}/voices-v1.0.bin")

def speak(text):
    for a, b in SPOKEN:
        text = text.replace(a, b)
    text = re.sub(r"\s*,\s*$", ".", text.strip())
    audio, sr = k.create(text, voice=VOICE, speed=SPEED, lang="en-us")
    loud = np.where(np.abs(audio) > 0.01)[0]
    return audio[loud[0]:loud[-1] + 1], sr

t, clips, cues, keys, events = 0.0, [], [], [], []
keys.append((0.0, *START))
for i, sc in enumerate(SCENES):
    x, y, z = sc["cam"]
    keys.append((t + MOVE, x, y, z))
    lt = t + LEAD
    for line in sc["lines"]:
        audio, sr = speak(line)
        d = len(audio) / sr
        clips.append((lt, audio))
        cues.append((lt, lt + d + 0.25, line))
        lt += d + GAP
    end = max(t + (MIN_OPEN if "open" in sc else MIN_SCENE), lt - GAP + TAIL, t + MOVE + 1.5)
    keys.append((end, x, y, z))
    if "open" in sc:
        events.append((t, "pick", sc["open"], (x, y, len(keys) - 1, len(keys))))
        events.append((t + MOVE, "open", None, None))
        events.append((end - 0.3, "close", None, None))
    print(f"{i:2d} {t:6.1f}-{end:6.1f}  {sc['lines'][0].splitlines()[0]}")
    t = end
total = t

sr = 24000
track = np.zeros(int((total + 1) * sr), np.float32)
for s, a in clips:
    track[int(s * sr):int(s * sr) + len(a)] += a
sf.write(os.path.join(OUT, "voice.wav"), track, sr)

def ts(x):
    return f"{int(x // 3600):02d}:{int(x % 3600 // 60):02d}:{x % 60:06.3f}".replace(".", ",")
with open(os.path.join(HERE, "spacelab-demo.en.srt"), "w") as f:
    f.write("\n".join(f"{n}\n{ts(a)} --> {ts(b)}\n{txt}\n" for n, (a, b, txt) in enumerate(cues, 1)))

tick = lambda s: int(round(s * 60))
lua = ["return {", f'  surface = "{SURFACE}",', f"  total = {tick(total)},", "  keys = {"]
lua += [f"    {{{tick(a)}, {x}, {y}, {z}}}," for a, x, y, z in keys]
lua += ["  },", "  events = {"]
for a, kind, target, pos in events:
    if kind == "pick":
        lua.append(f'    {{{tick(a)}, "pick", "{target[0]}", "{target[1]}", {pos[0]}, {pos[1]}, {pos[2]}, {pos[3]}}},')
    else:
        lua.append(f'    {{{tick(a)}, "{kind}"}},')
lua += ["  },", "}"]
open(os.path.join(HERE, "director", "scenes.lua"), "w").write("\n".join(lua) + "\n")
print(f"total {total:.1f}s, {len(cues)} lines")
