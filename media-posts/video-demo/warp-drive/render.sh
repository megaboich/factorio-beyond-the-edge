#!/usr/bin/env bash
# Warp Drive demo: edits the hand-made screen recording and renders the YouTube upload.
# Input: video-demo-output/warp-drive/Demo-recording.mov (QuickTime recording, game sound only).
# Edit: drop the first 7 s, slow source 54-60 s (run-up to the first jump) to 0.6x, rest 1x.
#   ./render.sh edit     picture-only and game-sound-only edits, the base for narration work
#   ./render.sh youtube  final 1440p upload with the V2-bella voice-over mix
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../../video-demo-output/warp-drive"
FF=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
cd "$OUT"
EDIT="[0:v]trim=7:54,setpts=PTS-STARTPTS[v1];[0:v]trim=54:60,setpts=(PTS-STARTPTS)/0.6[v2];\
[0:v]trim=60,setpts=PTS-STARTPTS[v3];[v1][v2][v3]concat=n=3:v=1:a=0,fps=60"

case "${1:-}" in
  edit)
    "$FF" -y -loglevel error -i Demo-recording.mov -filter_complex "$EDIT,format=yuv420p[v]" -map "[v]" -an \
      -c:v libx264 -preset slow -crf 16 warp-drive-demo-video.mp4
    "$FF" -y -loglevel error -i Demo-recording.mov -filter_complex "\
[0:a]atrim=7:54,asetpts=PTS-STARTPTS[a1];[0:a]atrim=54:60,asetpts=PTS-STARTPTS,atempo=0.6[a2];\
[0:a]atrim=60,asetpts=PTS-STARTPTS[a3];[a1][a2][a3]concat=n=3:v=0:a=1[a]" -map "[a]" \
      -c:a aac -b:a 192k warp-drive-demo-audio.m4a ;;
  youtube)
    # A 1080p upload only gets YouTube's lower-quality processing; 1440p keeps dialog text sharp.
    "$FF" -y -loglevel error -i Demo-recording.mov -i V2-bella.m4a -filter_complex \
      "$EDIT,scale=2560:1440:flags=lanczos,format=yuv420p[v]" -map "[v]" -map 1:a \
      -c:v libx264 -profile:v high -preset slow -crf 16 -g 30 -bf 2 -c:a aac -b:a 192k -ar 48000 \
      -shortest -movflags +faststart warp-drive-demo-youtube-1440p.mp4 ;;
  thumbnail)
    # Frame 57.0 s of the 1440p upload (first jump shockwave), saved as thumbnail-frames/frame-57.0.png.
    FONT='/System/Library/Fonts/Supplemental/Arial Black.ttf'
    "$FF" -y -loglevel error -i thumbnail-frames/frame-57.0.png -vf "crop=1760:990:395:120,\
scale=1280:720:flags=lanczos,delogo=x=938:y=240:w=36:h=46,eq=contrast=1.12:saturation=1.3,\
drawtext=fontfile='$FONT':text='WARP DRIVE':fontsize=130:fontcolor=white:borderw=10:bordercolor=0x002840:x=(w-tw)/2:y=30,\
drawbox=x=300:y=200:w=680:h=100:color=0x001826@0.75:t=fill,\
drawtext=fontfile='$FONT':text='7,500 km/s':fontsize=84:fontcolor=0x5FF2FF:borderw=6:bordercolor=0x001018:x=(w-tw)/2:y=205,\
drawtext=fontfile='$FONT':text='FACTORIO SPACE AGE MOD':fontsize=44:fontcolor=0x8FF0FF:borderw=6:bordercolor=0x101018:x=(w-tw)/2:y=640" \
      -q:v 2 "$HERE/thumbnail.jpg" ;;
  *) sed -n '2,7p' "$0"; exit 1 ;;
esac
