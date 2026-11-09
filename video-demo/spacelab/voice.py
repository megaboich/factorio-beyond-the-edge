#!/usr/bin/env python3
"""Voice step: speak the narration from scenes.py into the scene times of the existing
recording (read from director/scenes.lua, which the recording was made with), and write
  voice.wav               narration track on the master's clock, in video-demo-output
  spacelab-demo.en.srt    one cue per line; every line should be a complete sentence
A scene whose lines do not fit is spoken faster, up to MAX_SPEED, and reported.
Run with ~/.cache/narrated-screen-demo/venv/bin/python voice.py [voice]."""
import os, re, sys
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "video-demo-output", "spacelab")
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, HERE)
from scenes import SCENES  # noqa: E402

VOICE = sys.argv[1] if len(sys.argv) > 1 else "af_bella"
SPEED, MAX_SPEED = 1.25, 1.4
LEAD, GAP, TAIL = 0.4, 0.35, 0.3
SPOKEN = [("\n", " ")]
M = os.path.expanduser("~/.cache/narrated-screen-demo/models")
k = Kokoro(f"{M}/kokoro-v1.0.onnx", f"{M}/voices-v1.0.bin")

lua = open(os.path.join(HERE, "director", "scenes.lua")).read()
keys = [int(t) / 60 for t in re.findall(r"\{(\d+), -?[\d.]+, -?[\d.]+, [\d.]+\}", lua)]
# keys: start, then (glide end, hold end) per scene, so scene i ends at keys[2 + 2i].
ends = keys[2::2]
total = int(re.search(r"total = (\d+)", lua).group(1)) / 60
if len(ends) != len(SCENES):
    sys.exit(f"scenes.py has {len(SCENES)} scenes, the recording {len(ends)}")

def speak(text, speed):
    for a, b in SPOKEN:
        text = text.replace(a, b)
    audio, sr = k.create(text.strip(), voice=VOICE, speed=speed, lang="en-us")
    loud = np.where(np.abs(audio) > 0.01)[0]
    return audio[loud[0]:loud[-1] + 1], sr

sr = 24000
track = np.zeros(int((total + 1) * sr), np.float32)
cues, start = [], 0.0
for i, (sc, end) in enumerate(zip(SCENES, ends)):
    slot = end - start - LEAD - TAIL - GAP * (len(sc["lines"]) - 1)
    speed = SPEED
    while True:
        clips = [speak(l, speed)[0] for l in sc["lines"]]
        need = sum(len(c) for c in clips) / sr
        if need <= slot or speed >= MAX_SPEED:
            break
        speed = min(MAX_SPEED, speed * need / slot + 0.02)
    t = start + LEAD
    for line, c in zip(sc["lines"], clips):
        track[int(t * sr):int(t * sr) + len(c)] += c
        cues.append((t, min(t + len(c) / sr + 0.25, end), line))
        t += len(c) / sr + GAP
    flag = f"  OVERRUN {need - slot:.1f}s" if need > slot + 0.05 else ""
    print(f"{i:2d} {start:5.1f}-{end:5.1f}  voice {need:4.1f}s of {slot:4.1f}s  x{speed:.2f}{flag}")
    start = end

sf.write(os.path.join(OUT, "voice.wav"), track, sr)
def ts(x):
    return f"{int(x // 3600):02d}:{int(x % 3600 // 60):02d}:{x % 60:06.3f}".replace(".", ",")
with open(os.path.join(HERE, "spacelab-demo.en.srt"), "w") as f:
    f.write("\n".join(f"{n}\n{ts(a)} --> {ts(b)}\n{txt}\n" for n, (a, b, txt) in enumerate(cues, 1)))
print(f"{len(cues)} lines -> voice.wav, spacelab-demo.en.srt")
