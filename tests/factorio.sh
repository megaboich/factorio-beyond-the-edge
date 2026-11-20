#!/usr/bin/env bash
# Runs Factorio for the test runners and probes with a command line that never changes, so the
# Steam build asks to allow its launch arguments once rather than on every run.
#
#   tests/factorio.sh run TICKS MOD...     load the base save with MODs for TICKS ticks; log to stdout,
#                                          failing if the run ended early
#   tests/factorio.sh dump OUT MOD...      dump prototypes, then their locale, with MODs into directory OUT
#
# A MOD is a packaged ZIP or a mod directory. Everything lives in one fixed directory
# ($BTE_FACTORIO_HOME, by default ~/Library/Caches/bte-factorio): its own config.ini and write-data,
# the mod directory, emptied and refilled for each run, and the base save, created once with only
# the built-in mods (seed 12345). Mods missing from the base save run their on_init as it loads, so a
# test mod builds its world there as it would in a freshly created save. Runs are given a huge tick
# count and stopped by a generated helper mod, which raises the error BTE_RUN_STOP after TICKS.
# Only one run at a time can use the directory.
set -euo pipefail

FACTORIO_BIN="${FACTORIO_BIN:-/Applications/factorio.app/Contents/MacOS/factorio}"
HOME_DIR="${BTE_FACTORIO_HOME:-$HOME/Library/Caches/bte-factorio}"
CONFIG="$HOME_DIR/config.ini"
MODS="$HOME_DIR/mods"
WRITE="$HOME_DIR/write-data"
BASE="$HOME_DIR/base.zip"
LOCK="$HOME_DIR/lock"

if [[ ! -x "$FACTORIO_BIN" ]]; then
  printf 'Factorio executable not found: %s\n' "$FACTORIO_BIN" >&2
  exit 1
fi

mkdir -p "$HOME_DIR" "$MODS" "$WRITE"
if ! mkdir "$LOCK" 2>/dev/null; then
  printf 'Another run is using %s (remove %s if none is)\n' "$HOME_DIR" "$LOCK" >&2
  exit 1
fi
trap 'rm -rf "$LOCK"' EXIT
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$WRITE" > "$CONFIG"

fill_mods() {
  rm -rf "$MODS"
  mkdir "$MODS"
  for mod in "$@"; do
    cp -R "$mod" "$MODS/"
  done
}

if [[ ! -f "$BASE" ]]; then
  fill_mods
  "$FACTORIO_BIN" --config "$CONFIG" --mod-directory "$MODS" --create "$BASE" --map-gen-seed 12345 >/dev/null
fi

command="${1:-}"
shift || true
case "$command" in
  run)
    ticks="$1"
    shift
    fill_mods "$@"
    stop="$MODS/zzz-bte-run-stop"
    mkdir "$stop"
    printf '{"name":"zzz-bte-run-stop","version":"0.0.1","title":"Run stop","author":"bte","factorio_version":"2.1","dependencies":["base"]}\n' > "$stop/info.json"
    cat > "$stop/control.lua" <<EOF
script.on_init(function() storage.stop = game.tick + $ticks end)
script.on_event(defines.events.on_tick, function(event)
  if storage.stop and event.tick >= storage.stop then
    error("BTE_RUN_STOP")
  end
end)
EOF
    # The stop is an error, so the exit status says nothing; a run that ended without reaching it
    # failed (another error, or a crash).
    "$FACTORIO_BIN" --config "$CONFIG" --mod-directory "$MODS" --benchmark "$BASE" \
      --benchmark-ticks 100000000 --benchmark-runs 1 2>&1 | tee "$HOME_DIR/run.log" || true
    grep -q BTE_RUN_STOP "$HOME_DIR/run.log"
    ;;
  dump)
    out="$1"
    shift
    fill_mods "$@"
    mkdir -p "$out"
    rm -rf "$WRITE/script-output"
    # One dump per launch: resolved prototypes (data-raw-dump.json), then the names and
    # descriptions players see (<type>-locale.json).
    for flag in --dump-data --dump-prototype-locale; do
      if ! "$FACTORIO_BIN" --config "$CONFIG" --mod-directory "$MODS" "$flag" > "$out/factorio.log" 2>&1; then
        exit 1
      fi
    done
    cp "$WRITE"/script-output/* "$out/"
    ;;
  *)
    sed -n '2,7p' "$0" >&2
    exit 2
    ;;
esac
