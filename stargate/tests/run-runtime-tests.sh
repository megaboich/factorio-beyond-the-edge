#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$ROOT_DIR/.." && pwd)"
FACTORIO_BIN="${FACTORIO_BIN:-/Applications/factorio.app/Contents/MacOS/factorio}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bte-stargate-tests.XXXXXX")"
BUILD_MODS="$TEST_ROOT/build-mods"

cleanup() {
  if [[ "${KEEP_TEST_ARTIFACTS:-0}" == "1" ]]; then
    printf 'Test artifacts: %s\n' "$TEST_ROOT"
  else
    rm -rf "$TEST_ROOT"
  fi
}
trap cleanup EXIT

export FACTORIO_BIN
RUN="$REPO_DIR/tests/factorio.sh"

mkdir "$BUILD_MODS"
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

# Smoke test of the shipped package alone, added to a fresh save.
"$RUN" run 120 "$PACKAGE" > "$TEST_ROOT/smoke.log"
printf 'STARGATE_TEST_PASS: fresh-save smoke test\n'

"$RUN" run 44700 "$PACKAGE" "$ROOT_DIR/tests/mods/bte-stargate-runtime-test" | tee "$TEST_ROOT/run.log"

if ! grep -q 'STARGATE_TEST_PASS: filters, exact slots, completion, staged build, replacement, grid snapping, gate pairing, power, circuit, transfer, vehicle and enemy transfer, train transfer, and mining paths completed' "$TEST_ROOT/run.log"; then
  printf 'Stargate runtime test did not emit its pass marker\n' >&2
  exit 1
fi
printf 'STARGATE_TEST_PASS: all runtime tests\n'
