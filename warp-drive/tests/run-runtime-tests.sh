#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FACTORIO_BIN="${FACTORIO_BIN:-/Applications/factorio.app/Contents/MacOS/factorio}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/warp-drive-tests.XXXXXX")"
BUILD_MODS="$TEST_ROOT/build-mods"
BASIC_MODS="$TEST_ROOT/basic-mods"
PLATFORM_MODS="$TEST_ROOT/platform-mods"
MIGRATION_MODS="$TEST_ROOT/migration-mods"

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

mkdir "$BUILD_MODS" "$BASIC_MODS" "$PLATFORM_MODS" "$MIGRATION_MODS"
FACTORIO_MODS_DIR="$BUILD_MODS" "$ROOT_DIR/make.sh"

PACKAGE="$(printf '%s\n' "$BUILD_MODS"/warp-drive_*.zip)"
if [[ ! -f "$PACKAGE" ]]; then
  printf 'Warp Drive package was not created\n' >&2
  exit 1
fi
if unzip -Z1 "$PACKAGE" | grep -q '/tests/'; then
  printf 'Packaged mod unexpectedly contains tests/\n' >&2
  exit 1
fi

cp "$PACKAGE" "$BASIC_MODS/"
"$FACTORIO_BIN" \
  --mod-directory "$BASIC_MODS" \
  --create "$TEST_ROOT/basic-save.zip" \
  --map-gen-seed 12345
"$FACTORIO_BIN" \
  --mod-directory "$BASIC_MODS" \
  --benchmark "$TEST_ROOT/basic-save.zip" \
  --benchmark-ticks 120 \
  --benchmark-runs 1
printf 'WARP_TEST_PASS: fresh-save smoke test\n'

cp "$PACKAGE" "$PLATFORM_MODS/"
cp -R "$ROOT_DIR/tests/mods/aaa-warp-drive-speed-test" "$PLATFORM_MODS/"
cp -R "$ROOT_DIR/tests/mods/warp-drive-runtime-test" "$PLATFORM_MODS/"
"$FACTORIO_BIN" \
  --mod-directory "$PLATFORM_MODS" \
  --create "$TEST_ROOT/platform-save.zip" \
  --map-gen-seed 12345
"$FACTORIO_BIN" \
  --mod-directory "$PLATFORM_MODS" \
  --benchmark "$TEST_ROOT/platform-save.zip" \
  --benchmark-ticks 700 \
  --benchmark-runs 1 2>&1 | tee "$TEST_ROOT/platform.log"

if ! grep -q 'WARP_TEST_PASS: detector, duplicate, revocation, warp, power-loss, lockout, and relocation paths completed' "$TEST_ROOT/platform.log"; then
  printf 'Platform runtime test did not emit its pass marker\n' >&2
  exit 1
fi

cp "$PACKAGE" "$MIGRATION_MODS/"
cp -R "$ROOT_DIR/tests/mods/warp-drive-migration-fixture" "$MIGRATION_MODS/"
"$FACTORIO_BIN" \
  --mod-directory "$MIGRATION_MODS" \
  --create "$TEST_ROOT/migration-save.zip" \
  --map-gen-seed 12345
cp -R "$ROOT_DIR/tests/mods/warp-drive-migration-test" "$MIGRATION_MODS/"
"$FACTORIO_BIN" \
  --mod-directory "$MIGRATION_MODS" \
  --benchmark "$TEST_ROOT/migration-save.zip" \
  --benchmark-ticks 10 \
  --benchmark-runs 1 2>&1 | tee "$TEST_ROOT/migration.log"

if ! grep -q 'WARP_TEST_PASS: legacy drive, health, direction, circuit wire, and companions migrated' "$TEST_ROOT/migration.log"; then
  printf 'Migration runtime test did not emit its pass marker\n' >&2
  exit 1
fi

printf 'WARP_TEST_PASS: all runtime tests\n'
