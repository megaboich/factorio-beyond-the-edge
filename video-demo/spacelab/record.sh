#!/usr/bin/env bash
# Records the Space Lab demo: launches Factorio on the demo save with the director mod, records
# the game window (picture and system sound) with macOS screencapture until the scene list
# ends, then closes the game. Accept the Steam custom-arguments prompt when it appears, and keep
# the game's sound on. Output: video-demo-output/spacelab/capture.mov.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../../video-demo-output/spacelab"
F="${FACTORIO_BIN:-$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio}"
USER_DATA="$HOME/Library/Application Support/factorio"
SAVE="${SAVE:-$USER_DATA/saves/Continents - SpaceLab - Demo.zip}"
RUN="$OUT/run"; MODS="$RUN/mods"; LOG="$RUN/factorio.log"; BIN="$OUT/bin"

# Helpers: window bounds (to record only the game area) and mouse warp (to hide the pointer).
mkdir -p "$BIN"
for t in winbounds movemouse; do
  [[ "$BIN/$t" -nt "$HERE/tools/$t.swift" ]] || swiftc -O "$HERE/tools/$t.swift" -o "$BIN/$t"
done

# Your installed mods and their settings, plus the director. Without mod-settings.dat every mod
# runs on defaults (AAI Loaders then needs lubricant and shows red icons).
rm -rf "$RUN"; mkdir -p "$MODS/bte-video-director"
cp "$USER_DATA/mods/"*.zip "$USER_DATA/mods/mod-settings.dat" "$MODS/"
cp "$HERE/director/"* "$MODS/bte-video-director/"

# A copy of your config: windowed at 100% UI scale. Your own config.ini is not changed.
sed -e 's/^; full-screen=.*/full-screen=false/' -e 's/^full-screen=.*/full-screen=false/' \
    -e 's/^ui-scale-mode=.*/ui-scale-mode=manual-pixels/' \
    -e 's/^; custom-ui-scale=.*/custom-ui-scale=1/' -e 's/^custom-ui-scale=.*/custom-ui-scale=1/' \
    "$USER_DATA/config/config.ini" > "$RUN/config.ini"

# SteamAppId lets the Steam build start with custom arguments. Steam restarts the game from
# another directory, so every path given to Factorio must be absolute.
(SteamAppId=427520 SteamGameId=427520 "$F" --config "$RUN/config.ini" --mod-directory "$MODS" \
  --window-size 1920x1080 --disable-migration-window --load-game "$SAVE" > "$LOG" 2>&1 &)
until grep -q "DIRECTOR ready" "$LOG" 2>/dev/null; do sleep 0.2; done

# Record only the game area: the window's bottom 1080 points (above them is the title bar).
IFS=, read -r WX WY WW WH < <("$BIN/winbounds" factorio)
RECT="$WX,$((WY + WH - 1080)),1920,1080"
echo "window $WX,$WY ${WW}x$WH -> recording $RECT"
"$BIN/movemouse" $((WX + WW + 40)) $((WY + WH / 2))
TOTAL=$(sed -nE 's/.*total = ([0-9]+).*/\1/p' "$HERE/director/scenes.lua")
rm -f "$OUT/capture.mov"
# -A records system audio (the game sound); -x only silences the shutter sound.
screencapture -v -x -A -V $((TOTAL / 60 + 12)) -R "$RECT" "$OUT/capture.mov" &
REC=$!
until grep -qE "DIRECTOR done|Error" "$LOG"; do sleep 0.5; done
wait $REC || true  # stops by itself after -V seconds; interrupting can leave the file unfinished
pkill -f "MacOS/factorio" || true
grep -E "DIRECTOR|Error" "$LOG"
