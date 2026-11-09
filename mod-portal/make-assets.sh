#!/usr/bin/env bash
# Mod Portal assets: the 144x144 mod thumbnails (packaged as <mod>/thumbnail.png) and the gallery
# screenshots in mod-portal/<mod>/gallery/, cut from the demo-video recordings and in-game
# screenshots in the git-ignored video-demo-output/ (see video-demo/README.md).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/.."; SRC="$ROOT/video-demo-output"
FF=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
FONT='/System/Library/Fonts/Supplemental/Arial Black.ttf'
SL_VIDEO="$SRC/spacelab/master-1440p-pointer.mp4"; WD_VIDEO="$SRC/warp-drive/warp-drive-demo-youtube-1440p.mp4"

# Drawn at 576 px and reduced 4x so the title stays sharp at 144 px.
thumb() { # source crop title-line-1 title-line-2 colour border output
  "$FF" -loglevel error -y -i "$1" -vf "crop=$2,scale=576:576:flags=lanczos,eq=contrast=1.15:saturation=1.3,\
drawbox=x=0:y=0:w=576:h=250:color=$6@0.55:t=fill,\
drawtext=fontfile='$FONT':text='$3':fontsize=118:fontcolor=$5:borderw=12:bordercolor=$6:x=(w-tw)/2:y=10,\
drawtext=fontfile='$FONT':text='$4':fontsize=118:fontcolor=$5:borderw=12:bordercolor=$6:x=(w-tw)/2:y=124,\
scale=144:144:flags=lanczos" -frames:v 1 "$7"
}
thumb "$SRC/spacelab/thumb/growth.png" 760:760:568:250 SPACE LAB 0xB6FF3B 0x0B1A05 "$ROOT/spacelab/thumbnail.png"
thumb "$SRC/warp-drive/thumbnail-frames/frame-57.0.png" 900:900:640:170 WARP DRIVE white 0x002840 "$ROOT/warp-drive/thumbnail.png"

# Gallery: 1920x1080 JPEGs, named in display order.
shot() { # video-or-image seconds output
  local d="$HERE/$3"; mkdir -p "$(dirname "$d")"
  if [[ "$2" == - ]]; then "$FF" -loglevel error -y -i "$1" -vf scale=1920:1080:flags=lanczos -q:v 2 "$d"
  else "$FF" -loglevel error -y -ss "$2" -i "$1" -frames:v 1 -vf scale=1920:1080:flags=lanczos -q:v 2 "$d"; fi
}
shot "$SRC/spacelab/thumb/growth-close.png" - spacelab/gallery/1-growth-facilities.jpg
shot "$SL_VIDEO" 60 spacelab/gallery/2-biter-egg-incubation.jpg
shot "$SL_VIDEO" 27 spacelab/gallery/3-shattered-synthesis.jpg
shot "$SL_VIDEO" 39 spacelab/gallery/4-flurolite-condensation.jpg
shot "$SRC/spacelab/thumb/labs-close.png" - spacelab/gallery/5-labs-in-orbit.jpg
shot "$SRC/warp-drive/thumbnail-frames/frame-57.0.png" - warp-drive/gallery/1-warp-jump.jpg
shot "$WD_VIDEO" 62 warp-drive/gallery/2-subspace.jpg
shot "$WD_VIDEO" 90 warp-drive/gallery/3-warp-drive.jpg
shot "$WD_VIDEO" 45 warp-drive/gallery/4-charging.jpg
shot "$WD_VIDEO" 75 warp-drive/gallery/5-warp-status.jpg
shot "$WD_VIDEO" 115 warp-drive/gallery/6-space-map.jpg
echo done
