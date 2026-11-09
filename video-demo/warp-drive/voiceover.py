#!/usr/bin/env python3
"""Voice-over from the subtitle cues: one Kokoro line per cue, starting at the cue start.

Usage: voiceover.py <voice> <name> [base_speed]
Writes <name>-voice.wav (voice only) and <name>.m4a (voice + game sound) to
video-demo-output/warp-drive. The published video used `voiceover.py af_bella V2-bella`.
A line longer than its cue is re-spoken faster (up to MAX_SPEED); the report lists any
line that still overruns.
"""
import os, re, subprocess, sys
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "video-demo-output", "warp-drive")
sys.path.insert(0, HERE)
from subtitles import CUES  # noqa: E402

voice, name = sys.argv[1], sys.argv[2]
BASE = float(sys.argv[3]) if len(sys.argv) > 3 else 1.25
MAX_SPEED = 1.6
GAP = 0.1
SPOKEN = [("km/s", "kilometers per second"), ("WARP", "warp"), ("…", ","), ("\n", " ")]
FF = "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg"
M = os.path.expanduser("~/.cache/narrated-screen-demo/models")
k = Kokoro(f"{M}/kokoro-v1.0.onnx", f"{M}/voices-v1.0.bin")
lang = "en-gb" if voice.startswith("b") else "en-us"

def speak(text, speed):
    for a, b in SPOKEN:
        text = text.replace(a, b)
    text = re.sub(r"\s*,\s*$", ".", text.strip())
    audio, sr = k.create(text, voice=voice, speed=speed, lang=lang)
    # Kokoro pads with silence; trim it so lines start on the cue.
    loud = np.where(np.abs(audio) > 0.01)[0]
    return (audio[loud[0]:loud[-1] + 1] if len(loud) else audio), sr

total = CUES[-1][1] + 2
track, sr = None, 24000
for i, (start, end, text) in enumerate(CUES, 1):
    slot = end - start - GAP
    speed = BASE
    audio, sr = speak(text, speed)
    while len(audio) / sr > slot and speed < MAX_SPEED:
        speed = min(MAX_SPEED, speed * (len(audio) / sr) / slot + 0.02)
        audio, sr = speak(text, speed)
    if track is None:
        track = np.zeros(int(total * sr), np.float32)
    s = int(start * sr)
    track[s:s + len(audio)] += audio
    dur = len(audio) / sr
    flag = "  OVERRUN %.1fs" % (dur - slot) if dur > slot + 0.05 else ""
    print(f"{i:2d} {start:6.1f} slot {slot:4.1f}s voice {dur:4.1f}s x{speed:.2f}{flag}  {text.replace(chr(10), ' ')}")

voice_wav = os.path.join(OUT, f"{name}-voice.wav")
sf.write(voice_wav, track, sr)
subprocess.run([FF, "-y", "-loglevel", "error", "-i", os.path.join(OUT, "warp-drive-demo-audio.m4a"),
                "-i", voice_wav, "-filter_complex",
                "[0:a]volume=0.3[g];[1:a]aresample=48000,volume=1.4[v];[g][v]amix=inputs=2:duration=first:normalize=0[a]",
                "-map", "[a]", "-c:a", "aac", "-b:a", "160k", os.path.join(OUT, f"{name}.m4a")], check=True)
print("->", os.path.join(OUT, f"{name}.m4a"))
