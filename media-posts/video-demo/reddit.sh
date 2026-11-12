#!/usr/bin/env bash
# Reddit copies of both demo videos: 1920x1080 at 30 fps, about 12 Mbit/s, with the narration and
# burned-in subtitles (Reddit takes no subtitle files, and its own scaler and frame-rate
# conversion are poor). Written to reddit-post/ for upload; run after both videos are final.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; OUT="$HERE/../video-demo-output"; DEST="$HERE/../reddit-post"
FF=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
# libass sizes are relative to a 288-line script, so FontSize 10 is about 37 px at 1080p.
STYLE="FontName=Arial,FontSize=10,Bold=1,PrimaryColour=&H00FFFFFF,BorderStyle=4,BackColour=&H60000000,Outline=1,Shadow=0,MarginV=14"
ENC=(-c:v libx264 -profile:v high -preset slow -b:v 12M -maxrate 16M -bufsize 24M -g 60 -bf 2 -pix_fmt yuv420p
     -c:a aac -b:a 192k -ar 48000 -movflags +faststart)
srt() { sed "s/'/\\\\'/g; s/:/\\\\:/g" <<<"$1"; }
mkdir -p "$DEST"

# Warp Drive: the same edit as warp-drive/render.sh, from the 1080p recording.
EDIT="[0:v]trim=7:54,setpts=PTS-STARTPTS[v1];[0:v]trim=54:60,setpts=(PTS-STARTPTS)/0.6[v2];\
[0:v]trim=60,setpts=PTS-STARTPTS[v3];[v1][v2][v3]concat=n=3:v=1:a=0"
"$FF" -y -loglevel error -i "$OUT/warp-drive/Demo-recording.mov" -i "$OUT/warp-drive/V2-bella.m4a" -filter_complex \
  "$EDIT,scale=1920:1080:flags=lanczos,fps=30,subtitles='$(srt "$HERE/warp-drive/warp-drive-demo.en.srt")':force_style='$STYLE'[v]" \
  -map "[v]" -map 1:a -shortest "${ENC[@]}" "$DEST/warp-drive-demo-reddit.mp4"

# Space Lab: the published upload (pointer master with narration), back down to its capture size.
"$FF" -y -loglevel error -i "$OUT/spacelab/spacelab-demo-youtube-pointer.mp4" -vf \
  "scale=1920:1080:flags=lanczos,fps=30,subtitles='$(srt "$HERE/spacelab/spacelab-demo.en.srt")':force_style='$STYLE'" \
  -map 0:v -map 0:a "${ENC[@]}" "$DEST/spacelab-demo-reddit.mp4"
ls -la "$DEST"/*-reddit.mp4
