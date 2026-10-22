#!/usr/bin/env bash
set -euo pipefail

# Dumps resolved prototypes for vanilla Space Age, each mod alone, and every mod together,
# then checks each mod's tests/prototypes.py expectations. Every run uses its own mod and
# write-data directories, so installed mods and the user's script-output are untouched.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FACTORIO_BIN="${FACTORIO_BIN:-/Applications/factorio.app/Contents/MacOS/factorio}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bte-prototype-tests.XXXXXX")"
ALL_MODS=(spacelab warp-drive)

cleanup() {
  if [[ "${KEEP_TEST_ARTIFACTS:-0}" == "1" ]]; then
    printf 'Test artifacts: %s\n' "$TEST_ROOT"
  else
    rm -rf "$TEST_ROOT"
  fi
}
trap cleanup EXIT

if [[ ! -x "$FACTORIO_BIN" ]]; then
  printf 'Factorio executable not found: %s\n' "$FACTORIO_BIN" >&2
  exit 1
fi

# dump_data <label> [mod-directory...]; prints the dump path.
dump_data() {
  local label="$1"
  shift
  local run_dir="$TEST_ROOT/$label"
  mkdir -p "$run_dir/mods" "$run_dir/write-data"
  if [[ $# -gt 0 ]]; then
    FACTORIO_MODS_DIR="$run_dir/mods" "$REPO_DIR/make.sh" "$@" >/dev/null
  fi
  printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$run_dir/write-data" > "$run_dir/config.ini"
  # Factorio performs one dump per launch: resolved prototypes, then the names and descriptions
  # players see (<type>-locale.json beside it).
  local dump
  for dump in --dump-data --dump-prototype-locale; do
    if ! "$FACTORIO_BIN" --config "$run_dir/config.ini" --mod-directory "$run_dir/mods" "$dump" \
        > "$run_dir/factorio.log" 2>&1; then
      printf 'Factorio failed to load mod set %s:\n' "$label" >&2
      tail -20 "$run_dir/factorio.log" >&2
      exit 1
    fi
  done
  printf '%s\n' "$run_dir/write-data/script-output/data-raw-dump.json"
}

check() {
  local label="$1" dump="$2"
  shift 2
  python3 -B "$REPO_DIR/tests/prototype_checks.py" --vanilla "$VANILLA" --dump "$dump" --label "$label" "$@"
}

VANILLA="$(dump_data vanilla)"
status=0
for mod in "${ALL_MODS[@]}"; do
  check "alone" "$(dump_data "$mod" "$mod")" "$mod" || status=1
done
check "together" "$(dump_data together "${ALL_MODS[@]}")" "${ALL_MODS[@]}" || status=1

if [[ $status -ne 0 ]]; then
  printf 'PROTOTYPE_TEST_FAIL: see failures above\n' >&2
  exit 1
fi
printf 'PROTOTYPE_TEST_PASS: all prototype tests\n'
