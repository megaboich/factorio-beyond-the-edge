#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPRITE_DIR="$SCRIPT_DIR/entity/warp-drive"
BASE_SHEET_1="$SPRITE_DIR/quantum-stabilizer-hr-animation-1.png"
BASE_SHEET_2="$SPRITE_DIR/quantum-stabilizer-hr-animation-2.png"
EMISSION_SHEET_1="$SPRITE_DIR/quantum-stabilizer-hr-emission-1.png"
EMISSION_SHEET_2="$SPRITE_DIR/quantum-stabilizer-hr-emission-2.png"
OUTPUT="${1:-$SCRIPT_DIR/warp-drive.gif}"
OUTPUT_SIZE=220
OUTPUT_FPS=8
PALETTE_COLORS=64

command -v ffmpeg >/dev/null 2>&1 || {
  printf 'ffmpeg is required to generate the Warp Drive GIF.\n' >&2
  exit 1
}

for sheet in "$BASE_SHEET_1" "$BASE_SHEET_2" "$EMISSION_SHEET_1" "$EMISSION_SHEET_2"; do
  if [[ ! -f "$sheet" ]]; then
    printf 'Missing sprite sheet: %s\n' "$sheet" >&2
    exit 1
  fi
done

# The first 8x8 stripe provides frames 1-64. The second 8x5 stripe provides
# frames 65-100, with its final four cells unused.
# Factorio runs animation_speed 0.35 at 60 updates per second, yielding 21 fps.
# The GIF samples the complete loop at a smaller size and frame rate to stay below 1 MiB.
ffmpeg -hide_banner -loglevel warning -y \
  -loop 1 -framerate 21 -i "$BASE_SHEET_1" \
  -loop 1 -framerate 21 -i "$EMISSION_SHEET_1" \
  -loop 1 -framerate 21 -i "$BASE_SHEET_2" \
  -loop 1 -framerate 21 -i "$EMISSION_SHEET_2" \
  -filter_complex \
    "[0:v]format=rgba,crop=410:410:x='mod(n,8)*410':y='floor(n/8)*410',trim=end_frame=64,split[base1][alpha-source1]; \
     [alpha-source1]alphaextract[alpha1]; \
     [1:v]format=rgba,crop=410:410:x='mod(n,8)*410':y='floor(n/8)*410',trim=end_frame=64[emission1]; \
     [base1][emission1]blend=all_mode=addition:shortest=1[lit1]; \
     [lit1][alpha1]alphamerge[first]; \
     [2:v]format=rgba,crop=410:410:x='mod(n,8)*410':y='floor(n/8)*410',trim=end_frame=36,split[base2][alpha-source2]; \
     [alpha-source2]alphaextract[alpha2]; \
     [3:v]format=rgba,crop=410:410:x='mod(n,8)*410':y='floor(n/8)*410',trim=end_frame=36[emission2]; \
     [base2][emission2]blend=all_mode=addition:shortest=1[lit2]; \
     [lit2][alpha2]alphamerge[second]; \
     [first][second]concat=n=2:v=1:a=0,setpts=N/(21*TB),fps=$OUTPUT_FPS,scale=$OUTPUT_SIZE:$OUTPUT_SIZE:flags=lanczos,split[frames][palette-source]; \
     [palette-source]palettegen=max_colors=$PALETTE_COLORS:reserve_transparent=1:transparency_color=000000:stats_mode=diff[palette]; \
     [frames][palette]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  -loop 0 -final_delay 13 "$OUTPUT"

printf 'Generated %s\n' "$OUTPUT"
