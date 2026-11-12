#!/usr/bin/env python3
"""Mux step (files in video-demo-output/spacelab): mix voice.wav over game-audio.wav and put the mix next to the untouched
master-1440p.mp4 picture (stream copy, no video re-encode). Writes spacelab-demo-youtube.mp4;
`mux.py pointer` uses master-1440p-pointer.mp4 and writes spacelab-demo-youtube-pointer.mp4."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "video-demo-output", "spacelab")
os.makedirs(OUT, exist_ok=True)
FF = "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg"
GAME, VOICE = 0.9, 1.3
p = lambda n: os.path.join(OUT, n)
suffix = "-pointer" if sys.argv[1:] == ["pointer"] else ""
subprocess.run([FF, "-y", "-loglevel", "error", "-i", p(f"master-1440p{suffix}.mp4"), "-i", p("game-audio.wav"),
                "-i", p("voice.wav"), "-filter_complex",
                f"[1:a]volume={GAME}[g];[2:a]aresample=48000,volume={VOICE}[n];"
                "[g][n]amix=inputs=2:duration=first:normalize=0[a]",
                "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
                "-shortest", "-movflags", "+faststart", p(f"spacelab-demo-youtube{suffix}.mp4")], check=True)
print("->", p(f"spacelab-demo-youtube{suffix}.mp4"))
