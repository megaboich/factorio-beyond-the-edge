#!/usr/bin/env python3
"""Master step, run once per recording: cut capture.mov at the director's dark frames,
stretch it to the planned length (the game runs slightly under 60 UPS), and write to
video-demo-output/spacelab
  master-1440p.mp4   picture only, upscaled to 2560x1440 at high quality
  game-audio.wav     recorded game sound on the same clock
Later narration and subtitle changes only need voice.py and mux.py."""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "video-demo-output", "spacelab")
os.makedirs(OUT, exist_ok=True)
FF = "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg"
total = int(re.search(r"total = (\d+)", open(os.path.join(HERE, "director", "scenes.lua")).read()).group(1)) / 60
cap = os.path.join(OUT, "capture.mov")

# The director's blackout still shows the dim space background, and the status panel stays
# on top, so the cut points are where the centre's average brightness crosses DARK.
DARK = 35
out = subprocess.run([FF, "-hide_banner", "-i", cap, "-vf",
                      "crop=iw/2:ih/2:iw/4:ih/4,signalstats,metadata=print:key=lavfi.signalstats.YAVG",
                      "-an", "-f", "null", "-"], capture_output=True, text=True).stderr
times = [float(t) for t in re.findall(r"pts_time:([\d.]+)", out)]
luma = [float(v) for v in re.findall(r"YAVG=([\d.]+)", out)]
bright = [i for i, y in enumerate(luma) if y > DARK]
if not bright:
    sys.exit("no scene frames found")
start, end = times[bright[0]], times[bright[-1]] + 1 / 60
factor = total / (end - start)
print(f"scenes {start:.2f}-{end:.2f}s ({end - start:.2f}s) -> {total:.2f}s, x{factor:.4f}")

cut = ["-ss", f"{start:.3f}", "-to", f"{end:.3f}", "-i", cap]
subprocess.run([FF, "-y", "-loglevel", "error", *cut,
                "-vf", f"setpts=(PTS-STARTPTS)*{factor:.6f},fps=60,scale=2560:1440:flags=lanczos,format=yuv420p",
                "-an", "-t", f"{total:.3f}", "-c:v", "libx264", "-profile:v", "high", "-preset", "slow",
                "-crf", "14", "-g", "30", "-bf", "2", "-movflags", "+faststart",
                os.path.join(OUT, "master-1440p.mp4")], check=True)
subprocess.run([FF, "-y", "-loglevel", "error", *cut, "-vn",
                "-af", f"atempo={1 / factor:.6f},aresample=48000", "-t", f"{total:.3f}",
                "-c:a", "pcm_s16le", os.path.join(OUT, "game-audio.wav")], check=True)
print("-> master-1440p.mp4, game-audio.wav")
