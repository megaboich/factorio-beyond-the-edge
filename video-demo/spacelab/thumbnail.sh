#!/usr/bin/env bash
# Thumbnail: takes in-game screenshots of the demo save (shots-mod), then composes the
# 1280x720 split image: Growth Facilities left, labs right, lime title text.
# Accept the Steam custom-arguments prompt. Output: thumbnail.jpg (committed) and the raw
# screenshots in video-demo-output/spacelab/thumb. Set SKIP_SHOTS=1 to reuse existing ones.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../../video-demo-output/spacelab/thumb"
FF=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
F="${FACTORIO_BIN:-$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio}"
USER_DATA="$HOME/Library/Application Support/factorio"
SAVE="${SAVE:-$USER_DATA/saves/Continents - SpaceLab - Demo.zip}"
SHOTS="$USER_DATA/script-output/bte-thumb"
mkdir -p "$OUT"

if [[ "${SKIP_SHOTS:-0}" != 1 ]]; then
  rm -rf "$OUT/mods" "$SHOTS"; mkdir -p "$OUT/mods/bte-video-shots"
  cp "$USER_DATA/mods/"*.zip "$USER_DATA/mods/mod-settings.dat" "$OUT/mods/"
  cp "$HERE/shots-mod/"* "$OUT/mods/bte-video-shots/"
  (SteamAppId=427520 SteamGameId=427520 "$F" --mod-directory "$OUT/mods" --window-size 1920x1080 \
    --disable-migration-window --load-game "$SAVE" > "$OUT/run.log" 2>&1 &)
  until [[ $(ls "$SHOTS" 2>/dev/null | wc -l) -ge 8 ]]; do sleep 1; done
  sleep 3; pkill -f "MacOS/factorio" || true
  cp "$SHOTS"/*.png "$OUT/"
fi

FONT='/System/Library/Fonts/Supplemental/Arial Black.ttf'
LIME=0xB6FF3B; DARK=0x0B1A05
"$FF" -loglevel error -y -i "$OUT/growth.png" -i "$OUT/labs-close.png" -filter_complex "\
[0]crop=800:900:548:60,scale=640:720:flags=lanczos[l];\
[1]crop=960:1080:670:0,scale=640:720:flags=lanczos[r];\
[l][r]hstack,eq=contrast=1.1:saturation=1.25,\
drawbox=x=636:y=0:w=8:h=720:color=$DARK:t=fill,drawbox=x=638:y=0:w=4:h=720:color=$LIME:t=fill,\
drawtext=fontfile='$FONT':text='SPACE LAB':fontsize=140:fontcolor=$LIME:borderw=10:bordercolor=$DARK:x=(w-tw)/2:y=24,\
drawbox=x=250:y=205:w=780:h=96:color=$DARK@0.8:t=fill,\
drawtext=fontfile='$FONT':text='FULL SCIENCE IN ORBIT':fontsize=56:fontcolor=white:borderw=5:bordercolor=$DARK:x=(w-tw)/2:y=222,\
drawtext=fontfile='$FONT':text='FACTORIO SPACE AGE MOD':fontsize=44:fontcolor=$LIME:borderw=6:bordercolor=$DARK:x=(w-tw)/2:y=640" \
  -frames:v 1 -update 1 -q:v 2 "$HERE/thumbnail.jpg"
echo "-> $HERE/thumbnail.jpg"
