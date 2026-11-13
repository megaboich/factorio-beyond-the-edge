#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$ROOT_DIR/.." && pwd)"
FACTORIO_BIN="${FACTORIO_BIN:-/Applications/factorio.app/Contents/MacOS/factorio}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bte-stargate-tests.XXXXXX")"
BUILD_MODS="$TEST_ROOT/build-mods"
RUN_MODS="$TEST_ROOT/run-mods"

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

mkdir "$BUILD_MODS" "$RUN_MODS"
FACTORIO_MODS_DIR="$BUILD_MODS" "$REPO_DIR/make.sh" stargate

PACKAGE="$(printf '%s\n' "$BUILD_MODS"/bte-stargate_*.zip)"
if [[ ! -f "$PACKAGE" ]]; then
  printf 'Stargate package was not created\n' >&2
  exit 1
fi
if unzip -Z1 "$PACKAGE" | grep -q '/tests/'; then
  printf 'Packaged mod unexpectedly contains tests/\n' >&2
  exit 1
fi

# Fresh-save smoke test of the shipped package alone.
SMOKE_MODS="$TEST_ROOT/smoke-mods"
mkdir "$SMOKE_MODS"
cp "$PACKAGE" "$SMOKE_MODS/"
"$FACTORIO_BIN" --mod-directory "$SMOKE_MODS" --create "$TEST_ROOT/smoke-save.zip" --map-gen-seed 12345
"$FACTORIO_BIN" --mod-directory "$SMOKE_MODS" --benchmark "$TEST_ROOT/smoke-save.zip" \
  --benchmark-ticks 120 --benchmark-runs 1
printf 'STARGATE_TEST_PASS: fresh-save smoke test\n'

cp "$PACKAGE" "$RUN_MODS/"
cp -R "$ROOT_DIR/tests/mods/bte-stargate-runtime-test" "$RUN_MODS/"
"$FACTORIO_BIN" --mod-directory "$RUN_MODS" --create "$TEST_ROOT/run-save.zip" --map-gen-seed 12345
"$FACTORIO_BIN" --mod-directory "$RUN_MODS" --benchmark "$TEST_ROOT/run-save.zip" \
  --benchmark-ticks 600 --benchmark-runs 1 2>&1 | tee "$TEST_ROOT/run.log"

if ! grep -q 'STARGATE_TEST_PASS: filters, exact slots, completion, staged build, replacement, grid snapping, and mining paths completed' "$TEST_ROOT/run.log"; then
  printf 'Stargate runtime test did not emit its pass marker\n' >&2
  exit 1
fi
printf 'STARGATE_TEST_PASS: all runtime tests\n'
